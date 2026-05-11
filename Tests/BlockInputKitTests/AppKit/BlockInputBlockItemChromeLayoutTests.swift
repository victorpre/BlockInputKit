import XCTest
@testable import BlockInputKit

final class BlockInputBlockItemChromeLayoutTests: XCTestCase {
    @MainActor
    func testListMarkersAlignWithPlainTextBoundaryAndKeepReadableGap() throws {
        let view = BlockInputView()
        let paragraphItem = configuredItem(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            delegate: view
        )
        let paragraphTextMinX = try textContentMinX(in: paragraphItem)

        let listItem = configuredItem(
            block: BlockInputBlock(id: "list", kind: .bulletedListItem, text: "Bullet"),
            delegate: view
        )
        let listMarkerView = try XCTUnwrap(listItem.testingMarkerView)
        let listTextMinX = try textContentMinX(in: listItem)
        XCTAssertEqual(listMarkerView.frame.minX, paragraphTextMinX, accuracy: 0.5)
        XCTAssertEqual(listTextMinX - listMarkerView.frame.minX, BlockInputBlockItem.markerGutterWidth, accuracy: 0.5)

        let numberedItem = configuredItem(
            block: BlockInputBlock(id: "number", kind: .numberedListItem(start: 1), text: "Number"),
            delegate: view
        )
        let numberedMarkerView = try XCTUnwrap(numberedItem.testingMarkerView)
        XCTAssertEqual(numberedMarkerView.frame.minX, paragraphTextMinX, accuracy: 0.5)
        XCTAssertEqual(try textContentMinX(in: numberedItem) - numberedMarkerView.frame.minX, BlockInputBlockItem.markerGutterWidth, accuracy: 0.5)
    }

    @MainActor
    func testChecklistAndQuoteChromeAlignWithPlainTextBoundary() throws {
        let view = BlockInputView()
        let paragraphItem = configuredItem(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            delegate: view
        )
        let paragraphTextMinX = try textContentMinX(in: paragraphItem)

        let checklistItem = configuredItem(
            block: BlockInputBlock(id: "checklist", kind: .checklistItem(isChecked: false), text: "Task"),
            delegate: view
        )
        let checkbox = try XCTUnwrap(checklistItem.testingChecklistButton)
        XCTAssertEqual(checkbox.frame.minX, paragraphTextMinX, accuracy: 0.5)

        let quoteItem = configuredItem(
            block: BlockInputBlock(id: "quote", kind: .quote, text: "Quoted"),
            delegate: view
        )
        let quoteBar = try XCTUnwrap(quoteItem.testingQuoteBarView)
        XCTAssertEqual(quoteBar.frame.minX, paragraphTextMinX, accuracy: 0.5)
        XCTAssertGreaterThan(try textContentMinX(in: quoteItem) - quoteBar.frame.maxX, 8)
    }

    @MainActor
    func testListIndentationMovesTextContent() throws {
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "list", kind: .bulletedListItem, text: "Root"),
            allowsReordering: true,
            delegate: view
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 420, height: 44)
        item.view.layoutSubtreeIfNeeded()
        let scrollView = try XCTUnwrap(item.testingTextScrollView)
        let rootMinX = scrollView.frame.minX

        item.configure(
            block: BlockInputBlock(id: "list", kind: .bulletedListItem, text: "Indented", indentationLevel: 2),
            allowsReordering: true,
            delegate: view
        )
        item.view.layoutSubtreeIfNeeded()

        XCTAssertEqual(try XCTUnwrap(item.testingKindLabel).stringValue, "▪")
        XCTAssertGreaterThanOrEqual(scrollView.frame.minX - rootMinX, 48)
    }

    @MainActor
    func testIndentedChecklistMovesCheckboxAndTextContent() throws {
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "checklist", kind: .checklistItem(isChecked: false), text: "Root"),
            allowsReordering: true,
            delegate: view
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 420, height: 44)
        item.view.layoutSubtreeIfNeeded()
        let checkbox = try XCTUnwrap(item.testingChecklistButton)
        let rootCheckboxMinX = checkbox.frame.minX
        let scrollView = try XCTUnwrap(item.testingTextScrollView)
        let rootTextMinX = scrollView.frame.minX

        item.configure(
            block: BlockInputBlock(
                id: "checklist",
                kind: .checklistItem(isChecked: false),
                text: "Indented",
                indentationLevel: 2
            ),
            allowsReordering: true,
            delegate: view
        )
        item.view.layoutSubtreeIfNeeded()

        XCTAssertGreaterThanOrEqual(checkbox.frame.minX - rootCheckboxMinX, 48)
        XCTAssertGreaterThanOrEqual(scrollView.frame.minX - rootTextMinX, 48)
    }
}

private extension BlockInputBlockItemChromeLayoutTests {
    @MainActor
    func configuredItem(
        block: BlockInputBlock,
        delegate: BlockInputView
    ) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: delegate
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 420, height: 60)
        item.view.layoutSubtreeIfNeeded()
        return item
    }

    @MainActor
    func textContentMinX(in item: BlockInputBlockItem) throws -> CGFloat {
        let scrollView = try XCTUnwrap(item.testingTextScrollView)
        let textView = try XCTUnwrap(item.testingTextView)
        let lineFragmentPadding = textView.textContainer?.lineFragmentPadding ?? 0
        return scrollView.frame.minX + textView.textContainerInset.width + lineFragmentPadding
    }
}
