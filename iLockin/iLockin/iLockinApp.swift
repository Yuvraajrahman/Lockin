import SwiftUI
import SwiftData

@main
struct iLockinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Single SwiftData container shared across the app.
    let container: ModelContainer

    /// View models held at app scope so they survive view recreations.
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var prayerVM    = PrayerViewModel()
    @StateObject private var githubVM    = GitHubViewModel()

    init() {
        do {
            container = try ModelContainer(
                for: Habit.self,
                DailyBlock.self,
                PrayerTimes.self,
                GitHubRepo.self,
                GitHubIssue.self,
                Streak.self,
                AppSettings.self,
                TypingSession.self,
                ProgrammingSession.self,
                WorkoutSession.self
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

        // On first launch, register as a login item so iLockin opens automatically
        // the next time the user signs in. Subsequent launches respect the
        // user's preference toggle in Settings.
        let didRegisterKey = "iLockin.didAutoRegisterLoginItem"
        if !UserDefaults.standard.bool(forKey: didRegisterKey) {
            LaunchAtLoginService.setEnabled(true)
            UserDefaults.standard.set(true, forKey: didRegisterKey)
        }
    }

    var body: some Scene {
        WindowGroup("iLockin") {
            DashboardView()
                .environmentObject(dashboardVM)
                .environmentObject(prayerVM)
                .environmentObject(githubVM)
                .environmentObject(AlarmSession.shared)
                .modelContainer(container)
                .frame(minWidth: 1280, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // disable File > New Window
        }
    }
}
