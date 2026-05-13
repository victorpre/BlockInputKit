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
        // Copy needs a direct key-equivalent path; paste stays on NSText so insertion uses AppKit's normal edit pipeline.
        if event.blockInputIsCopyShortcut,
           copySelectedPlainText() {
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

    override func copy(_ sender: Any?) {
        guard copySelectedPlainText() else {
            super.copy(sender)
            return
        }
    }

    override func cut(_ sender: Any?) {
        guard copySelectedPlainText() else {
            super.cut(sender)
            return
        }
        delete(nil)
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
            guard let blockItem else {
                return true
            }
            return blockItem.requestReturn()
        case #selector(deleteBackward(_:)), #selector(deleteForward(_:)):
            if selectedRange().location == 0,
               selectedRange().length == 0,
               blockItem?.requestUnwrapBlock() == true {
                return true
            }
            if selectedRange().location == 0,
               selectedRange().length == 0,
               blockItem?.requestMergeWithPreviousBlock() == true {
                return true
            }
            return blockItem?.requestDeleteEmptyBlock() == true
        case #selector(selectAll(_:)):
            blockItem?.requestSelectAll()
            return true
        case #selector(insertTab(_:)):
            return blockItem?.requestIndent() == true
        case #selector(insertBacktab(_:)):
            return blockItem?.requestOutdent() == true
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

    private func copySelectedPlainText() -> Bool {
        let range = selectedRange()
        guard range.length > 0 else {
            return false
        }
        let copiedText = (string as NSString).substring(with: string.clampedRange(range))
        guard !copiedText.isEmpty else {
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copiedText, forType: .string)
        return true
    }
}

private extension String {
    func clampedRange(_ range: NSRange) -> NSRange {
        let text = self as NSString
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), max(text.length - location, 0))
        return NSRange(location: location, length: length)
    }
}
