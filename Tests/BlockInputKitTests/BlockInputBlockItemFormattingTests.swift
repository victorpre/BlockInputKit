import XCTest
@testable import BlockInputKit

final class BlockInputBlockItemFormattingTests: XCTestCase {
    @MainActor
    func testPrefixReflectsBlockKindAndIndentation() {
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .paragraph, indentationLevel: 2), "")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .heading(level: 3), indentationLevel: 0), "###")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .code(language: nil), indentationLevel: 1), " {}")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .horizontalRule, indentationLevel: 0), "")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .quote, indentationLevel: 2), "  >")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .bulletedListItem, indentationLevel: 1), " *")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .bulletedListItem, indentationLevel: 2), "  +")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .numberedListItem(start: 3), indentationLevel: 1), " c.")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .numberedListItem(start: 3), indentationLevel: 2), "  iii.")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .checklistItem(isChecked: false), indentationLevel: 1), " [ ]")
        XCTAssertEqual(BlockInputBlockItem.prefix(for: .checklistItem(isChecked: true), indentationLevel: 1), " [x]")
    }

    @MainActor
    func testHeightUsesMinimumForEmptyBlocks() {
        let height = BlockInputBlockItem.height(for: .emptyParagraph(), textWidth: 240)

        XCTAssertGreaterThanOrEqual(height, 34)
    }

    @MainActor
    func testChecklistButtonReflectsBlockState() throws {
        let blockID = BlockInputBlockID(rawValue: "check")
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: true), text: "Done"),
            allowsReordering: true,
            delegate: view
        )

        let checkbox = try XCTUnwrap(item.testingChecklistButton)
        XCTAssertFalse(checkbox.isHidden)
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertEqual(checkbox.accessibilityLabel(), "Toggle checklist item")
    }

    @MainActor
    func testChecklistButtonIsHiddenForNonChecklistBlocks() throws {
        let blockID = BlockInputBlockID(rawValue: "paragraph")
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: blockID, kind: .paragraph, text: "Plain"),
            allowsReordering: true,
            delegate: view
        )

        let checkbox = try XCTUnwrap(item.testingChecklistButton)
        XCTAssertTrue(checkbox.isHidden)
        XCTAssertEqual(checkbox.state, .off)
    }

    @MainActor
    func testHorizontalRuleUsesNonEditableEmptyTextView() throws {
        let blockID = BlockInputBlockID(rawValue: "rule")
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: blockID, kind: .horizontalRule, text: "Hidden"),
            allowsReordering: true,
            delegate: view
        )

        let textView = try XCTUnwrap(item.testingTextView)
        XCTAssertEqual(textView.string, "")
        XCTAssertFalse(textView.isEditable)
        XCTAssertTrue(try XCTUnwrap(item.testingTextScrollView).isHidden)
        XCTAssertFalse(try XCTUnwrap(item.testingHorizontalRuleView).isHidden)
    }

    @MainActor
    func testHorizontalRuleSelectionUsesAccentColor() throws {
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "rule", kind: .horizontalRule),
            allowsReordering: true,
            delegate: BlockInputView()
        )
        let ruleView = try XCTUnwrap(item.testingHorizontalRuleSelectionView)
        ruleView.accentColor = .systemPink

        item.setBlockSelection(true)

        XCTAssertEqual(ruleView.testingLineView?.layer?.backgroundColor, NSColor.systemPink.cgColor)
        XCTAssertEqual(ruleView.testingLineHeight, 3)
        XCTAssertNotEqual(ruleView.layer?.backgroundColor, NSColor.clear.cgColor)
    }

    @MainActor
    func testHorizontalRuleViewIsHiddenForTextBlocks() throws {
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "rule", kind: .horizontalRule),
            allowsReordering: true,
            delegate: view
        )

        item.configure(
            block: BlockInputBlock(id: "paragraph", text: "Plain"),
            allowsReordering: true,
            delegate: view
        )

        let ruleView = try XCTUnwrap(item.testingHorizontalRuleView)
        XCTAssertTrue(ruleView.isHidden)
        XCTAssertEqual(ruleView.alphaValue, 0)
        XCTAssertFalse(try XCTUnwrap(item.testingTextScrollView).isHidden)
    }

    @MainActor
    func testSelectedHorizontalRuleOverlayIsClearedWhenReconfiguredAsTextBlock() throws {
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "rule", kind: .horizontalRule),
            allowsReordering: true,
            delegate: view
        )
        item.setBlockSelection(true)

        item.configure(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            allowsReordering: true,
            isSelected: true,
            delegate: view
        )

        let ruleView = try XCTUnwrap(item.testingHorizontalRuleSelectionView)
        XCTAssertTrue(ruleView.isHidden)
        XCTAssertEqual(ruleView.alphaValue, 0)
        XCTAssertEqual(ruleView.testingLineHeight, 1)
        XCTAssertEqual(ruleView.testingLineView?.layer?.backgroundColor, NSColor.separatorColor.cgColor)
        XCTAssertEqual(ruleView.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertEqual(try XCTUnwrap(item.testingTextView).string, "Plain")
        XCTAssertFalse(try XCTUnwrap(item.testingTextScrollView).isHidden)
    }

    @MainActor
    func testChecklistButtonStateIsClearedWhenItemIsReconfigured() throws {
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "check", kind: .checklistItem(isChecked: true), text: "Done"),
            allowsReordering: true,
            delegate: view
        )

        item.configure(
            block: BlockInputBlock(id: "paragraph", kind: .paragraph, text: "Plain"),
            allowsReordering: true,
            delegate: view
        )

        let checkbox = try XCTUnwrap(item.testingChecklistButton)
        XCTAssertTrue(checkbox.isHidden)
        XCTAssertEqual(checkbox.state, .off)
    }

    @MainActor
    func testChecklistButtonReflectsIndentationWhenReconfigured() throws {
        let view = BlockInputView()
        let item = BlockInputBlockItem.configuredForTesting(
            block: BlockInputBlock(id: "check", kind: .checklistItem(isChecked: true), text: "Done"),
            allowsReordering: true,
            delegate: view
        )
        item.view.frame = NSRect(x: 0, y: 0, width: 320, height: 44)
        item.view.layoutSubtreeIfNeeded()
        let checkbox = try XCTUnwrap(item.testingChecklistButton)
        let initialMinX = checkbox.frame.minX

        item.configure(
            block: BlockInputBlock(
                id: "indented",
                kind: .checklistItem(isChecked: true),
                text: "Indented",
                indentationLevel: 2
            ),
            allowsReordering: true,
            delegate: view
        )
        item.view.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(checkbox.frame.minX, initialMinX)
    }
}
