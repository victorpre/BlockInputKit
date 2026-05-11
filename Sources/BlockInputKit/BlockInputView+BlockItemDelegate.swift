import AppKit

extension BlockInputView: BlockInputBlockItemDelegate {
    func blockItemDidBeginEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        refreshDocumentFromStore()
        guard index(of: blockID) != nil else {
            return
        }
        let offset = item.currentSelectedRange.location
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: offset)), notify: true)
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
        let beforeSelection = capturedSelectionBefore ?? selection
        document.blocks[index].text = text
        let selectedRange = item.currentSelectedRange
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: selectedRange.location + selectedRange.length
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
