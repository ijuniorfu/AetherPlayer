#if os(macOS)
import Foundation
import MediaPlayer
import AppKit
import AetherEngine

/// Drives the macOS system Now-Playing surfaces (Control Center widget,
/// media keys) for every backend. On macOS, AVPlayer does not auto-
/// populate MPNowPlayingInfoCenter, so the host writes it directly. The
/// controller is metadata/clock agnostic: the view model pushes updates
/// and the remote-command callbacks route back into the view model.
///
/// The system surface is one per process and every player window has a
/// controller, so exactly one of them owns it: the player that started
/// playing or whose window became key last (`claim()`). The others stay
/// silent until the owner clears, and the next one to push takes over.
@MainActor
final class NowPlayingController {
    private let info = MPNowPlayingInfoCenter.default()
    private static let commands = MPRemoteCommandCenter.shared()
    private static var targetsInstalled = false
    private static weak var owner: NowPlayingController?
    private var actions: Actions?

    /// Decoded cover, kept across pushes and rebuilt only when the bytes change.
    /// `update` runs on the throttled clock tick (about once a second for the
    /// whole session), and decoding the embedded artwork there re-ran a full
    /// image decode every second for artwork that never changes. On a file with
    /// a poster-sized cover that dominated the process: measured 18.8% of a core
    /// against 5.8% for the same A/V without one, with PNG decoding 60% of all
    /// running samples (AetherPlayer#2). `NowPlayingView` already gates its own
    /// copy on the artwork bytes; this is the same gate on the system surface.
    private var artworkSource: Data?
    private var artwork: MPMediaItemArtwork?

    /// Store this player's actions. The command targets are installed once per
    /// process and call whichever controller owns the surface.
    func configure(actions: Actions) {
        self.actions = actions
        Self.installTargets()
    }

    func claim() {
        Self.owner = self
    }

    /// True when this controller may write the surface, taking it over when nobody holds it.
    private func mayPublish() -> Bool {
        if Self.owner == nil { Self.owner = self }
        return Self.owner === self
    }

    private static func installTargets() {
        guard !targetsInstalled else { return }
        targetsInstalled = true

        func route(_ body: @escaping (Actions) -> Void) -> (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
            { _ in
                guard let actions = owner?.actions else { return .noActionableNowPlayingItem }
                body(actions)
                return .success
            }
        }
        commands.playCommand.addTarget(handler: route { $0.play() })
        commands.pauseCommand.addTarget(handler: route { $0.pause() })
        commands.togglePlayPauseCommand.addTarget(handler: route { $0.toggle() })

        commands.skipForwardCommand.preferredIntervals = [10]
        commands.skipForwardCommand.addTarget(handler: route { $0.skip(10) })
        commands.skipBackwardCommand.preferredIntervals = [10]
        commands.skipBackwardCommand.addTarget(handler: route { $0.skip(-10) })

        commands.nextTrackCommand.addTarget(handler: route { $0.next() })
        commands.previousTrackCommand.addTarget(handler: route { $0.previous() })

        commands.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent,
                  let actions = owner?.actions else { return .commandFailed }
            actions.seekTo(e.positionTime)
            return .success
        }
    }

    /// Enable/disable next/previous to match playlist availability.
    func updateAvailability(hasNext: Bool, hasPrevious: Bool) {
        guard mayPublish() else { return }
        let commands = Self.commands
        commands.nextTrackCommand.isEnabled = hasNext
        commands.previousTrackCommand.isEnabled = hasPrevious
    }

    /// Push the current metadata + clock to the system. Pass nil to clear.
    func update(metadata: MediaMetadata?, fallbackTitle: String,
                duration: Double, elapsed: Double, rate: Float) {
        guard mayPublish() else { return }
        var dict = nowPlayingInfo(
            metadata: metadata, fallbackTitle: fallbackTitle,
            duration: duration, elapsed: elapsed, rate: rate)
        if let data = metadata?.artworkData {
            if artworkSource != data {
                artworkSource = data
                artwork = NSImage(data: data).map { Self.makeArtwork($0) }
            }
            if let artwork { dict[MPMediaItemPropertyArtwork] = artwork }
        } else if artworkSource != nil {
            artworkSource = nil
            artwork = nil
        }
        info.nowPlayingInfo = dict
        info.playbackState = rate > 0 ? .playing : .paused
    }

    /// Wrap an image as `MPMediaItemArtwork`. MediaPlayer invokes the
    /// request handler on its own internal queue, so the closure must NOT
    /// be main-actor-isolated; otherwise Swift's actor-isolation runtime
    /// check traps (SIGTRAP) the moment MediaPlayer renders the artwork.
    /// A `nonisolated` context produces a plain, non-isolated closure.
    private nonisolated static func makeArtwork(_ image: NSImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    /// Clear the system surface on stop.
    func clear() {
        artworkSource = nil
        artwork = nil
        guard Self.owner === self else { return }
        Self.owner = nil
        info.nowPlayingInfo = nil
        info.playbackState = .stopped
    }

    struct Actions {
        let play: () -> Void
        let pause: () -> Void
        let toggle: () -> Void
        let skip: (Double) -> Void
        let next: () -> Void
        let previous: () -> Void
        let seekTo: (Double) -> Void
    }
}
#else
import Foundation
import AetherEngine

/// iOS no-op: Now Playing is owned by AVPlayerViewController via
/// AVPlayerItem.externalMetadata (Task 2.4). Manual MPNowPlayingInfoCenter
/// writes crash against the engine's HLS loopback (_dispatch_assert_queue_fail),
/// so this stub keeps `PlayerViewModel`'s calls valid without touching MediaPlayer.
@MainActor
final class NowPlayingController {
    struct Actions {
        let play: () -> Void
        let pause: () -> Void
        let toggle: () -> Void
        let skip: (Double) -> Void
        let next: () -> Void
        let previous: () -> Void
        let seekTo: (Double) -> Void
    }

    func configure(actions: Actions) {}

    func claim() {}

    func updateAvailability(hasNext: Bool, hasPrevious: Bool) {}

    func update(metadata: MediaMetadata?, fallbackTitle: String,
                duration: Double, elapsed: Double, rate: Float) {}

    func clear() {}
}
#endif
