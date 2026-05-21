import AppKit

extension BlockInputTextView {
    override func keyDown(with event: NSEvent) {
        if blockItem?.requestCompletionKeyDown(event) == true {
            return
        }
        if event.isArrowKey {
            BlockInputSelectionDebug.emit(
                "text key key=\(event.debugKeyName) modifiers=\(event.debugModifierNames) range=\(selectedRange())"
            )
        }
        if handleDocumentBoundaryShortcut(event) {
            BlockInputSelectionDebug.emit("text key consumed document boundary")
            return
        }
        if handleSelectionExpansionShortcut(event) {
            BlockInputSelectionDebug.emit("text key consumed")
            return
        }
        if handleHorizontalSelectionAdjustmentShortcut(event) {
            BlockInputSelectionDebug.emit("text key consumed horizontal")
            return
        }
        if handleLinkBoundaryMovementShortcut(event) {
            BlockInputSelectionDebug.emit("text key consumed link boundary")
            return
        }
        super.keyDown(with: event)
    }

    func requestSelectionExpansionFromOwningBlock(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        let result = blockItem?.requestExpandSelection(direction) == true
        BlockInputSelectionDebug.emit(
            "text request expand direction=\(direction.debugName) range=\(selectedRange()) result=\(result)"
        )
        return result
    }

    func requestActiveBlockSelectionExpansionFromOwningBlock(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        let result = blockItem?.requestExpandActiveBlockSelection(direction) == true
        BlockInputSelectionDebug.emit(
            "text request expand active blocks direction=\(direction.debugName) range=\(selectedRange()) result=\(result)"
        )
        return result
    }

    func requestDocumentBoundaryFromOwningBlock(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        let result = blockItem?.requestDocumentBoundary(direction) == true
        BlockInputSelectionDebug.emit(
            "text request document boundary direction=\(direction.debugName) range=\(selectedRange()) result=\(result)"
        )
        return result
    }

    func requestCancelSelectionFromOwningBlock() -> Bool {
        blockItem?.requestCancelSelection() == true
    }

    func requestMouseDownCancelSelectionFromOwningBlock() -> Bool {
        blockItem?.requestMouseDownCancelSelection() == true
    }

    func rememberBlockSelectionDragRange(_ range: NSRange) {
        blockSelectionDragSelectedRange = range
    }

    func collapsedBlockSelectionDragNativeRange() -> NSRange {
        let textLength = (string as NSString).length
        let offset = min(max(blockSelectionDragAnchorOffset ?? selectedRange().location, 0), textLength)
        return NSRange(location: offset, length: 0)
    }
}
