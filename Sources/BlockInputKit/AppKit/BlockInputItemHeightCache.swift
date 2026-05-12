import AppKit

/// Width-sensitive item height cache used by collection-view layout requests.
@MainActor
final class BlockInputItemHeightCache {
    private struct Entry {
        var block: BlockInputBlock
        var height: CGFloat
    }

    private var cachedTextWidth: CGFloat?
    private var entries: [Int: Entry] = [:]

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

        if let entry = entries[index], entry.block == block {
            return entry.height
        }

        let height = measure()
        entries[index] = Entry(block: block, height: height)
        return height
    }

    func invalidate(at index: Int) {
        entries[index] = nil
    }

    func invalidateAll() {
        entries.removeAll(keepingCapacity: true)
        cachedTextWidth = nil
    }
}
