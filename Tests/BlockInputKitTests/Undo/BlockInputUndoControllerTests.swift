import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputUndoControllerTests: XCTestCase {
    func testTextUndoIsScopedToBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "Before"),
            BlockInputBlock(id: secondID, text: "Untouched")
        ])
        let undoController = BlockInputUndoController()

        undoController.registerTextEdit(
            blockID: firstID,
            beforeText: "Before",
            afterText: "After",
            selectionBefore: .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 6)),
            selectionAfter: .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5))
        )
        document.blocks[0].text = "After"

        let undo = undoController.undoTextEdit(in: &document, blockID: firstID)
        let redo = undoController.redoTextEdit(in: &document, blockID: firstID)

        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 6)))
        XCTAssertEqual(redo?.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)))
        XCTAssertEqual(document.blocks[0].text, "After")
        XCTAssertEqual(document.blocks[1].text, "Untouched")
    }

    func testStructuralUndoRestoresDocumentAndSelection() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let before = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ])
        var after = before
        let selectionAfter = after.insertBlock(BlockInputBlock(id: secondID, text: "Second"), at: 1)
        var document = after
        let undoController = BlockInputUndoController()

        undoController.registerStructuralEdit(
            actionName: "Insert Block",
            beforeDocument: before,
            afterDocument: after,
            selectionBefore: .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)),
            selectionAfter: selectionAfter
        )

        let undo = undoController.undoStructuralEdit(in: &document)
        XCTAssertEqual(document, before)
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)))

        let redo = undoController.redoStructuralEdit(in: &document)
        XCTAssertEqual(document, after)
        XCTAssertEqual(redo?.selection, selectionAfter)
    }

    func testStructuralUndoCanReplaceSingleBlock() {
        let blockID = BlockInputBlockID(rawValue: "list")
        let beforeBlock = BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Item")
        var afterBlock = beforeBlock
        afterBlock.indentationLevel = 1
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: "first", text: "First"),
            afterBlock,
            BlockInputBlock(id: "last", text: "Last")
        ])
        let undoController = BlockInputUndoController()

        undoController.registerBlockReplacementStructuralEdit(
            actionName: "Indent Block",
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            selectionBefore: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)),
            selectionAfter: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4))
        )

        let undo = undoController.undoStructuralEdit(in: &document)
        XCTAssertEqual(document.blocks[0].text, "First")
        XCTAssertEqual(document.blocks[1], beforeBlock)
        XCTAssertEqual(document.blocks[2].text, "Last")
        XCTAssertEqual(undo?.actionName, "Indent Block")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))

        let redo = undoController.redoStructuralEdit(in: &document)
        XCTAssertEqual(document.blocks[1], afterBlock)
        XCTAssertEqual(redo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))
    }

    func testTextEditAfterStructuralUndoClearsStructuralRedo() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let before = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        var after = before
        after.blocks[0].kind = .quote
        var document = after
        let undoController = BlockInputUndoController()
        undoController.registerStructuralEdit(
            actionName: "Change Type",
            beforeDocument: before,
            afterDocument: after,
            selectionBefore: nil,
            selectionAfter: nil
        )
        _ = undoController.undoStructuralEdit(in: &document)

        undoController.registerTextEdit(
            blockID: blockID,
            beforeText: "First",
            afterText: "Edited",
            selectionBefore: nil,
            selectionAfter: nil
        )

        XCTAssertNil(undoController.redoStructuralEdit(in: &document))
    }

    func testStructuralEditAfterTextUndoClearsTextRedo() {
        let blockID = BlockInputBlockID(rawValue: "first")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Edited")
        ])
        let undoController = BlockInputUndoController()
        undoController.registerTextEdit(
            blockID: blockID,
            beforeText: "First",
            afterText: "Edited",
            selectionBefore: nil,
            selectionAfter: nil
        )
        _ = undoController.undoTextEdit(in: &document, blockID: blockID)

        let beforeStructural = document
        document.blocks[0].kind = .quote
        undoController.registerStructuralEdit(
            actionName: "Change Type",
            beforeDocument: beforeStructural,
            afterDocument: document,
            selectionBefore: nil,
            selectionAfter: nil
        )

        XCTAssertNil(undoController.redoTextEdit(in: &document, blockID: blockID))
    }

    func testTextUndoRestoresPerLineIndentationLevels() {
        let blockID = BlockInputBlockID(rawValue: "list")
        var document = BlockInputDocument(blocks: [
            BlockInputBlock(
                id: blockID,
                kind: .bulletedListItem,
                text: "One\nTwo\n",
                lineIndentationLevels: [0, 1, 1]
            )
        ])
        let undoController = BlockInputUndoController()

        undoController.registerTextEdit(
            blockID: blockID,
            beforeText: "One\nTwo",
            afterText: "One\nTwo\n",
            beforeLineIndentationLevels: [0, 1],
            afterLineIndentationLevels: [0, 1, 1],
            selectionBefore: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 7)),
            selectionAfter: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 8))
        )

        _ = undoController.undoTextEdit(in: &document, blockID: blockID)

        XCTAssertEqual(document.blocks[0].text, "One\nTwo")
        XCTAssertEqual(document.blocks[0].lineIndentationLevels, [0, 1])

        _ = undoController.redoTextEdit(in: &document, blockID: blockID)

        XCTAssertEqual(document.blocks[0].text, "One\nTwo\n")
        XCTAssertEqual(document.blocks[0].lineIndentationLevels, [0, 1, 1])
    }
}
