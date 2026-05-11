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
}
