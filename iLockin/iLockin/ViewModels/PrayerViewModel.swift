import Foundation
import SwiftData
import OSLog

/// Owns the lifecycle of fetching/caching prayer times and propagating
/// time changes into the schedule (Maghrib walk + Isha night-study blocks).
@MainActor
final class PrayerViewModel: ObservableObject {
    private let log = Logger(subsystem: "com.rogue.ilockin", category: "PrayerVM")
    @Published private(set) var todayTimings: PrayerTimes?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    /// Fetch today's prayer times if cache is older than today, then sync prayer-derived blocks.
    func refreshIfNeeded(context: ModelContext, settings: AppSettings, force: Bool = false) async {
        let today = DayKey.today()
        if !force, settings.lastPrayerFetchDay == today, let cached = loadCached(context: context, dayKey: today) {
            todayTimings = cached
            syncPrayerBlocks(in: context, with: cached, settings: settings)
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let timings = try await PrayerService.fetchToday(
                city: settings.prayerCity,
                country: settings.prayerCountry,
                method: settings.prayerMethod
            )
            // Replace any prior record for this day.
            let dayKey = today
            let existing = try context.fetch(FetchDescriptor<PrayerTimes>(predicate: #Predicate { $0.dayKey == dayKey }))
            for old in existing { context.delete(old) }
            context.insert(timings)
            settings.lastPrayerFetchDay = today
            try? context.save()
            todayTimings = timings
            lastError = nil
            syncPrayerBlocks(in: context, with: timings, settings: settings)
        } catch {
            // Fall back to most recent cached value if available.
            if let last = loadMostRecentCached(context: context) {
                todayTimings = last
                syncPrayerBlocks(in: context, with: last, settings: settings)
            }
            lastError = error.localizedDescription
            log.error("Prayer fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadCached(context: ModelContext, dayKey: Int) -> PrayerTimes? {
        let descriptor = FetchDescriptor<PrayerTimes>(predicate: #Predicate { $0.dayKey == dayKey })
        return (try? context.fetch(descriptor))?.first
    }

    private func loadMostRecentCached(context: ModelContext) -> PrayerTimes? {
        var d = FetchDescriptor<PrayerTimes>(sortBy: [SortDescriptor(\.dayKey, order: .reverse)])
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    /// Insert/refresh the auto-generated DailyBlocks for each prayer plus the
    /// post-Maghrib walk and post-Isha night-study blocks.
    func syncPrayerBlocks(in context: ModelContext, with t: PrayerTimes, settings: AppSettings) {
        let descriptor = FetchDescriptor<DailyBlock>(predicate: #Predicate { $0.isPrayerGenerated == true })
        let existing = (try? context.fetch(descriptor)) ?? []
        for old in existing { context.delete(old) }

        // Each prayer is a 15-minute block.
        let prayerDuration = 15
        let prayers: [(name: String, time: String, icon: String)] = t.ordered

        for prayer in prayers {
            guard let m = PrayerTimes.minutes(from: prayer.time) else { continue }
            let block = DailyBlock(
                title: "\(prayer.name) Prayer",
                startMinute: m,
                durationMinutes: prayerDuration,
                iconName: prayer.icon,
                notes: "Auto-inserted",
                order: 1000 + m,
                category: .prayer,
                isPrayerGenerated: true
            )
            context.insert(block)
        }

        if let mag = PrayerTimes.minutes(from: t.maghrib) {
            let walk = DailyBlock(
                title: "Walk (post-Maghrib)",
                startMinute: (mag + prayerDuration) % 1440,
                durationMinutes: settings.walkBlockMinutes,
                iconName: BlockCategory.walk.defaultIcon,
                notes: "2-hour walking block",
                order: 1100 + mag,
                category: .walk,
                isPrayerGenerated: true
            )
            context.insert(walk)
        }
        if let isha = PrayerTimes.minutes(from: t.isha) {
            let study = DailyBlock(
                title: "Night Study",
                startMinute: (isha + prayerDuration) % 1440,
                durationMinutes: settings.nightStudyMinutes,
                iconName: BlockCategory.study.defaultIcon,
                notes: "1-hour study session",
                order: 1200 + isha,
                category: .study,
                isPrayerGenerated: true
            )
            context.insert(study)
        }

        try? context.save()
    }

    /// Returns "(name, minutesUntil)" for the next prayer after `now` minute-of-day.
    func nextPrayer(after now: Int) -> (name: String, time: String, minutesUntil: Int)? {
        guard let t = todayTimings else { return nil }
        let candidates: [(String, Int, String)] = t.ordered.compactMap { p in
            guard let m = PrayerTimes.minutes(from: p.time) else { return nil }
            return (p.name, m, p.time)
        }
        if let next = candidates.first(where: { $0.1 > now }) {
            return (next.0, next.2, next.1 - now)
        }
        if let first = candidates.first {
            // Wrap to tomorrow's first prayer.
            return (first.0, first.2, (1440 - now) + first.1)
        }
        return nil
    }
}
