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
