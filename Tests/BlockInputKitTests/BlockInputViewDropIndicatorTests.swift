import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewDropIndicatorTests: XCTestCase {
    func testDropInsertionIndexUsesUpperHalfOfVisibleItem() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "first", text: "First"),
            BlockInputBlock(id: "second", text: "Second"),
            BlockInputBlock(id: "third", text: "Third")
        ])
        let attributes = try XCTUnwrap(mounted.view.collectionView.layoutAttributesForItem(
            at: IndexPath(item: 1, section: 0)
        ))

        let insertionIndex = mounted.view.dropInsertionIndex(
            forLocation: NSPoint(x: attributes.frame.midX, y: attributes.frame.minY + 1),
            fallbackIndex: 0
        )

        XCTAssertEqual(insertionIndex, 1)
    }

    func testDropInsertionIndexUsesLowerHalfOfVisibleItem() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "first", text: "First"),
            BlockInputBlock(id: "second", text: "Second"),
            BlockInputBlock(id: "third", text: "Third")
        ])
        let attributes = try XCTUnwrap(mounted.view.collectionView.layoutAttributesForItem(
            at: IndexPath(item: 1, section: 0)
        ))

        let insertionIndex = mounted.view.dropInsertionIndex(
            forLocation: NSPoint(x: attributes.frame.midX, y: attributes.frame.maxY - 1),
            fallbackIndex: 0
        )

        XCTAssertEqual(insertionIndex, 2)
    }

    func testValidateDropShowsInsertionIndicatorAtResolvedIndex() throws {
        let secondID = BlockInputBlockID(rawValue: "second")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "first", text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: "third", text: "Third")
        ])
        let attributes = try XCTUnwrap(mounted.view.collectionView.layoutAttributesForItem(
            at: IndexPath(item: 1, section: 0)
        ))
        let collectionLocation = NSPoint(x: attributes.frame.midX, y: attributes.frame.maxY - 1)
        let windowLocation = mounted.view.collectionView.convert(collectionLocation, to: nil)
        let draggingInfo = BlockInputDraggingInfo(blockID: secondID, location: windowLocation)
        var indexPath = NSIndexPath(forItem: 0, inSection: 0)
        var operation = NSCollectionView.DropOperation.on

        let dragOperation = withUnsafeMutablePointer(to: &indexPath) { pointer in
            mounted.view.collectionView(
                mounted.view.collectionView,
                validateDrop: draggingInfo,
                proposedIndexPath: AutoreleasingUnsafeMutablePointer(pointer),
                dropOperation: &operation
            )
        }

        XCTAssertTrue(dragOperation.contains(.move))
        XCTAssertEqual(indexPath.item, 2)
        XCTAssertEqual(operation, .before)
        XCTAssertFalse(mounted.view.dropIndicatorView.isHidden)
        XCTAssertEqual(
            mounted.view.dropIndicatorView.frame.minY,
            mounted.view.dropIndicatorFrame(forInsertionIndex: 2)?.minY
        )
    }

    func testAcceptDropUsesResolvedInsertionIndexInsteadOfStaleProposedIndex() throws {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])
        let secondAttributes = try XCTUnwrap(mounted.view.collectionView.layoutAttributesForItem(
            at: IndexPath(item: 1, section: 0)
        ))
        let collectionLocation = NSPoint(x: secondAttributes.frame.midX, y: secondAttributes.frame.minY + 1)
        let windowLocation = mounted.view.collectionView.convert(collectionLocation, to: nil)

        let accepted = mounted.view.collectionView(
            mounted.view.collectionView,
            acceptDrop: BlockInputDraggingInfo(blockID: thirdID, location: windowLocation),
            indexPath: IndexPath(item: 0, section: 0),
            dropOperation: .before
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(mounted.view.document.blocks.map(\.id), [firstID, thirdID, secondID])
    }

    func testDropIndicatorUsesConfiguredColor() {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "first", text: "First")
            ]),
            dropIndicatorColor: .systemPink
        ))

        view.showDropIndicator(atInsertionIndex: 0)

        XCTAssertEqual(view.dropIndicatorColor, .systemPink)
        XCTAssertEqual(view.dropIndicatorView.layer?.backgroundColor, NSColor.systemPink.cgColor)
    }

    func testDropIndicatorIsHiddenFromAccessibility() {
        let view = BlockInputView()

        XCTAssertFalse(view.dropIndicatorView.isAccessibilityElement())
    }

    func testDropIndicatorColorUpdatesWhenReconfigured() {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(dropIndicatorColor: .systemBlue))

        view.configure(BlockInputConfiguration(dropIndicatorColor: .systemGreen))

        XCTAssertEqual(view.dropIndicatorColor, .systemGreen)
        XCTAssertEqual(view.dropIndicatorView.layer?.backgroundColor, NSColor.systemGreen.cgColor)
    }

    func testInvalidDropHidesInsertionIndicator() {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: "first", text: "First")
        ])))
        view.showDropIndicator(atInsertionIndex: 0)
        var indexPath = NSIndexPath(forItem: 0, inSection: 0)
        var operation = NSCollectionView.DropOperation.on

        _ = withUnsafeMutablePointer(to: &indexPath) { pointer in
            view.collectionView(
                view.collectionView,
                validateDrop: BlockInputDraggingInfo(blockID: nil),
                proposedIndexPath: AutoreleasingUnsafeMutablePointer(pointer),
                dropOperation: &operation
            )
        }

        XCTAssertTrue(view.dropIndicatorView.isHidden)
    }
}
