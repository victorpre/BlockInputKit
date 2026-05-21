import AppKit

@MainActor
protocol BlockInputTableViewDelegate: AnyObject {
    func tableView(_ tableView: BlockInputTableView, didBeginEditing position: BlockInputTable.CellPosition)
    func tableView(_ tableView: BlockInputTableView, didEndEditing position: BlockInputTable.CellPosition)
    func tableView(_ tableView: BlockInputTableView, didChangeSelectionIn position: BlockInputTable.CellPosition, sourceRange: NSRange)
    func tableView(
        _ tableView: BlockInputTableView,
        didChangeText text: String,
        in position: BlockInputTable.CellPosition,
        selectedLocalRange: NSRange,
        selectionBefore: BlockInputSelection?
    )
    func tableView(
        _ tableView: BlockInputTableView,
        shouldChangeTextIn position: BlockInputTable.CellPosition,
        affectedLocalRange: NSRange,
        replacementString: String?
    ) -> Bool
}

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
    private var configuredBlockID: BlockInputBlockID?
    weak var delegate: BlockInputTableViewDelegate?
    weak var blockItem: BlockInputBlockItem?

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
        if configuredBlockID != block.id {
            hasAppliedInitialScrollPosition = false
            configuredBlockID = block.id
        }
        self.table = table
        self.style = style
        rebuildCells(for: table, style: style)
        isHidden = false
        needsLayout = true
    }

    func resetForReuse() {
        table = nil
        configuredBlockID = nil
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

    func updateTableAfterCellEdit(_ table: BlockInputTable) {
        self.table = table
        needsLayout = true
        documentView.needsLayout = true
    }

    var visibleTableFrame: NSRect {
        chromeView.frame
    }

    var overflowScrollViewForTesting: NSScrollView {
        scrollView
    }

    var activeCellSelectedSourceRange: NSRange? {
        guard let activeCell = activeCellView else {
            return nil
        }
        return sourceRange(for: activeCell.textView, localRange: activeCell.textView.selectedRange())
    }

    func isTableCellTextView(_ textView: NSTextView) -> Bool {
        cellView(containing: textView) != nil
    }

    func sourceRange(for textView: NSTextView, localRange: NSRange) -> NSRange? {
        guard let table,
              let cellView = cellView(containing: textView) else {
            return nil
        }
        return table.sourceRange(forLocalRange: localRange, in: cellView.position)
    }

    func sourceSelection(for textView: NSTextView, localRange: NSRange) -> BlockInputSelection? {
        guard let configuredBlockID,
              let sourceRange = sourceRange(for: textView, localRange: localRange) else {
            return nil
        }
        if sourceRange.length == 0 {
            return .cursor(BlockInputCursor(blockID: configuredBlockID, utf16Offset: sourceRange.location))
        }
        return .text(BlockInputTextRange(blockID: configuredBlockID, range: sourceRange))
    }

    func sourceInlineMarkdownRange(
        for textView: NSTextView,
        localRange: BlockInputInlineMarkdownRange
    ) -> BlockInputInlineMarkdownRange? {
        guard let sourceFullRange = sourceRange(for: textView, localRange: localRange.fullRange),
              let sourceContentRange = sourceRange(for: textView, localRange: localRange.contentRange) else {
            return nil
        }
        let delimiterRanges = localRange.delimiterRanges.compactMap { sourceRange(for: textView, localRange: $0) }
        guard delimiterRanges.count == localRange.delimiterRanges.count else {
            return nil
        }
        return BlockInputInlineMarkdownRange(
            style: localRange.style,
            fullRange: sourceFullRange,
            contentRange: sourceContentRange,
            delimiterRanges: delimiterRanges,
            linkDestination: localRange.linkDestination
        )
    }

    func sourceOffset(atWindowLocation windowLocation: NSPoint) -> Int? {
        guard let cellView = cellView(atWindowLocation: windowLocation) else {
            return nil
        }
        let localRange = cellView.textView.localInsertionRange(atWindowLocation: windowLocation)
        guard let sourceRange = sourceRange(for: cellView.textView, localRange: localRange) else {
            return nil
        }
        return sourceRange.location
    }

    func anchorWindowRect(forSourceRange range: NSRange) -> NSRect? {
        guard let table,
              let position = table.cellPosition(containingSourceRange: range),
              let localRange = table.localRange(forSourceRange: range, in: position),
              let cellView = cellView(at: position) else {
            return nil
        }
        return cellView.textView.anchorWindowRect(forLocalRange: localRange)
    }

    @discardableResult
    func focusSourceRange(_ range: NSRange) -> Bool {
        guard let table,
              let position = table.cellPosition(containingSourceRange: range),
              let localRange = table.localRange(forSourceRange: range, in: position),
              let cellView = cellView(at: position) else {
            return false
        }
        window?.makeFirstResponder(cellView.textView)
        cellView.textView.setSelectedRange(localRange)
        cellView.textView.scrollRangeToVisible(localRange)
        return true
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
                cell.configure(BlockInputTableCellConfiguration(
                    text: row[columnIndex].text,
                    isHeader: rowIndex == 0,
                    alignment: Self.textAlignment(for: table.alignments[columnIndex]),
                    style: style,
                    position: Self.cellPosition(rowIndex: rowIndex, columnIndex: columnIndex),
                    tableView: self,
                    blockItem: blockItem
                ))
                documentView.addSubview(cell)
                return cell
            }
        }
    }

    private static func cellPosition(rowIndex: Int, columnIndex: Int) -> BlockInputTable.CellPosition {
        rowIndex == 0
            ? .init(row: .header, column: columnIndex)
            : .init(row: .body(rowIndex - 1), column: columnIndex)
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

    static func attributedString(
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

    private var activeCellView: BlockInputTableCellView? {
        guard let responder = window?.firstResponder as? NSTextView else {
            return nil
        }
        return cellView(containing: responder)
    }

    private func cellView(containing textView: NSTextView) -> BlockInputTableCellView? {
        cellRows.flatMap { $0 }.first { $0.textView === textView }
    }

    private func cellView(at position: BlockInputTable.CellPosition) -> BlockInputTableCellView? {
        cellRows.flatMap { $0 }.first { $0.position == position }
    }

    private func cellView(atWindowLocation windowLocation: NSPoint) -> BlockInputTableCellView? {
        cellRows.flatMap { $0 }.first { cell in
            let localPoint = cell.textView.convert(windowLocation, from: nil)
            return cell.textView.bounds.contains(localPoint)
        }
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
