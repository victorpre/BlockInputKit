import Foundation

extension BlockInputDocument {
    struct TypingShortcut: Equatable {
        var kind: BlockInputBlockKind
        var text: String
        var cursorOffset: Int
        var preservesIndentation: Bool = false
        var insertedBlockText: String?
    }

    func typingShortcut(
        for blockID: BlockInputBlockID,
        proposedText: String,
        proposedUTF16Offset: Int
    ) -> TypingShortcut? {
        guard let block = block(withID: blockID) else {
            return nil
        }
        return typingShortcut(
            for: block,
            proposedText: proposedText,
            proposedUTF16Offset: proposedUTF16Offset
        )
    }

    func typingShortcut(
        for block: BlockInputBlock,
        proposedText: String,
        proposedUTF16Offset: Int
    ) -> TypingShortcut? {
        guard block.kind == .paragraph || block.kind.isHeading || block.kind == .bulletedListItem else {
            return nil
        }
        guard let match = BlockInputTypingShortcutParser.match(in: proposedText, currentKind: block.kind) else {
            return nil
        }
        let cursorOffset = max(0, proposedUTF16Offset - match.consumedUTF16Length)
        return TypingShortcut(
            kind: match.kind,
            text: match.kind == .horizontalRule ? "" : match.text,
            cursorOffset: min(cursorOffset, (match.text as NSString).length),
            preservesIndentation: match.preservesIndentation,
            insertedBlockText: match.kind == .horizontalRule ? match.text : nil
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
        if !shortcut.preservesIndentation {
            blocks[index].indentationLevel = 0
        }
        if shortcut.kind == .horizontalRule {
            let nextBlock = BlockInputBlock(kind: .paragraph, text: shortcut.insertedBlockText ?? "")
            blocks.insert(nextBlock, at: index + 1)
            return .cursor(BlockInputCursor(
                blockID: nextBlock.id,
                utf16Offset: min(shortcut.cursorOffset, nextBlock.utf16Length)
            ))
        }
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
        var preservesIndentation: Bool = false
    }

    static func match(in text: String, currentKind: BlockInputBlockKind) -> Match? {
        if currentKind == .paragraph,
           let horizontalRule = horizontalRuleMatch(in: text) {
            return horizontalRule
        }
        if currentKind != .bulletedListItem,
           let heading = headingMatch(in: text) {
            return heading
        }
        if currentKind == .bulletedListItem {
            return checklistMatch(in: text, consumesLeadingDash: false, preservesIndentation: true)
        }
        guard currentKind == .paragraph else {
            return nil
        }
        return quoteMatch(in: text)
            ?? checklistMatch(in: text, consumesLeadingDash: true, preservesIndentation: false)
            ?? bulletMatch(in: text)
            ?? numberedListMatch(in: text)
    }

    private static func horizontalRuleMatch(in text: String) -> Match? {
        if text == "---" {
            return Match(kind: .horizontalRule, text: "", consumedUTF16Length: 3)
        }
        guard text.hasPrefix("--- ") else {
            return nil
        }
        let suffixStart = text.index(text.startIndex, offsetBy: 4)
        let suffix = text[suffixStart...]
        let trimmedSuffix = suffix.drop { $0 == " " }
        let trimmedLeadingSpaceCount = suffix.distance(from: suffix.startIndex, to: trimmedSuffix.startIndex)
        return Match(
            kind: .horizontalRule,
            text: String(trimmedSuffix),
            consumedUTF16Length: 4 + trimmedLeadingSpaceCount
        )
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

    private static func checklistMatch(
        in text: String,
        consumesLeadingDash: Bool,
        preservesIndentation: Bool
    ) -> Match? {
        let uncheckedMarker = consumesLeadingDash ? "- [ ]" : "[ ]"
        let checkedMarker = consumesLeadingDash ? "- [x]" : "[x]"
        let uppercaseCheckedMarker = consumesLeadingDash ? "- [X]" : "[X]"
        let exactMarkerLength = (uncheckedMarker as NSString).length
        let markerAndSpaceLength = exactMarkerLength + 1
        if text == uncheckedMarker {
            return Match(
                kind: .checklistItem(isChecked: false),
                text: "",
                consumedUTF16Length: exactMarkerLength,
                preservesIndentation: preservesIndentation
            )
        }
        if text.hasPrefix("\(uncheckedMarker) ") {
            return Match(
                kind: .checklistItem(isChecked: false),
                text: String(text.dropFirst(markerAndSpaceLength)),
                consumedUTF16Length: markerAndSpaceLength,
                preservesIndentation: preservesIndentation
            )
        }
        if text == checkedMarker || text == uppercaseCheckedMarker {
            return Match(
                kind: .checklistItem(isChecked: true),
                text: "",
                consumedUTF16Length: exactMarkerLength,
                preservesIndentation: preservesIndentation
            )
        }
        if text.hasPrefix("\(checkedMarker) ") || text.hasPrefix("\(uppercaseCheckedMarker) ") {
            return Match(
                kind: .checklistItem(isChecked: true),
                text: String(text.dropFirst(markerAndSpaceLength)),
                consumedUTF16Length: markerAndSpaceLength,
                preservesIndentation: preservesIndentation
            )
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

extension BlockInputBlockKind {
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
        case .paragraph, .code, .rawMarkdown:
            return nil
        }
    }
}
