import AppKit

extension BlockInputBlockItem {
    func applyInlineCodeAttributes(for block: BlockInputBlock, textStorage: NSTextStorage) {
        guard Self.supportsInlineCodeStyling(block.kind) else {
            return
        }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let inlineFont = Self.inlineCodeFont(for: Self.font(for: block.kind))
        let delimiterFont = Self.inlineCodeDelimiterFont(for: Self.font(for: block.kind))
        let backgroundColor = Self.inlineCodeBackgroundColor
        for inlineCodeRange in BlockInputCodeParsing.inlineCodeRanges(in: textStorage.string) {
            let contentRange = NSIntersectionRange(inlineCodeRange.contentRange, fullRange)
            if contentRange.length > 0 {
                textStorage.addAttributes(
                    [
                        .font: inlineFont,
                        .foregroundColor: NSColor.labelColor,
                        .backgroundColor: backgroundColor
                    ],
                    range: contentRange
                )
            }
            for delimiterRange in inlineCodeRange.delimiterRanges {
                let clampedDelimiterRange = NSIntersectionRange(delimiterRange, fullRange)
                guard clampedDelimiterRange.length > 0 else {
                    continue
                }
                textStorage.addAttributes(
                    [
                        .font: delimiterFont,
                        .foregroundColor: NSColor.clear,
                        .backgroundColor: backgroundColor
                    ],
                    range: clampedDelimiterRange
                )
            }
        }
    }

    func inlineCodeContentRanges(for block: BlockInputBlock) -> [NSRange] {
        guard Self.supportsInlineCodeStyling(block.kind) else {
            return []
        }
        return BlockInputCodeParsing.inlineCodeRanges(in: textView.string).map(\.contentRange)
    }

    private static func supportsInlineCodeStyling(_ kind: BlockInputBlockKind) -> Bool {
        switch kind {
        case .paragraph, .heading, .quote, .bulletedListItem, .numberedListItem, .checklistItem:
            return true
        case .code, .horizontalRule, .frontMatter, .rawMarkdown:
            return false
        }
    }

    static func inlineCodeFont(for font: NSFont) -> NSFont {
        .monospacedSystemFont(ofSize: font.pointSize * 0.94, weight: .regular)
    }

    static var inlineCodeBackgroundColor: NSColor {
        NSColor.quaternaryLabelColor
    }

    private static func inlineCodeDelimiterFont(for font: NSFont) -> NSFont {
        .monospacedSystemFont(ofSize: max(font.pointSize * 0.38, 4.5), weight: .regular)
    }
}
