import Foundation

/// Caret position inside a single block.
public struct BlockInputCursor: Equatable, Codable, Sendable {
    public var blockID: BlockInputBlockID
    /// UTF-16 text offset compatible with AppKit text ranges.
    public var utf16Offset: Int

    public init(blockID: BlockInputBlockID, utf16Offset: Int) {
        self.blockID = blockID
        self.utf16Offset = max(0, utf16Offset)
    }
}

/// Text selection range inside a single block.
public struct BlockInputTextRange: Equatable, Codable, Sendable {
    public var blockID: BlockInputBlockID
    /// UTF-16 range compatible with AppKit text selections.
    public var range: NSRange

    public init(blockID: BlockInputBlockID, range: NSRange) {
        self.blockID = blockID
        self.range = range
    }
}

/// Current editor selection, including escalated multi-block selection.
public enum BlockInputSelection: Equatable, Codable, Sendable {
    case cursor(BlockInputCursor)
    case text(BlockInputTextRange)
    case blocks([BlockInputBlockID])
}
