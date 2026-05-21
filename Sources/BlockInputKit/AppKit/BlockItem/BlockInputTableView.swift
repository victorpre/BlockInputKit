import AppKit

/// AppKit table surface used by table blocks.
///
/// The view owns a horizontally scrollable table document and mirrors the
/// offscreen measurement code so collection row heights remain stable when cell
/// content wraps. Cells are intentionally simple rendering surfaces in this
/// phase; editing adapters are layered on top of the same structure later.
final class BlockInputTableView: NSView {
    static let minimumColumnWidth: CGFloat = 120
    static let maximumColumnWidth: CGFloat = 420
    static let cellHorizontalPadding: CGFloat = 10
    static let cellVerticalPadding: CGFloat = 7
    static let fallbackViewportWidth: CGFloat = 520

    private let chromeView = BlockInputTableChromeView()
    private let scrollView = BlockInputTableOverflowScrollView()
    private let documentView = BlockInputTableDocumentView()
    private var cellRows: [[BlockInputTableCellView]] = []
    private var table: BlockInputTable?
    private var style = BlockInputStyle.default
    private var hasAppliedInitialScrollPosition = false

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
        layoutTable()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        chromeView.updateColors()
        cellRows.flatMap { $0 }.forEach { $0.updateColors() }
    }

    func configure(block: BlockInputBlock, style: BlockInputStyle) {
        guard block.kind == .table,
              let table = BlockInputTable(markdown: block.text) else {
            resetForReuse()
            return
        }
        self.table = table
        self.style = style
        hasAppliedInitialScrollPosition = false
        rebuildCells(for: table, style: style)
        isHidden = false
        needsLayout = true
    }

    func resetForReuse() {
        table = nil
        style = .default
        hasAppliedInitialScrollPosition = false
        cellRows.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        cellRows = []
        documentView.frame = .zero
        chromeView.frame = .zero
        scrollView.frame = .zero
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        isHidden = true
    }

    var visibleTableFrame: NSRect {
        chromeView.frame
    }

    var overflowScrollViewForTesting: NSScrollView {
        scrollView
    }

    static func height(for table: BlockInputTable, width: CGFloat, style: BlockInputStyle = .default) -> CGFloat {
        layoutMetrics(for: table, viewportWidth: width, style: style).height
    }

    static func naturalWidth(for table: BlockInputTable, style: BlockInputStyle = .default) -> CGFloat {
        layoutMetrics(for: table, viewportWidth: fallbackViewportWidth, style: style).naturalWidth
    }

    private func setup() {
        isHidden = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        chromeView.translatesAutoresizingMaskIntoConstraints = true
        chromeView.wantsLayer = true
        chromeView.layer?.cornerRadius = 6
        chromeView.layer?.masksToBounds = true
        chromeView.layer?.borderWidth = 1
        chromeView.updateColors()
        addSubview(chromeView)

        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints = true
        chromeView.addSubview(scrollView)
    }

    private func rebuildCells(for table: BlockInputTable, style: BlockInputStyle) {
        cellRows.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        let rowModels = Self.rowModels(for: table)
        cellRows = rowModels.enumerated().map { rowIndex, row in
            (0..<table.columnCount).map { columnIndex in
                let cell = BlockInputTableCellView()
                cell.configure(
                    text: row[columnIndex].text,
                    isHeader: rowIndex == 0,
                    alignment: Self.textAlignment(for: table.alignments[columnIndex]),
                    style: style
                )
                documentView.addSubview(cell)
                return cell
            }
        }
    }

    private func layoutTable() {
        guard let table, table.columnCount > 0 else {
            chromeView.frame = .zero
            scrollView.frame = .zero
            documentView.frame = .zero
            return
        }
        let previousOrigin = scrollView.contentView.bounds.origin
        let metrics = Self.layoutMetrics(for: table, viewportWidth: bounds.width, style: style)
        var currentY: CGFloat = 0
        for (rowIndex, row) in cellRows.enumerated() {
            var currentX: CGFloat = 0
            let rowHeight = metrics.rowHeights[rowIndex]
            for (columnIndex, cell) in row.enumerated() {
                let columnWidth = metrics.columnWidths[columnIndex]
                cell.frame = NSRect(x: currentX, y: currentY, width: columnWidth, height: rowHeight)
                cell.layoutSubtreeIfNeeded()
                currentX += columnWidth
            }
            currentY += rowHeight
        }

        chromeView.frame = NSRect(x: 0, y: 0, width: metrics.viewportWidth, height: metrics.height)
        scrollView.frame = chromeView.bounds
        documentView.frame = NSRect(x: 0, y: 0, width: metrics.naturalWidth, height: metrics.tableHeight)
        restoreScrollPosition(previousOrigin, documentWidth: metrics.naturalWidth, viewportWidth: metrics.viewportWidth)
    }

    private func restoreScrollPosition(_ previousOrigin: NSPoint, documentWidth: CGFloat, viewportWidth: CGFloat) {
        let maximumX = max(0, documentWidth - viewportWidth)
        let targetOrigin: NSPoint
        if hasAppliedInitialScrollPosition {
            targetOrigin = NSPoint(x: min(max(previousOrigin.x, 0), maximumX), y: 0)
        } else {
            targetOrigin = .zero
            hasAppliedInitialScrollPosition = true
        }
        if scrollView.contentView.bounds.origin != targetOrigin {
            scrollView.contentView.scroll(to: targetOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private static func layoutMetrics(
        for table: BlockInputTable,
        viewportWidth: CGFloat,
        style: BlockInputStyle
    ) -> BlockInputTableLayoutMetrics {
        let rows = rowModels(for: table)
        let columnWidths = (0..<table.columnCount).map { columnIndex in
            columnWidth(columnIndex, rows: rows, style: style)
        }
        let naturalWidth = columnWidths.reduce(0, +)
        let viewportWidth = tableViewportWidth(naturalWidth: naturalWidth, proposedWidth: viewportWidth)
        let rowHeights = rows.enumerated().map { rowIndex, row in
            (0..<table.columnCount).map { columnIndex in
                measuredCellHeight(
                    row[columnIndex].text,
                    isHeader: rowIndex == 0,
                    width: columnWidths[columnIndex],
                    alignment: textAlignment(for: table.alignments[columnIndex]),
                    style: style
                )
            }.max() ?? 0
        }
        let tableHeight = rowHeights.reduce(0, +)
        let scrollerReserve = naturalWidth > viewportWidth + 0.5 ? horizontalScrollbarReserve : 0
        return BlockInputTableLayoutMetrics(
            columnWidths: columnWidths,
            rowHeights: rowHeights,
            naturalWidth: naturalWidth,
            viewportWidth: viewportWidth,
            tableHeight: tableHeight,
            height: ceil(tableHeight + scrollerReserve)
        )
    }

    private static func rowModels(for table: BlockInputTable) -> [[BlockInputTable.Cell]] {
        [table.header] + table.bodyRows
    }

    private static func columnWidth(
        _ columnIndex: Int,
        rows: [[BlockInputTable.Cell]],
        style: BlockInputStyle
    ) -> CGFloat {
        let naturalWidth = rows.enumerated().map { rowIndex, row in
            measuredUnwrappedTextWidth(row[columnIndex].text, isHeader: rowIndex == 0, style: style)
        }.max() ?? 0
        let paddedWidth = ceil(naturalWidth + cellHorizontalPadding * 2)
        return min(max(paddedWidth, minimumColumnWidth), maximumColumnWidth)
    }

    private static func tableViewportWidth(naturalWidth: CGFloat, proposedWidth: CGFloat) -> CGFloat {
        let proposedWidth = proposedWidth > 0 ? proposedWidth : fallbackViewportWidth
        return min(naturalWidth, max(proposedWidth, 0))
    }

    private static func measuredUnwrappedTextWidth(_ text: String, isHeader: Bool, style: BlockInputStyle) -> CGFloat {
        ceil((displayText(text) as NSString).size(withAttributes: [.font: font(isHeader: isHeader, style: style)]).width)
    }

    private static func measuredCellHeight(
        _ text: String,
        isHeader: Bool,
        width: CGFloat,
        alignment: NSTextAlignment,
        style: BlockInputStyle
    ) -> CGFloat {
        let attributed = attributedString(text, isHeader: isHeader, alignment: alignment, style: style)
        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textWidth = max(width - cellHorizontalPadding * 2, 0)
        let textContainer = NSTextContainer(size: NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)
        return ceil(max(layoutManager.usedRect(for: textContainer).height, lineHeight(isHeader: isHeader, style: style)) + cellVerticalPadding * 2)
    }

    fileprivate static func attributedString(
        _ text: String,
        isHeader: Bool,
        alignment: NSTextAlignment,
        style: BlockInputStyle
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        return NSAttributedString(
            string: displayText(text),
            attributes: [
                .font: font(isHeader: isHeader, style: style),
                .foregroundColor: style.baseText.foregroundColor ?? NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private static func font(isHeader: Bool, style: BlockInputStyle) -> NSFont {
        let baseFont = BlockInputBlockItem.font(for: .paragraph, style: style)
        guard isHeader else {
            return baseFont
        }
        return NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
    }

    private static func lineHeight(isHeader: Bool, style: BlockInputStyle) -> CGFloat {
        let font = font(isHeader: isHeader, style: style)
        return ceil(font.ascender - font.descender + font.leading)
    }

    private static func displayText(_ text: String) -> String {
        text.isEmpty ? " " : text
    }

    private static func textAlignment(for alignment: BlockInputTable.Alignment) -> NSTextAlignment {
        switch alignment {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }

    private static var horizontalScrollbarReserve: CGFloat {
        // Match Alveary transcript tables: overlay scrollers fade over content,
        // while legacy scrollers need a permanent reserve so the final row stays visible.
        guard NSScroller.preferredScrollerStyle == .legacy else {
            return 0
        }
        return ceil(NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy))
    }
}

private final class BlockInputTableCellView: NSView {
    private let textView = NSTextView()
    private var isHeader = false

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

    func configure(text: String, isHeader: Bool, alignment: NSTextAlignment, style: BlockInputStyle) {
        self.isHeader = isHeader
        textView.textStorage?.setAttributedString(BlockInputTableView.attributedString(
            text,
            isHeader: isHeader,
            alignment: alignment,
            style: style
        ))
        updateColors()
    }

    func updateColors() {
        wantsLayer = true
        layer?.backgroundColor = isHeader
            ? NSColor.separatorColor.withAlphaComponent(0.08).cgColor
            : NSColor.textBackgroundColor.withAlphaComponent(0.01).cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 0.5
    }

    private func setup() {
        wantsLayer = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        addSubview(textView)
        updateColors()
    }
}

private final class BlockInputTableChromeView: NSView {
    override var isFlipped: Bool {
        true
    }

    func updateColors() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.01).cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}

private final class BlockInputTableDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private struct BlockInputTableLayoutMetrics {
    var columnWidths: [CGFloat]
    var rowHeights: [CGFloat]
    var naturalWidth: CGFloat
    var viewportWidth: CGFloat
    var tableHeight: CGFloat
    var height: CGFloat
}
