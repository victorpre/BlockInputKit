import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class LargeLeadingReturnPerformanceTests: XCTestCase {
    func testStoreBackedReturnAtFrontOfLargeNumberedListRenumbersFollowingBlocksWithoutSnapshot() throws {
        let targetIndex = largeDocumentCacheMutationLimit + 2
        let count = largeDocumentCacheMutationLimit + 5
        let blockID = BlockInputBlockID(rawValue: "number-\(targetIndex)")
        let nextID = BlockInputBlockID(rawValue: "number-\(targetIndex + 1)")
        let secondNextID = BlockInputBlockID(rawValue: "number-\(targetIndex + 2)")
        let store = DocumentReadCountingStore(document: largeNumberedListDocument(count: count))
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        view.configure(BlockInputConfiguration(
            documentStore: store,
            undoController: BlockInputUndoController()
        ))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        store.resetCounts()

        _ = view.insertBlockBelowCurrentBlock()

        let insertedBlock = try XCTUnwrap(store.insertedBlockBatches.first?.blocks.first)
        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [blockID, nextID, secondNextID])
        XCTAssertEqual(store.insertedBlockBatches.first?.index, targetIndex + 1)
        XCTAssertEqual(store.block(at: targetIndex)?.kind, .numberedListItem(start: targetIndex + 1))
        XCTAssertEqual(store.block(at: targetIndex + 1)?.kind, .numberedListItem(start: targetIndex + 2))
        XCTAssertEqual(store.block(at: targetIndex + 2)?.kind, .numberedListItem(start: targetIndex + 3))
        XCTAssertEqual(store.block(at: targetIndex + 3)?.kind, .numberedListItem(start: targetIndex + 4))

        store.resetCounts()
        _ = view.undoStructuralEdit()

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [blockID, nextID, secondNextID])
        XCTAssertEqual(store.deletedBlockIDs, [[insertedBlock.id]])
        XCTAssertEqual(store.block(at: targetIndex)?.kind, .numberedListItem(start: targetIndex + 1))
        XCTAssertEqual(store.block(at: targetIndex + 1)?.kind, .numberedListItem(start: targetIndex + 2))
        XCTAssertEqual(store.block(at: targetIndex + 2)?.kind, .numberedListItem(start: targetIndex + 3))

        store.resetCounts()
        _ = view.redoStructuralEdit()

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [blockID, nextID, secondNextID])
        XCTAssertEqual(store.insertedBlockBatches.first?.index, targetIndex + 1)
        XCTAssertEqual(store.block(at: targetIndex + 1)?.id, insertedBlock.id)
        XCTAssertEqual(store.block(at: targetIndex + 3)?.kind, .numberedListItem(start: targetIndex + 4))
    }

    func testStoreBackedReturnAtFrontOfNestedNumberedListUsesParentSeedWithoutSnapshot() throws {
        let parentIndex = largeDocumentCacheMutationLimit + 1
        let targetIndex = parentIndex + 3
        let targetID = BlockInputBlockID(rawValue: "number-\(targetIndex)")
        let nextID = BlockInputBlockID(rawValue: "number-\(targetIndex + 1)")
        let store = DocumentReadCountingStore(document: largeNestedNumberedListDocument(parentIndex: parentIndex))
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        view.configure(BlockInputConfiguration(documentStore: store))
        view.applySelection(.cursor(BlockInputCursor(blockID: targetID, utf16Offset: 0)), notify: false)
        store.resetCounts()

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replacedBlockIDs, [targetID, nextID])
        XCTAssertEqual(store.block(at: targetIndex)?.kind, .numberedListItem(start: 2))
        XCTAssertEqual(store.block(at: targetIndex + 1)?.kind, .numberedListItem(start: 3))
        XCTAssertEqual(store.block(at: targetIndex + 2)?.kind, .numberedListItem(start: 4))
    }

    private func largeNumberedListDocument(count: Int) -> BlockInputDocument {
        BlockInputDocument(blocks: (0..<count).map { index in
            BlockInputBlock(
                id: BlockInputBlockID(rawValue: "number-\(index)"),
                kind: .numberedListItem(start: index + 1),
                text: "Number \(index)"
            )
        })
    }

    private func largeNestedNumberedListDocument(parentIndex: Int) -> BlockInputDocument {
        let count = parentIndex + 6
        return BlockInputDocument(blocks: (0..<count).map { index in
            let id = BlockInputBlockID(rawValue: "number-\(index)")
            switch index {
            case parentIndex:
                return BlockInputBlock(id: id, kind: .numberedListItem(start: 1), text: "Parent")
            case parentIndex + 1:
                return BlockInputBlock(id: id, kind: .numberedListItem(start: 1), text: "First child", indentationLevel: 1)
            case parentIndex + 2:
                return BlockInputBlock(id: id, kind: .numberedListItem(start: 1), text: "Grandchild", indentationLevel: 2)
            case parentIndex + 3:
                return BlockInputBlock(id: id, kind: .numberedListItem(start: 2), text: "Second child", indentationLevel: 1)
            case parentIndex + 4:
                return BlockInputBlock(id: id, kind: .numberedListItem(start: 3), text: "Third child", indentationLevel: 1)
            default:
                return BlockInputBlock(id: id, text: "Block \(index)")
            }
        })
    }
}
