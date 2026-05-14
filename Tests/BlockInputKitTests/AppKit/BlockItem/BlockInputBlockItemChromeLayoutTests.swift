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
    func testPlainHeadingCodeAndRuleRowsReserveOnlyReorderHandleSpace() throws {
        let view = BlockInputView()
        let paragraphItem = configuredItem(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            delegate: view
        )
        let paragraphScrollView = try XCTUnwrap(paragraphItem.testingTextScrollView)
        XCTAssertEqual(paragraphScrollView.frame.minX, BlockInputBlockItem.horizontalChromeWidth(allowsReordering: true), accuracy: 0.5)
        XCTAssertEqual(try XCTUnwrap(paragraphItem.testingMarkerView).frame.width, 0, accuracy: 0.5)

        let noMarkerBlocks = [
            BlockInputBlock(id: "heading", kind: .heading(level: 2), text: "Heading"),
            BlockInputBlock(id: "code", kind: .code(language: "swift"), text: "let value = 1"),
            BlockInputBlock(id: "rule", kind: .horizontalRule, text: "")
        ]
        for block in noMarkerBlocks {
            let item = configuredItem(block: block, delegate: view)
            XCTAssertEqual(try XCTUnwrap(item.testingMarkerView).frame.width, 0, accuracy: 0.5, "Unexpected marker lane for \(block.kind).")
        }
    }

    @MainActor
    func testPlainRowsWithoutReorderingReserveOnlyHandleMarginSpace() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            allowsReordering: false,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 420, height: 60)
        item.view.layoutSubtreeIfNeeded()

        let scrollView = try XCTUnwrap(item.testingTextScrollView)
        XCTAssertEqual(scrollView.frame.minX, BlockInputBlockItem.horizontalChromeWidth(allowsReordering: false), accuracy: 0.5)
        XCTAssertEqual(try XCTUnwrap(item.testingMarkerView).frame.width, 0, accuracy: 0.5)
    }

    @MainActor
    func testReorderHandleCentersOnFirstRenderedTextLine() throws {
        let view = BlockInputView()
        let blocks = [
            BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Test"),
            BlockInputBlock(id: "heading", kind: .heading(level: 1), text: "Heading"),
            BlockInputBlock(id: "bullet", kind: .bulletedListItem, text: "Bullet"),
            BlockInputBlock(id: "checklist", kind: .checklistItem(isChecked: false), text: "Task"),
            BlockInputBlock(id: "code", kind: .code(language: nil), text: "let value = 1")
        ]

        for block in blocks {
            let item = configuredItem(block: block, delegate: view)
            let handle = try XCTUnwrap(item.testingHandleView)
            let firstLineRect = try firstTextLineRect(in: item)

            XCTAssertEqual(handle.frame.midY, firstLineRect.midY, accuracy: 1, "Misaligned \(block.kind)")
        }
    }

    @MainActor
    func testReorderHandleDotGridFitsHandleBounds() {
        XCTAssertEqual(BlockInputDragHandleView.columnCount, 2)
        XCTAssertEqual(BlockInputDragHandleView.rowCount, 3)
        XCTAssertLessThanOrEqual(BlockInputDragHandleView.dotGridSize.width, BlockInputBlockItem.handleWidth)
        XCTAssertLessThanOrEqual(BlockInputDragHandleView.dotGridSize.height, BlockInputBlockItem.dragHandleHeight)
    }

    @MainActor
    func testSingleLineTextAndMarkerCenterWithinTallSelectedRow() throws {
        let block = BlockInputBlock(id: "bullet", kind: .bulletedListItem, text: "Test")
        let item = configuredItem(
            block: block,
            isSelected: true,
            delegate: BlockInputView()
        )
        item.view.frame.size.height = BlockInputBlockItem.height(for: block, textWidth: 340)
        item.view.layoutSubtreeIfNeeded()
        let markerView = try XCTUnwrap(item.testingMarkerView)
        let firstLineRect = try firstTextLineRect(in: item)
        let markerLineMidY = markerView.frame.maxY - markerView.markerLineYOffsets[0] - markerView.markerLineHeights[0] / 2
        let rowMidY = item.view.bounds.midY

        XCTAssertEqual(firstLineRect.midY, rowMidY, accuracy: 1)
        XCTAssertEqual(markerLineMidY, rowMidY, accuracy: 1)
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
        XCTAssertEqual(quoteBar.frame.width, BlockInputBlockItem.quoteBarWidth, accuracy: 0.5)
        XCTAssertEqual(quoteBar.frame.minX, paragraphTextMinX, accuracy: 0.5)
        XCTAssertGreaterThan(try textContentMinX(in: quoteItem) - quoteBar.frame.maxX, 8)
    }

    @MainActor
    func testCodeBlockSurfaceAlignsWithPlainTextRowAndUsesRoundedChrome() throws {
        let view = BlockInputView()
        let paragraphItem = configuredItem(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            delegate: view
        )
        let paragraphScrollView = try XCTUnwrap(paragraphItem.testingTextScrollView)
        let codeItem = configuredItem(
            block: BlockInputBlock(id: "code", kind: .code(language: "swift"), text: "let value = 1\nprint(value)"),
            delegate: view
        )
        let codeSurface = codeItem.testingCodeBackgroundView
        let codeScrollView = try XCTUnwrap(codeItem.testingTextScrollView)

        XCTAssertFalse(codeSurface.isHidden)
        XCTAssertEqual(codeSurface.frame.minX, paragraphScrollView.frame.minX, accuracy: 0.5)
        XCTAssertEqual(codeScrollView.frame.minX, paragraphScrollView.frame.minX, accuracy: 0.5)
        XCTAssertEqual(codeSurface.layer?.cornerRadius, 6)
        XCTAssertEqual(codeSurface.layer?.borderWidth, 1)
        XCTAssertNotNil(codeSurface.layer?.backgroundColor)
        XCTAssertNotNil(codeSurface.layer?.borderColor)
    }

    @MainActor
    func testMultilineQuoteBarTracksRenderedTextHeight() throws {
        let block = BlockInputBlock(id: "quote", kind: .quote, text: "First\nSecond\nThird")
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(
            x: 0,
            y: 0,
            width: 420,
            height: BlockInputBlockItem.height(for: block, textWidth: 340)
        )
        item.view.layoutSubtreeIfNeeded()
        item.view.layoutSubtreeIfNeeded()

        let quoteBar = try XCTUnwrap(item.testingQuoteBarView)
        let textRect = try textUsedRect(in: item)

        XCTAssertGreaterThanOrEqual(textRect.minY, item.view.bounds.minY)
        XCTAssertLessThanOrEqual(textRect.maxY, item.view.bounds.maxY)
        XCTAssertEqual(quoteBar.frame.minY, textRect.minY, accuracy: 2)
        XCTAssertEqual(quoteBar.frame.maxY, textRect.maxY, accuracy: 2)
    }

    @MainActor
    func testSingleLineQuoteBarUsesMinimumVisualHeightInsideRow() throws {
        let block = BlockInputBlock(id: "quote", kind: .quote, text: "Quoted")
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(
            x: 0,
            y: 0,
            width: 420,
            height: BlockInputBlockItem.height(for: block, textWidth: 340)
        )
        item.view.layoutSubtreeIfNeeded()

        let quoteBar = try XCTUnwrap(item.testingQuoteBarView)
        let textRect = try textUsedRect(in: item)

        XCTAssertGreaterThan(quoteBar.frame.height, textRect.height)
        XCTAssertGreaterThanOrEqual(quoteBar.frame.minY, item.view.bounds.minY)
        XCTAssertLessThanOrEqual(quoteBar.frame.maxY, item.view.bounds.maxY)
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

        let markerView = try XCTUnwrap(item.testingMarkerView)
        XCTAssertEqual(markerView.markerLines.map(\.text), ["▪"])
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
        isSelected: Bool = false,
        delegate: BlockInputView
    ) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            isSelected: isSelected,
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

    @MainActor
    func textUsedRect(in item: BlockInputBlockItem) throws -> NSRect {
        let textView = try XCTUnwrap(item.testingTextView)
        let layoutManager = try XCTUnwrap(textView.layoutManager)
        let textContainer = try XCTUnwrap(textView.textContainer)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer).offsetBy(
            dx: textView.textContainerOrigin.x,
            dy: textView.textContainerOrigin.y
        )
        return textView.convert(usedRect, to: item.view)
    }

    @MainActor
    func firstTextLineRect(in item: BlockInputBlockItem) throws -> NSRect {
        let textView = try XCTUnwrap(item.testingTextView)
        let layoutManager = try XCTUnwrap(textView.layoutManager)
        let textContainer = try XCTUnwrap(textView.textContainer)
        layoutManager.ensureLayout(for: textContainer)
        let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: 0, effectiveRange: nil).offsetBy(
            dx: textView.textContainerOrigin.x,
            dy: textView.textContainerOrigin.y
        )
        return textView.convert(lineRect, to: item.view)
    }
}
