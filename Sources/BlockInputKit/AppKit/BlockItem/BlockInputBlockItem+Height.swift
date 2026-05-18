import AppKit

extension BlockInputBlockItem {
    static func height(for block: BlockInputBlock, textWidth: CGFloat) -> CGFloat {
        let text = block.text.isEmpty ? " " : block.text
        let availableTextWidth = max(textWidth - perLineContentIndent(for: block), 120)
        let font = font(for: block.kind)
        let metrics = verticalMetrics(for: block)
        let hiddenDelimiterRanges = hiddenInlineDelimiterRanges(for: block, text: text)
        let frontMatterReserve = block.kind == .frontMatter
            ? (frontMatterDividerVerticalInset * 2) + frontMatterDividerHeight
            : 0
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
                metrics.minimumHeight + frontMatterReserve,
                singleLineTextHeight(font: font) + metrics.topContentInset + metrics.bottomContentInset + frontMatterReserve + 2
            )
        }
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: availableTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let textKitHeight = textKitHeight(
            for: text,
            width: availableTextWidth,
            font: font,
            hiddenDelimiterRanges: hiddenDelimiterRanges
        )
        let measuredTextHeight = hiddenDelimiterRanges.isEmpty
            ? max(ceil(boundingRect.height), textKitHeight)
            : textKitHeight
        return max(
            metrics.minimumHeight + frontMatterReserve,
            measuredTextHeight
                + metrics.topContentInset
                + metrics.bottomContentInset
                + frontMatterReserve
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
        hiddenDelimiterRanges: [NSRange] = []
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
        case .code, .horizontalRule, .frontMatter, .rawMarkdown:
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
