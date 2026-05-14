import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewHorizontalSelectionTests: XCTestCase {
    func testShiftRightFromCollapsedCaretCreatesVisiblePartialSelection() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftRightEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 1, length: 1))
        )))
        XCTAssertEqual(item.temporarySelectionHighlightRange, NSRange(location: 1, length: 1))
        XCTAssertFalse(item.testingSelectionBackgroundView.isHidden)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 1, length: 0))
        XCTAssertEqual(mounted.window.firstResponder, mounted.view)
        XCTAssertEqual(item.testingSelectionBackgroundView.frame.minX, try viewX(forUTF16Offset: 1, item: item), accuracy: 1)
        XCTAssertEqual(item.testingSelectionBackgroundView.frame.maxX, try viewX(forUTF16Offset: 2, item: item), accuracy: 1)
        XCTAssertLessThan(item.testingSelectionBackgroundView.frame.width, 24)
    }

    func testShiftLeftFromCollapsedCaretCreatesVisiblePartialSelection() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftLeftEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 1, length: 1))
        )))
        XCTAssertEqual(item.temporarySelectionHighlightRange, NSRange(location: 1, length: 1))
        XCTAssertFalse(item.testingSelectionBackgroundView.isHidden)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 1, length: 0))
        XCTAssertEqual(mounted.window.firstResponder, mounted.view)
    }

    func testShiftDownAfterShiftRightMaintainsAdjustedActiveEdgeX() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])
        let firstItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let secondItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let textView = try XCTUnwrap(firstItem.testingTextView)
        let activeX = try XCTUnwrap(firstItem.textContainerX(forUTF16Offset: 3))
        let expectedSecondOffset = secondItem.utf16Offset(closestToTextContainerX: activeX, linePosition: .first)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftRightEvent()))
        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftDownEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 2, length: 3)),
            trailingTextRange: BlockInputTextRange(blockID: secondID, range: NSRange(location: 0, length: expectedSecondOffset))
        )))
    }

    func testShiftUpAfterShiftLeftMaintainsAdjustedActiveEdgeX() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])
        let firstItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let secondItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let textView = try XCTUnwrap(secondItem.testingTextView)
        let activeX = try XCTUnwrap(secondItem.textContainerX(forUTF16Offset: 2))
        let expectedFirstOffset = firstItem.utf16Offset(closestToTextContainerX: activeX, linePosition: .last)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftLeftEvent()))
        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftUpEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [],
            leadingTextRange: BlockInputTextRange(
                blockID: firstID,
                range: NSRange(location: expectedFirstOffset, length: 5 - expectedFirstOffset)
            ),
            trailingTextRange: BlockInputTextRange(blockID: secondID, range: NSRange(location: 0, length: 3))
        )))
    }

    func testShiftRightFromWholeBlockSelectionSelectsFirstCharacterOfNextBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One"),
            BlockInputBlock(id: secondID, text: "Two")
        ])
        mounted.view.applySelection(.blocks([firstID]), notify: false)
        mounted.window.makeFirstResponder(mounted.view)

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftRightEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [firstID],
            trailingTextRange: BlockInputTextRange(blockID: secondID, range: NSRange(location: 0, length: 1))
        )))
    }

    func testRepeatedShiftRightExtendsTrailingPartialSelection() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One"),
            BlockInputBlock(id: secondID, text: "Two")
        ])
        mounted.view.applySelection(.blocks([firstID]), notify: false)
        mounted.window.makeFirstResponder(mounted.view)

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftRightEvent()))
        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftRightEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [firstID],
            trailingTextRange: BlockInputTextRange(blockID: secondID, range: NSRange(location: 0, length: 2))
        )))
    }

    func testShiftLeftContractsRightwardSelectionBeforeExpandingLeft() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One"),
            BlockInputBlock(id: secondID, text: "Two")
        ])
        mounted.view.applySelection(.blocks([firstID]), notify: false)
        mounted.window.makeFirstResponder(mounted.view)

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftRightEvent()))
        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftLeftEvent()))

        XCTAssertEqual(mounted.view.selection, .blocks([firstID]))
    }

    func testShiftLeftFromWholeBlockSelectionSelectsLastCharacterOfPreviousBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One"),
            BlockInputBlock(id: secondID, text: "Two")
        ])
        mounted.view.applySelection(.blocks([secondID]), notify: false)
        mounted.window.makeFirstResponder(mounted.view)

        XCTAssertTrue(mounted.view.performKeyEquivalent(with: try shiftLeftEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [secondID],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 2, length: 1))
        )))
    }

    func testShiftRightFromTextSelectionAtBlockEndSelectsFirstCharacterOfNextBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One"),
            BlockInputBlock(id: secondID, text: "Two")
        ])
        let firstItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(firstItem.testingTextView)
        mounted.view.applySelection(.text(BlockInputTextRange(
            blockID: firstID,
            range: NSRange(location: 0, length: 3)
        )), notify: false)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 0, length: 3))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftRightEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [firstID],
            trailingTextRange: BlockInputTextRange(blockID: secondID, range: NSRange(location: 0, length: 1))
        )))
    }

    func testShiftLeftFromTextSelectionAtBlockStartSelectsLastCharacterOfPreviousBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "One"),
            BlockInputBlock(id: secondID, text: "Two")
        ])
        let secondItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let textView = try XCTUnwrap(secondItem.testingTextView)
        mounted.view.applySelection(.text(BlockInputTextRange(
            blockID: secondID,
            range: NSRange(location: 0, length: 3)
        )), notify: false)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 0, length: 3))

        XCTAssertTrue(textView.performKeyEquivalent(with: try shiftLeftEvent()))

        XCTAssertEqual(mounted.view.selection, .mixed(BlockInputMixedSelection(
            blockIDs: [secondID],
            leadingTextRange: BlockInputTextRange(blockID: firstID, range: NSRange(location: 2, length: 1))
        )))
    }

    private func viewX(forUTF16Offset offset: Int, item: BlockInputBlockItem) throws -> CGFloat {
        let textView = try XCTUnwrap(item.testingTextView)
        let textContainerX = try XCTUnwrap(item.textContainerX(forUTF16Offset: offset))
        let textContainerOrigin = textView.textContainerOrigin
        return textView.convert(
            NSPoint(x: textContainerOrigin.x + textContainerX, y: textContainerOrigin.y),
            to: item.view
        ).x
    }
}
