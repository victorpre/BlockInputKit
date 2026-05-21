import AppKit

extension BlockInputBlockItem {
    static func height(for block: BlockInputBlock, textWidth: CGFloat, style: BlockInputStyle = .default) -> CGFloat {
        let text = block.text.isEmpty ? " " : block.text
        let availableTextWidth = max(textWidth - perLineContentIndent(for: block), 120)
        let font = font(for: block.kind, style: style)
        let metrics = verticalMetrics(for: block)
        let hiddenDelimiterRanges = hiddenInlineDelimiterRanges(for: block, text: text)
        let inlineCodeRanges = inlineCodeRangesForHeight(for: block, text: text)
        let frontMatterReserve = block.kind == .frontMatter
            ? (frontMatterDividerVerticalInset * 2) + frontMatterDividerHeight
            : 0
        if block.kind == .table,
           let table = BlockInputTable(markdown: block.text) {
            return max(
                metrics.minimumHeight,
                BlockInputTableView.height(for: table, width: availableTextWidth, style: style)
                    + (tableExternalVerticalInset * 2)
            )
        }
        if case .code = block.kind {
            return codeBlockHeight(text: text, availableTextWidth: availableTextWidth, font: font, metrics: metrics)
        }
        return textBlockHeight(BlockInputTextHeightContext(
            text: text,
            availableTextWidth: availableTextWidth,
            font: font,
            metrics: metrics,
            hiddenDelimiterRanges: hiddenDelimiterRanges,
            inlineCodeRanges: inlineCodeRanges,
            frontMatterReserve: frontMatterReserve,
            style: style
        ))
    }

    private static func codeBlockHeight(
        text: String,
        availableTextWidth: CGFloat,
        font: NSFont,
        metrics: BlockInputBlockItemVerticalMetrics
    ) -> CGFloat {
        let codeWidth = max(unwrappedTextWidth(for: text, font: font), availableTextWidth)
        let horizontalScrollerReserve = codeWidth > availableTextWidth ? codeHorizontalScrollerReserve : 0
        return max(
            metrics.minimumHeight,
            textKitHeight(for: text, width: codeWidth, font: font)
                + metrics.topContentInset
                + metrics.bottomContentInset
                + horizontalScrollerReserve
                + 2
        )
    }

    private static func textBlockHeight(_ context: BlockInputTextHeightContext) -> CGFloat {
        if context.inlineCodeRanges.isEmpty,
           isShortSingleLine(context.text, likelyFitting: context.availableTextWidth, font: context.font) {
            return max(
                context.metrics.minimumHeight + context.frontMatterReserve,
                singleLineTextHeight(font: context.font)
                    + context.metrics.topContentInset
                    + context.metrics.bottomContentInset
                    + context.frontMatterReserve
                    + 2
            )
        }
        let boundingRect = (context.text as NSString).boundingRect(
            with: NSSize(width: context.availableTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: context.font]
        )
        let textKitHeight = textKitHeight(
            for: context.text,
            width: context.availableTextWidth,
            font: context.font,
            hiddenDelimiterRanges: context.hiddenDelimiterRanges,
            inlineCodeRanges: context.inlineCodeRanges,
            style: context.style
        )
        let measuredTextHeight = context.hiddenDelimiterRanges.isEmpty
            ? max(ceil(boundingRect.height), textKitHeight)
            : textKitHeight
        return max(
            context.metrics.minimumHeight + context.frontMatterReserve,
            measuredTextHeight
                + context.metrics.topContentInset
                + context.metrics.bottomContentInset
                + context.frontMatterReserve
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

    private static func textKitHeight(
        for text: String,
        width: CGFloat,
        font: NSFont,
        hiddenDelimiterRanges: [NSRange] = [],
        inlineCodeRanges: [BlockInputInlineCodeRange] = [],
        style: BlockInputStyle = .default
    ) -> CGFloat {
        let textStorage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        let delimiterGlyphs = hiddenDelimiterRanges.isEmpty ? nil : BlockInputDelimiterGlyphs()
        layoutManager.delegate = delimiterGlyphs
        let textContainer = NSTextContainer(size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let fullRange = NSRange(location: 0, length: textStorage.length)
        applyInlineCodeHeightAttributes(
            inlineCodeRanges,
            font: font,
            style: style,
            textStorage: textStorage,
            fullRange: fullRange
        )
        for delimiterRange in hiddenDelimiterRanges {
            let clampedDelimiterRange = NSIntersectionRange(delimiterRange, fullRange)
            guard clampedDelimiterRange.length > 0 else {
                continue
            }
            textStorage.addAttribute(.blockInputHiddenDelimiter, value: true, range: clampedDelimiterRange)
        }
        return withExtendedLifetime(delimiterGlyphs) {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            return ceil(max(usedRect.maxY, singleLineTextHeight(font: font)))
        }
    }

    private static func inlineCodeRangesForHeight(for block: BlockInputBlock, text: String) -> [BlockInputInlineCodeRange] {
        guard supportsInlineCodeStyling(block.kind) else {
            return []
        }
        return BlockInputCodeParsing.inlineCodeRanges(in: text)
    }

    private static func applyInlineCodeHeightAttributes(
        _ inlineCodeRanges: [BlockInputInlineCodeRange],
        font: NSFont,
        style: BlockInputStyle,
        textStorage: NSTextStorage,
        fullRange: NSRange
    ) {
        guard !inlineCodeRanges.isEmpty else {
            return
        }
        let inlineFont = inlineCodeFont(for: font, style: style)
        let delimiterFont = inlineCodeDelimiterFont(for: font)
        for inlineCodeRange in inlineCodeRanges {
            let contentRange = NSIntersectionRange(inlineCodeRange.contentRange, fullRange)
            if contentRange.length > 0 {
                textStorage.addAttribute(.font, value: inlineFont, range: contentRange)
            }
            for delimiterRange in inlineCodeRange.delimiterRanges {
                let clampedDelimiterRange = NSIntersectionRange(delimiterRange, fullRange)
                guard clampedDelimiterRange.length > 0 else {
                    continue
                }
                textStorage.addAttribute(.font, value: delimiterFont, range: clampedDelimiterRange)
            }
        }
    }

    private static func hiddenInlineDelimiterRanges(for block: BlockInputBlock, text: String) -> [NSRange] {
        switch block.kind {
        case .paragraph, .heading, .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text)
            let inlineCodeFullRanges = inlineCodeRanges.map(\.fullRange)
            let inlineMarkdownRanges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
                in: text,
                excluding: inlineCodeFullRanges
            )
            return (
                inlineCodeRanges.flatMap(\.delimiterRanges)
                    + inlineMarkdownRanges.flatMap(\.delimiterRanges)
            )
            .sorted { first, second in
                first.location < second.location
            }
        case .code, .horizontalRule, .frontMatter, .table, .rawMarkdown:
            return []
        }
    }

    private static func unwrappedTextWidth(for text: String, font: NSFont) -> CGFloat {
        text.components(separatedBy: .newlines)
            .map { line in
                let measuredLine = line.isEmpty ? " " : line
                return ceil((measuredLine as NSString).size(withAttributes: [.font: font]).width)
            }
            .max() ?? 120
    }
}

private struct BlockInputTextHeightContext {
    var text: String
    var availableTextWidth: CGFloat
    var font: NSFont
    var metrics: BlockInputBlockItemVerticalMetrics
    var hiddenDelimiterRanges: [NSRange]
    var inlineCodeRanges: [BlockInputInlineCodeRange]
    var frontMatterReserve: CGFloat
    var style: BlockInputStyle
}
