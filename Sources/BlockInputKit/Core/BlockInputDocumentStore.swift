import Foundation

/// Document storage boundary used by the editor and host app.
///
/// The editor reads blocks by index and stable ID so hosts can keep large
/// documents outside of the view. Large host stores should keep these indexed
/// read methods cheap and override the granular mutation methods to avoid full
/// document replacement on common editor operations.
public protocol BlockInputDocumentStore: AnyObject {
    /// Current document snapshot.
    var document: BlockInputDocument { get }
    /// Number of blocks available to the editor.
    var blockCount: Int { get }

    /// Returns the block at an ordered index.
    func block(at index: Int) -> BlockInputBlock?
    /// Returns the block with a stable ID.
    func block(withID id: BlockInputBlockID) -> BlockInputBlock?
    /// Returns the ordered index for a stable block ID.
    func index(of id: BlockInputBlockID) -> Int?
    /// Replaces the full document after broad structural mutations.
    func replaceDocument(_ document: BlockInputDocument)
    /// Replaces one block after a text or formatting mutation.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when the
    /// block exists and changes the current document.
    func replaceBlock(_ block: BlockInputBlock)
    /// Inserts blocks at an ordered index.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when the
    /// insertion changes the current document.
    func insertBlocks(_ blocks: [BlockInputBlock], at index: Int)
    /// Deletes blocks by stable ID.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when at
    /// least one block is removed.
    func deleteBlocks(withIDs ids: [BlockInputBlockID])
    /// Moves one block to a final ordered index.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when the
    /// block exists and its index changes.
    func moveBlock(withID id: BlockInputBlockID, to index: Int)
}

/// Optional store capability for producing full snapshots away from the main actor.
public protocol BlockInputBackgroundSnapshotStore: BlockInputDocumentStore, Sendable {
    /// Returns a consistent full-document snapshot from a background thread.
    func backgroundDocumentSnapshot() -> BlockInputDocument
}

public extension BlockInputDocumentStore {
    var blockCount: Int {
        document.blocks.count
    }

    func block(at index: Int) -> BlockInputBlock? {
        guard document.blocks.indices.contains(index) else {
            return nil
        }
        return document.blocks[index]
    }

    func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        document.block(withID: id)
    }

    func index(of id: BlockInputBlockID) -> Int? {
        document.index(of: id)
    }

    func replaceBlock(_ block: BlockInputBlock) {
        var updatedDocument = document
        guard let index = updatedDocument.index(of: block.id) else {
            return
        }
        guard updatedDocument.blocks[index] != block else {
            return
        }
        updatedDocument.blocks[index] = block
        replaceDocument(updatedDocument)
    }

    func insertBlocks(_ blocks: [BlockInputBlock], at index: Int) {
        var updatedDocument = document
        guard updatedDocument.insertBlocks(blocks, at: index) != nil else {
            return
        }
        replaceDocument(updatedDocument)
    }

    func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        guard !ids.isEmpty else {
            return
        }
        var updatedDocument = document
        let beforeDocument = updatedDocument
        let deletedIDs = Set(ids)
        updatedDocument.blocks.removeAll { deletedIDs.contains($0.id) }
        guard updatedDocument != beforeDocument else {
            return
        }
        replaceDocument(updatedDocument)
    }

    func moveBlock(withID id: BlockInputBlockID, to index: Int) {
        var updatedDocument = document
        guard updatedDocument.moveBlock(blockID: id, to: index) != nil else {
            return
        }
        replaceDocument(updatedDocument)
    }
}

/// In-memory store for simple editors and tests.
public final class BlockInputMemoryDocumentStore: BlockInputBackgroundSnapshotStore, @unchecked Sendable {
    /// Current document snapshot.
    public var document: BlockInputDocument {
        lock.lock()
        defer { lock.unlock() }
        return storedDocument
    }

    public var blockCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedDocument.blocks.count
    }

    private var storedDocument: BlockInputDocument
    private var indexesByID: [BlockInputBlockID: Int]
    private let lock = NSLock()
    // Inserts and deletes leave suffix indexes stale; rebuild lazily only when
    // a later lookup asks for one, keeping 100k-demo mutations responsive.
    private var indexesNeedRebuild = false

    public init(document: BlockInputDocument = BlockInputDocument()) {
        storedDocument = document
        indexesByID = Self.indexesByID(for: document)
    }

    public func backgroundDocumentSnapshot() -> BlockInputDocument {
        lock.lock()
        defer { lock.unlock() }
        return storedDocument.detachedStorage()
    }

    public func block(at index: Int) -> BlockInputBlock? {
        lock.lock()
        defer { lock.unlock() }
        guard storedDocument.blocks.indices.contains(index) else {
            return nil
        }
        return storedDocument.blocks[index]
    }

    public func replaceDocument(_ document: BlockInputDocument) {
        lock.lock()
        defer { lock.unlock() }
        storedDocument = document
        rebuildIndexes()
    }

    public func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        lock.lock()
        defer { lock.unlock() }
        guard let index = unlockedIndex(of: id) else {
            return nil
        }
        return storedDocument.blocks[index]
    }

    public func index(of id: BlockInputBlockID) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return unlockedIndex(of: id)
    }

    public func replaceBlock(_ block: BlockInputBlock) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = unlockedIndex(of: block.id) else {
            return
        }
        storedDocument.blocks[index] = block
    }

    public func insertBlocks(_ blocks: [BlockInputBlock], at index: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard storedDocument.insertBlocks(blocks, at: index) != nil else {
            return
        }
        let insertionIndex = min(max(index, 0), storedDocument.blocks.count - blocks.count)
        indexesNeedRebuild = true
        for (offset, block) in blocks.enumerated() {
            let insertedIndex = insertionIndex + offset
            if let previousIndex = indexesByID[block.id],
               previousIndex <= insertedIndex {
                continue
            } else {
                indexesByID[block.id] = insertedIndex
            }
        }
    }

    public func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        lock.lock()
        defer { lock.unlock() }
        guard !ids.isEmpty else {
            return
        }
        if ids.count == 1,
           let id = ids.first,
           let index = unlockedIndex(of: id) {
            storedDocument.blocks.remove(at: index)
            indexesByID[id] = nil
            indexesNeedRebuild = true
            return
        }
        let deletedIDs = Set(ids)
        storedDocument.blocks.removeAll { deletedIDs.contains($0.id) }
        deletedIDs.forEach { indexesByID[$0] = nil }
        indexesNeedRebuild = true
    }

    public func moveBlock(withID id: BlockInputBlockID, to index: Int) {
        lock.lock()
        defer { lock.unlock() }
        if indexesNeedRebuild {
            rebuildIndexes()
        }
        guard let sourceIndex = unlockedIndex(of: id) else {
            return
        }
        let finalTargetIndex = min(max(index, 0), storedDocument.blocks.count - 1)
        guard finalTargetIndex != sourceIndex else {
            return
        }
        guard storedDocument.moveBlock(blockID: id, to: finalTargetIndex) != nil else {
            return
        }
        updateIndexesAfterMove(from: sourceIndex, to: finalTargetIndex)
    }

    private func unlockedIndex(of id: BlockInputBlockID) -> Int? {
        if let index = indexesByID[id],
           storedDocument.blocks.indices.contains(index),
           storedDocument.blocks[index].id == id {
            return index
        }
        guard indexesNeedRebuild else {
            return nil
        }
        rebuildIndexes()
        guard let index = indexesByID[id],
              storedDocument.blocks.indices.contains(index),
              storedDocument.blocks[index].id == id else {
            return nil
        }
        return index
    }

    private func updateIndexesAfterMove(from sourceIndex: Int, to targetIndex: Int) {
        // Reindex only the shifted run; duplicate IDs still need a full
        // first-occurrence rebuild to preserve stable lookup semantics.
        let affectedRange = min(sourceIndex, targetIndex)...max(sourceIndex, targetIndex)
        var affectedIDs = Set<BlockInputBlockID>()
        for index in affectedRange {
            let blockID = storedDocument.blocks[index].id
            guard affectedIDs.insert(blockID).inserted else {
                rebuildIndexes()
                return
            }
            if let existingIndex = indexesByID[blockID],
               !affectedRange.contains(existingIndex) {
                rebuildIndexes()
                return
            }
        }
        for index in affectedRange {
            indexesByID[storedDocument.blocks[index].id] = index
        }
        indexesNeedRebuild = false
    }

    private func rebuildIndexes() {
        indexesByID = Self.indexesByID(for: storedDocument)
        indexesNeedRebuild = false
    }

    private static func indexesByID(for document: BlockInputDocument) -> [BlockInputBlockID: Int] {
        var indexes: [BlockInputBlockID: Int] = [:]
        for (index, block) in document.blocks.enumerated() where indexes[block.id] == nil {
            indexes[block.id] = index
        }
        return indexes
    }
}
