import Foundation

/// In-memory progressive store for already parsed block sources.
///
/// The editor sees only the loaded prefix until callers request more batches.
/// Complete snapshots are materialized from the full source without appending
/// hidden rows to the editor-visible prefix.
public final class BlockInputProgressiveMemoryDocumentStore: BlockInputDocumentStore, @unchecked Sendable {
    /// Number of source blocks currently visible to the editor.
    public var loadedBlockCount: Int {
        locked { loadedBlocks.count }
    }

    /// Total source block count.
    public var totalBlockCount: Int? {
        locked { sourceBlocks.count }
    }

    /// Whether every source block has been appended to the editor-visible prefix.
    public var isComplete: Bool {
        locked { nextSourceIndex >= sourceBlocks.count }
    }

    /// Whether a batch load is currently appending to the visible prefix.
    public private(set) var isLoading: Bool {
        get {
            locked { loading }
        }
        set {
            locked {
                loading = newValue
            }
        }
    }

    private var sourceBlocks: [BlockInputBlock]
    private var loadedBlocks: [BlockInputBlock]
    private var nextSourceIndex: Int
    private var indexesByID: [BlockInputBlockID: Int]
    private var observers: [UUID: @MainActor (BlockInputDocumentStoreChange) -> Void] = [:]
    private var loadWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private let lock = NSLock()
    private var loading = false

    /// Creates a progressive store with an initial loaded prefix.
    ///
    /// Empty sources are normalized to a single editable paragraph. `initialLimit`
    /// is clamped to at least one block and at most the normalized source count.
    public init(blocks: [BlockInputBlock], initialLimit: Int) {
        let normalizedBlocks = blocks.isEmpty ? [BlockInputBlock.emptyParagraph()] : blocks
        let loadedCount = min(max(initialLimit, 1), normalizedBlocks.count)
        sourceBlocks = normalizedBlocks
        loadedBlocks = Array(normalizedBlocks.prefix(loadedCount))
        nextSourceIndex = loadedCount
        indexesByID = Self.indexesByID(for: loadedBlocks)
    }

    /// Registers for progressive append, replacement, and loading failure changes.
    public func observeChanges(_ observer: @escaping @MainActor (BlockInputDocumentStoreChange) -> Void) -> BlockInputDocumentStoreObservation {
        let id = UUID()
        locked {
            observers[id] = observer
        }
        return BlockInputDocumentStoreObservation { [weak self] in
            guard let self else {
                return
            }
            locked {
                observers[id] = nil
            }
        }
    }

    /// Appends the next unloaded source blocks to the editor-visible prefix.
    @MainActor
    public func loadNextBlockBatch(limit: Int) async throws {
        let loadingObservers: [@MainActor (BlockInputDocumentStoreChange) -> Void]
        loadLoop:
        while true {
            switch beginLoadIfPossible() {
            case .started(let observers):
                loadingObservers = observers
                break loadLoop
            case .wait:
                await waitForCurrentLoad()
                try Task.checkCancellation()
                continue
            case .finished:
                return
            }
        }
        loadingObservers.forEach { $0(.loadingStateChanged(isLoading: true)) }

        do {
            try Task.checkCancellation()
            emitFinishedLoad(finishLoad(limit: limit))
        } catch is CancellationError {
            emitCancelledLoad(finishFailedLoad())
            throw CancellationError()
        } catch {
            emitFailedLoad(finishFailedLoad(), error: error)
            throw error
        }
    }

    /// Appends every remaining source block to the editor-visible prefix.
    @MainActor
    public func loadAllRemainingBlocks(limit: Int) async throws {
        while !isComplete {
            try Task.checkCancellation()
            try await loadNextBlockBatch(limit: limit)
        }
    }

    /// Returns a complete source snapshot without changing the visible prefix.
    @MainActor
    public func completeDocumentSnapshot(limit: Int) async throws -> BlockInputDocument {
        locked {
            BlockInputDocument(blocks: sourceBlocks)
        }.detachedStorage()
    }

    /// Returns the loaded block at `index`, or nil when the index has not been loaded.
    public func block(at index: Int) -> BlockInputBlock? {
        locked {
            guard loadedBlocks.indices.contains(index) else {
                return nil
            }
            return loadedBlocks[index]
        }
    }

    /// Returns a loaded block by ID.
    public func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        locked {
            guard let index = indexesByID[id],
                  loadedBlocks.indices.contains(index),
                  loadedBlocks[index].id == id else {
                return nil
            }
            return loadedBlocks[index]
        }
    }

    /// Returns the loaded index for a block ID.
    public func index(of id: BlockInputBlockID) -> Int? {
        locked { indexesByID[id] }
    }

    /// Replaces the entire source and loaded prefix.
    public func replaceDocument(_ document: BlockInputDocument) {
        locked {
            loadedBlocks = document.blocks
            sourceBlocks = document.blocks
            nextSourceIndex = document.blocks.count
            indexesByID = Self.indexesByID(for: loadedBlocks)
        }
        emit(.replacedDocument)
    }

    /// Replaces a loaded block and its matching source block.
    public func replaceBlock(_ block: BlockInputBlock) {
        locked {
            guard let index = indexesByID[block.id], loadedBlocks.indices.contains(index) else {
                return
            }
            loadedBlocks[index] = block
            if let sourceIndex = sourceBlocks.firstIndex(where: { $0.id == block.id }) {
                sourceBlocks[sourceIndex] = block
            }
        }
    }

    /// Inserts loaded blocks into both the visible prefix and full source.
    public func insertBlocks(_ blocks: [BlockInputBlock], at index: Int) {
        locked {
            let insertionIndex = min(max(index, 0), loadedBlocks.count)
            loadedBlocks.insert(contentsOf: blocks, at: insertionIndex)
            sourceBlocks.insert(contentsOf: blocks, at: insertionIndex)
            nextSourceIndex += blocks.count
            indexesByID = Self.indexesByID(for: loadedBlocks)
        }
    }

    /// Deletes matching loaded and unloaded source blocks.
    public func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        locked {
            let deletedIDs = Set(ids)
            let loadedDeleteCount = loadedBlocks.reduce(0) { count, block in
                count + (deletedIDs.contains(block.id) ? 1 : 0)
            }
            loadedBlocks.removeAll { deletedIDs.contains($0.id) }
            sourceBlocks.removeAll { deletedIDs.contains($0.id) }
            nextSourceIndex = max(0, nextSourceIndex - loadedDeleteCount)
            nextSourceIndex = min(nextSourceIndex, sourceBlocks.count)
            indexesByID = Self.indexesByID(for: loadedBlocks)
        }
    }

    /// Moves a loaded block in both the visible prefix and full source.
    public func moveBlock(withID id: BlockInputBlockID, to index: Int) {
        locked {
            if let sourceIndex = indexesByID[id], loadedBlocks.indices.contains(sourceIndex) {
                let block = loadedBlocks.remove(at: sourceIndex)
                let targetIndex = min(max(index, 0), loadedBlocks.count)
                loadedBlocks.insert(block, at: targetIndex)
                if let sourceBlockIndex = sourceBlocks.firstIndex(where: { $0.id == id }) {
                    let sourceBlock = sourceBlocks.remove(at: sourceBlockIndex)
                    sourceBlocks.insert(sourceBlock, at: min(targetIndex, sourceBlocks.count))
                }
            }
            indexesByID = Self.indexesByID(for: loadedBlocks)
        }
    }

    private func emit(_ change: BlockInputDocumentStoreChange) {
        let observers = locked { Array(self.observers.values) }
        Task { @MainActor in
            observers.forEach { $0(change) }
        }
    }

    private func beginLoadIfPossible() -> LoadStart {
        locked {
            if loading {
                return .wait
            }
            guard nextSourceIndex < sourceBlocks.count else {
                return .finished
            }
            loading = true
            return .started(Array(observers.values))
        }
    }

    private func finishLoad(limit: Int) -> FinishedLoad {
        locked {
            let resolvedLimit = max(limit, 1)
            let startIndex = loadedBlocks.count
            let endIndex = min(sourceBlocks.count, nextSourceIndex + resolvedLimit)
            let newBlocks = Array(sourceBlocks[nextSourceIndex..<endIndex])
            loadedBlocks.append(contentsOf: newBlocks)
            nextSourceIndex = endIndex
            for (offset, block) in newBlocks.enumerated() where indexesByID[block.id] == nil {
                indexesByID[block.id] = startIndex + offset
            }
            loading = false
            return FinishedLoad(
                batch: BlockInputDocumentStoreBatch(
                    startIndex: startIndex,
                    blocks: newBlocks,
                    isComplete: nextSourceIndex >= sourceBlocks.count
                ),
                observers: Array(observers.values),
                waiters: removeLoadWaiters()
            )
        }
    }

    private func finishFailedLoad() -> FailedLoad {
        locked {
            loading = false
            return FailedLoad(observers: Array(observers.values), waiters: removeLoadWaiters())
        }
    }

    @MainActor
    private func emitFinishedLoad(_ finishedLoad: FinishedLoad) {
        finishedLoad.waiters.forEach { $0.resume() }
        finishedLoad.observers.forEach { $0(.appendedBlocks(finishedLoad.batch)) }
        finishedLoad.observers.forEach { $0(.loadingStateChanged(isLoading: false)) }
    }

    @MainActor
    private func emitCancelledLoad(_ cancelledLoad: FailedLoad) {
        cancelledLoad.waiters.forEach { $0.resume() }
        cancelledLoad.observers.forEach { $0(.loadingStateChanged(isLoading: false)) }
    }

    @MainActor
    private func emitFailedLoad(_ failedLoad: FailedLoad, error: Error) {
        failedLoad.waiters.forEach { $0.resume() }
        failedLoad.observers.forEach { $0(.loadingStateChanged(isLoading: false)) }
        failedLoad.observers.forEach { $0(.failed(error.localizedDescription)) }
    }

    private func removeLoadWaiters() -> [CheckedContinuation<Void, Never>] {
        let waiters = Array(loadWaiters.values)
        loadWaiters.removeAll()
        return waiters
    }

    private func waitForCurrentLoad() async {
        await withCheckedContinuation { continuation in
            let shouldResume = locked {
                guard loading else {
                    return true
                }
                loadWaiters[UUID()] = continuation
                return false
            }
            if shouldResume {
                continuation.resume()
            }
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func indexesByID(for blocks: [BlockInputBlock]) -> [BlockInputBlockID: Int] {
        var indexes: [BlockInputBlockID: Int] = [:]
        for (index, block) in blocks.enumerated() where indexes[block.id] == nil {
            indexes[block.id] = index
        }
        return indexes
    }
}

private enum LoadStart {
    case started([@MainActor (BlockInputDocumentStoreChange) -> Void])
    case wait
    case finished
}

private struct FinishedLoad {
    var batch: BlockInputDocumentStoreBatch
    var observers: [@MainActor (BlockInputDocumentStoreChange) -> Void]
    var waiters: [CheckedContinuation<Void, Never>]
}

private struct FailedLoad {
    var observers: [@MainActor (BlockInputDocumentStoreChange) -> Void]
    var waiters: [CheckedContinuation<Void, Never>]
}
