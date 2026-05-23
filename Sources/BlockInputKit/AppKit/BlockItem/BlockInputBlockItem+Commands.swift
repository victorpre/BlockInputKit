import AppKit

extension BlockInputBlockItem {
    func requestCopyActiveSelection() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestCopyActiveSelection(self, blockID: blockID) ?? false
    }

    func requestCutActiveSelection() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestCutActiveSelection(self, blockID: blockID) ?? false
    }

    func requestPasteActiveSelection() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestPasteActiveSelection(self, blockID: blockID) ?? false
    }

    func requestUndoShortcut(_ shortcut: BlockInputUndoShortcut) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(self, blockID: blockID, didRequestUndoShortcut: shortcut) ?? false
    }

    func requestReturn() -> Bool {
        guard let blockID else {
            return true
        }
        return delegate?.blockItemDidRequestReturn(self, blockID: blockID) ?? true
    }

    func requestDeleteEmptyBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestDeleteEmptyBlock(self, blockID: blockID) ?? false
    }

    func requestUnwrapBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestUnwrapBlock(self, blockID: blockID) ?? false
    }

    func requestSelectAll() {
        guard let blockID else {
            return
        }
        if tableView.selectAllInActiveCellIfNeeded() {
            return
        }
        delegate?.blockItemDidRequestSelectAll(self, blockID: blockID)
    }

    func requestSelectHorizontalRule() {
        requestSelectCurrentBlock()
    }

    func requestSelectCurrentBlock() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestSelectHorizontalRule(self, blockID: blockID)
    }

    func requestImageCaret(at offset: Int) {
        guard let blockID else {
            return
        }
        delegate?.blockItem(self, blockID: blockID, didRequestImageCaretAt: offset)
    }

    @objc func requestToggleChecklist() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestToggleChecklist(self, blockID: blockID)
    }

    func requestMoveVertically(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let blockID, canMoveVerticallyOutOfBlock(direction) else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestVerticalMovement: direction,
            preferredTextContainerX: currentCaretTextContainerX()
        ) ?? false
    }

    func draggingPasteboardItem() -> NSPasteboardItem? {
        guard handleView.isEnabled,
              let blockID else {
            return nil
        }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(blockID.rawValue, forType: .blockInputBlockID)
        return pasteboardItem
    }

    func beginDraggingHandle(with event: NSEvent) {
        guard let pasteboardItem = draggingPasteboardItem() else {
            return
        }
        if let blockID {
            delegate?.blockItemDidBeginReordering(self, blockID: blockID)
        }
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(
            handleView.convert(view.bounds, from: view),
            contents: draggingPreviewImage()
        )
        handleView.beginDraggingSession(with: [draggingItem], event: event, source: handleView)
    }
}
