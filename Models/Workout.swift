import Foundation
import SwiftData

/// Represents a complete workout session containing multiple exercises
@Model
final class Workout {
    var id: UUID
    var date: Date
    var notes: String?
    var rawTranscription: String?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutMedia.workout)
    var media: [WorkoutMedia]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        notes: String? = nil,
        rawTranscription: String? = nil,
        exercises: [Exercise] = [],
        media: [WorkoutMedia] = []
    ) {
        self.id = id
        self.date = date
        self.notes = notes
        self.rawTranscription = rawTranscription
        self.exercises = exercises
        self.media = media
    }

    /// Number of media items attached
    var mediaCount: Int {
        media.count
    }

    /// Check if workout has any media
    var hasMedia: Bool {
        !media.isEmpty
    }

    /// Total volume for the entire workout
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    /// Total number of sets across all exercises
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    /// Total number of reps across all exercises
    var totalReps: Int {
        exercises.reduce(0) { $0 + $1.totalReps }
    }

    /// Number of exercises in this workout
    var exerciseCount: Int {
        exercises.count
    }

    /// Formatted date string for display
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Formatted time string for display
    var formattedTime: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Summary string for list display
    var summary: String {
        "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") • \(totalSets) sets • \(Int(totalVolume)) lbs volume"
    }

    /// Check if this workout contains a specific exercise
    func containsExercise(named name: String) -> Bool {
        exercises.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// Get exercise by name
    func exercise(named name: String) -> Exercise? {
        exercises.first { $0.name.lowercased() == name.lowercased() }
    }
}

// MARK: - Sample Data for Previews

extension Workout {
    static var sampleWorkout: Workout {
        let workout = Workout(date: Date())

        let benchPress = Exercise(name: "Bench Press", workout: workout)
        benchPress.sets = [
            ExerciseSet(setNumber: 1, reps: 10, weight: 135, exercise: benchPress),
            ExerciseSet(setNumber: 2, reps: 8, weight: 155, exercise: benchPress),
            ExerciseSet(setNumber: 3, reps: 6, weight: 175, exercise: benchPress)
        ]

        let squats = Exercise(name: "Squats", workout: workout)
        squats.sets = [
            ExerciseSet(setNumber: 1, reps: 10, weight: 185, exercise: squats),
            ExerciseSet(setNumber: 2, reps: 8, weight: 205, exercise: squats),
            ExerciseSet(setNumber: 3, reps: 6, weight: 225, exercise: squats)
        ]

        workout.exercises = [benchPress, squats]
        return workout
    }

    static var sampleWorkouts: [Workout] {
        let calendar = Calendar.current
        var workouts: [Workout] = []

        for dayOffset in [0, 2, 4, 7, 9, 11, 14] {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            let workout = Workout(date: date)
            let baseWeight = 135.0 + Double(14 - dayOffset) * 2.5

            let benchPress = Exercise(name: "Bench Press", workout: workout)
            benchPress.sets = [
                ExerciseSet(setNumber: 1, reps: 10, weight: baseWeight, exercise: benchPress),
                ExerciseSet(setNumber: 2, reps: 8, weight: baseWeight + 20, exercise: benchPress),
                ExerciseSet(setNumber: 3, reps: 6, weight: baseWeight + 40, exercise: benchPress)
            ]

            workout.exercises = [benchPress]
            workouts.append(workout)
        }

        return workouts
    }
}
