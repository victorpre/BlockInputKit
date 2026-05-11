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

    func testHorizontalRuleIsNotEffectivelyEmptyContent() {
        let blockID = BlockInputBlockID(rawValue: "rule")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .horizontalRule)
        ])

        let selection = document.deleteEmptyBlockForBackspaceOrDelete(blockID: blockID)

        XCTAssertFalse(document.isEffectivelyEmpty)
        XCTAssertNil(selection)
        XCTAssertEqual(document.blocks[0].kind, .horizontalRule)
    }

    func testHorizontalRuleBlocksNormalizeStoredText() throws {
        var block = BlockInputBlock(id: "rule", kind: .horizontalRule, text: "Hidden")

        XCTAssertEqual(block.text, "")
        XCTAssertEqual(block.utf16Length, 0)

        block.text = "Ignored"
        XCTAssertEqual(block.text, "")

        block.kind = .paragraph
        block.text = "Visible"
        block.kind = .horizontalRule
        XCTAssertEqual(block.text, "")

        let encoded = try JSONEncoder().encode(BlockInputBlock(id: "decoded", kind: .horizontalRule))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload["text"] = "Hidden"
        let staleEncoded = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(BlockInputBlock.self, from: staleEncoded)
        XCTAssertEqual(decoded.text, "")
    }

    func testNonListBlocksNormalizeIndentation() throws {
        var block = BlockInputBlock(id: "quote", kind: .quote, text: "Quoted", indentationLevel: 2)

        XCTAssertEqual(block.indentationLevel, 0)

        block.kind = .bulletedListItem
        block.indentationLevel = 2
        XCTAssertEqual(block.indentationLevel, 2)

        block.kind = .heading(level: 2)
        XCTAssertEqual(block.indentationLevel, 0)

        let encoded = try JSONEncoder().encode(BlockInputBlock(
            id: "decoded",
            kind: .bulletedListItem,
            text: "Nested",
            indentationLevel: 3
        ))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload["kind"] = ["quote": [:]]
        let staleEncoded = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(BlockInputBlock.self, from: staleEncoded)
        XCTAssertEqual(decoded.indentationLevel, 0)
    }

    func testChangingBlockKindToHorizontalRuleClearsText() {
        let blockID = BlockInputBlockID(rawValue: "rule")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Will be cleared", indentationLevel: 2)
        ])

        let selection = document.changeBlockKind(blockID: blockID, to: .horizontalRule)

        XCTAssertEqual(document.blocks[0].kind, .horizontalRule)
        XCTAssertEqual(document.blocks[0].text, "")
        XCTAssertEqual(document.blocks[0].indentationLevel, 0)
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

    func testReplacingTextInHorizontalRuleIsNoOp() {
        let blockID = BlockInputBlockID(rawValue: "rule")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .horizontalRule)
        ])

        let selection = document.replaceText(
            in: blockID,
            range: NSRange(location: 0, length: 0),
            replacement: "Hidden"
        )

        XCTAssertEqual(document.blocks[0].kind, .horizontalRule)
        XCTAssertEqual(document.blocks[0].text, "")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
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

    func testIndentIgnoresNonListBlocks() {
        let blockID = BlockInputBlockID(rawValue: "quote")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "Quote")
        ])

        let selection = document.indentBlock(blockID: blockID)

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

    func testToggleChecklistItemFlipsCheckedState() {
        let blockID = BlockInputBlockID(rawValue: "check")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "Done")
        ])

        let selection = document.toggleChecklistItem(blockID: blockID)

        XCTAssertEqual(document.blocks[0].kind, .checklistItem(isChecked: true))
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))
    }

    func testToggleChecklistItemIgnoresNonChecklistBlocks() {
        let blockID = BlockInputBlockID(rawValue: "paragraph")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .paragraph, text: "Same")
        ])

        let selection = document.toggleChecklistItem(blockID: blockID)

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
