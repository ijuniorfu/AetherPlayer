import Testing
import AetherEngine
@testable import AetherPlayer

struct PlaybackEndedTests {
    @Test func endedStateWithMediaIsEnded() {
        #expect(PlayerViewModel.isEndedPlayback(state: .ended, hasMedia: true) == true)
    }
    @Test func idleStateWithMediaIsEnded() {
        #expect(PlayerViewModel.isEndedPlayback(state: .idle, hasMedia: true) == true)
    }
    @Test func playingIsNotEnded() {
        #expect(PlayerViewModel.isEndedPlayback(state: .playing, hasMedia: true) == false)
    }
    @Test func endedWithoutMediaIsNotEnded() {
        #expect(PlayerViewModel.isEndedPlayback(state: .ended, hasMedia: false) == false)
    }
}
