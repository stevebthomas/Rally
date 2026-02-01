import SwiftUI
import Charts

/// Data point for progress charts
struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Stats card for displaying metrics
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.rallyGray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// Exercise picker dropdown
struct ExercisePicker: View {
    @Binding var selectedExercise: String?
    let exercises: [String]

    var body: some View {
        Menu {
            Button("All Exercises") {
                selectedExercise = nil
            }
            Divider()
            ForEach(exercises, id: \.self) { exercise in
                Button(exercise) {
                    selectedExercise = exercise
                }
            }
        } label: {
            HStack {
                Text(selectedExercise ?? "Select Exercise")
                    .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(Color.rallyGray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

/// Weight progress line chart
struct WeightProgressChart: View {
    let data: [ProgressDataPoint]
    let exerciseName: String
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundStyle(Color.rallyOrange)
                Text("Weight Progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if data.isEmpty {
                emptyChartState
            } else {
                Chart(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(Color.rallyOrange)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(Color.rallyOrange)

                    if point.value == data.map({ $0.value }).max() {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.value)
                        )
                        .symbol(.circle)
                        .symbolSize(100)
                        .foregroundStyle(.yellow)
                        .annotation(position: .top) {
                            Text("PR")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel(unit.rawValue)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.rallyOrange.opacity(0.2), Color.rallyOrange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.rallyOrange.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(Color.rallyGray)
            Text("No data yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

/// Daily volume bar chart
struct DailyVolumeChart: View {
    let data: [ProgressDataPoint]
    var unit: WeightUnit = .lbs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundStyle(Color.rallyOrange)
                Text("Daily Volume")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if data.isEmpty {
                emptyChartState
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Volume", point.value)
                    )
                    .foregroundStyle(Color.rallyOrange.gradient)
                }
                .frame(height: 200)
                .chartYAxisLabel(unit.rawValue)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.rallyOrange.opacity(0.15), Color.rallyOrange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.rallyOrange.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(Color.rallyGray)
            Text("No data yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}
