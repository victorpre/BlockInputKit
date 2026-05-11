import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputDocumentStoreTests: XCTestCase {
    func testMemoryDocumentStoreExposesBlocksAndIndexes() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ]))

        XCTAssertEqual(store.blockCount, 2)
        XCTAssertEqual(store.block(at: 1)?.id, secondID)
        XCTAssertEqual(store.block(withID: firstID)?.text, "First")
        XCTAssertEqual(store.index(of: secondID), 1)
        XCTAssertNil(store.block(at: 2))
    }

    func testMemoryDocumentStoreReplacesDocument() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let replacementID = BlockInputBlockID(rawValue: "replacement")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ]))

        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: replacementID, text: "Replacement")
        ]))

        XCTAssertEqual(store.document.blocks.map(\.id), [replacementID])
    }

    @MainActor
    func testViewPublishesStructuralChangesBackToConfiguredStore() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.focus(blockID: firstID)

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.count, 2)
        XCTAssertEqual(store.document.blocks[0].id, firstID)
    }

    @MainActor
    func testViewPublishesTextChangesBackToConfiguredStoreAndUndoController() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "First")
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

        textView.string = "Edited"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(store.document.blocks[0].text, "Edited")
        var document = store.document
        let undo = undoController.undoTextEdit(in: &document, blockID: blockID)
        XCTAssertEqual(document.blocks[0].text, "First")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)))
    }
}
