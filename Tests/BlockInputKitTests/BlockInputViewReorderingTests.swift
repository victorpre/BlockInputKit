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

        let accepted = view.collectionView(
            view.collectionView,
            acceptDrop: BlockInputDraggingInfo(blockID: firstID),
            indexPath: IndexPath(item: 2, section: 0),
            dropOperation: .before
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(store.document.blocks.map(\.id), [secondID, firstID])
        XCTAssertEqual(view.document.blocks.map(\.id), [secondID, firstID])
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

        XCTAssertFalse(handleView.isEnabled)
        XCTAssertEqual(handleView.alphaValue, 0)
        XCTAssertNil(handleView.toolTip)
    }

    func testBlockItemEnablesHoverHandleWhenReorderingIsEnabled() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "first", text: "First"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let handleView = try XCTUnwrap(item.testingHandleView)

        XCTAssertTrue(handleView.isEnabled)
        XCTAssertEqual(handleView.alphaValue, 0)
        XCTAssertEqual(handleView.toolTip, "Drag to reorder block")
    }

    func testBlockItemClearConfigurationRemovesReusableBlockState() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "first", kind: .quote, text: "First"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)
        let handleView = try XCTUnwrap(item.testingHandleView)
        textView.setSelectedRange(NSRange(location: 2, length: 2))

        item.clearConfiguration()

        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertFalse(handleView.isEnabled)
        XCTAssertEqual(handleView.alphaValue, 0)
        XCTAssertNil(handleView.toolTip)
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

private final class BlockInputDraggingInfo: NSObject, NSDraggingInfo {
    private let pasteboard: NSPasteboard

    init(blockID: BlockInputBlockID?) {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("BlockInputKitTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        if let blockID {
            pasteboard.setString(blockID.rawValue, forType: .blockInputBlockID)
        }
    }

    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .move }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingPasteboard: NSPasteboard { pasteboard }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 0 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    func slideDraggedImage(to screenPoint: NSPoint) {}

    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
        nil
    }

    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions = [],
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}

    func resetSpringLoading() {}
}
