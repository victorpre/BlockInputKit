import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputTableStoreMutationTests: XCTestCase {
    func testStoreBackedTableRowAndColumnMutationsPublishReplaceBlockOnly() throws {
        let store = CountingDocumentStore(document: BlockInputDocument(blocks: [
            Self.tableBlock(bodyRows: [["one", "two"], ["three", "four"]])
        ]))
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(documentStore: store))

        store.resetCounts()
        XCTAssertTrue(mounted.view.appendTableBodyRow(blockID: "table"))
        assertReplaceBlockOnly(store)

        store.resetCounts()
        XCTAssertTrue(mounted.view.appendTableColumn(blockID: "table"))
        assertReplaceBlockOnly(store)

        store.resetCounts()
        XCTAssertTrue(mounted.view.deleteTableBodyRow(
            blockID: "table",
            position: .init(row: .body(0), column: 0),
            keepsLastBodyRow: true
        ))
        assertReplaceBlockOnly(store)

        store.resetCounts()
        XCTAssertTrue(mounted.view.deleteTableColumn(
            blockID: "table",
            position: .init(row: .body(0), column: 1)
        ))
        assertReplaceBlockOnly(store)
    }

    func testTableRowAndColumnMutationsRegisterStructuralUndo() throws {
        let undoController = BlockInputUndoController()
        let mounted = makeMountedBlockInputView(
            document: BlockInputDocument(blocks: [
                Self.tableBlock(bodyRows: [["one", "two"], ["three", "four"]])
            ]),
            undoController: undoController
        )

        XCTAssertTrue(mounted.view.appendTableBodyRow(blockID: "table"))
        var table = try XCTUnwrap(BlockInputTable(markdown: mounted.view.document.blocks[0].text))
        XCTAssertEqual(table.bodyRows.count, 3)

        let appendUndo = mounted.view.undoStructuralEdit()
        XCTAssertEqual(appendUndo?.actionName, "Append Row")
        table = try XCTUnwrap(BlockInputTable(markdown: mounted.view.document.blocks[0].text))
        XCTAssertEqual(table.bodyRows.count, 2)

        XCTAssertTrue(mounted.view.deleteTableColumn(
            blockID: "table",
            position: .init(row: .body(0), column: 1)
        ))
        table = try XCTUnwrap(BlockInputTable(markdown: mounted.view.document.blocks[0].text))
        XCTAssertEqual(table.columnCount, 1)

        let deleteUndo = mounted.view.undoStructuralEdit()
        XCTAssertEqual(deleteUndo?.actionName, "Delete Column")
        table = try XCTUnwrap(BlockInputTable(markdown: mounted.view.document.blocks[0].text))
        XCTAssertEqual(table.columnCount, 2)
    }

    private func assertReplaceBlockOnly(_ store: CountingDocumentStore) {
        XCTAssertEqual(store.replaceDocumentCount, 0)
        XCTAssertEqual(store.replaceBlockIDs, ["table"])
        XCTAssertTrue(store.insertedBlockBatches.isEmpty)
        XCTAssertTrue(store.deletedBlockIDs.isEmpty)
    }

    private static func tableBlock(bodyRows: [[String]]) -> BlockInputBlock {
        BlockInputBlock(
            id: "table",
            kind: .table,
            text: BlockInputTable.normalized(
                header: ["H1", "H2"],
                bodyRows: bodyRows,
                alignments: [.left, .left]
            ).markdown
        )
    }
}
