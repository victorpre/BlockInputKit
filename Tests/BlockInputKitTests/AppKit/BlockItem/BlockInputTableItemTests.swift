import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTableItemTests: XCTestCase {
    func testTableUsesDedicatedSurfaceAndHidesBlockTextView() throws {
        let item = configuredItem(block: Self.compactTable())
        let textView = try XCTUnwrap(item.testingTextView)
        let overflowScrollView = item.testingTableOverflowScrollView

        XCTAssertFalse(item.testingTableView.isHidden)
        XCTAssertTrue(item.scrollView.isHidden)
        XCTAssertFalse(textView.isEditable)
        XCTAssertFalse(textView.isSelectable)
        XCTAssertTrue(overflowScrollView.hasHorizontalScroller)
        XCTAssertFalse(overflowScrollView.hasVerticalScroller)
        XCTAssertEqual(overflowScrollView.scrollerStyle, .overlay)
        XCTAssertEqual(overflowScrollView.verticalScrollElasticity, .none)
    }

    func testCompactTableHugsNaturalWidth() {
        let item = configuredItem(block: Self.compactTable(), itemWidth: 640, textWidth: 560)

        XCTAssertEqual(item.testingTableView.visibleTableFrame.width, 240, accuracy: 1)
    }

    func testWideTableScrollsInternallyAndPreservesHorizontalOffsetAcrossRelayout() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260)
        let overflowScrollView = item.testingTableOverflowScrollView
        let documentView = try XCTUnwrap(overflowScrollView.documentView)

        XCTAssertGreaterThan(documentView.frame.width, overflowScrollView.contentView.bounds.width)

        overflowScrollView.contentView.scroll(to: NSPoint(x: 140, y: 0))
        overflowScrollView.reflectScrolledClipView(overflowScrollView.contentView)
        item.view.frame.size.height += 12
        item.view.layoutSubtreeIfNeeded()

        XCTAssertEqual(overflowScrollView.contentView.bounds.origin.x, 140, accuracy: 1)
    }

    func testAppendColumnHoverOnlyAppearsWhenRightTableEdgeIsVisibleInWideTable() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260)
        let tableView = item.testingTableView
        let overflowScrollView = item.testingTableOverflowScrollView
        let documentView = try XCTUnwrap(overflowScrollView.documentView)
        let tableFrame = tableView.visibleTableFrame

        tableView.updateAppendControlVisibility(for: NSPoint(x: tableFrame.maxX, y: tableFrame.midY))
        XCTAssertTrue(item.testingAppendTableColumnButton.isHidden)

        let maximumX = max(0, documentView.frame.width - overflowScrollView.contentView.bounds.width)
        overflowScrollView.contentView.scroll(to: NSPoint(x: maximumX, y: 0))
        overflowScrollView.reflectScrolledClipView(overflowScrollView.contentView)
        tableView.updateAppendControlVisibility(for: NSPoint(x: tableFrame.maxX, y: tableFrame.midY))

        XCTAssertFalse(item.testingAppendTableColumnButton.isHidden)
        XCTAssertEqual(item.testingAppendTableColumnButton.frame.midX, tableFrame.maxX, accuracy: 1)
    }

    func testHorizontalScrollbarReserveMatchesAlvearyOverflowBehavior() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260)
        let documentView = try XCTUnwrap(item.testingTableOverflowScrollView.documentView)
        let expectedReserve = NSScroller.preferredScrollerStyle == .legacy
            ? ceil(NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy))
            : 0

        XCTAssertEqual(item.testingTableView.visibleTableFrame.height, documentView.frame.height + expectedReserve, accuracy: 1)
    }

    func testTableOverflowClipViewClampsVerticalOrigin() {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260)
        let overflowScrollView = item.testingTableOverflowScrollView

        overflowScrollView.contentView.scroll(to: NSPoint(x: 48, y: 20))
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: overflowScrollView.contentView)

        XCTAssertEqual(overflowScrollView.contentView.bounds.origin.x, 48, accuracy: 1)
        XCTAssertEqual(overflowScrollView.contentView.bounds.origin.y, 0, accuracy: 0.5)
    }

    func testMostlyVerticalWheelOverTableOverflowForwardsToAncestor() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260, embeddedInVerticalScrollView: true)
        let parentScrollView = try XCTUnwrap(item.view.enclosingScrollView as? TableRecordingScrollView)

        item.testingTableOverflowScrollView.scrollWheel(with: try Self.scrollEvent(deltaY: -12, deltaX: -12))

        XCTAssertEqual(parentScrollView.verticalScrollCount, 1)
    }

    func testHorizontalDominantWheelOverTableOverflowStaysLocal() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260, embeddedInVerticalScrollView: true)
        let parentScrollView = try XCTUnwrap(item.view.enclosingScrollView as? TableRecordingScrollView)

        item.testingTableOverflowScrollView.scrollWheel(with: try Self.scrollEvent(deltaY: -4, deltaX: -12))

        XCTAssertEqual(parentScrollView.verticalScrollCount, 0)
    }

    func testDecayingVerticalWheelSequenceOverTableOverflowContinuesForwardingToAncestor() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260, embeddedInVerticalScrollView: true)
        let parentScrollView = try XCTUnwrap(item.view.enclosingScrollView as? TableRecordingScrollView)

        item.testingTableOverflowScrollView.scrollWheel(with: try Self.scrollEvent(deltaY: -12, deltaX: -1))
        item.testingTableOverflowScrollView.scrollWheel(with: try Self.scrollEvent(deltaY: -1, deltaX: -12))

        XCTAssertEqual(parentScrollView.verticalScrollCount, 2)
    }

    func testPhaseLessVerticalWheelSequenceOverTableOverflowResetsOnNextMainLoopTurn() throws {
        let item = configuredItem(block: Self.wideTable(), itemWidth: 340, textWidth: 260, embeddedInVerticalScrollView: true)
        let parentScrollView = try XCTUnwrap(item.view.enclosingScrollView as? TableRecordingScrollView)

        item.testingTableOverflowScrollView.scrollWheel(with: try Self.scrollEvent(deltaY: -12, deltaX: -1))
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        item.testingTableOverflowScrollView.scrollWheel(with: try Self.scrollEvent(deltaY: -1, deltaX: -12))

        XCTAssertEqual(parentScrollView.verticalScrollCount, 1)
    }

    func testTableHeightAccountsForWrappedCells() {
        let shortHeight = BlockInputBlockItem.height(for: Self.compactTable(), textWidth: 260)
        let wrappedHeight = BlockInputBlockItem.height(for: Self.wrappedTable(), textWidth: 260)

        XCTAssertGreaterThan(wrappedHeight, shortHeight)
    }

    func testReusingTableItemForParagraphResetsTableSurface() throws {
        let item = configuredItem(block: Self.wideTable())
        item.testingTableOverflowScrollView.contentView.scroll(to: NSPoint(x: 120, y: 0))
        item.testingTableOverflowScrollView.reflectScrolledClipView(item.testingTableOverflowScrollView.contentView)

        item.configure(
            block: BlockInputBlock(id: "paragraph", text: "Plain text"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.layoutSubtreeIfNeeded()

        let textView = try XCTUnwrap(item.testingTextView)
        XCTAssertTrue(item.testingTableView.isHidden)
        XCTAssertFalse(item.scrollView.isHidden)
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertEqual(item.testingTableOverflowScrollView.contentView.bounds.origin.x, 0, accuracy: 0.5)
    }

    func testInvalidTableBlockFallsBackToTextSurface() throws {
        let item = configuredItem(block: BlockInputBlock(id: "invalid", kind: .table, text: "| Not a table |"))
        let textView = try XCTUnwrap(item.testingTextView)

        XCTAssertTrue(item.testingTableView.isHidden)
        XCTAssertFalse(item.scrollView.isHidden)
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertEqual(textView.string, "| Not a table |")
        XCTAssertGreaterThan(textView.frame.width, 0)
        XCTAssertEqual(textView.frame.width, item.scrollView.contentView.bounds.width, accuracy: 0.5)
    }

    private func configuredItem(
        block: BlockInputBlock,
        itemWidth: CGFloat = 360,
        textWidth: CGFloat = 280,
        embeddedInVerticalScrollView: Bool = false
    ) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(
            x: 0,
            y: 0,
            width: itemWidth,
            height: BlockInputBlockItem.height(for: block, textWidth: textWidth)
        )
        item.view.layoutSubtreeIfNeeded()
        if embeddedInVerticalScrollView {
            let parentScrollView = TableRecordingScrollView(frame: NSRect(x: 0, y: 0, width: itemWidth + 40, height: 160))
            parentScrollView.hasVerticalScroller = true
            let documentView = NSView(frame: NSRect(x: 0, y: 0, width: itemWidth + 40, height: 420))
            parentScrollView.documentView = documentView
            documentView.addSubview(item.view)
            item.view.layoutSubtreeIfNeeded()
        }
        return item
    }

    private static func compactTable() -> BlockInputBlock {
        BlockInputBlock(id: "table", kind: .table, text: """
        | A | B |
        | --- | --- |
        | 1 | 2 |
        """)
    }

    private static func wideTable() -> BlockInputBlock {
        BlockInputBlock(id: "wide-table", kind: .table, text: """
        | One | Two | Three | Four | Five | Six |
        | --- | --- | --- | --- | --- | --- |
        | 1 | 2 | 3 | 4 | 5 | 6 |
        """)
    }

    private static func wrappedTable() -> BlockInputBlock {
        BlockInputBlock(id: "wrapped-table", kind: .table, text: """
        | A | B |
        | --- | --- |
        | \(Array(repeating: "wrapped", count: 60).joined(separator: " ")) | 2 |
        """)
    }

    private static func scrollEvent(deltaY: Int32, deltaX: Int32) throws -> NSEvent {
        let cgEvent = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ))
        return try XCTUnwrap(NSEvent(cgEvent: cgEvent))
    }
}

private final class TableRecordingScrollView: NSScrollView {
    var verticalScrollCount = 0

    override func scrollWheel(with event: NSEvent) {
        verticalScrollCount += 1
    }
}
