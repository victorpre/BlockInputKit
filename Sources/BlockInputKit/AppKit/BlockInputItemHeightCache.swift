import AppKit

/// Width-sensitive item height cache used by collection-view layout requests.
@MainActor
final class BlockInputItemHeightCache {
    private struct Entry {
        var block: BlockInputBlock
        var height: CGFloat
    }

    private var cachedTextWidth: CGFloat?
    private var entries: [BlockInputBlockID: Entry] = [:]
    private var blockIDsByIndex: [Int: BlockInputBlockID] = [:]

    func height(
        for block: BlockInputBlock,
        at index: Int,
        textWidth: CGFloat,
        measure: () -> CGFloat
    ) -> CGFloat {
        if let cachedTextWidth, abs(cachedTextWidth - textWidth) > 0.5 {
            invalidateAll()
        }
        cachedTextWidth = textWidth

        blockIDsByIndex[index] = block.id
        if let entry = entries[block.id], entry.block == block {
            return entry.height
        }

        let height = measure()
        entries[block.id] = Entry(block: block, height: height)
        return height
    }

    func invalidate(at index: Int) {
        guard let blockID = blockIDsByIndex[index] else {
            return
        }
        invalidate(blockID: blockID)
        blockIDsByIndex[index] = nil
    }

    func invalidate(blockID: BlockInputBlockID) {
        entries[blockID] = nil
    }

    func invalidateFrom(_ index: Int) {
        let invalidatedIDs = blockIDsByIndex.compactMap { key, blockID -> BlockInputBlockID? in
            key >= index ? blockID : nil
        }
        invalidatedIDs.forEach { entries[$0] = nil }
        blockIDsByIndex = blockIDsByIndex.filter { $0.key < index }
    }

    func insertItems(at index: Int, count: Int) {
        guard count > 0 else {
            return
        }
        for insertedIndex in index..<(index + count) {
            blockIDsByIndex[insertedIndex] = nil
        }
    }

    func deleteItems(at index: Int, count: Int, deletedBlockIDs: [BlockInputBlockID] = []) {
        guard count > 0 else {
            return
        }
        deletedBlockIDs.forEach { entries[$0] = nil }
        let deletedRange = index..<(index + count)
        for deletedIndex in deletedRange {
            if let blockID = blockIDsByIndex[deletedIndex] {
                entries[blockID] = nil
            }
            blockIDsByIndex[deletedIndex] = nil
        }
    }

    func invalidateAll() {
        entries.removeAll(keepingCapacity: true)
        blockIDsByIndex.removeAll(keepingCapacity: true)
        cachedTextWidth = nil
    }
}
