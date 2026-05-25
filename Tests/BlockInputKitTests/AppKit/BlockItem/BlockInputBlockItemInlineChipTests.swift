import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputBlockItemInlineChipTests: XCTestCase {
    func testInlineMarkdownRendersFileLinksAsChipsWhenSelectionIsOutsideSource() throws {
        let text = "Open [../README.md](<file:///tmp/README.md>) today"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textStorage = try XCTUnwrap(item.testingTextView?.textStorage)
        let contentOffset = contentLocation("../README.md", in: text)

        XCTAssertEqual((textStorage.attribute(.link, at: contentOffset, effectiveRange: nil) as? URL)?.absoluteString, "file:///tmp/README.md")
        XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor, .clear)
        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: 19, effectiveRange: nil) as? NSColor, .clear)
    }

    func testFileLinkChipAddsSpacingToAdjacentWhitespaceOnly() throws {
        let text = "Open [../README.md](<file:///tmp/README.md>) today"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textStorage = try XCTUnwrap(item.testingTextView?.textStorage)
        let openingBracketOffset = (text as NSString).range(of: "[").location
        let leadingSpaceOffset = openingBracketOffset - 1
        let destinationOffset = (text as NSString).range(of: "file:///tmp").location
        let closingParenthesisOffset = (text as NSString).range(of: ") today").location
        let trailingSpaceOffset = closingParenthesisOffset + 1

        XCTAssertEqual(textStorage.attribute(.kern, at: leadingSpaceOffset, effectiveRange: nil) as? CGFloat, 5)
        XCTAssertEqual(textStorage.attribute(.kern, at: trailingSpaceOffset, effectiveRange: nil) as? CGFloat, 5)
        XCTAssertNil(textStorage.attribute(.kern, at: openingBracketOffset, effectiveRange: nil))
        XCTAssertNil(textStorage.attribute(.kern, at: destinationOffset, effectiveRange: nil))
        XCTAssertNil(textStorage.attribute(.kern, at: closingParenthesisOffset, effectiveRange: nil))
    }

    func testSlashCommandLinkRendersAsReusableChip() throws {
        let text = "Run [/table](host-app://commands/table) today"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let textStorage = try XCTUnwrap(item.testingTextView?.textStorage)
        let contentOffset = contentLocation("/table", in: text)
        let openingBracketOffset = (text as NSString).range(of: "[").location
        let trailingSpaceOffset = (text as NSString).range(of: ") today").location + 1

        XCTAssertEqual(
            (textStorage.attribute(.link, at: contentOffset, effectiveRange: nil) as? URL)?.absoluteString,
            "host-app://commands/table"
        )
        XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: openingBracketOffset, effectiveRange: nil) as? NSColor, .clear)
        XCTAssertEqual(textStorage.attribute(.kern, at: trailingSpaceOffset, effectiveRange: nil) as? CGFloat, 5)
    }

    func testRawSlashCommandRendersAsVisualOnlyChipWhenEnabled() throws {
        let text = "Run /table today"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            rawSlashCommandChips: true,
            slashCommandAvailability: .anywhere,
            delegate: BlockInputView()
        )
        let textStorage = try XCTUnwrap(item.testingTextView?.textStorage)
        let contentOffset = contentLocation("/table", in: text)

        XCTAssertNil(textStorage.attribute(.link, at: contentOffset, effectiveRange: nil))
        XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
        XCTAssertNil(textStorage.attribute(.blockInputHiddenDelimiter, at: contentOffset, effectiveRange: nil))
        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
    }

    func testRawSlashCommandDoesNotRenderAsChipByDefault() throws {
        let text = "Run /table today"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            rawSlashCommandChips: false,
            slashCommandAvailability: .anywhere,
            delegate: BlockInputView()
        )
        let textStorage = try XCTUnwrap(item.testingTextView?.textStorage)
        let contentOffset = contentLocation("/table", in: text)

        XCTAssertFalse(try font(at: contentOffset, in: textStorage).isFixedPitch)
    }

    func testRawAndLinkBackedSlashCommandChipsCoexist() throws {
        let text = "/review [/table](host-app://commands/table)"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            rawSlashCommandChips: true,
            slashCommandAvailability: .documentStart,
            isDocumentStartBlock: true,
            delegate: BlockInputView()
        )
        let textStorage = try XCTUnwrap(item.testingTextView?.textStorage)
        let rawOffset = contentLocation("/review", in: text)
        let linkOffset = contentLocation("/table", in: text)

        XCTAssertNil(textStorage.attribute(.link, at: rawOffset, effectiveRange: nil))
        XCTAssertTrue(try font(at: rawOffset, in: textStorage).isFixedPitch)
        XCTAssertEqual(
            (textStorage.attribute(.link, at: linkOffset, effectiveRange: nil) as? URL)?.absoluteString,
            "host-app://commands/table"
        )
        XCTAssertTrue(try font(at: linkOffset, in: textStorage).isFixedPitch)
    }

    func testRawSlashCommandChipPreservesAccessibilityText() throws {
        let text = "/table"
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: text),
            allowsReordering: true,
            rawSlashCommandChips: true,
            delegate: BlockInputView()
        )
        let textView = try XCTUnwrap(item.testingTextView)

        XCTAssertEqual(textView.accessibilityValue(), text)
        XCTAssertEqual(textView.string, text)
    }

    func testRawSlashCommandDoesNotRenderAsChipInsideTables() throws {
        let table = BlockInputBlock(id: "table", kind: .table, text: """
        | Command |
        | --- |
        | /table |
        """)
        let item = BlockInputBlockItem.configuredForTesting(
            block: table,
            allowsReordering: true,
            rawSlashCommandChips: true,
            slashCommandAvailability: .anywhere,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 480, height: BlockInputBlockItem.height(for: table, textWidth: 420))
        item.view.layoutSubtreeIfNeeded()
        let cell = try XCTUnwrap(item.testingTableCellTextViews.first { $0.string == "/table" })
        let textStorage = try XCTUnwrap(cell.textStorage)

        XCTAssertFalse(try font(at: 0, in: textStorage).isFixedPitch)
    }

    func testRawSlashCommandDoesNotRenderAsChipInUnsupportedBlockKinds() throws {
        let cases: [(BlockInputBlockKind, String)] = [
            (.code(language: nil), "/table"),
            (.frontMatter, "command: /table"),
            (.rawMarkdown, "/table")
        ]
        for (kind, text) in cases {
            let item = BlockInputBlockItem.configuredForTesting(
                block: BlockInputBlock(id: BlockInputBlockID(rawValue: String(describing: kind)), kind: kind, text: text),
                allowsReordering: true,
                rawSlashCommandChips: true,
                slashCommandAvailability: .anywhere,
                delegate: BlockInputView()
            )
            let textView = try XCTUnwrap(item.testingTextView)
            let textStorage = try XCTUnwrap(textView.textStorage)
            let offset = contentLocation("/table", in: textView.string)

            XCTAssertNil(textStorage.attribute(.blockInputInlineChip, at: offset, effectiveRange: nil))
        }
    }

    func testFileLinkChipStaysVisibleWhenCaretIsInsideSource() throws {
        let text = "[README.md](file:///tmp/README.md) trailing"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "paragraph", kind: .paragraph, text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let contentOffset = contentLocation("README.md", in: text)
        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: contentOffset, length: 0))
        item.updateSelectionDependentAttributesForCurrentSelection()
        let textStorage = try XCTUnwrap(textView.textStorage)

        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
        XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
    }

    func testFileLinkChipStaysVisibleWhenSelectionOverlapsSource() throws {
        let text = "[README.md](file:///tmp/README.md) trailing"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "paragraph", kind: .paragraph, text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let contentOffset = contentLocation("README.md", in: text)

        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: contentOffset, length: 4))
        item.updateSelectionDependentAttributesForCurrentSelection()
        let textStorage = try XCTUnwrap(textView.textStorage)

        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
        XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
    }

    func testFileLinkChipStaysVisibleAtSourceBoundaries() throws {
        let text = "[README.md](file:///tmp/README.md) trailing"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "paragraph", kind: .paragraph, text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let contentOffset = contentLocation("README.md", in: text)
        let fullRange = (text as NSString).range(of: "[README.md](file:///tmp/README.md)")
        let textStorage = try XCTUnwrap(textView.textStorage)

        mounted.window.makeFirstResponder(textView)
        for caretOffset in [fullRange.location, NSMaxRange(fullRange)] {
            textView.setSelectedRange(NSRange(location: caretOffset, length: 0))
            item.updateSelectionDependentAttributesForCurrentSelection()

            XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
            XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
            XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
        }
    }

    func testRegularLinkKeepsNormalLinkStyle() throws {
        let text = "[README.md](https://example.com/README.md) trailing"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "paragraph", kind: .paragraph, text: text)
        ])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        let contentOffset = contentLocation("README.md", in: text)

        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: contentOffset, length: 0))
        item.updateSelectionDependentAttributesForCurrentSelection()
        let textStorage = try XCTUnwrap(textView.textStorage)

        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .linkColor)
        XCTAssertEqual(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertFalse(try font(at: contentOffset, in: textStorage).isFixedPitch)
    }

    private func font(at location: Int, in textStorage: NSTextStorage) throws -> NSFont {
        try XCTUnwrap(textStorage.attribute(.font, at: location, effectiveRange: nil) as? NSFont)
    }

    private func contentLocation(_ content: String, in text: String) -> Int {
        (text as NSString).range(of: content).location
    }
}
