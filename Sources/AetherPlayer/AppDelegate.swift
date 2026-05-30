import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by AetherPlayerApp; receives files opened from Finder / "Open With".
    static var onOpenFiles: (([URL]) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        AppDelegate.onOpenFiles?(urls)
    }
}
