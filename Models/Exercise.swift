import Foundation
import SwiftData

/// Represents an exercise performed during a workout (e.g., Bench Press with multiple sets)
/// Exercise type - weighted (track by weight) or bodyweight (track by reps)
enum ExerciseCategory: String, Codable {
    case weighted
    case bodyweight

    var displayName: String {
        switch self {
        case .weighted: return "Weighted"
        case .bodyweight: return "Bodyweight"
        }
    }

    var trackingMetric: String {
        switch self {
        case .weighted: return "Weight"
        case .bodyweight: return "Reps"
        }
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory = .weighted,
        workout: Workout? = nil,
        sets: [ExerciseSet] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.workout = workout
        self.sets = sets
    }

    /// Total volume for this exercise (sum of all sets)
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    /// Total number of reps across all sets
    var totalReps: Int {
        sets.reduce(0) { $0 + $1.reps }
    }

    /// Maximum weight lifted in any set
    var maxWeight: Double {
        sets.map { $0.weight }.max() ?? 0
    }

    /// Summary string for display
    var summary: String {
        let setCount = sets.count
        if category == .bodyweight {
            return "\(setCount) set\(setCount == 1 ? "" : "s") • \(totalReps) total reps"
        } else {
            let unit = sets.first?.unit ?? .lbs
            return "\(setCount) set\(setCount == 1 ? "" : "s") • \(totalReps) reps • max \(Int(maxWeight)) \(unit.rawValue)"
        }
    }

    /// Maximum reps in any set (for bodyweight exercises)
    var maxReps: Int {
        sets.map { $0.reps }.max() ?? 0
    }

    /// Check if this is a bodyweight exercise
    var isBodyweight: Bool {
        category == .bodyweight
    }

    /// Sorted sets by set number
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }
}
