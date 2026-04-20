import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .iLockinCheckFajrAlarm, object: nil)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier.hasPrefix("ilockin.fajr") {
            Task { @MainActor in AlarmSession.shared.presentFajrAlarm() }
        }
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier.hasPrefix("ilockin.fajr") {
            Task { @MainActor in AlarmSession.shared.presentFajrAlarm() }
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let iLockinCheckFajrAlarm = Notification.Name("iLockinCheckFajrAlarm")
}
