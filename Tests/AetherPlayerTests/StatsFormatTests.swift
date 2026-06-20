import XCTest
import AetherEngine
@testable import AetherPlayer

final class StatsFormatTests: XCTestCase {
    func testResolution() {
        XCTAssertEqual(formatResolution(width: 1920, height: 1080), "1920 \u{00D7} 1080")
        XCTAssertEqual(formatResolution(width: 0, height: 0), "\u{2012}")
    }

    func testVideoFormatLabels() {
        XCTAssertEqual(videoFormatLabel(.sdr), "SDR")
        XCTAssertEqual(videoFormatLabel(.hdr10), "HDR10")
        XCTAssertEqual(videoFormatLabel(.hdr10Plus), "HDR10+")
        XCTAssertEqual(videoFormatLabel(.dolbyVision), "Dolby Vision")
        XCTAssertEqual(videoFormatLabel(.hlg), "HLG")
    }

    func testOptionalNumericFormatters() {
        XCTAssertEqual(formatMbps(12.34), "12.3 Mbps")
        XCTAssertEqual(formatMbps(nil), "\u{2012}")
        XCTAssertEqual(formatFps(47.96), "48.0 fps")
        XCTAssertEqual(formatFps(nil), "\u{2012}")
        XCTAssertEqual(formatDroppedFrames(3), "3")
        XCTAssertEqual(formatDroppedFrames(nil), "\u{2012}")
        XCTAssertEqual(formatSeconds(2.5), "2.5 s")
        XCTAssertEqual(formatSeconds(nil), "\u{2012}")
    }

    func testMemoryAndBackend() {
        XCTAssertEqual(formatMemoryMB(340), "340 MB")
        XCTAssertEqual(formatBackend(.native), "Native (AVPlayer)")
        XCTAssertEqual(formatBackend(.software), "Software")
        XCTAssertEqual(formatBackend(.audio), "Audio")
        XCTAssertEqual(formatBackend(.aether), "Aether")
        XCTAssertEqual(formatBackend(.none), "\u{2012}")
    }
}
