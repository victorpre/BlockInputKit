import AppKit

extension BlockInputTableView {
    static func layoutMetrics(
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

    static func rowModels(for table: BlockInputTable) -> [[BlockInputTable.Cell]] {
        [table.header] + table.bodyRows
    }

    static func columnWidth(
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

    static func tableViewportWidth(naturalWidth: CGFloat, proposedWidth: CGFloat) -> CGFloat {
        let proposedWidth = proposedWidth > 0 ? proposedWidth : fallbackViewportWidth
        return min(naturalWidth, max(proposedWidth, 0))
    }

    static func measuredUnwrappedTextWidth(_ text: String, isHeader: Bool, style: BlockInputStyle) -> CGFloat {
        ceil((displayText(text) as NSString).size(withAttributes: [.font: font(isHeader: isHeader, style: style)]).width)
    }

    static func measuredCellHeight(
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
        let minimumHeight = lineHeight(isHeader: isHeader, style: style)
        return ceil(max(layoutManager.usedRect(for: textContainer).height, minimumHeight) + cellVerticalPadding * 2)
    }

    static func attributedString(
        _ text: String,
        isHeader: Bool,
        alignment: NSTextAlignment,
        style: BlockInputStyle,
        usesPlaceholder: Bool = true
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        return NSAttributedString(
            string: usesPlaceholder ? displayText(text) : text,
            attributes: [
                .font: font(isHeader: isHeader, style: style),
                .foregroundColor: style.baseText.foregroundColor ?? NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    static func font(isHeader: Bool, style: BlockInputStyle) -> NSFont {
        let baseFont = BlockInputBlockItem.font(for: .paragraph, style: style)
        guard isHeader else {
            return baseFont
        }
        return NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
    }

    static func lineHeight(isHeader: Bool, style: BlockInputStyle) -> CGFloat {
        let font = font(isHeader: isHeader, style: style)
        return ceil(font.ascender - font.descender + font.leading)
    }

    static func displayText(_ text: String) -> String {
        text.isEmpty ? " " : text
    }

    static func textAlignment(for alignment: BlockInputTable.Alignment) -> NSTextAlignment {
        switch alignment {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }

    static var horizontalScrollbarReserve: CGFloat {
        ceil(NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay))
    }
}
