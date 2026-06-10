import XCTest
@testable import BlockInputKit

final class BlockInputWhenDateParsingTests: XCTestCase {
    func testParsesSingleWhenDate() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].style, .whenDate)
        XCTAssertEqual(ranges[0].fullRange, NSRange(location: 0, length: 11))
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
        XCTAssertEqual(ranges[0].delimiterRanges, [NSRange(location: 0, length: 1)])
    }

    func testParsesWhenDateAfterText() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "buy milk @2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 10, length: 10))
    }

    func testParsesMultipleWhenDates() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15 and @2026-07-20")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 17, length: 10))
    }

    func testParsesMultipleAdjacentWhenDates() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15 @2026-07-20")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 13, length: 10))
    }

    func testDoesNotParseInvalidMonth() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-13-01")

        XCTAssertEqual(ranges.count, 1)
    }

    func testDoesNotParseInvalidDay() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-02-30")

        XCTAssertEqual(ranges.count, 1)
    }

    func testDoesNotParseInvalidCharacters() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@202x-06-15")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParsePrecededByWordCharacter() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "abc@2026-06-15")

        XCTAssertEqual(ranges.count, 0)
    }

    func testParsesPrecededByNonWordCharacter() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "abc @2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 5, length: 10))
    }

    func testParsesWhenDateAtEndOfText() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "schedule @2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 10, length: 10))
    }

    func testDoesNotParseEmptyAtSign() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "just a @")

        XCTAssertEqual(ranges.count, 0)
    }

    func testReturnsEmptyForEmptyText() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "")

        XCTAssertEqual(ranges, [])
    }

    func testDoesNotParseMention() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@john")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParseMentionAfterWhenDate() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15 @john")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }

    func testExcludesRangesIntersectingExcludedRanges() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(
            in: "@2026-06-15 plain @2026-07-20",
            excluding: [NSRange(location: 0, length: 11)]
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 19, length: 10))
    }

    func testExcludesWhenDateInsideExcludedRange() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(
            in: "@2026-06-15 @2026-07-20",
            excluding: [NSRange(location: 0, length: 12)]
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 13, length: 10))
    }

    func testWhenDateRangesDoNotOverlap() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15 @2026-07-20 @2026-08-25")

        XCTAssertEqual(ranges.count, 3)
        let sortedLocations = ranges.map(\.contentRange.location).sorted()
        XCTAssertEqual(sortedLocations, ranges.map(\.contentRange.location))
    }

    func testParsesWhenDateAtDocumentStart() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15 deadline")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }

    func testWhenDateAfterSpaceWithoutTextParses() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "  @2026-06-15")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 3, length: 10))
    }

    func testParsesLeapYearDate() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2024-02-29")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }

    func testDoesNotParseNonLeapYearDate() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2023-02-29")

        XCTAssertEqual(ranges.count, 1)
    }

    func testDoesNotParseWhenDateAdjacentToText() {
        let ranges = BlockInputWhenDateParsing.whenDateRanges(in: "@2026-06-15extra")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 1, length: 10))
    }
}
