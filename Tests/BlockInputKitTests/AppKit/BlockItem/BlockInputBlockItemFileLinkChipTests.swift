import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputBlockItemFileLinkChipTests: XCTestCase {
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

    func testFileLinkChipBacksOffWhenSelectionIsInsideSource() throws {
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

        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .linkColor)
        XCTAssertEqual(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
    }

    func testFileLinkChipReturnsWhenFocusMovesToAnotherBlock() throws {
        let text = "[README.md](file:///tmp/README.md) trailing"
        let mounted = makeMountedBlockInputView(blocks: [
            BlockInputBlock(id: "first", text: text),
            BlockInputBlock(id: "second", text: "Next block")
        ])
        let firstItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let secondItem = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 1))
        let firstTextView = try XCTUnwrap(firstItem.testingTextView)
        let secondTextView = try XCTUnwrap(secondItem.testingTextView)
        let contentOffset = contentLocation("README.md", in: text)

        mounted.window.makeFirstResponder(firstTextView)
        firstTextView.setSelectedRange(NSRange(location: contentOffset, length: 0))
        firstItem.updateSelectionDependentAttributesForCurrentSelection()
        let textStorage = try XCTUnwrap(firstTextView.textStorage)

        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .linkColor)
        XCTAssertEqual(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)

        mounted.window.makeFirstResponder(secondTextView)
        secondTextView.setSelectedRange(NSRange(location: 0, length: 0))

        XCTAssertEqual(textStorage.attribute(.foregroundColor, at: contentOffset, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertNil(textStorage.attribute(.underlineStyle, at: contentOffset, effectiveRange: nil))
        XCTAssertTrue(try font(at: contentOffset, in: textStorage).isFixedPitch)
    }

    private func font(at location: Int, in textStorage: NSTextStorage) throws -> NSFont {
        try XCTUnwrap(textStorage.attribute(.font, at: location, effectiveRange: nil) as? NSFont)
    }

    private func contentLocation(_ content: String, in text: String) -> Int {
        (text as NSString).range(of: content).location
    }
}
