import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewReorderPerformanceTests: XCTestCase {
    func testStoreBackedNumberedReorderAvoidsSnapshotAndUsesGranularMarkerReplacements() {
        let sourceIndex = 50_000
        let sourceID = BlockInputBlockID(rawValue: "block-\(sourceIndex)")
        let shiftedID = BlockInputBlockID(rawValue: "block-\(sourceIndex + 1)")
        let store = DocumentReadCountingStore(document: numberedListDocument())
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        let layout = ReorderTrackingFlowLayout()
        view.collectionView.collectionViewLayout = layout
        view.configure(BlockInputConfiguration(documentStore: store))
        layout.reset()
        store.resetCounts()

        _ = view.moveBlock(blockID: sourceID, to: sourceIndex + 1)

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertFalse(layout.didInvalidateEverything)
        XCTAssertEqual(store.movedBlocks.map(\.id), [sourceID])
        XCTAssertEqual(store.movedBlocks.map(\.index), [sourceIndex + 1])
        XCTAssertEqual(store.replacedBlockIDs, [shiftedID, sourceID])
        XCTAssertEqual(store.block(withID: shiftedID)?.kind, .numberedListItem(start: sourceIndex + 1))
        XCTAssertEqual(store.block(withID: sourceID)?.kind, .numberedListItem(start: sourceIndex + 2))
    }

    func testStoreBackedNumberedReorderUndoRedoAvoidsSnapshot() {
        let sourceIndex = 50_000
        let sourceID = BlockInputBlockID(rawValue: "block-\(sourceIndex)")
        let shiftedID = BlockInputBlockID(rawValue: "block-\(sourceIndex + 1)")
        let store = DocumentReadCountingStore(document: numberedListDocument())
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: BlockInputUndoController()
        ))
        _ = view.moveBlock(blockID: sourceID, to: sourceIndex + 1)
        store.resetCounts()

        _ = view.undoStructuralEdit()

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.movedBlocks.map(\.id), [sourceID])
        XCTAssertEqual(store.movedBlocks.map(\.index), [sourceIndex])
        XCTAssertEqual(store.replacedBlockIDs, [shiftedID, sourceID])
        XCTAssertEqual(store.block(withID: sourceID)?.kind, .numberedListItem(start: sourceIndex + 1))
        XCTAssertEqual(store.block(withID: shiftedID)?.kind, .numberedListItem(start: sourceIndex + 2))

        store.resetCounts()
        _ = view.redoStructuralEdit()

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.movedBlocks.map(\.id), [sourceID])
        XCTAssertEqual(store.movedBlocks.map(\.index), [sourceIndex + 1])
        XCTAssertEqual(store.replacedBlockIDs, [shiftedID, sourceID])
        XCTAssertEqual(store.block(withID: shiftedID)?.kind, .numberedListItem(start: sourceIndex + 1))
        XCTAssertEqual(store.block(withID: sourceID)?.kind, .numberedListItem(start: sourceIndex + 2))
    }

    func testStoreBackedNumberedReorderWithDuplicateIDsInWindowDoesNotTrap() {
        let sourceIndex = 50_000
        let sourceID = BlockInputBlockID(rawValue: "block-\(sourceIndex)")
        var document = numberedListDocument()
        let duplicateID = BlockInputBlockID(rawValue: "duplicate")
        document.blocks[sourceIndex - 1].id = duplicateID
        document.blocks[sourceIndex + 1].id = duplicateID
        let store = DocumentReadCountingStore(document: document)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        view.configure(BlockInputConfiguration(documentStore: store))
        store.resetCounts()

        _ = view.moveBlock(blockID: sourceID, to: sourceIndex + 1)

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.movedBlocks.map(\.id), [sourceID])
        XCTAssertEqual(store.movedBlocks.map(\.index), [sourceIndex + 1])
    }

    func testStoreBackedLargeReorderReconfiguresVisibleRowsBetweenMovedEndpoints() throws {
        let visibleIndex = 6
        let sourceIndex = 2
        let targetIndex = 14
        let sourceID = BlockInputBlockID(rawValue: "block-\(sourceIndex)")
        let store = BlockInputMemoryDocumentStore(document: bulletedListDocument(count: 10_005))
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(documentStore: store))
        let visibleItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: visibleIndex))
        XCTAssertEqual(visibleItem.testingTextView?.string, "Block \(visibleIndex)")

        _ = mounted.view.moveBlock(blockID: sourceID, to: targetIndex)

        XCTAssertEqual(store.block(at: visibleIndex)?.id, BlockInputBlockID(rawValue: "block-\(visibleIndex + 1)"))
        XCTAssertEqual(visibleItem.testingTextView?.string, "Block \(visibleIndex + 1)")
    }

    private func numberedListDocument() -> BlockInputDocument {
        BlockInputDocument(blocks: (0..<100_000).map { index in
            BlockInputBlock(
                id: BlockInputBlockID(rawValue: "block-\(index)"),
                kind: .numberedListItem(start: index + 1),
                text: "Block \(index)"
            )
        })
    }

    private func bulletedListDocument(count: Int) -> BlockInputDocument {
        BlockInputDocument(blocks: (0..<count).map { index in
            BlockInputBlock(
                id: BlockInputBlockID(rawValue: "block-\(index)"),
                kind: .bulletedListItem,
                text: "Block \(index)"
            )
        })
    }
}

private final class ReorderTrackingFlowLayout: NSCollectionViewFlowLayout {
    private(set) var didInvalidateEverything = false

    func reset() {
        didInvalidateEverything = false
    }

    override func invalidateLayout() {
        didInvalidateEverything = true
        super.invalidateLayout()
    }
}
