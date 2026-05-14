import Foundation

extension BlockInputView {
    func moveStoreBackedLargeListBlock(
        blockID: BlockInputBlockID,
        to targetIndex: Int
    ) -> BlockInputSelection? {
        guard documentStore != nil,
              blockCount > largeDocumentCacheMutationLimit,
              let sourceIndex = index(of: blockID) else {
            return nil
        }
        let finalTargetIndex = min(max(targetIndex, 0), blockCount - 1)
        guard finalTargetIndex != sourceIndex else {
            return nil
        }
        guard let move = boundedListMove(
            blockID: blockID,
            sourceIndex: sourceIndex,
            targetIndex: finalTargetIndex
        ) else {
            return nil
        }

        let selectionBefore = selection
        let selectionAfter = move.result.selection
        syncDocumentStore(.moveBlockAndReplaceChangedBlocks(
            blockID,
            targetIndex: finalTargetIndex,
            changedBlocks: move.afterChangedBlocks
        ))
        markDocumentCacheUnsynchronized()
        applySelection(selectionAfter, notify: true)
        undoController?.registerBlockMoveStructuralEdit(BlockInputMoveEdit(
            actionName: "Move Block",
            blockID: blockID,
            beforeIndex: sourceIndex,
            afterIndex: finalTargetIndex,
            beforeChangedBlocks: move.beforeChangedBlocks,
            afterChangedBlocks: move.afterChangedBlocks,
            selectionBefore: selectionBefore,
            selectionAfter: selectionAfter
        ))
        applyGranularMoveLayout(
            sourceIndex: sourceIndex,
            targetIndex: finalTargetIndex,
            changedBlocks: move.afterChangedBlocks
        )
        publishDocumentChange()
        return selectionAfter
    }

    func applyGranularMoveUndo(
        blockID: BlockInputBlockID,
        to targetIndex: Int,
        changedBlocks: [BlockInputBlock],
        selection: BlockInputSelection?
    ) -> Bool {
        guard let sourceIndex = index(of: blockID) else {
            return false
        }
        syncDocumentStore(.moveBlockAndReplaceChangedBlocks(
            blockID,
            targetIndex: targetIndex,
            changedBlocks: changedBlocks
        ))
        if documentStore != nil {
            markDocumentCacheUnsynchronized()
        } else {
            _ = document.moveBlock(blockID: blockID, to: targetIndex)
            for block in changedBlocks {
                if let index = document.index(of: block.id) {
                    document.blocks[index] = block
                }
            }
        }
        applySelection(validUndoSelection(selection), notify: true)
        applyGranularMoveLayout(
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            changedBlocks: changedBlocks
        )
        publishDocumentChange()
        return true
    }

    private func applyGranularMoveLayout(
        sourceIndex: Int,
        targetIndex: Int,
        changedBlocks: [BlockInputBlock]
    ) {
        itemHeightCache.invalidateFrom(min(sourceIndex, targetIndex))
        for block in changedBlocks {
            itemHeightCache.invalidate(blockID: block.id)
        }
        guard shouldDeferGranularCountLayout else {
            reloadDataKeepingFocus()
            return
        }
        reconfigureMountedBlocksAfterGranularMove(
            sourceIndex: sourceIndex,
            targetIndex: targetIndex
        )
        for block in changedBlocks {
            if let index = index(of: block.id) {
                _ = reconfigureVisibleReplacement(block, at: index)
            }
        }
        restoreMountedSelection()
    }

    private func reconfigureMountedBlocksAfterGranularMove(
        sourceIndex: Int,
        targetIndex: Int
    ) {
        let affectedRange = min(sourceIndex, targetIndex)...max(sourceIndex, targetIndex)
        let indexedItems = collectionView.visibleItems().compactMap { item -> (index: Int, item: BlockInputBlockItem)? in
            guard let blockItem = item as? BlockInputBlockItem,
                  let itemIndex = collectionView.indexPath(for: item)?.item,
                  affectedRange.contains(itemIndex),
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
            resizeVisibleItem(blockItem, for: block)
            return (itemIndex, blockItem)
        }.sorted { $0.index < $1.index }
        guard let first = indexedItems.first else {
            return
        }
        reflowVisibleItemsAfterHeightChange(startingAt: first.index)
    }

    private func boundedListMove(
        blockID: BlockInputBlockID,
        sourceIndex: Int,
        targetIndex: Int
    ) -> BoundedListMove? {
        let lowerBound = min(sourceIndex, targetIndex)
        let upperBound = max(sourceIndex, targetIndex)
        guard let sourceBlock = block(at: sourceIndex),
              sourceBlock.id == blockID,
              sourceBlock.kind.isListItem else {
            return nil
        }
        for index in lowerBound...upperBound {
            guard block(at: index)?.kind.isListItem == true else {
                return nil
            }
        }

        let windowStart = previousListSeedIndex(before: lowerBound) ?? lowerBound
        let windowBlocks = (windowStart...upperBound).compactMap { block(at: $0) }
        guard windowBlocks.count == upperBound - windowStart + 1 else {
            return nil
        }

        var blocksByID: [BlockInputBlockID: BlockInputBlock] = [:]
        for block in windowBlocks where blocksByID[block.id] == nil {
            blocksByID[block.id] = block
        }
        var windowDocument = BlockInputDocument(blocks: windowBlocks)
        guard let result = windowDocument.moveBlockWithChangedBlocks(
            sourceIndex: sourceIndex - windowStart,
            to: targetIndex - windowStart
        ) else {
            return nil
        }
        let beforeChangedBlocks = result.changedBlocks.compactMap { blocksByID[$0.id] }
        guard beforeChangedBlocks.count == result.changedBlocks.count else {
            return nil
        }
        return BoundedListMove(
            result: result,
            beforeChangedBlocks: beforeChangedBlocks,
            afterChangedBlocks: result.changedBlocks
        )
    }

    private func previousListSeedIndex(before index: Int) -> Int? {
        guard index > 0,
              block(at: index - 1)?.kind.isListItem == true else {
            return nil
        }
        return index - 1
    }
}

private struct BoundedListMove {
    var result: BlockInputMoveResult
    var beforeChangedBlocks: [BlockInputBlock]
    var afterChangedBlocks: [BlockInputBlock]
}

private extension BlockInputBlockKind {
    var isListItem: Bool {
        switch self {
        case .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .paragraph, .heading, .code, .horizontalRule, .quote:
            return false
        }
    }
}
