import AppKit
import XCTest
@testable import BlockInputKit

final class BlockInputViewDocumentStoreTests: XCTestCase {
    @MainActor
    func testCollectionDataSourceReadsThroughConfiguredStore() {
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(text: "First"),
            BlockInputBlock(text: "Second")
        ]))
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        view.configure(BlockInputConfiguration(documentStore: store))
        store.resetCounts()

        let itemCount = view.collectionView(view.collectionView, numberOfItemsInSection: 0)
        _ = view.collectionView(
            view.collectionView,
            layout: view.collectionView.collectionViewLayout ?? NSCollectionViewFlowLayout(),
            sizeForItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(itemCount, 2)
        XCTAssertEqual(store.blockCountReadCount, 1)
        XCTAssertEqual(store.blockAtReadIndexes, [0])
    }

    @MainActor
    func testPasteboardWriterReadsThroughConfiguredStore() throws {
        let staleID = BlockInputBlockID(rawValue: "stale")
        let replacementID = BlockInputBlockID(rawValue: "replacement")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: staleID, text: "Old")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: replacementID, text: "Replacement")
        ]))
        store.resetCounts()

        let writer = try XCTUnwrap(view.collectionView(
            view.collectionView,
            pasteboardWriterForItemAt: IndexPath(item: 0, section: 0)
        ) as? NSPasteboardItem)

        XCTAssertEqual(writer.string(forType: .blockInputBlockID), replacementID.rawValue)
        XCTAssertEqual(store.blockAtReadIndexes, [0])
    }

    @MainActor
    func testViewPublishesStructuralChangesBackToConfiguredStore() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.focus(blockID: firstID)
        store.resetCounts()

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.count, 2)
        XCTAssertEqual(store.document.blocks[0].id, firstID)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.insertedBlockBatches.count, 1)
        XCTAssertEqual(store.insertedBlockBatches.first?.index, 1)
    }

    @MainActor
    func testViewPublishesTextChangesBackToConfiguredStoreAndUndoController() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
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
        store.resetCounts()

        textView.string = "Edited"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        item.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(store.document.blocks[0].text, "Edited")
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
        var document = store.document
        let undo = undoController.undoTextEdit(in: &document, blockID: blockID)
        XCTAssertEqual(document.blocks[0].text, "First")
        XCTAssertEqual(undo?.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)))
    }
}
