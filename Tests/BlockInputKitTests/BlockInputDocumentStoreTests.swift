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
}
