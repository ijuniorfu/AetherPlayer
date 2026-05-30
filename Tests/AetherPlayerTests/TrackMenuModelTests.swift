import XCTest
import AetherEngine
@testable import AetherPlayer

final class TrackMenuModelTests: XCTestCase {
    private func audio(_ id: Int, _ name: String, lang: String? = nil, ch: Int = 2, atmos: Bool = false) -> TrackInfo {
        TrackInfo(id: id, name: name, codec: "eac3", language: lang, channels: ch, isDefault: false, isAtmos: atmos)
    }

    func testAudioRowLabelsIncludeLanguageAndChannels() {
        let rows = audioMenuRows([audio(0, "English", lang: "en", ch: 6)], activeIndex: 0)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].label, "English · EN · 5.1")
        XCTAssertTrue(rows[0].isSelected)
        XCTAssertEqual(rows[0].engineIndex, 0)
    }

    func testAtmosOverridesChannelLabel() {
        let rows = audioMenuRows([audio(0, "Surround", lang: "en", ch: 6, atmos: true)], activeIndex: nil)
        XCTAssertEqual(rows[0].label, "Surround · EN · Atmos")
        XCTAssertFalse(rows[0].isSelected)
    }

    func testStereoAndUnknownChannelLabels() {
        XCTAssertEqual(audioMenuRows([audio(0, "A", ch: 2)], activeIndex: nil)[0].label, "A · Stereo")
        XCTAssertEqual(audioMenuRows([audio(0, "B", ch: 8)], activeIndex: nil)[0].label, "B · 7.1")
    }

    func testSubtitleRowsPrependOffAndMarkSelection() {
        let subs = [TrackInfo(id: 3, name: "English", codec: "subrip", language: "en", channels: 0, isDefault: false)]
        let off = subtitleMenuRows(subs, selectedEngineIndex: nil, isActive: false)
        XCTAssertEqual(off.first?.kind, .off)
        XCTAssertTrue(off.first!.isSelected)
        let on = subtitleMenuRows(subs, selectedEngineIndex: 3, isActive: true)
        XCTAssertFalse(on.first!.isSelected)
        XCTAssertEqual(on.last?.label, "English · EN")
        XCTAssertTrue(on.last!.isSelected)
    }
}
