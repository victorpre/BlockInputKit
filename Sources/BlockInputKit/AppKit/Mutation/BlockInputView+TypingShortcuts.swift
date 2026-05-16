import AppKit

extension BlockInputView {
    func applyTypingShortcutIfNeeded(
        blockID: BlockInputBlockID,
        proposedText: String,
        proposedUTF16Offset: Int,
        selectionBefore: BlockInputSelection?
    ) -> BlockInputSelection? {
        guard let blockBeforeEdit = block(withID: blockID) else {
            return nil
        }
        guard let shortcut = document.typingShortcut(
            for: blockBeforeEdit,
            proposedText: proposedText,
            proposedUTF16Offset: proposedUTF16Offset
        ) else {
            return nil
        }
        let selectionBeforeEdit = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: min(proposedUTF16Offset, blockBeforeEdit.utf16Length)
        ))
        let undoSelectionBefore = validSelectionBeforeTypingShortcut(
            selectionBefore,
            blockBeforeEdit: blockBeforeEdit
        ) ?? selectionBeforeEdit
        if let selection = applyGranularTypingShortcutIfPossible(
            shortcut,
            blockBeforeEdit: blockBeforeEdit,
            selectionBefore: undoSelectionBefore
        ) {
            return selection
        }
        return performStructuralEdit(
            named: "Format Block",
            selectionBeforeOverride: undoSelectionBefore,
            storeSyncAction: { _, afterDocument, _ in
                guard let block = afterDocument.block(withID: blockID),
                      block.kind != .horizontalRule else {
                    return .replaceDocument
                }
                return afterDocument.block(withID: blockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
            },
            edit: { document in
                document.applyTypingShortcut(blockID: blockID, shortcut: shortcut)
            }
        )
    }

    private func applyGranularTypingShortcutIfPossible(
        _ shortcut: BlockInputDocument.TypingShortcut,
        blockBeforeEdit: BlockInputBlock,
        selectionBefore: BlockInputSelection
    ) -> BlockInputSelection? {
        guard let index = index(of: blockBeforeEdit.id) else {
            return nil
        }
        if shortcut.kind == .horizontalRule {
            return applyGranularHorizontalRuleShortcut(
                shortcut,
                blockBeforeEdit: blockBeforeEdit,
                index: index,
                selectionBefore: selectionBefore
            )
        }
        var afterBlock = blockBeforeEdit
        afterBlock.kind = shortcut.kind
        afterBlock.text = shortcut.text
        if !shortcut.preservesIndentation {
            afterBlock.indentationLevel = 0
        }
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockBeforeEdit.id,
            utf16Offset: min(shortcut.cursorOffset, afterBlock.utf16Length)
        ))
        syncDocumentStore(.replaceBlock(afterBlock))
        _ = replaceCachedBlock(afterBlock, at: index)
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: "Format Block",
            beforeBlock: blockBeforeEdit,
            afterBlock: afterBlock,
            selectionBefore: selectionBefore,
            selectionAfter: afterSelection
        )
        if !reconfigureVisibleReplacement(afterBlock, at: index),
           !shouldDeferGranularCountLayout {
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
            restoreMountedSelection()
        }
        publishDocumentChange()
        return afterSelection
    }

    private func applyGranularHorizontalRuleShortcut(
        _ shortcut: BlockInputDocument.TypingShortcut,
        blockBeforeEdit: BlockInputBlock,
        index: Int,
        selectionBefore: BlockInputSelection
    ) -> BlockInputSelection? {
        var afterBlock = blockBeforeEdit
        afterBlock.kind = .horizontalRule
        afterBlock.text = shortcut.text
        if !shortcut.preservesIndentation {
            afterBlock.indentationLevel = 0
        }
        let insertedBlock = BlockInputBlock(kind: .paragraph, text: shortcut.insertedBlockText ?? "")
        let insertedBlocks = [insertedBlock]
        let insertionIndex = index + 1
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: insertedBlocks.count) {
            guard replaceCachedBlock(afterBlock, at: index),
                  document.insertBlocks(insertedBlocks, at: insertionIndex) != nil else {
                return nil
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: insertedBlock.id,
            utf16Offset: min(shortcut.cursorOffset, insertedBlock.utf16Length)
        ))
        syncDocumentStore(.replaceBlock(afterBlock))
        syncDocumentStore(.insertBlocks(insertedBlocks, insertionIndex: insertionIndex))
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementInsertionStructuralEdit(BlockInputReplaceInsertEdit(
            actionName: "Format Block",
            beforeBlock: blockBeforeEdit,
            afterBlock: afterBlock,
            insertedBlocks: insertedBlocks,
            insertionIndex: insertionIndex,
            selectionBefore: selectionBefore,
            selectionAfter: afterSelection
        ))
        if shouldDeferGranularCountLayout {
            _ = reconfigureVisibleReplacement(afterBlock, at: index)
            insertVisibleBlock(at: insertionIndex)
        } else {
            reloadDataKeepingFocus()
        }
        publishDocumentChange()
        return afterSelection
    }

    func unwrapBlockToParagraph(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID),
              let beforeBlock = block(at: index),
              beforeBlock.kind.canUnwrapToParagraph else {
            return nil
        }
        let beforeSelection = selection
        var afterBlock = beforeBlock
        let cursorOffset: Int
        if let marker = afterBlock.kind.plainTextRevealMarker {
            afterBlock.kind = .paragraph
            afterBlock.text = marker + afterBlock.text
            cursorOffset = (marker as NSString).length
        } else {
            afterBlock.kind = .paragraph
            cursorOffset = 0
        }
        afterBlock.indentationLevel = 0
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: cursorOffset
        ))

        syncDocumentStore(.replaceBlock(afterBlock))
        _ = replaceCachedBlock(afterBlock, at: index)
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: "Unformat Block",
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        if !reconfigureVisibleReplacement(afterBlock, at: index),
           !shouldDeferGranularCountLayout {
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
            restoreMountedSelection()
        }
        publishDocumentChange()
        return afterSelection
    }
}

private func validSelectionBeforeTypingShortcut(
    _ selection: BlockInputSelection?,
    blockBeforeEdit block: BlockInputBlock
) -> BlockInputSelection? {
    guard let selection else {
        return nil
    }
    switch selection {
    case let .cursor(cursor):
        guard cursor.blockID == block.id,
              cursor.utf16Offset >= 0,
              cursor.utf16Offset <= block.utf16Length else {
            return nil
        }
        return selection
    case let .text(textRange):
        guard textRange.blockID == block.id,
              textRange.range.location >= 0,
              textRange.range.length >= 0,
              textRange.range.location <= block.utf16Length,
              textRange.range.length <= block.utf16Length - textRange.range.location else {
            return nil
        }
        return selection
    case .blocks, .mixed:
        return nil
    }
}
