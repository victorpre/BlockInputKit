import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTableCellInlineMarkdownTests: XCTestCase {
    func testTypingInlineMarkdownInTableCellRefreshesVisibleAttributes() throws {
        let mounted = makeMountedBlockInputView(blocks: [Self.tableBlock()])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item)
        XCTAssertTrue(mounted.window.makeFirstResponder(cell))

        cell.setSelectedRange(NSRange(location: 0, length: 3))
        cell.insertText("**one**", replacementRange: cell.selectedRange())

        let textStorage = try XCTUnwrap(cell.textStorage)
        XCTAssertEqual(textStorage.attribute(.blockInputHiddenDelimiter, at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(textStorage.attribute(.blockInputHiddenDelimiter, at: 1, effectiveRange: nil) as? Bool, true)
        XCTAssertNil(textStorage.attribute(.blockInputHiddenDelimiter, at: 2, effectiveRange: nil))
        let font = try XCTUnwrap(textStorage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    private func bodyCell(in item: BlockInputBlockItem) throws -> BlockInputTableCellTextView {
        try XCTUnwrap(item.testingTableCellTextViews.indices.contains(2) ? item.testingTableCellTextViews[2] : nil)
    }

    private static func tableBlock() -> BlockInputBlock {
        BlockInputBlock(
            id: "table",
            kind: .table,
            text: BlockInputTable.normalized(
                header: ["H1", "H2"],
                bodyRows: [["one", "two"]],
                alignments: [.left, .left]
            ).markdown
        )
    }
}
