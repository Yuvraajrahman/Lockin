import Foundation
import SwiftData

/// Singleton-style settings record. We always read/write the first instance.
@Model
final class AppSettings {
    var prayerCity: String
    var prayerCountry: String
    /// Aladhan calculation method id (2 = ISNA, 1 = MWL, etc.).
    var prayerMethod: Int
    /// Default GitHub username to fetch repos for. Optional; if empty, the
    /// authenticated user's repos (via PAT) are fetched.
    var githubUsername: String
    var launchAtLogin: Bool
    /// Set to true after the first launch successfully seeds defaults.
    var didSeedDefaults: Bool
    /// Last day (YYYYMMDD) we fetched/refreshed prayer times.
    var lastPrayerFetchDay: Int
    /// Last full GitHub refresh timestamp (used for 24h cache).
    var lastGithubFetchAt: Date?
    /// Walking-block duration in minutes (after Maghrib).
    var walkBlockMinutes: Int
    /// Night-study-block duration in minutes (after Isha).
    var nightStudyMinutes: Int
    /// Local notification + in-app alarm at Fajr (system default alert sound).
    var fajrAlarmEnabled: Bool?
    /// Daily repeating reminders at each schedule block start (non-auto-generated blocks only).
    var taskNotificationsEnabled: Bool?

    var isFajrAlarmEnabled: Bool {
        get { fajrAlarmEnabled ?? true }
        set { fajrAlarmEnabled = newValue }
    }

    var areTaskNotificationsEnabled: Bool {
        get { taskNotificationsEnabled ?? true }
        set { taskNotificationsEnabled = newValue }
    }

    init(
        prayerCity: String = "Dhaka",
        prayerCountry: String = "Bangladesh",
        prayerMethod: Int = 2,
        githubUsername: String = "",
        launchAtLogin: Bool = true,
        didSeedDefaults: Bool = false,
        lastPrayerFetchDay: Int = 0,
        lastGithubFetchAt: Date? = nil,
        walkBlockMinutes: Int = 120,
        nightStudyMinutes: Int = 60,
        fajrAlarmEnabled: Bool = true,
        taskNotificationsEnabled: Bool = true
    ) {
        self.prayerCity = prayerCity
        self.prayerCountry = prayerCountry
        self.prayerMethod = prayerMethod
        self.githubUsername = githubUsername
        self.launchAtLogin = launchAtLogin
        self.didSeedDefaults = didSeedDefaults
        self.lastPrayerFetchDay = lastPrayerFetchDay
        self.lastGithubFetchAt = lastGithubFetchAt
        self.walkBlockMinutes = walkBlockMinutes
        self.nightStudyMinutes = nightStudyMinutes
        self.fajrAlarmEnabled = fajrAlarmEnabled
        self.taskNotificationsEnabled = taskNotificationsEnabled
    }
}
