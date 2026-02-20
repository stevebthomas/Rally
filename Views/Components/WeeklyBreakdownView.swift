import SwiftUI

/// Weekly breakdown view showing workout activity for each day
struct WeeklyBreakdownView: View {
    let workouts: [Workout]
    let goal: Int
    @Environment(\.dismiss) private var dismiss

    /// Days of the week starting from Sunday
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Get the start of the current week (Sunday)
    private var weekStart: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1  // Sunday
        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return calendar.date(from: components) ?? today
    }

    /// Get all dates for the current week
    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    /// Group workouts by day
    private var workoutsByDay: [Date: [Workout]] {
        var result: [Date: [Workout]] = [:]
        for workout in workouts {
            let dayStart = Calendar.current.startOfDay(for: workout.date)
            result[dayStart, default: []].append(workout)
        }
        return result
    }

    /// Count of unique workout days
    private var uniqueWorkoutDays: Int {
        workoutsByDay.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress summary
                    progressSummary

                    // Day-by-day breakdown
                    VStack(spacing: 12) {
                        ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                            DayRow(
                                dayName: weekdays[index],
                                date: date,
                                workouts: workoutsByDay[Calendar.current.startOfDay(for: date)] ?? [],
                                isToday: Calendar.current.isDateInToday(date)
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(Color.appBackground)
            .navigationTitle("This Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var progressSummary: some View {
        VStack(spacing: 8) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.rallyOrange.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: min(CGFloat(uniqueWorkoutDays) / CGFloat(goal), 1.0))
                    .stroke(Color.rallyOrange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(uniqueWorkoutDays)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.rallyOrange)
                    Text("of \(goal)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            Text(progressMessage)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .padding(.top, 4)
        }
        .padding()
    }

    private var progressMessage: String {
        if uniqueWorkoutDays >= goal {
            return "Goal reached! Great work!"
        } else if uniqueWorkoutDays == 0 {
            return "Start your week strong!"
        } else {
            let remaining = goal - uniqueWorkoutDays
            return "\(remaining) more day\(remaining == 1 ? "" : "s") to reach your goal"
        }
    }
}

/// Row for a single day showing workout status and details
struct DayRow: View {
    let dayName: String
    let date: Date
    let workouts: [Workout]
    let isToday: Bool

    @State private var isExpanded = false

    private var hasWorkout: Bool {
        !workouts.isEmpty
    }

    private var isPast: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    private var isFuture: Bool {
        date > Calendar.current.startOfDay(for: Date())
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if hasWorkout {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Day indicator circle
                    ZStack {
                        Circle()
                            .fill(circleColor)
                            .frame(width: 40, height: 40)

                        if hasWorkout {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        } else if isToday {
                            Circle()
                                .stroke(Color.rallyOrange, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                    }

                    // Day info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(dayName)
                                .font(.headline)
                                .foregroundColor(textColor)

                            if isToday {
                                Text("Today")
                                    .font(.caption)
                                    .foregroundColor(.rallyOrange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.rallyOrange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }

                        Text(dateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }

                    Spacer()

                    // Dropdown arrow for days with workouts
                    if hasWorkout {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.rallyOrange)
                    }
                    // Note: "Rest day" only shown if user explicitly marks it (future feature)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)

            // Expanded workout details
            if isExpanded && hasWorkout {
                VStack(spacing: 8) {
                    ForEach(workouts, id: \.id) { workout in
                        WorkoutSummaryRow(workout: workout)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
                .padding(.top, -8)
            }
        }
    }

    private var circleColor: Color {
        if hasWorkout {
            return .rallyOrange
        } else if isFuture {
            return Color(UIColor.tertiarySystemFill)
        } else {
            return Color(UIColor.secondarySystemFill)
        }
    }

    private var textColor: Color {
        if isFuture {
            return .secondary
        }
        return .primary
    }
}

/// Summary row for a single workout
struct WorkoutSummaryRow: View {
    let workout: Workout

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Exercise names
                let exerciseNames = Array(Set(workout.exercises.map { $0.name }))
                    .prefix(3)
                    .joined(separator: ", ")

                Text(exerciseNames.isEmpty ? "Workout" : exerciseNames)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(timeFormatter.string(from: workout.date))
                        .font(.caption)
                        .foregroundColor(.secondaryText)

                    Text("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WeeklyBreakdownView(workouts: [], goal: 5)
}
