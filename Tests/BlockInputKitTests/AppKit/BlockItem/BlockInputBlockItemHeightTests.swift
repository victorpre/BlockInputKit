import XCTest
@testable import BlockInputKit

final class BlockInputBlockItemHeightTests: XCTestCase {
    @MainActor
    func testListHeightAccountsForIndentedTextWidth() {
        let text = Array(repeating: "Wrapped list content", count: 8).joined(separator: " ")
        let itemWidth: CGFloat = 260
        let rootBlock = BlockInputBlock(kind: .bulletedListItem, text: text)
        let indentedBlock = BlockInputBlock(kind: .bulletedListItem, text: text, indentationLevel: 3)
        let rootTextWidth = BlockInputBlockItem.measuredTextWidth(
            for: itemWidth,
            block: rootBlock,
            allowsReordering: true
        )
        let indentedTextWidth = BlockInputBlockItem.measuredTextWidth(
            for: itemWidth,
            block: indentedBlock,
            allowsReordering: true
        )
        let rootHeight = BlockInputBlockItem.height(for: rootBlock, textWidth: rootTextWidth)
        let indentedHeight = BlockInputBlockItem.height(for: indentedBlock, textWidth: indentedTextWidth)

        XCTAssertGreaterThan(indentedHeight, rootHeight)
    }

    @MainActor
    func testListHeightAccountsForPerLineIndentedTextWidth() {
        let text = "Short\n" + Array(repeating: "Wrapped list content", count: 12).joined(separator: " ")
        let itemWidth: CGFloat = 320
        let rootBlock = BlockInputBlock(kind: .bulletedListItem, text: text)
        let indentedBlock = BlockInputBlock(
            kind: .bulletedListItem,
            text: text,
            lineIndentationLevels: [0, 3, 1]
        )
        let rootTextWidth = BlockInputBlockItem.measuredTextWidth(
            for: itemWidth,
            block: rootBlock,
            allowsReordering: true
        )
        let indentedTextWidth = BlockInputBlockItem.measuredTextWidth(
            for: itemWidth,
            block: indentedBlock,
            allowsReordering: true
        )
        let rootHeight = BlockInputBlockItem.height(for: rootBlock, textWidth: rootTextWidth)
        let indentedHeight = BlockInputBlockItem.height(for: indentedBlock, textWidth: indentedTextWidth)

        XCTAssertGreaterThan(indentedHeight, rootHeight)
    }
}
