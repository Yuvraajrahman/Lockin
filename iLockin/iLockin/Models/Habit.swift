import Foundation
import SwiftData

/// A daily habit the user wants to build.
/// Completion history is stored as a Set of YYYYMMDD ints for compact storage
/// and trivial GitHub-style calendar rendering.
@Model
final class Habit {
    var id: UUID
    var name: String
    var iconName: String
    var order: Int
    /// Days completed, encoded as YYYYMMDD ints (e.g. 20260419).
    var completedDays: [Int]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "flame.fill",
        order: Int = 0,
        completedDays: [Int] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.order = order
        self.completedDays = completedDays
        self.createdAt = createdAt
    }

    func isCompleted(on day: Int) -> Bool { completedDays.contains(day) }

    func toggle(on day: Int) {
        if let idx = completedDays.firstIndex(of: day) {
            completedDays.remove(at: idx)
        } else {
            completedDays.append(day)
        }
    }

    /// Current consecutive-day streak ending today (or yesterday if today not done yet).
    func currentStreak(today: Int) -> Int {
        let set = Set(completedDays)
        var cursor = today
        var streak = 0
        // Allow today to be incomplete without breaking the streak.
        if !set.contains(cursor) {
            cursor = DayKey.previous(cursor)
        }
        while set.contains(cursor) {
            streak += 1
            cursor = DayKey.previous(cursor)
        }
        return streak
    }
}

/// Helper for YYYYMMDD integer day keys.
enum DayKey {
    static func today(_ now: Date = .now, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    static func date(from key: Int, calendar: Calendar = .current) -> Date? {
        var c = DateComponents()
        c.year = key / 10_000
        c.month = (key / 100) % 100
        c.day = key % 100
        return calendar.date(from: c)
    }

    static func previous(_ key: Int, calendar: Calendar = .current) -> Int {
        guard let d = date(from: key, calendar: calendar),
              let p = calendar.date(byAdding: .day, value: -1, to: d) else { return key }
        let c = calendar.dateComponents([.year, .month, .day], from: p)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
