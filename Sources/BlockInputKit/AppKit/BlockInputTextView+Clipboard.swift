import AppKit

extension BlockInputTextView {
    func copySelectedPlainText(allowingEditorRoute: Bool = true) -> Bool {
        let range = selectedRange()
        let copiedText: String?
        if blockItem?.isTableCellTextView(self) == true {
            if allowingEditorRoute, blockItem?.requestCopyActiveSelection() == true {
                return true
            }
            let clampedRange = string.blockInputTextViewClampedRange(range)
            copiedText = BlockInputBlock(text: string).markdownAwareCopiedText(in: clampedRange, fileBaseURL: blockItem?.fileBaseURL)
        } else if var block = blockItem?.renderedBlock {
            block.text = string
            copiedText = block.markdownAwareCopiedText(in: range, fileBaseURL: blockItem?.fileBaseURL)
        } else {
            let clampedRange = string.blockInputTextViewClampedRange(range)
            copiedText = clampedRange.length > 0
                ? (string as NSString).substring(with: clampedRange)
                : nil
        }
        guard let copiedText, !copiedText.isEmpty else {
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copiedText, forType: .string)
        return true
    }
}
