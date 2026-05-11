import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewReturnUndoTests: XCTestCase {
    func testReturnInEmptyFormattedBlockUsesUnformatStructuralUndoAction() {
        let blockID = BlockInputBlockID(rawValue: "quote")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .quote)
            ]),
            undoController: undoController
        ))
        view.focus(blockID: blockID)

        _ = view.insertBlockBelowCurrentBlock()
        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Unformat Block")
        XCTAssertEqual(view.document.blocks, [BlockInputBlock(id: blockID, kind: .quote)])

        let redo = view.redoStructuralEdit()

        XCTAssertEqual(redo?.actionName, "Unformat Block")
        XCTAssertEqual(view.document.blocks, [BlockInputBlock(id: blockID, kind: .paragraph)])
    }

    func testReturnInInlineBlockUsesInsertLineStructuralUndoAction() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "BeforeAfter")
            ]),
            undoController: undoController
        ))
        view.applySelection(.text(BlockInputTextRange(blockID: blockID, range: NSRange(location: 6, length: 1))), notify: false)

        _ = view.insertBlockBelowCurrentBlock()
        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Insert Line")
        XCTAssertEqual(view.document.blocks, [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "BeforeAfter")
        ])

        let redo = view.redoStructuralEdit()

        XCTAssertEqual(redo?.actionName, "Insert Line")
        XCTAssertEqual(view.document.blocks, [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Before\nfter")
        ])
    }

    func testReturnOnEmptyInlineListLineUsesInsertBlockStructuralUndoAction() {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Before\n")
            ]),
            undoController: undoController
        ))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 7)), notify: false)

        _ = view.insertBlockBelowCurrentBlock()
        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Insert Block")
        XCTAssertEqual(view.document.blocks, [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Before\n")
        ])

        let redo = view.redoStructuralEdit()

        XCTAssertEqual(redo?.actionName, "Insert Block")
        XCTAssertEqual(view.document.blocks.count, 2)
        XCTAssertEqual(view.document.blocks[0], BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Before"))
        XCTAssertEqual(view.document.blocks[1].kind, .paragraph)
    }

    func testReturnOnMiddleEmptyInlineListLineRestoresSplitWithStructuralUndo() {
        let blockID = BlockInputBlockID(rawValue: "number")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .numberedListItem(start: 4), text: "First\n\nThird")
            ]),
            undoController: undoController
        ))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)), notify: false)

        _ = view.insertBlockBelowCurrentBlock()
        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Insert Block")
        XCTAssertEqual(view.document.blocks, [
            BlockInputBlock(id: blockID, kind: .numberedListItem(start: 4), text: "First\n\nThird")
        ])

        let redo = view.redoStructuralEdit()

        XCTAssertEqual(redo?.actionName, "Insert Block")
        XCTAssertEqual(view.document.blocks.count, 3)
        XCTAssertEqual(view.document.blocks[0], BlockInputBlock(id: blockID, kind: .numberedListItem(start: 4), text: "First"))
        XCTAssertEqual(view.document.blocks[1].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[2].kind, .numberedListItem(start: 5))
        XCTAssertEqual(view.document.blocks[2].text, "Third")
    }
}
