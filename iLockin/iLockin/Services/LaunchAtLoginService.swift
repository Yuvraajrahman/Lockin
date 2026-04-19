import Foundation
import ServiceManagement
import OSLog

/// Wraps SMAppService.mainApp so the app can register itself as a Login Item
/// without needing a separate helper bundle (macOS 13+).
enum LaunchAtLoginService {
    private static let log = Logger(subsystem: "com.rogue.ilockin", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister the app as a login item.
    /// Returns true on success.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            log.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
