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
}
