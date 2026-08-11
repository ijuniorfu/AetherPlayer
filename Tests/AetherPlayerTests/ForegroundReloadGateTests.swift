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
