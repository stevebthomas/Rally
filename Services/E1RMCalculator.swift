import Foundation

/// Calculates Estimated 1 Rep Max (E1RM) using the Epley formula
/// E1RM = weight × (1 + reps/30)
struct E1RMCalculator {

    /// Calculate E1RM for a given weight and rep count
    /// - Parameters:
    ///   - weight: The weight lifted
    ///   - reps: Number of reps performed
    /// - Returns: Estimated 1 Rep Max, or the weight itself if reps <= 1
    static func calculate(weight: Double, reps: Int) -> Double {
        guard reps > 1 else { return weight }
        // Epley formula: E1RM = weight × (1 + reps/30)
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Calculate E1RM for an ExerciseSet
    static func calculate(for set: ExerciseSet) -> Double {
        calculate(weight: set.weightInPounds, reps: set.reps)
    }

    /// Calculate E1RM for a ParsedSet
    static func calculate(for set: ParsedSet) -> Double {
        let weightInLbs = set.unit == .kg ? set.weight * 2.20462 : set.weight
        return calculate(weight: weightInLbs, reps: set.reps)
    }

    /// Calculate average E1RM across multiple sets
    static func averageE1RM(for sets: [ExerciseSet]) -> Double {
        guard !sets.isEmpty else { return 0 }
        let total = sets.reduce(0.0) { $0 + calculate(for: $1) }
        return total / Double(sets.count)
    }

    /// Calculate average E1RM across parsed sets
    static func averageE1RM(for sets: [ParsedSet]) -> Double {
        guard !sets.isEmpty else { return 0 }
        let total = sets.reduce(0.0) { $0 + calculate(for: $1) }
        return total / Double(sets.count)
    }

    /// Calculate session strength score (average E1RM across all exercises)
    static func sessionStrengthScore(for exercises: [Exercise]) -> Double {
        let weightedExercises = exercises.filter { $0.category == .weighted && !$0.sets.isEmpty }
        guard !weightedExercises.isEmpty else { return 0 }

        let totalE1RM = weightedExercises.reduce(0.0) { total, exercise in
            total + averageE1RM(for: exercise.sets)
        }
        return totalE1RM / Double(weightedExercises.count)
    }

    /// Calculate session strength score for parsed exercises
    static func sessionStrengthScore(for exercises: [ParsedExercise]) -> Double {
        let weightedExercises = exercises.filter { $0.category == .weighted && !$0.sets.isEmpty }
        guard !weightedExercises.isEmpty else { return 0 }

        let totalE1RM = weightedExercises.reduce(0.0) { total, exercise in
            total + averageE1RM(for: exercise.sets)
        }
        return totalE1RM / Double(weightedExercises.count)
    }

    /// Compare two E1RMs and return percentage improvement
    static func improvement(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }

    /// Check if current E1RM is a personal best compared to previous
    static func isPersonalBest(current: Double, previous: Double, threshold: Double = 0) -> Bool {
        current > previous + threshold
    }
}
