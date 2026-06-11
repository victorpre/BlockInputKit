import AppKit

extension BlockInputView {
    func extractMetadataTokenIfNeeded(
        blockID: BlockInputBlockID,
        beforeBlock: BlockInputBlock,
        proposedText: String,
        proposedUTF16Offset: Int,
        selectionBefore: BlockInputSelection?
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        guard case .checklistItem = beforeBlock.kind else {
            return nil
        }
        guard let beforeBlockIndex = index(of: blockID) else {
            return nil
        }
        guard let extraction = document.metadataTokenExtraction(
            for: beforeBlock,
            proposedText: proposedText,
            proposedUTF16Offset: proposedUTF16Offset
        ) else {
            return nil
        }

        let beforeSelection = selection
        let afterBlock: BlockInputBlock = {
            var block = beforeBlock
            block.text = extraction.cleanText
            if let whenDate = extraction.whenDate { block.whenDate = whenDate }
            if let deadline = extraction.deadline { block.deadline = deadline }
            let newTags = extraction.tags.filter { !block.tags.contains($0) }
            block.tags.append(contentsOf: newTags)
            return block
        }()

        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: extraction.cursorOffset
        ))

        syncDocumentStore(.replaceBlock(afterBlock))
        _ = replaceCachedBlock(afterBlock, at: beforeBlockIndex)
        applySelection(afterSelection, notify: true)

        undoController?.registerBlockReplacementStructuralEdit(
            actionName: "Extract Metadata",
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )

        if !reconfigureVisibleReplacement(afterBlock, at: beforeBlockIndex),
           !shouldDeferGranularCountLayout {
            collectionView.reloadItems(at: [IndexPath(item: beforeBlockIndex, section: 0)])
            collectionView.layoutSubtreeIfNeeded()
            restoreMountedSelection()
        }

        publishDocumentChange()
        return afterSelection
    }
}
