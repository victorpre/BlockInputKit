import XCTest
@testable import BlockInputKit

final class BlockInputHashtagParsingTests: XCTestCase {
    func testParsesSingleHashtag() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "#groceries")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].style, .hashtag)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 0, length: 10))
        XCTAssertEqual(ranges[0].fullRange, NSRange(location: 0, length: 10))
        XCTAssertEqual(ranges[0].delimiterRanges, [])
    }

    func testParsesHashtagAfterText() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "buy milk #groceries")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 9, length: 10))
    }

    func testParsesMultipleHashtags() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "#one and #two")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 0, length: 4))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 9, length: 4))
    }

    func testParsesMultipleAdjacentHashtags() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "#tag1 #tag2")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 0, length: 5))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 6, length: 5))
    }

    func testParsesHashtagWithHyphens() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "check #my-tag here")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 6, length: 7))
    }

    func testParsesHashtagWithUnderscores() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "read #my_book today")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 5, length: 8))
    }

    func testDoesNotParseEmptyHashtag() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "just a #")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParseHashtagStartingWithHyphen() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "invalid #-tag")

        XCTAssertEqual(ranges.count, 0)
    }

    func testDoesNotParseHashtagPrecededByWordCharacter() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "email#tag")

        XCTAssertEqual(ranges.count, 0)
    }

    func testExcludesRangesIntersectingExcludedRanges() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(
            in: "#tag1 `code` #tag2",
            excluding: [NSRange(location: 6, length: 6)]
        )

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 0, length: 5))
        XCTAssertEqual(ranges[1].contentRange, NSRange(location: 13, length: 5))
    }

    func testExcludesHashtagInsideExcludedRange() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(
            in: "#tag1 #tag2",
            excluding: [NSRange(location: 0, length: 5)]
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 6, length: 5))
    }

    func testReturnsEmptyForEmptyText() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "")

        XCTAssertEqual(ranges, [])
    }

    func testParsesHashtagWithNumbers() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "task #tag123")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 5, length: 7))
    }

    func testDoesNotParseHashtagStartingWithUnderscore() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "#_invalid")

        XCTAssertEqual(ranges.count, 0)
    }

    func testParsesHashtagAtEndOfText() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "text #tag")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].contentRange, NSRange(location: 5, length: 4))
    }

    func testHashtagRangesDoNotOverlap() {
        let ranges = BlockInputHashtagParsing.hashtagRanges(in: "#a #b #c")

        XCTAssertEqual(ranges.count, 3)
        let sortedLocations = ranges.map(\.contentRange.location).sorted()
        XCTAssertEqual(sortedLocations, ranges.map(\.contentRange.location))
    }
}
