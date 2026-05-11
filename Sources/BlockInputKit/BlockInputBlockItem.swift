import AppKit

final class BlockInputBlockItem: NSCollectionViewItem, NSTextViewDelegate {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BlockInputBlockItem")
    static let horizontalChromeWidth: CGFloat = 56

    private let handleView = NSTextField(labelWithString: "::")
    private let kindLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = BlockInputTextView()
    private var trackingArea: NSTrackingArea?
    private weak var delegate: BlockInputBlockItemDelegate?
    private var blockID: BlockInputBlockID?
    private var selectionBeforeTextChange: BlockInputSelection?

    var currentSelectedRange: NSRange {
        textView.selectedRange()
    }

    var currentText: String {
        textView.string
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
        textView.blockItem = nil
        textView.string = ""
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        kindLabel.stringValue = ""
        handleView.isEnabled = false
        handleView.alphaValue = 0
        handleView.toolTip = nil
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
        textView.blockItem = self
        textView.string = block.text
        kindLabel.stringValue = Self.prefix(for: block.kind, indentationLevel: block.indentationLevel)
        handleView.isEnabled = allowsReordering
        handleView.alphaValue = 0
        handleView.toolTip = allowsReordering ? "Drag to reorder block" : nil
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

    func requestSelectAll() {
        guard let blockID else {
            return
        }
        delegate?.blockItemDidRequestSelectAll(self, blockID: blockID)
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

    private func setupViews() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        handleView.font = .systemFont(ofSize: 13, weight: .semibold)
        handleView.alignment = .center
        handleView.textColor = .secondaryLabelColor
        handleView.alphaValue = 0

        kindLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        kindLabel.alignment = .right
        kindLabel.textColor = .tertiaryLabelColor

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

        for subview in [handleView, kindLabel, scrollView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            handleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            handleView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleView.widthAnchor.constraint(equalToConstant: 24),

            kindLabel.leadingAnchor.constraint(equalTo: handleView.trailingAnchor),
            kindLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            kindLabel.widthAnchor.constraint(equalToConstant: 28),

            scrollView.leadingAnchor.constraint(equalTo: kindLabel.trailingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

}
