import Foundation
import SwiftData

/// Generic per-feature streak counter (e.g. typing sessions, workouts, programming sessions).
/// Habits track their own streaks; this model is for trainer activities.
@Model
final class Streak {
    /// Stable string key, e.g. "typing", "workout", "programming".
    @Attribute(.unique) var key: String
    var displayName: String
    var iconName: String
    /// Days the activity was completed, as YYYYMMDD ints.
    var completedDays: [Int]

    init(key: String, displayName: String, iconName: String, completedDays: [Int] = []) {
        self.key = key
        self.displayName = displayName
        self.iconName = iconName
        self.completedDays = completedDays
    }

    func markCompleted(today: Int = DayKey.today()) {
        if !completedDays.contains(today) { completedDays.append(today) }
    }

    func currentStreak(today: Int = DayKey.today()) -> Int {
        let set = Set(completedDays)
        var cursor = today
        var streak = 0
        if !set.contains(cursor) { cursor = DayKey.previous(cursor) }
        while set.contains(cursor) {
            streak += 1
            cursor = DayKey.previous(cursor)
        }
        return streak
    }
}

/// One typing-trainer session record (used for the history graph).
@Model
final class TypingSession {
    var id: UUID
    var date: Date
    var wpm: Double
    var accuracy: Double
    var durationSeconds: Int

    init(id: UUID = UUID(), date: Date = .now, wpm: Double, accuracy: Double, durationSeconds: Int) {
        self.id = id
        self.date = date
        self.wpm = wpm
        self.accuracy = accuracy
        self.durationSeconds = durationSeconds
    }
}

/// One programming-practice session record.
@Model
final class ProgrammingSession {
    var id: UUID
    var date: Date
    var durationMinutes: Int
    var note: String

    init(id: UUID = UUID(), date: Date = .now, durationMinutes: Int, note: String) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.note = note
    }
}

/// One workout session record.
@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var durationSeconds: Int
    /// Pipe-separated "name:reps:sets" entries for compactness.
    var exercisesEncoded: String

    init(id: UUID = UUID(), date: Date = .now, durationSeconds: Int, exercisesEncoded: String) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.exercisesEncoded = exercisesEncoded
    }
}
