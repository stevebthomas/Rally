import SwiftUI
import SwiftData

@main
struct VoiceLiftApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
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
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self, WorkoutMedia.self])
    }
}
