import AppKit

struct BlockInputTableCellConfiguration {
    var text: String
    var isHeader: Bool
    var alignment: NSTextAlignment
    var style: BlockInputStyle
    var position: BlockInputTable.CellPosition
    var tableView: BlockInputTableView?
    var blockItem: BlockInputBlockItem?
}

/// Border, background, and text editing host for one rendered table cell.
final class BlockInputTableCellView: NSView, NSTextViewDelegate {
    let textView = BlockInputTableCellTextView()
    private weak var tableView: BlockInputTableView?
    private var isConfiguring = false
    private var selectionBeforeTextChange: BlockInputSelection?
    private var isHeader = false
    private var isRowSelected = false
    var position = BlockInputTable.CellPosition(row: .header, column: 0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()
        textView.frame = bounds.insetBy(dx: BlockInputTableView.cellHorizontalPadding, dy: BlockInputTableView.cellVerticalPadding)
        textView.textContainer?.containerSize = NSSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutSubtreeIfNeeded()
    }

    func configure(_ configuration: BlockInputTableCellConfiguration) {
        isConfiguring = true
        defer { isConfiguring = false }
        isHeader = configuration.isHeader
        position = configuration.position
        tableView = configuration.tableView
        textView.blockItem = configuration.blockItem
        textView.textStorage?.setAttributedString(BlockInputTableView.attributedString(
            configuration.text,
            isHeader: configuration.isHeader,
            alignment: configuration.alignment,
            style: configuration.style,
            usesPlaceholder: false
        ))
        if let textStorage = textView.textStorage {
            configuration.blockItem?.applyInlineMarkdownAttributes(
                for: BlockInputBlock(kind: .paragraph, text: configuration.text),
                textStorage: textStorage
            )
        }
        updateColors()
    }

    func updateColors() {
        wantsLayer = true
        if isRowSelected {
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.22).cgColor
        } else {
            layer?.backgroundColor = isHeader
                ? NSColor.separatorColor.withAlphaComponent(0.08).cgColor
                : NSColor.textBackgroundColor.withAlphaComponent(0.01).cgColor
        }
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 0.5
    }

    func setRowSelected(_ isSelected: Bool) {
        guard isRowSelected != isSelected else {
            return
        }
        isRowSelected = isSelected
        updateColors()
    }

    private func setup() {
        wantsLayer = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.selectedTextAttributes = BlockInputBlockSelectionChrome.nativeSelectedTextAttributes
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = false
        textView.delegate = self
        addSubview(textView)
        updateColors()
    }

    func textDidBeginEditing(_ notification: Notification) {
        guard !isConfiguring,
              let tableView else {
            return
        }
        tableView.clearRowSelection()
        tableView.delegate?.tableView(tableView, didBeginEditing: position)
    }

    func textDidEndEditing(_ notification: Notification) {
        guard !isConfiguring,
              let tableView else {
            return
        }
        tableView.delegate?.tableView(tableView, didEndEditing: position)
    }

    func textDidChange(_ notification: Notification) {
        guard !isConfiguring,
              let tableView,
              !textView.hasMarkedText() else {
            return
        }
        tableView.delegate?.tableView(
            tableView,
            didChangeText: textView.string,
            in: position,
            selectedLocalRange: textView.selectedRange(),
            selectionBefore: selectionBeforeTextChange
        )
        selectionBeforeTextChange = nil
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isConfiguring,
              let tableView,
              let sourceRange = tableView.sourceRange(for: textView, localRange: textView.selectedRange()) else {
            return
        }
        tableView.clearRowSelection()
        tableView.delegate?.tableView(tableView, didChangeSelectionIn: position, sourceRange: sourceRange)
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard !isConfiguring else {
            return true
        }
        if let replacementString,
           replacementString.rangeOfCharacter(from: .newlines) != nil {
            let singleLineReplacement = Self.singleLineCellReplacement(replacementString)
            textView.insertText(singleLineReplacement, replacementRange: affectedCharRange)
            return false
        }
        guard let tableView else {
            return true
        }
        selectionBeforeTextChange = tableView.sourceSelection(for: textView, localRange: affectedCharRange)
        return tableView.delegate?.tableView(
            tableView,
            shouldChangeTextIn: position,
            affectedLocalRange: affectedCharRange,
            replacementString: replacementString
        ) ?? true
    }

    private static func singleLineCellReplacement(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
