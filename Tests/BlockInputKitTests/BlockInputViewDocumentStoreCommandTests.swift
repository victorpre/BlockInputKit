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

        let didDelete = item.requestDeleteEmptyBlock()

        XCTAssertTrue(didDelete)
        XCTAssertEqual(store.document.blocks.map(\.id), [secondID])
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 0)))
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

        let didMove = item.requestMoveToNextBlock()

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

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.map(\.id).first, replacementID)
        XCTAssertEqual(store.document.blocks.count, 2)
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

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.map(\.id).first, replacementID)
        XCTAssertEqual(store.document.blocks.count, 2)
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

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertEqual(store.document.blocks.map(\.id).prefix(2), [firstID, secondID])
        XCTAssertEqual(store.document.blocks.count, 3)
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: store.document.blocks[2].id, utf16Offset: 0)))
    }
}
