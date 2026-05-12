import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewLargeDocumentSnapshotTests: XCTestCase {
    func testLargeDocumentChangeSnapshotIsDeferredToBackgroundStore() async {
        let targetIndex = 50_000
        let (blockID, document) = largeListDocument(targetIndex: targetIndex)
        let store = BackgroundSnapshotCountingStore(document: document)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        let snapshotPublished = expectation(description: "Deferred snapshot published")
        var publishedDocument: BlockInputDocument?
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onDocumentChange: { document in
                publishedDocument = document
                snapshotPublished.fulfill()
            },
            documentChangeSnapshotDelay: 0.01
        ))
        view.applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 9)), notify: false)
        store.resetCounts()

        _ = view.insertBlockBelowCurrentBlock()

        XCTAssertNil(publishedDocument)
        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.backgroundSnapshotCount, 0)

        await fulfillment(of: [snapshotPublished], timeout: 1)
        XCTAssertEqual(store.documentReadCount, 0)
        XCTAssertEqual(store.backgroundSnapshotCount, 1)
        XCTAssertEqual(publishedDocument?.blocks.count, 100_001)
    }

    func testLargeDocumentChangeSnapshotsAreCoalesced() async {
        let (_, document) = largeListDocument(targetIndex: 50_000)
        let store = BackgroundSnapshotCountingStore(document: document)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        let snapshotPublished = expectation(description: "Deferred snapshot published once")
        snapshotPublished.assertForOverFulfill = true
        var publishCount = 0
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onDocumentChange: { _ in
                publishCount += 1
                snapshotPublished.fulfill()
            },
            documentChangeSnapshotDelay: 0.01
        ))
        store.resetCounts()

        view.publishDocumentChange()
        view.publishDocumentChange()

        await fulfillment(of: [snapshotPublished], timeout: 1)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(publishCount, 1)
        XCTAssertEqual(store.backgroundSnapshotCount, 1)
    }

    func testReconfigureCancelsDeferredDocumentChangeSnapshot() async {
        let (_, document) = largeListDocument(targetIndex: 50_000)
        let store = BackgroundSnapshotCountingStore(document: document)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        var stalePublishCount = 0
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onDocumentChange: { _ in stalePublishCount += 1 },
            documentChangeSnapshotDelay: 0.05
        ))

        view.publishDocumentChange()
        XCTAssertNotNil(view.pendingDocumentSnapshotWorkItem)
        view.configure(BlockInputConfiguration(documentStore: store))

        XCTAssertNil(view.pendingDocumentSnapshotWorkItem)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(stalePublishCount, 0)
        XCTAssertEqual(store.backgroundSnapshotCount, 0)
    }

    func testDroppingBelowLargeDocumentLimitPublishesFreshSnapshotOnce() async throws {
        let firstDeletedID = BlockInputBlockID(rawValue: "block-10001")
        let secondDeletedID = BlockInputBlockID(rawValue: "block-10000")
        let document = BlockInputDocument(blocks: (0..<10_002).map { index in
            BlockInputBlock(
                id: BlockInputBlockID(rawValue: "block-\(index)"),
                text: index >= 10_000 ? "" : "Block \(index)"
            )
        })
        let store = DocumentReadCountingStore(document: document)
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        var publishedCounts: [Int] = []
        view.configure(BlockInputConfiguration(
            documentStore: store,
            onDocumentChange: { publishedCounts.append($0.blocks.count) },
            documentChangeSnapshotDelay: 0.01
        ))
        view.applySelection(.cursor(BlockInputCursor(blockID: firstDeletedID, utf16Offset: 0)), notify: false)
        store.resetCounts()

        _ = view.deleteCurrentEmptyBlockForBackspaceOrDelete()
        XCTAssertNotNil(view.pendingDocumentSnapshotWorkItem)
        view.applySelection(.cursor(BlockInputCursor(blockID: secondDeletedID, utf16Offset: 0)), notify: false)
        _ = view.deleteCurrentEmptyBlockForBackspaceOrDelete()

        XCTAssertEqual(publishedCounts, [10_000])
        XCTAssertNil(view.pendingDocumentSnapshotWorkItem)
        XCTAssertEqual(store.documentReadCount, 1)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(publishedCounts, [10_000])
    }

    private func largeListDocument(targetIndex: Int) -> (BlockInputBlockID, BlockInputDocument) {
        let blockID = BlockInputBlockID(rawValue: "block-\(targetIndex)")
        let document = BlockInputDocument(blocks: (0..<100_000).map { index in
            BlockInputBlock(
                id: BlockInputBlockID(rawValue: "block-\(index)"),
                kind: index == targetIndex ? .bulletedListItem : .paragraph,
                text: index == targetIndex ? "List item" : "Block \(index)"
            )
        })
        return (blockID, document)
    }
}
