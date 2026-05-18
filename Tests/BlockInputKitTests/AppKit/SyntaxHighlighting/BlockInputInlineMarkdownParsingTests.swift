import XCTest
@testable import BlockInputKit

final class BlockInputInlineMarkdownParsingTests: XCTestCase {
    func testParsesSupportedInlineMarkdownRangesWithMultiWordContent() {
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: "*some text* **bold text** <u>underlined text</u> ~~struck text~~"
        )

        XCTAssertEqual(ranges.map(\.style), [.italic, .bold, .underline, .strikethrough])
        XCTAssertEqual(ranges.map { content(in: "*some text* **bold text** <u>underlined text</u> ~~struck text~~", range: $0.contentRange) }, [
            "some text",
            "bold text",
            "underlined text",
            "struck text"
        ])
    }

    func testParsesMultipleSpans() {
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "*one* and *two*")

        XCTAssertEqual(ranges.map(\.contentRange), [
            NSRange(location: 1, length: 3),
            NSRange(location: 11, length: 3)
        ])
    }

    func testBoldPrecedenceSkipsSingleStarInsideDoubleStarDelimiters() {
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "**bold text**")

        XCTAssertEqual(ranges, [
            BlockInputInlineMarkdownRange(
                style: .bold,
                fullRange: NSRange(location: 0, length: 13),
                contentRange: NSRange(location: 2, length: 9),
                delimiterRanges: [
                    NSRange(location: 0, length: 2),
                    NSRange(location: 11, length: 2)
                ]
            )
        ])
    }

    func testUnderscoreDelimitersMatchAsteriskBehavior() {
        let text = "_italic text_"
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text)

        XCTAssertEqual(ranges.map(\.style), [.italic])
        XCTAssertEqual(ranges.map { content(in: text, range: $0.contentRange) }, [
            "italic text"
        ])
        XCTAssertEqual(ranges.map(\.delimiterRanges), [
            [NSRange(location: 0, length: 1), NSRange(location: 12, length: 1)]
        ])
    }

    func testAllowsComposedOverlappingStyles() {
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "*some **bold** text*")

        XCTAssertEqual(ranges.map(\.style), [.italic, .bold])
        XCTAssertEqual(ranges.map { content(in: "*some **bold** text*", range: $0.contentRange) }, [
            "some **bold** text",
            "bold"
        ])
    }

    func testParsesTripleAsteriskAsBoldAndItalic() {
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "***bold and italic***")
        let expectedContentRange = NSRange(location: 3, length: 15)
        let expectedDelimiterRanges = [
            NSRange(location: 0, length: 3),
            NSRange(location: 18, length: 3)
        ]

        XCTAssertEqual(ranges, [
            BlockInputInlineMarkdownRange(
                style: .bold,
                fullRange: NSRange(location: 0, length: 21),
                contentRange: expectedContentRange,
                delimiterRanges: expectedDelimiterRanges
            ),
            BlockInputInlineMarkdownRange(
                style: .italic,
                fullRange: NSRange(location: 0, length: 21),
                contentRange: expectedContentRange,
                delimiterRanges: expectedDelimiterRanges
            )
        ])
    }

    func testParsesNestedInlineMarkdownExamples() {
        let examples: [InlineMarkdownNestedParsingCase] = [
            InlineMarkdownNestedParsingCase(
                text: "**_bold and italic_**",
                styles: [.bold, .italic],
                contents: ["_bold and italic_", "bold and italic"]
            ),
            InlineMarkdownNestedParsingCase(
                text: "**<u>bold and underlined</u>**",
                styles: [.bold, .underline],
                contents: ["<u>bold and underlined</u>", "bold and underlined"]
            ),
            InlineMarkdownNestedParsingCase(
                text: "~~*strikethrough and italic*~~",
                styles: [.strikethrough, .italic],
                contents: ["*strikethrough and italic*", "strikethrough and italic"]
            )
        ]

        for example in examples {
            let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: example.text)

            XCTAssertEqual(ranges.map(\.style), example.styles, "Unexpected styles for \(example.text).")
            XCTAssertEqual(
                ranges.map { content(in: example.text, range: $0.contentRange) },
                example.contents,
                "Unexpected content ranges for \(example.text)."
            )
        }
    }

    func testIgnoresInvalidSpans() {
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "*"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "**"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "****"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "____"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "__bold text__"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "~~~struck~~~"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "___text___"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<u></u>"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<u class=\"x\">text</u>"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<ins></ins>"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<ins class=\"x\">text</ins>"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<ins>text</u>"), [])
    }

    func testDoesNotCrossLineBoundaries() {
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "*some\ntext*"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "**some\ntext**"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "_some\ntext_"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<u>some\ntext</u>"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<ins>some\ntext</ins>"), [])
        XCTAssertEqual(BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "~~some\ntext~~"), [])
    }

    func testExcludesInlineCodeRanges() throws {
        let text = "Use `*code*` and *text*"
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)

        XCTAssertEqual(ranges.map(\.style), [.italic])
        XCTAssertEqual(content(in: text, range: try XCTUnwrap(ranges.first?.contentRange)), "text")
    }

    func testExcludesInlineCodeRangesForUnderscores() throws {
        let text = "Use `_code_` and _text_"
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)

        XCTAssertEqual(ranges.map(\.style), [.italic])
        XCTAssertEqual(content(in: text, range: try XCTUnwrap(ranges.first?.contentRange)), "text")
    }

    func testExcludesInlineCodeRangesForComposedDelimiters() {
        let text = "Use `***code***` and ***text***"
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)

        XCTAssertEqual(ranges.map(\.style), [.bold, .italic])
        XCTAssertEqual(ranges.map { content(in: text, range: $0.contentRange) }, ["text", "text"])
    }

    func testLargeInputWithManyExcludedRangesFindsOnlyOutsideSpans() throws {
        let chunkCount = 2_500
        let text = (0..<chunkCount)
            .map { "`*code \($0)*` *text \($0)*" }
            .joined(separator: " ")
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)

        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)

        XCTAssertEqual(ranges.count, chunkCount)
        XCTAssertEqual(content(in: text, range: try XCTUnwrap(ranges.first?.contentRange)), "text 0")
        XCTAssertEqual(content(in: text, range: try XCTUnwrap(ranges.last?.contentRange)), "text \(chunkCount - 1)")
    }

    func testLargeInputWithUnmatchedOpenersDoesNotCreateRanges() {
        let text = Array(repeating: "<u>unclosed", count: 2_500).joined(separator: " ")

        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text)

        XCTAssertEqual(ranges, [])
    }

    func testParsesOuterSpansAroundInlineCodeContent() throws {
        let text = "*some `code` text*"
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: text, excluding: inlineCodeRanges)

        XCTAssertEqual(ranges.map(\.style), [.italic])
        XCTAssertEqual(content(in: text, range: try XCTUnwrap(ranges.first?.contentRange)), "some `code` text")
    }

    func testUnderlineTagsAreCaseInsensitiveExactTags() throws {
        let ranges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(in: "<U>some text</U> and <INS>inserted text</INS>")

        XCTAssertEqual(ranges.map(\.style), [.underline, .underline])
        XCTAssertEqual(ranges.map { content(in: "<U>some text</U> and <INS>inserted text</INS>", range: $0.contentRange) }, [
            "some text",
            "inserted text"
        ])
    }
}

private func content(in text: String, range: NSRange) -> String {
    (text as NSString).substring(with: range)
}

private struct InlineMarkdownNestedParsingCase {
    let text: String
    let styles: [BlockInputInlineMarkdownStyle]
    let contents: [String]
}
