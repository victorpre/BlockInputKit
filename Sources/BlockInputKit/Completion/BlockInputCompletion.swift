import Foundation

/// Completion mode requested by a block editor.
public enum BlockInputCompletionTrigger: Equatable, Codable, Sendable {
    case mention
    case slashCommand
}

/// Host-provided context for mention and slash-command completion lookups.
public struct BlockInputCompletionContext: Equatable, Sendable {
    /// Completion trigger currently being resolved.
    public var trigger: BlockInputCompletionTrigger
    /// User-entered query text after the trigger.
    public var query: String
    /// Current document snapshot.
    public var document: BlockInputDocument
    /// Block that owns the completion request.
    public var blockID: BlockInputBlockID
    /// Current AppKit text selection range, when available.
    public var selectedRange: NSRange?

    public init(
        trigger: BlockInputCompletionTrigger,
        query: String,
        document: BlockInputDocument,
        blockID: BlockInputBlockID,
        selectedRange: NSRange? = nil
    ) {
        self.trigger = trigger
        self.query = query
        self.document = document
        self.blockID = blockID
        self.selectedRange = selectedRange
    }
}

/// A selectable completion row supplied by the host app.
public struct BlockInputCompletionSuggestion: Equatable, Identifiable, Sendable {
    /// Stable suggestion identity.
    public var id: String
    /// Primary text shown for the suggestion.
    public var title: String
    /// Optional secondary text shown for the suggestion.
    public var subtitle: String?
    /// Text inserted when the suggestion is accepted.
    public var insertionText: String
    /// Trigger this suggestion is intended to satisfy.
    public var trigger: BlockInputCompletionTrigger

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        insertionText: String,
        trigger: BlockInputCompletionTrigger
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.insertionText = insertionText
        self.trigger = trigger
    }
}

/// Supplies mention and slash-command completions to the editor.
public protocol BlockInputCompletionProvider: AnyObject, Sendable {
    /// Returns suggestions for the active completion context.
    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion]
}
