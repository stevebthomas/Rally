import SwiftUI
import SwiftData
import UIKit

/// View displaying workout history with calendar interface
struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showingDeleteConfirmation = false
    @State private var workoutToDelete: Workout?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calendar
                    calendarView

                    // Workouts for selected date
                    selectedDateWorkouts
                }
                .padding()
            }
            .background(Color(red: 245/255, green: 246/255, blue: 247/255))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.headline)
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete {
                        deleteWorkout(workout)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.rallyOrange)
                }

                Spacer()

                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.rallyOrange)
                }
            }
            .padding(.horizontal)

            // Day headers
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasWorkout: hasWorkout(on: date),
                            workoutCount: workoutCount(on: date),
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                    } else {
                        Text("")
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Selected Date Workouts

    private var selectedDateWorkouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundColor(.secondary)

            let dayWorkouts = workoutsFor(date: selectedDate)

            if dayWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No workouts on this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(dayWorkouts) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        WorkoutCard(workout: workout)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            workoutToDelete = workout
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: currentMonth)!
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = []

        // Add empty cells for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add all days of the month
        var currentDate = firstDay
        while currentDate < interval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return days
    }

    private func hasWorkout(on date: Date) -> Bool {
        workouts.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func workoutCount(on date: Date) -> Int {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    private func workoutsFor(date: Date) -> [Workout] {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private func deleteWorkout(_ workout: Workout) {
        modelContext.delete(workout)
        workoutToDelete = nil
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasWorkout: Bool
    let workoutCount: Int
    let isToday: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.rallyOrange)
                } else if isToday {
                    Circle()
                        .stroke(Color.rallyOrange, lineWidth: 2)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(hasWorkout ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : (hasWorkout ? .primary : .secondary))
            }
            .frame(width: 36, height: 36)

            // Workout indicator dots
            if hasWorkout && !isSelected {
                HStack(spacing: 2) {
                    ForEach(0..<min(workoutCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                    }
                }
            } else {
                Spacer()
                    .frame(height: 5)
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Workout Card

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(workout.formattedTime)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Media indicator
                if workout.hasMedia {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                        Text("\(workout.mediaCount)")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }

                Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.rallyOrange.opacity(0.1))
                    .foregroundColor(.rallyOrange)
                    .cornerRadius(8)
            }

            // Media thumbnails preview (show first 3)
            if workout.hasMedia {
                WorkoutMediaThumbnailStrip(media: Array(workout.media.prefix(3)))
            }

            // Exercise names (unique)
            Text(Array(Set(workout.exercises.map { $0.name })).sorted().joined(separator: ", "))
                .font(.headline)
                .lineLimit(2)

            // Stats
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .foregroundColor(.rallyOrange)
                    Text("\(workout.totalSets) sets")
                }

                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .foregroundColor(.orange)
                    Text("\(Int(workout.totalVolume)) lbs")
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Horizontal strip of media thumbnails for workout cards
struct WorkoutMediaThumbnailStrip: View {
    let media: [WorkoutMedia]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(media) { item in
                SmallMediaThumbnail(media: item)
            }
            Spacer()
        }
    }
}

/// Small thumbnail for workout card preview
struct SmallMediaThumbnail: View {
    let media: WorkoutMedia
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
            }

            if media.mediaType == .video {
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        Task {
            let image: UIImage?
            if media.mediaType == .photo {
                image = MediaService.shared.loadImage(filename: media.filename)
            } else {
                image = MediaService.shared.generateVideoThumbnail(filename: media.filename)
            }
            await MainActor.run {
                thumbnail = image
            }
        }
    }
}

#Preview {
    WorkoutHistoryView()
        .modelContainer(for: Workout.self, inMemory: true)
}
