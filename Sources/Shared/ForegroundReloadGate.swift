import AetherEngine

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
}
