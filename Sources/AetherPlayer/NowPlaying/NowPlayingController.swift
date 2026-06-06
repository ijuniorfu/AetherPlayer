import Foundation
import MediaPlayer
import AppKit
import AetherEngine

/// Drives the macOS system Now-Playing surfaces (Control Center widget,
/// media keys) for every backend. On macOS, AVPlayer does not auto-
/// populate MPNowPlayingInfoCenter, so the host writes it directly. The
/// controller is metadata/clock agnostic: the view model pushes updates
/// and the remote-command callbacks route back into the view model.
@MainActor
final class NowPlayingController {
    private let info = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()
    private var configured = false

    /// Wire transport commands once. Each closure calls back into the
    /// supplied action set (the view model's methods).
    func configure(actions: Actions) {
        guard !configured else { return }
        configured = true

        commands.playCommand.addTarget { _ in actions.play(); return .success }
        commands.pauseCommand.addTarget { _ in actions.pause(); return .success }
        commands.togglePlayPauseCommand.addTarget { _ in actions.toggle(); return .success }

        commands.skipForwardCommand.preferredIntervals = [10]
        commands.skipForwardCommand.addTarget { _ in actions.skip(10); return .success }
        commands.skipBackwardCommand.preferredIntervals = [10]
        commands.skipBackwardCommand.addTarget { _ in actions.skip(-10); return .success }

        commands.nextTrackCommand.addTarget { _ in actions.next(); return .success }
        commands.previousTrackCommand.addTarget { _ in actions.previous(); return .success }

        commands.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            actions.seekTo(e.positionTime)
            return .success
        }
    }

    /// Enable/disable next/previous to match playlist availability.
    func updateAvailability(hasNext: Bool, hasPrevious: Bool) {
        commands.nextTrackCommand.isEnabled = hasNext
        commands.previousTrackCommand.isEnabled = hasPrevious
    }

    /// Push the current metadata + clock to the system. Pass nil to clear.
    func update(metadata: MediaMetadata?, fallbackTitle: String,
                duration: Double, elapsed: Double, rate: Float) {
        var dict = nowPlayingInfo(
            metadata: metadata, fallbackTitle: fallbackTitle,
            duration: duration, elapsed: elapsed, rate: rate)
        if let data = metadata?.artworkData, let image = NSImage(data: data) {
            dict[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        info.nowPlayingInfo = dict
        info.playbackState = rate > 0 ? .playing : .paused
    }

    /// Clear the system surface on stop.
    func clear() {
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
