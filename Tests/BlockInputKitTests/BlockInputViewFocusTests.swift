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

    func testEditingPublishesFocusChanges() async throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        var focusValues: [Bool] = []
        let lostFocus = expectation(description: "Publishes focus loss")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            onFocusChange: { isFocused in
                focusValues.append(isFocused)
                if !isFocused {
                    lostFocus.fulfill()
                }
            }
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )

        view.blockItemDidBeginEditing(item, blockID: blockID)
        view.blockItemDidEndEditing(item, blockID: blockID)

        await fulfillment(of: [lostFocus], timeout: 1)
        XCTAssertEqual(focusValues, [true, false])
    }

    func testBecomingFirstResponderWithBlockSelectionPublishesFocus() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var focusValues: [Bool] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: "First"),
                BlockInputBlock(id: secondID, text: "Second")
            ]),
            onFocusChange: { focusValues.append($0) }
        ))
        mounted.view.applySelection(.blocks([firstID, secondID]), notify: false)

        XCTAssertTrue(mounted.window.makeFirstResponder(mounted.view))

        XCTAssertEqual(focusValues, [true])
    }

    func testBecomingFirstResponderWithCursorSelectionDoesNotPublishTransientFocusLoss() {
        let blockID = BlockInputBlockID(rawValue: "first")
        var focusValues: [Bool] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            onFocusChange: { focusValues.append($0) }
        ))
        mounted.view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)

        XCTAssertTrue(mounted.window.makeFirstResponder(mounted.view))

        XCTAssertEqual(focusValues, [true])
    }

    func testFocusEditorWithExistingCursorSelectionPublishesFocus() {
        let blockID = BlockInputBlockID(rawValue: "first")
        var focusValues: [Bool] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            onFocusChange: { focusValues.append($0) }
        ))
        mounted.view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 2)), notify: false)

        mounted.view.focusEditor()

        XCTAssertTrue(mounted.view.isEditorFirstResponder)
        XCTAssertEqual(focusValues, [true])
    }

    func testFocusEditorWithExistingBlockSelectionPublishesFocus() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var focusValues: [Bool] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: "First"),
                BlockInputBlock(id: secondID, text: "Second")
            ]),
            onFocusChange: { focusValues.append($0) }
        ))
        mounted.view.applySelection(.blocks([firstID, secondID]), notify: false)

        mounted.view.focusEditor()

        XCTAssertTrue(mounted.window.firstResponder === mounted.view)
        XCTAssertEqual(focusValues, [true])
    }

    func testMovingFromBlockSelectionToTextFocusDoesNotPublishTransientFocusLoss() async {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var focusValues: [Bool] = []
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: "First"),
                BlockInputBlock(id: secondID, text: "Second")
            ]),
            onFocusChange: { focusValues.append($0) }
        ))
        mounted.view.applySelection(.blocks([firstID, secondID]), notify: false)
        mounted.window.makeFirstResponder(mounted.view)

        mounted.view.focus(blockID: firstID, utf16Offset: 0)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(focusValues, [true])
    }

    func testResigningFirstResponderWithBlockSelectionPublishesFocusLoss() async {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var focusValues: [Bool] = []
        let lostFocus = expectation(description: "Publishes focus loss")
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: "First"),
                BlockInputBlock(id: secondID, text: "Second")
            ]),
            onFocusChange: { isFocused in
                focusValues.append(isFocused)
                if !isFocused {
                    lostFocus.fulfill()
                }
            }
        ))
        mounted.view.applySelection(.blocks([firstID, secondID]), notify: false)
        mounted.window.makeFirstResponder(mounted.view)

        mounted.window.makeFirstResponder(nil)

        await fulfillment(of: [lostFocus], timeout: 1)
        XCTAssertEqual(focusValues, [true, false])
    }

}
