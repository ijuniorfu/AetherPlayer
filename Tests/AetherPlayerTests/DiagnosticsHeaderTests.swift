import AetherEngine
import XCTest
@testable import AetherPlayer

/// The header is what a handed-over log is read against, and every line in it answers a question a
/// reporter would otherwise be asked one at a time. The engine line answers the one that cannot be
/// asked at all after the fact: which engine produced these lines. A report analysed without it had
/// the version invented from an older thread (#7), so this pins the line's presence and its shape.
final class DiagnosticsHeaderTests: XCTestCase {

    func testHeaderNamesTheEngineRelease() {
        let header = DiagnosticsLog.sessionHeader()
        XCTAssertTrue(header.contains("AetherEngine \(AetherEngine.version)"),
                      "the header must name the engine release, got:\n\(header)")
    }

    /// The header is read in a terminal, so its keys line up in one column. A new key that is longer
    /// than the gutter silently ragged-edges every line under it.
    func testEveryHeaderKeyIsPaddedToTheSameColumn() {
        let fields = DiagnosticsLog.sessionHeader()
            .split(separator: "\n")
            .filter { !$0.hasPrefix("=") && !$0.isEmpty }

        XCTAssertFalse(fields.isEmpty)
        for field in fields {
            let key = field.prefix { $0 != " " }
            guard key.count < 12 else {
                XCTFail("\"\(key)\" is too long for the 12-column gutter the header is read in")
                continue
            }
            XCTAssertTrue(field.hasPrefix(key + String(repeating: " ", count: 12 - key.count)),
                          "\"\(key)\" does not reach the value column at 12, line: \(field)")
        }
    }
}
