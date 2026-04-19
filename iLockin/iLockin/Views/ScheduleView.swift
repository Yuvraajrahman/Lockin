import SwiftUI
import SwiftData

/// Vertical list of today's time-blocked schedule cards.
struct ScheduleView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var dashboard: DashboardViewModel
    @Query private var blocks: [DailyBlock]

    var body: some View {
        let sorted = dashboard.sortedBlocks(blocks)

        VStack(alignment: .leading, spacing: 14) {
            ILSectionTitle(text: "Today's Schedule", glyph: "calendar")

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(sorted) { block in
                        BlockCard(block: block, minuteOfDay: dashboard.minuteOfDay, todayKey: dashboard.todayKey) {
                            toggleComplete(block)
                        }
                    }
                    if sorted.isEmpty {
                        ILCard {
                            Text("No blocks yet. Add some in Settings.")
                                .font(Theme.displayFont(14, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func toggleComplete(_ block: DailyBlock) {
        let today = dashboard.todayKey
        block.lastCompletedDay = (block.lastCompletedDay == today) ? 0 : today
        try? context.save()
    }
}

private struct BlockCard: View {
    let block: DailyBlock
    let minuteOfDay: Int
    let todayKey: Int
    var onToggle: () -> Void

    var body: some View {
        let status = block.status(forMinute: minuteOfDay)
        let progress = block.progress(forMinute: minuteOfDay)
        let completedToday = block.lastCompletedDay == todayKey

        ILCard(isActive: status == .active) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.black)
                        .frame(width: 56, height: 56)
                    ILGlyph(name: block.iconName, size: 26, active: status != .upcoming || completedToday)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(block.title)
                            .font(Theme.displayFont(16, weight: .black))
                            .foregroundStyle(Theme.textPrimary)
                        if completedToday {
                            Text("DONE")
                                .font(Theme.displayFont(10, weight: .black))
                                .tracking(1.5)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.orange))
                        } else if status == .active {
                            Text("NOW")
                                .font(Theme.displayFont(10, weight: .black))
                                .tracking(1.5)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.orange))
                        }
                        Spacer()
                        Text("\(DashboardViewModel.formatMinute(block.startMinute)) – \(DashboardViewModel.formatMinute((block.startMinute + block.durationMinutes) % 1440))")
                            .font(Theme.monoFont(12))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        Text("\(block.durationMinutes) min")
                            .font(Theme.displayFont(11, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.textSecondary)
                        Text("•")
                            .foregroundStyle(Theme.textSecondary)
                        Text(block.category.displayName.uppercased())
                            .font(Theme.displayFont(11, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.textSecondary)
                        if block.isPrayerGenerated {
                            Text("• AUTO")
                                .font(Theme.displayFont(11, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(Theme.orange.opacity(0.8))
                        }
                    }

                    // Progress bar – only meaningful for the active block.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(status == .done || completedToday ? Theme.orange.opacity(0.5) : Theme.orange)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 5)
                    .padding(.top, 4)
                }

                Button(action: onToggle) {
                    Image(systemName: completedToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(completedToday ? Theme.orange : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}
