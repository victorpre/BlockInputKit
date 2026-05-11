import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewTypingShortcutUndoTests: XCTestCase {
    func testTypingShortcutUsesStructuralUndoStack() throws {
        let blockID = BlockInputBlockID(rawValue: "heading")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "")
            ]),
            undoController: undoController
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        _ = item.textView(textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "# Heading")
        textView.string = "# Heading"
        textView.setSelectedRange(NSRange(location: 9, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        let undo = view.undoStructuralEdit()
        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))

        let redo = view.redoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Format Block")
        XCTAssertEqual(redo?.actionName, "Format Block")
        XCTAssertEqual(view.document.blocks[0].kind, .heading(level: 1))
        XCTAssertEqual(view.document.blocks[0].text, "Heading")
    }

    func testTypingShortcutUndoKeepsCapturedTextSelection() throws {
        let blockID = BlockInputBlockID(rawValue: "heading")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Selected")
            ]),
            undoController: undoController
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        _ = item.textView(
            textView,
            shouldChangeTextIn: NSRange(location: 0, length: 8),
            replacementString: "# Heading"
        )
        textView.string = "# Heading"
        textView.setSelectedRange(NSRange(location: 9, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        let undo = view.undoStructuralEdit()

        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, "Selected")
        XCTAssertEqual(undo?.selection, .text(BlockInputTextRange(
            blockID: blockID,
            range: NSRange(location: 0, length: 8)
        )))
    }

    func testBulletToChecklistShortcutUndoRestoresEmptyBulletSelection() throws {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "")
            ]),
            undoController: undoController
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        _ = item.textView(textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "[ ]")
        textView.string = "[ ]"
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        let undo = view.undoStructuralEdit()
        XCTAssertEqual(view.document.blocks[0].kind, .bulletedListItem)
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))

        _ = view.redoStructuralEdit()

        XCTAssertEqual(view.document.blocks[0].kind, .checklistItem(isChecked: false))
    }

    func testHorizontalRuleTypingShortcutUndoRestoresOriginalBlockCount() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: ""),
                BlockInputBlock(id: secondID, text: "Second")
            ]),
            undoController: undoController
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        _ = item.textView(textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "---")
        textView.string = "---"
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Format Block")
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, secondID])
        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 0)))

        let redo = view.redoStructuralEdit()

        XCTAssertEqual(redo?.actionName, "Format Block")
        XCTAssertEqual(view.document.blocks.count, 3)
        XCTAssertEqual(view.document.blocks[0].id, firstID)
        XCTAssertEqual(view.document.blocks[0].kind, .horizontalRule)
        XCTAssertEqual(view.document.blocks[2].id, secondID)
        XCTAssertEqual(redo?.selection, .cursor(BlockInputCursor(blockID: view.document.blocks[1].id, utf16Offset: 0)))
    }
}
