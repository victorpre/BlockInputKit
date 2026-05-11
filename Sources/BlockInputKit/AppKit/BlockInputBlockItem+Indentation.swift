import AppKit

extension BlockInputBlockItem {
    func requestIndent() -> Bool {
        guard let blockID else {
            return false
        }
        guard currentSelectionCanChangeIndent else {
            return true
        }
        delegate?.blockItemDidRequestIndent(self, blockID: blockID, selectedRange: currentSelectedRange)
        return true
    }

    func requestOutdent() -> Bool {
        guard let blockID else {
            return false
        }
        guard currentSelectionCanChangeIndent else {
            return true
        }
        delegate?.blockItemDidRequestOutdent(self, blockID: blockID, selectedRange: currentSelectedRange)
        return true
    }

    private var currentSelectionCanChangeIndent: Bool {
        let selectedRange = currentSelectedRange
        guard selectedRange.length == 0 else {
            return false
        }
        if selectedRange.location == 0 {
            return true
        }
        let text = textView.string as NSString
        guard selectedRange.location <= text.length else {
            return false
        }
        return text.character(at: selectedRange.location - 1).isLineEnding
    }
}
