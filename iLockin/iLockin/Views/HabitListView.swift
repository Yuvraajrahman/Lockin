import SwiftUI
import SwiftData

/// Habits row with one-tap completion + flame streak count.
/// Used inside the dashboard footer/sidebar.
struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var dashboard: DashboardViewModel
    @Query(sort: \Habit.order) private var habits: [Habit]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ILSectionTitle(text: "Habits", glyph: "flame.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(habits) { habit in
                        HabitChip(habit: habit, today: dashboard.todayKey) {
                            habit.toggle(on: dashboard.todayKey)
                            try? context.save()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct HabitChip: View {
    let habit: Habit
    let today: Int
    var onTap: () -> Void

    var body: some View {
        let done = habit.isCompleted(on: today)
        let streak = habit.currentStreak(today: today)

        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: habit.iconName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(done ? .black : Theme.orange)
                Text(habit.name.uppercased())
                    .font(Theme.displayFont(11, weight: .black))
                    .tracking(1)
                    .foregroundStyle(done ? .black : Theme.textPrimary)
                if streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill").font(.system(size: 10, weight: .black))
                        Text("\(streak)").font(Theme.displayFont(11, weight: .black))
                    }
                    .foregroundStyle(done ? .black : Theme.orange)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(done ? Theme.orange : Theme.dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(done ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
