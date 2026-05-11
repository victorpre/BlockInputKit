import Foundation

extension BlockInputView {
    @discardableResult
    func performUndoShortcut(
        _ shortcut: BlockInputUndoShortcut,
        preferredBlockID: BlockInputBlockID? = nil
    ) -> Bool {
        switch shortcut {
        case .undo:
            return undoForKeyboardShortcut(preferredBlockID: preferredBlockID) != nil
        case .redo:
            return redoForKeyboardShortcut(preferredBlockID: preferredBlockID) != nil
        }
    }

    @discardableResult
    func undoTextEdit(in blockID: BlockInputBlockID) -> BlockInputUndoResult? {
        refreshDocumentFromStore()
        guard let result = undoController?.undoTextEdit(in: &document, blockID: blockID) else {
            return nil
        }
        applyTextUndoResult(result, blockID: blockID)
        return result
    }

    @discardableResult
    func redoTextEdit(in blockID: BlockInputBlockID) -> BlockInputUndoResult? {
        refreshDocumentFromStore()
        guard let result = undoController?.redoTextEdit(in: &document, blockID: blockID) else {
            return nil
        }
        applyTextUndoResult(result, blockID: blockID)
        return result
    }

    private func undoForKeyboardShortcut(preferredBlockID: BlockInputBlockID?) -> BlockInputUndoResult? {
        if let preferredBlockID {
            return undoTextEdit(in: preferredBlockID) ?? undoStructuralEdit()
        }
        return undoTextEditInActiveBlock() ?? undoStructuralEdit()
    }

    private func redoForKeyboardShortcut(preferredBlockID: BlockInputBlockID?) -> BlockInputUndoResult? {
        if let preferredBlockID {
            return redoTextEdit(in: preferredBlockID) ?? redoStructuralEdit()
        }
        return redoTextEditInActiveBlock() ?? redoStructuralEdit()
    }

    private func applyTextUndoResult(_ result: BlockInputUndoResult, blockID: BlockInputBlockID) {
        if let block = document.block(withID: blockID) {
            applyUndoResult(result, storeSyncAction: .replaceBlock(block))
        } else {
            applyUndoResult(result)
        }
    }
}
