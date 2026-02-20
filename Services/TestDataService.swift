import Foundation
import SwiftData

/// Service to populate test data for development and testing
class TestDataService {
    static let shared = TestDataService()

    private init() {}

    /// Populate a week of realistic workout data
    func populateWeekOfWorkouts(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        // Day 1: Push Day (6 days ago)
        if let date = calendar.date(byAdding: .day, value: -6, to: today) {
            createPushDayWorkout(date: date, modelContext: modelContext)
        }

        // Day 2: Pull Day (5 days ago)
        if let date = calendar.date(byAdding: .day, value: -5, to: today) {
            createPullDayWorkout(date: date, modelContext: modelContext)
        }

        // Day 3: Leg Day (4 days ago)
        if let date = calendar.date(byAdding: .day, value: -4, to: today) {
            createLegDayWorkout(date: date, modelContext: modelContext)
        }

        // Day 4: Rest day (3 days ago) - no workout

        // Day 5: Upper Body (2 days ago)
        if let date = calendar.date(byAdding: .day, value: -2, to: today) {
            createUpperBodyWorkout(date: date, modelContext: modelContext)
        }

        // Day 6: Lower Body (yesterday)
        if let date = calendar.date(byAdding: .day, value: -1, to: today) {
            createLowerBodyWorkout(date: date, modelContext: modelContext)
        }

        // Day 7: Today - Full Body
        createFullBodyWorkout(date: today, modelContext: modelContext)

        // Add some historical data for progress charts (2-3 weeks back)
        addHistoricalData(modelContext: modelContext)

        try? modelContext.save()
    }

    // MARK: - Helper to create exercise with sets
    // Creates exercise and sets WITHOUT setting relationships in initializers
    // Relationships are set AFTER all objects are inserted

    private func createExercise(
        name: String,
        category: ExerciseCategory = .weighted,
        equipment: Equipment = .barbell,
        muscles: [MuscleGroup] = [],
        setsData: [(reps: Int, weight: Double)],
        modelContext: ModelContext
    ) -> Exercise {
        // Create exercise without workout relationship
        let exercise = Exercise(
            name: name,
            category: category,
            equipment: equipment,
            primaryMuscles: muscles
        )
        modelContext.insert(exercise)

        // Create sets without exercise relationship
        var sets: [ExerciseSet] = []
        for (index, data) in setsData.enumerated() {
            let set = ExerciseSet(
                setNumber: index + 1,
                reps: data.reps,
                weight: data.weight
            )
            modelContext.insert(set)
            sets.append(set)
        }

        // Now set relationships after insertion
        exercise.sets = sets

        return exercise
    }

    // MARK: - Workout Templates

    private func createPushDayWorkout(date: Date, modelContext: ModelContext) {
        let workout = Workout(date: setTime(date, hour: 7, minute: 30))
        workout.notes = "Great push session, hit a PR on bench"
        modelContext.insert(workout)

        let bench = createExercise(
            name: "Bench Press",
            equipment: .barbell,
            muscles: [.chest, .triceps],
            setsData: [(10, 135), (8, 155), (6, 185), (4, 205)],
            modelContext: modelContext
        )

        let incline = createExercise(
            name: "Incline Dumbbell Press",
            equipment: .dumbbell,
            muscles: [.chest, .shoulders],
            setsData: [(12, 50), (10, 55), (8, 60)],
            modelContext: modelContext
        )

        let ohp = createExercise(
            name: "Overhead Press",
            equipment: .barbell,
            muscles: [.shoulders],
            setsData: [(10, 85), (8, 95), (6, 105)],
            modelContext: modelContext
        )

        let pushdowns = createExercise(
            name: "Tricep Pushdowns",
            equipment: .cable,
            muscles: [.triceps],
            setsData: [(15, 40), (12, 50), (10, 60)],
            modelContext: modelContext
        )

        workout.exercises = [bench, incline, ohp, pushdowns]
    }

    private func createPullDayWorkout(date: Date, modelContext: ModelContext) {
        let workout = Workout(date: setTime(date, hour: 18, minute: 15))
        workout.notes = "Evening pull session"
        modelContext.insert(workout)

        let deadlift = createExercise(
            name: "Deadlift",
            equipment: .barbell,
            muscles: [.back, .hamstrings, .glutes],
            setsData: [(8, 185), (6, 225), (5, 275), (3, 315)],
            modelContext: modelContext
        )

        let rows = createExercise(
            name: "Barbell Rows",
            equipment: .barbell,
            muscles: [.back, .biceps],
            setsData: [(10, 135), (8, 155), (6, 175)],
            modelContext: modelContext
        )

        let pullups = createExercise(
            name: "Pull-ups",
            category: .bodyweight,
            equipment: .bodyweight,
            muscles: [.back, .biceps],
            setsData: [(12, 0), (10, 0), (8, 0)],
            modelContext: modelContext
        )

        let curls = createExercise(
            name: "Bicep Curls",
            equipment: .dumbbell,
            muscles: [.biceps],
            setsData: [(12, 25), (10, 30), (8, 35)],
            modelContext: modelContext
        )

        workout.exercises = [deadlift, rows, pullups, curls]
    }

    private func createLegDayWorkout(date: Date, modelContext: ModelContext) {
        let workout = Workout(date: setTime(date, hour: 6, minute: 45))
        workout.notes = "Early morning leg session"
        modelContext.insert(workout)

        let squats = createExercise(
            name: "Squats",
            equipment: .barbell,
            muscles: [.quads, .glutes],
            setsData: [(10, 135), (8, 185), (6, 225), (4, 255)],
            modelContext: modelContext
        )

        let rdl = createExercise(
            name: "Romanian Deadlift",
            equipment: .barbell,
            muscles: [.hamstrings, .glutes],
            setsData: [(12, 135), (10, 155), (8, 175)],
            modelContext: modelContext
        )

        let legPress = createExercise(
            name: "Leg Press",
            equipment: .machine,
            muscles: [.quads],
            setsData: [(12, 270), (10, 360), (8, 450)],
            modelContext: modelContext
        )

        let calves = createExercise(
            name: "Calf Raises",
            equipment: .machine,
            muscles: [.calves],
            setsData: [(15, 90), (12, 110), (10, 130)],
            modelContext: modelContext
        )

        workout.exercises = [squats, rdl, legPress, calves]
    }

    private func createUpperBodyWorkout(date: Date, modelContext: ModelContext) {
        let workout = Workout(date: setTime(date, hour: 17, minute: 0))
        modelContext.insert(workout)

        let dbPress = createExercise(
            name: "Dumbbell Press",
            equipment: .dumbbell,
            muscles: [.chest],
            setsData: [(10, 60), (8, 70), (6, 80)],
            modelContext: modelContext
        )

        let cableRows = createExercise(
            name: "Cable Rows",
            equipment: .cable,
            muscles: [.back],
            setsData: [(12, 100), (10, 120), (8, 140)],
            modelContext: modelContext
        )

        let laterals = createExercise(
            name: "Lateral Raises",
            equipment: .dumbbell,
            muscles: [.shoulders],
            setsData: [(15, 15), (12, 20), (10, 25)],
            modelContext: modelContext
        )

        let facePulls = createExercise(
            name: "Face Pulls",
            equipment: .cable,
            muscles: [.shoulders, .back],
            setsData: [(15, 30), (12, 40), (10, 50)],
            modelContext: modelContext
        )

        workout.exercises = [dbPress, cableRows, laterals, facePulls]
    }

    private func createLowerBodyWorkout(date: Date, modelContext: ModelContext) {
        let workout = Workout(date: setTime(date, hour: 8, minute: 0))
        modelContext.insert(workout)

        let frontSquats = createExercise(
            name: "Front Squats",
            equipment: .barbell,
            muscles: [.quads],
            setsData: [(8, 115), (6, 135), (5, 155)],
            modelContext: modelContext
        )

        let hipThrusts = createExercise(
            name: "Hip Thrusts",
            equipment: .barbell,
            muscles: [.glutes],
            setsData: [(12, 135), (10, 185), (8, 225)],
            modelContext: modelContext
        )

        let legCurls = createExercise(
            name: "Leg Curls",
            equipment: .machine,
            muscles: [.hamstrings],
            setsData: [(12, 60), (10, 70), (8, 80)],
            modelContext: modelContext
        )

        let lunges = createExercise(
            name: "Lunges",
            equipment: .dumbbell,
            muscles: [.quads, .glutes],
            setsData: [(12, 30), (10, 35), (8, 40)],
            modelContext: modelContext
        )

        workout.exercises = [frontSquats, hipThrusts, legCurls, lunges]
    }

    private func createFullBodyWorkout(date: Date, modelContext: ModelContext) {
        let workout = Workout(date: setTime(date, hour: 10, minute: 30))
        workout.notes = "Full body pump session"
        modelContext.insert(workout)

        let bench = createExercise(
            name: "Bench Press",
            equipment: .barbell,
            muscles: [.chest, .triceps],
            setsData: [(8, 155), (6, 175), (5, 195)],
            modelContext: modelContext
        )

        let squats = createExercise(
            name: "Squats",
            equipment: .barbell,
            muscles: [.quads, .glutes],
            setsData: [(8, 185), (6, 205), (5, 225)],
            modelContext: modelContext
        )

        let dbRows = createExercise(
            name: "Dumbbell Rows",
            equipment: .dumbbell,
            muscles: [.back],
            setsData: [(10, 55), (8, 65), (6, 75)],
            modelContext: modelContext
        )

        let pushups = createExercise(
            name: "Push-ups",
            category: .bodyweight,
            equipment: .bodyweight,
            muscles: [.chest, .triceps],
            setsData: [(20, 0), (15, 0)],
            modelContext: modelContext
        )

        workout.exercises = [bench, squats, dbRows, pushups]
    }

    // MARK: - Historical Data for Progress Charts

    private func addHistoricalData(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        // 2 weeks ago - Push day
        if let date = calendar.date(byAdding: .day, value: -13, to: today) {
            let workout = Workout(date: setTime(date, hour: 7, minute: 0))
            modelContext.insert(workout)

            let bench = createExercise(
                name: "Bench Press",
                equipment: .barbell,
                muscles: [.chest],
                setsData: [(10, 125), (8, 145), (6, 165)],
                modelContext: modelContext
            )

            let squats = createExercise(
                name: "Squats",
                equipment: .barbell,
                muscles: [.quads],
                setsData: [(10, 135), (8, 165), (6, 195)],
                modelContext: modelContext
            )

            workout.exercises = [bench, squats]
        }

        // 10 days ago
        if let date = calendar.date(byAdding: .day, value: -10, to: today) {
            let workout = Workout(date: setTime(date, hour: 18, minute: 30))
            modelContext.insert(workout)

            let deadlift = createExercise(
                name: "Deadlift",
                equipment: .barbell,
                muscles: [.back],
                setsData: [(8, 175), (6, 205), (4, 245)],
                modelContext: modelContext
            )

            let bench = createExercise(
                name: "Bench Press",
                equipment: .barbell,
                muscles: [.chest],
                setsData: [(8, 135), (6, 155), (5, 175)],
                modelContext: modelContext
            )

            workout.exercises = [deadlift, bench]
        }

        // 8 days ago
        if let date = calendar.date(byAdding: .day, value: -8, to: today) {
            let workout = Workout(date: setTime(date, hour: 9, minute: 0))
            modelContext.insert(workout)

            let squats = createExercise(
                name: "Squats",
                equipment: .barbell,
                muscles: [.quads],
                setsData: [(8, 155), (6, 185), (5, 215)],
                modelContext: modelContext
            )

            let ohp = createExercise(
                name: "Overhead Press",
                equipment: .barbell,
                muscles: [.shoulders],
                setsData: [(10, 75), (8, 85), (6, 95)],
                modelContext: modelContext
            )

            workout.exercises = [squats, ohp]
        }
    }

    // MARK: - Helper Methods

    private func setTime(_ date: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? date
    }

    func clearAllWorkouts(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: Workout.self)
            try modelContext.save()
        } catch {
            print("Failed to clear workouts: \(error)")
        }
    }
}
