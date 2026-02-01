import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is within this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Relative date string for display
    var relativeString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isThisWeek {
            return formatted(.dateTime.weekday(.wide))
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format as weight string with unit
    func formatWeight(unit: WeightUnit) -> String {
        if self >= 1000 {
            return String(format: "%.1fK %@", self / 1000, unit.rawValue)
        }
        return "\(Int(self)) \(unit.rawValue)"
    }

    /// Format as volume string
    var volumeString: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", self / 1_000_000)
        } else if self >= 1000 {
            return String(format: "%.1fK", self / 1000)
        }
        return "\(Int(self))"
    }
}

// MARK: - String Extensions

extension String {
    /// Capitalize first letter only
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst().lowercased()
    }

    /// Convert to title case (each word capitalized)
    var titleCased: String {
        self.components(separatedBy: " ")
            .map { $0.capitalizedFirst }
            .joined(separator: " ")
    }
}

// MARK: - Array Extensions

extension Array where Element == Workout {
    /// Group workouts by date
    func groupedByDate() -> [Date: [Workout]] {
        Dictionary(grouping: self) { workout in
            Calendar.current.startOfDay(for: workout.date)
        }
    }

    /// Get all unique exercise names
    var uniqueExerciseNames: [String] {
        var names: Set<String> = []
        for workout in self {
            for exercise in workout.exercises {
                names.insert(exercise.name)
            }
        }
        return names.sorted()
    }
}

// MARK: - View Extensions

extension View {
    /// Apply conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Hide keyboard
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Color Extensions

extension Color {
    /// Rally brand colors
    static let rallyOrange = Color(red: 232/255, green: 122/255, blue: 45/255)  // #E87A2D
    static let rallyGray = Color(red: 142/255, green: 142/255, blue: 147/255)   // #8E8E93

    /// App accent colors
    static let appAccent = Color.rallyOrange
    static let appGreen = Color.green
    static let appOrange = Color.rallyOrange
    static let appRed = Color.red
    static let appYellow = Color.yellow

    /// Semantic colors for workout stats
    static let volumeColor = Color.green
    static let repsColor = Color.rallyOrange
    static let weightColor = Color.rallyOrange
    static let prColor = Color.yellow
}

// MARK: - Bundle Extensions

extension Bundle {
    /// Load JSON resource from bundle
    func decode<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        guard let url = self.url(forResource: filename, withExtension: "json") else {
            print("Failed to locate \(filename).json in bundle")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            print("Failed to load \(filename).json from bundle")
            return nil
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(T.self, from: data) else {
            print("Failed to decode \(filename).json")
            return nil
        }

        return decoded
    }
}

// MARK: - Exercise Database Helper

struct ExerciseDatabase {
    static let shared = ExerciseDatabase()

    let exercises: [String]

    private init() {
        if let loaded = Bundle.main.decode([String].self, from: "ExerciseDatabase") {
            exercises = loaded
        } else {
            // Fallback to built-in list
            exercises = Self.defaultExercises
        }
    }

    static let defaultExercises = [
        "Bench Press",
        "Incline Bench Press",
        "Decline Bench Press",
        "Dumbbell Press",
        "Push-ups",
        "Squats",
        "Front Squats",
        "Leg Press",
        "Lunges",
        "Leg Extensions",
        "Leg Curls",
        "Deadlift",
        "Romanian Deadlift",
        "Sumo Deadlift",
        "Overhead Press",
        "Military Press",
        "Shoulder Press",
        "Lateral Raises",
        "Front Raises",
        "Bent Over Rows",
        "Barbell Rows",
        "Dumbbell Rows",
        "Cable Rows",
        "Lat Pulldowns",
        "Pull-ups",
        "Chin-ups",
        "Bicep Curls",
        "Hammer Curls",
        "Preacher Curls",
        "Tricep Extensions",
        "Tricep Pushdowns",
        "Skull Crushers",
        "Dips",
        "Face Pulls",
        "Shrugs",
        "Calf Raises",
        "Hip Thrusts",
        "Glute Bridges",
        "Planks",
        "Crunches",
        "Russian Twists"
    ]

    /// Fuzzy match exercise name
    func findMatch(for input: String) -> String? {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespaces)

        // Exact match
        if let exact = exercises.first(where: { $0.lowercased() == normalizedInput }) {
            return exact
        }

        // Contains match
        if let contains = exercises.first(where: { $0.lowercased().contains(normalizedInput) }) {
            return contains
        }

        // Input contains exercise name
        if let contains = exercises.first(where: { normalizedInput.contains($0.lowercased()) }) {
            return contains
        }

        return nil
    }
}
