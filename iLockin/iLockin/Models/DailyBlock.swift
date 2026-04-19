import Foundation
import SwiftData

/// A time-blocked unit in the user's daily schedule.
/// Stores wall-clock minutes (0–1439) so it represents a recurring daily block,
/// not a one-off date. Status is derived at runtime from the current time.
@Model
final class DailyBlock {
    /// Stable id (used for ordering, sync, and diffing).
    var id: UUID
    /// Display title, e.g. "Morning Workout".
    var title: String
    /// Minutes from midnight when the block starts (0..<1440).
    var startMinute: Int
    /// Duration in minutes.
    var durationMinutes: Int
    /// SF Symbol name used as a glyph icon.
    var iconName: String
    /// Optional notes / description.
    var notes: String
    /// Sort order within the day (lower = earlier in list).
    var order: Int
    /// Category – used to route the block to a trainer view if needed.
    var categoryRaw: String
    /// True when this block was injected from the prayer service and
    /// should be auto-refreshed daily.
    var isPrayerGenerated: Bool
    /// True when the user has manually marked this block done today.
    /// `lastCompletedDay` is the YYYYMMDD integer of the day it was completed.
    var lastCompletedDay: Int

    init(
        id: UUID = UUID(),
        title: String,
        startMinute: Int,
        durationMinutes: Int,
        iconName: String = "circle.fill",
        notes: String = "",
        order: Int = 0,
        category: BlockCategory = .general,
        isPrayerGenerated: Bool = false,
        lastCompletedDay: Int = 0
    ) {
        self.id = id
        self.title = title
        self.startMinute = max(0, min(1439, startMinute))
        self.durationMinutes = max(1, durationMinutes)
        self.iconName = iconName
        self.notes = notes
        self.order = order
        self.categoryRaw = category.rawValue
        self.isPrayerGenerated = isPrayerGenerated
        self.lastCompletedDay = lastCompletedDay
    }

    var category: BlockCategory {
        get { BlockCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    var endMinute: Int { (startMinute + durationMinutes) % 1440 }

    /// Status given a wall-clock minute-of-day.
    func status(forMinute now: Int) -> BlockStatus {
        let end = startMinute + durationMinutes
        if now < startMinute { return .upcoming }
        if now >= startMinute && now < end { return .active }
        return .done
    }

    /// 0...1 progress through the block at `now`, or 0/1 outside the window.
    func progress(forMinute now: Int) -> Double {
        let end = startMinute + durationMinutes
        if now <= startMinute { return 0 }
        if now >= end { return 1 }
        return Double(now - startMinute) / Double(durationMinutes)
    }
}

enum BlockStatus: String { case upcoming, active, done }

enum BlockCategory: String, CaseIterable, Identifiable, Codable {
    case general
    case prayer
    case workout
    case programming
    case typing
    case study
    case reading
    case walk
    case wake
    case sleep

    var id: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .general:    return "circle.grid.2x2.fill"
        case .prayer:     return "moon.stars.fill"
        case .workout:    return "figure.strengthtraining.traditional"
        case .programming:return "chevron.left.forwardslash.chevron.right"
        case .typing:     return "keyboard.fill"
        case .study:      return "book.closed.fill"
        case .reading:    return "books.vertical.fill"
        case .walk:       return "figure.walk"
        case .wake:       return "sun.max.fill"
        case .sleep:      return "bed.double.fill"
        }
    }

    var displayName: String {
        switch self {
        case .general:    return "General"
        case .prayer:     return "Prayer"
        case .workout:    return "Workout"
        case .programming:return "Programming"
        case .typing:     return "Typing"
        case .study:      return "Study"
        case .reading:    return "Reading"
        case .walk:       return "Walk"
        case .wake:       return "Wake"
        case .sleep:      return "Sleep"
        }
    }
}
