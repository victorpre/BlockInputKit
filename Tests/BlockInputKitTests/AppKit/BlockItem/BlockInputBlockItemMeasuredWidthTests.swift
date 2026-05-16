import XCTest
@testable import BlockInputKit

final class BlockInputBlockItemMeasuredWidthTests: XCTestCase {
    @MainActor
    func testMeasuredTextWidthMatchesMountedScrollWidthForRowsWithChrome() throws {
        for allowsReordering in [true, false] {
            for block in Self.wrappingBlocks {
                let item = configuredItem(block: block, allowsReordering: allowsReordering)
                let scrollView = try XCTUnwrap(item.testingTextScrollView)
                let expectedScrollWidth = BlockInputBlockItem.textScrollViewWidth(
                    for: item.view.bounds.width,
                    block: block,
                    allowsReordering: allowsReordering
                )
                let expectedMeasuredWidth = expectedScrollWidth - 2 * BlockInputBlockItem.textContainerLineFragmentPadding

                XCTAssertEqual(scrollView.frame.width, expectedScrollWidth, accuracy: 0.5, "\(block.kind)")
                XCTAssertEqual(
                    BlockInputBlockItem.measuredTextWidth(
                        for: item.view.bounds.width,
                        block: block,
                        allowsReordering: allowsReordering
                    ),
                    expectedMeasuredWidth,
                    accuracy: 0.5,
                    "\(block.kind)"
                )
            }
        }
    }

    @MainActor
    func testMeasuredTextWidthMatchesMountedTextContainerLineFragmentWidth() throws {
        for allowsReordering in [true, false] {
            for block in Self.wrappingBlocks {
                let item = configuredItem(block: block, allowsReordering: allowsReordering)
                let textView = try XCTUnwrap(item.testingTextView)
                let textContainer = try XCTUnwrap(textView.textContainer)
                let mountedLineFragmentWidth = max(
                    textContainer.containerSize.width - 2 * textContainer.lineFragmentPadding,
                    120
                )

                XCTAssertEqual(
                    BlockInputBlockItem.measuredTextWidth(
                        for: item.view.bounds.width,
                        block: block,
                        allowsReordering: allowsReordering
                    ),
                    mountedLineFragmentWidth,
                    accuracy: 0.5,
                    "\(block.kind)"
                )
            }
        }
    }

    private static let wrappingBlocks = [
        BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
        BlockInputBlock(id: "bullet", kind: .bulletedListItem, text: "Bullet"),
        BlockInputBlock(id: "indentedBullet", kind: .bulletedListItem, text: "Indented", indentationLevel: 2),
        BlockInputBlock(id: "checklist", kind: .checklistItem(isChecked: false), text: "Task"),
        BlockInputBlock(id: "quote", kind: .quote, text: "Quoted")
    ]

    @MainActor
    private func configuredItem(
        block: BlockInputBlock,
        allowsReordering: Bool
    ) -> BlockInputBlockItem {
        let item = BlockInputBlockItem.configuredForTesting(
            block: block,
            allowsReordering: allowsReordering,
            delegate: BlockInputView()
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 420, height: 60)
        item.view.layoutSubtreeIfNeeded()
        return item
    }
}
