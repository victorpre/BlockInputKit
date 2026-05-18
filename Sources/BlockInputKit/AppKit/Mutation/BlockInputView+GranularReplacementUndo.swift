import AppKit

struct ReplacementInsertionUndoContext {
    var replacement: BlockInputBlock
    var replacementIndex: Int
    var insertedBlocks: [BlockInputBlock]
    var insertionIndex: Int
    var changedBlocks: [BlockInputBlock]
}

struct ReplacementDeletionUndoContext {
    var replacement: BlockInputBlock
    var replacementIndex: Int
    var deletedBlockIDs: [BlockInputBlockID]
    var deletionIndex: Int
    var changedBlocks: [BlockInputBlock]
}

extension BlockInputView {
    func applyGranularReplacementInsertionUndo(
        _ context: ReplacementInsertionUndoContext,
        selection: BlockInputSelection?
    ) -> Bool {
        let resolvedInsertionIndex = frontMatterPreservingInsertionIndex(
            context.insertionIndex,
            afterReplacing: context.replacement,
            at: context.replacementIndex
        )
        syncDocumentStore(.replaceBlock(context.replacement))
        syncDocumentStore(.insertBlocks(context.insertedBlocks, insertionIndex: resolvedInsertionIndex))
        _ = replaceCachedBlock(context.replacement, at: context.replacementIndex)
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: context.insertedBlocks.count) {
            guard document.insertBlocks(context.insertedBlocks, at: resolvedInsertionIndex) != nil else {
                return false
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        context.changedBlocks.forEach { syncDocumentStore(.replaceBlock($0)) }
        for changedBlock in context.changedBlocks {
            if let changedIndex = index(of: changedBlock.id) {
                _ = replaceCachedBlock(changedBlock, at: changedIndex)
            }
        }
        applySelection(validUndoSelection(selection), notify: true)
        if !reconfigureVisibleReplacement(context.replacement, at: context.replacementIndex) {
            collectionView.reloadItems(at: [IndexPath(item: context.replacementIndex, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
        }
        if context.insertedBlocks.count == 1 {
            insertVisibleBlock(at: resolvedInsertionIndex)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return true
    }

    func applyGranularReplacementDeletionUndo(
        _ context: ReplacementDeletionUndoContext,
        selection: BlockInputSelection?
    ) -> Bool {
        syncDocumentStore(.replaceBlock(context.replacement))
        context.changedBlocks.forEach { syncDocumentStore(.replaceBlock($0)) }
        syncDocumentStore(.deleteBlocks(context.deletedBlockIDs))
        _ = replaceCachedBlock(context.replacement, at: context.replacementIndex)
        for changedBlock in context.changedBlocks {
            if let changedIndex = index(of: changedBlock.id) {
                _ = replaceCachedBlock(changedBlock, at: changedIndex)
            }
        }
        if canSynchronizeCacheForGranularDeletion(deletedBlockCount: context.deletedBlockIDs.count) {
            let deletedIDs = Set(context.deletedBlockIDs)
            document.blocks.removeAll { deletedIDs.contains($0.id) }
        } else {
            markDocumentCacheUnsynchronized()
        }
        applySelection(validUndoSelection(selection), notify: true)
        if !reconfigureVisibleReplacement(context.replacement, at: context.replacementIndex) {
            collectionView.reloadItems(at: [IndexPath(item: context.replacementIndex, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
        }
        if context.deletedBlockIDs.count == 1 {
            deleteVisibleBlock(at: context.deletionIndex, deletedBlockIDs: context.deletedBlockIDs)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return true
    }
}
