import AppKit

extension BlockInputTextView {
    override func keyDown(with event: NSEvent) {
        if blockItem?.isTableCellTextView(self) == true {
            if !hasMarkedText(),
               handleTableCellCommandArrow(event) {
                return
            }
            if !hasMarkedText(),
               blockItem?.handleTableCellKeyDown(event, selectedRange: selectedRange()) == true {
                return
            }
            // Table cells keep native arrow and selection movement local to the cell.
            super.keyDown(with: event)
            return
        }
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

    func handleTableCellKeyEquivalent(_ event: NSEvent) -> Bool {
        guard blockItem?.isTableCellTextView(self) == true,
              !hasMarkedText() else {
            return false
        }
        if handleTableCellCommandArrow(event) {
            return true
        }
        return blockItem?.handleTableCellKeyDown(event, selectedRange: selectedRange()) == true
    }

    func handleTableCellSelectionArrow(_ event: NSEvent) -> Bool {
        guard blockItem?.isTableCellTextView(self) == true,
              !hasMarkedText(),
              event.blockInputSelectionExpansionDirection != nil || event.horizontalSelectionAdjustmentDirection != nil else {
            return false
        }
        return blockItem?.handleTableCellKeyDown(event, selectedRange: selectedRange()) == true
    }

    func handleTableCellSelectionCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveUpAndModifySelection(_:)),
             #selector(moveDownAndModifySelection(_:)),
             #selector(moveLeftAndModifySelection(_:)),
             #selector(moveRightAndModifySelection(_:)):
            return blockItem?.isTableCellTextView(self) == true
                && blockItem?.handleTableCellCommand(selector, selectedRange: selectedRange()) == true
        default:
            return false
        }
    }

    func handleTableCellCommandArrow(_ event: NSEvent) -> Bool {
        guard event.tableCellCommandArrow else {
            return false
        }
        if keyCodeMatches(event, keyCode: 123, character: "\u{F702}") {
            moveToBeginningOfLine(nil)
            return true
        }
        if keyCodeMatches(event, keyCode: 124, character: "\u{F703}") {
            moveToEndOfLine(nil)
            return true
        }
        if keyCodeMatches(event, keyCode: 126, character: "\u{F700}") {
            moveToBeginningOfDocument(nil)
            return true
        }
        if keyCodeMatches(event, keyCode: 125, character: "\u{F701}") {
            moveToEndOfDocument(nil)
            return true
        }
        return false
    }

    private func keyCodeMatches(_ event: NSEvent, keyCode: UInt16, character: String) -> Bool {
        event.keyCode == keyCode || event.charactersIgnoringModifiers == character
    }

    func handleNonTableSelectionKeyEquivalent(_ event: NSEvent) -> Bool {
        guard blockItem?.isTableCellTextView(self) != true else {
            return false
        }
        if handleDocumentBoundaryShortcut(event) {
            BlockInputSelectionDebug.emit("text equivalent consumed document boundary")
            return true
        }
        if handleSelectionExpansionShortcut(event) {
            BlockInputSelectionDebug.emit("text equivalent consumed")
            return true
        }
        if handleHorizontalSelectionAdjustmentShortcut(event) {
            BlockInputSelectionDebug.emit("text equivalent consumed horizontal")
            return true
        }
        return false
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
