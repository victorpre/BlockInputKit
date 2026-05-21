import AppKit

extension BlockInputBlockItem: BlockInputTableViewDelegate {
    func isTableCellTextView(_ textView: NSTextView) -> Bool {
        tableView.isTableCellTextView(textView)
    }

    func sourceSelectedRange(for textView: NSTextView, localRange: NSRange) -> NSRange {
        tableView.sourceRange(for: textView, localRange: localRange) ?? localRange
    }

    func sourceInlineMarkdownRange(
        for textView: NSTextView,
        localRange: BlockInputInlineMarkdownRange
    ) -> BlockInputInlineMarkdownRange? {
        tableView.sourceInlineMarkdownRange(for: textView, localRange: localRange)
    }

    func supportsInlineMarkdownLinkRendering(for textView: NSTextView) -> Bool {
        if tableView.isTableCellTextView(textView) {
            return true
        }
        guard let kind = renderedBlock?.kind else {
            return false
        }
        return Self.supportsInlineMarkdownStyling(kind)
    }

    func handleTableCellCommand(_ selector: Selector, selectedRange: NSRange) -> Bool {
        switch selector {
        case #selector(cancelOperation(_:)):
            return requestCancelSelection()
        default:
            return false
        }
    }

    func tableView(_ tableView: BlockInputTableView, didBeginEditing position: BlockInputTable.CellPosition) {
        guard let blockID else {
            return
        }
        updateSelectionDependentAttributesForCurrentSelection()
        delegate?.blockItemDidBeginEditing(self, blockID: blockID)
    }

    func tableView(_ tableView: BlockInputTableView, didEndEditing position: BlockInputTable.CellPosition) {
        guard let blockID else {
            return
        }
        updateSelectionDependentAttributesForCurrentSelection()
        delegate?.blockItemDidEndEditing(self, blockID: blockID)
    }

    func tableView(_ tableView: BlockInputTableView, didChangeSelectionIn position: BlockInputTable.CellPosition, sourceRange: NSRange) {
        guard let blockID else {
            return
        }
        updateSelectionDependentAttributesForCurrentSelection()
        delegate?.blockItem(self, didChangeSelectionIn: blockID)
    }

    func tableView(
        _ tableView: BlockInputTableView,
        didChangeText text: String,
        in position: BlockInputTable.CellPosition,
        selectedLocalRange: NSRange,
        selectionBefore: BlockInputSelection?
    ) {
        guard let blockID else {
            return
        }
        delegate?.blockItem(
            self,
            blockID: blockID,
            didChangeTableCellText: BlockInputTableCellTextChange(
                text: text,
                position: position,
                selectedLocalRange: selectedLocalRange,
                selectionBefore: selectionBefore
            )
        )
    }

    func tableView(
        _ tableView: BlockInputTableView,
        shouldChangeTextIn position: BlockInputTable.CellPosition,
        affectedLocalRange: NSRange,
        replacementString: String?
    ) -> Bool {
        true
    }
}
