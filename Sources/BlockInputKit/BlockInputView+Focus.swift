import AppKit

extension BlockInputView {
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
            item.configure(block: block, allowsReordering: allowsBlockReordering, delegate: self)
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
        collectionView.reloadData()
        collectionView.collectionViewLayout?.invalidateLayout()
        if selection != nil {
            // AppKit may recreate items either immediately or on the next pass;
            // restoring in both places keeps cursor/text selection stable.
            restoreVisibleSelection()
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.layoutSubtreeIfNeeded()
                self?.restoreVisibleSelection()
            }
        }
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
        switch selection {
        case let .cursor(cursor):
            lastFocusedBlockID = cursor.blockID
            pendingFocus = cursor
        case let .text(range):
            lastFocusedBlockID = range.blockID
            pendingFocus = nil
        case let .blocks(blockIDs):
            lastFocusedBlockID = blockIDs.first
            pendingFocus = nil
        case nil:
            pendingFocus = nil
        }
        if notify {
            onSelectionChange?(selection)
        }
    }
}
