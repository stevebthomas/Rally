import SwiftUI
import SwiftData
import PhotosUI

/// Main view for recording and logging workouts via voice
struct RecordWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("userName") private var userName = ""
    @AppStorage("weeklyWorkoutGoal") private var weeklyGoal: Int = 5
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
    @State private var savedWorkout: Workout?
    @State private var navigateToWorkout = false

    // Text input state
    @State private var textInput = ""
    @State private var isTextInputFocused = false
    @FocusState private var textFieldFocused: Bool

    // Media state
    @State private var mediaItems: [MediaItem] = []
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []

    // Confirmation dialogs
    @State private var showingEndSessionConfirmation = false

    // AI Recommendations
    @State private var recommendations: [ExerciseRecommendation] = []
    @State private var showRecommendations = true

    // Weekly breakdown sheet
    @State private var showingWeeklyBreakdown = false

    // Track which exercise suggestion index for each muscle group (for cycling through options)
    @State private var muscleSuggestionIndex: [MuscleGroup: Int] = [:]

    // Services
    private let whisperService = WhisperService()
    private let recommendationService = ExerciseRecommendationService.shared
    private let speechService = SpeechRecognitionService()
    private let llmParser = LLMWorkoutParser()  // New hybrid parser
    private let offlineParser = OfflineWorkoutParser()

    // Quick-add exercises
    private let quickExercises = ["Bench Press", "Squat", "Deadlift", "Pull Ups", "Shoulder Press", "Rows"]

    // Computed properties for stats
    private var workoutsThisWeek: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 1  // 1 = Sunday

        // Get start of current week (Sunday)
        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let startOfWeek = calendar.date(from: components) else { return 0 }

        // Count unique workout DAYS, not total workouts
        let filtered = workouts.filter { $0.date >= startOfWeek }
        let uniqueDays = Set(filtered.map { Calendar.current.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    // Get workouts list for this week (for breakdown view)
    private var workoutsThisWeekList: [Workout] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1  // 1 = Sunday

        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let startOfWeek = calendar.date(from: components) else { return [] }

        return workouts.filter { $0.date >= startOfWeek }
    }

    /// Check if user is new (less than 3 workouts logged)
    private var isNewUser: Bool {
        workouts.count < 3
    }

    /// Check if user has moderate experience (3-10 workouts)
    private var isModerateUser: Bool {
        workouts.count >= 3 && workouts.count < 10
    }

    /// Get muscle groups sorted by how long since they were last worked
    private var neglectedMuscleGroups: [(muscle: MuscleGroup, daysSince: Int?)] {
        let allMuscles: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes, .calves, .core]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var muscleLastWorked: [MuscleGroup: Date] = [:]

        // Find the most recent date each muscle was worked
        for workout in workouts {
            let workoutDay = calendar.startOfDay(for: workout.date)
            for exercise in workout.exercises {
                for muscle in exercise.primaryMuscles {
                    if muscleLastWorked[muscle] == nil || workoutDay > muscleLastWorked[muscle]! {
                        muscleLastWorked[muscle] = workoutDay
                    }
                }
            }
        }

        // Calculate days since each muscle was worked
        let result = allMuscles.map { muscle -> (muscle: MuscleGroup, daysSince: Int?) in
            if let lastWorked = muscleLastWorked[muscle] {
                let days = calendar.dateComponents([.day], from: lastWorked, to: today).day ?? 0
                return (muscle, days)
            } else {
                return (muscle, nil) // Never worked
            }
        }

        // Sort: never worked first (nil), then by most days since
        return result.sorted { a, b in
            switch (a.daysSince, b.daysSince) {
            case (nil, nil): return a.muscle.rawValue < b.muscle.rawValue
            case (nil, _): return true
            case (_, nil): return false
            case let (daysA?, daysB?): return daysA > daysB
            }
        }
    }

    /// Get the top neglected muscle groups (ones that need attention)
    private var topNeglectedMuscles: [(muscle: MuscleGroup, daysSince: Int?)] {
        Array(neglectedMuscleGroups.prefix(4))
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
        isSessionActive || audioRecorder.isRecording || isTranscribing || !parsedExercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background adapts to light/dark mode - pure white/black
                    Color.appBackground
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

                            // AI Recommendations
                            if shouldShowUpPosition && showRecommendations {
                                recommendationsSection
                                    .transition(.opacity)
                            }

                            // Parsed exercises shown immediately
                            if !parsedExercises.isEmpty {
                                liveExercisesSection
                            }

                            // End workout button
                            if !parsedExercises.isEmpty && !isParsing {
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

                                // Combined voice + text input
                                combinedInputSection

                                // Quick-add exercise chips
                                quickAddSection

                                // Neglected body parts recommendations (only if user has some workout history)
                                if !isNewUser {
                                    neglectedMusclesSection
                                }

                                // Recent Workouts section (last 3 workouts)
                                if !workouts.isEmpty {
                                    recentWorkoutsSection
                                }

                                // Stats & Recent Activity (weekly progress)
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
            .alert("End Workout?", isPresented: $showingEndSessionConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("End Without Saving", role: .destructive) {
                    resetSession()
                }
            } message: {
                Text("You haven't saved your workout yet. Are you sure you want to end this session? Your progress will be lost.")
            }
            .sheet(isPresented: $showingPreview) {
                WorkoutPreviewSheet(
                    exercises: $parsedExercises,
                    mediaItems: $mediaItems,
                    workouts: workouts,
                    onSave: saveWorkout,
                    onCancel: { showingPreview = false }
                )
            }
            .navigationDestination(isPresented: $navigateToWorkout) {
                if let workout = savedWorkout {
                    WorkoutSummaryView(workout: workout, workouts: workouts)
                }
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
                Text("\(parsedExercises.count) exercise\(parsedExercises.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            Button("End Session") {
                showingEndSessionConfirmation = true
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Recording Section (shown when session is active - compact design)

    private var recordingSection: some View {
        VStack(spacing: 12) {
            // Compact input row: mic button + text field
            HStack(spacing: 12) {
                // Mic button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.rallyOrange)
                            .frame(width: 50, height: 50)

                        if audioRecorder.isRecording {
                            // Pulsing animation for recording
                            Circle()
                                .stroke(Color.red.opacity(0.5), lineWidth: 3)
                                .frame(width: 50 + (CGFloat(audioRecorder.recordingLevel) * 20), height: 50 + (CGFloat(audioRecorder.recordingLevel) * 20))
                                .animation(.easeInOut(duration: 0.1), value: audioRecorder.recordingLevel)
                        }

                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .disabled(isTranscribing || isParsing)

                // Text input field
                HStack {
                    TextField("Add exercise (e.g. 3x10 135lb Bench)", text: $textInput)
                        .textFieldStyle(.plain)
                        .focused($textFieldFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            submitTextInput()
                        }

                    if !textInput.isEmpty {
                        Button(action: submitTextInput) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.rallyOrange)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(25)
            }

            // Status indicator (only when something is happening)
            if audioRecorder.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Recording \(audioRecorder.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else if isTranscribing || isParsing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            // Permission request if needed
            if !audioRecorder.permissionGranted {
                Button {
                    audioRecorder.requestPermission()
                } label: {
                    HStack {
                        Image(systemName: "mic.slash")
                        Text("Enable microphone")
                    }
                    .font(.caption)
                    .foregroundColor(.rallyOrange)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - AI Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Suggested Exercises")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    updateRecommendations()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            if recommendations.isEmpty {
                Text("Add an exercise to get suggestions")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recommendations) { rec in
                            RecommendationChip(
                                recommendation: rec,
                                onTap: {
                                    addRecommendedExercise(rec.name)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            updateRecommendations()
        }
        .onChange(of: parsedExercises.count) { _, _ in
            updateRecommendations()
        }
    }

    private func updateRecommendations() {
        recommendations = recommendationService.getRecommendations(
            currentExercises: parsedExercises,
            recentWorkouts: Array(workouts.prefix(10)),
            limit: 6
        )
    }

    private func addRecommendedExercise(_ name: String) {
        // Create a basic exercise with default set
        let newExercise = ParsedExercise(
            name: name,
            sets: [ParsedSet(setNumber: 1, reps: 10, weight: 0, unit: .lbs)],
            category: nil,
            equipment: .other,
            primaryMuscles: []
        )
        parsedExercises.append(newExercise)

        // Activate session if not already
        if !isSessionActive {
            isSessionActive = true
        }

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Transcriptions Section (kept for backwards compatibility)

    private var transcriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recorded Exercises")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    showingEndSessionConfirmation = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }

            ForEach(sessionTranscriptions.indices, id: \.self) { index in
                TranscriptionCard(
                    index: index + 1,
                    text: $sessionTranscriptions[index],
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

    // MARK: - Live Exercises Section (shows parsed exercises immediately)

    private var liveExercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Workout")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    showingEndSessionConfirmation = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }

            // Stats summary
            HStack {
                StatBox(
                    title: "Exercises",
                    value: "\(parsedExercises.count)",
                    icon: "figure.strengthtraining.traditional"
                )
                StatBox(
                    title: "Total Sets",
                    value: "\(parsedExercises.reduce(0) { $0 + $1.sets.count })",
                    icon: "number"
                )
                StatBox(
                    title: "Total Reps",
                    value: "\(parsedExercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } })",
                    icon: "repeat"
                )
            }

            // Exercise cards
            ForEach(parsedExercises.indices, id: \.self) { index in
                LiveExerciseCard(
                    exercise: $parsedExercises[index],
                    onDelete: {
                        parsedExercises.remove(at: index)
                        if parsedExercises.isEmpty {
                            isSessionActive = false
                        }
                    }
                )
            }

            // Media section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MediaPickerButton(
                        selectedItems: $selectedPhotosPickerItems,
                        mediaData: $mediaItems
                    )
                    Spacer()
                }

                if !mediaItems.isEmpty {
                    MediaPreviewGrid(mediaItems: $mediaItems)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Large RALLY logo at the top
            Image("RallyLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

            // Motivational message below the logo
            VStack(spacing: 6) {
                Text(motivationalPhrase)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                Text(timeBasedMessage)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 20)
        }
    }

    // 30 motivational phrases - not corny
    private var motivationalPhrase: String {
        let phrases = [
            "Build the body you want",
            "Consistency beats perfection",
            "Earn your rest",
            "Stronger than yesterday",
            "Trust the process",
            "Progress over perfection",
            "Show up for yourself",
            "Discipline is freedom",
            "Your only limit is you",
            "Make it count",
            "One rep at a time",
            "Results take time",
            "Stay committed",
            "Push your limits",
            "Train with purpose",
            "Respect the grind",
            "Be relentless",
            "Work in silence",
            "Outwork your doubts",
            "Control what you can",
            "Focus on the process",
            "Embrace the challenge",
            "Keep showing up",
            "Build momentum",
            "No shortcuts",
            "Raise your standard",
            "Effort is everything",
            "Stay locked in",
            "Do the work",
            "Prove yourself right"
        ]
        // Use the day of year to rotate through phrases
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return phrases[dayOfYear % phrases.count]
    }

    private var timeBasedMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 5 && hour < 9 {
            return "Early bird gets the gains"
        } else if hour >= 9 && hour < 12 {
            return "Perfect time to train"
        } else if hour >= 12 && hour < 14 {
            return "Midday pump session"
        } else if hour >= 14 && hour < 17 {
            return "Afternoon power hour"
        } else if hour >= 17 && hour < 21 {
            return "Evening iron time"
        } else if hour >= 21 || hour < 1 {
            return "Late night grind"
        } else {
            return "Night owl training"
        }
    }

    // MARK: - Combined Input Section (Voice + Text)

    private var combinedInputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Mic button
                Button {
                    if audioRecorder.permissionGranted {
                        toggleRecording()
                    } else {
                        audioRecorder.requestPermission()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.rallyOrange)
                            .frame(width: 50, height: 50)

                        if audioRecorder.isRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.5), lineWidth: 3)
                                .frame(width: 50 + (CGFloat(audioRecorder.recordingLevel) * 20), height: 50 + (CGFloat(audioRecorder.recordingLevel) * 20))
                                .animation(.easeInOut(duration: 0.1), value: audioRecorder.recordingLevel)
                        }

                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .disabled(isTranscribing || isParsing)

                // Text input
                HStack {
                    TextField("3x10 135lb Bench Press", text: $textInput)
                        .textFieldStyle(.plain)
                        .focused($textFieldFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            submitTextInput()
                        }

                    if !textInput.isEmpty {
                        Button(action: submitTextInput) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.rallyOrange)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(25)
            }

            // Status text or hint
            if audioRecorder.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Recording \(audioRecorder.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else if isTranscribing || isParsing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            } else {
                Text("Type your workout here")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    // MARK: - Recent Workouts Section (Last 3 Workouts)

    /// Get last 3 workouts sorted by date (earliest first)
    private var last3WorkoutsSorted: [Workout] {
        Array(workouts.prefix(3)).sorted { $0.date < $1.date }
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)

            VStack(spacing: 12) {
                ForEach(last3WorkoutsSorted, id: \.id) { workout in
                    RecentWorkoutCard(
                        workout: workout,
                        onAddAll: { addAllExercises(from: workout) }
                    )
                }
            }
        }
    }

    private func addAllExercises(from workout: Workout) {
        for exercise in workout.exercises {
            repeatExercise(exercise)
        }

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    private func repeatExercise(_ exercise: Exercise) {
        // Calculate warm-up sets based on previous workout's weights
        let warmupSets = calculateWarmupSets(from: exercise)

        let newExercise = ParsedExercise(
            name: exercise.name,
            sets: warmupSets,
            category: exercise.category,
            equipment: exercise.equipment,
            primaryMuscles: exercise.primaryMuscles
        )

        parsedExercises.append(newExercise)

        if !isSessionActive {
            isSessionActive = true
        }

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Calculate warm-up sets based on previous workout data
    /// Returns a progressive warm-up scheme: lighter weight with higher reps to start
    private func calculateWarmupSets(from exercise: Exercise) -> [ParsedSet] {
        let sortedSets = exercise.sortedSets
        guard !sortedSets.isEmpty else {
            return [ParsedSet(setNumber: 1, reps: 10, weight: 0, unit: .lbs)]
        }

        // Find the working weight (highest weight from previous workout)
        let maxWeight = sortedSets.map { $0.weight }.max() ?? 0
        let unit = sortedSets.first?.unit ?? .lbs

        // For bodyweight exercises, just return a similar set structure
        if maxWeight == 0 {
            let avgReps = sortedSets.map { $0.reps }.reduce(0, +) / sortedSets.count
            return [ParsedSet(setNumber: 1, reps: avgReps, weight: 0, unit: unit)]
        }

        // Calculate warm-up progression
        // Round weights to nearest 5 for cleaner numbers
        let warmupWeight1 = roundToNearest5(maxWeight * 0.5)  // 50% for first warm-up
        let warmupWeight2 = roundToNearest5(maxWeight * 0.7)  // 70% for second warm-up

        var sets: [ParsedSet] = []

        // Warm-up set 1: 50% weight, 10-12 reps
        sets.append(ParsedSet(
            setNumber: 1,
            reps: 12,
            weight: warmupWeight1,
            unit: unit,
            setType: .warmup
        ))

        // Warm-up set 2: 70% weight, 8-10 reps (only if working weight is substantial)
        if maxWeight >= 50 {
            sets.append(ParsedSet(
                setNumber: 2,
                reps: 8,
                weight: warmupWeight2,
                unit: unit,
                setType: .warmup
            ))
        }

        // Working set template at previous max weight
        sets.append(ParsedSet(
            setNumber: sets.count + 1,
            reps: sortedSets.last?.reps ?? 8,
            weight: maxWeight,
            unit: unit,
            setType: .normal
        ))

        return sets
    }

    private func roundToNearest5(_ value: Double) -> Double {
        return (value / 5).rounded() * 5
    }

    // MARK: - Start Workout Button (legacy, kept for reference)

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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickExercises, id: \.self) { exercise in
                        Button {
                            addQuickExercise(exercise)
                        } label: {
                            Text(exercise)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .foregroundColor(.primaryText)
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

    // MARK: - Neglected Muscles Section

    private var neglectedMusclesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Needs Attention")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(topNeglectedMuscles, id: \.muscle) { item in
                        Button {
                            suggestExerciseForMuscle(item.muscle)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: muscleIcon(for: item.muscle))
                                    .font(.title3)
                                    .foregroundColor(.rallyOrange)

                                Text(item.muscle.rawValue.capitalized)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.primaryText)

                                Text(daysSinceText(item.daysSince))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(width: 80, height: 80)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func muscleIcon(for muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest: return "figure.arms.open"
        case .back: return "figure.walk"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.functional"
        case .quads: return "figure.run"
        case .hamstrings: return "figure.cooldown"
        case .glutes: return "figure.step.training"
        case .calves: return "figure.jumprope"
        case .core: return "figure.core.training"
        case .forearms: return "hand.raised.fingers.spread"
        case .fullBody: return "figure.mixed.cardio"
        }
    }

    private func daysSinceText(_ days: Int?) -> String {
        guard let days = days else {
            return "Never"
        }
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days)d ago"
        } else {
            let weeks = days / 7
            return "\(weeks)w ago"
        }
    }

    private func suggestExerciseForMuscle(_ muscle: MuscleGroup) {
        let exercises: [MuscleGroup: [String]] = [
            .chest: ["Bench Press", "Dumbbell Press", "Push Ups", "Incline Press"],
            .back: ["Pull Ups", "Rows", "Lat Pulldown", "Deadlift"],
            .shoulders: ["Shoulder Press", "Lateral Raises", "Face Pulls"],
            .biceps: ["Bicep Curls", "Hammer Curls", "Chin Ups"],
            .triceps: ["Tricep Pushdowns", "Skull Crushers", "Dips"],
            .quads: ["Squats", "Leg Press", "Lunges", "Leg Extensions"],
            .hamstrings: ["Romanian Deadlift", "Leg Curls", "Good Mornings"],
            .glutes: ["Hip Thrusts", "Squats", "Bulgarian Split Squats"],
            .calves: ["Calf Raises", "Seated Calf Raises"],
            .core: ["Planks", "Crunches", "Leg Raises", "Russian Twists"],
            .forearms: ["Wrist Curls", "Farmer Walks"],
            .fullBody: ["Burpees", "Deadlift", "Clean and Press"]
        ]

        guard let suggestions = exercises[muscle], !suggestions.isEmpty else { return }

        // Get current index for this muscle, cycle to next
        let currentIndex = muscleSuggestionIndex[muscle] ?? 0
        let nextIndex = (currentIndex + 1) % suggestions.count
        muscleSuggestionIndex[muscle] = nextIndex

        let exercise = suggestions[currentIndex]
        textInput = "3x10 \(exercise)"
        textFieldFocused = true
    }

    // MARK: - Stats & Recent Section

    private var statsAndRecentSection: some View {
        VStack(spacing: 16) {
            // Weekly progress with tally marks (tappable)
            WeeklyTallyView(count: workoutsThisWeek, goal: weeklyGoal)
                .onTapGesture {
                    showingWeeklyBreakdown = true
                }
                .sheet(isPresented: $showingWeeklyBreakdown) {
                    WeeklyBreakdownView(workouts: workoutsThisWeekList, goal: weeklyGoal)
                }
        }
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
                finishAndSaveWorkout()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Finish Workout")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if isParsing {
                ProgressView("Saving your workout...")
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
                    // Parse immediately and add to exercises
                    parseAndAddExercises(from: text)
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

    private func finishAndSaveWorkout() {
        guard !parsedExercises.isEmpty else { return }
        // Exercises are already parsed, just save them
        saveAndNavigate()
    }

    private func saveAndNavigate() {
        guard !parsedExercises.isEmpty else { return }

        // Build the complete object graph FIRST, then insert the root object
        // SwiftData will cascade insert related objects

        var exercisesToAdd: [Exercise] = []
        for parsedExercise in parsedExercises {
            let exercise = Exercise(
                name: parsedExercise.name,
                category: parsedExercise.category,
                equipment: parsedExercise.equipment,
                primaryMuscles: parsedExercise.primaryMuscles,
                notes: parsedExercise.notes
            )

            var setsToAdd: [ExerciseSet] = []
            for (index, parsedSet) in parsedExercise.sets.enumerated() {
                let exerciseSet = ExerciseSet(
                    setNumber: index + 1,
                    reps: parsedSet.reps,
                    weight: parsedSet.weight,
                    unit: parsedSet.unit,
                    duration: parsedSet.duration,
                    setType: parsedSet.setType,
                    rpe: parsedSet.rpe,
                    rir: parsedSet.rir,
                    restTime: parsedSet.restTime,
                    tempo: parsedSet.tempo,
                    gripType: parsedSet.gripType,
                    stanceType: parsedSet.stanceType
                )
                setsToAdd.append(exerciseSet)
            }
            exercise.sets = setsToAdd
            exercisesToAdd.append(exercise)
        }

        // Build media items
        var mediaToAdd: [WorkoutMedia] = []
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
                mediaToAdd.append(workoutMedia)
            }
        }

        // Create workout with all relationships
        let workout = Workout(
            date: Date(),
            rawTranscription: sessionTranscriptions.joined(separator: "\n---\n"),
            exercises: exercisesToAdd,
            media: mediaToAdd
        )

        // Insert ONLY the root object - SwiftData will cascade
        modelContext.insert(workout)

        // Store the saved workout BEFORE resetting state
        savedWorkout = workout

        // Explicitly save the context
        do {
            try modelContext.save()
            print("Workout saved successfully with \(workout.exercises.count) exercises")
        } catch {
            print("Failed to save workout: \(error)")
            // Show error to user
            errorMessage = "Failed to save workout: \(error.localizedDescription)"
            showingError = true
            return
        }

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        // Reset session state
        sessionTranscriptions = []
        parsedExercises = []
        mediaItems = []
        isSessionActive = false

        // Navigate to summary
        navigateToWorkout = true
    }

    private func saveWorkout() {
        guard !parsedExercises.isEmpty else { return }

        // Build the complete object graph FIRST
        var exercisesToAdd: [Exercise] = []
        for parsedExercise in parsedExercises {
            let exercise = Exercise(
                name: parsedExercise.name,
                category: parsedExercise.category,
                equipment: parsedExercise.equipment,
                primaryMuscles: parsedExercise.primaryMuscles,
                notes: parsedExercise.notes
            )

            var setsToAdd: [ExerciseSet] = []
            for (index, parsedSet) in parsedExercise.sets.enumerated() {
                let exerciseSet = ExerciseSet(
                    setNumber: index + 1,
                    reps: parsedSet.reps,
                    weight: parsedSet.weight,
                    unit: parsedSet.unit,
                    duration: parsedSet.duration,
                    setType: parsedSet.setType,
                    rpe: parsedSet.rpe,
                    rir: parsedSet.rir,
                    restTime: parsedSet.restTime,
                    tempo: parsedSet.tempo,
                    gripType: parsedSet.gripType,
                    stanceType: parsedSet.stanceType
                )
                setsToAdd.append(exerciseSet)
            }
            exercise.sets = setsToAdd
            exercisesToAdd.append(exercise)
        }

        // Build media items
        var mediaToAdd: [WorkoutMedia] = []
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
                mediaToAdd.append(workoutMedia)
            }
        }

        // Create workout with all relationships
        let workout = Workout(
            date: Date(),
            rawTranscription: sessionTranscriptions.joined(separator: "\n---\n"),
            exercises: exercisesToAdd,
            media: mediaToAdd
        )

        // Insert ONLY the root object
        modelContext.insert(workout)

        // Explicitly save the context
        do {
            try modelContext.save()
            print("Workout saved successfully via preview with \(workout.exercises.count) exercises")
        } catch {
            print("Failed to save workout: \(error)")
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
        // Stop recording if active
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
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

        // Parse immediately and add to exercises
        parseAndAddExercises(from: trimmedText)

        // Clear the text input
        textInput = ""
        textFieldFocused = false

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func parseAndAddExercises(from text: String) {
        // Parse the text immediately
        let newExercises = offlineParser.parseWorkout(transcription: text)

        // Merge with existing exercises (combine sets for same exercise)
        for newExercise in newExercises {
            if let existingIndex = parsedExercises.firstIndex(where: { $0.name.lowercased() == newExercise.name.lowercased() }) {
                // Add sets to existing exercise
                var updatedExercise = parsedExercises[existingIndex]
                let startingSetNumber = updatedExercise.sets.count + 1
                for (offset, set) in newExercise.sets.enumerated() {
                    var newSet = set
                    newSet.setNumber = startingSetNumber + offset
                    updatedExercise.sets.append(newSet)
                }
                parsedExercises[existingIndex] = updatedExercise
            } else {
                // Add as new exercise
                parsedExercises.append(newExercise)
            }
        }
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
                .foregroundColor(.secondaryText)

            Text("Microphone access is required")
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            Button("Grant Permission", action: onRequest)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Live Exercise Card (shows parsed exercise immediately)

struct LiveExerciseCard: View {
    @Binding var exercise: ParsedExercise
    let onDelete: () -> Void
    @State private var showingInfo = false
    @State private var showingNotes = false
    @State private var activeRestTimers: Set<Int> = []  // Track which rest timers are active (by set index)

    // Determine valid categories for this exercise
    private var validCategories: [ExerciseCategory] {
        // Exercises that can only be weighted (use equipment with weight)
        let weightedOnlyExercises: Set<String> = [
            "Bench Press", "Incline Bench Press", "Decline Bench Press",
            "Dumbbell Press", "Incline Dumbbell Press",
            "Squat", "Squats", "Back Squat", "Front Squat", "Leg Press",
            "Goblet Squat", "Hack Squat", "Bulgarian Split Squat",
            "Deadlift", "Romanian Deadlift", "Sumo Deadlift",
            "Barbell Row", "Barbell Curls", "Skull Crushers",
            "Shoulder Press", "Overhead Press",
            "Lat Pulldown", "Cable Row", "Cable Curls",
            "Leg Extension", "Leg Curl", "Leg Extensions", "Leg Curls",
            "Calf Raises", "Standing Calf Raises", "Seated Calf Raises",
            "Hip Thrust", "Hip Thrusts", "Barbell Hip Thrusts",
        ]

        // Exercises that can only be timed
        let timedOnlyExercises: Set<String> = [
            "Plank", "Side Plank", "Hollow Hold",
            "Dead Hang", "Towel Hangs", "L-Sit",
            "Front Lever", "Back Lever", "Wall Sit",
            "Static Holds", "Barbell Holds",
        ]

        // Exercises that can only be bodyweight
        let bodyweightOnlyExercises: Set<String> = [
            "Push Ups", "Pull Ups", "Chin Ups", "Dips",
            "Crunches", "Sit Ups", "Burpees",
            "Mountain Climbers", "Jumping Jacks",
        ]

        if weightedOnlyExercises.contains(exercise.name) {
            return [.weighted]
        } else if timedOnlyExercises.contains(exercise.name) {
            return [.timed]
        } else if bodyweightOnlyExercises.contains(exercise.name) {
            return [.bodyweight]
        }

        // Default: allow all categories
        return ExerciseCategory.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                // Exercise name (non-editable) with info button
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)

                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                }

                Spacer()

                // Exercise type picker (filtered by valid categories)
                if validCategories.count > 1 {
                    Picker("Type", selection: $exercise.category) {
                        ForEach(validCategories, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                } else {
                    // Show as label if only one option
                    Text(exercise.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            // Equipment row
            HStack(spacing: 8) {
                // Equipment picker
                Picker("Equipment", selection: $exercise.equipment) {
                    ForEach(Equipment.allCases, id: \.self) { eq in
                        Label(eq.displayName, systemImage: eq.icon).tag(eq)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: exercise.equipment) { _, newEquipment in
                    // Auto-populate weight with equipment base weight if current weight is 0
                    let equipmentService = EquipmentService.shared
                    if equipmentService.hasBaseWeight(newEquipment) {
                        let baseWeight = equipmentService.baseWeight(for: newEquipment)
                        for i in exercise.sets.indices {
                            if exercise.sets[i].weight == 0 {
                                exercise.sets[i].weight = baseWeight
                            }
                        }
                    }
                }

                Spacer()
            }

            // Validation warning banner
            if let issue = WorkoutValidationService.shared.mostSevereIssue(for: exercise) {
                HStack(spacing: 8) {
                    Image(systemName: issue.severity.icon)
                        .foregroundColor(issue.severity == .error ? .red : .orange)
                        .font(.subheadline)

                    Text(issue.message)
                        .font(.caption)
                        .foregroundColor(issue.severity == .error ? .red : .orange)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(issue.severity == .error ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                )
            }

            Divider()

            // Sets with rest timers between them
            ForEach(exercise.sets.indices, id: \.self) { index in
                LiveSetRow(
                    parsedSet: $exercise.sets[index],
                    setNumber: index + 1,
                    category: exercise.category,
                    onDelete: {
                        if exercise.sets.count > 1 {
                            exercise.sets.remove(at: index)
                            activeRestTimers.remove(index)
                        }
                    }
                )

                // Rest timer between sets (not after the last set)
                if index < exercise.sets.count - 1 {
                    RestTimerRow(
                        afterSetNumber: index + 1,
                        isActive: Binding(
                            get: { activeRestTimers.contains(index) },
                            set: { isActive in
                                if isActive {
                                    activeRestTimers.insert(index)
                                } else {
                                    activeRestTimers.remove(index)
                                }
                            }
                        )
                    )
                }
            }

            // Add set button
            Button {
                let lastSet = exercise.sets.last
                exercise.sets.append(ParsedSet(
                    setNumber: exercise.sets.count + 1,
                    reps: lastSet?.reps ?? 10,
                    weight: lastSet?.weight ?? 0,
                    unit: lastSet?.unit ?? .lbs,
                    duration: lastSet?.duration,
                    setType: lastSet?.setType ?? .normal
                ))
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundColor(.rallyOrange)
            }

            // Notes section (collapsible)
            if exercise.notes.isEmpty && !showingNotes {
                Button {
                    showingNotes = true
                } label: {
                    Label("Note", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Note")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        if exercise.notes.isEmpty {
                            Button {
                                showingNotes = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                    TextField("Add note...", text: $exercise.notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .alert("Exercise Info", isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exerciseInfoMessage)
        }
    }

    private var exerciseInfoMessage: String {
        var info = exercise.name

        if !exercise.primaryMuscles.isEmpty {
            info += "\n\nMuscles: " + exercise.primaryMuscles.map { $0.displayName }.joined(separator: ", ")
        }

        info += "\n\nEquipment: " + exercise.equipment.displayName
        info += "\nType: " + exercise.category.displayName

        return info
    }
}

struct LiveSetRow: View {
    @Binding var parsedSet: ParsedSet
    let setNumber: Int
    let category: ExerciseCategory
    let onDelete: () -> Void
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 6) {
            // Main row
            HStack {
                // Set number with type indicator
                HStack(spacing: 4) {
                    Text("Set \(setNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)

                    if parsedSet.setType != .normal {
                        Image(systemName: setTypeIcon)
                            .font(.caption2)
                            .foregroundColor(.rallyOrange)
                    }
                }
                .frame(width: 55, alignment: .leading)

                Spacer()

                // Show different inputs based on category
                if category == .timed {
                    // Duration input for timed exercises
                    HStack(spacing: 4) {
                        TextField("0", value: Binding(
                            get: { parsedSet.duration ?? 0 },
                            set: { newVal in parsedSet.duration = newVal }
                        ), format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("sec")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                } else {
                    // Reps input
                    HStack(spacing: 4) {
                        TextField("0", value: $parsedSet.reps, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 45)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("reps")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }

                    // Weight (only for weighted exercises)
                    if category == .weighted {
                        HStack(spacing: 4) {
                            TextField("0", value: $parsedSet.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 55)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)

                            Picker("", selection: $parsedSet.unit) {
                                Text("lbs").tag(WeightUnit.lbs)
                                Text("kg").tag(WeightUnit.kg)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }

                // Advanced options toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    Image(systemName: showAdvanced ? "chevron.up.circle.fill" : "slider.horizontal.3")
                        .foregroundColor(hasAdvancedData ? .rallyOrange : .secondary)
                        .font(.subheadline)
                }

                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
            }

            // Advanced options (expandable)
            if showAdvanced {
                advancedOptionsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Compact indicators for set metadata
            if !showAdvanced && hasAdvancedData {
                HStack(spacing: 8) {
                    if parsedSet.setType != .normal {
                        Text(parsedSet.setType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.rallyOrange.opacity(0.2))
                            .foregroundColor(.rallyOrange)
                            .cornerRadius(4)
                    }
                    if let tempo = parsedSet.tempo {
                        Text(tempo)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                    if let grip = parsedSet.gripType, grip != .standard {
                        Text(grip.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.teal.opacity(0.2))
                            .foregroundColor(.teal)
                            .cornerRadius(4)
                    }
                    if let stance = parsedSet.stanceType, stance != .standard {
                        Text(stance.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.2))
                            .foregroundColor(.indigo)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(.leading, 55)
            }
        }
    }

    private var advancedOptionsView: some View {
        VStack(spacing: 12) {
            // Row 1: Type and Tempo
            HStack(spacing: 16) {
                // Type
                HStack(spacing: 6) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    Menu {
                        ForEach(SetType.allCases, id: \.self) { type in
                            Button(type.displayName) {
                                parsedSet.setType = type
                            }
                        }
                    } label: {
                        Text(parsedSet.setType.displayName)
                            .font(.caption)
                            .foregroundColor(.rallyOrange)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Tempo
                HStack(spacing: 6) {
                    Text("Tempo")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    TextField("-", text: Binding(
                        get: { parsedSet.tempo ?? "" },
                        set: { newVal in parsedSet.tempo = newVal.isEmpty ? nil : newVal }
                    ))
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.caption)
                }
            }

            // Row 2: Grip and Stance
            HStack(spacing: 16) {
                // Grip
                HStack(spacing: 6) {
                    Text("Grip")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    Menu {
                        ForEach(GripType.allCases, id: \.self) { grip in
                            Button(grip.displayName) {
                                parsedSet.gripType = grip == .standard ? nil : grip
                            }
                        }
                    } label: {
                        Text((parsedSet.gripType ?? .standard).displayName)
                            .font(.caption)
                            .foregroundColor(.rallyOrange)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Stance
                HStack(spacing: 6) {
                    Text("Stance")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    Menu {
                        ForEach(StanceType.allCases, id: \.self) { stance in
                            Button(stance.displayName) {
                                parsedSet.stanceType = stance == .standard ? nil : stance
                            }
                        }
                    } label: {
                        Text((parsedSet.stanceType ?? .standard).displayName)
                            .font(.caption)
                            .foregroundColor(.rallyOrange)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private var hasAdvancedData: Bool {
        parsedSet.tempo != nil || (parsedSet.gripType != nil && parsedSet.gripType != .standard) ||
        (parsedSet.stanceType != nil && parsedSet.stanceType != .standard) || parsedSet.setType != .normal
    }

    private var setTypeIcon: String {
        switch parsedSet.setType {
        case .normal: return ""
        case .warmup: return "flame"
        case .dropSet: return "arrow.down"
        case .superset: return "arrow.triangle.2.circlepath"
        case .restPause: return "pause.circle"
        case .amrap: return "infinity"
        case .toFailure: return "exclamationmark.triangle"
        case .cluster: return "circle.grid.3x3"
        }
    }
}

struct TranscriptionCard: View {
    let index: Int
    @Binding var text: String
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top) {
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .frame(width: 24)

            if isEditing {
                TextField("Exercise", text: $editText)
                    .font(.body)
                    .focused($isFocused)
                    .onSubmit {
                        saveEdit()
                    }
                    .submitLabel(.done)
            } else {
                Text(text)
                    .font(.body)
                    .onTapGesture {
                        startEditing()
                    }
            }

            Spacer()

            if isEditing {
                Button {
                    saveEdit()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else {
                Button {
                    startEditing()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.rallyOrange)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private func startEditing() {
        editText = text
        isEditing = true
        isFocused = true
    }

    private func saveEdit() {
        if !editText.trimmingCharacters(in: .whitespaces).isEmpty {
            text = editText
        }
        isEditing = false
        isFocused = false
    }
}

// MARK: - Workout Preview Sheet

struct WorkoutPreviewSheet: View {
    @Binding var exercises: [ParsedExercise]
    @Binding var mediaItems: [MediaItem]
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    let workouts: [Workout]  // For ghost set comparison
    let onSave: () -> Void
    let onCancel: () -> Void

    // Computed ghost data
    private var ghostExercises: [String: GhostSetService.GhostExercise] {
        GhostSetService.fetchGhostExercises(
            named: exercises.map { $0.name },
            from: workouts
        )
    }

    // Workout progression summary
    private var progressionSummary: GhostSetService.WorkoutProgressionSummary {
        GhostSetService.getWorkoutProgressionSummary(
            exercises: exercises,
            from: workouts
        )
    }

    // Check if any set is a PR
    private var hasPR: Bool {
        for exercise in exercises {
            if let ghost = ghostExercises[exercise.name.lowercased()] {
                for (index, set) in exercise.sets.enumerated() {
                    if index < ghost.sets.count {
                        let comparison = GhostSetService.compareSet(current: set, ghost: ghost.sets[index])
                        if comparison.isPersonalBest { return true }
                    }
                }
            }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // PR Celebration
                    if hasPR {
                        PersonalBestIndicator()
                            .padding(.bottom, 8)
                    }

                    // Workout Progression Insights
                    if !exercises.filter({ $0.category == .weighted }).isEmpty {
                        WorkoutProgressionCard(summary: progressionSummary)
                    }

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

                    // Exercises with ghost sets
                    ForEach(exercises.indices, id: \.self) { index in
                        EditableParsedExerciseCard(
                            exercise: $exercises[index],
                            ghostExercise: ghostExercises[exercises[index].name.lowercased()],
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
                            .foregroundColor(.secondaryText)

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
            .background(Color.appBackground)
            .navigationTitle("Review Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct EditableParsedExerciseCard: View {
    @Binding var exercise: ParsedExercise
    let ghostExercise: GhostSetService.GhostExercise?
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
                .fixedSize()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            // Ghost exercise header (if available)
            if let ghost = ghostExercise {
                GhostExerciseHeader(ghostExercise: ghost)
            }

            Divider()

            // Sets with ghost comparison
            ForEach(exercise.sets.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    PreviewSetRow(
                        set: $exercise.sets[index],
                        setNumber: index + 1,
                        isBodyweight: exercise.isBodyweight,
                        ghostSet: ghostExercise?.sets.indices.contains(index) == true ? ghostExercise?.sets[index] : nil,
                        onDelete: {
                            if exercise.sets.count > 1 {
                                exercise.sets.remove(at: index)
                            }
                        }
                    )
                }
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
    let ghostSet: GhostSetService.GhostSet?
    let onDelete: () -> Void

    private var comparison: GhostSetService.SetComparison? {
        guard let ghost = ghostSet else { return nil }
        return GhostSetService.compareSet(current: set, ghost: ghost)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Set \(setNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
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
                        .foregroundColor(.secondaryText)
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

                // E1RM comparison badge
                if let comparison = comparison {
                    E1RMComparisonBadge(comparison: comparison)
                }

                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
            }

            // Ghost set reference
            if let ghost = ghostSet {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Last: \(ghost.displayString)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .padding(.leading, 50)
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

                    // White fitness icon
                    FitnessIconView(color: .white)
                } else {
                    // Progress state - ring with fitness icon
                    Circle()
                        .stroke(Color.rallyOrange.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(count) / CGFloat(goal))
                        .stroke(Color.rallyOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    // Orange fitness icon
                    FitnessIconView(color: .rallyOrange)
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

// MARK: - Fitness Icon View (replaces tally marks)

struct FitnessIconView: View {
    let color: Color

    // Fitness equipment icons that rotate daily
    private let fitnessIcons = [
        "dumbbell.fill",
        "figure.strengthtraining.traditional",
        "figure.highintensity.intervaltraining",
        "figure.core.training",
        "scalemass.fill",
        "figure.run",
        "figure.cross.training",
        "figure.mixed.cardio",
        "figure.flexibility"
    ]

    // Get a consistent icon for today based on day of year
    private var todaysIcon: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % fitnessIcons.count
        return fitnessIcons[index]
    }

    var body: some View {
        Image(systemName: todaysIcon)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(color)
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

// MARK: - Workout Summary View (shown after saving)

struct WorkoutSummaryView: View {
    let workout: Workout
    let workouts: [Workout]
    @Environment(\.dismiss) private var dismiss

    private var progressionSummary: GhostSetService.WorkoutProgressionSummary {
        // Convert saved exercises to ParsedExercise format for progression calculation
        let parsedExercises = workout.exercises.map { exercise in
            ParsedExercise(
                name: exercise.name,
                sets: exercise.sets.map { set in
                    ParsedSet(
                        setNumber: set.setNumber,
                        reps: set.reps,
                        weight: set.weight,
                        unit: set.unit
                    )
                },
                category: exercise.category
            )
        }
        return GhostSetService.getWorkoutProgressionSummary(
            exercises: parsedExercises,
            from: workouts
        )
    }

    // Check if any set is a PR
    private var hasPR: Bool {
        let parsedExercises = workout.exercises.map { exercise in
            ParsedExercise(
                name: exercise.name,
                sets: exercise.sets.map { set in
                    ParsedSet(setNumber: set.setNumber, reps: set.reps, weight: set.weight, unit: set.unit)
                },
                category: exercise.category
            )
        }

        let ghostExercises = GhostSetService.fetchGhostExercises(
            named: parsedExercises.map { $0.name },
            from: workouts
        )

        for exercise in parsedExercises {
            if let ghost = ghostExercises[exercise.name.lowercased()] {
                for (index, set) in exercise.sets.enumerated() {
                    if index < ghost.sets.count {
                        let comparison = GhostSetService.compareSet(current: set, ghost: ghost.sets[index])
                        if comparison.isPersonalBest { return true }
                    }
                }
            }
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Success header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Workout Saved!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(workout.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding(.top, 20)

                // PR Celebration
                if hasPR {
                    PersonalBestIndicator()
                }

                // Workout Progression Insights
                if !workout.exercises.filter({ $0.category == .weighted }).isEmpty {
                    WorkoutProgressionCard(summary: progressionSummary)
                }

                // Stats
                HStack {
                    StatBox(
                        title: "Exercises",
                        value: "\(workout.exerciseCount)",
                        icon: "figure.strengthtraining.traditional"
                    )
                    StatBox(
                        title: "Total Sets",
                        value: "\(workout.totalSets)",
                        icon: "number"
                    )
                    StatBox(
                        title: "Total Reps",
                        value: "\(workout.totalReps)",
                        icon: "repeat"
                    )
                }

                // Volume stat (if weighted exercises)
                if workout.totalVolume > 0 {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.rallyOrange)
                        Text("Total Volume")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text("\(Int(workout.totalVolume)) lbs")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Exercises breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercises")
                        .font(.headline)

                    ForEach(workout.exercises, id: \.id) { exercise in
                        ExerciseSummaryCard(exercise: exercise)
                    }
                }

                Spacer().frame(height: 20)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct ExerciseSummaryCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    if exercise.equipment != .other && exercise.equipment != .bodyweight {
                        Text(exercise.equipment.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    Text(exercise.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.rallyOrange.opacity(0.1))
                        .foregroundColor(.rallyOrange)
                        .cornerRadius(4)
                }
            }

            ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Set \(set.setNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            if set.setType != .normal {
                                Text(set.setType.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.rallyOrange.opacity(0.2))
                                    .foregroundColor(.rallyOrange)
                                    .cornerRadius(3)
                            }
                        }
                        Spacer()
                        if exercise.category == .timed {
                            Text("\(set.duration ?? 0) sec")
                                .font(.subheadline)
                        } else if exercise.category == .bodyweight {
                            Text("\(set.reps) reps")
                                .font(.subheadline)
                        } else {
                            Text("\(set.reps) reps × \(Int(set.weight)) \(set.unit.rawValue)")
                                .font(.subheadline)
                        }
                    }

                    // Phase 2 indicators
                    if hasPhase2Data(set) {
                        HStack(spacing: 6) {
                            if let rpe = set.rpe {
                                Text("RPE \(rpe)")
                                    .font(.caption2)
                                    .foregroundColor(rpeColor(rpe))
                            }
                            if let rir = set.rir {
                                Text("RIR \(rir)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            if let tempo = set.tempo {
                                Text(tempo)
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                            }
                            if let grip = set.gripType, grip != .standard {
                                Text(grip.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.teal)
                            }
                            if let rest = set.restTime {
                                Text("\(rest)s rest")
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func hasPhase2Data(_ exerciseSet: ExerciseSet) -> Bool {
        exerciseSet.rpe != nil || exerciseSet.rir != nil || exerciseSet.tempo != nil ||
        exerciseSet.restTime != nil || (exerciseSet.gripType != nil && exerciseSet.gripType != .standard) ||
        (exerciseSet.stanceType != nil && exerciseSet.stanceType != .standard)
    }

    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...5: return .green
        case 6...7: return .yellow
        case 8...9: return .orange
        case 10: return .red
        default: return .gray
        }
    }
}

struct RecommendationChip: View {
    let recommendation: ExerciseRecommendation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: recommendation.icon)
                        .font(.caption2)
                        .foregroundColor(iconColor)
                    Text(recommendation.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                }
                Text(recommendation.reason)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch recommendation.type {
        case .complementary: return .rallyOrange
        case .frequent: return .yellow
        case .variety: return .purple
        }
    }
}

// MARK: - Rest Timer Row

struct RestTimerRow: View {
    let afterSetNumber: Int
    @Binding var isActive: Bool
    @State private var timeRemaining: Int = 90  // Default 90 seconds
    @State private var timer: Timer?
    @State private var initialTime: Int = 90

    private let presetTimes = [30, 60, 90, 120, 180]

    var body: some View {
        HStack(spacing: 8) {
            // Timer icon
            Image(systemName: isActive ? "timer" : "clock")
                .font(.caption)
                .foregroundColor(isActive ? .rallyOrange : .secondary)

            if isActive {
                // Active timer display
                Text(formatTime(timeRemaining))
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundColor(timeRemaining <= 10 ? .red : .rallyOrange)

                Spacer()

                // Add/subtract time buttons
                Button {
                    timeRemaining = max(0, timeRemaining - 15)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Button {
                    timeRemaining += 15
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                // Stop button
                Button {
                    stopTimer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            } else {
                // Inactive - show "Rest" button with quick time options
                Text("Rest")
                    .font(.caption)
                    .foregroundColor(.secondaryText)

                Spacer()

                // Quick time buttons
                ForEach(presetTimes.prefix(3), id: \.self) { seconds in
                    Button {
                        startTimer(seconds: seconds)
                    } label: {
                        Text(formatTimeShort(seconds))
                            .font(.caption2)
                            .foregroundColor(.rallyOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.rallyOrange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.rallyOrange.opacity(0.1) : Color(.tertiarySystemBackground).opacity(0.5))
        .cornerRadius(6)
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startTimer(seconds: Int) {
        initialTime = seconds
        timeRemaining = seconds
        isActive = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Timer complete - haptic feedback
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isActive = false
        timeRemaining = initialTime
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatTimeShort(_ seconds: Int) -> String {
        if seconds >= 120 {
            let mins = seconds / 60
            return "\(mins)m"
        } else if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs == 0 {
                return "\(mins)m"
            } else {
                return "\(mins):\(String(format: "%02d", secs))"
            }
        }
        return "\(seconds)s"
    }
}

// MARK: - Recent Workout Card Component

struct RecentWorkoutCard: View {
    let workout: Workout
    let onAddAll: () -> Void

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.date) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.date) {
            return "Yesterday"
        } else {
            return workout.date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with date and add button
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.rallyOrange)

                Spacer()

                Button(action: onAddAll) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add All")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.rallyOrange)
                }
                .buttonStyle(.plain)
            }

            // Exercise list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(workout.exercises.prefix(4), id: \.id) { exercise in
                    HStack {
                        Text(exercise.name)
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text(exercise.summary)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }

                if workout.exercises.count > 4 {
                    Text("+\(workout.exercises.count - 4) more")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    RecordWorkoutView()
        .modelContainer(for: Workout.self, inMemory: true)
}
