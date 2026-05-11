import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputViewDocumentStoreCommandTests: XCTestCase {
    @MainActor
    func testDeleteEmptyBlockRefreshesFromStoreBeforeCheckingBlock() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "Old"),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[0],
            allowsReordering: true,
            delegate: view
        )
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: ""),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        store.resetCounts()

        let didDelete = item.requestDeleteEmptyBlock()

        XCTAssertTrue(didDelete)
        XCTAssertEqual(store.document.blocks.map(\.id), [secondID])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.deletedBlockIDs, [[blockID]])
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 0)))
    }

    @MainActor
    func testDeleteOnlyEmptyBlockPublishesBlockReplacementToStore() {
        let blockID = BlockInputBlockID(rawValue: "only")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, kind: .quote, text: "")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        store.resetCounts()

        _ = view.deleteCurrentEmptyBlockForBackspaceOrDelete()

        XCTAssertEqual(store.document.blocks.map(\.id), [blockID])
        XCTAssertEqual(store.document.blocks.map(\.kind), [.paragraph])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, [blockID])
        XCTAssertTrue(store.deletedBlockIDs.isEmpty)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)))
    }

    @MainActor
    func testArrowMovementRefreshesFromStoreBeforeResolvingAdjacentBlocks() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "Old first"),
            BlockInputBlock(id: secondID, text: "Old second")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        let item = BlockInputBlockItem.configuredForTesting(
            block: view.document.blocks[1],
            allowsReordering: true,
            delegate: view
        )
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ]))

        let didMove = item.requestMoveVertically(.downward)

        XCTAssertTrue(didMove)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: thirdID, utf16Offset: 0)))
    }

    @MainActor
    func testReturnRefreshesFromStoreBeforeResolvingActiveBlock() {
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

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.map(\.id).first, replacementID)
        XCTAssertEqual(store.document.blocks.count, 2)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.insertedBlockBatches.count, 1)
    }

    @MainActor
    func testReturnFallsBackToFirstStoreBlockWhenSelectionWasRemoved() {
        let staleID = BlockInputBlockID(rawValue: "stale")
        let replacementID = BlockInputBlockID(rawValue: "replacement")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: staleID, text: "Old")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.applySelection(.cursor(BlockInputCursor(blockID: staleID, utf16Offset: 0)), notify: false)
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: replacementID, text: "Replacement")
        ]))
        store.resetCounts()

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.map(\.id).first, replacementID)
        XCTAssertEqual(store.document.blocks.count, 2)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.insertedBlockBatches.count, 1)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: store.document.blocks[1].id, utf16Offset: 0)))
    }

    @MainActor
    func testReturnUsesFirstStillValidBlockFromPartiallyStaleBlockSelection() {
        let staleID = BlockInputBlockID(rawValue: "stale")
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: staleID, text: "Old"),
            BlockInputBlock(id: firstID, text: "First")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        view.applySelection(.blocks([staleID, secondID]), notify: false)
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        store.resetCounts()

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.map(\.id).prefix(2), [firstID, secondID])
        XCTAssertEqual(store.document.blocks.count, 3)
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.insertedBlockBatches.count, 1)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: store.document.blocks[2].id, utf16Offset: 0)))
    }
}
