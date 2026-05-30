import XCTest
@testable import AetherPlayer

final class TimecodeTests: XCTestCase {
    func testUnderOneHour() {
        XCTAssertEqual(formatTimecode(0), "0:00")
        XCTAssertEqual(formatTimecode(5), "0:05")
        XCTAssertEqual(formatTimecode(65), "1:05")
        XCTAssertEqual(formatTimecode(599), "9:59")
    }
    func testOverOneHour() {
        XCTAssertEqual(formatTimecode(3600), "1:00:00")
        XCTAssertEqual(formatTimecode(3661), "1:01:01")
    }
    func testNegativeAndNaNClampToZero() {
        XCTAssertEqual(formatTimecode(-5), "0:00")
        XCTAssertEqual(formatTimecode(.nan), "0:00")
        XCTAssertEqual(formatTimecode(.infinity), "0:00")
    }
}
