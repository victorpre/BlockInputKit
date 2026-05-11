import Foundation

/// Caret position inside a single block.
public struct BlockInputCursor: Equatable, Codable, Sendable {
    /// Block that owns the caret.
    public var blockID: BlockInputBlockID
    /// UTF-16 text offset compatible with AppKit text ranges.
    public var utf16Offset: Int

    /// Creates a cursor at a UTF-16 offset inside a block.
    public init(blockID: BlockInputBlockID, utf16Offset: Int) {
        self.blockID = blockID
        self.utf16Offset = max(0, utf16Offset)
    }
}

/// Text selection range inside a single block.
public struct BlockInputTextRange: Equatable, Codable, Sendable {
    /// Block that owns the selected text.
    public var blockID: BlockInputBlockID
    /// UTF-16 range compatible with AppKit text selections.
    public var range: NSRange

    /// Creates a text selection range inside a block.
    public init(blockID: BlockInputBlockID, range: NSRange) {
        self.blockID = blockID
        self.range = range
    }
}

/// Current editor selection, including escalated multi-block selection.
public enum BlockInputSelection: Equatable, Codable, Sendable {
    /// A collapsed caret inside one block.
    case cursor(BlockInputCursor)
    /// A non-empty AppKit text range inside one block.
    case text(BlockInputTextRange)
    /// Whole-block selection, used after Cmd+A escalates beyond the active block.
    case blocks([BlockInputBlockID])
}
