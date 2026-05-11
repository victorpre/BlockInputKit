import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTextCommandTypingShortcutTests: XCTestCase {
    func testTypingShortcutFormatsBlockThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "- [ ] Todo"
        textView.setSelectedRange(NSRange(location: 10, length: 0))

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .checklistItem(isChecked: false))
        XCTAssertEqual(view.document.blocks[0].text, "Todo")
        XCTAssertEqual(textView.string, "Todo")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))
    }

    func testTypingShortcutClampsVisibleSelectionAfterRemovingOnlyMarkerText() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "- [ ] "
        textView.setSelectedRange(NSRange(location: 6, length: 0))

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .checklistItem(isChecked: false))
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testTypingShortcutFormatsExactChecklistMarkerThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "- [ ]"
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .checklistItem(isChecked: false))
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testTypingShortcutFormatsExactCheckedChecklistMarkerThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "- [x]"
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .checklistItem(isChecked: true))
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testDeleteAtFrontUnwrapsFormattedBlockThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "quote")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "Quoted")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, ">Quoted")
        XCTAssertEqual(textView.string, ">Quoted")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 1)))
    }

    func testSpaceAfterRevealedQuoteMarkerReformatsQuoteBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "quote")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "Quoted")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        textView.string = "> Quoted"
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .quote)
        XCTAssertEqual(view.document.blocks[0].text, "Quoted")
        XCTAssertEqual(textView.string, "Quoted")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testSpaceAfterRevealedBulletMarkerReformatsListBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "bullet")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "Bullet")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        textView.string = "- Bullet"
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .bulletedListItem)
        XCTAssertEqual(view.document.blocks[0].text, "Bullet")
        XCTAssertEqual(textView.string, "Bullet")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testSpaceAfterRevealedChecklistMarkerReformatsChecklistBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "check")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "Todo")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        textView.string = "- [ ] Todo"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .checklistItem(isChecked: false))
        XCTAssertEqual(view.document.blocks[0].text, "Todo")
        XCTAssertEqual(textView.string, "Todo")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testSpaceAfterRevealedNumberedMarkerReformatsNumberedListBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "number")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .numberedListItem(start: 3), text: "Number")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        textView.string = "3. Number"
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .numberedListItem(start: 3))
        XCTAssertEqual(view.document.blocks[0].text, "Number")
        XCTAssertEqual(textView.string, "Number")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testSpaceAfterRevealedHorizontalRuleMarkerReformatsRuleBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "rule")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .horizontalRule)
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, "---")
        XCTAssertEqual(textView.string, "---")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 3)))

        textView.string = "--- "
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .horizontalRule)
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    func testHorizontalRuleIgnoresProgrammaticTextChangesThroughDelegatePath() throws {
        let blockID = BlockInputBlockID(rawValue: "rule")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .horizontalRule)
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "Hidden"
        textView.setSelectedRange(NSRange(location: 6, length: 0))

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .horizontalRule)
        XCTAssertEqual(view.document.blocks[0].text, "")
        XCTAssertEqual(textView.string, "")
        XCTAssertFalse(textView.isEditable)
    }

    func testDeleteAtFrontOfHeadingRevealsHashesForReformatting() throws {
        let blockID = BlockInputBlockID(rawValue: "heading")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .heading(level: 3), text: "Heading")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.doCommand(by: #selector(NSResponder.deleteForward(_:)))

        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, "###Heading")
        XCTAssertEqual(textView.string, "###Heading")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 3)))
    }

    func testSpaceAfterRevealedHeadingMarkerReformatsHeadingBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "heading")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .heading(level: 3), text: "Heading")
        ])))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.doCommand(by: #selector(NSResponder.deleteForward(_:)))

        textView.string = "### Heading"
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(view.document.blocks[0].kind, .heading(level: 3))
        XCTAssertEqual(view.document.blocks[0].text, "Heading")
        XCTAssertEqual(textView.string, "Heading")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }
}
