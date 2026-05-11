import Foundation
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewFileInsertionTests: XCTestCase {
    func testInsertFileURLsBelowActiveBlockPublishesAndRegistersUndo() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        var publishedDocument: BlockInputDocument?
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: "First"),
                BlockInputBlock(id: secondID, text: "Second")
            ]),
            undoController: undoController,
            onDocumentChange: { publishedDocument = $0 }
        ))
        view.focus(blockID: firstID, utf16Offset: 5)

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md"),
            URL(fileURLWithPath: "/tmp/Beta.md")
        ])

        XCTAssertEqual(view.document.blocks.count, 4)
        XCTAssertEqual(view.document.blocks.map(\.id).first, firstID)
        XCTAssertEqual(view.document.blocks.map(\.id).last, secondID)
        XCTAssertEqual(view.document.blocks[1].text, "[Alpha File.md](<file:///tmp/Alpha%20File.md>)")
        XCTAssertEqual(view.document.blocks[2].text, "[Beta.md](<file:///tmp/Beta.md>)")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: view.document.blocks[1].id, utf16Offset: 0)))
        XCTAssertEqual(publishedDocument, view.document)

        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Insert Files")
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, secondID])
    }

    func testInsertFileURLsReplacesDefaultEmptyParagraph() {
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        var publishedDocument: BlockInputDocument?
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(),
            undoController: undoController,
            onDocumentChange: { publishedDocument = $0 }
        ))

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ])

        XCTAssertEqual(view.document.blocks.count, 1)
        XCTAssertEqual(view.document.blocks[0].text, "[Alpha File.md](<file:///tmp/Alpha%20File.md>)")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: view.document.blocks[0].id, utf16Offset: 0)))
        XCTAssertEqual(publishedDocument, view.document)

        let undo = view.undoStructuralEdit()

        XCTAssertEqual(undo?.actionName, "Insert Files")
        XCTAssertEqual(view.document.blocks.count, 1)
        XCTAssertEqual(view.document.blocks[0].kind, .paragraph)
        XCTAssertEqual(view.document.blocks[0].text, "")
    }

    func testInsertFileURLsBelowExplicitBlockIgnoresActiveBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let thirdID = BlockInputBlockID(rawValue: "third")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second"),
            BlockInputBlock(id: thirdID, text: "Third")
        ])))
        view.focus(blockID: firstID, utf16Offset: 5)

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ], below: secondID)

        XCTAssertEqual(view.document.blocks.count, 4)
        let insertedID = view.document.blocks[2].id
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, secondID, insertedID, thirdID])
        XCTAssertEqual(view.document.blocks[2].text, "[Alpha File.md](<file:///tmp/Alpha%20File.md>)")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0)))
    }

    func testInsertFileURLsAtExplicitIndex() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])))

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ], at: 1)

        XCTAssertEqual(view.document.blocks.count, 3)
        let insertedID = view.document.blocks[1].id
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, insertedID, secondID])
        XCTAssertEqual(view.document.blocks[1].text, "[Alpha File.md](<file:///tmp/Alpha%20File.md>)")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0)))
    }

    func testInsertFileURLsClampsExplicitIndex() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First")
        ])))

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ], at: 99)

        XCTAssertEqual(view.document.blocks.count, 2)
        XCTAssertEqual(view.document.blocks.map(\.id).first, firstID)
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: view.document.blocks[1].id, utf16Offset: 0)))
    }

    func testInsertFileURLsWithoutSelectionUsesDefaultActiveBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: firstID, text: "First"),
            BlockInputBlock(id: secondID, text: "Second")
        ])))

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ])

        XCTAssertEqual(view.document.blocks.count, 3)
        let insertedID = view.document.blocks[1].id
        XCTAssertEqual(view.document.blocks.map(\.id), [firstID, insertedID, secondID])
        XCTAssertEqual(view.document.blocks[1].text, "[Alpha File.md](<file:///tmp/Alpha%20File.md>)")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: insertedID, utf16Offset: 0)))
    }

    func testInsertFileURLsIgnoresEmptyAndNonFileInput() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        var publishCount = 0
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            onDocumentChange: { _ in publishCount += 1 }
        ))

        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/file.md"))

        let selection = view.insertFileURLs([remoteURL])

        XCTAssertNil(selection)
        XCTAssertEqual(publishCount, 0)
        XCTAssertEqual(view.document.blocks.map(\.id), [blockID])
    }

    func testInsertFileURLsIgnoresNonFileURLsWhenMixedWithFileURLs() throws {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument(blocks: [
            BlockInputBlock(id: blockID, text: "First")
        ])))
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/file.md"))

        let selection = view.insertFileURLs([
            remoteURL,
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ])

        XCTAssertEqual(view.document.blocks.count, 2)
        XCTAssertEqual(view.document.blocks[1].text, "[Alpha File.md](<file:///tmp/Alpha%20File.md>)")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: view.document.blocks[1].id, utf16Offset: 0)))
    }

    func testInsertFileURLsIgnoresEmptyInput() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        var publishCount = 0
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            onDocumentChange: { _ in publishCount += 1 }
        ))

        let selection = view.insertFileURLs([])

        XCTAssertNil(selection)
        XCTAssertEqual(publishCount, 0)
        XCTAssertEqual(view.document.blocks.map(\.id), [blockID])
    }

    func testInsertFileURLsWithExplicitMissingBlockDoesNothing() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let view = BlockInputView()
        var publishCount = 0
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "First")
            ]),
            onDocumentChange: { _ in publishCount += 1 }
        ))

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ], below: "missing")

        XCTAssertNil(selection)
        XCTAssertEqual(publishCount, 0)
        XCTAssertEqual(view.document.blocks.map(\.id), [blockID])
    }

    func testInsertFileURLsWithExplicitMissingBlockDoesNotReplaceDefaultEmptyParagraph() {
        let view = BlockInputView()
        var publishCount = 0
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(),
            onDocumentChange: { _ in publishCount += 1 }
        ))
        let originalDocument = view.document

        let selection = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha File.md")
        ], below: "missing")

        XCTAssertNil(selection)
        XCTAssertEqual(publishCount, 0)
        XCTAssertEqual(view.document, originalDocument)
    }

    func testInsertFileURLsEscapesMarkdownLinkText() {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument()))

        _ = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/[Alpha]\\Beta.md")
        ])

        XCTAssertEqual(view.document.blocks[0].text, "[\\[Alpha\\]\\\\Beta.md](<file:///tmp/%5BAlpha%5D%5CBeta.md>)")
    }

    func testInsertFileURLsWrapsDestinationsThatContainClosingParenthesis() {
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(document: BlockInputDocument()))

        _ = view.insertFileURLs([
            URL(fileURLWithPath: "/tmp/Alpha).md")
        ])

        XCTAssertEqual(view.document.blocks[0].text, "[Alpha).md](<file:///tmp/Alpha).md>)")
    }
}
