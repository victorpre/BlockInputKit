import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputItemHeightCacheTests: XCTestCase {
    func testReusesHeightForUnchangedBlockAndWidth() {
        let cache = BlockInputItemHeightCache()
        let block = BlockInputBlock(id: "target", text: "Short")
        var measurementCount = 0

        let firstHeight = cache.height(for: block, at: 0, textWidth: 320) {
            measurementCount += 1
            return 44
        }
        let secondHeight = cache.height(for: block, at: 0, textWidth: 320) {
            measurementCount += 1
            return 88
        }

        XCTAssertEqual(firstHeight, 44)
        XCTAssertEqual(secondHeight, 44)
        XCTAssertEqual(measurementCount, 1)
    }

    func testRemeasuresWhenBlockChanges() {
        let cache = BlockInputItemHeightCache()
        let block = BlockInputBlock(id: "target", text: "Short")
        let updatedBlock = BlockInputBlock(id: "target", text: "Short\nwrapped")
        var measurementCount = 0

        _ = cache.height(for: block, at: 0, textWidth: 320) {
            measurementCount += 1
            return 44
        }
        let updatedHeight = cache.height(for: updatedBlock, at: 0, textWidth: 320) {
            measurementCount += 1
            return 72
        }

        XCTAssertEqual(updatedHeight, 72)
        XCTAssertEqual(measurementCount, 2)
    }

    func testRemeasuresWhenWidthChanges() {
        let cache = BlockInputItemHeightCache()
        let block = BlockInputBlock(id: "target", text: "Short")
        var measurementCount = 0

        _ = cache.height(for: block, at: 0, textWidth: 320) {
            measurementCount += 1
            return 44
        }
        let narrowedHeight = cache.height(for: block, at: 0, textWidth: 200) {
            measurementCount += 1
            return 64
        }

        XCTAssertEqual(narrowedHeight, 64)
        XCTAssertEqual(measurementCount, 2)
    }

    func testInvalidatesOneCachedIndex() {
        let cache = BlockInputItemHeightCache()
        let firstBlock = BlockInputBlock(id: "first", text: "First")
        let secondBlock = BlockInputBlock(id: "second", text: "Second")
        var measurementCount = 0

        _ = cache.height(for: firstBlock, at: 0, textWidth: 320) {
            measurementCount += 1
            return 44
        }
        _ = cache.height(for: secondBlock, at: 1, textWidth: 320) {
            measurementCount += 1
            return 44
        }
        cache.invalidate(at: 1)

        _ = cache.height(for: firstBlock, at: 0, textWidth: 320) {
            measurementCount += 1
            return 88
        }
        let secondHeight = cache.height(for: secondBlock, at: 1, textWidth: 320) {
            measurementCount += 1
            return 88
        }

        XCTAssertEqual(secondHeight, 88)
        XCTAssertEqual(measurementCount, 3)
    }
}
