import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputInlineChipNavigationTests: XCTestCase {
    func testPlainLeftAtFileLinkChipContentStartExitsLeadingEdge() throws {
        let text = "Open [README.md](file:///tmp/README.md) trailing"
        let textView = try mountedTextView(for: text)
        let linkRange = try XCTUnwrap(inlineLinkRange(in: text))
        textView.setSelectedRange(NSRange(location: linkRange.contentRange.location, length: 0))

        textView.keyDown(with: try plainLeftEvent())

        XCTAssertEqual(textView.selectedRange(), NSRange(location: linkRange.fullRange.location, length: 0))
        XCTAssertEqual(textView.selectionAffinity, .upstream)
        try assertCaret(in: textView, isAtLeadingEdgeOfChipFor: linkRange)
    }

    func testPlainRightAtFileLinkChipContentEndExitsTrailingEdge() throws {
        let text = "Open [README.md](file:///tmp/README.md) trailing"
        let textView = try mountedTextView(for: text)
        let linkRange = try XCTUnwrap(inlineLinkRange(in: text))
        textView.setSelectedRange(NSRange(location: NSMaxRange(linkRange.contentRange), length: 0))

        textView.keyDown(with: try plainRightEvent())

        XCTAssertEqual(textView.selectedRange(), NSRange(location: NSMaxRange(linkRange.fullRange), length: 0))
        XCTAssertEqual(textView.selectionAffinity, .downstream)
        try assertCaret(in: textView, isAtTrailingEdgeOfChipFor: linkRange)
    }

    func testMoveLeftCommandAtSlashCommandChipContentStartExitsLeadingEdge() throws {
        let text = "Run [/table](host-app://commands/table) today"
        let textView = try mountedTextView(for: text)
        let linkRange = try XCTUnwrap(inlineLinkRange(in: text))
        textView.setSelectedRange(NSRange(location: linkRange.contentRange.location, length: 0))

        textView.doCommand(by: #selector(NSResponder.moveLeft(_:)))

        XCTAssertEqual(textView.selectedRange(), NSRange(location: linkRange.fullRange.location, length: 0))
        XCTAssertEqual(textView.selectionAffinity, .upstream)
        try assertCaret(in: textView, isAtLeadingEdgeOfChipFor: linkRange)
    }

    func testMoveRightCommandAtSlashCommandChipContentEndExitsTrailingEdge() throws {
        let text = "Run [/table](host-app://commands/table) today"
        let textView = try mountedTextView(for: text)
        let linkRange = try XCTUnwrap(inlineLinkRange(in: text))
        textView.setSelectedRange(NSRange(location: NSMaxRange(linkRange.contentRange), length: 0))

        textView.doCommand(by: #selector(NSResponder.moveRight(_:)))

        XCTAssertEqual(textView.selectedRange(), NSRange(location: NSMaxRange(linkRange.fullRange), length: 0))
        XCTAssertEqual(textView.selectionAffinity, .downstream)
        try assertCaret(in: textView, isAtTrailingEdgeOfChipFor: linkRange)
    }

    func testPlainHorizontalMovementInsideFileLinkChipUsesNativeMovement() throws {
        let text = "Open [README.md](file:///tmp/README.md) trailing"
        let textView = try mountedTextView(for: text)
        let linkRange = try XCTUnwrap(inlineLinkRange(in: text))

        textView.setSelectedRange(NSRange(location: linkRange.contentRange.location + 1, length: 0))
        textView.keyDown(with: try plainLeftEvent())
        XCTAssertEqual(textView.selectedRange(), NSRange(location: linkRange.contentRange.location, length: 0))

        textView.setSelectedRange(NSRange(location: NSMaxRange(linkRange.contentRange) - 2, length: 0))
        textView.keyDown(with: try plainRightEvent())
        XCTAssertEqual(textView.selectedRange(), NSRange(location: NSMaxRange(linkRange.contentRange) - 1, length: 0))
    }

    func testPlainLeftAtRawSlashCommandChipUsesNativeMovement() throws {
        let text = "Run /table today"
        let textView = try mountedTextView(
            configuration: BlockInputConfiguration(
                document: BlockInputDocument(blocks: [
                    BlockInputBlock(id: "paragraph", kind: .paragraph, text: text)
                ]),
                rawSlashCommandChips: true,
                slashCommandAvailability: .anywhere
            )
        )
        let slashOffset = contentLocation("/table", in: text)
        textView.setSelectedRange(NSRange(location: slashOffset, length: 0))

        textView.keyDown(with: try plainLeftEvent())

        XCTAssertEqual(textView.selectedRange(), NSRange(location: slashOffset - 1, length: 0))
    }

    private func mountedTextView(for text: String) throws -> BlockInputTextView {
        try mountedTextView(
            configuration: BlockInputConfiguration(document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "paragraph", kind: .paragraph, text: text)
            ]))
        )
    }

    private func mountedTextView(configuration: BlockInputConfiguration) throws -> BlockInputTextView {
        let mounted = makeMountedBlockInputView(configuration: configuration)
        resizeMountedBlockInputView(mounted, to: NSSize(width: 620, height: 140))
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        mounted.window.makeFirstResponder(textView)
        textView.layoutManager?.ensureLayout(for: try XCTUnwrap(textView.textContainer))
        return textView
    }

    private func inlineLinkRange(in text: String) -> BlockInputInlineMarkdownRange? {
        BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: text,
            excluding: BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        )
        .first { $0.style == .link }
    }

    private func contentLocation(_ content: String, in text: String) -> Int {
        (text as NSString).range(of: content).location
    }

    private func assertCaret(
        in textView: BlockInputTextView,
        isAtLeadingEdgeOfChipFor range: BlockInputInlineMarkdownRange,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let caretRect = try caretRect(in: textView)
        let chipRect = try chipRect(in: textView, for: range)
        XCTAssertLessThanOrEqual(caretRect.minX, chipRect.minX + 3, file: file, line: line)
        XCTAssertLessThan(caretRect.minX, chipRect.midX, file: file, line: line)
    }

    private func assertCaret(
        in textView: BlockInputTextView,
        isAtTrailingEdgeOfChipFor range: BlockInputInlineMarkdownRange,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let caretRect = try caretRect(in: textView)
        let chipRect = try chipRect(in: textView, for: range)
        XCTAssertGreaterThanOrEqual(caretRect.minX, chipRect.maxX - 3, file: file, line: line)
        XCTAssertGreaterThan(caretRect.minX, chipRect.midX, file: file, line: line)
    }

    private func caretRect(in textView: BlockInputTextView) throws -> NSRect {
        let screenRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
        guard screenRect != .zero, !screenRect.isNull, !screenRect.isInfinite else {
            return try XCTUnwrap(Optional<NSRect>.none)
        }
        let window = try XCTUnwrap(textView.window)
        let windowPoint = window.convertPoint(fromScreen: screenRect.origin)
        return NSRect(origin: textView.convert(windowPoint, from: nil), size: screenRect.size)
    }

    private func chipRect(in textView: BlockInputTextView, for range: BlockInputInlineMarkdownRange) throws -> NSRect {
        let layoutManager = try XCTUnwrap(textView.layoutManager)
        let textContainer = try XCTUnwrap(textView.textContainer)
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range.contentRange, actualCharacterRange: nil)
        let contentRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            .offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
        return try XCTUnwrap(textView.inlineChipBackgroundRectsForTesting().first { $0.intersects(contentRect) })
    }
}
