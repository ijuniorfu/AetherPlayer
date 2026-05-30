import SwiftUI
import AppKit
import AetherEngine

struct PlayerContainerView: View {
    let model: PlayerViewModel

    @State private var controlsVisible = true
    @State private var lastActivity = Date()
    @State private var showTracks = false
    private let hideInterval: TimeInterval = 3
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Bottom layer: mouse-move tracker (needs hit testing to receive mouseMoved).
            MouseActivityView { bumpActivity() }

            AetherPlayerSurface(engine: model.engine)
                .onTapGesture { model.primaryAction(); bumpActivity() }

            SubtitleOverlayView(cues: model.subtitleCues, currentTime: model.currentTime)
                .allowsHitTesting(false)

            if controlsVisible {
                VStack {
                    Spacer()
                    TransportBar(
                        model: model,
                        onTracksTapped: { showTracks.toggle() },
                        onPrevious: { ensureFolderThenAdvance(next: false) },
                        onNext: { ensureFolderThenAdvance(next: true) }
                    )
                }
                .transition(.opacity)
                .popover(isPresented: $showTracks, arrowEdge: .bottom) {
                    TracksPopover(model: model)
                }
            }

            KeyCatcherView(onKey: handleKey)
                .allowsHitTesting(false)
        }
        .onAppear { NSApp.keyWindow?.acceptsMouseMovedEvents = true }
        .onReceive(tick) { _ in
            if shouldHideControls(now: Date().timeIntervalSinceReferenceDate,
                                  lastActivity: lastActivity.timeIntervalSinceReferenceDate,
                                  interval: hideInterval),
               model.isPlaying, !showTracks {
                withAnimation { controlsVisible = false }
            }
        }
    }

    private func bumpActivity() {
        lastActivity = Date()
        if !controlsVisible { withAnimation { controlsVisible = true } }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 49: model.primaryAction(); bumpActivity(); return true     // Space
        case 53: model.stop(); return true                              // Esc
        case 124 where event.modifierFlags.contains(.command):          // Cmd+Right = next
            ensureFolderThenAdvance(next: true); bumpActivity(); return true
        case 123 where event.modifierFlags.contains(.command):          // Cmd+Left = previous
            ensureFolderThenAdvance(next: false); bumpActivity(); return true
        case 123: model.seek(by: -10); bumpActivity(); return true      // Left
        case 124: model.seek(by: 10); bumpActivity(); return true       // Right
        case 126: model.adjustVolume(by: 0.05); bumpActivity(); return true  // Up
        case 125: model.adjustVolume(by: -0.05); bumpActivity(); return true // Down
        case 46: model.toggleMute(); bumpActivity(); return true        // M
        case 3:  toggleFullScreen(); return true                        // F
        default: return false
        }
    }

    private func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    private func ensureFolderThenAdvance(next: Bool) {
        if model.playlist != nil {
            Task { if next { await model.playNext() } else { await model.playPrevious() } }
            return
        }
        guard let current = model.loadedURL else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = current.deletingLastPathComponent()
        panel.message = "Grant access to this folder to play the next file."
        if panel.runModal() == .OK, let folder = panel.url {
            let bm = BookmarkAccess.bookmark(for: folder)
            model.adoptFolderPlaylist(folderURL: folder, around: current, bookmarkData: bm)
            Task { if next { await model.playNext() } else { await model.playPrevious() } }
        }
    }
}

/// Tracks mouse movement over the player and reports activity.
private struct MouseActivityView: NSViewRepresentable {
    let onMove: () -> Void
    func makeNSView(context: Context) -> _Tracking {
        let v = _Tracking(); v.onMove = onMove; return v
    }
    func updateNSView(_ nsView: _Tracking, context: Context) { nsView.onMove = onMove }

    final class _Tracking: NSView {
        var onMove: (() -> Void)?
        private var area: NSTrackingArea?
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let a = NSTrackingArea(rect: bounds,
                                   options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
                                   owner: self, userInfo: nil)
            addTrackingArea(a); area = a
        }
        override func mouseMoved(with event: NSEvent) { onMove?() }
    }
}
