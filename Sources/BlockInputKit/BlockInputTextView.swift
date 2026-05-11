import AppKit

final class BlockInputTextView: NSTextView {
    weak var blockItem: BlockInputBlockItem?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.blockInputIsSelectAllShortcut,
           let blockItem {
            blockItem.requestSelectAll()
            return true
        }
        if let undoShortcut = event.blockInputUndoShortcut,
           blockItem?.requestUndoShortcut(undoShortcut) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func selectAll(_ sender: Any?) {
        guard let blockItem else {
            super.selectAll(sender)
            return
        }
        blockItem.requestSelectAll()
    }

    @objc(undo:)
    func blockInputUndo(_ sender: Any?) {
        _ = blockItem?.requestUndoShortcut(.undo)
    }

    @objc(redo:)
    func blockInputRedo(_ sender: Any?) {
        _ = blockItem?.requestUndoShortcut(.redo)
    }

    override func doCommand(by selector: Selector) {
        if handleBlockCommand(selector) || handleBoundaryCommand(selector) {
            return
        }
        super.doCommand(by: selector)
    }

    private func handleBlockCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(insertNewline(_:)):
            blockItem?.requestReturn()
            return true
        case #selector(deleteBackward(_:)), #selector(deleteForward(_:)):
            if selectedRange().location == 0,
               selectedRange().length == 0,
               blockItem?.requestUnwrapBlock() == true {
                return true
            }
            return blockItem?.requestDeleteEmptyBlock() == true
        case #selector(selectAll(_:)):
            blockItem?.requestSelectAll()
            return true
        case #selector(insertTab(_:)):
            blockItem?.requestIndent()
            return true
        case #selector(insertBacktab(_:)):
            blockItem?.requestOutdent()
            return true
        case #selector(cancelOperation(_:)):
            return true
        default:
            return false
        }
    }

    private func handleBoundaryCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveUp(_:)):
            return blockItem?.requestMoveVertically(.upward) == true
        case #selector(moveDown(_:)):
            return blockItem?.requestMoveVertically(.downward) == true
        default:
            return false
        }
    }
}
