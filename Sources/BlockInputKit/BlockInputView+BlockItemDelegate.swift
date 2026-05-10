import AppKit

extension BlockInputView: BlockInputBlockItemDelegate {
    func blockItemDidBeginEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        let offset = item.currentSelectedRange.location
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: offset)), notify: true)
    }

    func blockItem(_ item: BlockInputBlockItem, blockID: BlockInputBlockID, didChangeText text: String) {
        guard let index = document.index(of: blockID) else {
            return
        }
        let beforeText = document.blocks[index].text
        guard beforeText != text else {
            return
        }
        let beforeSelection = selection
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
        publishDocumentChange()
    }

    func blockItem(_ item: BlockInputBlockItem, didChangeSelectionIn blockID: BlockInputBlockID) {
        let range = item.currentSelectedRange
        if range.length == 0 {
            applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: range.location)), notify: true)
        } else {
            applySelection(.text(BlockInputTextRange(blockID: blockID, range: range)), notify: true)
        }
    }

    func blockItemDidRequestReturn(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: item.currentSelectedRange.location)), notify: false)
        insertBlockBelowCurrentBlock()
    }

    func blockItemDidRequestDeleteEmptyBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard let block = document.block(withID: blockID), block.isEmpty else {
            return false
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        return deleteCurrentEmptyBlockForBackspaceOrDelete() != nil
    }

    func blockItemDidRequestSelectAll(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        let nextSelection = document.selectAll(currentBlockID: blockID, currentSelection: selection)
        applySelection(nextSelection, notify: true)
        if case let .text(range) = nextSelection,
           range.blockID == blockID {
            item.setSelectedRange(range.range)
        }
    }

    func blockItemDidRequestIndent(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        _ = performStructuralEdit(named: "Indent Block") { document in
            document.indentBlock(blockID: blockID)
        }
    }

    func blockItemDidRequestOutdent(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        _ = performStructuralEdit(named: "Outdent Block") { document in
            document.outdentBlock(blockID: blockID)
        }
    }

    func blockItemDidRequestMoveToPreviousBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard let index = document.index(of: blockID), document.blocks.indices.contains(index - 1) else {
            return false
        }
        let previous = document.blocks[index - 1]
        focus(blockID: previous.id, utf16Offset: previous.utf16Length)
        return true
    }

    func blockItemDidRequestMoveToNextBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard let index = document.index(of: blockID), document.blocks.indices.contains(index + 1) else {
            return false
        }
        focus(blockID: document.blocks[index + 1].id, utf16Offset: 0)
        return true
    }
}
