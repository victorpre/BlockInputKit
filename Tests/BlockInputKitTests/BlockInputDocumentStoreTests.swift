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

    func testMemoryDocumentStoreAppliesGranularMutations() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ]))

        store.replaceBlock(BlockInputBlock(id: firstID, text: "Updated"))
        store.insertBlocks([BlockInputBlock(id: thirdID, text: "Third")], at: 2)
        store.moveBlock(withID: thirdID, to: 0)
        store.deleteBlocks(withIDs: [secondID])

        XCTAssertEqual(store.document.blocks.map(\.id), [thirdID, firstID])
        XCTAssertEqual(store.document.blocks.map(\.text), ["Third", "Updated"])
    }

    func testDefaultGranularMutationsFallBackToDocumentReplacement() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let fallbackStore = FallbackDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ]))

        fallbackStore.replaceBlock(BlockInputBlock(id: firstID, text: "Updated"))
        fallbackStore.insertBlocks([BlockInputBlock(id: secondID, text: "Second")], at: 1)
        fallbackStore.insertBlocks([BlockInputBlock(id: thirdID, text: "Third")], at: 2)
        fallbackStore.moveBlock(withID: thirdID, to: 0)
        fallbackStore.deleteBlocks(withIDs: [secondID])

        XCTAssertEqual(fallbackStore.document.blocks.map(\.id), [thirdID, firstID])
        XCTAssertEqual(fallbackStore.document.blocks.map(\.text), ["Third", "Updated"])
        XCTAssertEqual(fallbackStore.replaceDocumentCount, 5)
    }

    func testDefaultGranularNoOpsDoNotReplaceDocument() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let fallbackStore = FallbackDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ]))

        fallbackStore.replaceBlock(BlockInputBlock(id: "missing", text: "Missing"))
        fallbackStore.replaceBlock(BlockInputBlock(id: firstID, text: "First"))
        fallbackStore.insertBlocks([], at: 0)
        fallbackStore.deleteBlocks(withIDs: ["missing"])
        fallbackStore.moveBlock(withID: "missing", to: 0)

        XCTAssertEqual(fallbackStore.document.blocks.map(\.id), [firstID])
        XCTAssertEqual(fallbackStore.replaceDocumentCount, 0)
    }
}

private final class FallbackDocumentStore: BlockInputDocumentStore {
    private(set) var document: BlockInputDocument
    private(set) var replaceDocumentCount = 0

    init(document: BlockInputDocument) {
        self.document = document
    }

    func replaceDocument(_ document: BlockInputDocument) {
        replaceDocumentCount += 1
        self.document = document
    }
}
