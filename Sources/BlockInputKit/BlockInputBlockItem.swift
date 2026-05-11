import AppKit

final class BlockInputBlockItem: NSCollectionViewItem, NSTextViewDelegate {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BlockInputBlockItem")
    private static let checklistButtonBaseLeading: CGFloat = 5
    private static let checklistButtonIndentStep: CGFloat = 4
    private static let checklistButtonMaxLeading: CGFloat = 10

    private static let handleWidth: CGFloat = 24
    private static let horizontalChromeWidthWithHandle: CGFloat = 56
    private static let horizontalChromeWidthWithoutHandle: CGFloat = 32
    private let handleView = BlockInputDragHandleView()
    private let kindLabel = NSTextField(labelWithString: "")
    private let checklistButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let scrollView = NSScrollView()
    private let horizontalRuleView = NSView()
    private let textView = BlockInputTextView()
    private var trackingArea: NSTrackingArea?
    private weak var delegate: BlockInputBlockItemDelegate?
    private var blockID: BlockInputBlockID?
    private var selectionBeforeTextChange: BlockInputSelection?
    private var handleWidthConstraint: NSLayoutConstraint?
    private var checklistButtonLeadingConstraint: NSLayoutConstraint?

    var currentSelectedRange: NSRange {
        textView.selectedRange()
    }

    var currentText: String {
        textView.string
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

    func clearConfiguration() {
        blockID = nil
        delegate = nil
        selectionBeforeTextChange = nil
        handleView.blockItem = nil
        textView.blockItem = nil
        textView.string = ""
        textView.isEditable = true
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        kindLabel.stringValue = ""
        checklistButton.state = .off
        checklistButton.isHidden = true
        checklistButton.isEnabled = false
        checklistButtonLeadingConstraint?.constant = Self.checklistButtonBaseLeading
        horizontalRuleView.isHidden = true
        handleView.isEnabled = false
        handleView.isHidden = true
        handleView.alphaValue = 0
        handleView.toolTip = nil
        handleWidthConstraint?.constant = 0
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateHoverTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            handleView.animator().alphaValue = handleView.isEnabled ? 1 : 0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            handleView.animator().alphaValue = 0
        }
    }

    func configure(
        block: BlockInputBlock,
        allowsReordering: Bool,
        delegate: BlockInputBlockItemDelegate
    ) {
        blockID = block.id
        self.delegate = delegate
        selectionBeforeTextChange = nil
        handleView.blockItem = self
        textView.blockItem = self
        textView.string = block.kind == .horizontalRule ? "" : block.text
        configureBlockKindChrome(kind: block.kind, indentationLevel: block.indentationLevel)
        handleView.isEnabled = allowsReordering
        handleView.isHidden = !allowsReordering
        handleView.alphaValue = 0
        handleView.toolTip = allowsReordering ? "Drag to reorder block" : nil
        handleWidthConstraint?.constant = allowsReordering ? Self.handleWidth : 0
    }

    func focusText(atUTF16Offset offset: Int) {
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(
            location: min(max(offset, 0), (textView.string as NSString).length),
            length: 0
        ))
    }

    func focusText(inUTF16Range range: NSRange) {
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(range)
    }

    func setSelectedRange(_ range: NSRange) {
        textView.setSelectedRange(range)
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
        guard let blockID else {
            return
        }
        delegate?.blockItem(self, didChangeSelectionIn: blockID)
    }

    func requestReturn() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestReturn(self, blockID: blockID)
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

    @objc func requestToggleChecklist() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestToggleChecklist(self, blockID: blockID)
    }

    func requestIndent() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestIndent(self, blockID: blockID)
    }

    func requestOutdent() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestOutdent(self, blockID: blockID)
    }

    func requestMoveToPreviousBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestMoveToPreviousBlock(self, blockID: blockID) ?? false
    }

    func requestMoveToNextBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestMoveToNextBlock(self, blockID: blockID) ?? false
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

    private func configureBlockKindChrome(kind: BlockInputBlockKind, indentationLevel: Int) {
        textView.isEditable = kind != .horizontalRule
        horizontalRuleView.isHidden = kind != .horizontalRule
        switch kind {
        case let .checklistItem(isChecked):
            kindLabel.stringValue = ""
            checklistButton.isHidden = false
            checklistButton.isEnabled = true
            checklistButton.state = isChecked ? .on : .off
            checklistButtonLeadingConstraint?.constant = Self.checklistButtonLeadingConstant(indentationLevel: indentationLevel)
        default:
            kindLabel.stringValue = Self.prefix(for: kind, indentationLevel: indentationLevel)
            checklistButton.isHidden = true
            checklistButton.isEnabled = false
            checklistButton.state = .off
            checklistButtonLeadingConstraint?.constant = Self.checklistButtonBaseLeading
        }
    }

    private static func checklistButtonLeadingConstant(indentationLevel: Int) -> CGFloat {
        min(
            checklistButtonBaseLeading + CGFloat(max(0, indentationLevel)) * checklistButtonIndentStep,
            checklistButtonMaxLeading
        )
    }

    private func setupViews() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        handleView.font = .systemFont(ofSize: 13, weight: .semibold)
        handleView.alignment = .center
        handleView.textColor = .secondaryLabelColor
        handleView.alphaValue = 0

        kindLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        kindLabel.alignment = .right
        kindLabel.textColor = .tertiaryLabelColor

        setupChecklistButton()

        setupTextView()
        setupHorizontalRuleView()

        for subview in [handleView, kindLabel, checklistButton, scrollView, horizontalRuleView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let checklistButtonLeadingConstraint = checklistButton.leadingAnchor.constraint(
            equalTo: kindLabel.leadingAnchor,
            constant: Self.checklistButtonBaseLeading
        )
        self.checklistButtonLeadingConstraint = checklistButtonLeadingConstraint

        let handleWidthConstraint = handleView.widthAnchor.constraint(equalToConstant: Self.handleWidth)
        self.handleWidthConstraint = handleWidthConstraint

        NSLayoutConstraint.activate([
            handleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            handleView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleWidthConstraint,

            kindLabel.leadingAnchor.constraint(equalTo: handleView.trailingAnchor),
            kindLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            kindLabel.widthAnchor.constraint(equalToConstant: 28),

            checklistButtonLeadingConstraint,
            checklistButton.centerYAnchor.constraint(equalTo: kindLabel.centerYAnchor),
            checklistButton.widthAnchor.constraint(equalToConstant: 18),
            checklistButton.heightAnchor.constraint(equalToConstant: 18),

            scrollView.leadingAnchor.constraint(equalTo: kindLabel.trailingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            horizontalRuleView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 4),
            horizontalRuleView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -4),
            horizontalRuleView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            horizontalRuleView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupChecklistButton() {
        checklistButton.target = self
        checklistButton.action = #selector(requestToggleChecklist)
        checklistButton.isHidden = true
        checklistButton.toolTip = "Toggle checklist item"
        checklistButton.setAccessibilityLabel("Toggle checklist item")
    }

    private func setupHorizontalRuleView() {
        horizontalRuleView.wantsLayer = true
        horizontalRuleView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        horizontalRuleView.isHidden = true
        horizontalRuleView.setAccessibilityElement(false)
        horizontalRuleView.identifier = NSUserInterfaceItemIdentifier("BlockInputHorizontalRuleView")
    }

    private func setupTextView() {
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = self
    }

    private func draggingPreviewImage() -> NSImage {
        let image = NSImage(size: view.bounds.size)
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return image
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        image.addRepresentation(representation)
        return image
    }

}
