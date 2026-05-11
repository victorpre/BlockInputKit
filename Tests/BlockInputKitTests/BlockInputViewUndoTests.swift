import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewUndoTests: XCTestCase {
    func testViewUndoAndRedoStructuralEditPublishesDocumentChange() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        var publishedDocuments: [BlockInputDocument] = []
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: undoController,
            onDocumentChange: { publishedDocuments.append($0) }
        ))
        view.focus(blockID: blockID, utf16Offset: 5)
        _ = view.insertBlockBelowCurrentBlock()

        let undo = view.undoStructuralEdit()
        XCTAssertEqual(view.document.blocks.map(\.id), [blockID])
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 5)))
        XCTAssertEqual(publishedDocuments.last, view.document)

        let redo = view.redoStructuralEdit()
        XCTAssertEqual(view.document.blocks.count, 2)
        XCTAssertEqual(redo?.selection, .cursor(BlockInputCursor(blockID: view.document.blocks[1].id, utf16Offset: 0)))
        XCTAssertEqual(publishedDocuments.last, view.document)
    }

    func testUndoStructuralEditWithNilSelectionCanRefocusEditor() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: undoController
        ))
        _ = view.insertBlockBelowCurrentBlock()

        let undo = view.undoStructuralEdit()
        view.focusEditor()

        XCTAssertNil(undo?.selection)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testViewUndoAndRedoTextEditPublishesDocumentChange() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        var publishedDocuments: [BlockInputDocument] = []
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: undoController,
            onDocumentChange: { publishedDocuments.append($0) }
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "Edited"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        let undo = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks[0].text, "First")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)))
        XCTAssertEqual(publishedDocuments.last, view.document)

        let redo = view.redoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks[0].text, "Edited")
        XCTAssertEqual(redo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)))
        XCTAssertEqual(publishedDocuments.last, view.document)
    }

    func testUndoTextEditRestoresVisibleTextSelectionAfterReload() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let mounted = makeMountedBlockInputView(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: undoController
        )
        mounted.view.applySelection(.text(BlockInputTextRange(
            blockID: blockID,
            range: NSRange(location: 1, length: 3)
        )), notify: false)
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        _ = item.textView(textView, shouldChangeTextIn: NSRange(location: 1, length: 3), replacementString: "dit")
        textView.string = "Edited"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        _ = mounted.view.undoTextEditInActiveBlock()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let restoredItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        XCTAssertEqual(restoredItem.testingTextView?.selectedRange(), NSRange(location: 1, length: 3))
    }

    func testFocusEditorPreservesVisibleTextSelection() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedBlockInputView(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: BlockInputUndoController()
        )
        mounted.view.applySelection(.text(BlockInputTextRange(
            blockID: blockID,
            range: NSRange(location: 1, length: 3)
        )), notify: false)

        mounted.view.focusEditor()

        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        XCTAssertEqual(item.testingTextView?.selectedRange(), NSRange(location: 1, length: 3))
    }

    func testFocusEditorPreservesVisibleBlockSelectionAsEditorResponder() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedBlockInputView(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: BlockInputUndoController()
        )
        mounted.view.applySelection(.blocks([blockID]), notify: false)

        mounted.view.focusEditor()

        XCTAssertEqual(mounted.view.selection, .blocks([blockID]))
        XCTAssertTrue(mounted.window.firstResponder === mounted.view)
    }

    func testWindowCanMakeEditorFirstResponderWithBlockSelection() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedBlockInputView(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            undoController: BlockInputUndoController()
        )
        mounted.view.applySelection(.blocks([blockID]), notify: false)

        XCTAssertTrue(mounted.window.makeFirstResponder(mounted.view))
        XCTAssertEqual(mounted.view.selection, .blocks([blockID]))
        XCTAssertTrue(mounted.window.firstResponder === mounted.view)
    }

}
