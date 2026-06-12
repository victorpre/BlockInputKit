import Foundation

/// Completion mode requested by a block editor.
public enum BlockInputCompletionTrigger: Equatable, Codable, Sendable {
    /// Mention completion triggered by inline mention text.
    case mention
    /// Slash-command completion triggered by inline slash-command text.
    case slashCommand
}

/// Where live slash-command completion is allowed to open.
public enum BlockInputSlashCommandAvailability: String, CaseIterable, Equatable, Codable, Sendable {
    /// Only allow slash-command completion when `/` starts the first block.
    case documentStart
    /// Allow slash-command completion after token boundaries in any inline-capable text block.
    case anywhere
}

/// Source inserted when accepting a slash-command completion suggestion.
public enum BlockInputSlashCommandInsertionStyle: String, CaseIterable, Equatable, Codable, Sendable {
    /// Insert a Markdown link whose label renders as a slash-command chip.
    case markdownLink
    /// Insert the raw slash-command token text.
    case rawToken
}

/// Return-key behavior while the editor-owned completion popup is active.
public enum BlockInputCompletionReturnBehavior: String, CaseIterable, Equatable, Codable, Sendable {
    /// Return accepts the highlighted suggestion when one is available.
    case acceptHighlightedSuggestion
    /// Return passes through when the replacement text already exactly matches the highlighted suggestion.
    case passthroughExactMatch
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
        /// Query resolves from the current directory shorthand.
        case current
        /// Query resolves from the parent directory shorthand.
        case parent
        /// Query resolves from the grandparent directory shorthand.
        case grandparent
    }

    /// Directory shorthand typed before the path query, when present.
    public var directoryReference: DirectoryReference?
    /// Number of parent-directory hops represented by the shorthand.
    public var levelsUp: Int
    /// Query text after the directory shorthand.
    public var remainder: String

    /// Creates parsed file-query intent for a mention completion request.
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

/// A Sendable-safe RGBA color representation used to tint completion icons.
public struct CompletionIconTint: Equatable, Sendable {
    /// Red component in the 0–1 range.
    public var red: CGFloat
    /// Green component in the 0–1 range.
    public var green: CGFloat
    /// Blue component in the 0–1 range.
    public var blue: CGFloat
    /// Alpha component in the 0–1 range (defaults to 1).
    public var alpha: CGFloat

    /// Creates an RGBA color value.
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Date formatting style for date completion suggestions.
public enum BlockInputCompletionDateStyle: String, CaseIterable, Equatable, Codable, Sendable {
    /// Short style e.g. "6/10/26".
    case short
    /// Medium style e.g. "Jun 10, 2026".
    case medium
    /// Long style e.g. "June 10, 2026".
    case long
    /// Full style e.g. "Wednesday, June 10, 2026".
    case full
    /// Relative style e.g. "Today", "Tomorrow", "Yesterday".
    case relative
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

    /// Creates host completion lookup context for the active editor request.
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
    /// Optional text used for `.passthroughExactMatch`; defaults to `insertionText`.
    public var exactMatchText: String?
    /// Trigger this suggestion is intended to satisfy.
    public var trigger: BlockInputCompletionTrigger
    /// Optional SF Symbol name shown by built-in completion UI.
    public var iconSystemName: String?
    /// Optional trailing detail shown by built-in completion UI.
    public var detailText: String?
    /// Optional icon tint applied by built-in completion UI.
    public var iconTint: CompletionIconTint?

    /// Optional title color applied by built-in completion UI.
    public var titleColor: CompletionIconTint?

    /// Creates a host-provided completion suggestion.
    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        insertionText: String,
        exactMatchText: String? = nil,
        trigger: BlockInputCompletionTrigger,
        iconSystemName: String? = nil,
        detailText: String? = nil,
        iconTint: CompletionIconTint? = nil,
        titleColor: CompletionIconTint? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.insertionText = insertionText
        self.exactMatchText = exactMatchText
        self.trigger = trigger
        self.iconSystemName = iconSystemName
        self.detailText = detailText
        self.iconTint = iconTint
        self.titleColor = titleColor
    }

    /// Builds a mention suggestion that inserts a Markdown file link followed by a space.
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
            insertionText: "[\(Self.escapedMarkdownLinkLabel(label))](\(Self.escapedMarkdownLinkDestination(destination))) ",
            trigger: trigger,
            iconSystemName: iconSystemName,
            detailText: detailText
        )
    }

    /// Builds a mention suggestion that inserts a Markdown file link labeled with the file name followed by a space.
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

    /// Builds a slash-command suggestion that inserts slash-command source followed by a space.
    ///
    /// The visible label is normalized to begin with `/`. By default the inserted source is a Markdown link that
    /// renders as a slash-command chip; use `.rawToken` when the underlying Markdown should stay as raw `/command` text.
    public static func slashCommand(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        uri: String,
        label: String? = nil,
        insertionStyle: BlockInputSlashCommandInsertionStyle = .markdownLink,
        iconSystemName: String? = "command",
        detailText: String? = nil
    ) -> BlockInputCompletionSuggestion {
        let chipLabel = Self.normalizedSlashCommandLabel(label ?? title)
        return BlockInputCompletionSuggestion(
            id: id ?? uri,
            title: title,
            subtitle: subtitle,
            insertionText: Self.slashCommandInsertionText(label: chipLabel, uri: uri, insertionStyle: insertionStyle),
            exactMatchText: chipLabel,
            trigger: .slashCommand,
            iconSystemName: iconSystemName,
            detailText: detailText
        )
    }
}

// MARK: - Date Completion

extension BlockInputCompletionSuggestion {
    /// Builds a date completion suggestion that inserts a when-date token followed by a space.
    ///
    /// The visible title is formatted according to the requested style. The insertion text is
    /// `@YYYY-MM-DD` that the editor recognizes as a when-date chip in checklist blocks.
    public static func date(
        id: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        date: Date,
        style: BlockInputCompletionDateStyle = .medium,
        trigger: BlockInputCompletionTrigger = .mention,
        iconSystemName: String? = "calendar",
        detailText: String? = "Date"
    ) -> BlockInputCompletionSuggestion {
        let isoDate = isoDateString(from: date)
        let displayTitle = title ?? formattedDate(date, style: style)
        let today = Calendar.current.startOfDay(for: Date())
        let dateDay = Calendar.current.startOfDay(for: date)
        let pastTint = CompletionIconTint(red: 230 / 255, green: 87 / 255, blue: 120 / 255)
        let iconTint: CompletionIconTint?
        let titleColor: CompletionIconTint?
        if dateDay == today {
            iconTint = CompletionIconTint(red: 1, green: 0.8, blue: 0)
            titleColor = nil
        } else if dateDay < today {
            iconTint = pastTint
            titleColor = pastTint
        } else {
            iconTint = nil
            titleColor = nil
        }
        return BlockInputCompletionSuggestion(
            id: id ?? isoDate,
            title: displayTitle,
            subtitle: subtitle,
            insertionText: "@\(isoDate)",
            exactMatchText: isoDate,
            trigger: trigger,
            iconSystemName: iconSystemName,
            detailText: detailText,
            iconTint: iconTint,
            titleColor: titleColor
        )
    }

    /// Returns matching date suggestions for a query string typed after `@`.
    ///
    /// Matches against natural-language labels (today, tomorrow, yesterday, next week,
    /// next month, day names) and YYYY-MM-DD date strings.
    public static func dateSuggestions(
        for query: String,
        style: BlockInputCompletionDateStyle = .relative
    ) -> [BlockInputCompletionSuggestion] {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        let referenceDate = Date()
        let today = Calendar.current.startOfDay(for: referenceDate)

        var results: [BlockInputCompletionSuggestion] = matchKnownDateSuggestions(query: lowerQuery, today: today, style: style)
        results += matchDayNameSuggestions(query: lowerQuery, referenceDate: referenceDate, style: style)
        results += matchISOStringSuggestions(query: lowerQuery, referenceDate: referenceDate, style: style)

        results.sort { lhs, rhs in
            let lhsIsExact = lhs.title.lowercased() == lowerQuery
            let rhsIsExact = rhs.title.lowercased() == lowerQuery
            if lhsIsExact != rhsIsExact {
                return lhsIsExact
            }
            return lhs.title < rhs.title
        }

        return results
    }

    private static func matchKnownDateSuggestions(
        query: String,
        today: Date,
        style: BlockInputCompletionDateStyle
    ) -> [BlockInputCompletionSuggestion] {
        let entries: [(String, Date?)] = [
            ("today", today),
            ("tomorrow", Calendar.current.date(byAdding: .day, value: 1, to: today)),
            ("yesterday", Calendar.current.date(byAdding: .day, value: -1, to: today)),
            ("next week", Calendar.current.date(byAdding: .day, value: 7, to: today)),
            ("next month", Calendar.current.date(byAdding: .month, value: 1, to: today))
        ]
        return entries.compactMap { label, date in
            guard let date, label.hasPrefix(query) else { return nil }
            return .date(date: date, style: style, detailText: formattedDate(date, style: .medium))
        }
    }

    private static func matchDayNameSuggestions(
        query: String,
        referenceDate: Date,
        style: BlockInputCompletionDateStyle
    ) -> [BlockInputCompletionSuggestion] {
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        return dayNames.compactMap { dayName in
            guard dayName.hasPrefix(query) || query.isEmpty else { return nil }
            guard let date = BlockInputDateResolver.resolveDate(from: dayName, relativeTo: referenceDate) else { return nil }
            return .date(date: date, style: style, detailText: formattedDate(date, style: .medium))
        }
    }

    private static func matchISOStringSuggestions(
        query: String,
        referenceDate: Date,
        style: BlockInputCompletionDateStyle
    ) -> [BlockInputCompletionSuggestion] {
        let pattern = #"^\d{4}(-\d{2}(-\d{2})?)?$"#
        guard query.range(of: pattern, options: .regularExpression) != nil,
              let date = BlockInputDateResolver.resolveDate(from: query, relativeTo: referenceDate) else {
            return []
        }
        return [.date(date: date, style: style, detailText: formattedDate(date, style: .medium))]
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

    static func slashCommandInsertionText(
        label: String,
        uri: String,
        insertionStyle: BlockInputSlashCommandInsertionStyle
    ) -> String {
        switch insertionStyle {
        case .markdownLink:
            return "[\(escapedMarkdownLinkLabel(label))](\(escapedMarkdownLinkDestination(uri))) "
        case .rawToken:
            return "\(label) "
        }
    }

    static func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func formattedDate(_ date: Date, style: BlockInputCompletionDateStyle) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch style {
        case .short:
            formatter.dateStyle = .short
        case .medium:
            formatter.dateStyle = .medium
        case .long:
            formatter.dateStyle = .long
        case .full:
            formatter.dateStyle = .full
        case .relative:
            formatter.dateStyle = .medium
            formatter.doesRelativeDateFormatting = true
        }
        return formatter.string(from: date)
    }
}
