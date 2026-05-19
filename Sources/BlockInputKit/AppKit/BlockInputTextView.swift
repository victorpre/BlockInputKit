import AppKit

/// Text view wrapper that forwards block-aware commands and cross-block drag selection to its owning block item.
///
/// AppKit owns native text selection inside one `NSTextView`; this subclass captures enough range and anchor information
/// during plain mouse drags for `BlockInputView` to promote the drag into the editor-level mixed selection model.
///
/// Modified clicks and multi-clicks stay on AppKit's native path so standard word, paragraph, and extended text-field
/// gestures keep working. Plain drags use editor-owned selection chrome to avoid gray native selection paint layering
/// over mixed block-selection endpoints.
final class BlockInputTextView: NSTextView {
    weak var blockItem: BlockInputBlockItem?
    var isDraggingBlockSelection = false
    var blockSelectionDragMonitor: Any?
    var blockSelectionDragTimer: Timer?
    // Cross-block drags carry a logical text range while the native NSTextView selection stays collapsed. This keeps
    // AppKit's inactive gray selection paint out of editor-owned partial selection chrome during mouse tracking.
    var blockSelectionDragSelectedRange: NSRange?
    var blockSelectionLocalDragRange: NSRange?
    var blockSelectionDragAnchorOffset: Int?
    // Native modified-click and multi-click gestures can re-enter mouseDragged/mouseUp during AppKit tracking. Keep that
    // separate from the custom plain-drag state so native selection restoration cannot be consumed as a block drag.
    var isUsingNativeMouseSelection = false
    private var isForwardingVerticalScrollSequence = false
    private var verticalScrollSequenceToken = UUID()

    override func mouseDown(with event: NSEvent) {
        _ = requestMouseDownCancelSelectionFromOwningBlock()
        guard shouldTrackBlockSelectionDrag(for: event) else {
            // Multi-click and modified-click selection are native NSTextView gestures; only plain single-click drags need
            // custom tracking.
            finishBlockSelectionDrag()
            isUsingNativeMouseSelection = true
            super.mouseDown(with: event)
            isUsingNativeMouseSelection = false
            return
        }
        blockItem?.beginBlockSelectionDrag()
        isDraggingBlockSelection = false
        let anchorOffset = blockSelectionDragAnchorOffset(for: event)
        blockSelectionDragAnchorOffset = anchorOffset
        blockSelectionDragSelectedRange = NSRange(location: anchorOffset, length: 0)
        blockSelectionLocalDragRange = nil
        installBlockSelectionDragMonitor()
        installBlockSelectionDragTimer()
        window?.makeFirstResponder(self)
        setSelectedRange(NSRange(location: anchorOffset, length: 0))
    }

    override func mouseDragged(with event: NSEvent) {
        if isUsingNativeMouseSelection {
            super.mouseDragged(with: event)
            return
        }
        let localDragRange = blockSelectionDragRange(for: event)
        blockSelectionDragSelectedRange = localDragRange
        blockSelectionLocalDragRange = localDragRange
        isDraggingBlockSelection = blockItem?.updateBlockSelectionDrag(
            with: event,
            selectedRange: localDragRange
        ) == true
        if isDraggingBlockSelection {
            return
        }
        // Keep AppKit out of the native drag-selection path while block selection may be promoted. The visible selection
        // chrome is editor-owned, and allowing `NSTextView` to build a native range here can leave gray selection paint
        // over the custom blue endpoint background for the rest of the tracking cycle.
        updateTrackedLocalTextSelection(localDragRange)
    }

    override func mouseUp(with event: NSEvent) {
        if isUsingNativeMouseSelection {
            super.mouseUp(with: event)
            isUsingNativeMouseSelection = false
            return
        }
        if completeTrackedBlockSelectionMouseUp() {
            return
        }
        super.mouseUp(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if shouldBreakVerticalSequenceForHorizontalScroll(event),
           forwardHorizontalScroll(event) {
            isForwardingVerticalScrollSequence = false
            verticalScrollSequenceToken = UUID()
            return
        }
        if isForwardingVerticalScrollSequence,
           let verticalAncestorScrollView {
            verticalAncestorScrollView.scrollWheel(with: event)
            schedulePhaseLessVerticalScrollSequenceResetIfNeeded(for: event)
            updateVerticalScrollSequenceState(after: event)
            return
        }
        if shouldForwardHorizontalScroll(event),
           forwardHorizontalScroll(event) {
            return
        }
        if shouldForwardVerticalScroll(event),
           let verticalAncestorScrollView {
            isForwardingVerticalScrollSequence = true
            schedulePhaseLessVerticalScrollSequenceResetIfNeeded(for: event)
            verticalAncestorScrollView.scrollWheel(with: event)
            updateVerticalScrollSequenceState(after: event)
            return
        }
        updateVerticalScrollSequenceState(after: event)
        super.scrollWheel(with: event)
    }

    override func keyDown(with event: NSEvent) {
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
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.isArrowKey {
            BlockInputSelectionDebug.emit(
                "text equivalent key=\(event.debugKeyName) modifiers=\(event.debugModifierNames) range=\(selectedRange())"
            )
        }
        if event.blockInputIsSelectAllShortcut,
           let blockItem {
            blockItem.requestSelectAll()
            return true
        }
        if let undoShortcut = event.blockInputUndoShortcut,
           blockItem?.requestUndoShortcut(undoShortcut) == true {
            return true
        }
        if let formattingShortcut = event.blockInputTextFormattingShortcut {
            _ = blockItem?.requestTextFormattingShortcut(formattingShortcut)
            return true
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
        // Copy needs a direct key-equivalent path; paste stays on NSText so insertion uses AppKit's normal edit pipeline.
        if event.blockInputIsCopyShortcut,
           copySelectedPlainText() {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = systemMenuPreservingSelectedRange(for: event)
        menu.blockInputRemovingSystemFontItems()
        menu.blockInputPrependingTextFormattingItems(textFormattingMenuItems(for: event))
        return menu.items.isEmpty ? nil : menu
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
        BlockInputSelectionDebug.emit("text command selector=\(selector) range=\(selectedRange())")
        if handleBlockCommand(selector) ||
            handleDocumentBoundaryCommand(selector) ||
            handleSelectionExpansionCommand(selector) ||
            handleHorizontalSelectionAdjustmentCommand(selector) ||
            handleBoundaryCommand(selector) {
            BlockInputSelectionDebug.emit("text command consumed selector=\(selector)")
            return
        }
        super.doCommand(by: selector)
    }

    override func moveToBeginningOfDocument(_ sender: Any?) {
        if requestDocumentBoundaryFromOwningBlock(.upward) {
            return
        }
        super.moveToBeginningOfDocument(sender)
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        if requestDocumentBoundaryFromOwningBlock(.downward) {
            return
        }
        super.moveToEndOfDocument(sender)
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
            return blockItem?.requestCancelSelection() == true
        default:
            return false
        }
    }

    private func handleBoundaryCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveUp(_:)):
            return blockItem?.requestCollapseSelection(.upward) == true
                || blockItem?.requestMoveVertically(.upward) == true
        case #selector(moveDown(_:)):
            return blockItem?.requestCollapseSelection(.downward) == true
                || blockItem?.requestMoveVertically(.downward) == true
        default:
            return false
        }
    }

    private func handleSelectionExpansionCommand(_ selector: Selector) -> Bool {
        let direction: BlockInputVerticalMovementDirection
        switch selector {
        case #selector(moveUpAndModifySelection(_:)):
            direction = .upward
        case #selector(moveDownAndModifySelection(_:)):
            direction = .downward
        default:
            return false
        }
        _ = blockItem?.requestExpandSelection(direction)
        return true
    }

    private func handleDocumentBoundaryCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveToBeginningOfDocument(_:)):
            return requestDocumentBoundaryFromOwningBlock(.upward)
        case #selector(moveToEndOfDocument(_:)):
            return requestDocumentBoundaryFromOwningBlock(.downward)
        default:
            return false
        }
    }

    private func handleDocumentBoundaryShortcut(_ event: NSEvent) -> Bool {
        guard let direction = event.blockInputDocumentBoundaryDirection else {
            return false
        }
        return requestDocumentBoundaryFromOwningBlock(direction)
    }

    private func handleSelectionExpansionShortcut(_ event: NSEvent) -> Bool {
        if let direction = event.blockInputSelectionExpansionDirection {
            _ = requestSelectionExpansionFromOwningBlock(direction)
            return true
        }
        return false
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

    private func copySelectedPlainText() -> Bool {
        let range = selectedRange()
        let copiedText: String?
        if var block = blockItem?.renderedBlock {
            block.text = string
            copiedText = block.markdownAwareCopiedText(in: range)
        } else {
            let clampedRange = string.clampedRange(range)
            copiedText = clampedRange.length > 0
                ? (string as NSString).substring(with: clampedRange)
                : nil
        }
        guard let copiedText, !copiedText.isEmpty else {
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copiedText, forType: .string)
        return true
    }

    private func shouldForwardVerticalScroll(_ event: NSEvent) -> Bool {
        guard !event.modifierFlags.contains(.shift) else {
            return false
        }
        let deltaY = abs(verticalScrollDelta(for: event))
        return deltaY > 0 && deltaY >= abs(horizontalRawScrollDelta(for: event))
    }

    private func shouldForwardHorizontalScroll(_ event: NSEvent) -> Bool {
        abs(horizontalRawScrollDelta(for: event)) > abs(verticalScrollDelta(for: event)) ||
            shouldBreakVerticalSequenceForHorizontalScroll(event)
    }

    private func forwardHorizontalScroll(_ event: NSEvent) -> Bool {
        guard let horizontalScrollView = enclosingScrollView,
              horizontalScrollView.hasHorizontalScroller else {
            return false
        }
        horizontalScrollView.scrollWheel(with: event)
        return true
    }

    private func shouldBreakVerticalSequenceForHorizontalScroll(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.shift) &&
            (abs(verticalScrollDelta(for: event)) > 0 || abs(horizontalRawScrollDelta(for: event)) > 0)
    }

    private func horizontalRawScrollDelta(for event: NSEvent) -> CGFloat {
        event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.deltaX
    }

    private func verticalScrollDelta(for event: NSEvent) -> CGFloat {
        event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
    }

    private func updateVerticalScrollSequenceState(after event: NSEvent) {
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) ||
            event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
            isForwardingVerticalScrollSequence = false
            verticalScrollSequenceToken = UUID()
        }
    }

    private func schedulePhaseLessVerticalScrollSequenceResetIfNeeded(for event: NSEvent) {
        guard event.phase == [], event.momentumPhase == [] else {
            return
        }
        let token = UUID()
        verticalScrollSequenceToken = token
        DispatchQueue.main.async { [weak self] in
            guard self?.verticalScrollSequenceToken == token else {
                return
            }
            self?.isForwardingVerticalScrollSequence = false
        }
    }

    private var verticalAncestorScrollView: NSScrollView? {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? NSScrollView,
               scrollView.hasVerticalScroller {
                return scrollView
            }
            candidate = view.superview
        }
        return nil
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
