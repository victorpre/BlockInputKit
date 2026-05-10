import Foundation

public struct BlockInputCursor: Equatable, Codable, Sendable {
    public var blockID: BlockInputBlockID
    public var utf16Offset: Int

    public init(blockID: BlockInputBlockID, utf16Offset: Int) {
        self.blockID = blockID
        self.utf16Offset = max(0, utf16Offset)
    }
}

public struct BlockInputTextRange: Equatable, Codable, Sendable {
    public var blockID: BlockInputBlockID
    public var range: NSRange

    public init(blockID: BlockInputBlockID, range: NSRange) {
        self.blockID = blockID
        self.range = range
    }
}

public enum BlockInputSelection: Equatable, Codable, Sendable {
    case cursor(BlockInputCursor)
    case text(BlockInputTextRange)
    case blocks([BlockInputBlockID])
}
