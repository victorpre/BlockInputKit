import AppKit

extension BlockInputView: BlockInputBlockItemDelegate {
    func blockItemDidBeginEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
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
        guard let index = index(of: blockID),
              let beforeBlock = block(at: index),
              beforeBlock.id == blockID else {
            return
        }
        let beforeText = beforeBlock.text
        guard beforeText != text else {
            return
        }
        if beforeBlock.kind == .horizontalRule {
            configureBlockItem(item, block: beforeBlock)
            return
        }
        replaceCachedBlock(beforeBlock, at: index)
        let selectedRange = item.currentSelectedRange
        let proposedOffset = selectedRange.location + selectedRange.length
        if let shortcutSelection = applyTypingShortcutIfNeeded(
            blockID: blockID,
            proposedText: text,
            proposedUTF16Offset: proposedOffset,
            selectionBefore: capturedSelectionBefore
        ) {
            // Shortcuts can insert a new focused block and reload collection items,
            // so only reconfigure this item if it still owns the edited block.
            if case let .cursor(cursor) = shortcutSelection,
               cursor.blockID == blockID,
               item.representedBlockID == blockID {
                if let block = block(withID: blockID) {
                    configureBlockItem(item, block: block)
                }
                item.setSelectedRange(NSRange(location: cursor.utf16Offset, length: 0))
            }
            return
        }
        applyPlainTextChange(
            item: item,
            blockIndex: index,
            change: PlainTextChangeContext(
                beforeBlock: beforeBlock,
                afterText: text,
                proposedOffset: proposedOffset,
                selectionBefore: capturedSelectionBefore
            )
        )
    }

    private func applyPlainTextChange(
        item: BlockInputBlockItem,
        blockIndex index: Int,
        change: PlainTextChangeContext
    ) {
        let beforeSelection = change.selectionBefore ?? selection
        var afterBlock = change.beforeBlock
        afterBlock.text = change.afterText
        if let lineIndentationLevels = lineIndentationLevelsAfterTextChange(
            beforeBlock: change.beforeBlock,
            afterText: change.afterText,
            selectionBefore: change.selectionBefore
        ) {
            afterBlock.lineIndentationLevels = lineIndentationLevels
        }
        let didReplaceCachedBlock = replaceCachedBlock(afterBlock, at: index)
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: change.beforeBlock.id,
            utf16Offset: change.proposedOffset
        ))
        applySelection(afterSelection, notify: true)
        undoController?.registerTextEdit(
            blockID: change.beforeBlock.id,
            beforeText: change.beforeBlock.text,
            afterText: change.afterText,
            beforeLineIndentationLevels: change.beforeBlock.lineIndentationLevels,
            afterLineIndentationLevels: afterBlock.lineIndentationLevels,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        item.updateTextDependentChrome(for: afterBlock)
        if shouldInvalidateLayoutForTextChange(
            item: item,
            beforeBlock: change.beforeBlock,
            afterBlock: afterBlock
        ) {
            invalidateLayoutForBlock(at: index)
        }
        syncDocumentStore(.replaceBlock(afterBlock))
        if !didReplaceCachedBlock && isDocumentCacheSynchronized {
            refreshDocumentFromStore()
        }
        publishDocumentChange()
    }

    private func shouldInvalidateLayoutForTextChange(
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

    func blockItem(_ item: BlockInputBlockItem, didChangeSelectionIn blockID: BlockInputBlockID) {
        guard let block = block(withID: blockID),
              block.kind != .horizontalRule else {
            return
        }
        let range = item.currentSelectedRange
        if range.length == 0 {
            applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: range.location)), notify: true)
        } else {
            applySelection(.text(BlockInputTextRange(blockID: blockID, range: range)), notify: true)
        }
    }

    func blockItemDidRequestReturn(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard let block = block(withID: blockID) else {
            return true
        }
        let selectedRange = item.currentSelectedRange
        let currentBlock = BlockInputBlock(
            id: block.id,
            kind: block.kind,
            text: item.currentText,
            indentationLevel: block.indentationLevel,
            lineIndentationLevels: block.lineIndentationLevels
        )
        if block.kind.acceptsInlineReturn,
           !currentBlock.requiresStructuralReturnHandling(
               utf16Offset: selectedRange.location,
               selectedUTF16Length: selectedRange.length
           ) {
            return false
        }
        if selectedRange.length == 0 {
            applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: selectedRange.location)), notify: false)
        } else {
            applySelection(.text(BlockInputTextRange(blockID: blockID, range: selectedRange)), notify: false)
        }
        insertBlockBelowCurrentBlock()
        return true
    }

    func blockItemDidRequestMergeWithPreviousBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard item.currentSelectedRange.location == 0,
              item.currentSelectedRange.length == 0 else {
            return false
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        return mergeBlockIntoPrevious(blockID: blockID) != nil
    }

    func blockItemDidRequestDeleteEmptyBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard let block = block(withID: blockID) else {
            return false
        }
        if block.kind == .horizontalRule {
            return deleteSelectedHorizontalRuleForBackspaceOrDelete() != nil
        }
        guard block.isEmpty else {
            return false
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        return deleteCurrentEmptyBlockForBackspaceOrDelete() != nil
    }

    func blockItemDidRequestUnwrapBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool {
        guard let currentBlock = block(withID: blockID) else {
            return false
        }
        if currentBlock.kind == .horizontalRule,
           selection == .blocks([blockID]) {
            return deleteSelectedHorizontalRuleForBackspaceOrDelete() != nil
        }
        guard currentBlock.kind.canUnwrapToParagraph else {
            return false
        }
        applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0)), notify: false)
        guard let unwrapSelection = unwrapBlockToParagraph(blockID: blockID) else {
            return false
        }
        guard item.representedBlockID == blockID else {
            return true
        }
        if let updatedBlock = block(withID: blockID) {
            configureBlockItem(item, block: updatedBlock)
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
            configureBlockItem(item, block: block)
        }
        let nextSelection = document.selectAll(currentBlockID: blockID, currentSelection: selection)
        applySelection(nextSelection, notify: true)
        if case let .text(range) = nextSelection,
           range.blockID == blockID {
            item.setSelectedRange(range.range)
        } else if case .blocks = nextSelection, window != nil {
            restoreVisibleSelection()
        }
    }

    func selectAllFromActiveSelection() -> Bool {
        refreshDocumentFromStore()
        guard let blockID = activeBlockID,
              let nextSelection = document.selectAll(currentBlockID: blockID, currentSelection: selection) else {
            return false
        }
        applySelection(nextSelection, notify: true)
        restoreVisibleSelection()
        return true
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestUndoShortcut shortcut: BlockInputUndoShortcut
    ) -> Bool {
        performUndoShortcut(shortcut, preferredBlockID: blockID)
    }

    func blockItemDidRequestToggleChecklist(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        _ = toggleChecklistItem(blockID: blockID)
    }

    func blockItemDidRequestSelectHorizontalRule(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) {
        refreshDocumentFromStore()
        guard block(withID: blockID)?.kind == .horizontalRule else {
            return
        }
        selectedHorizontalRuleIndex = collectionView.indexPath(for: item)?.item
        hideDropIndicator()
        applySelection(.blocks([blockID]), notify: true)
        selectOnlyVisibleBlockItem(item)
        window?.makeFirstResponder(self)
        selectOnlyVisibleBlockItem(item)
        publishFocusChange(true)
    }

    func blockItemDidRequestIndent(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        selectedRange: NSRange
    ) {
        _ = performBlockIndentationEdit(
            named: "Indent Block",
            item: item,
            blockID: blockID,
            selectedRange: selectedRange,
            direction: .indent
        )
    }

    func blockItemDidRequestOutdent(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        selectedRange: NSRange
    ) {
        _ = performBlockIndentationEdit(
            named: "Outdent Block",
            item: item,
            blockID: blockID,
            selectedRange: selectedRange,
            direction: .outdent
        )
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestVerticalMovement direction: BlockInputVerticalMovementDirection,
        preferredTextContainerX: CGFloat?
    ) -> Bool {
        moveVertically(from: blockID, direction: direction, preferredTextContainerX: preferredTextContainerX)
    }

    func moveSelectedBlockVertically(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard case let .blocks(blockIDs) = selection,
              blockIDs.count == 1,
              let blockID = blockIDs.first else {
            return false
        }
        return moveVertically(from: blockID, direction: direction, preferredTextContainerX: nil)
    }

    private func moveVertically(
        from blockID: BlockInputBlockID,
        direction: BlockInputVerticalMovementDirection,
        preferredTextContainerX: CGFloat?
    ) -> Bool {
        refreshDocumentFromStore()
        guard let index = index(of: blockID) else {
            return false
        }
        let targetIndex = direction == .upward ? index - 1 : index + 1
        guard let targetBlock = block(at: targetIndex) else {
            return false
        }
        let resolvedPreferredTextContainerX = preferredNavigationX ?? preferredTextContainerX
        if targetBlock.kind == .horizontalRule {
            selectedHorizontalRuleIndex = targetIndex
            applySelection(.blocks([targetBlock.id]), notify: true)
            if let targetItem = visibleItem(for: targetBlock.id, refreshConfiguration: false) {
                selectOnlyVisibleBlockItem(targetItem)
            }
            window?.makeFirstResponder(self)
            preferredNavigationX = resolvedPreferredTextContainerX
            return true
        }
        let targetItem = visibleItem(for: targetBlock.id)
        let linePosition: BlockInputBlockItem.TextLinePosition = direction == .upward ? .last : .first
        let offset = targetItem?.utf16Offset(
            closestToTextContainerX: resolvedPreferredTextContainerX,
            linePosition: linePosition
        ) ?? (direction == .upward ? targetBlock.utf16Length : 0)
        focus(blockID: targetBlock.id, utf16Offset: offset)
        preferredNavigationX = resolvedPreferredTextContainerX
        return true
    }

    private func lineIndentationLevelsAfterTextChange(
        beforeBlock: BlockInputBlock,
        afterText: String,
        selectionBefore: BlockInputSelection?
    ) -> [Int]? {
        guard beforeBlock.kind.supportsIndentation else {
            return nil
        }
        guard let editRange = editRange(in: beforeBlock.id, selectionBefore: selectionBefore) else {
            return nil
        }
        return beforeBlock.lineIndentationLevelsAfterReplacingText(
            utf16Offset: editRange.location,
            selectedUTF16Length: editRange.length,
            updatedText: afterText
        )
    }

    private func editRange(
        in blockID: BlockInputBlockID,
        selectionBefore: BlockInputSelection?
    ) -> NSRange? {
        switch selectionBefore {
        case let .cursor(cursor) where cursor.blockID == blockID:
            return NSRange(location: cursor.utf16Offset, length: 0)
        case let .text(range) where range.blockID == blockID:
            return range.range
        default:
            return nil
        }
    }

    private func configureBlockItem(_ item: BlockInputBlockItem, block: BlockInputBlock) {
        item.configure(
            block: block,
            allowsReordering: allowsBlockReordering,
            accentColor: dropIndicatorColor,
            isSelected: isBlockSelected(block.id),
            delegate: self
        )
    }

}

private struct PlainTextChangeContext {
    var beforeBlock: BlockInputBlock
    var afterText: String
    var proposedOffset: Int
    var selectionBefore: BlockInputSelection?
}
