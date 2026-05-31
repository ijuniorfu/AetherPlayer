import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Captures the current frame from the model and writes it to a
/// user-chosen PNG via a save panel. The panel grants write access, so no
/// read-write entitlement is needed.
@MainActor
enum SnapshotSaver {
    /// Capture + save. No-op if the frame can't be captured or the user cancels.
    static func captureAndSave(model: PlayerViewModel) {
        Task {
            guard let image = await model.snapshotCurrentFrame() else { return }
            let name = snapshotFilename(
                movieName: model.loadedURL?.lastPathComponent ?? "Frame",
                at: model.currentTime
            )
            present(image, suggestedName: name)
        }
    }

    private static func present(_ image: CGImage, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
