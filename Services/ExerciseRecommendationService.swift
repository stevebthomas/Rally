import Foundation
import SwiftData

/// Service for recommending exercises based on current workout and history
class ExerciseRecommendationService {
    static let shared = ExerciseRecommendationService()

    // Exercise database organized by muscle group
    private let exercisesByMuscle: [MuscleGroup: [String]] = [
        .chest: [
            "Bench Press", "Incline Bench Press", "Decline Bench Press",
            "Dumbbell Press", "Incline Dumbbell Press", "Dumbbell Flyes",
            "Cable Crossover", "Pec Deck Fly", "Push Ups", "Chest Dips"
        ],
        .back: [
            "Deadlift", "Pull Ups", "Chin Ups", "Lat Pulldown", "Barbell Row",
            "Dumbbell Row", "Cable Row", "Seated Cable Row", "T-Bar Row",
            "Face Pulls", "Back Extensions"
        ],
        .shoulders: [
            "Shoulder Press", "Overhead Press", "Dumbbell Shoulder Press",
            "Arnold Press", "Lateral Raises", "Front Raises", "Rear Delt Flyes",
            "Upright Row", "Shrugs", "Face Pulls"
        ],
        .biceps: [
            "Bicep Curls", "Barbell Curls", "Dumbbell Curls", "Hammer Curls",
            "Preacher Curls", "Concentration Curls", "Cable Curls",
            "Incline Curls", "Spider Curls", "EZ Bar Curls"
        ],
        .triceps: [
            "Tricep Extensions", "Tricep Pushdowns", "Skull Crushers",
            "Close Grip Bench Press", "Overhead Tricep Extensions",
            "Tricep Dips", "Bench Dips", "Tricep Kickbacks", "Rope Pushdowns"
        ],
        .forearms: [
            "Wrist Curls", "Reverse Wrist Curls", "Farmer's Walk",
            "Dead Hang", "Plate Pinch", "Hammer Curls", "Reverse Curls"
        ],
        .quads: [
            "Squats", "Front Squat", "Leg Press", "Lunges", "Walking Lunges",
            "Leg Extensions", "Hack Squat", "Goblet Squat", "Bulgarian Split Squat"
        ],
        .hamstrings: [
            "Romanian Deadlift", "Leg Curls", "Stiff Leg Deadlift",
            "Good Mornings", "Nordic Curls", "Hip Thrusts"
        ],
        .glutes: [
            "Hip Thrusts", "Glute Bridge", "Romanian Deadlift", "Squats",
            "Lunges", "Bulgarian Split Squat", "Step Ups", "Cable Kickbacks"
        ],
        .calves: [
            "Calf Raises", "Standing Calf Raises", "Seated Calf Raises",
            "Donkey Calf Raises"
        ],
        .core: [
            "Plank", "Crunches", "Sit Ups", "Hanging Leg Raises",
            "Russian Twists", "Ab Wheel Rollout", "Cable Crunches",
            "Dead Bug", "Mountain Climbers", "Side Plank"
        ],
        .fullBody: [
            "Burpees", "Kettlebell Swings", "Thrusters", "Clean and Press",
            "Turkish Get Up", "Battle Ropes"
        ]
    ]

    // Map exercise names to their primary muscle groups
    private let exerciseMuscleMap: [String: [MuscleGroup]] = [
        "Bench Press": [.chest, .triceps, .shoulders],
        "Incline Bench Press": [.chest, .shoulders],
        "Squats": [.quads, .glutes, .hamstrings],
        "Back Squat": [.quads, .glutes, .hamstrings],
        "Deadlift": [.back, .hamstrings, .glutes],
        "Romanian Deadlift": [.hamstrings, .glutes, .back],
        "Pull Ups": [.back, .biceps],
        "Lat Pulldown": [.back, .biceps],
        "Shoulder Press": [.shoulders, .triceps],
        "Bicep Curls": [.biceps],
        "Tricep Extensions": [.triceps],
        "Leg Press": [.quads, .glutes],
        "Lunges": [.quads, .glutes],
        "Calf Raises": [.calves],
        "Hip Thrusts": [.glutes, .hamstrings],
        "Plank": [.core],
        "Barbell Row": [.back, .biceps],
        "Dumbbell Row": [.back, .biceps],
        "Cable Row": [.back, .biceps],
        "Face Pulls": [.shoulders, .back],
        "Lateral Raises": [.shoulders],
        "Leg Curls": [.hamstrings],
        "Leg Extensions": [.quads],
    ]

    private init() {}

    /// Get exercise recommendations based on current exercises in the session
    func getRecommendations(
        currentExercises: [ParsedExercise],
        recentWorkouts: [Workout] = [],
        limit: Int = 5
    ) -> [ExerciseRecommendation] {
        var recommendations: [ExerciseRecommendation] = []
        var addedExercises: Set<String> = Set(currentExercises.map { $0.name })

        // Get muscle groups from current exercises
        let currentMuscles = getCurrentMuscleGroups(from: currentExercises)

        // 1. Recommend exercises from same muscle groups (complementary)
        for muscle in currentMuscles {
            if let exercises = exercisesByMuscle[muscle] {
                for exercise in exercises {
                    if !addedExercises.contains(exercise) {
                        recommendations.append(ExerciseRecommendation(
                            name: exercise,
                            reason: "Works your \(muscle.displayName.lowercased())",
                            type: .complementary
                        ))
                        addedExercises.insert(exercise)
                    }
                }
            }
        }

        // 2. Add frequently used exercises from history
        let frequentExercises = getFrequentExercises(from: recentWorkouts)
        for (exerciseName, count) in frequentExercises.prefix(10) {
            if !addedExercises.contains(exerciseName) {
                recommendations.append(ExerciseRecommendation(
                    name: exerciseName,
                    reason: "You've done this \(count) times",
                    type: .frequent
                ))
                addedExercises.insert(exerciseName)
            }
        }

        // 3. Add some variety suggestions (different muscle groups)
        let unusedMuscles = Set(MuscleGroup.allCases).subtracting(currentMuscles)
        for muscle in unusedMuscles.prefix(2) {
            if let exercises = exercisesByMuscle[muscle], let exercise = exercises.randomElement() {
                if !addedExercises.contains(exercise) {
                    recommendations.append(ExerciseRecommendation(
                        name: exercise,
                        reason: "Try some \(muscle.displayName.lowercased()) work",
                        type: .variety
                    ))
                    addedExercises.insert(exercise)
                }
            }
        }

        // Shuffle and limit
        return Array(recommendations.shuffled().prefix(limit))
    }

    /// Get recommendations based on a single exercise (quick suggestions)
    func getQuickRecommendations(forExercise exerciseName: String, excluding: [String] = []) -> [ExerciseRecommendation] {
        var recommendations: [ExerciseRecommendation] = []
        var addedExercises = Set(excluding)
        addedExercises.insert(exerciseName)

        // Find muscle groups for this exercise
        let muscles = getMuscleGroups(for: exerciseName)

        // Get related exercises from same muscle groups
        for muscle in muscles {
            if let exercises = exercisesByMuscle[muscle] {
                for exercise in exercises.prefix(3) {
                    if !addedExercises.contains(exercise) {
                        recommendations.append(ExerciseRecommendation(
                            name: exercise,
                            reason: "Also targets \(muscle.displayName.lowercased())",
                            type: .complementary
                        ))
                        addedExercises.insert(exercise)
                    }
                }
            }
        }

        return Array(recommendations.prefix(4))
    }

    private func getCurrentMuscleGroups(from exercises: [ParsedExercise]) -> Set<MuscleGroup> {
        var muscles = Set<MuscleGroup>()
        for exercise in exercises {
            // First check primary muscles from the parsed exercise
            muscles.formUnion(exercise.primaryMuscles)
            // Also check our map
            if let mapped = exerciseMuscleMap[exercise.name] {
                muscles.formUnion(mapped)
            }
        }
        return muscles
    }

    private func getMuscleGroups(for exerciseName: String) -> [MuscleGroup] {
        if let muscles = exerciseMuscleMap[exerciseName] {
            return muscles
        }

        // Fallback: search through exercisesByMuscle
        for (muscle, exercises) in exercisesByMuscle {
            if exercises.contains(exerciseName) {
                return [muscle]
            }
        }

        return []
    }

    private func getFrequentExercises(from workouts: [Workout]) -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                counts[exercise.name, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
}

// MARK: - Data Types

struct ExerciseRecommendation: Identifiable {
    let id = UUID()
    let name: String
    let reason: String
    let type: RecommendationType

    enum RecommendationType {
        case complementary  // Same muscle group
        case frequent       // Frequently used
        case variety        // Different muscle group for variety
    }

    var icon: String {
        switch type {
        case .complementary: return "figure.strengthtraining.traditional"
        case .frequent: return "star.fill"
        case .variety: return "sparkles"
        }
    }

    var iconColor: String {
        switch type {
        case .complementary: return "rallyOrange"
        case .frequent: return "yellow"
        case .variety: return "purple"
        }
    }
}
