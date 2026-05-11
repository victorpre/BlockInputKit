import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewFocusTests: XCTestCase {
    func testWindowCanMakeEditorFirstResponderWithCursorSelection() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        mounted.view.focus(blockID: blockID, utf16Offset: 2)

        XCTAssertTrue(mounted.window.makeFirstResponder(mounted.view))

        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        XCTAssertTrue(mounted.window.firstResponder === textView)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0))
        XCTAssertEqual(
            mounted.view.selection,
            .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 2))
        )
    }

    func testWindowCanMakeEditorFirstResponderWithTextSelection() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedView(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])
        mounted.view.applySelection(.text(BlockInputTextRange(
            blockID: blockID,
            range: NSRange(location: 1, length: 3)
        )), notify: false)

        XCTAssertTrue(mounted.window.makeFirstResponder(mounted.view))

        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        XCTAssertTrue(mounted.window.firstResponder === textView)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 1, length: 3))
        XCTAssertEqual(
            mounted.view.selection,
            .text(BlockInputTextRange(blockID: blockID, range: NSRange(location: 1, length: 3)))
        )
    }

    private func makeMountedView(blocks: [BlockInputBlock]) -> (view: BlockInputView, window: NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let view = BlockInputView(frame: window.contentView?.bounds ?? window.frame)
        window.contentView = view
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: blocks),
            undoController: BlockInputUndoController()
        ))
        view.layoutSubtreeIfNeeded()
        view.collectionView.layoutSubtreeIfNeeded()
        return (view, window)
    }
}

private extension BlockInputView {
    func visibleBlockItemForTesting(at item: Int) -> BlockInputBlockItem? {
        collectionView.scrollToItems(at: [IndexPath(item: item, section: 0)], scrollPosition: .nearestVerticalEdge)
        collectionView.layoutSubtreeIfNeeded()
        return collectionView.item(at: IndexPath(item: item, section: 0)) as? BlockInputBlockItem
    }
}
