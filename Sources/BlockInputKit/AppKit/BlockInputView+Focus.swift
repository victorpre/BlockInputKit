import AppKit

extension BlockInputView {
    var isEditorFirstResponder: Bool {
        guard let firstResponder = window?.firstResponder else {
            return false
        }
        if firstResponder === self {
            return true
        }
        var candidateView = firstResponder as? NSView
        while let view = candidateView {
            if view === self {
                return true
            }
            candidateView = view.superview
        }
        return false
    }

    var activeBlockID: BlockInputBlockID? {
        let candidateID: BlockInputBlockID?
        switch selection {
        case let .cursor(cursor):
            candidateID = cursor.blockID
        case let .text(range):
            candidateID = range.blockID
        case let .blocks(ids):
            // Store-backed documents can change under an existing multi-block selection.
            // Keep commands anchored to the first selected block that still exists.
            if let validBlockID = ids.first(where: { index(of: $0) != nil }) {
                return validBlockID
            }
            candidateID = nil
        case nil:
            candidateID = lastFocusedBlockID
        }
        if let candidateID, index(of: candidateID) != nil {
            return candidateID
        }
        return block(at: 0)?.id
    }

    func cursorForRestoredFocus() -> BlockInputCursor {
        if let cursor = pendingFocus, index(of: cursor.blockID) != nil {
            return cursor
        }
        if selection != nil,
           let blockID = activeBlockID,
           let block = block(withID: blockID) {
            return BlockInputCursor(blockID: blockID, utf16Offset: block.utf16Length)
        }
        if let lastFocusedBlockID, let block = block(withID: lastFocusedBlockID) {
            return BlockInputCursor(blockID: lastFocusedBlockID, utf16Offset: block.utf16Length)
        }
        let firstBlock = block(at: 0) ?? document.blocks[0]
        return BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0)
    }

    @discardableResult
    func resignEditorFocus() -> Bool {
        guard isEditorFirstResponder else {
            return true
        }
        window?.endEditing(for: nil)
        let didResign = window?.makeFirstResponder(nil) ?? false
        let isResigned = !isEditorFirstResponder
        if didResign || isResigned {
            publishFocusLossIfNeeded()
        }
        return didResign || isResigned
    }

    func publishFocusChange(_ isFocused: Bool) {
        guard publishedFocusState != isFocused else {
            return
        }
        publishedFocusState = isFocused
        onFocusChange?(isFocused)
    }

    func publishFocusLossIfNeeded() {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !isEditorFirstResponder else {
                return
            }
            publishFocusChange(false)
        }
    }

    func visibleItem(
        for blockID: BlockInputBlockID,
        refreshConfiguration: Bool = true
    ) -> BlockInputBlockItem? {
        guard let index = index(of: blockID),
              let block = block(at: index) else {
            return nil
        }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
        collectionView.layoutSubtreeIfNeeded()
        guard let item = collectionView.item(at: indexPath) as? BlockInputBlockItem else {
            return nil
        }
        if refreshConfiguration {
            item.configure(
                block: block,
                allowsReordering: allowsBlockReordering,
                accentColor: dropIndicatorColor,
                isSelected: isBlockSelected(block.id),
                delegate: self
            )
        }
        return item
    }

    func focusVisibleItem(for cursor: BlockInputCursor) {
        guard let item = visibleItem(for: cursor.blockID) else {
            pendingFocus = cursor
            return
        }
        item.focusText(atUTF16Offset: cursor.utf16Offset)
        pendingFocus = nil
    }

    func restoreVisibleTextSelection(_ textRange: BlockInputTextRange) {
        guard let item = visibleItem(for: textRange.blockID) else {
            return
        }
        item.focusText(inUTF16Range: textRange.range)
    }

    func restoreVisibleBlockSelection(_ blockIDs: [BlockInputBlockID]) {
        if let firstBlockID = blockIDs.first {
            _ = visibleItem(for: firstBlockID, refreshConfiguration: false)
        }
        if !isBecomingFirstResponder, window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
    }

    func restoreVisibleSelection() {
        switch selection {
        case let .cursor(cursor):
            focusVisibleItem(for: cursor)
        case let .text(textRange):
            restoreVisibleTextSelection(textRange)
        case let .blocks(blockIDs):
            restoreVisibleBlockSelection(blockIDs)
        case nil:
            break
        }
    }

    func reloadDataKeepingFocus() {
        focusRestoreGeneration += 1
        let generation = focusRestoreGeneration
        collectionView.reloadData()
        collectionView.collectionViewLayout?.invalidateLayout()
        if selection != nil {
            // AppKit may recreate items either immediately or on the next pass;
            // restoring in both places keeps cursor/text selection stable.
            restoreVisibleSelection()
            DispatchQueue.main.async { [weak self] in
                guard let self, focusRestoreGeneration == generation else {
                    return
                }
                collectionView.layoutSubtreeIfNeeded()
                restoreVisibleSelection()
            }
        }
    }

    func reloadDataWithoutRestoringFocus() {
        focusRestoreGeneration += 1
        collectionView.reloadData()
        collectionView.collectionViewLayout?.invalidateLayout()
        collectionView.layoutSubtreeIfNeeded()
    }

    func clearStaleFocusState() {
        if let selection, !containsValidSelection(selection) {
            applySelection(nil, notify: true)
        }
        if let cursor = pendingFocus, !containsValidCursor(cursor) {
            pendingFocus = nil
        }
        if let lastFocusedBlockID, index(of: lastFocusedBlockID) == nil {
            self.lastFocusedBlockID = nil
        }
    }

    func applySelection(_ selection: BlockInputSelection?, notify: Bool) {
        self.selection = selection
        preferredNavigationX = nil
        switch selection {
        case let .cursor(cursor):
            lastFocusedBlockID = cursor.blockID
            pendingFocus = cursor
            selectedHorizontalRuleIndex = nil
        case let .text(range):
            lastFocusedBlockID = range.blockID
            pendingFocus = nil
            selectedHorizontalRuleIndex = nil
        case let .blocks(blockIDs):
            lastFocusedBlockID = blockIDs.first
            pendingFocus = nil
        case nil:
            pendingFocus = nil
            selectedHorizontalRuleIndex = nil
        }
        if notify {
            onSelectionChange?(selection)
        }
        updateVisibleBlockSelectionHighlights()
    }

    func isBlockSelected(_ blockID: BlockInputBlockID) -> Bool {
        guard case let .blocks(blockIDs) = selection else {
            return false
        }
        return blockIDs.contains(blockID)
    }

    var selectedBlockCount: Int {
        guard case let .blocks(blockIDs) = selection else {
            return 0
        }
        return blockIDs.count
    }

    private func updateVisibleBlockSelectionHighlights() {
        for item in collectionView.visibleItems().compactMap({ $0 as? BlockInputBlockItem }) {
            guard let blockID = item.representedBlockID else {
                item.setBlockSelection(false)
                continue
            }
            item.setBlockSelection(isBlockSelected(blockID))
        }
    }

    func selectOnlyVisibleBlockItem(_ selectedItem: BlockInputBlockItem) {
        for item in collectionView.visibleItems().compactMap({ $0 as? BlockInputBlockItem }) {
            item.setBlockSelection(item === selectedItem)
        }
    }
}
