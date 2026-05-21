import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTableCellEditingTests: XCTestCase {
    func testMountedCellEditingUpdatesTableMarkdownAndSourceSelection() throws {
        let mounted = makeMountedBlockInputView(blocks: [Self.tableBlock()])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item, row: 0, column: 0)
        XCTAssertTrue(mounted.window.makeFirstResponder(cell))

        cell.setSelectedRange(NSRange(location: 3, length: 0))
        cell.insertText("X", replacementRange: cell.selectedRange())

        let expectedTable = BlockInputTable.normalized(
            header: ["H1", "H2"],
            bodyRows: [["oneX", "two"]],
            alignments: [.left, .left]
        )
        XCTAssertEqual(mounted.view.document.blocks[0].text, expectedTable.markdown)
        XCTAssertEqual(
            mounted.view.selection,
            expectedTable.selection(blockID: "table", position: .init(row: .body(0), column: 0), localRange: NSRange(location: 4, length: 0))
        )
        XCTAssertTrue(mounted.window.firstResponder === cell)
        XCTAssertTrue(item.testingTableCellTextViews.contains { $0 === cell })
    }

    func testFormattingShortcutAppliesInsideTableCellThroughSharedMutationPath() throws {
        let mounted = makeMountedBlockInputView(blocks: [Self.tableBlock()])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item, row: 0, column: 0)
        XCTAssertTrue(mounted.window.makeFirstResponder(cell))

        cell.setSelectedRange(NSRange(location: 0, length: 3))
        XCTAssertTrue(cell.performKeyEquivalent(with: try commandBEvent()))

        let expectedTable = BlockInputTable.normalized(
            header: ["H1", "H2"],
            bodyRows: [["**one**", "two"]],
            alignments: [.left, .left]
        )
        XCTAssertEqual(mounted.view.document.blocks[0].text, expectedTable.markdown)
        XCTAssertEqual(
            mounted.view.selection,
            expectedTable.selection(blockID: "table", position: .init(row: .body(0), column: 0), localRange: NSRange(location: 2, length: 3))
        )
    }

    func testURLPasteInTableCellUsesSharedLinkMutationPath() throws {
        let mounted = makeMountedBlockInputView(blocks: [Self.tableBlock()])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item, row: 0, column: 0)
        XCTAssertTrue(mounted.window.makeFirstResponder(cell))
        cell.setSelectedRange(NSRange(location: 0, length: 3))

        withCleanPasteboard { pasteboard in
            pasteboard.setString("https://example.com", forType: .string)
            cell.paste(nil)
        }

        let expectedTable = BlockInputTable.normalized(
            header: ["H1", "H2"],
            bodyRows: [["[one](https://example.com)", "two"]],
            alignments: [.left, .left]
        )
        XCTAssertEqual(mounted.view.document.blocks[0].text, expectedTable.markdown)
    }

    func testStoreBackedCellEditPublishesReplaceBlockOnly() throws {
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [Self.tableBlock()]))
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(documentStore: store))
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item, row: 0, column: 0)
        XCTAssertTrue(mounted.window.makeFirstResponder(cell))
        store.resetCounts()

        cell.setSelectedRange(NSRange(location: 3, length: 0))
        cell.insertText("X", replacementRange: cell.selectedRange())

        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, ["table"])
        XCTAssertEqual(store.document.blocks[0].text, mounted.view.document.blocks[0].text)
    }

    func testCellTextUndoRestoresTableBlock() throws {
        let undoController = BlockInputUndoController()
        let mounted = makeMountedBlockInputView(
            document: BlockInputDocument(blocks: [Self.tableBlock()]),
            undoController: undoController
        )
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item, row: 0, column: 0)
        XCTAssertTrue(mounted.window.makeFirstResponder(cell))
        let beforeText = mounted.view.document.blocks[0].text

        cell.setSelectedRange(NSRange(location: 3, length: 0))
        cell.insertText("X", replacementRange: cell.selectedRange())
        XCTAssertTrue(cell.performKeyEquivalent(with: try commandZEvent()))

        XCTAssertEqual(mounted.view.document.blocks[0].text, beforeText)
    }

    func testTableCellsUseNativeMouseSelectionInsteadOfBlockDragTracking() throws {
        let mounted = makeMountedBlockInputView(blocks: [Self.tableBlock()])
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let cell = try bodyCell(in: item, row: 0, column: 0)

        XCTAssertFalse(cell.shouldTrackBlockSelectionDrag(for: try mouseDownEvent(windowNumber: mounted.window.windowNumber)))
    }

    private func bodyCell(in item: BlockInputBlockItem, row: Int, column: Int) throws -> BlockInputTableCellTextView {
        let index = 2 + (row * 2) + column
        return try XCTUnwrap(item.testingTableCellTextViews[safe: index])
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

private extension BlockInputTable {
    func selection(
        blockID: BlockInputBlockID,
        position: BlockInputTable.CellPosition,
        localRange: NSRange
    ) -> BlockInputSelection? {
        guard let sourceRange = sourceRange(forLocalRange: localRange, in: position) else {
            return nil
        }
        if sourceRange.length == 0 {
            return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: sourceRange.location))
        }
        return .text(BlockInputTextRange(blockID: blockID, range: sourceRange))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private func withCleanPasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    defer { pasteboard.clearContents() }
    try body(pasteboard)
}
