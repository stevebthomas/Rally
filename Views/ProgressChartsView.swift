import SwiftUI
import SwiftData
import Charts

/// View displaying workout progress charts and statistics
struct ProgressChartsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @AppStorage("weight_unit") private var preferredUnit = WeightUnit.lbs.rawValue

    @State private var selectedExercise: String?

    private var unit: WeightUnit {
        WeightUnit(rawValue: preferredUnit) ?? .lbs
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if workouts.isEmpty {
                        emptyState
                    } else {
                        statsSection
                        exercisePickerSection
                        if let exercise = selectedExercise {
                            chartSection(for: exercise)
                        }
                        personalRecordsSection
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress")
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondaryText)

            Text("No Progress Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record some workouts to see your progress here")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Workouts",
                value: "\(workouts.count)",
                subtitle: "Total",
                icon: "figure.strengthtraining.traditional",
                color: .rallyOrange
            )

            StatCard(
                title: "Volume",
                value: formatVolume(totalVolume),
                subtitle: unit.rawValue + " lifted",
                icon: "scalemass",
                color: .green
            )

            StatCard(
                title: "Exercises",
                value: "\(uniqueExercises.count)",
                subtitle: "Tracked",
                icon: "list.bullet",
                color: .orange
            )
        }
    }

    // MARK: - Exercise Picker

    private var exercisePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track Progress")
                .font(.headline)

            ExercisePicker(selectedExercise: $selectedExercise, exercises: uniqueExercises)
        }
    }

    // MARK: - Chart Section

    private func chartSection(for exerciseName: String) -> some View {
        let category = getExerciseCategory(for: exerciseName)

        return VStack(spacing: 16) {
            // Weight/Reps chart
            if category == .bodyweight {
                RepsProgressChart(
                    data: repsProgressData(for: exerciseName),
                    exerciseName: exerciseName
                )
            } else {
                WeightProgressChart(
                    data: weightProgressData(for: exerciseName),
                    exerciseName: exerciseName,
                    unit: unit
                )
            }

            // Progression chart (comparing to historical average)
            if category == .weighted {
                ProgressionTrendChart(
                    data: progressionData(for: exerciseName),
                    exerciseName: exerciseName
                )
            }
        }
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)

            if allPersonalRecords.isEmpty {
                Text("No PRs recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .padding()
            } else {
                ForEach(allPersonalRecords.prefix(5)) { pr in
                    PRRow(record: pr, unit: unit)
                }
            }
        }
    }

    // MARK: - Helpers

    private var uniqueExercises: [String] {
        var names: Set<String> = []
        for workout in workouts {
            for exercise in workout.exercises {
                names.insert(exercise.name)
            }
        }
        return Array(names).sorted()
    }

    private var totalVolume: Double {
        workouts.reduce(0) { $0 + $1.totalVolume }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func getExerciseCategory(for name: String) -> ExerciseCategory {
        for workout in workouts {
            if let exercise = workout.exercises.first(where: { $0.name == name }) {
                return exercise.category
            }
        }
        return .weighted
    }

    private func weightProgressData(for exerciseName: String) -> [ProgressDataPoint] {
        var dataPoints: [ProgressDataPoint] = []
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            if let exercise = workout.exercises.first(where: { $0.name == exerciseName }) {
                dataPoints.append(ProgressDataPoint(date: workout.date, value: exercise.maxWeight))
            }
        }
        return dataPoints
    }

    private func repsProgressData(for exerciseName: String) -> [ProgressDataPoint] {
        var dataPoints: [ProgressDataPoint] = []
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            if let exercise = workout.exercises.first(where: { $0.name == exerciseName }) {
                dataPoints.append(ProgressDataPoint(date: workout.date, value: Double(exercise.maxReps)))
            }
        }
        return dataPoints
    }

    private func progressionData(for exerciseName: String) -> [ProgressionDataPoint] {
        let sortedWorkouts = workouts.sorted(by: { $0.date < $1.date })
        var dataPoints: [ProgressionDataPoint] = []
        var historicalE1RMs: [Double] = []

        for workout in sortedWorkouts {
            guard let exercise = workout.exercises.first(where: { $0.name == exerciseName }),
                  !exercise.sets.isEmpty else { continue }

            let currentE1RM = E1RMCalculator.averageE1RM(for: exercise.sets)

            // Calculate percentage vs historical average (need at least 2 prior sessions)
            if historicalE1RMs.count >= 2 {
                let historicalAvg = historicalE1RMs.reduce(0, +) / Double(historicalE1RMs.count)
                let percentageVsAvg = historicalAvg > 0
                    ? ((currentE1RM - historicalAvg) / historicalAvg) * 100
                    : 0

                dataPoints.append(ProgressionDataPoint(
                    date: workout.date,
                    percentageChange: percentageVsAvg,
                    e1rm: currentE1RM
                ))
            }

            historicalE1RMs.append(currentE1RM)
        }

        return dataPoints
    }

    private var allPersonalRecords: [PersonalRecord] {
        var prs: [String: PersonalRecord] = [:]

        for workout in workouts {
            for exercise in workout.exercises {
                let isBodyweight = exercise.category == .bodyweight
                let value = isBodyweight ? Double(exercise.maxReps) : exercise.maxWeight

                if let existing = prs[exercise.name] {
                    if value > existing.value {
                        prs[exercise.name] = PersonalRecord(
                            exerciseName: exercise.name,
                            value: value,
                            date: workout.date,
                            category: exercise.category
                        )
                    }
                } else {
                    prs[exercise.name] = PersonalRecord(
                        exerciseName: exercise.name,
                        value: value,
                        date: workout.date,
                        category: exercise.category
                    )
                }
            }
        }

        return Array(prs.values).sorted { $0.value > $1.value }
    }
}

// MARK: - Supporting Types

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let value: Double
    let date: Date
    let category: ExerciseCategory
}

// MARK: - PR Row

struct PRRow: View {
    let record: PersonalRecord
    let unit: WeightUnit

    private let goldColor = Color(red: 1.0, green: 0.84, blue: 0.0)  // #FFD700

    var body: some View {
        HStack(spacing: 12) {
            // Trophy with light gold background
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundColor(goldColor)
                .frame(width: 36, height: 36)
                .background(goldColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }

            Spacer()

            if record.category == .bodyweight {
                Text("\(Int(record.value)) reps")
                    .font(.headline)
                    .foregroundColor(.rallyOrange)
            } else {
                Text("\(Int(record.value)) \(unit.rawValue)")
                    .font(.headline)
                    .foregroundColor(.rallyOrange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(goldColor, lineWidth: 1.5)
        )
    }
}

// MARK: - Reps Progress Chart

struct RepsProgressChart: View {
    let data: [ProgressDataPoint]
    let exerciseName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(exerciseName) - Reps")
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            if data.isEmpty {
                emptyChartState
            } else {
                Chart(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Reps", point.value)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Reps", point.value)
                    )
                    .foregroundStyle(.green)
                }
                .chartYAxisLabel("Reps")
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.secondaryText)
            Text("No data yet")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progression Trend Chart

struct ProgressionDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let percentageChange: Double  // vs historical average
    let e1rm: Double
}

struct ProgressionTrendChart: View {
    let data: [ProgressionDataPoint]
    let exerciseName: String

    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progression vs Average")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer()
            }
            .alert("How Progression Works", isPresented: $showingInfo) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("This shows how each session compares to your historical average for this exercise.\n\n• Above 0%: Stronger than usual\n• Below 0%: Lighter session\n\nAim for consistency with occasional peaks!")
            }

            if data.count < 2 {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondaryText)
                    Text("Need 3+ sessions to show progression")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Zero baseline
                    RuleMark(y: .value("Baseline", 0))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                    ForEach(data) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Change", point.percentageChange)
                        )
                        .foregroundStyle(point.percentageChange >= 0 ? Color.green : Color.orange)
                        .cornerRadius(4)
                    }
                }
                .chartYAxisLabel("%")
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 180)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Above avg")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Below avg")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ProgressChartsView()
        .modelContainer(for: Workout.self, inMemory: true)
}
