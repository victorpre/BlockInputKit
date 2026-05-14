import AppKit

/// Collection item that owns one AppKit text input plus block-specific chrome for a single document block.
final class BlockInputBlockItem: NSCollectionViewItem, NSTextViewDelegate {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BlockInputBlockItem")
    static let chromeFrameAlignmentOffset: CGFloat = 0
    static let checklistButtonBaseLeading: CGFloat = chromeFrameAlignmentOffset

    static let handleWidth: CGFloat = 24
    static let horizontalChromeWidthWithHandle: CGFloat = 56
    static let horizontalChromeWidthWithoutHandle: CGFloat = 32
    static let markerGutterWidth: CGFloat = 24
    static let markerChromeWidth: CGFloat = 18
    static let minimumMarkerTextGap: CGFloat = 4
    static let defaultTextLeading: CGFloat = 4
    // Mirrors the NSTextView inset plus line-fragment padding so external chrome starts at the plain-text glyph column.
    static let textContainerContentLeading: CGFloat = 9
    static let markerAlignmentLeading: CGFloat = markerGutterWidth + defaultTextLeading + textContainerContentLeading
    static let listTextLeading: CGFloat = -textContainerContentLeading
    static let quoteBarIdentifier = NSUserInterfaceItemIdentifier("BlockInputQuoteBarView")
    static let quoteBarWidth: CGFloat = 6
    static let minimumQuoteBarHeight: CGFloat = 32
    static let quoteBarVerticalInset: CGFloat = 2
    static let quoteTextLeading: CGFloat = 9

    let handleView = BlockInputDragHandleView()
    let kindLabel = BlockInputMarkerView()
    let checklistButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let quoteBarView = NSView()
    let scrollView = NSScrollView()
    let horizontalRuleView = BlockInputHorizontalRuleView()
    let selectionBackgroundView = BlockInputSelectionBackgroundView()
    let textView = BlockInputTextView()
    private var trackingArea: NSTrackingArea?
    private(set) weak var delegate: BlockInputBlockItemDelegate?
    private(set) var blockID: BlockInputBlockID?
    var renderedBlock: BlockInputBlock?
    private var selectionBeforeTextChange: BlockInputSelection?
    // Programmatic reuse/configuration can move NSTextView selection; do not
    // report that as user selection, especially on large store-backed docs.
    private var isConfiguringBlock = false
    var blockSelectionChrome: BlockInputBlockSelectionChrome = .none
    var temporarySelectionHighlightRange: NSRange?
    var isTrackingBlockSelectionDrag = false
    var isDraggingBlockSelection = false
    var handleWidthConstraint: NSLayoutConstraint?
    var kindLabelLeadingConstraint: NSLayoutConstraint?
    var kindLabelWidthConstraint: NSLayoutConstraint?
    var checklistButtonLeadingConstraint: NSLayoutConstraint?
    var scrollViewLeadingConstraint: NSLayoutConstraint?
    var scrollViewTopConstraint: NSLayoutConstraint?
    var scrollViewBottomConstraint: NSLayoutConstraint?
    var handleTopConstraint: NSLayoutConstraint?
    var kindLabelTopConstraint: NSLayoutConstraint?
    var checklistButtonTopConstraint: NSLayoutConstraint?
    var quoteBarLeadingConstraint: NSLayoutConstraint?
    var quoteBarTopConstraint: NSLayoutConstraint?
    var quoteBarBottomConstraint: NSLayoutConstraint?
    var horizontalRuleLeadingConstraint: NSLayoutConstraint?
    private var isHorizontalRule = false

    enum TextLinePosition {
        case first
        case last
    }

    var currentSelectedRange: NSRange {
        textView.selectedRange()
    }

    var currentText: String {
        textView.string
    }

    var representedBlockID: BlockInputBlockID? {
        blockID
    }

    static func horizontalChromeWidth(allowsReordering: Bool) -> CGFloat {
        allowsReordering ? horizontalChromeWidthWithHandle : horizontalChromeWidthWithoutHandle
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clearConfiguration()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateTextViewDocumentFrame()
        updateSelectionChromeFrame()
        updateHoverTrackingArea()
        updateMarkerLineYOffsets()
        updateQuoteBarVerticalExtent()
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.blockItemDidRevealReorderHandle(self)
        setReorderHandleVisible(true)
    }

    override func mouseExited(with event: NSEvent) {
        setReorderHandleVisible(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard isHorizontalRule else {
            super.mouseDown(with: event)
            return
        }
        beginBlockSelectionDrag()
        requestSelectHorizontalRule()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isHorizontalRule,
              updateBlockSelectionDrag(with: event) else {
            super.mouseDragged(with: event)
            return
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isHorizontalRule else {
            super.mouseUp(with: event)
            return
        }
        finishBlockSelectionDrag()
    }

    func configure(
        block: BlockInputBlock,
        allowsReordering: Bool,
        accentColor: NSColor = .controlAccentColor,
        isSelected: Bool = false,
        delegate: BlockInputBlockItemDelegate
    ) {
        isConfiguringBlock = true
        defer { isConfiguringBlock = false }
        blockID = block.id
        renderedBlock = block
        self.delegate = delegate
        selectionBeforeTextChange = nil
        isHorizontalRule = block.kind == .horizontalRule
        handleView.blockItem = self
        horizontalRuleView.blockItem = self
        horizontalRuleView.accentColor = accentColor
        textView.blockItem = self
        let text = block.kind == .horizontalRule ? "" : block.text
        if textView.string != text {
            textView.string = text
        }
        configureBlockKindChrome(block: block)
        setBlockSelection(isSelected)
        handleView.isEnabled = allowsReordering
        handleView.isHidden = !allowsReordering
        handleView.alphaValue = 0
        handleView.toolTip = allowsReordering ? "Drag to reorder block" : nil
        handleWidthConstraint?.constant = allowsReordering ? Self.handleWidth : 0
    }

    func updateTextDependentChrome(for block: BlockInputBlock) {
        renderedBlock = block
        configureBlockKindChrome(block: block)
    }

    func focusText(atUTF16Offset offset: Int) {
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(
            location: min(max(offset, 0), (textView.string as NSString).length),
            length: 0
        ))
        updateTypingAttributesForCurrentSelection()
    }

    func focusText(inUTF16Range range: NSRange) {
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(range)
        updateTypingAttributesForCurrentSelection()
    }

    func setSelectedRange(_ range: NSRange) {
        textView.setSelectedRange(range)
        updateTypingAttributesForCurrentSelection()
    }

    func collapseNativeSelectionIfNeeded(at offset: Int? = nil) {
        guard !isHorizontalRule,
              textView.selectedRange().length > 0 || offset != nil else {
            return
        }
        let wasConfiguringBlock = isConfiguringBlock
        isConfiguringBlock = true
        let textLength = (textView.string as NSString).length
        let location = min(max(offset ?? textView.selectedRange().location, 0), textLength)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        updateTypingAttributesForCurrentSelection()
        isConfiguringBlock = wasConfiguringBlock
    }

    func setSelectionHighlightRange(_ range: NSRange) {
        let wasConfiguringBlock = isConfiguringBlock
        isConfiguringBlock = true
        guard applyTemporarySelectionHighlight(range) else {
            applySelectionChrome(.none)
            isConfiguringBlock = wasConfiguringBlock
            return
        }
        applySelectionChrome(.partial)
        collapseNativeSelectionIfNeeded(at: range.location)
        suppressNativeSelectionDisplayForPartialChrome()
        isConfiguringBlock = wasConfiguringBlock
    }

    func textDidBeginEditing(_ notification: Notification) {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidBeginEditing(self, blockID: blockID)
    }

    func textDidEndEditing(_ notification: Notification) {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidEndEditing(self, blockID: blockID)
    }

    func textDidChange(_ notification: Notification) {
        guard !isConfiguringBlock else {
            return
        }
        guard let blockID else {
            return
        }
        delegate?.blockItem(
            self,
            blockID: blockID,
            didChangeText: textView.string,
            selectionBefore: selectionBeforeTextChange
        )
        selectionBeforeTextChange = nil
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let blockID else {
            return true
        }
        // NSTextView reports the final selection before textDidChange, so capture
        // the affected pre-edit range here for undo selection restoration.
        selectionBeforeTextChange = affectedCharRange.length == 0
            ? .cursor(BlockInputCursor(blockID: blockID, utf16Offset: affectedCharRange.location))
            : .text(BlockInputTextRange(blockID: blockID, range: affectedCharRange))
        return true
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isConfiguringBlock else {
            return
        }
        guard let blockID else {
            return
        }
        updateTypingAttributesForCurrentSelection()
        delegate?.blockItem(self, didChangeSelectionIn: blockID)
    }

    func textView(
        _ textView: NSTextView,
        willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange,
        toCharacterRange newSelectedCharRange: NSRange
    ) -> NSRange {
        guard !isConfiguringBlock,
              isTrackingBlockSelectionDrag,
              let event = currentBlockSelectionDragEvent() else {
            return newSelectedCharRange
        }
        let blockTextView = textView as? BlockInputTextView
        blockTextView?.rememberBlockSelectionDragRange(newSelectedCharRange)
        guard updateBlockSelectionDrag(with: event, selectedRange: newSelectedCharRange) else {
            return newSelectedCharRange
        }
        return blockTextView?.collapsedBlockSelectionDragNativeRange() ?? oldSelectedCharRange
    }

    private func currentBlockSelectionDragEvent() -> NSEvent? {
        if let event = NSApp.currentEvent,
           event.type == .leftMouseDragged {
            return event
        }
        guard NSEvent.pressedMouseButtons & 1 == 1,
              let window = view.window else {
            return nil
        }
        let windowLocation = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: windowLocation,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )
    }

    func requestReturn() -> Bool {
        guard let blockID else {
            return true
        }
        return delegate?.blockItemDidRequestReturn(self, blockID: blockID) ?? true
    }

    func requestDeleteEmptyBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestDeleteEmptyBlock(self, blockID: blockID) ?? false
    }

    func requestUnwrapBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestUnwrapBlock(self, blockID: blockID) ?? false
    }

    func requestSelectAll() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestSelectAll(self, blockID: blockID)
    }

    func requestUndoShortcut(_ shortcut: BlockInputUndoShortcut) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(self, blockID: blockID, didRequestUndoShortcut: shortcut) ?? false
    }

    func requestSelectHorizontalRule() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestSelectHorizontalRule(self, blockID: blockID)
    }

    func setBlockSelection(_ isSelected: Bool) {
        clearTemporarySelectionHighlight()
        applySelectionChrome(isSelected ? .whole : .none)
        horizontalRuleView.isSelected = isHorizontalRule && isSelected
        if isSelected {
            collapseNativeSelectionIfNeeded()
        }
    }

    @objc func requestToggleChecklist() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestToggleChecklist(self, blockID: blockID)
    }

    func requestMoveVertically(_ direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let blockID, canMoveVerticallyOutOfBlock(direction) else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestVerticalMovement: direction,
            preferredTextContainerX: currentCaretTextContainerX()
        ) ?? false
    }

    func draggingPasteboardItem() -> NSPasteboardItem? {
        guard handleView.isEnabled,
              let blockID else {
            return nil
        }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(blockID.rawValue, forType: .blockInputBlockID)
        return pasteboardItem
    }

    func beginDraggingHandle(with event: NSEvent) {
        guard let pasteboardItem = draggingPasteboardItem() else {
            return
        }
        if let blockID {
            delegate?.blockItemDidBeginReordering(self, blockID: blockID)
        }
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(
            handleView.convert(view.bounds, from: view),
            contents: draggingPreviewImage()
        )
        handleView.beginDraggingSession(with: [draggingItem], event: event, source: handleView)
    }

    private func updateHoverTrackingArea() {
        if let trackingArea {
            view.removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        view.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

}

extension BlockInputBlockItem {
    func clearConfiguration() {
        blockID = nil
        renderedBlock = nil
        delegate = nil
        selectionBeforeTextChange = nil
        isHorizontalRule = false
        setBlockSelection(false)
        handleView.blockItem = nil
        horizontalRuleView.blockItem = nil
        horizontalRuleView.resetForReuse()
        textView.cancelBlockSelectionDrag()
        textView.blockItem = nil
        finishBlockSelectionDrag()
        textView.string = ""
        textView.isEditable = true
        textView.textContainerInset = Self.standardTextContainerInset
        scrollView.isHidden = false
        scrollViewLeadingConstraint?.constant = Self.defaultTextLeading
        scrollViewTopConstraint?.constant = 0
        scrollViewBottomConstraint?.constant = 0
        handleTopConstraint?.constant = Self.dragHandleTopConstant(for: .paragraph, metrics: .standard)
        kindLabelTopConstraint?.constant = 0
        checklistButtonTopConstraint?.constant = BlockInputBlockItemVerticalMetrics.standard.checklistButtonTopConstant(
            font: Self.font(for: .paragraph),
            checkboxHeight: Self.checklistButtonHeight
        )
        quoteBarLeadingConstraint?.constant = Self.chromeFrameAlignmentOffset
        quoteBarTopConstraint?.constant = Self.quoteBarVerticalInset
        quoteBarBottomConstraint?.constant = -Self.quoteBarVerticalInset
        horizontalRuleLeadingConstraint?.constant = Self.defaultTextLeading + 4
        quoteBarView.isHidden = true
        quoteBarView.alphaValue = 0
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.font = Self.font(for: .paragraph)
        kindLabel.setMarkerLines([])
        kindLabelLeadingConstraint?.constant = 0
        kindLabelWidthConstraint?.constant = Self.markerGutterWidth
        checklistButton.state = .off
        checklistButton.isHidden = true
        checklistButton.isEnabled = false
        checklistButtonLeadingConstraint?.constant = Self.checklistButtonBaseLeading
        handleView.isEnabled = false
        handleView.isHidden = true
        handleView.alphaValue = 0
        handleView.toolTip = nil
        handleWidthConstraint?.constant = 0
    }
}
