import Testing
import CoreGraphics
@testable import AetherPlayer

struct PlayerTouchInputTests {
    @Test func leftThirdSkipsBack() {
        #expect(PlayerTouchInput.skipSeconds(forTapX: 10, width: 300, interval: 10) == -10)
    }
    @Test func rightThirdSkipsForward() {
        #expect(PlayerTouchInput.skipSeconds(forTapX: 290, width: 300, interval: 10) == 10)
    }
    @Test func centerIsNil() {
        #expect(PlayerTouchInput.skipSeconds(forTapX: 150, width: 300, interval: 10) == nil)
    }
    @Test func zeroWidthIsNil() {
        #expect(PlayerTouchInput.skipSeconds(forTapX: 10, width: 0, interval: 10) == nil)
    }
}
