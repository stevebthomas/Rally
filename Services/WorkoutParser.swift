import Foundation

/// Service for parsing natural language workout descriptions into structured data
final class WorkoutParser {

    /// Known exercise names for fuzzy matching
    private let knownExercises: Set<String>

    init(exerciseDatabase: [String]? = nil) {
        if let exercises = exerciseDatabase {
            self.knownExercises = Set(exercises.map { $0.lowercased() })
        } else {
            // Default common exercises
            self.knownExercises = Set([
                "bench press", "flat bench press", "incline bench press", "decline bench press",
                "squats", "squat", "back squat", "front squat", "goblet squat",
                "deadlift", "deadlifts", "conventional deadlift", "sumo deadlift", "romanian deadlift",
                "overhead press", "shoulder press", "military press", "ohp",
                "barbell row", "bent over row", "rows", "dumbbell row", "cable row", "seated row",
                "pull ups", "pull-ups", "pullups", "chin ups", "chin-ups", "chinups",
                "lat pulldown", "lat pulldowns", "pulldown",
                "bicep curl", "bicep curls", "curls", "hammer curl", "hammer curls", "preacher curl",
                "tricep extension", "tricep extensions", "skull crushers", "tricep pushdown",
                "leg press", "leg extension", "leg curl", "calf raise", "calf raises",
                "lunges", "lunge", "walking lunges", "bulgarian split squat",
                "dips", "dip", "tricep dips", "chest dips",
                "face pull", "face pulls", "lateral raise", "lateral raises", "front raise",
                "shrugs", "shrug", "upright row",
                "plank", "ab crunch", "crunches", "sit ups", "leg raise", "hanging leg raise"
            ])
        }
    }

    /// Parse transcribed text into a list of exercises with sets
    func parse(_ text: String) -> [ParsedExercise] {
        let normalizedText = normalizeText(text)
        var exercises: [ParsedExercise] = []

        // Split by common delimiters that might separate exercises
        let segments = splitIntoExerciseSegments(normalizedText)

        for segment in segments {
            if let exercise = parseExerciseSegment(segment) {
                // Merge with existing exercise if same name
                if let existingIndex = exercises.firstIndex(where: { $0.name.lowercased() == exercise.name.lowercased() }) {
                    exercises[existingIndex].sets.append(contentsOf: exercise.sets)
                } else {
                    exercises.append(exercise)
                }
            }
        }

        // Number sets sequentially for each exercise
        for i in exercises.indices {
            for (setIndex, _) in exercises[i].sets.enumerated() {
                exercises[i].sets[setIndex].setNumber = setIndex + 1
            }
        }

        return exercises
    }

    private func normalizeText(_ text: String) -> String {
        var normalized = text.lowercased()

        // Normalize weight units
        normalized = normalized.replacingOccurrences(of: "pounds", with: "lbs")
        normalized = normalized.replacingOccurrences(of: "pound", with: "lbs")
        normalized = normalized.replacingOccurrences(of: "kilograms", with: "kg")
        normalized = normalized.replacingOccurrences(of: "kilos", with: "kg")
        normalized = normalized.replacingOccurrences(of: "kgs", with: "kg")

        // Normalize number words
        let numberWords = [
            "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
            "eleven": "11", "twelve": "12", "fifteen": "15", "twenty": "20"
        ]
        for (word, digit) in numberWords {
            normalized = normalized.replacingOccurrences(of: " \(word) ", with: " \(digit) ")
        }

        return normalized
    }

    private func splitIntoExerciseSegments(_ text: String) -> [String] {
        // Split on common transition words
        let delimiters = ["then", "next", "after that", "followed by", "and then", "also did", "moved on to"]
        var segments = [text]

        for delimiter in delimiters {
            segments = segments.flatMap { $0.components(separatedBy: delimiter) }
        }

        // Also split on periods and semicolons
        segments = segments.flatMap { $0.components(separatedBy: ".") }
        segments = segments.flatMap { $0.components(separatedBy: ";") }

        return segments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseExerciseSegment(_ segment: String) -> ParsedExercise? {
        // Find exercise name
        guard let exerciseName = findExerciseName(in: segment) else {
            return nil
        }

        let sets = parseSets(from: segment)

        guard !sets.isEmpty else {
            return nil
        }

        return ParsedExercise(name: exerciseName.capitalized, sets: sets)
    }

    private func findExerciseName(in text: String) -> String? {
        // Try to match known exercises (longest match first)
        let sortedExercises = knownExercises.sorted { $0.count > $1.count }

        for exercise in sortedExercises {
            if text.contains(exercise) {
                return exercise
            }
        }

        // Fallback: try to extract exercise name from common patterns
        // "did X", "some X", etc.
        let patterns = [
            "did (?:some )?([a-z ]+?)(?:\\s+\\d|$|,)",
            "^([a-z ]+?)(?:\\s+\\d|$|,)"
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let candidate = String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "did ", with: "")
                    .replacingOccurrences(of: "some ", with: "")
                    .components(separatedBy: CharacterSet.decimalDigits).first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let candidate = candidate, candidate.count > 2 {
                    return candidate
                }
            }
        }

        return nil
    }

    private func parseSets(from text: String) -> [ParsedSet] {
        var sets: [ParsedSet] = []

        // Pattern 1: "X sets of Y reps at Z lbs" or "X sets Y reps Z lbs"
        // Pattern 2: "Z lbs for Y reps" (single set implied)
        // Pattern 3: "Y reps at Z lbs" (single set implied)
        // Pattern 4: "then Z for Y" (weight for reps, context from previous)

        // Extract all numbers and their context
        let numbers = extractNumbers(from: text)

        // Look for explicit set count
        let setCount = findSetCount(in: text, numbers: numbers)

        // Look for weight and reps patterns
        let weightReps = findWeightAndReps(in: text, numbers: numbers)

        if !weightReps.isEmpty {
            // If we have explicit set count, duplicate the weight/reps
            let actualSetCount = setCount ?? 1

            for wr in weightReps {
                for _ in 0..<actualSetCount {
                    sets.append(ParsedSet(
                        setNumber: 0,
                        reps: wr.reps,
                        weight: wr.weight,
                        unit: wr.unit
                    ))
                }
            }
        }

        // Handle progressive sets like "135 for 10, 155 for 8, 175 for 6"
        let progressiveSets = findProgressiveSets(in: text)
        if !progressiveSets.isEmpty {
            sets = progressiveSets
        }

        return sets
    }

    private func extractNumbers(from text: String) -> [(value: Int, range: Range<String.Index>)] {
        var numbers: [(value: Int, range: Range<String.Index>)] = []

        let pattern = "\\d+"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: nsRange)

            for match in matches {
                if let range = Range(match.range, in: text),
                   let value = Int(text[range]) {
                    numbers.append((value: value, range: range))
                }
            }
        }

        return numbers
    }

    private func findSetCount(in text: String, numbers: [(value: Int, range: Range<String.Index>)]) -> Int? {
        // Look for "X sets" pattern
        let pattern = "(\\d+)\\s*sets?"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let count = Int(text[range]) {
            return count
        }
        return nil
    }

    private func findWeightAndReps(in text: String, numbers: [(value: Int, range: Range<String.Index>)]) -> [(weight: Double, reps: Int, unit: WeightUnit)] {
        var results: [(weight: Double, reps: Int, unit: WeightUnit)] = []

        // Pattern: "X lbs for Y reps" or "X lbs Y reps"
        let weightFirstPattern = "(\\d+)\\s*(lbs?|kg)\\s*(?:for\\s*)?(\\d+)\\s*reps?"
        if let regex = try? NSRegularExpression(pattern: weightFirstPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let weightRange = Range(match.range(at: 1), in: text),
                   let unitRange = Range(match.range(at: 2), in: text),
                   let repsRange = Range(match.range(at: 3), in: text),
                   let weight = Double(text[weightRange]),
                   let reps = Int(text[repsRange]) {
                    let unitStr = String(text[unitRange])
                    let unit: WeightUnit = unitStr.contains("kg") ? .kg : .lbs
                    results.append((weight: weight, reps: reps, unit: unit))
                }
            }
        }

        // Pattern: "Y reps at X lbs"
        let repsFirstPattern = "(\\d+)\\s*reps?\\s*(?:at|with|@)?\\s*(\\d+)\\s*(lbs?|kg)"
        if let regex = try? NSRegularExpression(pattern: repsFirstPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let repsRange = Range(match.range(at: 1), in: text),
                   let weightRange = Range(match.range(at: 2), in: text),
                   let unitRange = Range(match.range(at: 3), in: text),
                   let reps = Int(text[repsRange]),
                   let weight = Double(text[weightRange]) {
                    let unitStr = String(text[unitRange])
                    let unit: WeightUnit = unitStr.contains("kg") ? .kg : .lbs
                    results.append((weight: weight, reps: reps, unit: unit))
                }
            }
        }

        return results
    }

    private func findProgressiveSets(in text: String) -> [ParsedSet] {
        var sets: [ParsedSet] = []

        // Pattern for progressive sets: "135 for 10, 155 for 8, 175 for 6"
        // or "135 pounds 10 reps, then 155 for 8"
        let pattern = "(\\d+)\\s*(?:lbs?|kg|pounds?)?\\s*(?:for\\s*)?(\\d+)(?:\\s*reps?)?"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            // Only treat as progressive if we have multiple matches
            if matches.count >= 2 {
                var setNumber = 1
                for match in matches {
                    if let weightRange = Range(match.range(at: 1), in: text),
                       let repsRange = Range(match.range(at: 2), in: text),
                       let weight = Double(text[weightRange]),
                       let reps = Int(text[repsRange]) {
                        // Determine unit from context
                        let unit: WeightUnit = text.contains("kg") ? .kg : .lbs
                        sets.append(ParsedSet(setNumber: setNumber, reps: reps, weight: weight, unit: unit))
                        setNumber += 1
                    }
                }
            }
        }

        return sets
    }
}

// MARK: - Parsed Data Structures

struct ParsedExercise: Identifiable {
    var id = UUID()
    var name: String
    var sets: [ParsedSet]
    var category: ExerciseCategory
    var equipment: Equipment
    var primaryMuscles: [MuscleGroup]
    var notes: String  // Notes for this exercise

    init(name: String, sets: [ParsedSet], category: ExerciseCategory? = nil, equipment: Equipment = .other, primaryMuscles: [MuscleGroup] = [], notes: String = "") {
        self.name = name
        self.sets = sets
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.notes = notes
        // Auto-detect category if not specified
        if let cat = category {
            self.category = cat
        } else {
            // Check if any set has duration (timed exercise)
            if sets.contains(where: { $0.duration != nil && $0.duration! > 0 }) {
                self.category = .timed
            }
            // If weight is 0 or very small, assume bodyweight
            else {
                let avgWeight = sets.isEmpty ? 0 : sets.reduce(0.0) { $0 + $1.weight } / Double(sets.count)
                self.category = avgWeight < 1 ? .bodyweight : .weighted
            }
        }
    }

    var isBodyweight: Bool {
        category == .bodyweight
    }

    var isTimed: Bool {
        category == .timed
    }
}

struct ParsedSet: Identifiable {
    var id = UUID()
    var setNumber: Int
    var reps: Int
    var weight: Double
    var unit: WeightUnit
    var duration: Int?  // Duration in seconds for timed exercises
    var setType: SetType

    // Phase 2: Intensity & execution tracking
    var rpe: Int?  // Rate of Perceived Exertion (1-10)
    var rir: Int?  // Reps In Reserve
    var restTime: Int?  // Rest time in seconds
    var tempo: String?  // Tempo notation (e.g., "3-1-2")
    var gripType: GripType?
    var stanceType: StanceType?

    init(
        setNumber: Int,
        reps: Int,
        weight: Double,
        unit: WeightUnit = .lbs,
        duration: Int? = nil,
        setType: SetType = .normal,
        rpe: Int? = nil,
        rir: Int? = nil,
        restTime: Int? = nil,
        tempo: String? = nil,
        gripType: GripType? = nil,
        stanceType: StanceType? = nil
    ) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.duration = duration
        self.setType = setType
        self.rpe = rpe
        self.rir = rir
        self.restTime = restTime
        self.tempo = tempo
        self.gripType = gripType
        self.stanceType = stanceType
    }
}

// MARK: - Conversion to Model Objects

extension ParsedExercise {
    func toExercise() -> Exercise {
        let exercise = Exercise(
            name: name,
            category: category,
            equipment: equipment,
            primaryMuscles: primaryMuscles
        )
        // Don't pass exercise in initializer - SwiftData handles inverse relationship
        // when we assign to exercise.sets
        exercise.sets = sets.map { parsedSet in
            ExerciseSet(
                setNumber: parsedSet.setNumber,
                reps: parsedSet.reps,
                weight: parsedSet.weight,
                unit: parsedSet.unit,
                duration: parsedSet.duration,
                setType: parsedSet.setType
            )
        }
        return exercise
    }
}
