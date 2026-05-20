import AppKit

extension BlockInputBlockItem {
    func updateSelectionDependentAttributesForCurrentSelection() {
        guard let block = renderedBlock,
              containsFileLink(in: block) else {
            updateTypingAttributesForCurrentSelection()
            return
        }
        // Chip presentation backs off while editing link source, so file-link blocks need full attribute refreshes.
        applyTextAttributes(for: block)
    }

    private func containsFileLink(in block: BlockInputBlock) -> Bool {
        guard Self.supportsInlineMarkdownStyling(block.kind) else {
            return false
        }
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: textView.string).map(\.fullRange)
        return BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: textView.string,
            excluding: inlineCodeRanges
        )
        .contains { $0.style == .link && $0.linkDestination?.isFileURL == true }
    }
}
