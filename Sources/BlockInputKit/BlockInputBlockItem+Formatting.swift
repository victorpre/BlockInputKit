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
        case .heading(let level):
            return String(repeating: "#", count: min(max(level, 1), 6))
        case .code:
            return indentation + "{}"
        case .horizontalRule:
            return ""
        case .quote:
            return indentation + ">"
        case .bulletedListItem:
            return indentation + unorderedListMarker(indentationLevel: indentationLevel)
        case let .numberedListItem(start):
            return indentation + orderedListMarker(start: start, indentationLevel: indentationLevel)
        case let .checklistItem(isChecked):
            return indentation + (isChecked ? "[x]" : "[ ]")
        }
    }

    private static func unorderedListMarker(indentationLevel: Int) -> String {
        ["-", "*", "+"][max(0, indentationLevel) % 3]
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
}
