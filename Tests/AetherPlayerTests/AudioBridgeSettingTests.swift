import Testing
import Foundation
import AetherEngine
@testable import AetherPlayer

/// The bridge-encoder choice's pure half: what a stored string resolves to, and what each mode
/// reads as on screen. The resolution is the part worth pinning, because every way it can fail
/// ends in audio that is worse or absent, with nothing on screen saying so.
struct AudioBridgeSettingTests {

    @Test func absentValueTakesTheEngineDefault() {
        #expect(AudioBridgeSetting.resolve(stored: nil) == .surroundCompat)
    }

    @Test func emptyValueTakesTheEngineDefault() {
        #expect(AudioBridgeSetting.resolve(stored: "") == .surroundCompat)
    }

    @Test func anUnknownValueTakesTheEngineDefaultRatherThanFailing() {
        // A value left behind by a renamed case must not strand playback on something unplayable.
        #expect(AudioBridgeSetting.resolve(stored: "atmosPassthrough") == .surroundCompat)
    }

    @Test func eachModeRoundTripsThroughItsStoredForm() {
        for mode in AudioBridgeMode.allCases {
            #expect(AudioBridgeSetting.resolve(stored: mode.rawValue) == mode,
                    "\(mode.rawValue) must survive a write and a read")
        }
    }

    @Test func bothModesAreOfferedAndNamed() {
        // The picker is built from allCases, so a mode the engine adds shows up without an edit
        // here; what it must never do is show up unlabelled.
        for mode in AudioBridgeMode.allCases {
            #expect(!AudioBridgeSetting.label(mode).isEmpty)
            #expect(!AudioBridgeSetting.explanation(mode).isEmpty)
        }
        #expect(AudioBridgeSetting.label(.lossless) != AudioBridgeSetting.label(.surroundCompat))
    }
}
