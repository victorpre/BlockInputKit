import AppKit

extension BlockInputBlockItem {
    static func height(for block: BlockInputBlock, textWidth: CGFloat) -> CGFloat {
        let text = block.text.isEmpty ? " " : block.text
        let availableTextWidth = max(
            textWidth - measuredContentIndent(for: block),
            120
        )
        let font = font(for: block.kind)
        let metrics = verticalMetrics(for: block)
        if case .code = block.kind {
            let codeWidth = max(unwrappedTextWidth(for: text, font: font), availableTextWidth)
            let horizontalScrollerReserve = codeWidth > availableTextWidth
                ? codeHorizontalScrollerReserve
                : 0
            return max(
                metrics.minimumHeight,
                textKitHeight(for: text, width: codeWidth, font: font)
                    + metrics.topContentInset
                    + metrics.bottomContentInset
                    + horizontalScrollerReserve
                    + 2
            )
        }
        if isShortSingleLine(text, likelyFitting: availableTextWidth, font: font) {
            return max(
                metrics.minimumHeight,
                singleLineTextHeight(font: font) + metrics.topContentInset + metrics.bottomContentInset + 2
            )
        }
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: availableTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return max(
            metrics.minimumHeight,
            max(ceil(boundingRect.height), textKitHeight(for: text, width: availableTextWidth, font: font))
                + metrics.topContentInset
                + metrics.bottomContentInset
                + 2
        )
    }

    private static func isShortSingleLine(_ text: String, likelyFitting width: CGFloat, font: NSFont) -> Bool {
        guard text.rangeOfCharacter(from: .newlines) == nil else {
            return false
        }
        guard text.utf16.count <= 24 else {
            return false
        }
        let conservativeCharacterWidth = max(font.pointSize * 0.75, 1)
        return CGFloat(text.utf16.count) * conservativeCharacterWidth <= width
    }

    private static func singleLineTextHeight(font: NSFont) -> CGFloat {
        let boundingRect = (" " as NSString).boundingRect(
            with: NSSize(width: 120, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(boundingRect.height)
    }

    private static func textKitHeight(for text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let textStorage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return ceil(max(usedRect.maxY, singleLineTextHeight(font: font)))
    }

    private static func unwrappedTextWidth(for text: String, font: NSFont) -> CGFloat {
        text.components(separatedBy: .newlines)
            .map { line in
                let measuredLine = line.isEmpty ? " " : line
                return ceil((measuredLine as NSString).size(withAttributes: [.font: font]).width)
            }
            .max() ?? 120
    }

    static func verticalMetrics(for block: BlockInputBlock) -> BlockInputBlockItemVerticalMetrics {
        switch block.kind {
        case .bulletedListItem, .numberedListItem:
            return .textList
        case .checklistItem:
            return .checklist
        case .paragraph, .quote:
            return .textBlock
        case .heading, .code, .horizontalRule, .rawMarkdown:
            return .standard
        }
    }

    static func prefix(for kind: BlockInputBlockKind, indentationLevel: Int) -> String {
        switch kind {
        case .paragraph, .heading, .code, .horizontalRule, .quote, .rawMarkdown:
            return ""
        case .bulletedListItem:
            return unorderedListMarker(indentationLevel: indentationLevel)
        case let .numberedListItem(start):
            return orderedListMarker(start: start, indentationLevel: indentationLevel)
        case let .checklistItem(isChecked):
            return isChecked ? "[x]" : "[ ]"
        }
    }

    static func font(for kind: BlockInputBlockKind) -> NSFont {
        switch kind {
        case let .heading(level):
            let clampedLevel = min(max(level, 1), 6)
            let sizes: [CGFloat] = [26, 23, 20, 18, 16, 15]
            return .systemFont(ofSize: sizes[clampedLevel - 1], weight: .semibold)
        case .code, .rawMarkdown:
            return .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        case .paragraph, .horizontalRule, .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return .preferredFont(forTextStyle: .body)
        }
    }

    static func contentIndent(for block: BlockInputBlock) -> CGFloat {
        guard block.kind.supportsIndentation,
              block.lineIndentationLevels.isEmpty else {
            return 0
        }
        return contentIndent(forIndentationLevel: block.indentationLevel)
    }

    static func measuredContentIndent(for block: BlockInputBlock) -> CGFloat {
        guard block.kind.supportsIndentation else {
            return 0
        }
        let indentationLevel = block.lineIndentationLevels.max() ?? block.indentationLevel
        return contentIndent(forIndentationLevel: indentationLevel)
    }

    static func perLineContentIndent(for block: BlockInputBlock) -> CGFloat {
        guard block.kind.supportsIndentation,
              !block.lineIndentationLevels.isEmpty else {
            return 0
        }
        return measuredContentIndent(for: block)
    }

    static func contentIndent(forIndentationLevel indentationLevel: Int) -> CGFloat {
        CGFloat(max(0, indentationLevel)) * 24
    }

    static func prefixes(for block: BlockInputBlock) -> String {
        prefixes(
            for: block.kind,
            indentationLevel: block.indentationLevel,
            lineIndentationLevels: block.lineIndentationLevels,
            text: block.text
        )
    }

    static func prefixes(for kind: BlockInputBlockKind, indentationLevel: Int, text: String) -> String {
        prefixes(
            for: kind,
            indentationLevel: indentationLevel,
            lineIndentationLevels: [],
            text: text
        )
    }

    static func prefixes(
        for kind: BlockInputBlockKind,
        indentationLevel: Int,
        lineIndentationLevels: [Int],
        text: String
    ) -> String {
        let markerPrefix = prefix(for: kind, indentationLevel: indentationLevel)
        guard kind.repeatsPrefixForTextLines, !markerPrefix.isEmpty else {
            return markerPrefix
        }
        if case let .numberedListItem(start) = kind, !lineIndentationLevels.isEmpty {
            return numberedListMarkers(
                start: start,
                indentationLevel: indentationLevel,
                lineIndentationLevels: lineIndentationLevels,
                lineCount: lineCount(for: text)
            )
        }
        if !lineIndentationLevels.isEmpty {
            return (0..<lineCount(for: text))
                .map { lineOffset in
                    let lineIndentation = lineIndentationLevels.indices.contains(lineOffset)
                        ? lineIndentationLevels[lineOffset]
                        : indentationLevel
                    return prefix(for: kind, indentationLevel: lineIndentation)
                }
                .joined(separator: "\n")
        }
        if case let .numberedListItem(start) = kind {
            return (0..<lineCount(for: text))
                .map { lineOffset in
                    prefix(for: .numberedListItem(start: start + lineOffset), indentationLevel: indentationLevel)
                }
                .joined(separator: "\n")
        }
        return repeatedPrefix(markerPrefix, lineCount: lineCount(for: text))
    }

    static func markerLines(for block: BlockInputBlock) -> [BlockInputMarkerView.MarkerLine] {
        switch block.kind {
        case let .checklistItem(isChecked):
            let lineCount = lineCount(for: block.text)
            guard lineCount > 1 else {
                return []
            }
            let checkboxState: BlockInputMarkerView.CheckboxState = isChecked ? .checked : .unchecked
            return (0..<lineCount).map { lineIndex in
                if lineIndex == 0 {
                    return BlockInputMarkerView.MarkerLine(text: "", indentationLevel: 0)
                }
                return BlockInputMarkerView.MarkerLine(
                    text: "",
                    indentationLevel: markerIndentationLevel(for: block, lineIndex: lineIndex),
                    checkboxState: checkboxState
                )
            }
        default:
            let prefixes = prefixes(for: block)
            guard !prefixes.isEmpty else {
                return []
            }
            return BlockInputLineBreaks.lines(in: prefixes)
                .enumerated()
                .map { lineIndex, marker in
                    BlockInputMarkerView.MarkerLine(
                        text: marker,
                        indentationLevel: markerIndentationLevel(for: block, lineIndex: lineIndex)
                    )
                }
        }
    }

    private static func repeatedPrefix(_ prefix: String, lineCount: Int) -> String {
        Array(repeating: prefix, count: max(1, lineCount)).joined(separator: "\n")
    }

    private static func lineCount(for text: String) -> Int {
        BlockInputLineBreaks.lineCount(in: text)
    }

    private static func numberedListMarkers(
        start: Int,
        indentationLevel: Int,
        lineIndentationLevels: [Int],
        lineCount: Int
    ) -> String {
        var countersByLevel: [Int: Int] = [:]
        let baselineIndentationLevel = lineIndentationLevels.first ?? indentationLevel
        return (0..<lineCount)
            .map { lineOffset in
                let lineIndentation = lineIndentationLevels.indices.contains(lineOffset)
                    ? lineIndentationLevels[lineOffset]
                    : indentationLevel
                countersByLevel = countersByLevel.filter { $0.key <= lineIndentation }
                let counter = countersByLevel[lineIndentation, default: 0]
                countersByLevel[lineIndentation] = counter + 1
                let markerStart = lineIndentation == baselineIndentationLevel ? start + counter : counter + 1
                return prefix(for: .numberedListItem(start: markerStart), indentationLevel: lineIndentation)
            }
            .joined(separator: "\n")
    }

    private static func markerIndentationLevel(for block: BlockInputBlock, lineIndex: Int) -> Int {
        guard block.kind.supportsIndentation,
              !block.lineIndentationLevels.isEmpty else {
            return 0
        }
        return block.indentationLevel(forLine: lineIndex)
    }

    private static func unorderedListMarker(indentationLevel: Int) -> String {
        ["•", "◦", "▪"][max(0, indentationLevel) % 3]
    }

    private static func orderedListMarker(start: Int, indentationLevel: Int) -> String {
        switch max(0, indentationLevel) % 3 {
        case 1:
            return "\(alphabeticMarker(for: start))."
        case 2:
            return "\(romanMarker(for: start))."
        default:
            return "\(start)."
        }
    }

    private static func alphabeticMarker(for value: Int) -> String {
        let scalarValue = UnicodeScalar("a").value + UInt32(max(value - 1, 0) % 26)
        return UnicodeScalar(scalarValue).map(String.init) ?? "a"
    }

    private static func romanMarker(for value: Int) -> String {
        let markers = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"]
        return markers[max(value - 1, 0) % markers.count]
    }

    func applyTextAttributes(for block: BlockInputBlock) {
        let font = Self.font(for: block.kind)
        textView.font = font
        textView.typingAttributes[.font] = font
        guard let textStorage = textView.textStorage else {
            updateTypingAttributesForCurrentSelection()
            return
        }
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard fullRange.length > 0 else {
            updateTypingAttributesForCurrentSelection()
            return
        }
        textStorage.beginEditing()
        textStorage.addAttribute(.font, value: font, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.removeAttribute(.kern, range: fullRange)
        textStorage.removeAttribute(.paragraphStyle, range: fullRange)
        applyCodeBlockAttributes(for: block, textStorage: textStorage)
        applyLineIndentationAttributes(for: block, textStorage: textStorage)
        applyInlineCodeAttributes(for: block, textStorage: textStorage)
        textStorage.endEditing()
        textView.layoutManager?.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
        textView.needsDisplay = true
        updateTypingAttributesForCurrentSelection()
    }

    func updateTypingAttributesForCurrentSelection() {
        guard let block = renderedBlock else {
            return
        }
        var attributes = textView.typingAttributes
        let font = Self.font(for: block.kind)
        attributes[.font] = font
        attributes.removeValue(forKey: .foregroundColor)
        attributes.removeValue(forKey: .backgroundColor)
        attributes.removeValue(forKey: .kern)
        let textLength = (textView.string as NSString).length
        let selectedLocation = min(textView.selectedRange().location, max(textLength - 1, 0))
        let insertionRange = NSRange(location: selectedLocation, length: max(textView.selectedRange().length, 1))
        if inlineCodeContentRanges(for: block).contains(where: { range in
            return NSIntersectionRange(range, insertionRange).length > 0
        }) {
            attributes[.font] = Self.inlineCodeFont(for: font)
            attributes[.foregroundColor] = NSColor.labelColor
            attributes[.backgroundColor] = Self.inlineCodeBackgroundColor
        }
        if block.kind.supportsIndentation, !block.lineIndentationLevels.isEmpty {
            let lineIndex = block.lineIndex(containingUTF16Offset: textView.selectedRange().location)
            let paragraphStyle = Self.paragraphStyle(
                indentationLevel: block.indentationLevel(forLine: lineIndex)
            )
            attributes[.paragraphStyle] = paragraphStyle
            textView.defaultParagraphStyle = paragraphStyle
        } else {
            attributes.removeValue(forKey: .paragraphStyle)
            textView.defaultParagraphStyle = nil
        }
        textView.typingAttributes = attributes
    }

    func applyKindLabelAttributes(for block: BlockInputBlock) {
        kindLabel.setMarkerLines(Self.markerLines(for: block))
        updateMarkerLineYOffsets()
    }

    private func applyLineIndentationAttributes(for block: BlockInputBlock, textStorage: NSTextStorage) {
        guard block.kind.supportsIndentation,
              !block.lineIndentationLevels.isEmpty else {
            return
        }
        let text = textStorage.string as NSString
        var offset = 0
        var lineIndex = 0
        while offset < text.length {
            let lineRange = text.lineRange(for: NSRange(location: offset, length: 0))
            let paragraphStyle = Self.paragraphStyle(indentationLevel: block.indentationLevel(forLine: lineIndex))
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
            offset = NSMaxRange(lineRange)
            lineIndex += 1
        }
    }

    private static func paragraphStyle(indentationLevel: Int) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        let indent = contentIndent(forIndentationLevel: indentationLevel)
        paragraphStyle.firstLineHeadIndent = indent
        paragraphStyle.headIndent = indent
        return paragraphStyle
    }

    func updateMarkerLineYOffsets() {
        guard !kindLabel.markerLines.isEmpty,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            kindLabel.setMarkerLineYOffsets([])
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        let textLength = (textView.string as NSString).length
        let lineStarts = BlockInputLineBreaks.lineStartOffsets(in: textView.string)
        let metrics = lineStarts.prefix(kindLabel.markerLines.count).enumerated().map { lineIndex, lineStart in
            let lineFragment = markerAlignmentRect(
                lineIndex: lineIndex,
                lineStart: lineStart,
                textLength: textLength,
                layoutManager: layoutManager
            )
            let textPoint = NSPoint(x: 0, y: textView.textContainerOrigin.y + lineFragment.minY)
            let itemPoint = textView.convert(textPoint, to: view)
            let markerPoint = kindLabel.convert(itemPoint, from: view)
            return (yOffset: markerPoint.y, height: lineFragment.height)
        }
        kindLabel.setMarkerLineMetrics(
            yOffsets: metrics.map(\.yOffset),
            heights: metrics.map(\.height)
        )
    }

    func updateQuoteBarVerticalExtent() {
        guard renderedBlock?.kind == .quote,
              !quoteBarView.isHidden,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            quoteBarTopConstraint?.constant = Self.quoteBarVerticalInset
            quoteBarBottomConstraint?.constant = -Self.quoteBarVerticalInset
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let textRect = layoutManager.usedRect(for: textContainer).offsetBy(
            dx: textView.textContainerOrigin.x,
            dy: textView.textContainerOrigin.y
        )
        guard !textRect.isEmpty else {
            quoteBarTopConstraint?.constant = Self.quoteBarVerticalInset
            quoteBarBottomConstraint?.constant = -Self.quoteBarVerticalInset
            return
        }

        let itemTextRect = textView.convert(textRect, to: view)
        let quoteBarHeight = max(Self.minimumQuoteBarHeight, itemTextRect.height)
        let textMidY = itemTextRect.midY
        let quoteBarMinY = max(view.bounds.minY + Self.quoteBarVerticalInset, textMidY - quoteBarHeight / 2)
        let quoteBarMaxY = min(view.bounds.maxY - Self.quoteBarVerticalInset, textMidY + quoteBarHeight / 2)
        let topInset = max(Self.quoteBarVerticalInset, view.bounds.maxY - quoteBarMaxY)
        let bottomInset = max(Self.quoteBarVerticalInset, quoteBarMinY - view.bounds.minY)
        quoteBarTopConstraint?.constant = topInset
        quoteBarBottomConstraint?.constant = -bottomInset
    }

    private func markerAlignmentRect(
        lineIndex: Int,
        lineStart: Int,
        textLength: Int,
        layoutManager: NSLayoutManager
    ) -> NSRect {
        guard textLength > 0, lineStart < textLength else {
            let extraLineFragmentRect = layoutManager.extraLineFragmentRect
            guard !extraLineFragmentRect.isEmpty else {
                let font = Self.font(for: renderedBlock?.kind ?? .paragraph)
                let lineHeight = ceil(font.ascender - font.descender + font.leading)
                return NSRect(x: 0, y: CGFloat(lineIndex) * lineHeight, width: 0, height: lineHeight)
            }
            return extraLineFragmentRect
        }
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineStart)
        return layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
    }
}

private extension BlockInputBlockKind {
    var repeatsPrefixForTextLines: Bool {
        switch self {
        case .quote, .bulletedListItem, .numberedListItem:
            return true
        case .paragraph, .heading, .code, .horizontalRule, .checklistItem, .rawMarkdown:
            return false
        }
    }
}
