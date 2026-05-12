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
        XCTAssertEqual(store.index(of: replacementID), 0)
        XCTAssertNil(store.index(of: firstID))
        XCTAssertEqual(store.block(withID: replacementID)?.text, "Replacement")
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
        XCTAssertEqual(store.index(of: thirdID), 0)
        XCTAssertEqual(store.index(of: firstID), 1)
        XCTAssertNil(store.index(of: secondID))
        XCTAssertEqual(store.block(withID: thirdID)?.text, "Third")
    }

    func testMemoryDocumentStoreUpdatesIndexesAfterMiddleInsertion() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let insertedID = BlockInputBlockID(rawValue: "inserted")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ]))

        store.insertBlocks([BlockInputBlock(id: insertedID, text: "Inserted")], at: 1)

        XCTAssertEqual(store.document.blocks.map(\.id), [firstID, insertedID, secondID, thirdID])
        XCTAssertEqual(store.index(of: firstID), 0)
        XCTAssertEqual(store.index(of: insertedID), 1)
        XCTAssertEqual(store.index(of: secondID), 2)
        XCTAssertEqual(store.index(of: thirdID), 3)
        XCTAssertEqual(store.block(withID: secondID)?.text, "Second")
    }

    func testMemoryDocumentStoreUpdatesIndexesAfterMiddleDeletion() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ]))

        store.deleteBlocks(withIDs: [secondID])

        XCTAssertEqual(store.document.blocks.map(\.id), [firstID, thirdID])
        XCTAssertEqual(store.index(of: firstID), 0)
        XCTAssertEqual(store.index(of: thirdID), 1)
        XCTAssertNil(store.index(of: secondID))
        XCTAssertEqual(store.block(withID: thirdID)?.text, "Third")
    }

    func testMemoryDocumentStoreUpdatesIndexesAfterMoves() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let fourthID = BlockInputBlockID(rawValue: "fourth")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third"),
            BlockInputBlock(id: fourthID, text: "Fourth")
        ]))

        store.moveBlock(withID: secondID, to: 3)

        XCTAssertEqual(store.document.blocks.map(\.id), [firstID, thirdID, fourthID, secondID])
        XCTAssertEqual(store.index(of: firstID), 0)
        XCTAssertEqual(store.index(of: thirdID), 1)
        XCTAssertEqual(store.index(of: fourthID), 2)
        XCTAssertEqual(store.index(of: secondID), 3)

        store.moveBlock(withID: fourthID, to: 0)

        XCTAssertEqual(store.document.blocks.map(\.id), [fourthID, firstID, thirdID, secondID])
        XCTAssertEqual(store.index(of: fourthID), 0)
        XCTAssertEqual(store.index(of: firstID), 1)
        XCTAssertEqual(store.index(of: thirdID), 2)
        XCTAssertEqual(store.index(of: secondID), 3)
    }

    func testMemoryDocumentStorePreservesFirstIndexWhenIDsAreDuplicated() {
        let sharedID = BlockInputBlockID(rawValue: "shared")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: sharedID, text: "First"),
            BlockInputBlock(id: sharedID, text: "Second")
        ]))

        XCTAssertEqual(store.index(of: sharedID), 0)
        XCTAssertEqual(store.block(withID: sharedID)?.text, "First")
    }

    func testMemoryDocumentStorePreservesFirstIndexWhenInsertedIDsAreDuplicated() {
        let sharedID = BlockInputBlockID(rawValue: "shared")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: "first", text: "First")
        ]))

        store.insertBlocks([
            BlockInputBlock(id: sharedID, text: "Inserted first"),
            BlockInputBlock(id: sharedID, text: "Inserted second")
        ], at: 1)

        XCTAssertEqual(store.index(of: sharedID), 1)
        XCTAssertEqual(store.block(withID: sharedID)?.text, "Inserted first")
    }

    func testMemoryDocumentStorePreservesFirstIndexWhenMovingDuplicateIDs() {
        let sharedID = BlockInputBlockID(rawValue: "shared")
        let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: sharedID, text: "First"),
            BlockInputBlock(id: "middle", text: "Middle"),
            BlockInputBlock(id: sharedID, text: "Second")
        ]))

        store.moveBlock(withID: sharedID, to: 2)

        XCTAssertEqual(store.document.blocks.map(\.text), ["Middle", "Second", "First"])
        XCTAssertEqual(store.index(of: sharedID), 1)
        XCTAssertEqual(store.block(withID: sharedID)?.text, "Second")
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
