import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTextCommandTests: XCTestCase {
    func testReturnCommandInsertsBlockThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        XCTAssertEqual(view.document.blocks.count, 2)
        XCTAssertEqual(view.document.blocks[0].id, blockID)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: view.document.blocks[1].id, utf16Offset: 0)))
    }

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

    func testTabCommandsIndentAndOutdentThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 1)

        textView.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
    }
}
