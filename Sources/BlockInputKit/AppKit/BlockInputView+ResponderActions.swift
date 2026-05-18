import AppKit

extension BlockInputView {
    @objc(undo:)
    func blockInputUndo(_ sender: Any?) {
        _ = performUndoShortcut(.undo)
    }

    @objc(redo:)
    func blockInputRedo(_ sender: Any?) {
        _ = performUndoShortcut(.redo)
    }

    @objc(copy:)
    func blockInputCopy(_ sender: Any?) {
        _ = copyActiveSelection()
    }

    @objc(cut:)
    func blockInputCut(_ sender: Any?) {
        _ = cutActiveSelection()
    }

    @objc(paste:)
    func blockInputPaste(_ sender: Any?) {
        _ = pasteIntoActiveSelection()
    }
}
