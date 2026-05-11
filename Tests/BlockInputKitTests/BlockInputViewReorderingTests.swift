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

    private func configuredReorderView(blockIDs: [BlockInputBlockID]) -> BlockInputView {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: blockIDs.map { blockID in
            BlockInputBlock(id: blockID, text: blockID.rawValue)
        })))
        return view
    }
}
