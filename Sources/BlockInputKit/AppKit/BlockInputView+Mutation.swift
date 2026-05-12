import AppKit

let largeDocumentCacheMutationLimit = 10_000

extension BlockInputView {
    enum StoreSyncAction {
        case replaceDocument
        case replaceBlock(BlockInputBlock)
        case insertBlocks([BlockInputBlock], insertionIndex: Int)
        case deleteBlocks([BlockInputBlockID])
        case moveBlock(BlockInputBlockID, targetIndex: Int)
    }

    func publishDocumentChange() {
        guard let onDocumentChange else {
            return
        }
        guard shouldDeferDocumentChangeSnapshot else {
            // A threshold-crossing edit can supersede an older deferred snapshot
            // while the duplicate cache is still stale.
            cancelPendingDocumentSnapshot()
            if !isDocumentCacheSynchronized {
                refreshDocumentFromStore()
            }
            onDocumentChange(document)
            return
        }
        scheduleDeferredDocumentSnapshot()
    }

    func syncDocumentStore(_ action: StoreSyncAction) {
        guard let documentStore else {
            return
        }
        switch action {
        case .replaceDocument:
            documentStore.replaceDocument(document)
        case let .replaceBlock(block):
            documentStore.replaceBlock(block)
        case let .insertBlocks(blocks, insertionIndex):
            documentStore.insertBlocks(blocks, at: insertionIndex)
        case let .deleteBlocks(blockIDs):
            documentStore.deleteBlocks(withIDs: blockIDs)
        case let .moveBlock(blockID, targetIndex):
            documentStore.moveBlock(withID: blockID, to: targetIndex)
        }
        publishDocumentMutation(action.documentChange(document: document))
    }

    func refreshDocumentFromStore() {
        if let documentStore {
            document = documentStore.document.detachedStorage()
            isDocumentCacheSynchronized = true
        }
    }

    func canSynchronizeCacheForGranularInsertion(insertedBlockCount: Int) -> Bool {
        guard documentStore != nil else {
            return true
        }
        // Above this size, duplicating the store mutation with a local array
        // insert is visible in the 100k demo's repeated list-item Return path.
        return document.blocks.count + insertedBlockCount <= largeDocumentCacheMutationLimit
    }

    func canSynchronizeCacheForGranularDeletion(deletedBlockCount: Int) -> Bool {
        guard documentStore != nil else {
            return true
        }
        return document.blocks.count - deletedBlockCount <= largeDocumentCacheMutationLimit
    }

    func markDocumentCacheUnsynchronized() {
        isDocumentCacheSynchronized = false
    }

    @discardableResult
    func replaceCachedBlock(_ block: BlockInputBlock, at index: Int) -> Bool {
        if document.blocks.indices.contains(index),
           document.blocks[index].id == block.id {
            document.blocks[index] = block
            return true
        }

        guard isDocumentCacheSynchronized else {
            return false
        }
        refreshDocumentFromStore()
        guard document.blocks.indices.contains(index),
              document.blocks[index].id == block.id else {
            return false
        }
        document.blocks[index] = block
        return true
    }

    func invalidateLayoutForBlock(
        at index: Int,
        editedItem: BlockInputBlockItem? = nil,
        block: BlockInputBlock? = nil
    ) {
        if let block {
            itemHeightCache.invalidate(blockID: block.id)
        } else {
            itemHeightCache.invalidate(at: index)
        }
        if let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            let context = NSCollectionViewFlowLayoutInvalidationContext()
            context.invalidateFlowLayoutDelegateMetrics = true
            flowLayout.invalidateLayout(with: context)
        } else {
            collectionView.collectionViewLayout?.invalidateLayout()
        }
        collectionView.layoutSubtreeIfNeeded()
        if let editedItem, let block {
            resizeVisibleItem(editedItem, for: block)
        }
        reflowVisibleItemsAfterHeightChange(startingAt: index)
    }

    func deleteVisibleBlock(at index: Int, deletedBlockIDs: [BlockInputBlockID] = []) {
        itemHeightCache.deleteItems(at: index, count: 1, deletedBlockIDs: deletedBlockIDs)
        let indexPath = IndexPath(item: index, section: 0)
        if shouldDeferGranularCountLayout {
            reconfigureMountedBlocksAfterGranularCountChange(startingAt: index)
            return
        }
        collectionView.deleteItems(at: [indexPath])
        collectionView.layoutSubtreeIfNeeded()
        restoreMountedSelection()
    }

    var shouldDeferGranularCountLayout: Bool {
        blockCount > largeDocumentCacheMutationLimit
    }

    func reconfigureMountedBlocksAfterGranularCountChange(startingAt index: Int) {
        let intendedSelection = selection
        let indexedItems = collectionView.visibleItems().compactMap { item -> (index: Int, item: BlockInputBlockItem)? in
            guard let blockItem = item as? BlockInputBlockItem,
                  let itemIndex = collectionView.indexPath(for: item)?.item,
                  itemIndex >= index,
                  let block = block(at: itemIndex) else {
                return nil
            }
            blockItem.configure(
                block: block,
                allowsReordering: allowsBlockReordering,
                accentColor: dropIndicatorColor,
                isSelected: isBlockSelected(block.id),
                delegate: self
            )
            // The mounted item may now represent a different block kind; keep
            // its frame height in sync before manually reflowing visible rows.
            resizeVisibleItem(blockItem, for: block)
            return (itemIndex, blockItem)
        }.sorted { $0.index < $1.index }
        guard let first = indexedItems.first else {
            if selection != intendedSelection {
                applySelection(intendedSelection, notify: false)
            }
            restoreMountedSelection()
            return
        }
        reflowVisibleItemsAfterHeightChange(startingAt: first.index)
        if selection != intendedSelection {
            applySelection(intendedSelection, notify: false)
        }
        restoreMountedSelection()
    }

    @discardableResult
    func reconfigureVisibleReplacement(_ block: BlockInputBlock, at index: Int) -> Bool {
        let indexPath = IndexPath(item: index, section: 0)
        guard shouldDeferGranularCountLayout,
              let item = collectionView.item(at: indexPath) as? BlockInputBlockItem else {
            return false
        }
        item.configure(
            block: block,
            allowsReordering: allowsBlockReordering,
            accentColor: dropIndicatorColor,
            isSelected: isBlockSelected(block.id),
            delegate: self
        )
        resizeVisibleItem(item, for: block)
        reflowVisibleItemsAfterHeightChange(startingAt: index)
        restoreMountedSelection()
        return true
    }

    func resizeVisibleItem(_ item: BlockInputBlockItem, for block: BlockInputBlock) {
        let itemWidth = item.view.bounds.width > 0 ? item.view.bounds.width : collectionView.bounds.width
        let textWidth = max(
            itemWidth - BlockInputBlockItem.horizontalChromeWidth(allowsReordering: allowsBlockReordering),
            120
        )
        let height = BlockInputBlockItem.height(for: block, textWidth: textWidth)
        guard abs(item.view.frame.height - height) > 0.5 else {
            return
        }
        item.view.frame.size.height = height
        item.view.needsLayout = true
        item.view.layoutSubtreeIfNeeded()
    }

    func reflowVisibleItemsAfterHeightChange(startingAt index: Int) {
        let indexedItems = collectionView.visibleItems().compactMap { item -> (index: Int, item: NSCollectionViewItem)? in
            guard let itemIndex = collectionView.indexPath(for: item)?.item,
                  itemIndex >= index else {
                return nil
            }
            return (itemIndex, item)
        }.sorted { $0.index < $1.index }
        guard let first = indexedItems.first, first.index == index else {
            return
        }

        // NSCollectionViewFlowLayout can leave stale origins for already-mounted
        // rows after a delegate-height change; fix only the visible run so the
        // edited block does not overlap the next mounted blocks while typing.
        var nextMinY = first.item.view.frame.minY
        for indexedItem in indexedItems {
            var frame = indexedItem.item.view.frame
            frame.origin.y = nextMinY
            indexedItem.item.view.frame = frame
            nextMinY = frame.maxY
        }
    }

    func performStructuralEdit(
        named actionName: String,
        selectionBeforeOverride: BlockInputSelection? = nil,
        storeSyncAction: (
            _ beforeDocument: BlockInputDocument,
            _ afterDocument: BlockInputDocument,
            _ afterSelection: BlockInputSelection
        ) -> StoreSyncAction = { _, _, _ in .replaceDocument },
        edit: (inout BlockInputDocument) -> BlockInputSelection?
    ) -> BlockInputSelection? {
        refreshDocumentFromStore()
        let beforeDocument = document
        let beforeSelection = selectionBeforeOverride ?? selection
        guard let afterSelection = edit(&document) else {
            return nil
        }
        guard beforeDocument != document else {
            applySelection(afterSelection, notify: beforeSelection != afterSelection)
            return nil
        }
        syncDocumentStore(storeSyncAction(beforeDocument, document, afterSelection))
        applySelection(afterSelection, notify: true)
        undoController?.registerStructuralEdit(
            actionName: actionName,
            beforeDocument: beforeDocument,
            afterDocument: document,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        reloadDataKeepingFocus()
        publishDocumentChange()
        return afterSelection
    }

    func applyUndoResult(_ result: BlockInputUndoResult, storeSyncAction: StoreSyncAction? = nil) {
        syncDocumentStore(storeSyncAction ?? defaultStoreSyncAction(for: result))
        let restoredSelection = result.selection.flatMap { selection -> BlockInputSelection? in
            containsValidSelection(selection) ? selection : nil
        }
        applySelection(restoredSelection, notify: true)
        reloadDataKeepingFocus()
        publishDocumentChange()
    }

    @discardableResult
    func applyGranularUndoResult(_ result: BlockInputUndoResult) -> Bool {
        if let replacedBlock = result.replacedBlock,
           let replacementIndex = index(of: replacedBlock.id) {
            if let insertedBlocks = result.insertedBlocks,
               let insertionIndex = result.insertionIndex {
                return applyGranularReplacementInsertionUndo(
                    replacement: replacedBlock,
                    replacementIndex: replacementIndex,
                    insertedBlocks: insertedBlocks,
                    insertionIndex: insertionIndex,
                    selection: result.selection
                )
            }
            if let deletedBlockIDs = result.deletedBlockIDs,
               let firstDeletedBlockID = deletedBlockIDs.first,
               let deletionIndex = index(of: firstDeletedBlockID) {
                return applyGranularReplacementDeletionUndo(
                    replacement: replacedBlock,
                    replacementIndex: replacementIndex,
                    deletedBlockIDs: deletedBlockIDs,
                    deletionIndex: deletionIndex,
                    selection: result.selection
                )
            }
            return applyGranularReplacementUndo(replacedBlock, at: replacementIndex, selection: result.selection)
        }

        if let insertedBlocks = result.insertedBlocks,
           let insertionIndex = result.insertionIndex {
            return applyGranularInsertionUndo(insertedBlocks, at: insertionIndex, selection: result.selection)
        }

        if let deletedBlockIDs = result.deletedBlockIDs,
           let firstDeletedBlockID = deletedBlockIDs.first,
           let deletionIndex = index(of: firstDeletedBlockID) {
            return applyGranularDeletionUndo(deletedBlockIDs, at: deletionIndex, selection: result.selection)
        }

        return false
    }

    func applyGranularBlockReplacement(
        _ block: BlockInputBlock,
        at index: Int,
        selection: BlockInputSelection?
    ) -> Bool {
        syncDocumentStore(.replaceBlock(block))
        _ = replaceCachedBlock(block, at: index)
        applySelection(validUndoSelection(selection), notify: true)
        itemHeightCache.invalidate(blockID: block.id)
        if reconfigureVisibleReplacement(block, at: index) {
            publishDocumentChange()
            return true
        }
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        collectionView.layoutSubtreeIfNeeded()
        restoreMountedSelection()
        publishDocumentChange()
        return true
    }

    func applyGranularReplacementUndo(
        _ block: BlockInputBlock,
        at index: Int,
        selection: BlockInputSelection?
    ) -> Bool {
        applyGranularBlockReplacement(block, at: index, selection: selection)
    }

    private func applyGranularReplacementInsertionUndo(
        replacement: BlockInputBlock,
        replacementIndex: Int,
        insertedBlocks: [BlockInputBlock],
        insertionIndex: Int,
        selection: BlockInputSelection?
    ) -> Bool {
        syncDocumentStore(.replaceBlock(replacement))
        syncDocumentStore(.insertBlocks(insertedBlocks, insertionIndex: insertionIndex))
        _ = replaceCachedBlock(replacement, at: replacementIndex)
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: insertedBlocks.count) {
            guard document.insertBlocks(insertedBlocks, at: insertionIndex) != nil else {
                return false
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        applySelection(validUndoSelection(selection), notify: true)
        itemHeightCache.invalidate(blockID: replacement.id)
        if !reconfigureVisibleReplacement(replacement, at: replacementIndex) {
            collectionView.reloadItems(at: [IndexPath(item: replacementIndex, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
        }
        if insertedBlocks.count == 1 {
            insertVisibleBlock(at: insertionIndex)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return true
    }

    private func applyGranularReplacementDeletionUndo(
        replacement: BlockInputBlock,
        replacementIndex: Int,
        deletedBlockIDs: [BlockInputBlockID],
        deletionIndex: Int,
        selection: BlockInputSelection?
    ) -> Bool {
        syncDocumentStore(.replaceBlock(replacement))
        syncDocumentStore(.deleteBlocks(deletedBlockIDs))
        _ = replaceCachedBlock(replacement, at: replacementIndex)
        if canSynchronizeCacheForGranularDeletion(deletedBlockCount: deletedBlockIDs.count) {
            let deletedIDs = Set(deletedBlockIDs)
            document.blocks.removeAll { deletedIDs.contains($0.id) }
        } else {
            markDocumentCacheUnsynchronized()
        }
        applySelection(validUndoSelection(selection), notify: true)
        itemHeightCache.invalidate(blockID: replacement.id)
        if !reconfigureVisibleReplacement(replacement, at: replacementIndex) {
            collectionView.reloadItems(at: [IndexPath(item: replacementIndex, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
        }
        if deletedBlockIDs.count == 1 {
            deleteVisibleBlock(at: deletionIndex, deletedBlockIDs: deletedBlockIDs)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return true
    }

    private func applyGranularInsertionUndo(
        _ blocks: [BlockInputBlock],
        at insertionIndex: Int,
        selection: BlockInputSelection?
    ) -> Bool {
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: blocks.count) {
            guard document.insertBlocks(blocks, at: insertionIndex) != nil else {
                return false
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        syncDocumentStore(.insertBlocks(blocks, insertionIndex: insertionIndex))
        applySelection(validUndoSelection(selection), notify: true)
        if blocks.count == 1 {
            insertVisibleBlock(at: insertionIndex)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return true
    }

    private func applyGranularDeletionUndo(
        _ blockIDs: [BlockInputBlockID],
        at deletionIndex: Int,
        selection: BlockInputSelection?
    ) -> Bool {
        if canSynchronizeCacheForGranularDeletion(deletedBlockCount: blockIDs.count) {
            let deletedIDs = Set(blockIDs)
            document.blocks.removeAll { deletedIDs.contains($0.id) }
        } else {
            markDocumentCacheUnsynchronized()
        }
        syncDocumentStore(.deleteBlocks(blockIDs))
        applySelection(validUndoSelection(selection), notify: true)
        if blockIDs.count == 1 {
            deleteVisibleBlock(at: deletionIndex, deletedBlockIDs: blockIDs)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return true
    }

    private func validUndoSelection(_ selection: BlockInputSelection?) -> BlockInputSelection? {
        selection.flatMap { containsValidSelection($0) ? $0 : nil }
    }

    private func defaultStoreSyncAction(for result: BlockInputUndoResult) -> StoreSyncAction {
        if result.replacedBlock != nil,
           result.insertedBlocks != nil || result.deletedBlockIDs != nil {
            return .replaceDocument
        }
        if let replacedBlock = result.replacedBlock {
            return .replaceBlock(replacedBlock)
        }
        if let insertedBlocks = result.insertedBlocks,
           let insertionIndex = result.insertionIndex {
            return .insertBlocks(insertedBlocks, insertionIndex: insertionIndex)
        }
        if let deletedBlockIDs = result.deletedBlockIDs {
            return .deleteBlocks(deletedBlockIDs)
        }
        return .replaceDocument
    }
}

private extension BlockInputView.StoreSyncAction {
    func documentChange(document: BlockInputDocument) -> BlockInputDocumentChange {
        switch self {
        case .replaceDocument:
            return .replaceDocument(document)
        case let .replaceBlock(block):
            return .replaceBlock(block)
        case let .insertBlocks(blocks, insertionIndex):
            return .insertBlocks(blocks, index: insertionIndex)
        case let .deleteBlocks(blockIDs):
            return .deleteBlocks(blockIDs)
        case let .moveBlock(blockID, targetIndex):
            return .moveBlock(blockID, index: targetIndex)
        }
    }
}
