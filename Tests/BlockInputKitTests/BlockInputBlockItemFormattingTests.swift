import XCTest
@testable import BlockInputKit

final class BlockInputBlockItemFormattingTests: XCTestCase {
    @MainActor
    func testPrefixReflectsBlockKindAndIndentation() {
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .paragraph, indentationLevel: 2), "")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .code(language: nil), indentationLevel: 1), " {}")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .quote, indentationLevel: 2), "  >")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .bulletedListItem, indentationLevel: 1), " -")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .numberedListItem(start: 3), indentationLevel: 1), " 3.")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .checklistItem(isChecked: false), indentationLevel: 1), " [ ]")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .checklistItem(isChecked: true), indentationLevel: 1), " [x]")
    }

    @MainActor
    func testHeightUsesMinimumForEmptyBlocks() {
        let height = BlockInputBlockItem.height(for: .emptyParagraph(), textWidth: 240)

        XCTAssertGreaterThanOrEqual(height, 34)
    }
}
