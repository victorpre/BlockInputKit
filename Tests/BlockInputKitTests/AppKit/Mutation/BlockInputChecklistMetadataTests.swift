import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputChecklistMetadataTests: XCTestCase {
    private let testBlockID = BlockInputBlockID(rawValue: "test")

    private func makeView(
        whenDate: String? = nil,
        deadline: String? = nil,
        tags: [String] = [],
        isEditable: Bool = true
    ) -> BlockInputView {
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: testBlockID,
                    kind: .checklistItem(isChecked: false),
                    text: "Test item",
                    whenDate: whenDate,
                    deadline: deadline,
                    tags: tags
                )
            ]),
            isEditable: isEditable,
            undoController: undoController
        ))
        return view
    }

    // MARK: - setChecklistWhenDate

    func testSetWhenDate() {
        let view = makeView()
        let result = view.setChecklistWhenDate(blockID: testBlockID, dateString: "2026-06-15")
        XCTAssertTrue(result)
        XCTAssertEqual(view.document.blocks[0].whenDate, "2026-06-15")
    }

    func testSetWhenDateClearsExisting() {
        let view = makeView(whenDate: "2026-06-15")
        let result = view.setChecklistWhenDate(blockID: testBlockID, dateString: nil)
        XCTAssertTrue(result)
        XCTAssertNil(view.document.blocks[0].whenDate)
    }

    func testSetWhenDateFailsOnNonChecklist() {
        let blockID = BlockInputBlockID(rawValue: "para")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .paragraph, text: "Text")
            ])
        ))
        let result = view.setChecklistWhenDate(blockID: blockID, dateString: "2026-06-15")
        XCTAssertFalse(result)
    }

    func testSetWhenDateFailsWhenNotEditable() {
        let view = makeView(isEditable: false)
        let result = view.setChecklistWhenDate(blockID: testBlockID, dateString: "2026-06-15")
        XCTAssertFalse(result)
    }

    func testSetWhenDateUndoRestoresPreviousValue() {
        let view = makeView(whenDate: "2026-06-15")
        let result = view.setChecklistWhenDate(blockID: testBlockID, dateString: nil)
        XCTAssertTrue(result)
        XCTAssertNil(view.document.blocks[0].whenDate)

        let undo = view.undoStructuralEdit()
        XCTAssertNotNil(undo)
        XCTAssertEqual(view.document.blocks[0].whenDate, "2026-06-15")
    }

    // MARK: - setChecklistDeadline

    func testSetDeadline() {
        let view = makeView()
        let result = view.setChecklistDeadline(blockID: testBlockID, dateString: "2026-06-20")
        XCTAssertTrue(result)
        XCTAssertEqual(view.document.blocks[0].deadline, "2026-06-20")
    }

    func testSetDeadlineClearsExisting() {
        let view = makeView(deadline: "2026-06-20")
        let result = view.setChecklistDeadline(blockID: testBlockID, dateString: nil)
        XCTAssertTrue(result)
        XCTAssertNil(view.document.blocks[0].deadline)
    }

    func testSetDeadlineUndoRestoresPreviousValue() {
        let view = makeView(deadline: "2026-06-20")
        let result = view.setChecklistDeadline(blockID: testBlockID, dateString: nil)
        XCTAssertTrue(result)
        XCTAssertNil(view.document.blocks[0].deadline)

        let undo = view.undoStructuralEdit()
        XCTAssertNotNil(undo)
        XCTAssertEqual(view.document.blocks[0].deadline, "2026-06-20")
    }

    // MARK: - addChecklistTag

    func testAddTag() {
        let view = makeView()
        let result = view.addChecklistTag(blockID: testBlockID, tag: "work")
        XCTAssertTrue(result)
        XCTAssertEqual(view.document.blocks[0].tags, ["work"])
    }

    func testAddDuplicateTagIgnored() {
        let view = makeView(tags: ["work"])
        let result = view.addChecklistTag(blockID: testBlockID, tag: "work")
        XCTAssertFalse(result)
        XCTAssertEqual(view.document.blocks[0].tags, ["work"])
    }

    func testAddEmptyTagReturnsFalse() {
        let view = makeView()
        let result = view.addChecklistTag(blockID: testBlockID, tag: "")
        XCTAssertFalse(result)
    }

    func testAddMultipleTags() {
        let view = makeView()
        XCTAssertTrue(view.addChecklistTag(blockID: testBlockID, tag: "work"))
        XCTAssertTrue(view.addChecklistTag(blockID: testBlockID, tag: "urgent"))
        XCTAssertTrue(view.addChecklistTag(blockID: testBlockID, tag: "project"))
        XCTAssertEqual(view.document.blocks[0].tags, ["work", "urgent", "project"])
    }

    func testAddTagUndoRestoresPreviousTags() {
        let view = makeView(tags: ["work"])
        let result = view.addChecklistTag(blockID: testBlockID, tag: "urgent")
        XCTAssertTrue(result)
        XCTAssertEqual(view.document.blocks[0].tags, ["work", "urgent"])

        let undo = view.undoStructuralEdit()
        XCTAssertNotNil(undo)
        XCTAssertEqual(view.document.blocks[0].tags, ["work"])
    }

    // MARK: - removeChecklistTag

    func testRemoveTag() {
        let view = makeView(tags: ["work", "urgent"])
        let result = view.removeChecklistTag(blockID: testBlockID, tag: "work")
        XCTAssertTrue(result)
        XCTAssertEqual(view.document.blocks[0].tags, ["urgent"])
    }

    func testRemoveNonExistentTagReturnsFalse() {
        let view = makeView(tags: ["work"])
        let result = view.removeChecklistTag(blockID: testBlockID, tag: "nonexistent")
        XCTAssertFalse(result)
        XCTAssertEqual(view.document.blocks[0].tags, ["work"])
    }

    func testRemoveEmptyTagReturnsFalse() {
        let view = makeView(tags: ["work"])
        let result = view.removeChecklistTag(blockID: testBlockID, tag: "")
        XCTAssertFalse(result)
    }

    func testRemoveTagUndoRestoresPreviousTags() {
        let view = makeView(tags: ["work", "urgent"])
        let result = view.removeChecklistTag(blockID: testBlockID, tag: "urgent")
        XCTAssertTrue(result)
        XCTAssertEqual(view.document.blocks[0].tags, ["work"])

        let undo = view.undoStructuralEdit()
        XCTAssertNotNil(undo)
        XCTAssertEqual(view.document.blocks[0].tags, ["work", "urgent"])
    }

    // MARK: - clearChecklistMetadata

    func testClearAllMetadata() {
        let view = makeView(whenDate: "2026-06-15", deadline: "2026-06-20", tags: ["work"])
        let result = view.clearChecklistMetadata(blockID: testBlockID)
        XCTAssertTrue(result)
        XCTAssertNil(view.document.blocks[0].whenDate)
        XCTAssertNil(view.document.blocks[0].deadline)
        XCTAssertTrue(view.document.blocks[0].tags.isEmpty)
    }

    func testClearAllMetadataUndoRestoresValues() {
        let view = makeView(whenDate: "2026-06-15", deadline: "2026-06-20", tags: ["work"])
        let result = view.clearChecklistMetadata(blockID: testBlockID)
        XCTAssertTrue(result)

        let undo = view.undoStructuralEdit()
        XCTAssertNotNil(undo)
        XCTAssertEqual(view.document.blocks[0].whenDate, "2026-06-15")
        XCTAssertEqual(view.document.blocks[0].deadline, "2026-06-20")
        XCTAssertEqual(view.document.blocks[0].tags, ["work"])
    }

    // MARK: - Fails on non-checklist blocks

    func testAllMutationsFailOnNonChecklist() {
        let blockID = BlockInputBlockID(rawValue: "para")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .paragraph, text: "Text")
            ])
        ))

        XCTAssertFalse(view.setChecklistWhenDate(blockID: blockID, dateString: "2026-06-15"))
        XCTAssertFalse(view.setChecklistDeadline(blockID: blockID, dateString: "2026-06-15"))
        XCTAssertFalse(view.addChecklistTag(blockID: blockID, tag: "work"))
        XCTAssertFalse(view.removeChecklistTag(blockID: blockID, tag: "work"))
        XCTAssertFalse(view.clearChecklistMetadata(blockID: blockID))
    }

    // MARK: - Detail button handler callback

    func testDetailButtonClickCallsHostHandler() {
        let blockID = testBlockID
        let undoController = BlockInputUndoController()
        var capturedContext: BlockInputChecklistMetadataDetailContext?
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(
                    id: blockID,
                    kind: .checklistItem(isChecked: false),
                    text: "Test",
                    whenDate: "2026-06-15",
                    tags: ["work"]
                )
            ]),
            undoController: undoController,
            checklistMetadataDetailHandler: { context in
                capturedContext = context
            }
        ))

        let sourceRect = NSRect(x: 0, y: 0, width: 20, height: 20)
        view.blockItem(BlockInputBlockItem(), blockID: blockID, didRequestChecklistMetadataDetail: sourceRect)

        XCTAssertNotNil(capturedContext)
        XCTAssertEqual(capturedContext?.blockID, blockID)
        XCTAssertEqual(capturedContext?.whenDate, "2026-06-15")
        XCTAssertNil(capturedContext?.deadline)
        XCTAssertEqual(capturedContext?.tags, ["work"])
        XCTAssertEqual(capturedContext?.sourceRect, sourceRect)
        XCTAssertTrue(capturedContext?.editorView === view)
    }

    func testDetailButtonClickDoesNotCallHandlerWhenNotEditable() {
        let blockID = testBlockID
        var wasCalled = false
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .checklistItem(isChecked: false), text: "Test")
            ]),
            isEditable: false,
            checklistMetadataDetailHandler: { _ in
                wasCalled = true
            }
        ))

        view.blockItem(BlockInputBlockItem(), blockID: blockID, didRequestChecklistMetadataDetail: .zero)
        XCTAssertFalse(wasCalled)
    }

    func testDetailButtonClickDoesNotCallHandlerForNonChecklist() {
        let blockID = BlockInputBlockID(rawValue: "para")
        var wasCalled = false
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, kind: .paragraph, text: "Text")
            ]),
            checklistMetadataDetailHandler: { _ in
                wasCalled = true
            }
        ))

        view.blockItem(BlockInputBlockItem(), blockID: blockID, didRequestChecklistMetadataDetail: .zero)
        XCTAssertFalse(wasCalled)
    }
}
