import Foundation

public extension BlockInputDocument {
    /// Inserts blocks at a clamped document index and focuses the first inserted block.
    ///
    /// Empty insertions are ignored so callers can forward parsed content without
    /// separately special-casing no-op results.
    @discardableResult
    mutating func insertBlocks(
        _ insertedBlocks: [BlockInputBlock],
        at index: Int
    ) -> BlockInputSelection? {
        guard let firstBlock = insertedBlocks.first else {
            return nil
        }
        let insertionIndex = min(max(index, 0), blocks.count)
        blocks.insert(contentsOf: insertedBlocks, at: insertionIndex)
        return .cursor(BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0))
    }
}
