import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Dock click: front the last player window, or open a new one when only the Stats window (or
    /// nothing) is left.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        let windows = PlayerWindowRegistry.shared
        if windows.sessions.isEmpty {
            windows.openPlayerWindow()
        } else {
            windows.bringToFront()
        }
        return false
    }
}
