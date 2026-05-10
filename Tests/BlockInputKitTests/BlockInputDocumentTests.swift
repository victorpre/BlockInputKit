import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputDocumentTests: XCTestCase {
    func testDefaultDocumentStartsWithOneEmptyParagraph() {
        let document = BlockInputDocument()

        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0].kind, .paragraph)
        XCTAssertTrue(document.isEffectivelyEmpty)
    }

    func testMarkdownRoundTripsSupportedBlockKinds() {
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(id: "intro", kind: .paragraph, text: "Intro"),
            BlockInputBlock(id: "code", kind: .code(language: "swift"), text: "let value = 1"),
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

    func testDeleteEmptyBlockFocusesEndOfPreviousBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "Before"),
            BlockInputBlock(id: secondID, text: "")
        ])

        let selection = document.deleteEmptyBlockForBackspaceOrDelete(blockID: secondID)

        XCTAssertEqual(document.blocks.map(\.id), [firstID])
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 6)))
    }

    func testDeleteEmptyFirstBlockFocusesNextRemainingBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: ""),
            BlockInputBlock(id: secondID, text: "After")
        ])

        let selection = document.deleteEmptyBlockForBackspaceOrDelete(blockID: firstID)

        XCTAssertEqual(document.blocks.map(\.id), [secondID])
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 0)))
    }

    func testDeleteOnlyBlockKeepsOneEmptyParagraphFocused() {
        let blockID = BlockInputBlockID(rawValue: "only")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "")
        ])

        let selection = document.deleteEmptyBlockForBackspaceOrDelete(blockID: blockID)

        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0].id, blockID)
        XCTAssertEqual(document.blocks[0].kind, .paragraph)
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testReplacingTextUsesUTF16Offsets() {
        let blockID = BlockInputBlockID(rawValue: "emoji")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "a😀c")
        ])

        let selection = document.replaceText(
            in: blockID,
            range: NSRange(location: 1, length: 2),
            replacement: "b"
        )

        XCTAssertEqual(document.blocks[0].text, "abc")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 2)))
    }

    func testReplacingTextClampsSelectionToActualEditLocation() {
        let blockID = BlockInputBlockID(rawValue: "short")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "abc")
        ])

        let selection = document.replaceText(
            in: blockID,
            range: NSRange(location: 10, length: 5),
            replacement: "d"
        )

        XCTAssertEqual(document.blocks[0].text, "abcd")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))
    }

    func testMoveBlockUsesFinalTargetIndex() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])

        let selection = document.moveBlock(blockID: firstID, to: 2)

        XCTAssertEqual(document.blocks.map(\.id), [secondID, thirdID, firstID])
        XCTAssertEqual(selection, .blocks([firstID]))
    }

    func testMoveBlockToSameIndexIsNoOp() {
        let blockID = BlockInputBlockID(rawValue: "only")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Only")
        ])

        let selection = document.moveBlock(blockID: blockID, to: 0)

        XCTAssertNil(selection)
        XCTAssertEqual(document.blocks.map(\.id), [blockID])
    }

    func testOutdentAtRootLevelIsNoOp() {
        let blockID = BlockInputBlockID(rawValue: "root")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Root", indentationLevel: 0)
        ])

        let selection = document.outdentBlock(blockID: blockID)

        XCTAssertNil(selection)
        XCTAssertEqual(document.blocks[0].indentationLevel, 0)
    }

    func testChangeBlockKindToExistingKindIsNoOp() {
        let blockID = BlockInputBlockID(rawValue: "paragraph")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .paragraph, text: "Same")
        ])

        let selection = document.changeBlockKind(blockID: blockID, to: .paragraph)

        XCTAssertNil(selection)
        XCTAssertEqual(document.blocks[0].kind, .paragraph)
    }

    func testSelectAllEscalatesFromCurrentBlockToAllBlocks() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "Hello"),
            BlockInputBlock(id: secondID, text: "World")
        ])

        let firstSelection = document.selectAll(currentBlockID: firstID, currentSelection: nil)
        let secondSelection = document.selectAll(currentBlockID: firstID, currentSelection: firstSelection)

        XCTAssertEqual(firstSelection, .text(BlockInputTextRange(
            blockID: firstID,
            range: NSRange(location: 0, length: 5)
        )))
        XCTAssertEqual(secondSelection, .blocks([firstID, secondID]))
    }

    func testSelectAllKeepsAllBlocksSelectedWhenAlreadyEscalated() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "Hello"),
            BlockInputBlock(id: secondID, text: "World")
        ])

        let selection = document.selectAll(
            currentBlockID: firstID,
            currentSelection: .blocks([firstID, secondID])
        )

        XCTAssertEqual(selection, .blocks([firstID, secondID]))
    }
}
