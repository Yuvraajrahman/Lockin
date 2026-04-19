import Foundation
import SwiftData
import Combine
import OSLog

/// Centralizes runtime state for the dashboard:
/// - current minute-of-day clock that ticks every second
/// - active/next block resolution
/// - first-launch seeding of habits + default schedule
@MainActor
final class DashboardViewModel: ObservableObject {
    private let log = Logger(subsystem: "com.rogue.ilockin", category: "DashboardVM")

    @Published var now: Date = .now
    @Published var minuteOfDay: Int = DashboardViewModel.minutes(from: .now)
    @Published var todayKey: Int = DayKey.today()

    private var timer: Timer?

    init() {
        // Tick every second; we only care about minute resolution but the clock
        // header in the dashboard updates seconds.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.now = .now
                let m = Self.minutes(from: self.now)
                if m != self.minuteOfDay { self.minuteOfDay = m }
                let k = DayKey.today()
                if k != self.todayKey { self.todayKey = k }
            }
        }
    }

    deinit { timer?.invalidate() }

    static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Sorted blocks for "today" – we sort by start minute (and then order).
    func sortedBlocks(_ all: [DailyBlock]) -> [DailyBlock] {
        all.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute { return lhs.startMinute < rhs.startMinute }
            return lhs.order < rhs.order
        }
    }

    func activeBlock(in blocks: [DailyBlock]) -> DailyBlock? {
        blocks.first { $0.status(forMinute: minuteOfDay) == .active }
    }

    func nextBlock(in blocks: [DailyBlock]) -> DailyBlock? {
        blocks.first { $0.status(forMinute: minuteOfDay) == .upcoming }
    }

    // MARK: - Seeding

    /// Idempotent: seeds default habits + default schedule on first launch.
    func seedIfNeeded(context: ModelContext, settings: AppSettings) {
        guard !settings.didSeedDefaults else { return }
        seedHabits(context: context)
        seedStreaks(context: context)
        seedDefaultSchedule(context: context)
        settings.didSeedDefaults = true
        try? context.save()
    }

    private func seedHabits(context: ModelContext) {
        let defaults: [(String, String)] = [
            ("Wake 5AM", "sunrise.fill"),
            ("Home Workout", "figure.strengthtraining.traditional"),
            ("Quran", "book.closed.fill"),
            ("2h Walk", "figure.walk"),
            ("Night Study", "moon.stars.fill"),
            ("Typing AM", "keyboard.fill"),
            ("Typing PM", "keyboard.fill"),
            ("Programming AM", "chevron.left.forwardslash.chevron.right"),
            ("Programming PM", "chevron.left.forwardslash.chevron.right"),
            ("Reading", "books.vertical.fill")
        ]
        for (idx, h) in defaults.enumerated() {
            context.insert(Habit(name: h.0, iconName: h.1, order: idx))
        }
    }

    private func seedStreaks(context: ModelContext) {
        let defaults: [(String, String, String)] = [
            ("typing", "Typing", "keyboard.fill"),
            ("workout", "Workout", "figure.strengthtraining.traditional"),
            ("programming", "Programming", "chevron.left.forwardslash.chevron.right")
        ]
        for d in defaults { context.insert(Streak(key: d.0, displayName: d.1, iconName: d.2)) }
    }

    private func seedDefaultSchedule(context: ModelContext) {
        for (idx, t) in DefaultSchedule.template.enumerated() {
            let block = DailyBlock(
                title: t.title,
                startMinute: t.startMinute,
                durationMinutes: t.durationMinutes,
                iconName: t.category.defaultIcon,
                notes: "",
                order: idx,
                category: t.category,
                isPrayerGenerated: false
            )
            context.insert(block)
        }
    }

    /// Format minutes-from-midnight as "HH:mm".
    static func formatMinute(_ m: Int) -> String {
        let h = (m / 60) % 24
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    /// Format a Date as "EEE, MMM d • HH:mm:ss".
    static func formatNow(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d • HH:mm:ss"
        return f.string(from: d)
    }
}

// MARK: - Default Schedule Template

/// Hardcoded fallback schedule (also mirrored in Resources/DefaultSchedule.json).
/// Times are wall-clock minutes-from-midnight (e.g. 5*60 = 300 = 05:00).
enum DefaultSchedule {
    struct Item {
        let title: String
        let startMinute: Int
        let durationMinutes: Int
        let category: BlockCategory
    }

    static let template: [Item] = [
        Item(title: "Wake + Coffee",                startMinute:  5*60 +  0, durationMinutes: 30, category: .wake),
        Item(title: "Morning Home Workout",         startMinute:  5*60 + 30, durationMinutes: 30, category: .workout),
        Item(title: "Quran + Pronunciation",        startMinute:  6*60 +  0, durationMinutes: 45, category: .reading),
        Item(title: "Morning Touch Typing",         startMinute:  6*60 + 45, durationMinutes: 20, category: .typing),
        Item(title: "Morning Programming Practice", startMinute:  7*60 + 10, durationMinutes: 45, category: .programming),
        Item(title: "Deep Work",                    startMinute:  8*60 +  0, durationMinutes: 4*60, category: .programming),
        // Maghrib walk + Isha night-study are inserted automatically by PrayerVM.
        Item(title: "Evening Touch Typing",         startMinute: 21*60 +  0, durationMinutes: 20, category: .typing),
        Item(title: "Evening Programming Practice", startMinute: 21*60 + 20, durationMinutes: 45, category: .programming),
        Item(title: "Reading + Light Stretch",      startMinute: 22*60 + 30, durationMinutes: 60, category: .reading),
        Item(title: "Sleep",                        startMinute: 23*60 + 30, durationMinutes: 30, category: .sleep)
    ]
}
