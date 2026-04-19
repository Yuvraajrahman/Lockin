import SwiftUI
import SwiftData
import Charts

/// 20-min typing trainer. Counts WPM + accuracy live, picks random quotes
/// (Quran translations + self-improvement), records sessions for the history graph.
struct TypingTrainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TypingSession.date) private var sessions: [TypingSession]

    @State private var prompt: String = TypingTrainerView.quotes.randomElement() ?? ""
    @State private var typed: String = ""
    @State private var startedAt: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var isRunning = false
    @FocusState private var inputFocused: Bool

    /// Default 20 minute session.
    private let sessionLength: TimeInterval = 20 * 60

    private var wpm: Double {
        guard elapsed > 0 else { return 0 }
        let words = Double(typed.split(whereSeparator: \.isWhitespace).count)
        return (words / elapsed) * 60.0
    }

    private var accuracy: Double {
        guard !typed.isEmpty else { return 100 }
        let zipped = zip(typed, prompt)
        let correct = zipped.reduce(0) { $0 + ($1.0 == $1.1 ? 1 : 0) }
        return Double(correct) / Double(typed.count) * 100.0
    }

    private var remaining: TimeInterval {
        max(0, sessionLength - elapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            ILCard(isActive: isRunning) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(prompt)
                        .font(Theme.monoFont(18, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(6)

                    Divider().background(Color.white.opacity(0.06))

                    // Reuse a TextEditor so multi-line typing works.
                    TextEditor(text: $typed)
                        .font(Theme.monoFont(18, weight: .bold))
                        .scrollContentBackground(.hidden)
                        .background(Theme.black)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minHeight: 160)
                        .focused($inputFocused)
                        .disabled(!isRunning)
                        .overlay(alignment: .topLeading) {
                            if typed.isEmpty {
                                Text(isRunning ? "Start typing…" : "Press START to begin a 20-minute session.")
                                    .font(Theme.monoFont(16))
                                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
                                    .padding(.top, 8).padding(.leading, 6)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }

            HStack(spacing: 14) {
                MetricTile(label: "WPM",      value: String(format: "%.0f", wpm))
                MetricTile(label: "ACCURACY", value: String(format: "%.0f%%", accuracy))
                MetricTile(label: "TIME LEFT", value: TypingTrainerView.formatRemaining(remaining))
            }

            HStack(spacing: 10) {
                if isRunning {
                    ILSecondaryButton(title: "Stop & Save", icon: "stop.fill") { stop(save: true) }
                    ILSecondaryButton(title: "Cancel",      icon: "xmark")     { stop(save: false) }
                } else {
                    ILPrimaryButton(title: "Start 20 min Session", icon: "play.fill") { start() }
                }
                Spacer()
                ILSecondaryButton(title: "New Quote", icon: "shuffle") {
                    prompt = TypingTrainerView.quotes.randomElement() ?? prompt
                    typed = ""
                }
            }

            historyChart
        }
        .padding(28)
        .frame(minWidth: 700, minHeight: 700)
        .background(Theme.black)
        .iLockinBackground()
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning, let start = startedAt else { return }
            elapsed = Date().timeIntervalSince(start)
            if elapsed >= sessionLength { stop(save: true) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TYPING TRAINER")
                    .font(Theme.displayFont(12, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Lock In. Hit 100 WPM.")
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

    @ViewBuilder
    private var historyChart: some View {
        if !sessions.isEmpty {
            ILCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WPM HISTORY")
                        .font(Theme.displayFont(11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Theme.textSecondary)
                    Chart(sessions) { s in
                        LineMark(x: .value("Date", s.date), y: .value("WPM", s.wpm))
                            .foregroundStyle(Theme.orange)
                        PointMark(x: .value("Date", s.date), y: .value("WPM", s.wpm))
                            .foregroundStyle(Theme.orange)
                    }
                    .frame(height: 140)
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel().foregroundStyle(Theme.textSecondary)
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func start() {
        typed = ""
        startedAt = .now
        elapsed = 0
        isRunning = true
        inputFocused = true
    }

    private func stop(save: Bool) {
        isRunning = false
        inputFocused = false
        if save, !typed.isEmpty {
            let session = TypingSession(
                date: .now,
                wpm: wpm,
                accuracy: accuracy,
                durationSeconds: Int(elapsed)
            )
            context.insert(session)

            if let streak = (try? context.fetch(FetchDescriptor<Streak>(predicate: #Predicate { $0.key == "typing" })))?.first {
                streak.markCompleted()
            }
            try? context.save()
        }
        typed = ""
        elapsed = 0
        startedAt = nil
    }

    static func formatRemaining(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Mix of Quran translations and self-improvement quotes.
    static let quotes: [String] = [
        "Indeed, with hardship comes ease. With every difficulty there is relief, and after every storm there is calm.",
        "Discipline is choosing between what you want now and what you want most. Show up daily, even when you do not feel like it.",
        "And when My servants ask you concerning Me, indeed I am near. I respond to the call of the caller when they call upon Me.",
        "We rise by lifting others. We grow by demanding more of ourselves than anyone else ever could.",
        "Verily in the remembrance of Allah do hearts find rest. Patience is beautiful when you trust the timing of your life.",
        "Small daily improvements over time lead to stunning results. Compound interest is the eighth wonder of the world.",
        "Do not lose hope, nor be sad. You will surely be victorious if you are true believers. Keep moving forward.",
        "The strongest among you is the one who controls his anger and remains calm under pressure. Master yourself first.",
        "Energy and persistence conquer all things. Focus on the process, not the prize, and the prize will come.",
        "And whoever puts their trust in Allah, He will be sufficient for them. Work hard, then leave the rest."
    ]
}

private struct MetricTile: View {
    let label: String
    let value: String
    var body: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Theme.displayFont(10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(Theme.displayFont(28, weight: .black))
                    .foregroundStyle(Theme.orange)
            }
        }
    }
}
