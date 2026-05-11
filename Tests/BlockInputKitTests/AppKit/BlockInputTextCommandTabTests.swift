import AppKit
import XCTest
@testable import BlockInputKit

final class BlockInputTextCommandTabTests: XCTestCase {
    @MainActor
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
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 1)

        textView.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
    }

    @MainActor
    func testTabCommandsDoNotMutatePlainBlocks() throws {
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
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))
        textView.doCommand(by: #selector(NSResponder.insertBacktab(_:)))

        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
        XCTAssertEqual(view.document.blocks[0].text, "First")
        XCTAssertEqual(textView.string, "First")
    }

    @MainActor
    func testTabCommandsIndentAndOutdentCurrentLineInMultilineListBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "One\nTwo\nThree")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))

        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
        XCTAssertEqual(view.document.blocks[0].lineIndentationLevels, [0, 1, 0])
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))

        textView.doCommand(by: #selector(NSResponder.insertBacktab(_:)))

        XCTAssertEqual(view.document.blocks[0].lineIndentationLevels, [])
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))
    }

    @MainActor
    func testTabCommandsDoNotIndentWhenCaretIsNotAtLineStart() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "One\nTwo")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.doCommand(by: #selector(NSResponder.insertTab(_:)))
        textView.doCommand(by: #selector(NSResponder.insertBacktab(_:)))

        XCTAssertEqual(view.document.blocks[0].indentationLevel, 0)
        XCTAssertEqual(view.document.blocks[0].lineIndentationLevels, [])
        XCTAssertEqual(textView.string, "One\nTwo")
    }
}
