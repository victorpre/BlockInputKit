import AppKit

extension BlockInputBlockItem {
    static func height(for block: BlockInputBlock, textWidth: CGFloat) -> CGFloat {
        let text = block.text.isEmpty ? " " : block.text
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.preferredFont(forTextStyle: .body)]
        )
        return max(34, ceil(boundingRect.height) + 14)
    }

    static func prefix(for kind: BlockInputBlockKind, indentationLevel: Int) -> String {
        let indentation = String(repeating: " ", count: indentationLevel)
        switch kind {
        case .paragraph:
            return ""
        case .code:
            return indentation + "{}"
        case .quote:
            return indentation + ">"
        case .bulletedListItem:
            return indentation + "-"
        case let .numberedListItem(start):
            return indentation + "\(start)."
        case let .checklistItem(isChecked):
            return indentation + (isChecked ? "[x]" : "[ ]")
        }
    }
}
