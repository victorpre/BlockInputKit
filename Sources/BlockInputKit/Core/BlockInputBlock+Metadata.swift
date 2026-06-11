import Foundation

extension BlockInputBlock {
    /// Metadata tokens appended to the first line of Markdown export for checklist items.
    var metadataMarkdownSuffix: String {
        var parts: [String] = []
        if let whenDate = whenDate, !whenDate.isEmpty {
            parts.append("@\(whenDate)")
        }
        if let deadline = deadline, !deadline.isEmpty {
            parts.append("!\(deadline)")
        }
        for tag in tags where !tag.isEmpty {
            parts.append("#\(tag)")
        }
        guard !parts.isEmpty else {
            return ""
        }
        return " " + parts.joined(separator: " ")
    }

    /// Strips metadata tokens from the block's text and populates metadata properties.
    /// Used during Markdown import to recover structured metadata from inline tokens.
    mutating func applyImportedMetadata() {
        guard case .checklistItem = kind else { return }
        let searchText = text + " "
        guard let extraction = BlockInputDocument.extractMetadataTokens(
            from: searchText,
            cursorUTF16Offset: text.utf16.count
        ) else { return }
        text = extraction.cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        whenDate = extraction.whenDate
        deadline = extraction.deadline
        tags = extraction.tags
    }
}
