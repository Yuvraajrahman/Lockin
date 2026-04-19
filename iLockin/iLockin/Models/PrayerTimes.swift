import Foundation
import SwiftData

/// Daily prayer times fetched from Aladhan, cached for 24h offline use.
@Model
final class PrayerTimes {
    /// YYYYMMDD key for the day these timings apply to.
    var dayKey: Int
    var city: String
    var country: String
    /// Each value is "HH:mm" in 24h local time (as returned by Aladhan).
    var fajr: String
    var sunrise: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
    var fetchedAt: Date

    init(
        dayKey: Int,
        city: String,
        country: String,
        fajr: String,
        sunrise: String,
        dhuhr: String,
        asr: String,
        maghrib: String,
        isha: String,
        fetchedAt: Date = .now
    ) {
        self.dayKey = dayKey
        self.city = city
        self.country = country
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.fetchedAt = fetchedAt
    }

    /// All 5 prayers in order with display labels.
    var ordered: [(name: String, time: String, icon: String)] {
        [
            ("Fajr",    fajr,    "sunrise.fill"),
            ("Dhuhr",   dhuhr,   "sun.max.fill"),
            ("Asr",     asr,     "sun.haze.fill"),
            ("Maghrib", maghrib, "sunset.fill"),
            ("Isha",    isha,    "moon.stars.fill")
        ]
    }

    /// Convert "HH:mm" to minutes-from-midnight, or nil if malformed.
    static func minutes(from hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1].prefix(2)) else { return nil }
        return h * 60 + m
    }
}
