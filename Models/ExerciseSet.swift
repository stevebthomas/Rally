import Foundation
import SwiftData

/// Set type variations
enum SetType: String, Codable, CaseIterable {
    case normal = "Normal"
    case warmup = "Warm-up"
    case dropSet = "Drop Set"
    case superset = "Superset"
    case restPause = "Rest-Pause"
    case amrap = "AMRAP"
    case toFailure = "To Failure"
    case cluster = "Cluster"

    var displayName: String { rawValue }
}

/// Grip variations for exercises
enum GripType: String, Codable, CaseIterable {
    case standard = "Standard"
    case wide = "Wide"
    case narrow = "Narrow"
    case underhand = "Underhand"
    case overhand = "Overhand"
    case neutral = "Neutral"
    case mixed = "Mixed"
    case reverse = "Reverse"

    var displayName: String { rawValue }
}

/// Stance variations for exercises
enum StanceType: String, Codable, CaseIterable {
    case standard = "Standard"
    case wide = "Wide"
    case narrow = "Narrow"
    case sumo = "Sumo"
    case staggered = "Staggered"
    case singleLeg = "Single Leg"

    var displayName: String { rawValue }
}

/// Represents a single set within an exercise (e.g., 10 reps at 135 lbs)
@Model
final class ExerciseSet {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var unit: WeightUnit
    var duration: Int?  // Duration in seconds (for time-based exercises like planks)
    var setType: SetType
    var exercise: Exercise?

    // Phase 2: Intensity & execution tracking
    var rpe: Int?  // Rate of Perceived Exertion (1-10 scale)
    var rir: Int?  // Reps In Reserve (how many more reps you could have done)
    var restTime: Int?  // Rest time after this set in seconds
    var tempo: String?  // Tempo notation (e.g., "3-1-2-0" = 3s eccentric, 1s pause, 2s concentric, 0s top)
    var gripTypeRaw: String?  // Stored as raw string for SwiftData
    var stanceTypeRaw: String?  // Stored as raw string for SwiftData

    // Computed properties for grip and stance
    var gripType: GripType? {
        get { gripTypeRaw.flatMap { GripType(rawValue: $0) } }
        set { gripTypeRaw = newValue?.rawValue }
    }

    var stanceType: StanceType? {
        get { stanceTypeRaw.flatMap { StanceType(rawValue: $0) } }
        set { stanceTypeRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int,
        weight: Double,
        unit: WeightUnit = .lbs,
        duration: Int? = nil,
        setType: SetType = .normal,
        exercise: Exercise? = nil,
        rpe: Int? = nil,
        rir: Int? = nil,
        restTime: Int? = nil,
        tempo: String? = nil,
        gripType: GripType? = nil,
        stanceType: StanceType? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.duration = duration
        self.setType = setType
        self.exercise = exercise
        self.rpe = rpe
        self.rir = rir
        self.restTime = restTime
        self.tempo = tempo
        self.gripTypeRaw = gripType?.rawValue
        self.stanceTypeRaw = stanceType?.rawValue
    }

    /// Calculate volume for this set (weight × reps)
    var volume: Double {
        weight * Double(reps)
    }

    /// Weight converted to pounds (for consistent comparisons)
    var weightInPounds: Double {
        switch unit {
        case .lbs:
            return weight
        case .kg:
            return weight * 2.20462
        }
    }

    /// Weight converted to kilograms
    var weightInKilograms: Double {
        switch unit {
        case .lbs:
            return weight / 2.20462
        case .kg:
            return weight
        }
    }
}

/// Weight unit enumeration
enum WeightUnit: String, Codable, CaseIterable {
    case lbs = "lbs"
    case kg = "kg"

    var displayName: String {
        rawValue
    }
}
