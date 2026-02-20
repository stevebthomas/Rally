import Foundation

/// Severity levels for validation issues
enum ValidationSeverity: String, Codable {
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// Represents a validation issue found during workout validation
struct ValidationIssue: Identifiable {
    let id = UUID()
    let code: String
    let severity: ValidationSeverity
    let message: String
    let exerciseName: String
    let setNumber: Int?

    init(code: String, severity: ValidationSeverity, message: String, exerciseName: String, setNumber: Int? = nil) {
        self.code = code
        self.severity = severity
        self.message = message
        self.exerciseName = exerciseName
        self.setNumber = setNumber
    }
}

/// Service for validating workout data and detecting potential issues
class WorkoutValidationService {
    static let shared = WorkoutValidationService()
    private let equipmentService = EquipmentService.shared

    private init() {}

    /// Validate a single parsed exercise and its sets
    /// - Parameter exercise: The exercise to validate
    /// - Returns: Array of validation issues found
    func validate(exercise: ParsedExercise) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Only validate weighted exercises
        guard exercise.category == .weighted else {
            return issues
        }

        for (index, set) in exercise.sets.enumerated() {
            let setNumber = index + 1

            // WV001: Weighted exercise with barbell-type equipment at 0 lbs
            if equipmentService.hasBaseWeight(exercise.equipment) && set.weight == 0 {
                let baseWeight = Int(equipmentService.baseWeight(for: exercise.equipment))
                issues.append(ValidationIssue(
                    code: "WV001",
                    severity: .warning,
                    message: "\(exercise.equipment.displayName) weighs \(baseWeight) lbs. Add plate weight?",
                    exerciseName: exercise.name,
                    setNumber: setNumber
                ))
            }

            // WV002: Weight exceeds 1000 lbs (likely an error)
            if set.weight > 1000 {
                issues.append(ValidationIssue(
                    code: "WV002",
                    severity: .warning,
                    message: "This weight seems high (\(Int(set.weight)) \(set.unit.rawValue)). Please verify.",
                    exerciseName: exercise.name,
                    setNumber: setNumber
                ))
            }

            // WV003: Weight is less than equipment base weight (impossible)
            if equipmentService.hasBaseWeight(exercise.equipment) {
                let baseWeight = equipmentService.baseWeight(for: exercise.equipment, unit: set.unit)
                if set.weight > 0 && set.weight < baseWeight {
                    issues.append(ValidationIssue(
                        code: "WV003",
                        severity: .error,
                        message: "Weight can't be less than \(exercise.equipment.displayName.lowercased()) weight (\(Int(baseWeight)) \(set.unit.rawValue))",
                        exerciseName: exercise.name,
                        setNumber: setNumber
                    ))
                }
            }
        }

        // Deduplicate issues with same code for this exercise
        // (only keep first occurrence for cleaner UI)
        var seenCodes: Set<String> = []
        issues = issues.filter { issue in
            if seenCodes.contains(issue.code) {
                return false
            }
            seenCodes.insert(issue.code)
            return true
        }

        return issues
    }

    /// Validate all exercises in a workout
    /// - Parameter exercises: Array of parsed exercises
    /// - Returns: Array of all validation issues found
    func validateAll(exercises: [ParsedExercise]) -> [ValidationIssue] {
        exercises.flatMap { validate(exercise: $0) }
    }

    /// Check if an exercise has any validation issues
    /// - Parameter exercise: The exercise to check
    /// - Returns: True if there are any issues
    func hasIssues(exercise: ParsedExercise) -> Bool {
        !validate(exercise: exercise).isEmpty
    }

    /// Get the most severe issue for an exercise
    /// - Parameter exercise: The exercise to check
    /// - Returns: The most severe issue, if any
    func mostSevereIssue(for exercise: ParsedExercise) -> ValidationIssue? {
        let issues = validate(exercise: exercise)
        // Error > Warning > Info
        return issues.first { $0.severity == .error }
            ?? issues.first { $0.severity == .warning }
            ?? issues.first
    }
}
