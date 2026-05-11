import Foundation

extension BlockInputDocument {
    struct TypingShortcut: Equatable {
        var kind: BlockInputBlockKind
        var text: String
        var cursorOffset: Int
    }

    func typingShortcut(
        for blockID: BlockInputBlockID,
        proposedText: String,
        proposedUTF16Offset: Int
    ) -> TypingShortcut? {
        guard let block = block(withID: blockID) else {
            return nil
        }
        guard block.kind == .paragraph || block.kind.isHeading else {
            return nil
        }
        guard let match = BlockInputTypingShortcutParser.match(in: proposedText, currentKind: block.kind) else {
            return nil
        }
        let cursorOffset = max(0, proposedUTF16Offset - match.consumedUTF16Length)
        return TypingShortcut(
            kind: match.kind,
            text: match.text,
            cursorOffset: min(cursorOffset, (match.text as NSString).length)
        )
    }

    @discardableResult
    mutating func applyTypingShortcut(
        blockID: BlockInputBlockID,
        shortcut: TypingShortcut
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        blocks[index].kind = shortcut.kind
        blocks[index].text = shortcut.text
        blocks[index].indentationLevel = 0
        let offset = min(shortcut.cursorOffset, blocks[index].utf16Length)
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: offset))
    }

    @discardableResult
    mutating func unwrapBlockToParagraph(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID),
              blocks[index].kind.canUnwrapToParagraph else {
            return nil
        }
        let marker = blocks[index].kind.plainTextRevealMarker
        let cursorOffset: Int
        if let marker {
            let revealedText = marker + blocks[index].text
            blocks[index].kind = .paragraph
            blocks[index].text = revealedText
            cursorOffset = (marker as NSString).length
        } else {
            blocks[index].kind = .paragraph
            cursorOffset = 0
        }
        blocks[index].indentationLevel = 0
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: cursorOffset))
    }
}

private enum BlockInputTypingShortcutParser {
    struct Match {
        var kind: BlockInputBlockKind
        var text: String
        var consumedUTF16Length: Int
    }

    static func match(in text: String, currentKind: BlockInputBlockKind) -> Match? {
        if text == "---", currentKind == .paragraph {
            return Match(kind: .horizontalRule, text: "", consumedUTF16Length: 3)
        }
        if text == "--- ", currentKind == .paragraph {
            return Match(kind: .horizontalRule, text: "", consumedUTF16Length: 4)
        }
        if let heading = headingMatch(in: text) {
            return heading
        }
        guard currentKind == .paragraph else {
            return nil
        }
        return quoteMatch(in: text)
            ?? checklistMatch(in: text)
            ?? bulletMatch(in: text)
            ?? numberedListMatch(in: text)
    }

    private static func headingMatch(in text: String) -> Match? {
        let hashes = text.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes),
              text.dropFirst(hashes).first == " " else {
            return nil
        }
        return Match(
            kind: .heading(level: hashes),
            text: String(text.dropFirst(hashes + 1)),
            consumedUTF16Length: hashes + 1
        )
    }

    private static func quoteMatch(in text: String) -> Match? {
        if text == ">" {
            return Match(kind: .quote, text: "", consumedUTF16Length: 1)
        }
        if text.hasPrefix("> ") {
            return Match(kind: .quote, text: String(text.dropFirst(2)), consumedUTF16Length: 2)
        }
        return nil
    }

    private static func checklistMatch(in text: String) -> Match? {
        if text == "- [ ]" {
            return Match(kind: .checklistItem(isChecked: false), text: "", consumedUTF16Length: 5)
        }
        if text.hasPrefix("- [ ] ") {
            return Match(kind: .checklistItem(isChecked: false), text: String(text.dropFirst(6)), consumedUTF16Length: 6)
        }
        if text == "- [x]" || text == "- [X]" {
            return Match(kind: .checklistItem(isChecked: true), text: "", consumedUTF16Length: 5)
        }
        if text.hasPrefix("- [x] ") || text.hasPrefix("- [X] ") {
            return Match(kind: .checklistItem(isChecked: true), text: String(text.dropFirst(6)), consumedUTF16Length: 6)
        }
        return nil
    }

    private static func bulletMatch(in text: String) -> Match? {
        guard text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("+ ") else {
            return nil
        }
        return Match(kind: .bulletedListItem, text: String(text.dropFirst(2)), consumedUTF16Length: 2)
    }

    private static func numberedListMatch(in text: String) -> Match? {
        var digits = ""
        var cursor = text.startIndex
        while cursor < text.endIndex, text[cursor].isNumber {
            digits.append(text[cursor])
            cursor = text.index(after: cursor)
        }
        guard !digits.isEmpty,
              cursor < text.endIndex,
              text[cursor] == "." else {
            return nil
        }
        cursor = text.index(after: cursor)
        guard cursor < text.endIndex, text[cursor] == " " else {
            return nil
        }
        let textStart = text.index(after: cursor)
        return Match(
            kind: .numberedListItem(start: Int(digits) ?? 1),
            text: String(text[textStart...]),
            consumedUTF16Length: digits.count + 2
        )
    }
}

private extension BlockInputBlockKind {
    var isHeading: Bool {
        if case .heading = self {
            return true
        }
        return false
    }

    var plainTextRevealMarker: String? {
        switch self {
        case .heading(let level):
            return String(repeating: "#", count: min(max(level, 1), 6))
        case .horizontalRule:
            return "---"
        case .quote:
            return ">"
        case .bulletedListItem:
            return "-"
        case .numberedListItem(let start):
            return "\(start)."
        case .checklistItem(let isChecked):
            return isChecked ? "- [x]" : "- [ ]"
        case .paragraph, .code:
            return nil
        }
    }
}
