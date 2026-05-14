import AppKit

extension BlockInputBlockItem {
    func beginBlockSelectionDrag() {
        isTrackingBlockSelectionDrag = true
        isDraggingBlockSelection = false
    }

    func updateBlockSelectionDrag(with event: NSEvent, selectedRange: NSRange? = nil) -> Bool {
        guard let blockID,
              isTrackingBlockSelectionDrag else {
            return false
        }
        let wasDraggingBlockSelection = isDraggingBlockSelection
        if delegate?.blockItem(
            self,
            blockID: blockID,
            didDragSelectBlocksWith: event,
            selectedRange: selectedRange
        ) == true {
            suppressNativeSelectionDisplayForPartialChrome()
            collapseNativeSelectionIfNeeded(at: selectedRange?.location)
            isDraggingBlockSelection = true
            return true
        }
        isDraggingBlockSelection = false
        if wasDraggingBlockSelection {
            if renderedBlock?.kind == .horizontalRule {
                requestSelectHorizontalRule()
            } else {
                view.window?.makeFirstResponder(textView)
            }
        }
        return false
    }

    func finishBlockSelectionDrag() {
        isTrackingBlockSelectionDrag = false
        isDraggingBlockSelection = false
    }

    func requestExpandSelection(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let blockID else {
            return false
        }
        let range = textView.selectedRange()
        let result = delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestExpandSelection: direction,
            selectedRange: range,
            preferredTextContainerX: selectionExtentTextContainerX(direction)
        ) ?? false
        BlockInputSelectionDebug.emit(
            "item request expand block=\(blockID.rawValue) direction=\(direction.debugName) range=\(range) result=\(result)"
        )
        return result
    }

    func requestExpandActiveBlockSelection(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let blockID else {
            return false
        }
        let result = delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestExpandActiveBlockSelection: direction
        ) ?? false
        BlockInputSelectionDebug.emit(
            "item request expand active blocks block=\(blockID.rawValue) direction=\(direction.debugName) result=\(result)"
        )
        return result
    }

    func requestHorizontalSelectionAdjustment(_ direction: BlockInputHorizontalMovementDirection) -> Bool {
        guard let blockID else {
            return false
        }
        let range = textView.selectedRange()
        let result = delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestHorizontalSelectionAdjustment: direction,
            selectedRange: range
        ) ?? false
        BlockInputSelectionDebug.emit(
            "item request horizontal block=\(blockID.rawValue) direction=\(direction.debugName) range=\(range) result=\(result)"
        )
        return result
    }

    func requestCollapseSelection(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestCollapseSelection: direction
        ) ?? false
    }

    func requestDocumentBoundary(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestDocumentBoundary: direction
        ) ?? false
    }

    func requestCancelSelection() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestCancelSelection(self, blockID: blockID) ?? false
    }

    func requestMouseDownCancelSelection() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestMouseDownCancelSelection(self, blockID: blockID) ?? false
    }
}
