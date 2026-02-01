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
            .background(Color(red: 245/255, green: 246/255, blue: 247/255))
            .navigationBarTitleDisplayMode(.inline)
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
                .foregroundColor(.secondary)

            Text("No Progress Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record some workouts to see your progress here")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
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

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                .foregroundColor(.secondary)

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
                .foregroundColor(.secondary)
            Text("No data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressChartsView()
        .modelContainer(for: Workout.self, inMemory: true)
}
