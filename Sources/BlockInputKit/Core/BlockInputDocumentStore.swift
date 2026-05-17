import Foundation

/// Document storage boundary used by the editor and host app.
///
/// The editor reads blocks by index and stable ID so hosts can keep large
/// documents outside of the view. Large host stores should keep these indexed
/// read methods cheap and override the granular mutation methods to avoid full
/// document replacement on common editor operations.
public protocol BlockInputDocumentStore: AnyObject {
    /// Number of blocks currently loaded and available to the editor.
    var loadedBlockCount: Int { get }
    /// Total block count when it is known without finishing the load.
    var totalBlockCount: Int? { get }
    /// Whether every block has been loaded.
    var isComplete: Bool { get }
    /// Whether the store is currently loading another block batch.
    var isLoading: Bool { get }

    /// Returns the block at an ordered index.
    func block(at index: Int) -> BlockInputBlock?
    /// Returns the block with a stable ID.
    func block(withID id: BlockInputBlockID) -> BlockInputBlock?
    /// Returns the ordered index for a stable block ID.
    func index(of id: BlockInputBlockID) -> Int?
    /// Registers a store observer. Release or cancel the returned token to stop observing changes.
    func observeChanges(_ observer: @escaping @MainActor (BlockInputDocumentStoreChange) -> Void) -> BlockInputDocumentStoreObservation
    /// Loads the next available block batch. `limit` is a target count of complete parsed blocks, not source lines.
    @MainActor
    func loadNextBlockBatch(limit: Int) async throws
    /// Loads all remaining blocks into the editor-visible loaded prefix in batches.
    @MainActor
    func loadAllRemainingBlocks(limit: Int) async throws
    /// Returns a complete document snapshot for save/export.
    ///
    /// Progressive stores may materialize this without publishing append changes
    /// or expanding `loadedBlockCount`; the default implementation loads all
    /// remaining blocks into the visible prefix first.
    @MainActor
    func completeDocumentSnapshot(limit: Int) async throws -> BlockInputDocument
    /// Replaces the full document after broad structural mutations.
    func replaceDocument(_ document: BlockInputDocument)
    /// Replaces one block after a text or formatting mutation.
    ///
    /// The default implementation calls `replaceDocument(_:)` only for complete
    /// stores when the block exists and changes the current document.
    func replaceBlock(_ block: BlockInputBlock)
    /// Inserts blocks at an ordered index.
    ///
    /// The default implementation calls `replaceDocument(_:)` only for complete
    /// stores when the insertion changes the current document.
    func insertBlocks(_ blocks: [BlockInputBlock], at index: Int)
    /// Deletes blocks by stable ID.
    ///
    /// The default implementation calls `replaceDocument(_:)` only for complete
    /// stores when at least one block is removed.
    func deleteBlocks(withIDs ids: [BlockInputBlockID])
    /// Moves one block to a final ordered index.
    ///
    /// The default implementation calls `replaceDocument(_:)` only for complete
    /// stores when the block exists and its index changes.
    func moveBlock(withID id: BlockInputBlockID, to index: Int)
}

/// Append or loading state change emitted by a document store.
public enum BlockInputDocumentStoreChange: Sendable {
    /// Store loading state changed.
    case loadingStateChanged(isLoading: Bool)
    /// Blocks were appended at a tail range.
    case appendedBlocks(BlockInputDocumentStoreBatch)
    /// The full store document was replaced.
    case replacedDocument
    /// Loading failed.
    case failed(String)
}

/// Errors thrown by document-store progressive loading helpers.
public enum BlockInputDocumentStoreError: Error, Equatable, Sendable {
    /// A store reported that loading was incomplete but a batch load made no observable progress.
    case progressiveLoadMadeNoProgress
}

/// Tail append metadata for progressive stores.
public struct BlockInputDocumentStoreBatch: Equatable, Sendable {
    /// Ordered index where the batch starts.
    public var startIndex: Int
    /// Complete parsed blocks appended to the store.
    public var blocks: [BlockInputBlock]
    /// Whether the store is complete after this batch.
    public var isComplete: Bool

    /// Creates tail append metadata.
    public init(startIndex: Int, blocks: [BlockInputBlock], isComplete: Bool) {
        self.startIndex = startIndex
        self.blocks = blocks
        self.isComplete = isComplete
    }
}

/// Cancellable store observation token.
public final class BlockInputDocumentStoreObservation: @unchecked Sendable {
    private let cancellation: @Sendable () -> Void
    private var isCancelled = false
    private let lock = NSLock()

    /// Creates an observation token that runs `cancellation` once when cancelled or deallocated.
    public init(_ cancellation: @escaping @Sendable () -> Void = {}) {
        self.cancellation = cancellation
    }

    deinit {
        cancel()
    }

    /// Cancels the observation. Repeated calls are ignored.
    public func cancel() {
        lock.lock()
        let shouldCancel = !isCancelled
        isCancelled = true
        lock.unlock()
        if shouldCancel {
            cancellation()
        }
    }
}

public extension BlockInputDocumentStore {
    var totalBlockCount: Int? {
        isComplete ? loadedBlockCount : nil
    }

    var isComplete: Bool {
        true
    }

    var isLoading: Bool {
        false
    }

    func observeChanges(_ observer: @escaping @MainActor (BlockInputDocumentStoreChange) -> Void) -> BlockInputDocumentStoreObservation {
        BlockInputDocumentStoreObservation()
    }

    @MainActor
    func loadNextBlockBatch(limit: Int) async throws {}

    @MainActor
    func loadAllRemainingBlocks(limit: Int) async throws {
        while !isComplete {
            try Task.checkCancellation()
            let beforeCount = loadedBlockCount
            try await loadNextBlockBatch(limit: limit)
            guard isComplete || loadedBlockCount > beforeCount else {
                throw BlockInputDocumentStoreError.progressiveLoadMadeNoProgress
            }
        }
    }

    @MainActor
    func completeDocumentSnapshot(limit: Int) async throws -> BlockInputDocument {
        try await loadAllRemainingBlocks(limit: limit)
        return BlockInputDocument(blocks: (0..<loadedBlockCount).compactMap { block(at: $0) })
    }

    func replaceBlock(_ block: BlockInputBlock) {
        guard isComplete else {
            return
        }
        var updatedDocument = BlockInputDocument(blocks: (0..<loadedBlockCount).compactMap { self.block(at: $0) })
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
        guard isComplete else {
            return
        }
        var updatedDocument = BlockInputDocument(blocks: (0..<loadedBlockCount).compactMap { self.block(at: $0) })
        guard updatedDocument.insertBlocks(blocks, at: index) != nil else {
            return
        }
        replaceDocument(updatedDocument)
    }

    func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        guard isComplete else {
            return
        }
        guard !ids.isEmpty else {
            return
        }
        var updatedDocument = BlockInputDocument(blocks: (0..<loadedBlockCount).compactMap { self.block(at: $0) })
        let beforeDocument = updatedDocument
        let deletedIDs = Set(ids)
        updatedDocument.blocks.removeAll { deletedIDs.contains($0.id) }
        guard updatedDocument != beforeDocument else {
            return
        }
        replaceDocument(updatedDocument)
    }

    func moveBlock(withID id: BlockInputBlockID, to index: Int) {
        guard isComplete else {
            return
        }
        var updatedDocument = BlockInputDocument(blocks: (0..<loadedBlockCount).compactMap { self.block(at: $0) })
        guard updatedDocument.moveBlock(blockID: id, to: index) != nil else {
            return
        }
        replaceDocument(updatedDocument)
    }
}

/// In-memory store for simple editors and tests.
public final class BlockInputMemoryDocumentStore: BlockInputDocumentStore, @unchecked Sendable {
    /// Current document snapshot.
    public var document: BlockInputDocument {
        lock.lock()
        defer { lock.unlock() }
        return storedDocument
    }

    /// Number of blocks available to the editor.
    public var loadedBlockCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedDocument.blocks.count
    }

    /// Total block count.
    public var totalBlockCount: Int? {
        loadedBlockCount
    }

    private var storedDocument: BlockInputDocument
    private var indexesByID: [BlockInputBlockID: Int]
    private let lock = NSLock()
    // Inserts and deletes leave suffix indexes stale; rebuild lazily only when
    // a later lookup asks for one, keeping 100k-demo mutations responsive.
    private var indexesNeedRebuild = false

    /// Creates a memory-backed store for a complete document.
    public init(document: BlockInputDocument = BlockInputDocument()) {
        storedDocument = document
        indexesByID = Self.indexesByID(for: document)
    }

    @MainActor
    public func completeDocumentSnapshot(limit: Int) async throws -> BlockInputDocument {
        document.detachedStorage()
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
        guard storedDocument.moveBlockWithChangedBlocks(sourceIndex: sourceIndex, to: finalTargetIndex) != nil else {
            return
        }
        updateIndexesAfterMove(from: sourceIndex, to: finalTargetIndex)
    }

    func moveBlockWithoutNormalizing(withID id: BlockInputBlockID, to index: Int) {
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
        if abs(finalTargetIndex - sourceIndex) == 1 {
            storedDocument.blocks.swapAt(sourceIndex, finalTargetIndex)
            updateIndexesAfterMove(from: sourceIndex, to: finalTargetIndex)
            return
        }
        let block = storedDocument.blocks.remove(at: sourceIndex)
        storedDocument.blocks.insert(block, at: finalTargetIndex)
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
