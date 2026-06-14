import AppKit

public extension BlockInputView {
    /// Toggles the active checklist item, or a specific checklist item by ID.
    ///
    /// The edit is recorded on the structural undo stack because it changes block
    /// metadata rather than the block's owned text.
    @discardableResult
    func toggleChecklistItem(blockID: BlockInputBlockID? = nil) -> BlockInputSelection? {
        guard isEditable,
              let targetBlockID = blockID ?? activeBlockID,
              let index = index(of: targetBlockID),
              let beforeBlock = block(at: index),
              case let .checklistItem(isChecked) = beforeBlock.kind else {
            return nil
        }
        let beforeSelection = selection
        var afterBlock = beforeBlock
        afterBlock.kind = .checklistItem(isChecked: !isChecked)
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: targetBlockID,
            utf16Offset: afterBlock.utf16Length
        ))

        syncDocumentStore(.replaceBlock(afterBlock))
        _ = replaceCachedBlock(afterBlock, at: index)
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: "Toggle Checklist",
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

    // MARK: - Checklist Metadata Mutations

    /// Sets or clears the `whenDate` for a checklist item.
    @discardableResult
    func setChecklistWhenDate(blockID: BlockInputBlockID, dateString: String?) -> Bool {
        applyChecklistMetadataMutation(blockID: blockID, actionName: "Set When Date") { afterBlock in
            afterBlock.whenDate = dateString
            return true
        }
    }

    /// Sets or clears the `deadline` for a checklist item.
    @discardableResult
    func setChecklistDeadline(blockID: BlockInputBlockID, dateString: String?) -> Bool {
        applyChecklistMetadataMutation(blockID: blockID, actionName: "Set Deadline") { afterBlock in
            afterBlock.deadline = dateString
            return true
        }
    }

    /// Adds a tag to a checklist item. Duplicate tags are ignored.
    @discardableResult
    func addChecklistTag(blockID: BlockInputBlockID, tag: String) -> Bool {
        guard !tag.isEmpty else { return false }
        return applyChecklistMetadataMutation(blockID: blockID, actionName: "Add Tag") { afterBlock in
            guard !afterBlock.tags.contains(tag) else { return false }
            afterBlock.tags.append(tag)
            return true
        }
    }

    /// Removes a specific tag from a checklist item.
    @discardableResult
    func removeChecklistTag(blockID: BlockInputBlockID, tag: String) -> Bool {
        guard !tag.isEmpty else { return false }
        return applyChecklistMetadataMutation(blockID: blockID, actionName: "Remove Tag") { afterBlock in
            guard let removeIndex = afterBlock.tags.firstIndex(of: tag) else { return false }
            afterBlock.tags.remove(at: removeIndex)
            return true
        }
    }

    /// Clears all metadata (whenDate, deadline, tags) from a checklist item.
    @discardableResult
    func clearChecklistMetadata(blockID: BlockInputBlockID) -> Bool {
        applyChecklistMetadataMutation(blockID: blockID, actionName: "Clear Metadata") { afterBlock in
            afterBlock.whenDate = nil
            afterBlock.deadline = nil
            afterBlock.tags = []
            return true
        }
    }
}

private extension BlockInputView {
    @discardableResult
    func applyChecklistMetadataMutation(
        blockID: BlockInputBlockID,
        actionName: String,
        mutate: (inout BlockInputBlock) -> Bool
    ) -> Bool {
        guard isEditable,
              let index = index(of: blockID),
              let beforeBlock = block(at: index),
              case .checklistItem = beforeBlock.kind else {
            return false
        }
        let beforeSelection = selection
        var afterBlock = beforeBlock
        guard mutate(&afterBlock) else {
            return false
        }
        guard afterBlock != beforeBlock else {
            return false
        }
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: afterBlock.utf16Length
        ))

        syncDocumentStore(.replaceBlock(afterBlock))
        _ = replaceCachedBlock(afterBlock, at: index)
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: actionName,
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
        return true
    }
}
