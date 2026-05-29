import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTextCommandTests: XCTestCase {
    func testDeleteCommandRemovesEmptyBlockThroughDelegatePath() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[1],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        XCTAssertEqual(view.document.blocks.map(\.id), [firstID])
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)))
    }

    func testSelectAllCommandEscalatesThroughDelegatePath() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)

        textView.doCommand(by: #selector(NSResponder.selectAll(_:)))
        textView.doCommand(by: #selector(NSResponder.selectAll(_:)))

        XCTAssertEqual(view.selection, .blocks([firstID, secondID]))
    }

    func testMoveUpCommandFocusesPreviousBlockAtBoundary() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[1],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveUp(_:)))

        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)))
    }

    func testMoveDownCommandFocusesNextBlockAtBoundary() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 0)))
    }

    func testMoveUpFromSingleLineMiddlePreservesHorizontalCursorPosition() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: secondID, text: "abcdefghij")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveUp(_:)))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)))
    }

    func testMoveDownFromSingleLineMiddlePreservesHorizontalCursorPosition() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: secondID, text: "abcdefghij")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 6, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 6)))
    }

    func testMoveDownClampsHorizontalCursorToShorterNextBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: secondID, text: "abc")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 8, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 3)))
    }

    func testMoveDownToMultilineTargetClampsToVisibleLineEnd() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: secondID, text: "abc\ndef")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 9, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 3)))
    }

    func testMoveUpToMultilineTargetClampsToVisibleLineEnd() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abc\ndef"),
            BlockInputBlock(id: secondID, text: "abcdefghij")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 9, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveUp(_:)))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 7)))
    }

    func testMoveDownFromInternalLineStaysInCurrentBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abc\ndef"),
            BlockInputBlock(id: secondID, text: "Next")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        if case let .cursor(cursor) = mounted.view.selection {
            XCTAssertEqual(cursor.blockID, firstID)
        } else {
            XCTFail("Expected cursor selection in the current block.")
        }
    }

    func testRepeatedMoveDownPreservesOriginalHorizontalCursorAfterShortBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: secondID, text: "abc"),
            BlockInputBlock(id: thirdID, text: "abcdefghij")
        ])
        let firstItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let firstTextView = try XCTUnwrap(firstItem.testingTextView)
        firstTextView.setSelectedRange(NSRange(location: 8, length: 0))
        firstTextView.doCommand(by: #selector(NSResponder.moveDown(_:)))
        let secondItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let secondTextView = try XCTUnwrap(secondItem.testingTextView)

        secondTextView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: thirdID, utf16Offset: 8)))
    }

    func testRepeatedMoveDownPreservesHorizontalCursorAcrossHorizontalRule() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let ruleID = BlockInputBlockID(rawValue: "rule")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: ruleID, kind: .horizontalRule),
            BlockInputBlock(id: thirdID, text: "abcdefghij")
        ])
        let firstItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let firstTextView = try XCTUnwrap(firstItem.testingTextView)
        firstTextView.setSelectedRange(NSRange(location: 7, length: 0))

        firstTextView.doCommand(by: #selector(NSResponder.moveDown(_:)))

        XCTAssertEqual(mounted.view.selection, .blocks([ruleID]))
        XCTAssertTrue(mounted.window.firstResponder === mounted.view)

        mounted.view.keyDown(with: try keyDownEvent(keyCode: 125, characters: "\u{F701}"))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: thirdID, utf16Offset: 7)))
    }

    func testRepeatedMoveUpPreservesHorizontalCursorAcrossHorizontalRule() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let ruleID = BlockInputBlockID(rawValue: "rule")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "abcdefghij"),
            BlockInputBlock(id: ruleID, kind: .horizontalRule),
            BlockInputBlock(id: thirdID, text: "abcdefghij")
        ])
        let thirdItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 2))
        let thirdTextView = try XCTUnwrap(thirdItem.testingTextView)
        thirdTextView.setSelectedRange(NSRange(location: 6, length: 0))

        thirdTextView.doCommand(by: #selector(NSResponder.moveUp(_:)))

        XCTAssertEqual(mounted.view.selection, .blocks([ruleID]))
        XCTAssertTrue(mounted.window.firstResponder === mounted.view)

        mounted.view.keyDown(with: try keyDownEvent(keyCode: 126, characters: "\u{F700}"))

        XCTAssertEqual(mounted.view.selection, .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 6)))
    }

    func testMoveUpAtStartOfInternalLineStaysInCurrentBlock() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "Previous"),
            BlockInputBlock(id: secondID, text: "abc\ndef")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveUp(_:)))

        if case let .cursor(cursor) = mounted.view.selection {
            XCTAssertEqual(cursor.blockID, secondID)
        } else {
            XCTFail("Expected cursor selection in the current block.")
        }
    }

}
