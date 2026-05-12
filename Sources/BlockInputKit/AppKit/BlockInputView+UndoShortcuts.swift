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
        guard let block = block(withID: blockID),
              let result = undoController?.undoTextEdit(for: block) else {
            return nil
        }
        applyTextUndoResult(result, blockID: blockID)
        return result
    }

    @discardableResult
    func redoTextEdit(in blockID: BlockInputBlockID) -> BlockInputUndoResult? {
        guard let block = block(withID: blockID),
              let result = undoController?.redoTextEdit(for: block) else {
            return nil
        }
        applyTextUndoResult(result, blockID: blockID)
        return result
    }

    private func undoForKeyboardShortcut(preferredBlockID: BlockInputBlockID?) -> BlockInputUndoResult? {
        if let preferredBlockID {
            if undoController?.canUndoTextEdit(in: preferredBlockID) == true {
                return undoTextEdit(in: preferredBlockID)
            }
            return undoStructuralEdit()
        }
        if let activeBlockID, undoController?.canUndoTextEdit(in: activeBlockID) == true {
            return undoTextEdit(in: activeBlockID)
        }
        return undoStructuralEdit()
    }

    private func redoForKeyboardShortcut(preferredBlockID: BlockInputBlockID?) -> BlockInputUndoResult? {
        if let preferredBlockID {
            if undoController?.canRedoTextEdit(in: preferredBlockID) == true {
                return redoTextEdit(in: preferredBlockID)
            }
            return redoStructuralEdit()
        }
        if let activeBlockID, undoController?.canRedoTextEdit(in: activeBlockID) == true {
            return redoTextEdit(in: activeBlockID)
        }
        return redoStructuralEdit()
    }

    private func applyTextUndoResult(_ result: BlockInputUndoResult, blockID: BlockInputBlockID) {
        guard let replacedBlock = result.replacedBlock,
              let replacementIndex = index(of: blockID) else {
            applyUndoResult(result)
            return
        }
        _ = applyGranularReplacementUndo(replacedBlock, at: replacementIndex, selection: result.selection)
    }
}
