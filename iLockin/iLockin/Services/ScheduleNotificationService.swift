import Foundation
import OSLog
import SwiftData
import UserNotifications

/// Registers local notifications: Fajr alarm + daily reminders for schedule blocks.
enum ScheduleNotificationService {
    private static let log = Logger(subsystem: "com.rogue.ilockin", category: "Notifications")
    private static let idPrefix = "ilockin."

    private static let fajrTodayId = "ilockin.fajr.today"
    private static let fajrTomorrowId = "ilockin.fajr.tomorrow"

    /// Removes previously scheduled iLockin requests and reinstalls from current settings + data.
    @MainActor
    static func reschedule(
        context: ModelContext,
        settings: AppSettings,
        blocks: [DailyBlock],
        prayerTimesToday: PrayerTimes?,
        authorizationAllowed: Bool
    ) async {
        guard authorizationAllowed else { return }

        registerCategories()
        await removeAllILockinPending()

        let calendar = Calendar.current
        let now = Date.now
        let todayKey = DayKey.today(now, calendar: calendar)

        if settings.fajrAlarmEnabled, let pt = prayerTimesToday, pt.dayKey == todayKey {
            await scheduleFajrAnchors(pt: pt, settings: settings, calendar: calendar, now: now)
        }

        if settings.taskNotificationsEnabled {
            scheduleTaskReminders(blocks: blocks, calendar: calendar)
        }
    }

    private static func registerCategories() {
        let center = UNUserNotificationCenter.current()
        let fajrCategory = UNNotificationCategory(
            identifier: "FAJR_ALARM",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([fajrCategory, taskCategory])
    }

    private static func removeAllILockinPending() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let ids = requests.filter { $0.identifier.hasPrefix(idPrefix) }.map(\.identifier)
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                cont.resume()
            }
        }
    }

    /// Schedules today’s Fajr (if still ahead) and tomorrow’s using the API for the next day.
    private static func scheduleFajrAnchors(
        pt: PrayerTimes,
        settings: AppSettings,
        calendar: Calendar,
        now: Date
    ) async {
        guard let fajrMin = PrayerTimes.minutes(from: pt.fajr) else { return }

        let todayKey = pt.dayKey
        if let todayFire = wallClockDate(dayKey: todayKey, minuteOfDay: fajrMin, calendar: calendar),
           todayFire.timeIntervalSince(now) > 8 {
            addFajrRequest(fireDate: todayFire, identifier: fajrTodayId)
        }

        let nextKey = DayKey.next(todayKey, calendar: calendar)
        do {
            let tomorrowPT = try await PrayerService.fetchForDayKey(
                nextKey,
                city: settings.prayerCity,
                country: settings.prayerCountry,
                method: settings.prayerMethod
            )
            guard let tm = PrayerTimes.minutes(from: tomorrowPT.fajr) else { return }
            if let tomorrowFire = wallClockDate(dayKey: nextKey, minuteOfDay: tm, calendar: calendar),
               tomorrowFire.timeIntervalSince(now) > 8 {
                addFajrRequest(fireDate: tomorrowFire, identifier: fajrTomorrowId)
            }
        } catch {
            log.error("Tomorrow Fajr fetch failed; only today may be scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func addFajrRequest(fireDate: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Fajr"
        content.body = "Open iLockin and dismiss the alarm."
        content.sound = .default
        content.categoryIdentifier = "FAJR_ALARM"

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 5 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { err in
            if let err {
                log.error("Failed to schedule Fajr: \(err.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func wallClockDate(dayKey: Int, minuteOfDay: Int, calendar: Calendar) -> Date? {
        guard let dayDate = DayKey.date(from: dayKey, calendar: calendar) else { return nil }
        let h = minuteOfDay / 60
        let m = minuteOfDay % 60
        return calendar.date(bySettingHour: h, minute: m, second: 0, of: dayDate)
    }

    /// Daily repeating reminders for user-authored blocks only (skip auto prayer/sync blocks).
    private static func scheduleTaskReminders(blocks: [DailyBlock], calendar: Calendar) {
        for block in blocks where !block.isPrayerGenerated {
            let id = taskIdentifier(for: block.id)
            var dc = DateComponents()
            dc.hour = block.startMinute / 60
            dc.minute = block.startMinute % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = block.title
            content.body = "Scheduled block starting now."
            content.sound = .default
            content.categoryIdentifier = "TASK_REMINDER"

            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { err in
                if let err {
                    log.error("Task notification failed: \(err.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private static func taskIdentifier(for blockId: UUID) -> String {
        "\(idPrefix)task.\(blockId.uuidString)"
    }
}
