import Foundation
import SwiftData

/// Service for fetching "ghost" sets from previous sessions for comparison
class GhostSetService {

    /// Represents a ghost set from a previous session
    struct GhostSet: Identifiable {
        let id = UUID()
        let setNumber: Int
        let reps: Int
        let weight: Double
        let unit: WeightUnit
        let e1rm: Double
        let date: Date

        var displayString: String {
            if weight > 0 {
                return "\(reps) × \(Int(weight)) \(unit.rawValue)"
            } else {
                return "\(reps) reps"
            }
        }
    }

    /// Represents ghost data for an entire exercise
    struct GhostExercise {
        let exerciseName: String
        let sets: [GhostSet]
        let date: Date
        let averageE1RM: Double

        var isEmpty: Bool { sets.isEmpty }
    }

    /// Fetch the most recent session's sets for a given exercise name
    /// - Parameters:
    ///   - exerciseName: Name of the exercise to find
    ///   - workouts: All workouts to search through
    ///   - excludeWorkoutId: Optional workout ID to exclude (e.g., current workout being edited)
    /// - Returns: GhostExercise with previous session's data, or nil if not found
    static func fetchGhostExercise(
        named exerciseName: String,
        from workouts: [Workout],
        excludeWorkoutId: UUID? = nil
    ) -> GhostExercise? {
        // Sort workouts by date (most recent first)
        let sortedWorkouts = workouts
            .filter { $0.id != excludeWorkoutId }
            .sorted { $0.date > $1.date }

        // Find the most recent workout containing this exercise
        for workout in sortedWorkouts {
            if let exercise = workout.exercise(named: exerciseName) {
                let ghostSets = exercise.sortedSets.map { set in
                    GhostSet(
                        setNumber: set.setNumber,
                        reps: set.reps,
                        weight: set.weight,
                        unit: set.unit,
                        e1rm: E1RMCalculator.calculate(for: set),
                        date: workout.date
                    )
                }

                return GhostExercise(
                    exerciseName: exercise.name,
                    sets: ghostSets,
                    date: workout.date,
                    averageE1RM: E1RMCalculator.averageE1RM(for: exercise.sets)
                )
            }
        }

        return nil
    }

    /// Fetch ghost data for multiple exercises at once
    static func fetchGhostExercises(
        named exerciseNames: [String],
        from workouts: [Workout],
        excludeWorkoutId: UUID? = nil
    ) -> [String: GhostExercise] {
        var result: [String: GhostExercise] = [:]

        for name in exerciseNames {
            if let ghost = fetchGhostExercise(named: name, from: workouts, excludeWorkoutId: excludeWorkoutId) {
                result[name.lowercased()] = ghost
            }
        }

        return result
    }

    /// Compare a current set to a ghost set and determine if it's a PR
    static func compareSet(
        current: ParsedSet,
        ghost: GhostSet
    ) -> SetComparison {
        let currentE1RM = E1RMCalculator.calculate(for: current)
        let improvement = E1RMCalculator.improvement(current: currentE1RM, previous: ghost.e1rm)
        let isPR = E1RMCalculator.isPersonalBest(current: currentE1RM, previous: ghost.e1rm)

        return SetComparison(
            currentE1RM: currentE1RM,
            previousE1RM: ghost.e1rm,
            improvement: improvement,
            isPersonalBest: isPR
        )
    }

    /// Result of comparing current set to previous
    struct SetComparison {
        let currentE1RM: Double
        let previousE1RM: Double
        let improvement: Double  // Percentage
        let isPersonalBest: Bool

        var improvementString: String {
            if improvement > 0 {
                return "+\(String(format: "%.1f", improvement))%"
            } else if improvement < 0 {
                return "\(String(format: "%.1f", improvement))%"
            } else {
                return "Same"
            }
        }
    }

    // MARK: - Exercise Progression Tracking

    /// Minimum sessions required for an exercise to show progression
    static let minimumSessionsForProgression = 3

    /// Represents progression data for a single exercise
    struct ExerciseProgression: Identifiable {
        let id = UUID()
        let exerciseName: String
        let currentE1RM: Double
        let historicalAverageE1RM: Double
        let sessionCount: Int  // How many times this exercise has been done
        let trend: ProgressionTrend
        let percentageChange: Double

        var hasEnoughData: Bool {
            sessionCount >= minimumSessionsForProgression
        }
    }

    enum ProgressionTrend {
        case improving
        case maintaining
        case declining
        case insufficientData

        var description: String {
            switch self {
            case .improving: return "Improving"
            case .maintaining: return "Steady"
            case .declining: return "Below average"
            case .insufficientData: return "Need more data"
            }
        }
    }

    /// Calculate progression for an exercise based on historical data
    static func calculateExerciseProgression(
        exerciseName: String,
        currentSets: [ParsedSet],
        from workouts: [Workout],
        excludeWorkoutId: UUID? = nil
    ) -> ExerciseProgression {
        let normalizedName = exerciseName.lowercased()

        // Find all historical sessions of this exercise
        let historicalSessions = workouts
            .filter { $0.id != excludeWorkoutId }
            .compactMap { workout -> (date: Date, e1rm: Double)? in
                guard let exercise = workout.exercises.first(where: { $0.name.lowercased() == normalizedName }),
                      !exercise.sets.isEmpty else { return nil }
                return (workout.date, E1RMCalculator.averageE1RM(for: exercise.sets))
            }
            .sorted { $0.date < $1.date }

        let sessionCount = historicalSessions.count
        let currentE1RM = E1RMCalculator.averageE1RM(for: currentSets)

        // Not enough data
        guard sessionCount >= minimumSessionsForProgression else {
            return ExerciseProgression(
                exerciseName: exerciseName,
                currentE1RM: currentE1RM,
                historicalAverageE1RM: 0,
                sessionCount: sessionCount,
                trend: .insufficientData,
                percentageChange: 0
            )
        }

        // Calculate historical average (excluding outliers - use middle 80%)
        let sortedE1RMs = historicalSessions.map { $0.e1rm }.sorted()
        let trimCount = max(1, sortedE1RMs.count / 10)  // Trim 10% from each end
        let trimmedE1RMs = Array(sortedE1RMs.dropFirst(trimCount).dropLast(trimCount))
        let historicalAverage = trimmedE1RMs.isEmpty
            ? sortedE1RMs.reduce(0, +) / Double(sortedE1RMs.count)
            : trimmedE1RMs.reduce(0, +) / Double(trimmedE1RMs.count)

        // Calculate percentage change from historical average
        let percentageChange = historicalAverage > 0
            ? ((currentE1RM - historicalAverage) / historicalAverage) * 100
            : 0

        // Determine trend (±3% is considered maintaining)
        let trend: ProgressionTrend
        if percentageChange > 3 {
            trend = .improving
        } else if percentageChange < -3 {
            trend = .declining
        } else {
            trend = .maintaining
        }

        return ExerciseProgression(
            exerciseName: exerciseName,
            currentE1RM: currentE1RM,
            historicalAverageE1RM: historicalAverage,
            sessionCount: sessionCount,
            trend: trend,
            percentageChange: percentageChange
        )
    }

    /// Calculate progressions for all exercises in current workout
    static func calculateWorkoutProgressions(
        exercises: [ParsedExercise],
        from workouts: [Workout],
        excludeWorkoutId: UUID? = nil
    ) -> [ExerciseProgression] {
        exercises
            .filter { $0.category == .weighted && !$0.sets.isEmpty }
            .map { exercise in
                calculateExerciseProgression(
                    exerciseName: exercise.name,
                    currentSets: exercise.sets,
                    from: workouts,
                    excludeWorkoutId: excludeWorkoutId
                )
            }
    }

    /// Summary of workout progression
    struct WorkoutProgressionSummary {
        let progressions: [ExerciseProgression]
        let exercisesWithEnoughData: Int
        let totalExercises: Int
        let overallTrend: ProgressionTrend
        let averagePercentageChange: Double

        var hasEnoughData: Bool {
            exercisesWithEnoughData >= 1
        }

        var dataReadinessMessage: String {
            if totalExercises == 0 {
                return "Add weighted exercises to track progression"
            } else if exercisesWithEnoughData == 0 {
                return "Keep training! Progression insights unlock after 3 sessions per exercise."
            } else {
                return "\(exercisesWithEnoughData) of \(totalExercises) exercises have progression data"
            }
        }
    }

    /// Get summary of workout progressions
    static func getWorkoutProgressionSummary(
        exercises: [ParsedExercise],
        from workouts: [Workout],
        excludeWorkoutId: UUID? = nil
    ) -> WorkoutProgressionSummary {
        let progressions = calculateWorkoutProgressions(
            exercises: exercises,
            from: workouts,
            excludeWorkoutId: excludeWorkoutId
        )

        let withEnoughData = progressions.filter { $0.hasEnoughData }
        let averageChange = withEnoughData.isEmpty
            ? 0
            : withEnoughData.map { $0.percentageChange }.reduce(0, +) / Double(withEnoughData.count)

        let overallTrend: ProgressionTrend
        if withEnoughData.isEmpty {
            overallTrend = .insufficientData
        } else if averageChange > 3 {
            overallTrend = .improving
        } else if averageChange < -3 {
            overallTrend = .declining
        } else {
            overallTrend = .maintaining
        }

        return WorkoutProgressionSummary(
            progressions: progressions,
            exercisesWithEnoughData: withEnoughData.count,
            totalExercises: progressions.count,
            overallTrend: overallTrend,
            averagePercentageChange: averageChange
        )
    }
}
