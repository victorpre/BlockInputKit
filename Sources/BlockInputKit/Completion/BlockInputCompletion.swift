import Foundation

/// Completion mode requested by a block editor.
public enum BlockInputCompletionTrigger: Equatable, Codable, Sendable {
    case mention
    case slashCommand
}

/// Where live slash-command completion is allowed to open.
public enum BlockInputSlashCommandAvailability: String, CaseIterable, Equatable, Codable, Sendable {
    /// Only allow slash-command completion when `/` starts the first block.
    case documentStart
    /// Allow slash-command completion after token boundaries in any inline-capable text block.
    case anywhere
}

/// Where the editor-owned completion popup should be shown.
public enum BlockInputCompletionPopupPlacement: String, CaseIterable, Equatable, Codable, Sendable {
    /// Anchor the popup near the active text caret.
    case caret
    /// Host the popup in an overlay surface, optionally with a host-provided parent view and frame.
    case overlay
}

/// Parsed path intent for file mention completion queries.
public struct BlockInputCompletionFileQuery: Equatable, Sendable {
    /// Directory shorthand typed before the path query.
    public enum DirectoryReference: String, Equatable, Codable, Sendable {
        case current
        case parent
        case grandparent
    }

    /// Directory shorthand typed before the path query, when present.
    public var directoryReference: DirectoryReference?
    /// Number of parent-directory hops represented by the shorthand.
    public var levelsUp: Int
    /// Query text after the directory shorthand.
    public var remainder: String

    public init(
        directoryReference: DirectoryReference?,
        levelsUp: Int,
        remainder: String
    ) {
        self.directoryReference = directoryReference
        self.levelsUp = levelsUp
        self.remainder = remainder
    }
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
    /// Source range that accepting a suggestion should replace, when known.
    public var replacementRange: NSRange?
    /// Raw query text after the trigger before editor-owned normalization.
    public var rawQuery: String
    /// Parsed file path intent for mention completions, when available.
    public var fileQuery: BlockInputCompletionFileQuery?

    public init(
        trigger: BlockInputCompletionTrigger,
        query: String,
        document: BlockInputDocument,
        blockID: BlockInputBlockID,
        selectedRange: NSRange? = nil,
        replacementRange: NSRange? = nil,
        rawQuery: String? = nil,
        fileQuery: BlockInputCompletionFileQuery? = nil
    ) {
        self.trigger = trigger
        self.query = query
        self.document = document
        self.blockID = blockID
        self.selectedRange = selectedRange
        self.replacementRange = replacementRange
        self.rawQuery = rawQuery ?? query
        self.fileQuery = fileQuery
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
    /// Optional SF Symbol name shown by built-in completion UI.
    public var iconSystemName: String?
    /// Optional trailing detail shown by built-in completion UI.
    public var detailText: String?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        insertionText: String,
        trigger: BlockInputCompletionTrigger,
        iconSystemName: String? = nil,
        detailText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.insertionText = insertionText
        self.trigger = trigger
        self.iconSystemName = iconSystemName
        self.detailText = detailText
    }

    /// Builds a mention suggestion that inserts a Markdown file link.
    public static func fileLink(
        id: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        label: String,
        fileURL: URL,
        trigger: BlockInputCompletionTrigger = .mention,
        iconSystemName: String? = "doc.text",
        detailText: String? = nil
    ) -> BlockInputCompletionSuggestion {
        let destination = fileURL.absoluteString
        return BlockInputCompletionSuggestion(
            id: id ?? destination,
            title: title ?? label,
            subtitle: subtitle,
            insertionText: "[\(Self.escapedMarkdownLinkLabel(label))](\(Self.escapedMarkdownLinkDestination(destination)))",
            trigger: trigger,
            iconSystemName: iconSystemName,
            detailText: detailText
        )
    }

    /// Builds a mention suggestion that inserts a Markdown file link labeled with the file name.
    public static func fileLink(
        id: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        fileURL: URL,
        trigger: BlockInputCompletionTrigger = .mention,
        iconSystemName: String? = "doc.text",
        detailText: String? = nil
    ) -> BlockInputCompletionSuggestion {
        fileLink(
            id: id,
            title: title,
            subtitle: subtitle,
            label: Self.defaultFileLinkLabel(for: fileURL),
            fileURL: fileURL,
            trigger: trigger,
            iconSystemName: iconSystemName,
            detailText: detailText
        )
    }

    /// Builds a slash-command suggestion that inserts host-owned Markdown link source.
    ///
    /// The visible link label is normalized to begin with `/` so the inserted source renders as a slash-command chip.
    public static func slashCommand(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        uri: String,
        label: String? = nil,
        iconSystemName: String? = "command",
        detailText: String? = nil
    ) -> BlockInputCompletionSuggestion {
        let chipLabel = Self.normalizedSlashCommandLabel(label ?? title)
        return BlockInputCompletionSuggestion(
            id: id ?? uri,
            title: title,
            subtitle: subtitle,
            insertionText: "[\(Self.escapedMarkdownLinkLabel(chipLabel))](\(Self.escapedMarkdownLinkDestination(uri)))",
            trigger: .slashCommand,
            iconSystemName: iconSystemName,
            detailText: detailText
        )
    }
}

/// Supplies mention and slash-command completions to the editor.
public protocol BlockInputCompletionProvider: AnyObject, Sendable {
    /// Returns suggestions for the active completion context.
    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion]
}

private extension BlockInputCompletionSuggestion {
    static func defaultFileLinkLabel(for fileURL: URL) -> String {
        let name = fileURL.lastPathComponent
        return name.isEmpty ? fileURL.path : name
    }

    static func escapedMarkdownLinkLabel(_ label: String) -> String {
        label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    static func escapedMarkdownLinkDestination(_ destination: String) -> String {
        destination
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    }

    static func normalizedSlashCommandLabel(_ label: String) -> String {
        label.hasPrefix("/") ? label : "/\(label)"
    }
}
