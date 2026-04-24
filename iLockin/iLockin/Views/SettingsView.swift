import SwiftUI
import SwiftData

/// Settings: GitHub PAT, prayer city, schedule editor (add/remove/reorder/edit times),
/// auto-launch toggle, reset-to-default.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prayerVM: PrayerViewModel
    @EnvironmentObject private var githubVM: GitHubViewModel
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var alarmSession: AlarmSession

    @Query private var allSettings: [AppSettings]
    @Query(sort: \DailyBlock.startMinute) private var blocks: [DailyBlock]

    @State private var tokenField: String = KeychainService.getGithubToken() ?? ""
    @State private var revealToken: Bool = false
    @State private var saveStatus: String?

    private var settings: AppSettings {
        allSettings.first ?? {
            let s = AppSettings()
            context.insert(s)
            return s
        }()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.06))
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    githubSection
                    prayerSection
                    notificationsSection
                    autoLaunchSection
                    scheduleSection
                    resetSection
                }
                .padding(28)
            }
        }
        .frame(minWidth: 820, minHeight: 720)
        .background(Theme.black)
        .iLockinBackground()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SETTINGS")
                    .font(Theme.displayFont(12, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Configure iLockin")
                    .font(Theme.displayFont(26, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            if let saveStatus {
                Text(saveStatus)
                    .font(Theme.displayFont(11, weight: .black))
                    .foregroundStyle(Theme.orange)
                    .tracking(1.2)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.textSecondary)
            }.buttonStyle(.plain)
        }
        .padding(28)
    }

    // MARK: - GitHub

    private var githubSection: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 12) {
                ILSectionTitle(text: "GitHub", glyph: "key.fill")
                Text("Personal Access Token (stored in Keychain)")
                    .font(Theme.displayFont(11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    Group {
                        if revealToken {
                            TextField("ghp_…", text: $tokenField)
                        } else {
                            SecureField("ghp_…", text: $tokenField)
                        }
                    }
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.black))
                    .foregroundStyle(Theme.textPrimary)

                    Button { revealToken.toggle() } label: {
                        Image(systemName: revealToken ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.orange)
                    }.buttonStyle(.plain)
                }

                Text("Optional GitHub username (used for public repos when no token)")
                    .font(Theme.displayFont(11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                TextField("yourusername", text: Binding(
                    get: { settings.githubUsername },
                    set: { settings.githubUsername = $0 }
                ))
                .textFieldStyle(.plain)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.black))
                .foregroundStyle(Theme.textPrimary)

                HStack {
                    ILPrimaryButton(title: "Save & Refresh", icon: "arrow.clockwise") {
                        KeychainService.setGithubToken(tokenField)
                        try? context.save()
                        Task {
                            await githubVM.refresh(context: context, settings: settings)
                            await flash("GitHub refreshed")
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Prayer

    private var prayerSection: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 12) {
                ILSectionTitle(text: "Prayer Times", glyph: "moon.stars.fill")
                HStack {
                    LabeledField(label: "City") {
                        TextField("Dhaka", text: Binding(
                            get: { settings.prayerCity },
                            set: { settings.prayerCity = $0 }
                        ))
                    }
                    LabeledField(label: "Country") {
                        TextField("Bangladesh", text: Binding(
                            get: { settings.prayerCountry },
                            set: { settings.prayerCountry = $0 }
                        ))
                    }
                }
                HStack {
                    LabeledField(label: "Walk minutes (post-Maghrib)") {
                        Stepper(value: Binding(
                            get: { settings.walkBlockMinutes },
                            set: { settings.walkBlockMinutes = $0 }
                        ), in: 15...240, step: 15) {
                            Text("\(settings.walkBlockMinutes) min").foregroundStyle(Theme.textPrimary)
                        }
                    }
                    LabeledField(label: "Night study minutes (post-Isha)") {
                        Stepper(value: Binding(
                            get: { settings.nightStudyMinutes },
                            set: { settings.nightStudyMinutes = $0 }
                        ), in: 15...180, step: 15) {
                            Text("\(settings.nightStudyMinutes) min").foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                HStack {
                    ILPrimaryButton(title: "Save & Fetch Prayer Times", icon: "arrow.clockwise") {
                        try? context.save()
                        Task {
                            await prayerVM.refreshIfNeeded(context: context, settings: settings, force: true)
                            await rescheduleNotificationsFromSettings()
                            await flash("Prayer times refreshed")
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 12) {
                ILSectionTitle(text: "Reminders", glyph: "bell.badge.fill")
                Toggle(isOn: Binding(
                    get: { settings.isFajrAlarmEnabled },
                    set: {
                        settings.isFajrAlarmEnabled = $0
                        try? context.save()
                        Task { await rescheduleNotificationsFromSettings() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fajr alarm")
                            .font(Theme.displayFont(13, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Notification at Fajr with default alert sound; open the app and dismiss the full-screen alarm.")
                            .font(Theme.displayFont(11, weight: .heavy))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.orange)

                Toggle(isOn: Binding(
                    get: { settings.areTaskNotificationsEnabled },
                    set: {
                        settings.areTaskNotificationsEnabled = $0
                        try? context.save()
                        Task { await rescheduleNotificationsFromSettings() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task start reminders")
                            .font(Theme.displayFont(13, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Daily notification at each schedule block start (blocks you edit here; auto-generated prayer rows are skipped).")
                            .font(Theme.displayFont(11, weight: .heavy))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.orange)
            }
        }
    }

    // MARK: - Auto-launch

    private var autoLaunchSection: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 8) {
                ILSectionTitle(text: "Launch at Login", glyph: "power")
                Toggle(isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: {
                        settings.launchAtLogin = $0
                        LaunchAtLoginService.setEnabled($0)
                        try? context.save()
                    }
                )) {
                    Text("Open iLockin automatically when I sign in")
                        .font(Theme.displayFont(13, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(Theme.orange)
            }
        }
    }

    // MARK: - Schedule editor

    private var scheduleSection: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ILSectionTitle(text: "Schedule Blocks", glyph: "calendar")
                    Spacer()
                    Button {
                        let next = (blocks.map(\.order).max() ?? 0) + 1
                        let block = DailyBlock(
                            title: "New Block",
                            startMinute: 9 * 60,
                            durationMinutes: 30,
                            iconName: BlockCategory.general.defaultIcon,
                            order: next,
                            category: .general
                        )
                        context.insert(block)
                        try? context.save()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("ADD BLOCK")
                                .font(Theme.displayFont(11, weight: .black))
                                .tracking(1.2)
                        }
                        .foregroundStyle(Theme.orange)
                    }.buttonStyle(.plain)
                }

                Text("Drag the order number to reorder. Auto-generated prayer blocks are read-only.")
                    .font(Theme.displayFont(11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)

                VStack(spacing: 8) {
                    ForEach(blocks) { block in
                        BlockEditorRow(block: block) {
                            context.delete(block)
                            try? context.save()
                        }
                        if block.id != blocks.last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 10) {
                ILSectionTitle(text: "Danger Zone", glyph: "exclamationmark.triangle.fill")
                Text("Restores the default schedule. Auto-generated prayer blocks will be re-synced on next prayer fetch.")
                    .font(Theme.displayFont(11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                ILSecondaryButton(title: "Reset to Default Schedule", icon: "arrow.counterclockwise") {
                    resetSchedule()
                }
            }
        }
    }

    private func resetSchedule() {
        for b in blocks { context.delete(b) }
        for (idx, t) in DefaultSchedule.template.enumerated() {
            context.insert(DailyBlock(
                title: t.title,
                startMinute: t.startMinute,
                durationMinutes: t.durationMinutes,
                iconName: t.category.defaultIcon,
                order: idx,
                category: t.category
            ))
        }
        try? context.save()
        Task {
            await prayerVM.refreshIfNeeded(context: context, settings: settings, force: true)
            await flash("Schedule reset")
        }
    }

    @MainActor
    private func flash(_ message: String) async {
        saveStatus = message
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if saveStatus == message { saveStatus = nil }
    }

    @MainActor
    private func rescheduleNotificationsFromSettings() async {
        let allowed = await alarmSession.requestNotificationAuthorizationIfNeeded()
        await ScheduleNotificationService.reschedule(
            context: context,
            settings: settings,
            blocks: blocks,
            prayerTimesToday: prayerVM.todayTimings,
            authorizationAllowed: allowed
        )
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Theme.displayFont(10, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            content()
                .textFieldStyle(.plain)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.black))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BlockEditorRow: View {
    @Bindable var block: DailyBlock
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: block.iconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.orange)
                .frame(width: 20)

            TextField("Title", text: $block.title)
                .textFieldStyle(.plain)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.black))
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 200)
                .disabled(block.isPrayerGenerated)

            TimePicker(minutes: $block.startMinute)
            DurationPicker(minutes: $block.durationMinutes)

            Picker("", selection: $block.categoryRaw) {
                ForEach(BlockCategory.allCases) { c in
                    Text(c.displayName).tag(c.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 130)
            .disabled(block.isPrayerGenerated)
            .onChange(of: block.categoryRaw) { _, _ in
                if !block.isPrayerGenerated {
                    block.iconName = block.category.defaultIcon
                }
            }

            Stepper(value: $block.order, in: 0...9999) {
                Text("#\(block.order)")
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .controlSize(.small)
            .labelsHidden()

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(block.isPrayerGenerated ? Theme.textSecondary : Theme.orange)
            }
            .buttonStyle(.plain)
            .disabled(block.isPrayerGenerated)
        }
        .padding(.vertical, 4)
    }
}

private struct TimePicker: View {
    @Binding var minutes: Int
    var body: some View {
        let h = Binding(get: { minutes / 60 }, set: { minutes = max(0, min(23, $0)) * 60 + (minutes % 60) })
        let m = Binding(get: { minutes % 60 }, set: { minutes = (minutes / 60) * 60 + max(0, min(59, $0)) })
        HStack(spacing: 4) {
            Stepper(value: h, in: 0...23) { Text(String(format: "%02d", h.wrappedValue)).font(Theme.monoFont(12)).foregroundStyle(Theme.textPrimary) }
                .controlSize(.small).labelsHidden()
            Text(":").foregroundStyle(Theme.textSecondary)
            Stepper(value: m, in: 0...59, step: 5) { Text(String(format: "%02d", m.wrappedValue)).font(Theme.monoFont(12)).foregroundStyle(Theme.textPrimary) }
                .controlSize(.small).labelsHidden()
        }
        .frame(width: 130)
    }
}

private struct DurationPicker: View {
    @Binding var minutes: Int
    var body: some View {
        Stepper(value: $minutes, in: 5...720, step: 5) {
            Text("\(minutes)m")
                .font(Theme.monoFont(12))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, alignment: .trailing)
        }
        .controlSize(.small).labelsHidden()
    }
}
