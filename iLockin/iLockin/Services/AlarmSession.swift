import AppKit
import Foundation
import OSLog
import UserNotifications

/// In-app Fajr alarm: loops the user’s preferred system alert sound until dismissed.
@MainActor
final class AlarmSession: ObservableObject {
    static let shared = AlarmSession()

    private let log = Logger(subsystem: "com.rogue.ilockin", category: "Alarm")
    private static let dismissedDayKey = "iLockin.fajrAlarmDismissedDay"

    @Published private(set) var isFajrAlarmShowing = false

    private var loopingSound: NSSound?

    private init() {}

    func presentFajrAlarm() {
        guard !isFajrAlarmShowing else {
            loopingSound?.play()
            return
        }
        isFajrAlarmShowing = true
        playLoopingPreferredAlertSound()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissFajrAlarm(for todayKey: Int) {
        loopingSound?.stop()
        loopingSound = nil
        isFajrAlarmShowing = false
        UserDefaults.standard.set(todayKey, forKey: Self.dismissedDayKey)
    }

    /// Whether we should auto-open the alarm UI on this calendar day after a cold launch.
    func shouldOfferFajrAlarmOnLaunch(
        fajrMinute: Int,
        nowMinute: Int,
        todayKey: Int,
        prayerDayKey: Int?,
        windowMinutes: Int = 45
    ) -> Bool {
        guard prayerDayKey == todayKey else { return false }
        let dismissed = UserDefaults.standard.integer(forKey: Self.dismissedDayKey)
        guard dismissed != todayKey else { return false }
        if nowMinute == fajrMinute { return true }
        let start = fajrMinute
        let end = (fajrMinute + windowMinutes) % 1440
        if start <= end {
            return nowMinute >= start && nowMinute < end
        }
        return nowMinute >= start || nowMinute < end
    }

    private func playLoopingPreferredAlertSound() {
        loopingSound?.stop()
        // Bundled alert tone (same family as Finder / system alerts). Notifications use UNNotificationSound.default.
        let sound = NSSound(named: NSSound.Name("Glass"))
        sound?.loops = true
        sound?.play()
        loopingSound = sound
        if loopingSound == nil {
            NSSound.beep()
            log.error("Could not load bundled Glass alert sound")
        }
    }

    func requestNotificationAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                log.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        default:
            return false
        }
    }
}
