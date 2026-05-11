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

/// Supported editable block types.
public enum BlockInputBlockKind: Equatable, Codable, Sendable {
    case paragraph
    case code(language: String?)
    case quote
    case bulletedListItem
    case numberedListItem(start: Int)
    case checklistItem(isChecked: Bool)
}

/// Structured document unit edited by its own AppKit text input.
public struct BlockInputBlock: Equatable, Codable, Sendable, Identifiable {
    /// Stable block identity used for focus, selection, undo, and reordering.
    public var id: BlockInputBlockID
    /// Semantic rendering and Markdown export kind.
    public var kind: BlockInputBlockKind
    /// Plain text content owned by this block.
    public var text: String
    /// Nesting level used by list-like blocks.
    public var indentationLevel: Int

    public init(
        id: BlockInputBlockID = .unique(),
        kind: BlockInputBlockKind = .paragraph,
        text: String = "",
        indentationLevel: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.indentationLevel = max(0, indentationLevel)
    }

    /// Returns true when the block has no meaningful user-visible text.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Text length in UTF-16 units for AppKit selection interoperability.
    public var utf16Length: Int {
        (text as NSString).length
    }
}
