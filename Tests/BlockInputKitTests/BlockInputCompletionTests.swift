import Foundation
import XCTest
@testable import BlockInputKit

final class BlockInputCompletionTests: XCTestCase {
    func testCompletionSuggestionStoresHostProvidedInsertion() {
        let suggestion = BlockInputCompletionSuggestion(
            id: "mention:alice",
            title: "Alice",
            subtitle: "Engineering",
            insertionText: "@alice",
            trigger: .mention
        )

        XCTAssertEqual(suggestion.id, "mention:alice")
        XCTAssertEqual(suggestion.title, "Alice")
        XCTAssertEqual(suggestion.subtitle, "Engineering")
        XCTAssertEqual(suggestion.insertionText, "@alice")
        XCTAssertEqual(suggestion.trigger, .mention)
    }

    func testCompletionProviderReceivesContext() async {
        let blockID = BlockInputBlockID(rawValue: "first")
        let provider = CapturingCompletionProvider()
        let context = BlockInputCompletionContext(
            trigger: .slashCommand,
            query: "cod",
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "/cod")
            ]),
            blockID: blockID,
            selectedRange: NSRange(location: 1, length: 3)
        )

        let suggestions = await provider.suggestions(for: context)

        XCTAssertEqual(provider.lastContext, context)
        XCTAssertEqual(suggestions.map(\.insertionText), ["```"])
    }

    @MainActor
    func testAcceptCompletionSuggestionReplacesCurrentTextSelection() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        var publishedDocuments: [BlockInputDocument] = []
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Hello @al")
            ]),
            undoController: undoController,
            onDocumentChange: { publishedDocuments.append($0) }
        ))
        view.applySelection(.text(BlockInputTextRange(
            blockID: blockID,
            range: NSRange(location: 6, length: 3)
        )), notify: false)

        let selection = view.acceptCompletionSuggestion(BlockInputCompletionSuggestion(
            id: "mention:alice",
            title: "Alice",
            insertionText: "@alice",
            trigger: .mention
        ))

        XCTAssertEqual(view.document.blocks[0].text, "Hello @alice")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 12)))
        XCTAssertEqual(publishedDocuments.last, view.document)

        _ = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks[0].text, "Hello @al")
        XCTAssertEqual(view.selection, .text(BlockInputTextRange(
            blockID: blockID,
            range: NSRange(location: 6, length: 3)
        )))
    }

    @MainActor
    func testAcceptCompletionSuggestionInsertsAtCurrentCursor() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Hello ")
            ]),
            undoController: undoController
        ))
        view.focus(blockID: blockID, utf16Offset: 6)

        let selection = view.acceptCompletionSuggestion(BlockInputCompletionSuggestion(
            id: "mention:alice",
            title: "Alice",
            insertionText: "@alice",
            trigger: .mention
        ))

        XCTAssertEqual(view.document.blocks[0].text, "Hello @alice")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 12)))

        _ = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks[0].text, "Hello ")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 6)))
    }

    @MainActor
    func testAcceptCompletionSuggestionUsesExplicitRangeAndBlock() {
        let firstID = BlockInputBlockID(rawValue: "first")
        let secondID = BlockInputBlockID(rawValue: "second")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: firstID, text: "First"),
                BlockInputBlock(id: secondID, text: "/cod")
            ]),
            undoController: undoController
        ))
        view.applySelection(.cursor(BlockInputCursor(blockID: firstID, utf16Offset: 1)), notify: false)

        let selection = view.acceptCompletionSuggestion(
            BlockInputCompletionSuggestion(
                id: "slash:code",
                title: "Code block",
                insertionText: "```",
                trigger: .slashCommand
            ),
            in: secondID,
            replacing: NSRange(location: 0, length: 4)
        )

        XCTAssertEqual(view.document.blocks.map(\.text), ["First", "```"])
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: secondID, utf16Offset: 3)))

        view.focus(blockID: firstID, utf16Offset: 1)
        _ = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks.map(\.text), ["First", "```"])

        view.focus(blockID: secondID, utf16Offset: 3)
        _ = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks.map(\.text), ["First", "/cod"])
        XCTAssertEqual(view.selection, .text(BlockInputTextRange(
            blockID: secondID,
            range: NSRange(location: 0, length: 4)
        )))
    }

    @MainActor
    func testAcceptCompletionSuggestionClampsExplicitRangeBeforeRegisteringUndo() {
        let blockID = BlockInputBlockID(rawValue: "first")
        let undoController = BlockInputUndoController()
        let view = BlockInputView()
        view.configure(BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "abc")
            ]),
            undoController: undoController
        ))

        let selection = view.acceptCompletionSuggestion(
            BlockInputCompletionSuggestion(
                id: "mention:alice",
                title: "Alice",
                insertionText: "@alice",
                trigger: .mention
            ),
            in: blockID,
            replacing: NSRange(location: 10, length: 4)
        )

        XCTAssertEqual(view.document.blocks[0].text, "abc@alice")
        XCTAssertEqual(selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 9)))

        _ = view.undoTextEditInActiveBlock()
        XCTAssertEqual(view.document.blocks[0].text, "abc")
        XCTAssertEqual(view.selection, .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 3)))
    }
}

private final class CapturingCompletionProvider: BlockInputCompletionProvider {
    private(set) var lastContext: BlockInputCompletionContext?

    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        lastContext = context
        return [
            BlockInputCompletionSuggestion(
                id: "slash:code",
                title: "Code block",
                insertionText: "```",
                trigger: context.trigger
            )
        ]
    }
}
