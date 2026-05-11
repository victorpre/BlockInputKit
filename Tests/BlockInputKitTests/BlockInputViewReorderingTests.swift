import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewReorderingTests: XCTestCase {
    func testCollectionDropTargetAdjustsForwardMovesToFinalDocumentIndex() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let view = configuredReorderView(blockIDs: [firstID, secondID, thirdID])

        let targetIndex = view.collectionDropTargetIndex(
            forBlockID: firstID,
            proposedItemIndex: 2
        )

        XCTAssertEqual(targetIndex, 1)
    }

    func testCollectionDropTargetKeepsBackwardMovesAtProposedIndex() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let view = configuredReorderView(blockIDs: [firstID, secondID, thirdID])

        let targetIndex = view.collectionDropTargetIndex(
            forBlockID: thirdID,
            proposedItemIndex: 0
        )

        XCTAssertEqual(targetIndex, 0)
    }

    func testCollectionDropTargetSupportsDroppingAtEnd() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let view = configuredReorderView(blockIDs: [firstID, secondID, thirdID])

        let targetIndex = view.collectionDropTargetIndex(
            forBlockID: firstID,
            proposedItemIndex: 3
        )

        XCTAssertEqual(targetIndex, 2)
    }

    func testPasteboardWriterIsDisabledWhenReorderingIsDisabled() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            allowsBlockReordering: false
        ))

        let writer = view.collectionView(
            view.collectionView,
            pasteboardWriterForItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertNil(writer)
    }

    func testPasteboardWriterStoresBlockIDWhenReorderingIsEnabled() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = configuredReorderView(blockIDs: [blockID])

        let writer = try XCTUnwrap(view.collectionView(
            view.collectionView,
            pasteboardWriterForItemAt: IndexPath(item: 0, section: 0)
        ) as? NSPasteboardItem)

        XCTAssertEqual(writer.string(forType: .blockInputBlockID), blockID.rawValue)
    }

    func testCanAcceptBlockReorderDropAcceptsKnownBlockID() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = configuredReorderView(blockIDs: [blockID])

        XCTAssertTrue(view.canAcceptBlockReorderDrop(BlockInputDraggingInfo(blockID: blockID)))
    }

    func testCanAcceptBlockReorderDropRejectsDisabledReordering() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = configuredReorderView(
            blockIDs: [blockID],
            allowsBlockReordering: false
        )

        XCTAssertFalse(view.canAcceptBlockReorderDrop(BlockInputDraggingInfo(blockID: blockID)))
    }

    func testCanAcceptBlockReorderDropRejectsUnknownBlockID() {
        let view = configuredReorderView(blockIDs: ["first"])

        XCTAssertFalse(view.canAcceptBlockReorderDrop(BlockInputDraggingInfo(blockID: "missing")))
    }

    func testCanAcceptBlockReorderDropRejectsMissingBlockID() {
        let view = configuredReorderView(blockIDs: ["first"])

        XCTAssertFalse(view.canAcceptBlockReorderDrop(BlockInputDraggingInfo(blockID: nil)))
    }

    func testValidateDropAcceptsFileURLsEvenWhenReorderingIsDisabled() {
        let view = configuredReorderView(
            blockIDs: ["first"],
            allowsBlockReordering: false
        )
        let draggingInfo = BlockInputDraggingInfo(fileURLs: [
            URL(fileURLWithPath: "/tmp/example.txt")
        ])
        var indexPath = NSIndexPath(forItem: 0, inSection: 0)
        var operation = NSCollectionView.DropOperation.on

        let dragOperation = withUnsafeMutablePointer(to: &indexPath) { pointer in
            view.collectionView(
                view.collectionView,
                validateDrop: draggingInfo,
                proposedIndexPath: AutoreleasingUnsafeMutablePointer(pointer),
                dropOperation: &operation
            )
        }

        XCTAssertTrue(dragOperation.contains(.copy))
        XCTAssertEqual(operation, .before)
    }

    func testValidateDropRejectsRemoteURLs() throws {
        let view = configuredReorderView(blockIDs: ["first"])
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/file.txt"))
        var indexPath = NSIndexPath(forItem: 0, inSection: 0)
        var operation = NSCollectionView.DropOperation.on

        let dragOperation = withUnsafeMutablePointer(to: &indexPath) { pointer in
            view.collectionView(
                view.collectionView,
                validateDrop: BlockInputDraggingInfo(fileURLs: [remoteURL]),
                proposedIndexPath: AutoreleasingUnsafeMutablePointer(pointer),
                dropOperation: &operation
            )
        }

        XCTAssertTrue(dragOperation.isEmpty)
    }

    func testAcceptDropMovesBlockAndPublishesDocumentChange() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        var publishedDocuments: [BlockInputDocument] = []
        let view = configuredReorderView(
            blockIDs: [firstID, secondID, thirdID],
            onDocumentChange: { publishedDocuments.append($0) }
        )
        let draggingInfo = BlockInputDraggingInfo(blockID: firstID)

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: draggingInfo,
            indexPath: IndexPath(item: 2, section: 0),
            dropOperation: .before
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(view.document.blocks.map(\.id), [secondID, firstID, thirdID])
        XCTAssertEqual(publishedDocuments.last, view.document)
    }

    func testAcceptDropInsertsFileURLsAtProposedIndex() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        var publishedDocuments: [BlockInputDocument] = []
        let view = configuredReorderView(
            blockIDs: [firstID, secondID],
            allowsBlockReordering: false,
            onDocumentChange: { publishedDocuments.append($0) }
        )

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: BlockInputDraggingInfo(fileURLs: [
                URL(fileURLWithPath: "/tmp/example.txt")
            ]),
            indexPath: IndexPath(item: 1, section: 0),
            dropOperation: .before
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(view.document.blocks.map(\.text), [
            "first",
            "[example.txt](<file:///tmp/example.txt>)",
            "second"
        ])
        XCTAssertEqual(publishedDocuments.last, view.document)
    }

    func testAcceptFileDropPublishesGranularInsertionToStore() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            documentStore: store,
            allowsBlockReordering: false
        ))
        store.resetCounts()

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: BlockInputDraggingInfo(fileURLs: [
                URL(fileURLWithPath: "/tmp/example.txt")
            ]),
            indexPath: IndexPath(item: 1, section: 0),
            dropOperation: .before
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(store.document.blocks.map(\.text), [
            "First",
            "[example.txt](<file:///tmp/example.txt>)",
            "Second"
        ])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.insertedBlockBatches.count, 1)
        XCTAssertEqual(store.insertedBlockBatches.first?.index, 1)
        XCTAssertEqual(store.insertedBlockBatches.first?.blocks.map(\.text), [
            "[example.txt](<file:///tmp/example.txt>)"
        ])
    }

    func testAcceptDropRefreshesFromConfiguredStoreBeforeMovingBlock() {
        let staleID = BlockInputBlockID(rawValue: "stale")
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: staleID, text: "Old")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        store.replaceDocument(BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ]))
        store.resetCounts()

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: BlockInputDraggingInfo(blockID: firstID),
            indexPath: IndexPath(item: 2, section: 0),
            dropOperation: .before
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(store.document.blocks.map(\.id), [secondID, firstID])
        XCTAssertEqual(view.document.blocks.map(\.id), [secondID, firstID])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.movedBlocks.map(\.id), [firstID])
        XCTAssertEqual(store.movedBlocks.map(\.index), [1])
    }

    func testMoveBlockPublishesClampedFinalIndexToStore() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ]))
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(documentStore: store))
        store.resetCounts()

        _ = view.moveBlock(blockID: firstID, to: 99)

        XCTAssertEqual(store.document.blocks.map(\.id), [secondID, thirdID, firstID])
        XCTAssertEqual(view.document.blocks.map(\.id), [secondID, thirdID, firstID])
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.movedBlocks.map(\.id), [firstID])
        XCTAssertEqual(store.movedBlocks.map(\.index), [2])
    }

    func testAcceptDropReturnsFalseWhenReorderingIsDisabled() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = configuredReorderView(
            blockIDs: [firstID, secondID],
            allowsBlockReordering: false
        )
        let draggingInfo = BlockInputDraggingInfo(blockID: firstID)

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: draggingInfo,
            indexPath: IndexPath(item: 1, section: 0),
            dropOperation: .before
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, secondID])
    }

    func testAcceptDropReturnsFalseForUnknownBlockID() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = configuredReorderView(blockIDs: [firstID, secondID])
        let draggingInfo = BlockInputDraggingInfo(blockID: "missing")

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: draggingInfo,
            indexPath: IndexPath(item: 1, section: 0),
            dropOperation: .before
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, secondID])
    }

    func testBlockItemDisablesHoverHandleWhenReorderingIsDisabled() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "first", text: "First"),
            allowsReordering: false,
            delegate: BlockInputView()
        )
        let handleView = try XCTUnwrap(item.testingHandleView)
        let handleWidthConstraint = try XCTUnwrap(item.testingHandleWidthConstraint)

        XCTAssertFalse(handleView.isEnabled)
        XCTAssertTrue(handleView.isHidden)
        XCTAssertEqual(handleWidthConstraint.constant, 0)
        XCTAssertEqual(handleView.alphaValue, 0)
        XCTAssertNil(handleView.toolTip)
        XCTAssertNil(item.draggingPasteboardItem())
    }

    func testBlockItemEnablesHoverHandleWhenReorderingIsEnabled() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: blockID, text: "First"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let handleView = try XCTUnwrap(item.testingHandleView)
        let handleWidthConstraint = try XCTUnwrap(item.testingHandleWidthConstraint)
        let pasteboardItem = try XCTUnwrap(item.draggingPasteboardItem())

        XCTAssertTrue(handleView.isEnabled)
        XCTAssertFalse(handleView.isHidden)
        XCTAssertEqual(handleWidthConstraint.constant, 24)
        XCTAssertEqual(handleView.alphaValue, 0)
        XCTAssertEqual(handleView.toolTip, "Drag to reorder block")
        XCTAssertEqual(handleView.accessibilityLabel(), "Drag to reorder block")
        XCTAssertEqual(pasteboardItem.string(forType: .blockInputBlockID), blockID.rawValue)
    }

    func testBlockItemHidesHoverHandleWhenReconfiguredWithReorderingDisabled() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "first", text: "First"),
            allowsReordering: true,
            delegate: BlockInputView()
        )

        item.configure(
            block: BlockInputBlock(id: "first", text: "First"),
            allowsReordering: false,
            delegate: BlockInputView()
        )

        let handleView = try XCTUnwrap(item.testingHandleView)
        let handleWidthConstraint = try XCTUnwrap(item.testingHandleWidthConstraint)
        XCTAssertFalse(handleView.isEnabled)
        XCTAssertTrue(handleView.isHidden)
        XCTAssertEqual(handleWidthConstraint.constant, 0)
        XCTAssertNil(handleView.toolTip)
        XCTAssertNil(item.draggingPasteboardItem())
    }

    func testBlockItemClearConfigurationRemovesReusableBlockState() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "first", kind: .quote, text: "First"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)
        let handleView = try XCTUnwrap(item.testingHandleView)
        let handleWidthConstraint = try XCTUnwrap(item.testingHandleWidthConstraint)
        textView.setSelectedRange(NSRange(location: 2, length: 2))

        item.clearConfiguration()

        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertFalse(handleView.isEnabled)
        XCTAssertTrue(handleView.isHidden)
        XCTAssertEqual(handleWidthConstraint.constant, 0)
        XCTAssertEqual(handleView.alphaValue, 0)
        XCTAssertNil(handleView.toolTip)
        XCTAssertNil(item.draggingPasteboardItem())
        textView.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        XCTAssertEqual(textView.string, "")
    }

    private func configuredReorderView(blockIDs: [BlockInputBlockID]) -> BlockInputView {
        configuredReorderView(blockIDs: blockIDs, allowsBlockReordering: true)
    }

    private func configuredReorderView(
        blockIDs: [BlockInputBlockID],
        allowsBlockReordering: Bool = true,
        onDocumentChange: ((BlockInputDocument) -> Void)? = nil
    ) -> BlockInputView {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: blockIDs.map { blockID in
                BlockInputBlock(id: blockID, text: blockID.rawValue)
            }),
            allowsBlockReordering: allowsBlockReordering,
            onDocumentChange: onDocumentChange
        ))
        return view
    }
}
