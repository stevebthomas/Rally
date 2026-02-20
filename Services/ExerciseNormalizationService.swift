import Foundation

/// Confidence level for exercise name matching
enum MatchConfidence: String, Codable {
    case exact       // Exact match from alias dictionary
    case fuzzy       // Close match via Levenshtein distance
    case unrecognized // No good match found
}

/// Result of normalizing an exercise name
struct NormalizationResult {
    let canonicalName: String?
    let confidence: MatchConfidence
    let suggestions: [String]  // For unrecognized, show close matches
    let originalInput: String

    var isRecognized: Bool {
        confidence != .unrecognized
    }
}

/// Service for normalizing exercise names to canonical forms
/// Uses the exercise aliases from OfflineWorkoutParser and adds fuzzy matching
class ExerciseNormalizationService {
    static let shared = ExerciseNormalizationService()

    /// Maximum Levenshtein distance for fuzzy matching
    private let fuzzyMatchThreshold = 3

    /// Common exercise name variations mapped to canonical names
    /// Sourced from OfflineWorkoutParser.exerciseAliases
    private let exerciseAliases: [String: String] = [
        // CHEST
        "bench press": "Bench Press",
        "bench": "Bench Press",
        "flat bench": "Bench Press",
        "flat bench press": "Bench Press",
        "barbell bench press": "Bench Press",
        "barbell bench": "Bench Press",
        "incline bench": "Incline Bench Press",
        "incline bench press": "Incline Bench Press",
        "incline press": "Incline Press",
        "incline dumbbell press": "Incline Dumbbell Press",
        "decline bench": "Decline Bench Press",
        "decline bench press": "Decline Bench Press",
        "dumbbell press": "Dumbbell Press",
        "db press": "Dumbbell Press",
        "chest press": "Chest Press",
        "push ups": "Push Ups",
        "push-ups": "Push Ups",
        "pushups": "Push Ups",

        // BACK
        "deadlift": "Deadlift",
        "deadlifts": "Deadlift",
        "dead lift": "Deadlift",
        "romanian deadlift": "Romanian Deadlift",
        "rdl": "Romanian Deadlift",
        "rdls": "Romanian Deadlift",
        "pull ups": "Pull Ups",
        "pull-ups": "Pull Ups",
        "pullups": "Pull Ups",
        "chin ups": "Chin Ups",
        "chin-ups": "Chin Ups",
        "chinups": "Chin Ups",
        "lat pulldown": "Lat Pulldown",
        "lat pull down": "Lat Pulldown",
        "pulldown": "Lat Pulldown",
        "seated cable row": "Seated Cable Row",
        "seated row": "Seated Cable Row",
        "cable row": "Cable Row",
        "barbell row": "Barbell Row",
        "bent over row": "Bent Over Row",
        "dumbbell row": "Dumbbell Row",
        "db row": "Dumbbell Row",
        "t-bar row": "T-Bar Row",
        "t bar row": "T-Bar Row",
        "face pull": "Face Pulls",
        "face pulls": "Face Pulls",

        // SHOULDERS
        "shoulder press": "Shoulder Press",
        "overhead press": "Overhead Press",
        "ohp": "Overhead Press",
        "military press": "Military Press",
        "lateral raise": "Lateral Raises",
        "lateral raises": "Lateral Raises",
        "side raise": "Lateral Raises",
        "front raise": "Front Raises",
        "front raises": "Front Raises",
        "shrugs": "Shrugs",
        "shrug": "Shrugs",

        // LEGS
        "squat": "Squats",
        "squats": "Squats",
        "back squat": "Back Squat",
        "front squat": "Front Squat",
        "goblet squat": "Goblet Squat",
        "leg press": "Leg Press",
        "lunges": "Lunges",
        "lunge": "Lunges",
        "leg extension": "Leg Extensions",
        "leg extensions": "Leg Extensions",
        "leg curl": "Leg Curls",
        "leg curls": "Leg Curls",
        "calf raise": "Calf Raises",
        "calf raises": "Calf Raises",
        "hip thrust": "Hip Thrusts",
        "hip thrusts": "Hip Thrusts",

        // ARMS
        "bicep curl": "Bicep Curls",
        "bicep curls": "Bicep Curls",
        "curls": "Bicep Curls",
        "curl": "Bicep Curls",
        "dumbbell curl": "Dumbbell Curls",
        "barbell curl": "Barbell Curls",
        "hammer curl": "Hammer Curls",
        "hammer curls": "Hammer Curls",
        "preacher curl": "Preacher Curls",
        "tricep extension": "Tricep Extensions",
        "tricep extensions": "Tricep Extensions",
        "tricep pushdown": "Tricep Pushdowns",
        "pushdown": "Tricep Pushdowns",
        "pushdowns": "Tricep Pushdowns",
        "skull crusher": "Skull Crushers",
        "skull crushers": "Skull Crushers",
        "dips": "Dips",

        // CORE
        "plank": "Plank",
        "planks": "Plank",
        "crunch": "Crunches",
        "crunches": "Crunches",
        "sit ups": "Sit Ups",
        "sit-ups": "Sit Ups",
        "situps": "Sit Ups",
        "hanging leg raise": "Hanging Leg Raises",
        "russian twist": "Russian Twists",
        "ab wheel": "Ab Wheel Rollout",
    ]

    /// All canonical exercise names (for fuzzy matching suggestions)
    private lazy var canonicalNames: Set<String> = {
        Set(exerciseAliases.values)
    }()

    private init() {}

    /// Normalize an exercise name to its canonical form
    /// - Parameter input: The exercise name to normalize
    /// - Returns: Normalization result with canonical name and confidence
    func normalize(_ input: String) -> NormalizationResult {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for exact alias match
        if let canonical = exerciseAliases[lowercased] {
            return NormalizationResult(
                canonicalName: canonical,
                confidence: .exact,
                suggestions: [],
                originalInput: input
            )
        }

        // Check if input is already a canonical name
        if canonicalNames.contains(input) {
            return NormalizationResult(
                canonicalName: input,
                confidence: .exact,
                suggestions: [],
                originalInput: input
            )
        }

        // Try fuzzy matching against all aliases
        var bestMatch: (alias: String, canonical: String, distance: Int)?

        for (alias, canonical) in exerciseAliases {
            let distance = levenshteinDistance(lowercased, alias)
            if distance <= fuzzyMatchThreshold {
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (alias, canonical, distance)
                }
            }
        }

        if let match = bestMatch {
            return NormalizationResult(
                canonicalName: match.canonical,
                confidence: .fuzzy,
                suggestions: [],
                originalInput: input
            )
        }

        // No match found - provide suggestions
        let suggestions = findClosestMatches(to: lowercased, limit: 3)
        return NormalizationResult(
            canonicalName: nil,
            confidence: .unrecognized,
            suggestions: suggestions,
            originalInput: input
        )
    }

    /// Find the closest matching canonical names
    /// - Parameters:
    ///   - input: The input string
    ///   - limit: Maximum number of suggestions
    /// - Returns: Array of suggested canonical names
    private func findClosestMatches(to input: String, limit: Int) -> [String] {
        var matches: [(name: String, distance: Int)] = []

        for canonical in canonicalNames {
            let distance = levenshteinDistance(input, canonical.lowercased())
            matches.append((canonical, distance))
        }

        return matches
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0.name }
    }

    /// Calculate Levenshtein distance between two strings
    /// - Parameters:
    ///   - s1: First string
    ///   - s2: Second string
    /// - Returns: The edit distance between the strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        // Early exit for empty strings
        if m == 0 { return n }
        if n == 0 { return m }

        // Create distance matrix
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        // Initialize first row and column
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        // Fill in the rest of the matrix
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }

        return matrix[m][n]
    }

    /// Check if an exercise name is recognized (exact or fuzzy match)
    func isRecognized(_ name: String) -> Bool {
        normalize(name).isRecognized
    }

    /// Get the canonical name for an exercise, or nil if not recognized
    func canonicalName(for input: String) -> String? {
        normalize(input).canonicalName
    }
}
