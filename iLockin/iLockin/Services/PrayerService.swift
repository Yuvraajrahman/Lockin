import Foundation
import OSLog

/// Fetches daily prayer times from the public Aladhan API and decodes them.
/// Caching/persistence is handled by `PrayerViewModel` against SwiftData.
enum PrayerService {
    private static let log = Logger(subsystem: "com.rogue.ilockin", category: "PrayerService")

    struct AladhanResponse: Decodable {
        struct Data: Decodable {
            struct Timings: Decodable {
                let Fajr: String
                let Sunrise: String
                let Dhuhr: String
                let Asr: String
                let Maghrib: String
                let Isha: String
            }
            let timings: Timings
        }
        let code: Int
        let status: String
        let data: Data
    }

    /// Fetch today's timings for the given city/country/method.
    /// Throws on network error or non-2xx response.
    static func fetchToday(
        city: String,
        country: String,
        method: Int = 2,
        session: URLSession = .shared
    ) async throws -> PrayerTimes {
        var components = URLComponents(string: "https://api.aladhan.com/v1/timingsByCity")!
        components.queryItems = [
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "method", value: String(method))
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            log.error("Aladhan returned non-2xx for \(city, privacy: .public)")
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
        let t = decoded.data.timings

        return PrayerTimes(
            dayKey: DayKey.today(),
            city: city,
            country: country,
            fajr: stripTimezone(t.Fajr),
            sunrise: stripTimezone(t.Sunrise),
            dhuhr: stripTimezone(t.Dhuhr),
            asr: stripTimezone(t.Asr),
            maghrib: stripTimezone(t.Maghrib),
            isha: stripTimezone(t.Isha)
        )
    }

    /// Fetch timings for a specific calendar day (`dayKey` is YYYYMMDD).
    static func fetchForDayKey(
        _ dayKey: Int,
        city: String,
        country: String,
        method: Int = 2,
        session: URLSession = .shared
    ) async throws -> PrayerTimes {
        guard let dateStr = aladhanDatePathSegment(dayKey: dayKey) else {
            throw URLError(.badURL)
        }
        var components = URLComponents(string: "https://api.aladhan.com/v1/timingsByCity/\(dateStr)")!
        components.queryItems = [
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "method", value: String(method))
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            log.error("Aladhan returned non-2xx for dated city request")
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
        let t = decoded.data.timings

        return PrayerTimes(
            dayKey: dayKey,
            city: city,
            country: country,
            fajr: stripTimezone(t.Fajr),
            sunrise: stripTimezone(t.Sunrise),
            dhuhr: stripTimezone(t.Dhuhr),
            asr: stripTimezone(t.Asr),
            maghrib: stripTimezone(t.Maghrib),
            isha: stripTimezone(t.Isha)
        )
    }

    /// Aladhan path segment `DD-MM-YYYY` for `timingsByCity/:date`.
    private static func aladhanDatePathSegment(dayKey: Int, calendar: Calendar = .current) -> String? {
        guard let date = DayKey.date(from: dayKey, calendar: calendar) else { return nil }
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        guard let day = c.day, let month = c.month, let year = c.year else { return nil }
        return String(format: "%02d-%02d-%04d", day, month, year)
    }

    /// Aladhan often returns "HH:mm (TZN)"; we want plain "HH:mm".
    private static func stripTimezone(_ s: String) -> String {
        if let space = s.firstIndex(of: " ") {
            return String(s[..<space])
        }
        return s
    }
}
