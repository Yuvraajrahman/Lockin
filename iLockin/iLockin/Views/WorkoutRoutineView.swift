import SwiftUI
import SwiftData

/// Simple home workout tracker: select exercises, run a session timer,
/// log reps/sets and check each exercise off.
struct WorkoutRoutineView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// User-editable list of exercises within the session.
    @State private var exercises: [WorkoutExercise] = WorkoutExercise.defaultPreset

    @State private var elapsed: TimeInterval = 0
    @State private var startedAt: Date?
    @State private var isRunning = false

    @State private var newExerciseName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(alignment: .top, spacing: 18) {
                ILCard(isActive: isRunning) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SESSION TIMER")
                            .font(Theme.displayFont(11, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textSecondary)
                        Text(WorkoutRoutineView.formatTime(elapsed))
                            .font(Theme.monoFont(56, weight: .black))
                            .foregroundStyle(Theme.orange)
                        HStack {
                            if isRunning {
                                ILSecondaryButton(title: "Stop & Save", icon: "stop.fill") { stop(save: true) }
                                ILSecondaryButton(title: "Cancel", icon: "xmark") { stop(save: false) }
                            } else {
                                ILPrimaryButton(title: "Start Workout", icon: "play.fill") { start() }
                            }
                        }
                    }
                }
                .frame(maxWidth: 320)

                ILCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ADD EXERCISE")
                            .font(Theme.displayFont(11, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textSecondary)
                        HStack {
                            TextField("e.g. Burpees", text: $newExerciseName)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.black))
                                .foregroundStyle(Theme.textPrimary)
                            Button {
                                let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                exercises.append(WorkoutExercise(name: trimmed))
                                newExerciseName = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(Theme.orange)
                            }.buttonStyle(.plain)
                        }
                        Text("Tap a row to mark complete. Edit reps/sets inline.")
                            .font(Theme.displayFont(11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            ILCard {
                VStack(spacing: 0) {
                    ForEach($exercises) { $ex in
                        ExerciseRow(exercise: $ex)
                        if ex.id != exercises.last?.id {
                            Divider().background(Color.white.opacity(0.06))
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
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKOUT ROUTINE")
                    .font(Theme.displayFont(12, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Move. Earn the day.")
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
        for i in exercises.indices { exercises[i].completed = false }
    }

    private func stop(save: Bool) {
        isRunning = false
        if save, elapsed > 5 {
            let encoded = exercises.map { "\($0.name):\($0.reps):\($0.sets)" }.joined(separator: "|")
            let session = WorkoutSession(date: .now, durationSeconds: Int(elapsed), exercisesEncoded: encoded)
            context.insert(session)
            if let streak = (try? context.fetch(FetchDescriptor<Streak>(predicate: #Predicate { $0.key == "workout" })))?.first {
                streak.markCompleted()
            }
            try? context.save()
        }
        elapsed = 0
        startedAt = nil
    }

    static func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

/// In-memory exercise structure (not persisted; the session result is encoded into WorkoutSession.exercisesEncoded).
struct WorkoutExercise: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var reps: Int = 10
    var sets: Int = 3
    var completed: Bool = false

    static let defaultPreset: [WorkoutExercise] = [
        .init(name: "Push-ups",   reps: 15, sets: 3),
        .init(name: "Squats",     reps: 20, sets: 3),
        .init(name: "Pull-ups",   reps: 8,  sets: 3),
        .init(name: "Plank (sec)", reps: 60, sets: 3),
        .init(name: "Lunges",     reps: 12, sets: 3),
        .init(name: "Sit-ups",    reps: 20, sets: 3)
    ]
}

private struct ExerciseRow: View {
    @Binding var exercise: WorkoutExercise

    var body: some View {
        HStack(spacing: 12) {
            Button { exercise.completed.toggle() } label: {
                Image(systemName: exercise.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(exercise.completed ? Theme.orange : Theme.textSecondary)
            }.buttonStyle(.plain)

            Text(exercise.name)
                .font(Theme.displayFont(15, weight: .heavy))
                .foregroundStyle(exercise.completed ? Theme.textSecondary : Theme.textPrimary)
                .strikethrough(exercise.completed, color: Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Stepper("\(exercise.reps) reps", value: $exercise.reps, in: 1...500)
                .controlSize(.small)
                .labelsHidden()
            Text("\(exercise.reps) reps")
                .font(Theme.monoFont(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .leading)

            Stepper("\(exercise.sets) sets", value: $exercise.sets, in: 1...20)
                .controlSize(.small)
                .labelsHidden()
            Text("\(exercise.sets) sets")
                .font(Theme.monoFont(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}
