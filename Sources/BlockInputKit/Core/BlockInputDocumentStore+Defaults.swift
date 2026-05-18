import Foundation

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
