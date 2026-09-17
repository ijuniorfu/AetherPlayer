import AetherEngine
import AppKit

/// The standard About panel, plus the one fact it cannot know by itself: which engine this build
/// embeds. AppKit fills name, version and copyright from the bundle, and the engine is not in the
/// bundle's vocabulary, so it goes in through the credits slot, directly under the version line.
@MainActor
enum AboutPanel {

    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let credits = NSAttributedString(
            string: "AetherEngine \(AetherEngine.version)",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ])

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
