import XCTest
@testable import BlockInputKit

final class BlockInputKitTests: XCTestCase {
    func testVersionIsPresent() {
        XCTAssertEqual(BlockInputKit.version, "0.1.0")
    }
}
