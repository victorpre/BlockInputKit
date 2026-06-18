import XCTest
@testable import BlockInputKit

final class BlockInputDueDateParsingTests: XCTestCase {
    func testParsesSingleDueDate() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].style, .dueDate)
        XCTAssertEqual(ranges[0].fullRange, NSRange(location: 0, length: 11))
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
        XCTAssertEqual(ranges[0].delimiterRanges, [NSRange(location: 0, length: 1)])
    }

    func testParsesDueDateAfterText() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "buy milk !2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 10, length: 10))
    }

    func testParsesMultipleDueDates() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-06-15 and !2026-07-20")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 17, length: 10))
    }

    func testParsesMultipleAdjacentDueDates() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-06-15 !2026-07-20")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 13, length: 10))
    }

    func testDoesNotParseInvalidMonth() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-13-01")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParseInvalidDay() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-02-30")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParseInvalidCharacters() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!202x-06-15")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParsePrecededByWordCharacter() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "abc!2026-06-15")

        XCTAssertEqual(ranges.count, 0)
    }

    func testParsesPrecededByNonWordCharacter() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "abc !2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 5, length: 10))
    }

    func testParsesDueDateAtEndOfText() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "deadline !2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 10, length: 10))
    }

    func testDoesNotParseEmptyExclamation() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "just a !")

        XCTAssertEqual(ranges.count, 0)
    }

    func testReturnsEmptyForEmptyText() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "")

        XCTAssertEqual(ranges, [])
    }

    func testExcludesRangesIntersectingExcludedRanges() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(
            in: "!2026-06-15 plain !2026-07-20",
            excluding: [NSRange(location: 0, length: 11)]
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 18, length: 10))
    }

    func testExcludesDueDateInsideExcludedRange() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(
            in: "!2026-06-15 !2026-07-20",
            excluding: [NSRange(location: 0, length: 12)]
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 13, length: 10))
    }

    func testDueDateRangesDoNotOverlap() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-06-15 !2026-07-20 !2026-08-25")

        XCTAssertEqual(ranges.count, 3)
        let sortedLocations = ranges.map(\.contentRange.location).sorted()
        XCTAssertEqual(sortedLocations, ranges.map(\.contentRange.location))
    }

    func testParsesDueDateAtDocumentStart() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-06-15 deadline")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }

    func testDueDateAfterSpaceWithoutTextParses() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "  !2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 3, length: 10))
    }

    func testParsesLeapYearDate() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2024-02-29")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }

    func testDoesNotParseNonLeapYearDate() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2023-02-29")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParseDateWithoutTrailingSpace() {
        let ranges = BlockInputDueDateParsing.dueDateRanges(in: "!2026-06-15extra")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }
}
