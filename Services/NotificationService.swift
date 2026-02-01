import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let messages = [
        "Time to crush it! Your muscles are waiting.",
        "Rest day? Nah. Let's get after it!",
        "Your future self will thank you. Let's go!",
        "Gains don't build themselves. Rally up!",
        "Drop and give me... a solid workout!",
        "Iron therapy session starts now.",
        "Consistency beats intensity. Show up today!",
        "You didn't come this far to only come this far.",
        "Excuses don't burn calories. Let's rally!",
        "Today's workout is tomorrow's strength."
    ]

    func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                self.scheduleDailyNotification()
            }
        }
    }

    func scheduleDailyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_workout_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Rally"
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        content.body = messages[dayOfYear % messages.count]
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_workout_reminder", content: content, trigger: trigger)

        center.add(request)
    }
}
