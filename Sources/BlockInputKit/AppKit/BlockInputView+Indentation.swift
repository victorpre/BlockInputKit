import AppKit

extension BlockInputView {
    enum IndentationDirection {
        case indent
        case outdent
    }

    func performBlockIndentationEdit(
        named actionName: String,
        item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        selectedRange: NSRange,
        direction: IndentationDirection
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID),
              let beforeBlock = block(at: index),
              beforeBlock.kind.supportsIndentation else {
            return nil
        }
        let beforeSelection = selection
        guard let (afterBlock, afterSelection) = indentedBlock(
            from: beforeBlock,
            blockID: blockID,
            selectedRange: selectedRange,
            direction: direction
        ) else {
            return nil
        }
        guard beforeBlock != afterBlock else {
            applySelection(afterSelection, notify: beforeSelection != afterSelection)
            return nil
        }
        // Indentation is a one-block structural edit. Keep it off the generic
        // document-snapshot path so Tab stays responsive in large documents.
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
        if item.representedBlockID == blockID {
            item.updateTextDependentChrome(for: afterBlock)
            if case let .cursor(cursor) = afterSelection {
                item.setSelectedRange(NSRange(location: cursor.utf16Offset, length: 0))
            }
            item.view.needsLayout = true
            item.view.layoutSubtreeIfNeeded()
            if heightChangesAfterIndentation(item: item, beforeBlock: beforeBlock, afterBlock: afterBlock) {
                resizeVisibleItem(item, for: afterBlock)
                invalidateLayoutForBlock(at: index, editedItem: item, block: afterBlock)
            }
        }
        publishDocumentChange()
        return afterSelection
    }

    private func heightChangesAfterIndentation(
        item: BlockInputBlockItem,
        beforeBlock: BlockInputBlock,
        afterBlock: BlockInputBlock
    ) -> Bool {
        let itemWidth = item.view.bounds.width > 0 ? item.view.bounds.width : collectionView.bounds.width
        let textWidth = max(
            itemWidth - BlockInputBlockItem.horizontalChromeWidth(allowsReordering: allowsBlockReordering),
            120
        )
        let beforeHeight = BlockInputBlockItem.height(for: beforeBlock, textWidth: textWidth)
        let afterHeight = BlockInputBlockItem.height(for: afterBlock, textWidth: textWidth)
        return abs(beforeHeight - afterHeight) > 0.5
    }

    private func indentedBlock(
        from beforeBlock: BlockInputBlock,
        blockID: BlockInputBlockID,
        selectedRange: NSRange,
        direction: IndentationDirection
    ) -> (BlockInputBlock, BlockInputSelection)? {
        var afterBlock = beforeBlock
        if beforeBlock.text.contains("\n") {
            let lineIndex = beforeBlock.lineIndex(containingUTF16Offset: selectedRange.location)
            guard updateLineIndentation(in: &afterBlock, lineIndex: lineIndex, direction: direction) else {
                return nil
            }
        } else {
            guard updateBlockIndentation(in: &afterBlock, direction: direction) else {
                return nil
            }
        }
        let selection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: selectedRange.location
        ))
        return (afterBlock, selection)
    }

    private func updateLineIndentation(
        in block: inout BlockInputBlock,
        lineIndex: Int,
        direction: IndentationDirection
    ) -> Bool {
        let currentLevel = block.indentationLevel(forLine: lineIndex)
        switch direction {
        case .indent:
            block.setIndentationLevel(currentLevel + 1, forLine: lineIndex)
            return true
        case .outdent:
            guard currentLevel > 0 else {
                return false
            }
            block.setIndentationLevel(currentLevel - 1, forLine: lineIndex)
            return true
        }
    }

    private func updateBlockIndentation(
        in block: inout BlockInputBlock,
        direction: IndentationDirection
    ) -> Bool {
        switch direction {
        case .indent:
            block.indentationLevel += 1
            return true
        case .outdent:
            guard block.indentationLevel > 0 else {
                return false
            }
            block.indentationLevel = max(0, block.indentationLevel - 1)
            return true
        }
    }
}
