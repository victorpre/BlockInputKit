import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputZeroWidthLayoutRegressionTests: XCTestCase {
    func testBlockItemRootViewDoesNotUseAutoresizingMaskLayout() {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            allowsReordering: true,
            delegate: BlockInputView()
        )

        XCTAssertFalse(item.view.translatesAutoresizingMaskIntoConstraints)
    }

    func testRowSizingFallsBackWhenCollectionViewWidthIsZero() {
        let view = BlockInputView(frame: NSRect(x: 0, y: 0, width: 360, height: 240))
        let block = BlockInputBlock(
            id: "checklist",
            kind: .checklistItem(isChecked: false),
            text: "Task",
            whenDate: "2026-06-15",
            tags: ["work"]
        )

        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [block])))
        view.layoutSubtreeIfNeeded()

        let previousFrame = view.collectionView.frame
        view.collectionView.frame = NSRect(origin: previousFrame.origin, size: NSSize(width: 0, height: previousFrame.height))

        let rowSize = view.collectionView(
            view.collectionView,
            layout: view.layout,
            sizeForItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertGreaterThan(rowSize.width, 0)
        XCTAssertEqual(rowSize.width, view.currentCollectionItemWidth(viewportWidth: view.resolvedCollectionViewportWidth()), accuracy: 0.5)
    }

    func testMountedChecklistTableAndImageRowsKeepPositiveGeometryOnFirstLayout() throws {
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: "checklist",
                    kind: .checklistItem(isChecked: false),
                    text: "Task",
                    whenDate: "2026-06-15",
                    deadline: "2026-06-20",
                    tags: ["work", "urgent"]
                ),
                BlockInputBlock(
                    id: "table",
                    kind: .table,
                    text: """
                    | First column | Second column |
                    | --- | --- |
                    | First cell | Second cell |
                    """
                ),
                BlockInputBlock(
                    id: "image",
                    kind: .image(BlockInputImage(
                        source: "https://example.com/image.png",
                        width: 240,
                        height: 120,
                        sourceStyle: .html
                    ))
                )
            ])
        ), size: NSSize(width: 720, height: 480), styleMask: [.borderless])

        let checklistItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let tableItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let imageItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 2))

        try assertPositiveRowGeometry(checklistItem)
        try assertPositiveRowGeometry(tableItem)
        try assertPositiveRowGeometry(imageItem)

        let metadataRowView = try XCTUnwrap(checklistItem.testingMetadataRowView)
        XCTAssertFalse(metadataRowView.isHidden)
        XCTAssertGreaterThan(metadataRowView.frame.height, 0)
        XCTAssertLessThanOrEqual(metadataRowView.frame.maxY, checklistItem.view.bounds.maxY + 0.5)

        XCTAssertGreaterThan(tableItem.testingTableView.frame.width, 0)
        XCTAssertGreaterThan(tableItem.testingTableView.frame.height, 0)
        XCTAssertLessThanOrEqual(tableItem.testingTableView.frame.maxX, tableItem.view.bounds.maxX + 0.5)
        XCTAssertLessThanOrEqual(tableItem.testingTableView.frame.maxY, tableItem.view.bounds.maxY + 0.5)

        XCTAssertGreaterThan(imageItem.testingImageBlockView.frame.width, 0)
        XCTAssertGreaterThan(imageItem.testingImageBlockView.frame.height, 0)
        XCTAssertLessThanOrEqual(imageItem.testingImageBlockView.frame.maxX, imageItem.view.bounds.maxX + 0.5)
        XCTAssertLessThanOrEqual(imageItem.testingImageBlockView.frame.maxY, imageItem.view.bounds.maxY + 0.5)
    }

    func testMountedChecklistWithoutMetadataCollapsesSecondRow() throws {
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: "checklist",
                    kind: .checklistItem(isChecked: false),
                    text: "Task"
                )
            ])
        ), size: NSSize(width: 720, height: 240), styleMask: [.borderless])

        let checklistItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let metadataRowView = try XCTUnwrap(checklistItem.testingMetadataRowView)
        let detailButton = try XCTUnwrap(checklistItem.testingDetailButton)

        XCTAssertTrue(metadataRowView.isHidden)
        XCTAssertEqual(metadataRowView.frame.height, 0, accuracy: 0.5)
        XCTAssertLessThanOrEqual(metadataRowView.frame.maxY, checklistItem.view.bounds.maxY + 0.5)
        XCTAssertTrue(detailButton.isHidden)
    }

    private func assertPositiveRowGeometry(_ item: BlockInputBlockItem, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertGreaterThan(item.view.bounds.width, 0, file: file, line: line)
        XCTAssertGreaterThan(item.view.bounds.height, 0, file: file, line: line)

        let scrollView = try XCTUnwrap(item.testingTextScrollView, file: file, line: line)
        XCTAssertGreaterThanOrEqual(scrollView.frame.minX, item.view.bounds.minX - 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(scrollView.frame.maxX, item.view.bounds.maxX + 0.5, file: file, line: line)
    }
}
