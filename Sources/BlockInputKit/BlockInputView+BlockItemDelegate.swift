import AppKit

extension BlockInputView: BlockInputBlockItemDelegate {
    func blockItemDidBeginEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        refreshDocumentFromStore()
        guard index(of: blockID) != nil else {
            return
        }
        publishFocusChange(true)
        let offset = item.currentSelectedRange.location
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: offset)), notify: true)
    }

    func blockItemDidEndEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        publishFocusLossIfNeeded()
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didChangeText text: String,
        selectionBefore capturedSelectionBefore: BlockInputSelection?
    ) {
        refreshDocumentFromStore()
        guard let index = index(of: blockID), document.blocks.indices.contains(index) else {
            return
        }
        let beforeText = document.blocks[index].text
        guard beforeText != text else {
            return
        }
        if document.blocks[index].kind == .horizontalRule {
            item.configure(block: document.blocks[index], allowsReordering: allowsBlockReordering, delegate: self)
            return
        }
        let selectedRange = item.currentSelectedRange
        let proposedOffset = selectedRange.location + selectedRange.length
        if let shortcutSelection = applyTypingShortcutIfNeeded(
            blockID: blockID,
            proposedText: text,
            proposedUTF16Offset: proposedOffset
        ) {
            if let block = block(withID: blockID) {
                item.configure(block: block, allowsReordering: allowsBlockReordering, delegate: self)
            }
            if case let .cursor(cursor) = shortcutSelection, cursor.blockID == blockID {
                item.setSelectedRange(NSRange(location: cursor.utf16Offset, length: 0))
            }
            return
        }
        let beforeSelection = capturedSelectionBefore ?? selection
        document.blocks[index].text = text
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: proposedOffset
        ))
        applySelection(afterSelection, notify: true)
        undoController?.registerTextEdit(
            blockID: blockID,
            beforeText: beforeText,
            afterText: text,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        collectionView.collectionViewLayout?.invalidateLayout()
        syncDocumentStore(.replaceBlock(document.blocks[index]))
        publishDocumentChange()
    }

    func blockItem(_ item: BlockInputBlockItem, didChangeSelectionIn blockID: BlockInputBlockID) {
        refreshDocumentFromStore()
        guard index(of: blockID) != nil else {
            return
        }
        let range = item.currentSelectedRange
        if range.length == 0 {
            applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: range.location)), notify: true)
        } else {
            applySelection(.text(BlockInputTextRange(blockID: blockID, range: range)), notify: true)
        }
    }

    func blockItemDidRequestReturn(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        refreshDocumentFromStore()
        guard index(of: blockID) != nil else {
            return
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: item.currentSelectedRange.location)), notify: false)
        insertBlockBelowCurrentBlock()
    }

    func blockItemDidRequestDeleteEmptyBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        refreshDocumentFromStore()
        guard let block = block(withID: blockID), block.isEmpty else {
            return false
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        return deleteCurrentEmptyBlockForBackspaceOrDelete() != nil
    }

    func blockItemDidRequestUnwrapBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        refreshDocumentFromStore()
        guard let currentBlock = block(withID: blockID), currentBlock.kind.canUnwrapToParagraph else {
            return false
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        guard let unwrapSelection = unwrapBlockToParagraph(blockID: blockID) else {
            return false
        }
        if let updatedBlock = block(withID: blockID) {
            item.configure(block: updatedBlock, allowsReordering: allowsBlockReordering, delegate: self)
        }
        if case let .cursor(cursor) = unwrapSelection, cursor.blockID == blockID {
            item.setSelectedRange(NSRange(location: cursor.utf16Offset, length: 0))
        }
        return true
    }

    func blockItemDidRequestSelectAll(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        refreshDocumentFromStore()
        guard let block = block(withID: blockID) else {
            return
        }
        if item.currentText != block.text {
            item.configure(block: block, allowsReordering: allowsBlockReordering, delegate: self)
        }
        let nextSelection = document.selectAll(currentBlockID: blockID, currentSelection: selection)
        applySelection(nextSelection, notify: true)
        if case let .text(range) = nextSelection,
           range.blockID == blockID {
            item.setSelectedRange(range.range)
        }
    }

    func blockItemDidRequestToggleChecklist(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        _ = toggleChecklistItem(blockID: blockID)
    }

    func blockItemDidRequestIndent(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        _ = performStructuralEdit(
            named: "Indent Block",
            storeSyncAction: { _, afterDocument, _ in
                afterDocument.block(withID: blockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
            },
            edit: { document in
                document.indentBlock(blockID: blockID)
            }
        )
    }

    func blockItemDidRequestOutdent(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        _ = performStructuralEdit(
            named: "Outdent Block",
            storeSyncAction: { _, afterDocument, _ in
                afterDocument.block(withID: blockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
            },
            edit: { document in
                document.outdentBlock(blockID: blockID)
            }
        )
    }

    func blockItemDidRequestMoveToPreviousBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        refreshDocumentFromStore()
        guard let index = index(of: blockID), let previous = block(at: index - 1) else {
            return false
        }
        focus(blockID: previous.id, utf16Offset: previous.utf16Length)
        return true
    }

    func blockItemDidRequestMoveToNextBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        refreshDocumentFromStore()
        guard let index = index(of: blockID), let next = block(at: index + 1) else {
            return false
        }
        focus(blockID: next.id, utf16Offset: 0)
        return true
    }
}
