import Foundation

public struct BlockInputBlockID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static func unique() -> Self {
        Self(rawValue: UUID().uuidString)
    }
}

public enum BlockInputBlockKind: Equatable, Codable, Sendable {
    case paragraph
    case code(language: String?)
    case quote
    case bulletedListItem
    case numberedListItem(start: Int)
    case checklistItem(isChecked: Bool)
}

public struct BlockInputBlock: Equatable, Codable, Sendable, Identifiable {
    public var id: BlockInputBlockID
    public var kind: BlockInputBlockKind
    public var text: String
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

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var utf16Length: Int {
        (text as NSString).length
    }
}
