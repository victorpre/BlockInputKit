import AppKit
import XCTest
@testable import BlockInputKit

final class BlockInputViewDocumentStoreMutationTests: XCTestCase {
    @MainActor
    func testViewRefreshesFromStoreBeforeTextChanges() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Old")
        ]))
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: undoController
        ))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "New")
        ]))

        textView.string = "Edited"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(store.document.blocks[0].text, "Edited")
        var document = store.document
        _ = undoController.undoTextEdit(in: &document, blockID: blockID)
        XCTAssertEqual(document.blocks[0].text, "New")
    }

    @MainActor
    func testTextUndoRefreshesFromStoreBeforeMutating() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Original")
        ]))
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: undoController
        ))
        undoController.registerTextEdit(
            blockID: blockID,
            beforeText: "Original",
            afterText: "Edited",
            selectionBefore: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 8)),
            selectionAfter: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6))
        )
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Edited")
        ]))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)), notify: false)
        store.resetCounts()

        _ = view.undoTextEditInActiveBlock()

        XCTAssertEqual(store.document.blocks.map(\.text), ["Original"])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testTextRedoRefreshesFromStoreBeforeMutating() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Original")
        ]))
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: undoController
        ))
        undoController.registerTextEdit(
            blockID: blockID,
            beforeText: "Original",
            afterText: "Edited",
            selectionBefore: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 8)),
            selectionAfter: .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6))
        )
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Edited"),
            BlockInputBlock(id: secondID, text: "Host block")
        ]))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)), notify: false)
        _ = view.undoTextEditInActiveBlock()
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Original"),
            BlockInputBlock(id: secondID, text: "Host updated")
        ]))
        store.resetCounts()

        _ = view.redoTextEditInActiveBlock()

        XCTAssertEqual(store.document.blocks.map(\.text), ["Edited", "Host updated"])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testIndentPublishesBlockReplacementToStore() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .bulletedListItem, text: "First")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )

        item.requestIndent()

        XCTAssertEqual(store.document.blocks[0].indentationLevel, 1)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testChecklistTogglePublishesBlockReplacementToStore() {
        let blockID = BlockInputBlockID(rawValue: "check")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "Done")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.focus(blockID: blockID, utf16Offset: 0)
        store.resetCounts()

        let selection = view.toggleChecklistItem()

        XCTAssertEqual(store.document.blocks[0].kind, .checklistItem(isChecked: true))
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 4)))
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testChecklistItemButtonTogglesBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "check")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "Done")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )

        item.requestToggleChecklist()

        XCTAssertEqual(store.document.blocks[0].kind, .checklistItem(isChecked: true))
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testTypingShortcutPublishesBlockReplacementToStore() throws {
        let blockID = BlockInputBlockID(rawValue: "heading")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "## Heading"
        textView.setSelectedRange(NSRange(location: 10, length: 0))
        store.resetCounts()

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(store.document.blocks[0].kind, .heading(level: 2))
        XCTAssertEqual(store.document.blocks[0].text, "Heading")
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testHorizontalRuleTypingShortcutPublishesDocumentReplacementToStore() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: ""),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.string = "---"
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        store.resetCounts()

        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(store.document.blocks.count, 3)
        XCTAssertEqual(store.document.blocks[0].id, firstID)
        XCTAssertEqual(store.document.blocks[2].id, secondID)
        XCTAssertEqual(store.document.blocks[0].kind, .horizontalRule)
        XCTAssertEqual(store.document.blocks[1].kind, .paragraph)
        XCTAssertEqual(store.replaceDocumentCount, 1)
        XCTAssertEqual(store.replaceBlockIDs, [])
        XCTAssertEqual(store.insertedBlockBatches.count, 0)
    }

    @MainActor
    func testSelectedHorizontalRuleDeletePublishesDocumentReplacementToStore() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let ruleID = BlockInputBlockID(rawValue: "rule")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: ruleID, kind: .horizontalRule),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.applySelection(.blocks([ruleID]), notify: false)
        store.resetCounts()

        _ = view.deleteSelectedHorizontalRuleForBackspaceOrDelete()

        XCTAssertEqual(store.document.blocks.map(\.id), [firstID, secondID])
        XCTAssertEqual(store.replaceDocumentCount, 1)
        XCTAssertEqual(store.replaceBlockIDs, [])
        XCTAssertEqual(store.deletedBlockIDs, [])
    }

    @MainActor
    func testUnwrapBlockPublishesBlockReplacementToStore() throws {
        let blockID = BlockInputBlockID(rawValue: "quote")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "Quoted")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        store.resetCounts()

        textView.doCommand(by: #selector(NSResponder.deleteBackward(_:)))

        XCTAssertEqual(store.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(store.document.blocks[0].text, ">Quoted")
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
    }

    @MainActor
    func testStructuralUndoRefreshesFromStoreBeforeMutating() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let insertedID = BlockInputBlockID(rawValue: "inserted")
        let beforeDocument = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ])
        let afterDocument = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: insertedID, text: "")
        ])
        let store = CountingDocumentStore(document: beforeDocument)
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: undoController
        ))
        undoController.registerStructuralEdit(
            actionName: "Insert Block",
            beforeDocument: beforeDocument,
            afterDocument: afterDocument,
            selectionBefore: .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)),
            selectionAfter: .cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0))
        )
        store.replaceDocument(afterDocument)
        view.applySelection(.cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0)), notify: false)

        _ = view.undoStructuralEdit()

        XCTAssertEqual(store.document.blocks.map(\.id), [firstID])
    }

    @MainActor
    func testStructuralRedoPublishesResultBackToStore() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let insertedID = BlockInputBlockID(rawValue: "inserted")
        let beforeDocument = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ])
        let afterDocument = BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: insertedID, text: "")
        ])
        let store = CountingDocumentStore(document: beforeDocument)
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: undoController
        ))
        undoController.registerStructuralEdit(
            actionName: "Insert Block",
            beforeDocument: beforeDocument,
            afterDocument: afterDocument,
            selectionBefore: .cursor(BlockInputCursor(blockID: firstID, utf16Offset: 5)),
            selectionAfter: .cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0))
        )
        store.replaceDocument(afterDocument)
        view.applySelection(.cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0)), notify: false)
        _ = view.undoStructuralEdit()

        _ = view.redoStructuralEdit()

        XCTAssertEqual(store.document.blocks.map(\.id), [firstID, insertedID])
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0)))
    }
}
