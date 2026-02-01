import SwiftUI
import SwiftData
import PhotosUI

/// Main view for recording and logging workouts via voice
struct RecordWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("userName") private var userName = ""
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var networkMonitor = NetworkMonitor.shared

    // Session state - accumulates multiple recordings
    @State private var sessionTranscriptions: [String] = []
    @State private var parsedExercises: [ParsedExercise] = []
    @State private var isSessionActive = false

    // UI state
    @State private var isTranscribing = false
    @State private var isParsing = false
    @State private var showingPreview = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSaveSuccess = false
    @State private var lastTranscriptionMode: TranscriptionMode = .offline

    // Text input state
    @State private var textInput = ""
    @State private var isTextInputFocused = false
    @FocusState private var textFieldFocused: Bool

    // Media state
    @State private var mediaItems: [MediaItem] = []

    // Services
    private let whisperService = WhisperService()
    private let speechService = SpeechRecognitionService()
    private let llmParser = LLMWorkoutParser()  // New hybrid parser
    private let offlineParser = OfflineWorkoutParser()

    // Quick-add exercises
    private let quickExercises = ["Bench Press", "Squat", "Deadlift", "Pull Ups", "Shoulder Press", "Rows"]

    // Computed properties for stats
    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.filter { $0.date >= weekAgo }.count
    }

    private var lastWorkout: Workout? {
        workouts.first
    }

    private var recentExerciseNames: [String] {
        Array(Set(workouts.prefix(3).flatMap { $0.exercises.map { $0.name } })).prefix(3).map { $0 }
    }

    enum TranscriptionMode {
        case online
        case offline
    }

    enum ParsingMode {
        case gpt
        case offline
    }

    // Computed property to determine if button should be in "up" position
    private var shouldShowUpPosition: Bool {
        isSessionActive || audioRecorder.isRecording || isTranscribing || !sessionTranscriptions.isEmpty
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Match background to logo image background
                    Color(red: 245/255, green: 246/255, blue: 247/255)
                        .ignoresSafeArea()

                    // Background scroll content (transcriptions, etc.)
                    ScrollView {
                        VStack(spacing: 24) {
                            // Session status
                            if isSessionActive {
                                sessionStatusCard
                            }

                            // Recording section - only show when in up position
                            if shouldShowUpPosition {
                                recordingSection
                                    .transition(.opacity)
                            }

                            // Transcriptions list
                            if !sessionTranscriptions.isEmpty {
                                transcriptionsSection
                            }

                            // End workout button
                            if !sessionTranscriptions.isEmpty && !isParsing {
                                endWorkoutButton
                            }

                            // Spacer to allow scrolling past centered button area
                            if !shouldShowUpPosition {
                                Spacer()
                                    .frame(height: geometry.size.height * 0.6)
                            }
                        }
                        .padding()
                    }

                    // Home screen (when not in active session)
                    if !shouldShowUpPosition {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Header with small logo and greeting
                                headerSection
                                    .padding(.top, 8)

                                // Start Workout button
                                startWorkoutButton

                                // Text input bar
                                VStack(spacing: 8) {
                                    textInputBar
                                    Text("e.g. 3x10 135lb Bench")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                // Quick-add exercise chips
                                quickAddSection

                                // Stats & Recent Activity
                                if !workouts.isEmpty {
                                    statsAndRecentSection
                                }

                                Spacer().frame(height: 20)
                            }
                            .padding(.horizontal)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: shouldShowUpPosition)
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Workout Saved!", isPresented: $showingSaveSuccess) {
                Button("OK") {
                    resetSession()
                }
            } message: {
                Text("Your workout has been saved to History. Check the Progress tab to track your gains!")
            }
            .sheet(isPresented: $showingPreview) {
                WorkoutPreviewSheet(
                    exercises: $parsedExercises,
                    mediaItems: $mediaItems,
                    onSave: saveWorkout,
                    onCancel: { showingPreview = false }
                )
            }
        }
    }

    // MARK: - Session Status Card

    private var sessionStatusCard: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundColor(.green)
            VStack(alignment: .leading) {
                Text("Workout Session Active")
                    .font(.headline)
                Text("\(sessionTranscriptions.count) recording\(sessionTranscriptions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("End Session") {
                resetSession()
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Recording Section (shown when session is active)

    private var recordingSection: some View {
        VStack(spacing: 16) {
            if audioRecorder.isRecording {
                Text("Recording...")
                    .font(.headline)
                    .foregroundColor(.red)
            } else if isTranscribing {
                Text("Transcribing...")
                    .font(.headline)
                    .foregroundColor(.rallyOrange)
            } else {
                Text(sessionTranscriptions.isEmpty ? "Tap to add exercises" : "Tap to add more exercises")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            TapRecordButton(
                isRecording: audioRecorder.isRecording,
                audioLevel: audioRecorder.recordingLevel,
                duration: audioRecorder.formattedDuration,
                onToggle: toggleRecording
            )
            .disabled(isTranscribing || isParsing)

            if isTranscribing {
                ProgressView("Processing audio...")
                    .padding()
            }

            if !audioRecorder.permissionGranted {
                MicrophonePermissionView {
                    audioRecorder.requestPermission()
                }
            }

            // Text input option
            Text("or type below")
                .font(.caption)
                .foregroundColor(.secondary)

            textInputBar
        }
        .padding(.vertical, 20)
    }

    // MARK: - Transcriptions Section

    private var transcriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recorded Exercises")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    resetSession()
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }

            ForEach(sessionTranscriptions.indices, id: \.self) { index in
                TranscriptionCard(
                    index: index + 1,
                    text: sessionTranscriptions[index],
                    onDelete: {
                        sessionTranscriptions.remove(at: index)
                        if sessionTranscriptions.isEmpty {
                            isSessionActive = false
                        }
                    }
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image("RallyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(userName.isEmpty ? "Welcome!" : "Welcome back, \(userName)!")
                    .font(.headline)
                Text(greetingMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            SimpleConnectionStatus(isConnected: networkMonitor.isConnected)
        }
    }

    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Ready for a morning workout?"
        } else if hour < 17 {
            return "Time to crush it!"
        } else {
            return "Evening gains await!"
        }
    }

    // MARK: - Start Workout Button

    private var startWorkoutButton: some View {
        Button {
            if audioRecorder.permissionGranted {
                toggleRecording()
            } else {
                audioRecorder.requestPermission()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Tap to record your exercises")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.rallyOrange, .rallyOrange.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickExercises, id: \.self) { exercise in
                        Button {
                            addQuickExercise(exercise)
                        } label: {
                            Text(exercise)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func addQuickExercise(_ exercise: String) {
        textInput = "3x10 \(exercise)"
        textFieldFocused = true
    }

    // MARK: - Stats & Recent Section

    private var statsAndRecentSection: some View {
        VStack(spacing: 16) {
            // Weekly progress with tally marks
            WeeklyTallyView(count: workoutsThisWeek, goal: 5)

            // Last workout
            if let last = lastWorkout {
                lastWorkoutCard(last)
            }

            // Recent exercises
            if !recentExerciseNames.isEmpty {
                recentExercisesCard
            }
        }
    }

    private func lastWorkoutCard(_ workout: Workout) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(.rallyOrange)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Session")
                    .font(.subheadline)
                    .fontWeight(.medium)
                let exerciseNames = Array(Set(workout.exercises.map { $0.name })).prefix(2).joined(separator: ", ")
                Text(exerciseNames.isEmpty ? "Workout" : exerciseNames)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(workout.date.timeAgoDisplay())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var recentExercisesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Exercises")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(recentExerciseNames, id: \.self) { name in
                    Button {
                        textInput = "3x10 \(name)"
                        textFieldFocused = true
                    } label: {
                        Text(name)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.rallyOrange.opacity(0.1))
                            .foregroundColor(.rallyOrange)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Text Input Bar

    private var textInputBar: some View {
        HStack(spacing: 12) {
            TextField("Log a set (e.g. 3x10 135lb Bench)", text: $textInput)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(24)
                .focused($textFieldFocused)
                .submitLabel(.send)
                .onSubmit {
                    submitTextInput()
                }

            Button(action: submitTextInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(textInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .rallyOrange)
            }
            .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
    }

    // MARK: - End Workout Button

    private var endWorkoutButton: some View {
        VStack(spacing: 12) {
            Button {
                parseAndShowPreview()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("End Workout & Review")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if isParsing {
                ProgressView("Analyzing your workout...")
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if audioRecorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // No API key check needed - offline mode works without it
        if !isSessionActive {
            isSessionActive = true
        }

        audioRecorder.startRecording()
    }

    private func stopRecording() {
        guard let audioURL = audioRecorder.stopRecording() else {
            return
        }

        Task {
            await transcribeAudio(audioURL: audioURL)
        }
    }

    private func transcribeAudio(audioURL: URL) async {
        await MainActor.run { isTranscribing = true }

        do {
            let text: String

            // Hybrid approach: Use online if connected and API key available, otherwise offline
            if networkMonitor.isConnected && !apiKey.isEmpty {
                // Online mode: Use OpenAI Whisper API
                text = try await whisperService.transcribe(audioURL: audioURL, apiKey: apiKey)
                await MainActor.run { lastTranscriptionMode = .online }
            } else {
                // Offline mode: Use Apple Speech Recognition
                text = try await speechService.transcribe(audioURL: audioURL)
                await MainActor.run { lastTranscriptionMode = .offline }
            }

            await MainActor.run {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sessionTranscriptions.append(text)
                }
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: audioURL)

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }

        await MainActor.run { isTranscribing = false }
    }

    private func parseAndShowPreview() {
        guard !sessionTranscriptions.isEmpty else { return }

        // Combine all transcriptions
        let combinedText = sessionTranscriptions.joined(separator: ". ")

        // Use hybrid LLM parser (online + API key) or pure offline parser
        let useLLM = networkMonitor.isConnected && !apiKey.isEmpty

        if useLLM {
            // Use hybrid LLM parser (with automatic fallback to regex)
            Task {
                await MainActor.run { isParsing = true }

                let exercises = await llmParser.parseWorkout(
                    transcription: combinedText,
                    apiKey: apiKey
                )

                await MainActor.run {
                    parsedExercises = exercises
                    isParsing = false

                    if parsedExercises.isEmpty {
                        errorMessage = "Couldn't recognize any exercises. Try saying something like 'Bench press, 3 sets, 10 reps, 135 pounds' or use gym slang like '3x10 at 2 plates'"
                        showingError = true
                    } else {
                        showingPreview = true
                    }
                }
            }
        } else {
            // Use offline parser only (no API needed)
            isParsing = true

            // Small delay to show loading state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.parsedExercises = self.offlineParser.parseWorkout(transcription: combinedText)
                self.isParsing = false

                if self.parsedExercises.isEmpty {
                    self.errorMessage = "Couldn't recognize any exercises. Try saying something like 'Bench press, 3 sets, 10 reps, 135 pounds'"
                    self.showingError = true
                } else {
                    self.showingPreview = true
                }
            }
        }
    }

    private func saveWorkout() {
        guard !parsedExercises.isEmpty else { return }

        let workout = Workout(
            date: Date(),
            rawTranscription: sessionTranscriptions.joined(separator: "\n---\n")
        )

        // Insert workout first before modifying relationships
        modelContext.insert(workout)

        // Now add exercises after workout is in context
        for parsedExercise in parsedExercises {
            let exercise = Exercise(name: parsedExercise.name, category: parsedExercise.category)
            modelContext.insert(exercise)
            exercise.workout = workout

            for (index, parsedSet) in parsedExercise.sets.enumerated() {
                let exerciseSet = ExerciseSet(
                    setNumber: index + 1,
                    reps: parsedSet.reps,
                    weight: parsedSet.weight,
                    unit: parsedSet.unit
                )
                modelContext.insert(exerciseSet)
                exerciseSet.exercise = exercise
            }
        }

        // Save media items
        for item in mediaItems {
            var filename: String?
            var mediaType: WorkoutMedia.MediaType = .photo

            if item.type == .photo, let image = item.image {
                filename = MediaService.shared.saveImage(image)
                mediaType = .photo
            } else if item.type == .video, let videoURL = item.videoURL {
                filename = MediaService.shared.saveVideo(from: videoURL)
                mediaType = .video
            }

            if let filename = filename {
                let workoutMedia = WorkoutMedia(
                    filename: filename,
                    mediaType: mediaType
                )
                modelContext.insert(workoutMedia)
                workoutMedia.workout = workout
            }
        }

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        // Reset session immediately after saving
        sessionTranscriptions = []
        parsedExercises = []
        mediaItems = []
        isSessionActive = false

        showingPreview = false
        showingSaveSuccess = true
    }

    private func resetSession() {
        sessionTranscriptions = []
        parsedExercises = []
        mediaItems = []
        isSessionActive = false
    }

    private func submitTextInput() {
        let trimmedText = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Start session if not active
        if !isSessionActive {
            isSessionActive = true
        }

        // Add the typed text as a transcription (same as voice input)
        sessionTranscriptions.append(trimmedText)

        // Clear the text input
        textInput = ""
        textFieldFocused = false

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Supporting Views

/// Simple connection status indicator - just wifi icon and Online/Offline
struct SimpleConnectionStatus: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isConnected ? "wifi" : "wifi.slash")
                .font(.caption)
                .foregroundColor(isConnected ? .green : .orange)

            Text(isConnected ? "Online" : "Offline")
                .font(.caption)
                .foregroundColor(isConnected ? .green : .orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isConnected ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }
}

struct MicrophonePermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("Microphone access is required")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Grant Permission", action: onRequest)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct TranscriptionCard: View {
    let index: Int
    let text: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(text)
                .font(.body)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Workout Preview Sheet

struct WorkoutPreviewSheet: View {
    @Binding var exercises: [ParsedExercise]
    @Binding var mediaItems: [MediaItem]
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary
                    HStack {
                        StatBox(
                            title: "Exercises",
                            value: "\(exercises.count)",
                            icon: "figure.strengthtraining.traditional"
                        )
                        StatBox(
                            title: "Total Sets",
                            value: "\(exercises.reduce(0) { $0 + $1.sets.count })",
                            icon: "number"
                        )
                        StatBox(
                            title: "Total Reps",
                            value: "\(exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } })",
                            icon: "repeat"
                        )
                    }
                    .padding(.bottom)

                    // Exercises
                    ForEach(exercises.indices, id: \.self) { index in
                        EditableParsedExerciseCard(
                            exercise: $exercises[index],
                            onDelete: {
                                exercises.remove(at: index)
                            }
                        )
                    }

                    // Add exercise button
                    Button {
                        exercises.append(ParsedExercise(
                            name: "New Exercise",
                            sets: [ParsedSet(setNumber: 1, reps: 10, weight: 0, unit: .lbs)],
                            category: .weighted
                        ))
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Media section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Document Your Workout")
                            .font(.headline)

                        Text("Add photos or videos from today's session")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        MediaPickerButton(
                            selectedItems: $selectedPhotosPickerItems,
                            mediaData: $mediaItems
                        )

                        MediaPreviewGrid(mediaItems: $mediaItems)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Review Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Workout") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(exercises.isEmpty)
                }
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.rallyOrange)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct EditableParsedExerciseCard: View {
    @Binding var exercise: ParsedExercise

    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                TextField("Exercise name", text: $exercise.name)
                    .font(.headline)
                    .textFieldStyle(.plain)

                Spacer()

                // Exercise type picker
                Picker("Type", selection: $exercise.category) {
                    Text("Weighted").tag(ExerciseCategory.weighted)
                    Text("Bodyweight").tag(ExerciseCategory.bodyweight)
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            Divider()

            // Sets
            ForEach(exercise.sets.indices, id: \.self) { index in
                PreviewSetRow(
                    set: $exercise.sets[index],
                    setNumber: index + 1,
                    isBodyweight: exercise.isBodyweight,
                    onDelete: {
                        if exercise.sets.count > 1 {
                            exercise.sets.remove(at: index)
                        }
                    }
                )
            }

            // Add set button
            Button {
                let lastSet = exercise.sets.last
                exercise.sets.append(ParsedSet(
                    setNumber: exercise.sets.count + 1,
                    reps: lastSet?.reps ?? 10,
                    weight: lastSet?.weight ?? 0,
                    unit: lastSet?.unit ?? .lbs
                ))
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PreviewSetRow: View {
    @Binding var set: ParsedSet
    let setNumber: Int
    let isBodyweight: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Spacer()

            // Reps
            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                Text("reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Weight (only for weighted exercises)
            if !isBodyweight {
                HStack(spacing: 4) {
                    TextField("0", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)

                    Picker("", selection: $set.unit) {
                        Text("lbs").tag(WeightUnit.lbs)
                        Text("kg").tag(WeightUnit.kg)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Weekly Tally View

struct WeeklyTallyView: View {
    let count: Int
    let goal: Int

    private var isComplete: Bool {
        count >= goal
    }

    var body: some View {
        HStack(spacing: 16) {
            // Tally marks container
            ZStack {
                if isComplete {
                    // Celebration state - filled orange circle
                    Circle()
                        .fill(Color.rallyOrange)
                        .frame(width: 70, height: 70)

                    // White tally marks
                    TallyMarksView(count: min(count, 5), color: .white)
                        .frame(width: 40, height: 40)
                } else {
                    // Progress state - ring with orange tallies
                    Circle()
                        .stroke(Color.rallyOrange.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(count) / CGFloat(goal))
                        .stroke(Color.rallyOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    // Orange tally marks
                    TallyMarksView(count: count, color: .rallyOrange)
                        .frame(width: 35, height: 35)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("This Week")
                        .font(.headline)

                    if isComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.rallyOrange)
                            .font(.subheadline)
                    }
                }

                Text(isComplete ? "Goal reached!" : "\(count) of \(goal) workouts")
                    .font(.caption)
                    .foregroundColor(isComplete ? .rallyOrange : .secondary)
            }

            Spacer()

            if isComplete {
                // Fire emoji for celebration
                Text("🔥")
                    .font(.title)
            }
        }
        .padding()
        .background(
            isComplete
                ? Color.rallyOrange.opacity(0.1)
                : Color(.secondarySystemBackground)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComplete ? Color.rallyOrange.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Tally Marks View

struct TallyMarksView: View {
    let count: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let spacing = geo.size.width / 6
            let strokeWidth: CGFloat = 3

            ZStack {
                // Draw vertical lines (up to 4)
                ForEach(0..<min(count, 4), id: \.self) { index in
                    Rectangle()
                        .fill(color)
                        .frame(width: strokeWidth, height: geo.size.height * 0.8)
                        .offset(x: CGFloat(index) * spacing - geo.size.width / 3)
                }

                // Draw diagonal line for 5th mark
                if count >= 5 {
                    Rectangle()
                        .fill(color)
                        .frame(width: strokeWidth, height: geo.size.height)
                        .rotationEffect(.degrees(-50))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: self, to: now)

        if let days = components.day, days > 0 {
            return days == 1 ? "Yesterday" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    RecordWorkoutView()
        .modelContainer(for: Workout.self, inMemory: true)
}
