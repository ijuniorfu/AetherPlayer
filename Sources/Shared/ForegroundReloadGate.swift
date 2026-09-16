import AetherEngine
import Foundation

/// AetherEngine #127: a paused session that stays backgrounded past the engine's grace window has
/// its video pipeline torn down, deliberately, because it must not cross an idle suspension (a
/// live AVPlayer decode session in mediaserverd wedges the whole system across a long one).
/// Nothing rebuilds it unless the host asks, so a host without this returns to a dead session.
///
/// The engine keeps the pipeline alive whenever it can: PiP, background audio, or a return inside
/// the grace window. Reloading one of those would throw away exactly the rebuild it avoided, and
/// what distinguishes the two is the backend: `.none` is the torn-down session and nothing else.
enum ForegroundReloadGate {

    /// Whether a foreground return has to rebuild the session from its current position.
    static func needsReload(state: PlaybackState, backend: PlaybackBackend) -> Bool {
        state != .playing && backend == .none
    }

    enum ForegroundReturn: Equatable {
        /// The session is where the viewer left it.
        case none
        /// Rebuild the torn-down session at its position.
        case reload
        /// Open the live source again, at the live edge.
        case retune
    }

    /// A gap this short leaves a live session inside one segment of live, which the edge tolerance
    /// covers, and a tune would cost a rebuffer for nothing.
    static let liveStaleSeconds: TimeInterval = 5
    /// The playhead is sampled either side of a gap measured on a different clock, and a session that
    /// played through pays a moment of it to the resume itself.
    static let liveAdvanceSlack: TimeInterval = 2

    /// What a foreground return does, live sessions included. The live rules are Sodalite's
    /// `liveForegroundReturn`.
    ///
    /// A torn-down live session is not rebuilt: its source is a forward-only ingest with no position
    /// to reopen at, and the engine refuses (`sessionNotReloadable`, AetherEngine #526). The DVR window
    /// died with the producer, so the answer is a tune. A live session that survived is judged by
    /// whether its playhead MOVED across the gap: one that played through (background audio, PiP) is
    /// as live as it was, one that was suspended while playing sits next to a frontier that stopped
    /// moving, which nothing in the window can close. A pause is the viewer's and is kept.
    static func action(state: PlaybackState, backend: PlaybackBackend, wasLive: Bool, wasPlaying: Bool,
                       backgroundSeconds: TimeInterval, playheadAdvance: TimeInterval) -> ForegroundReturn {
        let tornDown = needsReload(state: state, backend: backend)
        guard wasLive else { return tornDown ? .reload : .none }
        if tornDown { return .retune }
        guard wasPlaying, backgroundSeconds > liveStaleSeconds else { return .none }
        return playheadAdvance >= backgroundSeconds - liveAdvanceSlack ? .none : .retune
    }
}
