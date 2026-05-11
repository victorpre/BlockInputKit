import Foundation

/// Stable identifier for a block in a document.
public struct BlockInputBlockID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    /// Host-storable identifier value.
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    /// Creates a random UUID-backed block identifier.
    public static func unique() -> Self {
        Self(rawValue: UUID().uuidString)
    }
}

/// Supported document block types.
public enum BlockInputBlockKind: Equatable, Codable, Sendable {
    /// Plain text with no block-level formatting.
    case paragraph
    /// Markdown heading level, clamped to levels 1 through 6 when rendered.
    case heading(level: Int)
    /// Fenced code block with an optional language identifier.
    case code(language: String?)
    /// Horizontal divider exported as `---`.
    case horizontalRule
    /// Markdown quote block.
    case quote
    /// Unordered list item.
    case bulletedListItem
    /// Ordered list item with the number to display for this block.
    case numberedListItem(start: Int)
    /// Checklist item with checked state stored in the block kind.
    case checklistItem(isChecked: Bool)
}

/// Structured document unit edited by its own AppKit text input.
public struct BlockInputBlock: Equatable, Codable, Sendable, Identifiable {
    /// Stable block identity used for focus, selection, undo, and reordering.
    public var id: BlockInputBlockID
    /// Semantic rendering and Markdown export kind.
    public var kind: BlockInputBlockKind {
        didSet {
            normalizeForKind()
        }
    }
    /// Plain text content owned by editable block kinds.
    ///
    /// Non-text blocks such as horizontal rules normalize this value to an empty string.
    public var text: String {
        didSet {
            normalizeForKind()
        }
    }
    /// Nesting level used by list-like blocks.
    public var indentationLevel: Int {
        didSet {
            normalizeForKind()
        }
    }

    public init(
        id: BlockInputBlockID = .unique(),
        kind: BlockInputBlockKind = .paragraph,
        text: String = "",
        indentationLevel: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.text = kind == .horizontalRule ? "" : text
        self.indentationLevel = indentationLevel
        normalizeForKind()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(BlockInputBlockID.self, forKey: .id)
        kind = try container.decode(BlockInputBlockKind.self, forKey: .kind)
        let decodedText = try container.decode(String.self, forKey: .text)
        text = kind == .horizontalRule ? "" : decodedText
        indentationLevel = try container.decode(Int.self, forKey: .indentationLevel)
        normalizeForKind()
    }

    /// Returns true when the block has no meaningful user-visible content.
    public var isEmpty: Bool {
        if kind == .horizontalRule {
            return false
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Text length in UTF-16 units for AppKit selection interoperability.
    public var utf16Length: Int {
        (text as NSString).length
    }

    private mutating func normalizeForKind() {
        if kind == .horizontalRule, !text.isEmpty {
            text = ""
        }
        let normalizedIndentation = kind.supportsIndentation ? max(0, indentationLevel) : 0
        if indentationLevel != normalizedIndentation {
            indentationLevel = normalizedIndentation
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case text
        case indentationLevel
    }
}

extension BlockInputBlock {
    func requiresStructuralReturnHandling(utf16Offset: Int, selectedUTF16Length: Int) -> Bool {
        if isEmpty, kind.exitsToParagraphOnEmptyReturn {
            return true
        }
        guard kind.acceptsInlineReturn else {
            return true
        }
        guard selectedUTF16Length == 0 else {
            return false
        }
        return emptyInlineLineRemovalRangeForReturn(utf16Offset: utf16Offset) != nil
    }

    func emptyInlineLineRemovalRangeForReturn(utf16Offset: Int) -> NSRange? {
        guard kind.acceptsInlineReturn, !isEmpty else {
            return nil
        }
        let textStorage = text as NSString
        let offset = min(max(utf16Offset, 0), textStorage.length)
        let lineRange = textStorage.lineRange(for: NSRange(location: offset, length: 0))
        guard isEmptyLine(range: lineRange, in: textStorage) else {
            return nil
        }
        if lineRange.length > 0 {
            return lineRange
        }
        guard offset > 0, textStorage.character(at: offset - 1).isLineEnding else {
            return nil
        }
        let lineEndingStart = offset > 1 && textStorage.character(at: offset - 2).isCarriageReturn
            ? offset - 2
            : offset - 1
        return NSRange(location: lineEndingStart, length: offset - lineEndingStart)
    }

    private func isEmptyLine(range: NSRange, in textStorage: NSString) -> Bool {
        var contentLength = range.length
        while contentLength > 0,
              textStorage.character(at: range.location + contentLength - 1).isLineEnding {
            contentLength -= 1
        }
        let contentRange = NSRange(location: range.location, length: contentLength)
        return textStorage
            .substring(with: contentRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}

extension BlockInputBlockKind {
    var supportsIndentation: Bool {
        switch self {
        case .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .heading, .code, .horizontalRule, .quote:
            return false
        }
    }

    var canUnwrapToParagraph: Bool {
        switch self {
        case .paragraph, .code:
            return false
        case .heading, .horizontalRule, .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        }
    }

    var exitsToParagraphOnEmptyReturn: Bool {
        switch self {
        case .heading, .code, .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .horizontalRule:
            return false
        }
    }

    var acceptsInlineReturn: Bool {
        switch self {
        case .code, .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .heading, .horizontalRule:
            return false
        }
    }
}

private extension unichar {
    var isLineEnding: Bool {
        self == 10 || self == 13
    }

    var isCarriageReturn: Bool {
        self == 13
    }
}
