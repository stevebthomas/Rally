import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Detailed view for a single workout
struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingDeleteConfirmation = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var isProcessingMedia = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // Media section (gallery + add button)
                mediaSection

                // Exercises
                exercisesSection

                // Stats
                statsSection

                // Raw transcription (if available)
                if let transcription = workout.rawTranscription, !transcription.isEmpty {
                    transcriptionSection(transcription)
                }
            }
            .padding()
        }
        .onChange(of: selectedPhotosPickerItems) { oldValue, newValue in
            Task {
                await processSelectedMedia(newValue)
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text("Are you sure you want to delete this workout? This action cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.formattedDate)
                .font(.title2)
                .fontWeight(.bold)

            Text(workout.formattedTime)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos & Videos")
                    .font(.headline)

                Spacer()

                PhotosPicker(
                    selection: $selectedPhotosPickerItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .foregroundColor(.rallyOrange)
                }
            }

            if isProcessingMedia {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Adding media...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            if workout.hasMedia {
                WorkoutMediaGallery(
                    media: workout.media
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.secondaryText)
                    Text("No photos or videos yet")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    Text("Tap + Add to document this workout")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Media Processing

    private func processSelectedMedia(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        await MainActor.run { isProcessingMedia = true }

        for item in items {
            // Try to load as image first
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                if let filename = MediaService.shared.saveImage(uiImage) {
                    await MainActor.run {
                        let workoutMedia = WorkoutMedia(
                            filename: filename,
                            mediaType: .photo
                        )
                        modelContext.insert(workoutMedia)
                        workoutMedia.workout = workout
                    }
                }
            }
            // Try to load as video
            else if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                if let filename = MediaService.shared.saveVideo(from: movie.url) {
                    await MainActor.run {
                        let workoutMedia = WorkoutMedia(
                            filename: filename,
                            mediaType: .video
                        )
                        modelContext.insert(workoutMedia)
                        workoutMedia.workout = workout
                    }
                }
            }
        }

        await MainActor.run {
            isProcessingMedia = false
            selectedPhotosPickerItems = []
        }
    }

    private func deleteMedia(_ media: WorkoutMedia) {
        // Delete the file
        MediaService.shared.deleteMedia(filename: media.filename)
        // Delete from database
        modelContext.delete(media)
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.headline)

            ForEach(workout.exercises, id: \.id) { exercise in
                ExerciseCard(exercise: exercise)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            HStack(spacing: 16) {
                StatItem(
                    icon: "number",
                    label: "Sets",
                    value: "\(workout.totalSets)"
                )

                StatItem(
                    icon: "repeat",
                    label: "Reps",
                    value: "\(workout.totalReps)"
                )

                StatItem(
                    icon: "scalemass",
                    label: "Volume",
                    value: "\(Int(workout.totalVolume)) lbs"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Transcription Section

    private func transcriptionSection(_ transcription: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Original Transcription")
                .font(.headline)

            Text(transcription)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }

    // MARK: - Actions

    private func deleteWorkout() {
        modelContext.delete(workout)
        dismiss()
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.rallyOrange)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout.sampleWorkout)
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
