import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputMarkdownTests: XCTestCase {
    func testMarkdownRoundTripsSupportedBlockKinds() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(id: "intro", kind: .paragraph, text: "Intro"),
            BlockInputBlock(id: "heading", kind: .heading(level: 2), text: "Heading"),
            BlockInputBlock(id: "code", kind: .code(language: "swift"), text: "let value = 1"),
            BlockInputBlock(id: "rule", kind: .horizontalRule),
            BlockInputBlock(id: "quote", kind: .quote, text: "Quoted\nText"),
            BlockInputBlock(id: "bullet", kind: .bulletedListItem, text: "Bullet", indentationLevel: 1),
            BlockInputBlock(id: "number", kind: .numberedListItem(start: 3), text: "Numbered"),
            BlockInputBlock(id: "check", kind: .checklistItem(isChecked: true), text: "Done")
        ])

        let markdown = document.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(parsed.blocks.map(\.kind), document.blocks.map(\.kind))
        XCTAssertEqual(parsed.blocks.map(\.text), document.blocks.map(\.text))
        XCTAssertEqual(parsed.blocks.map(\.indentationLevel), document.blocks.map(\.indentationLevel))
    }

    func testMarkdownRoundTripKeepsAdjacentParagraphBlocksSeparate() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(id: "first", kind: .paragraph, text: "First"),
            BlockInputBlock(id: "second", kind: .paragraph, text: "Second")
        ])

        let parsed = BlockInputDocument(markdown: document.markdown)

        XCTAssertEqual(parsed.blocks.map(\.kind), [.paragraph, .paragraph])
        XCTAssertEqual(parsed.blocks.map(\.text), ["First", "Second"])
    }

    func testMarkdownRoundTripsMultilineListBlocks() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(id: "bullet", kind: .bulletedListItem, text: "One\nTwo\n", indentationLevel: 1),
            BlockInputBlock(id: "number", kind: .numberedListItem(start: 3), text: "Three\nFour\n"),
            BlockInputBlock(id: "check", kind: .checklistItem(isChecked: false), text: "Todo\nLater\n")
        ])

        let parsed = BlockInputDocument(markdown: document.markdown)

        XCTAssertEqual(parsed.blocks.map(\.kind), document.blocks.map(\.kind))
        XCTAssertEqual(parsed.blocks.map(\.text), document.blocks.map(\.text))
        XCTAssertEqual(parsed.blocks.map(\.indentationLevel), document.blocks.map(\.indentationLevel))
    }

    func testMarkdownRoundTripsPerLineListIndentation() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(
                id: "bullet",
                kind: .bulletedListItem,
                text: "One\nTwo\nThree",
                lineIndentationLevels: [0, 1, 2]
            )
        ])

        let markdown = document.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(markdown, "- One\n  - Two\n    - Three")
        XCTAssertEqual(parsed.blocks[0].kind, .bulletedListItem)
        XCTAssertEqual(parsed.blocks[0].text, "One\nTwo\nThree")
        XCTAssertEqual(parsed.blocks[0].lineIndentationLevels, [0, 1, 2])
    }

    func testMarkdownTreatsCRLFAsSingleLineBreak() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(
                id: "bullet",
                kind: .bulletedListItem,
                text: "One\r\nTwo",
                lineIndentationLevels: [0, 1]
            )
        ])

        let markdown = document.markdown
        let parsed = BlockInputDocument(markdown: "- One\r\n  - Two")

        XCTAssertEqual(markdown, "- One\n  - Two")
        XCTAssertEqual(parsed.blocks[0].text, "One\nTwo")
        XCTAssertEqual(parsed.blocks[0].lineIndentationLevels, [0, 1])
    }

    func testMarkdownRoundTripsNestedOrderedListIndentationWithPerLevelCounters() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(
                id: "number",
                kind: .numberedListItem(start: 1),
                text: "One\nTwo\nThree\nFour\nFive",
                lineIndentationLevels: [0, 1, 2, 1, 0]
            )
        ])

        let markdown = document.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(markdown, "1. One\n  1. Two\n    1. Three\n  2. Four\n2. Five")
        XCTAssertEqual(parsed.blocks[0].kind, .numberedListItem(start: 1))
        XCTAssertEqual(parsed.blocks[0].text, "One\nTwo\nThree\nFour\nFive")
        XCTAssertEqual(parsed.blocks[0].lineIndentationLevels, [0, 1, 2, 1, 0])
    }

    func testMarkdownRoundTripsIndentedOrderedListStartAtBaselineIndentation() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(
                id: "number",
                kind: .numberedListItem(start: 3),
                text: "One\nTwo\nThree",
                lineIndentationLevels: [1, 2, 1]
            )
        ])

        let markdown = document.markdown
        let parsed = BlockInputDocument(markdown: markdown)

        XCTAssertEqual(markdown, "  3. One\n    1. Two\n  4. Three")
        XCTAssertEqual(parsed.blocks[0].kind, .numberedListItem(start: 3))
        XCTAssertEqual(parsed.blocks[0].text, "One\nTwo\nThree")
        XCTAssertEqual(parsed.blocks[0].lineIndentationLevels, [1, 2, 1])
    }

    func testMarkdownKeepsUnexpectedNumberedListSequenceSeparate() {
        let parsed = BlockInputDocument(markdown: "1. One\n3. Three")

        XCTAssertEqual(parsed.blocks.count, 2)
        XCTAssertEqual(parsed.blocks[0].kind, .numberedListItem(start: 1))
        XCTAssertEqual(parsed.blocks[0].text, "One")
        XCTAssertEqual(parsed.blocks[1].kind, .numberedListItem(start: 3))
        XCTAssertEqual(parsed.blocks[1].text, "Three")
    }
}
