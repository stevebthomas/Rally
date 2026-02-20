import SwiftUI

// MARK: - Ghost Set Row (shows previous session's set as faint comparison)

struct GhostSetRow: View {
    let ghostSet: GhostSetService.GhostSet
    let currentSet: ParsedSet?
    let comparison: GhostSetService.SetComparison?

    var body: some View {
        HStack(spacing: 8) {
            // Ghost indicator
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))

            // Ghost set details
            Text("Last: \(ghostSet.displayString)")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))

            Spacer()

            // E1RM comparison if we have current data
            if let comparison = comparison {
                E1RMComparisonBadge(comparison: comparison)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - E1RM Comparison Badge

struct E1RMComparisonBadge: View {
    let comparison: GhostSetService.SetComparison

    var body: some View {
        HStack(spacing: 4) {
            if comparison.isPersonalBest {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("PR!")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            } else {
                Image(systemName: comparison.improvement >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                    .foregroundColor(comparison.improvement >= 0 ? .green : .orange)
                Text(comparison.improvementString)
                    .font(.caption2)
                    .foregroundColor(comparison.improvement >= 0 ? .green : .orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            comparison.isPersonalBest
                ? Color.yellow.opacity(0.2)
                : (comparison.improvement >= 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
        )
        .cornerRadius(6)
    }
}

// MARK: - Personal Best Indicator (animated)

struct PersonalBestIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.title3)
                .foregroundColor(.yellow)
                .scaleEffect(isAnimating ? 1.2 : 1.0)

            Text("New Personal Best!")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Workout Progression Card

struct WorkoutProgressionCard: View {
    let summary: GhostSetService.WorkoutProgressionSummary

    @State private var showingInfo = false

    var body: some View {
        VStack(spacing: 12) {
            // Header with info button
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.rallyOrange)
                Text("Workout Insights")
                    .font(.headline)

                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .alert("How Progression Works", isPresented: $showingInfo) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("Progression compares your current performance to your historical average for each exercise.\n\n• Improving: >3% above your average\n• Steady: Within ±3% of average\n• Below average: >3% below average\n\nIdeal range: Aim for steady or improving. Occasional dips are normal — recovery matters!")
            }

            if summary.hasEnoughData {
                // Overall trend
                HStack(spacing: 8) {
                    trendIcon(for: summary.overallTrend)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.overallTrend.description)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if summary.averagePercentageChange != 0 {
                            Text(String(format: "%+.1f%% vs your average", summary.averagePercentageChange))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }

                Divider()

                // Per-exercise breakdown
                VStack(spacing: 8) {
                    ForEach(summary.progressions.filter { $0.hasEnoughData }) { progression in
                        ExerciseProgressionRow(progression: progression)
                    }
                }

                // Show exercises needing more data
                let needsData = summary.progressions.filter { !$0.hasEnoughData }
                if !needsData.isEmpty {
                    HStack {
                        Image(systemName: "hourglass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(needsData.count) exercise\(needsData.count == 1 ? "" : "s") need\(needsData.count == 1 ? "s" : "") more sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } else {
                // Not enough data message
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))

                    Text(summary.dataReadinessMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if summary.totalExercises > 0 {
                        // Show progress toward unlocking insights
                        let sessionsNeeded = summary.progressions.map { max(0, 3 - $0.sessionCount) }
                        let minSessionsLeft = sessionsNeeded.min() ?? 3
                        if minSessionsLeft > 0 {
                            Text("\(minSessionsLeft) more session\(minSessionsLeft == 1 ? "" : "s") to unlock first insight")
                                .font(.caption)
                                .foregroundColor(.rallyOrange)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func trendIcon(for trend: GhostSetService.ProgressionTrend) -> some View {
        switch trend {
        case .improving:
            Image(systemName: "arrow.up.right.circle.fill")
                .foregroundColor(.green)
        case .maintaining:
            Image(systemName: "equal.circle.fill")
                .foregroundColor(.blue)
        case .declining:
            Image(systemName: "arrow.down.right.circle.fill")
                .foregroundColor(.orange)
        case .insufficientData:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Exercise Progression Row

struct ExerciseProgressionRow: View {
    let progression: GhostSetService.ExerciseProgression

    var body: some View {
        HStack {
            Text(progression.exerciseName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                trendIcon
                    .font(.caption)

                Text(String(format: "%+.1f%%", progression.percentageChange))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(trendColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trendColor.opacity(0.15))
            .cornerRadius(6)
        }
    }

    private var trendIcon: some View {
        switch progression.trend {
        case .improving:
            return Image(systemName: "arrow.up.right")
        case .maintaining:
            return Image(systemName: "equal")
        case .declining:
            return Image(systemName: "arrow.down.right")
        case .insufficientData:
            return Image(systemName: "questionmark")
        }
    }

    private var trendColor: Color {
        switch progression.trend {
        case .improving: return .green
        case .maintaining: return .blue
        case .declining: return .orange
        case .insufficientData: return .secondary
        }
    }
}

// MARK: - Ghost Exercise Header

struct GhostExerciseHeader: View {
    let ghostExercise: GhostSetService.GhostExercise

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Previous: \(ghostExercise.date.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text("\(Int(ghostExercise.averageE1RM)) avg")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PersonalBestIndicator()

        WorkoutProgressionCard(
            summary: GhostSetService.WorkoutProgressionSummary(
                progressions: [
                    GhostSetService.ExerciseProgression(
                        exerciseName: "Bench Press",
                        currentE1RM: 200,
                        historicalAverageE1RM: 190,
                        sessionCount: 5,
                        trend: .improving,
                        percentageChange: 5.3
                    ),
                    GhostSetService.ExerciseProgression(
                        exerciseName: "Squat",
                        currentE1RM: 250,
                        historicalAverageE1RM: 255,
                        sessionCount: 4,
                        trend: .maintaining,
                        percentageChange: -2.0
                    )
                ],
                exercisesWithEnoughData: 2,
                totalExercises: 2,
                overallTrend: .improving,
                averagePercentageChange: 1.65
            )
        )

        E1RMComparisonBadge(
            comparison: GhostSetService.SetComparison(
                currentE1RM: 200,
                previousE1RM: 185,
                improvement: 8.1,
                isPersonalBest: true
            )
        )
    }
    .padding()
}
