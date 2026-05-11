import BlockInputKit
import Foundation

// The demo provider has no mutable state, but the task-based sample asks Swift
// to prove sendability across an async boundary.
final class DemoCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        switch context.trigger {
        case .mention:
            return [
                BlockInputCompletionSuggestion(
                    id: "mention:ava",
                    title: "Ava",
                    subtitle: "Design",
                    insertionText: "@ava",
                    trigger: .mention
                ),
                BlockInputCompletionSuggestion(
                    id: "mention:noah",
                    title: "Noah",
                    subtitle: "Engineering",
                    insertionText: "@noah",
                    trigger: .mention
                )
            ].filtered(by: context.query)
        case .slashCommand:
            return [
                BlockInputCompletionSuggestion(
                    id: "slash:code",
                    title: "Code block",
                    subtitle: "Insert fenced code",
                    insertionText: "```",
                    trigger: .slashCommand
                ),
                BlockInputCompletionSuggestion(
                    id: "slash:quote",
                    title: "Quote",
                    subtitle: "Switch to quote block",
                    insertionText: "> ",
                    trigger: .slashCommand
                ),
                BlockInputCompletionSuggestion(
                    id: "slash:todo",
                    title: "Checklist",
                    subtitle: "Insert unchecked task",
                    insertionText: "- [ ] ",
                    trigger: .slashCommand
                )
            ].filtered(by: context.query)
        }
    }
}

private extension Array where Element == BlockInputCompletionSuggestion {
    func filtered(by query: String) -> [Element] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@/"))
            .lowercased()
        guard !normalizedQuery.isEmpty else {
            return self
        }
        return filter { suggestion in
            suggestion.title.lowercased().contains(normalizedQuery)
                || suggestion.subtitle?.lowercased().contains(normalizedQuery) == true
                || suggestion.insertionText.lowercased().contains(normalizedQuery)
        }
    }
}
