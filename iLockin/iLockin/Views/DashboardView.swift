import SwiftUI
import SwiftData

/// The main full-screen dashboard shown the moment the user logs in.
/// Layout: header → 60/40 split (schedule / GitHub) → bottom action bar with habits.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var prayerVM: PrayerViewModel
    @EnvironmentObject private var githubVM: GitHubViewModel

    @Query private var allSettings: [AppSettings]
    @Query(sort: \Streak.key) private var streaks: [Streak]

    @State private var sheet: ActiveSheet?

    private var settings: AppSettings {
        if let s = allSettings.first { return s }
        let s = AppSettings()
        context.insert(s)
        try? context.save()
        return s
    }

    var body: some View {
        VStack(spacing: 18) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 28)

            HStack(alignment: .top, spacing: 18) {
                ScheduleView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                GitHubPanelView(settings: settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 28)

            bottomBar
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
        }
        .frame(minWidth: 1280, minHeight: 800)
        .background(Theme.black.ignoresSafeArea())
        .iLockinBackground()
        .task {
            dashboardVM.seedIfNeeded(context: context, settings: settings)
            await prayerVM.refreshIfNeeded(context: context, settings: settings)
            await githubVM.refreshIfNeeded(context: context, settings: settings)
        }
        .sheet(item: $sheet) { which in
            sheetContent(for: which)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 24) {
            HStack(spacing: 10) {
                ILGlyph(name: "lock.fill", size: 30)
                Text("iLOCKIN")
                    .font(Theme.displayFont(28, weight: .black))
                    .tracking(4)
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            // Next prayer countdown
            if let next = prayerVM.nextPrayer(after: dashboardVM.minuteOfDay) {
                HStack(spacing: 8) {
                    ILGlyph(name: "moon.stars.fill", size: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT PRAYER")
                            .font(Theme.displayFont(9, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(next.name) • \(next.time) • in \(formatCountdown(next.minutesUntil))")
                            .font(Theme.displayFont(12, weight: .black))
                            .foregroundStyle(Theme.orange)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.dark))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }

            // Live clock
            VStack(alignment: .trailing, spacing: 2) {
                Text(DashboardViewModel.formatNow(dashboardVM.now).uppercased())
                    .font(Theme.monoFont(13, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                Text(timeOnly(dashboardVM.now))
                    .font(Theme.monoFont(28, weight: .black))
                    .foregroundStyle(Theme.orange)
            }

            Button { sheet = .settings } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.dark))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HabitListView()

            HStack(spacing: 10) {
                ILPrimaryButton(title: "Start Typing", icon: "keyboard.fill") { sheet = .typing }
                ILPrimaryButton(title: "Start Workout", icon: "figure.strengthtraining.traditional") { sheet = .workout }
                ILPrimaryButton(title: "Start Programming", icon: "chevron.left.forwardslash.chevron.right") { sheet = .programming }
                ILSecondaryButton(title: "Mark All Habits", icon: "checkmark.seal.fill") { markAllHabits() }
            }

            // Streak flames row.
            if !streaks.isEmpty {
                HStack(spacing: 14) {
                    ForEach(streaks) { streak in
                        StreakBadge(streak: streak, today: dashboardVM.todayKey)
                    }
                    Spacer()
                }
            }
        }
    }

    private func markAllHabits() {
        let descriptor = FetchDescriptor<Habit>()
        let all = (try? context.fetch(descriptor)) ?? []
        let today = dashboardVM.todayKey
        for habit in all where !habit.isCompleted(on: today) {
            habit.toggle(on: today)
        }
        try? context.save()
    }

    // MARK: - Sheets

    private enum ActiveSheet: Identifiable {
        case typing, workout, programming, settings
        var id: Int { hashValue }
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .typing:      TypingTrainerView()
        case .workout:     WorkoutRoutineView()
        case .programming: ProgrammingPracticeView()
        case .settings:    SettingsView()
        }
    }

    // MARK: - Formatting helpers

    private func formatCountdown(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func timeOnly(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}

private struct StreakBadge: View {
    let streak: Streak
    let today: Int

    var body: some View {
        let count = streak.currentStreak(today: today)
        HStack(spacing: 6) {
            ILGlyph(name: "flame.fill", size: 14, active: count > 0)
            Text("\(streak.displayName.uppercased()) \(count)")
                .font(Theme.displayFont(11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(count > 0 ? Theme.orange : Theme.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.dark))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
