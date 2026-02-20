import Foundation
import SwiftData

/// Exercise type - weighted (track by weight), bodyweight (track by reps), or timed (track by duration)
enum ExerciseCategory: String, Codable, CaseIterable {
    case weighted
    case bodyweight
    case timed

    var displayName: String {
        switch self {
        case .weighted: return "Weighted"
        case .bodyweight: return "Bodyweight"
        case .timed: return "Timed"
        }
    }

    var trackingMetric: String {
        switch self {
        case .weighted: return "Weight"
        case .bodyweight: return "Reps"
        case .timed: return "Duration"
        }
    }
}

/// Equipment types
enum Equipment: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case cable = "Cable"
    case machine = "Machine"
    case kettlebell = "Kettlebell"
    case bodyweight = "Bodyweight"
    case resistanceBand = "Band"
    case smithMachine = "Smith Machine"
    case trapBar = "Trap Bar"
    case ezBar = "EZ Bar"
    case other = "Other"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .cable: return "cable.connector"
        case .machine: return "gearshape.fill"
        case .kettlebell: return "scalemass.fill"
        case .bodyweight: return "figure.stand"
        case .resistanceBand: return "figure.flexibility"
        case .smithMachine: return "square.stack.3d.up.fill"
        case .trapBar: return "hexagon"
        case .ezBar: return "figure.strengthtraining.traditional"
        case .other: return "questionmark.circle"
        }
    }
}

/// Muscle groups
enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case core = "Core"
    case fullBody = "Full Body"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "heart.fill"
        case .back: return "arrow.left.and.right"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "figure.wave"
        case .triceps: return "figure.wave"
        case .forearms: return "hand.raised.fill"
        case .quads: return "figure.walk"
        case .hamstrings: return "figure.walk"
        case .glutes: return "figure.walk"
        case .calves: return "figure.walk"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var categoryRaw: String?  // Stored as optional string for migration
    var equipmentRaw: String?  // Stored as optional string for migration
    var primaryMusclesRaw: String?  // Stored as comma-separated string (optional for migration)
    var notes: String?  // Notes for this exercise (optional for migration)
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

    // Computed properties with defaults for backward compatibility
    var category: ExerciseCategory {
        get { categoryRaw.flatMap { ExerciseCategory(rawValue: $0) } ?? .weighted }
        set { categoryRaw = newValue.rawValue }
    }

    var equipment: Equipment {
        get { equipmentRaw.flatMap { Equipment(rawValue: $0) } ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    // Computed property for muscle groups
    var primaryMuscles: [MuscleGroup] {
        get {
            (primaryMusclesRaw ?? "").split(separator: ",")
                .compactMap { MuscleGroup(rawValue: String($0)) }
        }
        set {
            primaryMusclesRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory = .weighted,
        equipment: Equipment = .other,
        primaryMuscles: [MuscleGroup] = [],
        notes: String = "",
        workout: Workout? = nil,
        sets: [ExerciseSet] = []
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.equipmentRaw = equipment.rawValue
        self.primaryMusclesRaw = primaryMuscles.map { $0.rawValue }.joined(separator: ",")
        self.notes = notes
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
