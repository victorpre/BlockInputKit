import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputBlockItemSelectionChromeTests: XCTestCase {
    func testListSelectionChromeUsesContentWidth() throws {
        let paragraphItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "paragraph", text: "Try mention query")
        )
        let orderedItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "ordered", kind: .numberedListItem(start: 1), text: "Toggle reordering")
        )
        let checklistItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "check", kind: .checklistItem(isChecked: false), text: "Checklist data")
        )

        XCTAssertEqual(orderedItem.testingSelectionBackgroundView.frame.minX, paragraphItem.testingSelectionBackgroundView.frame.minX)
        XCTAssertEqual(checklistItem.testingSelectionBackgroundView.frame.minX, paragraphItem.testingSelectionBackgroundView.frame.minX)
        XCTAssertLessThan(orderedItem.testingSelectionBackgroundView.frame.maxX, orderedItem.view.bounds.width / 2)
        XCTAssertLessThan(checklistItem.testingSelectionBackgroundView.frame.maxX, checklistItem.view.bounds.width / 2)
    }

    func testWholeSelectionChromeStartsAtContentLeadingEdge() throws {
        let item = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "paragraph", text: "BlockInputKit demo")
        )
        let scrollView = try XCTUnwrap(item.testingTextScrollView)
        let textView = try XCTUnwrap(item.testingTextView)
        let expectedLeading = floor(scrollView.frame.minX + textView.textContainerInset.width)

        XCTAssertEqual(item.testingSelectionBackgroundView.frame.minX, expectedLeading, accuracy: 1)
    }

    func testHorizontalRuleSelectionChromeUsesTextColumnLeadingEdge() throws {
        let paragraphItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "paragraph", text: "Try mention query")
        )
        let ruleItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "rule", kind: .horizontalRule)
        )

        XCTAssertEqual(ruleItem.testingSelectionBackgroundView.frame.minX, paragraphItem.testingSelectionBackgroundView.frame.minX)
    }

    func testCodeBlockSelectionChromeUsesPlainTextLeadingEdge() throws {
        let paragraphItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "paragraph", text: "Try mention query")
        )
        let codeItem = selectedItemForWidthTesting(
            block: BlockInputBlock(id: "code", kind: .code(language: "swift"), text: "let value = 1")
        )

        XCTAssertEqual(codeItem.testingSelectionBackgroundView.frame.minX, paragraphItem.testingSelectionBackgroundView.frame.minX)
    }

    func testPartialSelectionChromeCollapsesNativeTextSelection() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", text: "BlockInputKit demo"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: 5, length: 8))

        item.setSelectionHighlightRange(NSRange(location: 5, length: 8))

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
        XCTAssertFalse(item.testingSelectionBackgroundView.isHidden)
    }

    func testPartialSelectionChromeSuppressesNativeSelectionBackground() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", text: "BlockInputKit demo"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)

        item.setSelectionHighlightRange(NSRange(location: 5, length: 8))

        XCTAssertEqual(textView.selectedTextAttributes[.backgroundColor] as? NSColor, .clear)
        XCTAssertTrue(textView.isSelectable)
        item.setBlockSelection(false)
        XCTAssertEqual(textView.selectedTextAttributes[.backgroundColor] as? NSColor, .clear)
        XCTAssertTrue(textView.isSelectable)
    }

    func testPartialSelectionChromeKeepsTextViewSelectableForCaretMechanics() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", text: "BlockInputKit demo"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)

        item.setSelectionHighlightRange(NSRange(location: 5, length: 8))

        XCTAssertTrue(textView.isSelectable)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
    }

    func testNativeSelectionBackgroundStaysDisabledForTextViewSelectionMechanics() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", text: "BlockInputKit demo"),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)

        XCTAssertEqual(textView.selectedTextAttributes[.backgroundColor] as? NSColor, .clear)
        XCTAssertTrue(textView.isSelectable)
        item.restoreNativeSelectionDisplay()
        XCTAssertEqual(textView.selectedTextAttributes[.backgroundColor] as? NSColor, .clear)
        XCTAssertTrue(textView.isSelectable)
    }

    func testPartialSelectionChromeIncludesChecklistMarkerWhenStartingAtBeginning() throws {
        let item = partialSelectedItemForWidthTesting(
            block: BlockInputBlock(id: "check", kind: .checklistItem(isChecked: false), text: "Checklist data"),
            range: NSRange(location: 0, length: 1)
        )
        let checkbox = try XCTUnwrap(item.testingChecklistButton)

        XCTAssertLessThanOrEqual(item.testingSelectionBackgroundView.frame.minX, checkbox.frame.minX)
        XCTAssertGreaterThanOrEqual(item.testingSelectionBackgroundView.frame.maxX, checkbox.frame.maxX)
    }

    func testPartialSelectionChromeIncludesListMarkerWhenStartingAtBeginning() throws {
        let item = partialSelectedItemForWidthTesting(
            block: BlockInputBlock(id: "ordered", kind: .numberedListItem(start: 100), text: "Item"),
            range: NSRange(location: 0, length: 1)
        )
        let markerView = try XCTUnwrap(item.testingMarkerView)

        XCTAssertLessThanOrEqual(item.testingSelectionBackgroundView.frame.minX, markerView.frame.minX)
        XCTAssertGreaterThanOrEqual(item.testingSelectionBackgroundView.frame.maxX, markerView.frame.maxX)
    }

    func testPartialSelectionChromeEndsAtInsertionCaret() throws {
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "plain", text: "reveal")
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        mounted.window.makeFirstResponder(textView)

        item.setSelectionHighlightRange(NSRange(location: 0, length: 4))
        item.view.layoutSubtreeIfNeeded()

        let endCaretX = try XCTUnwrap(item.textContainerX(forUTF16Offset: 4))
        let textContainerOrigin = textView.textContainerOrigin
        let endViewX = textView.convert(NSPoint(x: textContainerOrigin.x + endCaretX, y: textContainerOrigin.y), to: item.view).x
        XCTAssertEqual(item.testingSelectionBackgroundView.frame.maxX, ceil(endViewX), accuracy: 1)
    }

    func testPartialSelectionChromeLimitsSingleSelectedLineInMultilineCodeBlock() throws {
        let block = BlockInputBlock(
            id: "code",
            kind: .code(language: nil),
            text: "let one = 1\nlet two = 2\nlet three = 3"
        )
        let item = multilineCodeItemForSelectionChromeTesting(block: block)
        let firstLineRange = (block.text as NSString).lineRange(for: NSRange(location: 0, length: 0))

        item.setSelectionHighlightRange(firstLineRange)
        item.view.layoutSubtreeIfNeeded()

        let segments = item.testingSelectionBackgroundSegmentFrames
        XCTAssertEqual(segments.count, 1)
        XCTAssertLessThan(segments[0].height, item.view.bounds.height / 2)
        XCTAssertLessThan(item.testingSelectionBackgroundView.frame.height, item.view.bounds.height / 2)
    }

    func testPartialSelectionChromeSplitsMultilineCodeSelectionIntoLineSegments() throws {
        let block = BlockInputBlock(
            id: "code",
            kind: .code(language: nil),
            text: "let one = 1\nlet two = 2\nlet three = 3"
        )
        let item = multilineCodeItemForSelectionChromeTesting(block: block)
        let text = block.text as NSString
        let startOffset = text.range(of: "one").location
        let endOffset = text.range(of: "two").location + 3

        item.setSelectionHighlightRange(NSRange(location: startOffset, length: endOffset - startOffset))
        item.view.layoutSubtreeIfNeeded()

        let segments = item.testingSelectionBackgroundSegmentFrames
        XCTAssertEqual(segments.count, 2)
        XCTAssertGreaterThan(abs(segments[0].midY - segments[1].midY), 4)
        XCTAssertLessThan(segments[0].height, item.view.bounds.height / 2)
        XCTAssertLessThan(segments[1].height, item.view.bounds.height / 2)
    }

    func testPartialSelectionChromeIncludesBlankCodeLineSegment() throws {
        let block = BlockInputBlock(
            id: "code",
            kind: .code(language: nil),
            text: "let one = 1\n\nlet three = 3"
        )
        let item = multilineCodeItemForSelectionChromeTesting(block: block)

        item.setSelectionHighlightRange(NSRange(location: 0, length: block.utf16Length))
        item.view.layoutSubtreeIfNeeded()

        let segments = item.testingSelectionBackgroundSegmentFrames
        XCTAssertEqual(segments.count, 3)
        XCTAssertGreaterThan(segments[1].width, 1)
    }

    func testPartialSelectionChromeIncludesTrailingBlankCodeLineSegment() throws {
        let block = BlockInputBlock(
            id: "code",
            kind: .code(language: nil),
            text: "let one = 1\n"
        )
        let item = multilineCodeItemForSelectionChromeTesting(block: block)

        item.setSelectionHighlightRange(NSRange(location: 0, length: block.utf16Length))
        item.view.layoutSubtreeIfNeeded()

        let segments = item.testingSelectionBackgroundSegmentFrames
        XCTAssertEqual(segments.count, 2)
        XCTAssertGreaterThan(segments[1].width, 1)
        XCTAssertGreaterThan(abs(segments[1].midY - segments[0].midY), 4)
    }

    private func selectedItemForWidthTesting(block: BlockInputBlock) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 900, height: 44)
        item.view.layoutSubtreeIfNeeded()
        item.setBlockSelection(true)
        item.view.layoutSubtreeIfNeeded()
        return item
    }

    private func partialSelectedItemForWidthTesting(block: BlockInputBlock, range: NSRange) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 900, height: 44)
        item.view.layoutSubtreeIfNeeded()
        item.setSelectionHighlightRange(range)
        item.view.layoutSubtreeIfNeeded()
        return item
    }

    private func multilineCodeItemForSelectionChromeTesting(block: BlockInputBlock) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: true,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(
            x: 0,
            y: 0,
            width: 900,
            height: BlockInputBlockItem.height(for: block, textWidth: 820)
        )
        item.view.layoutSubtreeIfNeeded()
        return item
    }
}
