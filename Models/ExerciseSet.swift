import Foundation
import SwiftData

/// Represents a single set within an exercise (e.g., 10 reps at 135 lbs)
@Model
final class ExerciseSet {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var unit: WeightUnit
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int,
        weight: Double,
        unit: WeightUnit = .lbs,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.exercise = exercise
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
