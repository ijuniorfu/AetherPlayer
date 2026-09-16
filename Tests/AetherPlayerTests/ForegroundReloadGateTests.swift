import XCTest
import AetherEngine
@testable import AetherPlayer

/// The gate that decides whether a foreground return rebuilds the session. Mirrors the host
/// adoption Sodalite ships for AetherEngine #127, and the reason it is a pure function is that the
/// interesting cases (PiP holding the pipeline, a return inside the grace window) are states, not
/// notifications, and are worth pinning without an app lifecycle.
final class ForegroundReloadGateTests: XCTestCase {

    func testTornDownPausedSessionIsRebuilt() {
        XCTAssertTrue(ForegroundReloadGate.needsReload(state: .paused, backend: .none))
    }

    func testASessionKeptAliveIsLeftAlone() {
        // PiP or background audio: the pipeline survived, so a reload would be pure cost.
        XCTAssertFalse(ForegroundReloadGate.needsReload(state: .playing, backend: .native))
        XCTAssertFalse(ForegroundReloadGate.needsReload(state: .playing, backend: .software))
        XCTAssertFalse(ForegroundReloadGate.needsReload(state: .playing, backend: .audio))
    }

    func testAQuickSwitchInsideTheGraceWindowIsNotAReload() {
        // The window is what kept the paused pipeline; the backend still names it.
        XCTAssertFalse(ForegroundReloadGate.needsReload(state: .paused, backend: .native))
        XCTAssertFalse(ForegroundReloadGate.needsReload(state: .paused, backend: .software))
    }

    func testOtherTornDownStatesAlsoRebuild() {
        XCTAssertTrue(ForegroundReloadGate.needsReload(state: .idle, backend: .none))
        XCTAssertTrue(ForegroundReloadGate.needsReload(state: .ended, backend: .none))
        XCTAssertTrue(ForegroundReloadGate.needsReload(state: .error("gone"), backend: .none))
    }
}

/// What a foreground return does with the session it finds, live sessions included. A live session
/// torn down in the background cannot be rebuilt at a position (AetherEngine #526: the engine
/// refuses, and a swallowed refusal left the player dead), so it tunes again. The live rules mirror
/// Sodalite's `liveForegroundReturn`.
final class ForegroundReturnActionTests: XCTestCase {

    private func action(state: PlaybackState = .paused, backend: PlaybackBackend = .none,
                        wasLive: Bool, wasPlaying: Bool = false,
                        away: TimeInterval = 900, advance: TimeInterval = 0) -> ForegroundReloadGate.ForegroundReturn {
        ForegroundReloadGate.action(state: state, backend: backend, wasLive: wasLive,
                                    wasPlaying: wasPlaying, backgroundSeconds: away, playheadAdvance: advance)
    }

    func testATornDownFileIsRebuiltAtItsPosition() {
        XCTAssertEqual(action(wasLive: false), .reload)
    }

    func testAFileKeptAliveIsLeftAlone() {
        XCTAssertEqual(action(state: .playing, backend: .software, wasLive: false, wasPlaying: true), .none)
        XCTAssertEqual(action(state: .paused, backend: .native, wasLive: false), .none)
    }

    func testATornDownLiveSessionTunesAgainInsteadOfAskingForARebuildTheEngineRefuses() {
        XCTAssertEqual(action(wasLive: true), .retune)
        XCTAssertEqual(action(state: .idle, wasLive: true, wasPlaying: true), .retune)
    }

    func testAPausedLiveSessionThatSurvivedKeepsTheViewersPause() {
        XCTAssertEqual(action(state: .paused, backend: .software, wasLive: true, wasPlaying: false,
                              away: 600, advance: 0), .none)
    }

    func testALiveSessionThatPlayedThroughTheBackgroundIsStillLive() {
        XCTAssertEqual(action(state: .playing, backend: .native, wasLive: true, wasPlaying: true,
                              away: 120, advance: 119.5), .none)
    }

    func testALiveSessionSuspendedWhilePlayingTunesAgain() {
        // The playhead did not move across the gap, so the frontier it sits next to is the past.
        XCTAssertEqual(action(state: .playing, backend: .native, wasLive: true, wasPlaying: true,
                              away: 120, advance: 0.3), .retune)
    }

    func testAShortGapIsCoveredByTheLiveEdgeTolerance() {
        XCTAssertEqual(action(state: .playing, backend: .native, wasLive: true, wasPlaying: true,
                              away: 5, advance: 0), .none)
    }

    func testTheAdvanceSlackCountsAsPlayedThrough() {
        XCTAssertEqual(action(state: .playing, backend: .native, wasLive: true, wasPlaying: true,
                              away: 60, advance: 58), .none)
        XCTAssertEqual(action(state: .playing, backend: .native, wasLive: true, wasPlaying: true,
                              away: 60, advance: 57.9), .retune)
    }
}
