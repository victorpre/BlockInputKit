import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewSelectionContractionTests: XCTestCase {
    func testShiftDownShrinksBlockSelectionCreatedUpward() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 2))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([secondID, thirdID]))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .text(BlockInputTextRange(
            blockID: thirdID,
            range: NSRange(location: 0, length: 5)
        )))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftNumericPadUpEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([secondID, thirdID]))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([firstID, secondID, thirdID]))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([secondID, thirdID]))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .text(BlockInputTextRange(
            blockID: thirdID,
            range: NSRange(location: 0, length: 5)
        )))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([secondID, thirdID]))
    }

    func testShiftUpShrinksBlockSelectionCreatedDownward() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([firstID, secondID]))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([firstID, secondID, thirdID]))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([firstID, secondID]))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .text(BlockInputTextRange(
            blockID: firstID,
            range: NSRange(location: 0, length: 5)
        )))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([firstID, secondID]))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .text(BlockInputTextRange(
            blockID: firstID,
            range: NSRange(location: 0, length: 5)
        )))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftNumericPadDownEvent()))
        XCTAssertEqual(mounted.view.selection, .blocks([firstID, secondID]))
    }

    func testShiftUpShrinksMixedSelectionCreatedDownwardToPreviousPartialEndpoint() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftDownEvent()))
        let firstExpansion = mounted.view.selection
        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftDownEvent()))
        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [secondID],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 2, length: 3)),
            trailingTextRange: BlockInputTextRange(blockID: thirdID, range: NSRange(location: 0, length: 1))
        )))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftUpEvent()))

        XCTAssertEqual(mounted.view.selection, firstExpansion)
    }

    func testShiftDownShrinksMixedSelectionCreatedUpwardToPreviousPartialEndpoint() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 2))
        let textView = try XCTUnwrap(item.testingTextView)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftUpEvent()))
        let firstExpansion = mounted.view.selection
        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftUpEvent()))
        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [secondID],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 4, length: 1)),
            trailingTextRange: BlockInputTextRange(blockID: thirdID, range: NSRange(location: 0, length: 3))
        )))

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftDownEvent()))

        XCTAssertEqual(mounted.view.selection, firstExpansion)
    }
}
