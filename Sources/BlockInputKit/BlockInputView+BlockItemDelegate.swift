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
            configureBlockItem(item, block: document.blocks[index])
            return
        }
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
            if case let .cursor(cursor) = shortcutSelection, cursor.blockID == blockID {
                if let block = block(withID: blockID) {
                    configureBlockItem(item, block: block)
                }
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
        refreshDocumentFromStore()
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
