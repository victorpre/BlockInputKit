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
        case #selector(insertTab(_:)):
            return moveTableFocus(.forward)
        case #selector(insertBacktab(_:)):
            return moveTableFocus(.backward)
        case #selector(insertNewline(_:)):
            return moveTableFocusVertically(.below)
        case #selector(insertNewlineIgnoringFieldEditor(_:)):
            return moveTableFocusVertically(.above)
        case #selector(deleteBackward(_:)), #selector(deleteForward(_:)):
            return handleTableCellDelete(selectedRange: selectedRange)
        case #selector(selectAll(_:)):
            requestSelectAll()
            return true
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

    func tableViewDidRequestAppendBodyRow(_ tableView: BlockInputTableView, from position: BlockInputTable.CellPosition?) {
        guard let blockID else {
            return
        }
        _ = delegate?.blockItem(self, blockID: blockID, didRequestTableBodyRowAppendFrom: position)
    }

    func tableViewDidRequestAppendColumn(_ tableView: BlockInputTableView, from position: BlockInputTable.CellPosition?) {
        guard let blockID else {
            return
        }
        _ = delegate?.blockItem(self, blockID: blockID, didRequestTableColumnAppendFrom: position)
    }

    private func moveTableFocus(_ direction: TableCellLinearMovement) -> Bool {
        guard let blockID,
              let position = tableView.activeCellPosition else {
            return false
        }
        let target = direction == .forward
            ? tableView.nextCellPosition(after: position)
            : tableView.previousCellPosition(before: position)
        guard let target else {
            return false
        }
        return delegate?.blockItem(self, blockID: blockID, didRequestTableFocus: target) ?? false
    }

    private func moveTableFocusVertically(_ placement: BlockInputTableBoundaryPlacement) -> Bool {
        guard let blockID,
              let position = tableView.activeCellPosition else {
            return false
        }
        if let target = tableView.verticalCellPosition(from: position, placement: placement) {
            return delegate?.blockItem(self, blockID: blockID, didRequestTableFocus: target) ?? false
        }
        return delegate?.blockItem(self, blockID: blockID, didRequestParagraphAdjacentToTable: placement) ?? false
    }

    private func handleTableCellDelete(selectedRange: NSRange) -> Bool {
        guard selectedRange.length == 0,
              let blockID,
              let position = tableView.activeCellPosition,
              tableView.activeCellText?.isEmpty == true else {
            return false
        }
        if tableView.isRowSelected(position.row) {
            guard case .body = position.row else {
                return true
            }
            return delegate?.blockItem(self, blockID: blockID, didRequestTableBodyRowDeletionAt: position) ?? false
        }
        tableView.selectRow(position.row)
        return true
    }
}

private enum TableCellLinearMovement {
    case forward
    case backward
}
