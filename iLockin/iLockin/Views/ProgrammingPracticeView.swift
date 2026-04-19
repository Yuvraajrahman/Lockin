import SwiftUI
import SwiftData

/// Simple programming-practice timer with a notes field for "What I practiced today".
struct ProgrammingPracticeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgrammingSession.date, order: .reverse) private var sessions: [ProgrammingSession]

    @State private var targetMinutes: Int = 45
    @State private var elapsed: TimeInterval = 0
    @State private var startedAt: Date?
    @State private var isRunning = false
    @State private var note: String = ""

    private var remaining: TimeInterval {
        max(0, TimeInterval(targetMinutes * 60) - elapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(alignment: .top, spacing: 18) {
                ILCard(isActive: isRunning) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("DURATION")
                            .font(Theme.displayFont(11, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textSecondary)
                        if isRunning {
                            Text(format(remaining))
                                .font(Theme.monoFont(56, weight: .black))
                                .foregroundStyle(Theme.orange)
                        } else {
                            HStack(spacing: 8) {
                                ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                                    Button { targetMinutes = m } label: {
                                        Text("\(m)m")
                                            .font(Theme.displayFont(13, weight: .black))
                                            .frame(width: 54, height: 38)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(targetMinutes == m ? Theme.orange : Theme.black)
                                            )
                                            .foregroundStyle(targetMinutes == m ? .black : Theme.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        HStack {
                            if isRunning {
                                ILSecondaryButton(title: "Stop & Save", icon: "stop.fill") { stop(save: true) }
                                ILSecondaryButton(title: "Cancel", icon: "xmark") { stop(save: false) }
                            } else {
                                ILPrimaryButton(title: "Start \(targetMinutes) min", icon: "play.fill") { start() }
                            }
                        }
                    }
                }
                .frame(maxWidth: 360)

                ILCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WHAT I PRACTICED TODAY")
                            .font(Theme.displayFont(11, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textSecondary)
                        TextEditor(text: $note)
                            .font(Theme.displayFont(14, weight: .medium))
                            .scrollContentBackground(.hidden)
                            .background(Theme.black)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minHeight: 180)
                            .overlay(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text("e.g. LeetCode #200 (DFS), refactored auth flow, read SwiftData docs…")
                                        .font(Theme.displayFont(13, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                                        .padding(.top, 8).padding(.leading, 6)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
            }

            ILCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECENT SESSIONS")
                        .font(Theme.displayFont(11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Theme.textSecondary)
                    if sessions.isEmpty {
                        Text("No sessions yet. Start your first today.")
                            .font(Theme.displayFont(12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(sessions.prefix(8)) { s in
                            HStack(alignment: .top, spacing: 12) {
                                Text(s.date.formatted(.dateTime.month().day().hour().minute()))
                                    .font(Theme.monoFont(11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 110, alignment: .leading)
                                Text("\(s.durationMinutes) min")
                                    .font(Theme.displayFont(12, weight: .heavy))
                                    .foregroundStyle(Theme.orange)
                                    .frame(width: 60, alignment: .leading)
                                Text(s.note.isEmpty ? "—" : s.note)
                                    .font(Theme.displayFont(12, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(minWidth: 760, minHeight: 700)
        .background(Theme.black)
        .iLockinBackground()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning, let s = startedAt else { return }
            elapsed = Date().timeIntervalSince(s)
            if remaining <= 0 { stop(save: true) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PROGRAMMING PRACTICE")
                    .font(Theme.displayFont(12, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Build the portfolio. Daily reps.")
                    .font(Theme.displayFont(28, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.textSecondary)
            }.buttonStyle(.plain)
        }
    }

    private func start() {
        startedAt = .now
        elapsed = 0
        isRunning = true
    }

    private func stop(save: Bool) {
        isRunning = false
        if save, elapsed > 5 {
            let session = ProgrammingSession(
                date: .now,
                durationMinutes: max(1, Int(elapsed / 60)),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            context.insert(session)
            if let streak = (try? context.fetch(FetchDescriptor<Streak>(predicate: #Predicate { $0.key == "programming" })))?.first {
                streak.markCompleted()
            }
            try? context.save()
            note = ""
        }
        elapsed = 0
        startedAt = nil
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
