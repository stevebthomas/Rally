import Foundation

/// Service for equipment-related calculations and lookups
class EquipmentService {
    static let shared = EquipmentService()

    private init() {}

    /// Base weights for equipment types (in lbs)
    private let baseWeightsLbs: [Equipment: Double] = [
        .barbell: 45,
        .ezBar: 25,
        .trapBar: 45,
        .smithMachine: 20
    ]

    /// Get the base weight for a piece of equipment
    /// - Parameters:
    ///   - equipment: The equipment type
    ///   - unit: The weight unit to return (defaults to lbs)
    /// - Returns: The base weight in the specified unit
    func baseWeight(for equipment: Equipment, unit: WeightUnit = .lbs) -> Double {
        guard let weightLbs = baseWeightsLbs[equipment] else {
            return 0
        }

        switch unit {
        case .lbs:
            return weightLbs
        case .kg:
            return weightLbs / 2.20462
        }
    }

    /// Check if equipment has a base weight
    /// - Parameter equipment: The equipment type to check
    /// - Returns: True if the equipment has a non-zero base weight
    func hasBaseWeight(_ equipment: Equipment) -> Bool {
        baseWeightsLbs[equipment] != nil
    }

    /// Get all equipment types that have base weights
    var equipmentWithBaseWeights: [Equipment] {
        Array(baseWeightsLbs.keys)
    }

    /// Get a formatted description of the base weight
    /// - Parameters:
    ///   - equipment: The equipment type
    ///   - unit: The weight unit (defaults to lbs)
    /// - Returns: A formatted string like "45 lbs" or nil if no base weight
    func baseWeightDescription(for equipment: Equipment, unit: WeightUnit = .lbs) -> String? {
        guard hasBaseWeight(equipment) else { return nil }
        let weight = baseWeight(for: equipment, unit: unit)
        return "\(Int(weight)) \(unit.rawValue)"
    }
}
