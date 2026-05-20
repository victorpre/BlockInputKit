import Foundation

/// Inline Markdown link variants that render as chips instead of normal links.
enum BlockInputInlineChipKind: Equatable {
    case fileLink
    case slashCommand
}

extension BlockInputInlineMarkdownRange {
    func inlineChipKind(in text: String) -> BlockInputInlineChipKind? {
        guard style == .link,
              let linkDestination else {
            return nil
        }
        if linkDestination.isFileURL {
            return .fileLink
        }
        return slashCommandChipLabel(in: text) == nil ? nil : .slashCommand
    }

    func slashCommandChipLabel(in text: String) -> String? {
        let label = linkLabel(in: text)
        guard label.hasPrefix("/") else {
            return nil
        }
        return label
    }

    func linkLabel(in text: String) -> String {
        (text as NSString)
            .substring(with: text.blockInputLinkClampedRange(contentRange))
            .blockInputUnescapedLinkLabel
    }
}
