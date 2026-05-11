import XCTest
@testable import BlockInputKit

final class BlockInputDocumentReturnTests: XCTestCase {
    func testReturnInsertsEmptyParagraphBelowCurrentBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "Hello")
        ])

        let selection = document.handleReturn(in: firstID)

        XCTAssertEqual(document.blocks.count, 2)
        XCTAssertEqual(document.blocks[0].text, "Hello")
        XCTAssertEqual(document.blocks[1].kind, .paragraph)
        XCTAssertEqual(document.blocks[1].text, "")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: document.blocks[1].id, utf16Offset: 0)))
    }

    func testReturnInListItemContinuesListKindAndIndentation() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Item", indentationLevel: 2)
        ])

        let selection = document.handleReturn(in: blockID)

        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0].kind, .bulletedListItem)
        XCTAssertEqual(document.blocks[0].indentationLevel, 2)
        XCTAssertEqual(document.blocks[0].text, "Item\n")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 5)))
    }

    func testReturnInListItemInsertsLineAtCursorOffset() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "BeforeAfter")
        ])

        let selection = document.handleReturn(in: blockID, utf16Offset: 6)

        XCTAssertEqual(document.blocks, [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Before\nAfter")
        ])
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 7)))
    }

    func testReturnInListItemReplacesSelectedTextWithNewLine() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "BeforeMiddleAfter")
        ])

        let selection = document.handleReturn(in: blockID, utf16Offset: 6, selectedUTF16Length: 6)

        XCTAssertEqual(document.blocks, [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Before\nAfter")
        ])
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 7)))
    }

    func testReturnOnEmptyInlineListLineRemovesLineAndInsertsParagraphBelow() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Item\n")
        ])

        let selection = document.handleReturn(in: blockID, utf16Offset: 5)

        XCTAssertEqual(document.blocks.count, 2)
        XCTAssertEqual(document.blocks[0], BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Item"))
        XCTAssertEqual(document.blocks[1].kind, .paragraph)
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: document.blocks[1].id, utf16Offset: 0)))
    }

    func testReturnOnWhitespaceOnlyInlineListLineRemovesLineAndInsertsParagraphBelow() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Item\n   ")
        ])

        let selection = document.handleReturn(in: blockID, utf16Offset: 8)

        XCTAssertEqual(document.blocks.count, 2)
        XCTAssertEqual(document.blocks[0], BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Item"))
        XCTAssertEqual(document.blocks[1].kind, .paragraph)
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: document.blocks[1].id, utf16Offset: 0)))
    }

    func testReturnOnMiddleEmptyInlineListLineSplitsAroundInsertedParagraph() {
        let blockID = BlockInputBlockID(rawValue: "number")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .numberedListItem(start: 4), text: "First\n\nThird")
        ])

        let selection = document.handleReturn(in: blockID, utf16Offset: 6)

        XCTAssertEqual(document.blocks.count, 3)
        XCTAssertEqual(document.blocks[0], BlockInputBlock(id: blockID, kind: .numberedListItem(start: 4), text: "First"))
        XCTAssertEqual(document.blocks[1].kind, .paragraph)
        XCTAssertEqual(document.blocks[2].kind, .numberedListItem(start: 5))
        XCTAssertEqual(document.blocks[2].text, "Third")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: document.blocks[1].id, utf16Offset: 0)))
    }

    func testReturnOnEmptyInlineListLinePreservesAdjacentEmptyLines() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First\n\n\nFourth")
        ])

        _ = document.handleReturn(in: blockID, utf16Offset: 6)

        XCTAssertEqual(document.blocks.count, 3)
        XCTAssertEqual(document.blocks[0], BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First"))
        XCTAssertEqual(document.blocks[2].kind, .bulletedListItem)
        XCTAssertEqual(document.blocks[2].text, "\nFourth")
    }

    func testReturnInNumberedListItemAddsLineInsideCurrentBlock() {
        let blockID = BlockInputBlockID(rawValue: "number")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .numberedListItem(start: 3), text: "Item")
        ])

        _ = document.handleReturn(in: blockID)

        XCTAssertEqual(document.blocks, [
            BlockInputBlock(id: blockID, kind: .numberedListItem(start: 3), text: "Item\n")
        ])
    }

    func testReturnInChecklistItemAddsLineInsideCurrentBlock() {
        let blockID = BlockInputBlockID(rawValue: "check")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: true), text: "Done", indentationLevel: 1)
        ])

        _ = document.handleReturn(in: blockID)

        XCTAssertEqual(document.blocks, [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: true), text: "Done\n", indentationLevel: 1)
        ])
    }

    func testReturnInQuoteAddsLineInsideCurrentBlock() {
        let blockID = BlockInputBlockID(rawValue: "quote")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "Quoted")
        ])

        _ = document.handleReturn(in: blockID)

        XCTAssertEqual(document.blocks, [
            BlockInputBlock(id: blockID, kind: .quote, text: "Quoted\n")
        ])
    }

    func testReturnInEmptyListItemExitsToParagraphAtSamePosition() {
        let blockID = BlockInputBlockID(rawValue: "empty")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: "previous", kind: .bulletedListItem, text: "Previous"),
            BlockInputBlock(id: blockID, kind: .bulletedListItem),
            BlockInputBlock(id: "next", text: "Next")
        ])

        let selection = document.handleReturn(in: blockID)

        XCTAssertEqual(document.blocks.map(\.id), ["previous", blockID, "next"])
        XCTAssertEqual(document.blocks[1].kind, .paragraph)
        XCTAssertEqual(document.blocks[1].text, "")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testReturnInEmptyFormattedBlockExitsToParagraphAtSamePosition() {
        let blockID = BlockInputBlockID(rawValue: "heading")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .heading(level: 2))
        ])

        let selection = document.handleReturn(in: blockID)

        XCTAssertEqual(document.blocks, [BlockInputBlock(id: blockID, kind: .paragraph)])
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }
}
