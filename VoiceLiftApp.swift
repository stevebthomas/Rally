import SwiftUI
import SwiftData

@main
struct VoiceLiftApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true

    // Create a shared model container
    let modelContainer: ModelContainer

    init() {
        // Initialize the model container explicitly
        do {
            let schema = Schema([Workout.self, Exercise.self, ExerciseSet.self, WorkoutMedia.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Tab bar and nav bar appearance is configured in ContentView with glass effect
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    WelcomeView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                } else if !hasCompletedOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                        .onAppear {
                            NotificationService.shared.scheduleDailyNotification()
                        }
                }
            }
            .preferredColorScheme(.dark)  // Force dark mode throughout the app
        }
        .modelContainer(modelContainer)
    }
}
