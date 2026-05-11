import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewFocusTests: XCTestCase {
    func testWindowCanMakeEditorFirstResponderWithCursorSelection() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedBlockInputView(blocks: [
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
        let mounted = makeMountedBlockInputView(blocks: [
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

}
