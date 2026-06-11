import Foundation

extension BlockInputDocument {
    struct BlockInputMetadataExtraction: Equatable {
        var cleanText: String
        var cursorOffset: Int
        var whenDate: String?
        var deadline: String?
        var tags: [String]
    }

    static func extractMetadataTokens(
        from text: String,
        cursorUTF16Offset: Int
    ) -> BlockInputMetadataExtraction? {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(
            pattern: "(?:^|\\s)([@!#])(\\S+)(?=\\s)",
            options: []
        ) else {
            return nil
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return nil }

        let sortedMatches = matches.sorted { $0.range.location > $1.range.location }

        var whenDate: String?
        var deadline: String?
        var tags: [String] = []
        var cleanText = text
        var adjustedOffset = cursorUTF16Offset

        for match in sortedMatches {
            let removalRange = match.range(at: 0)
            let trigger = nsText.substring(with: match.range(at: 1))
            let value = nsText.substring(with: match.range(at: 2))

            assignMetadata(trigger: trigger, value: value, whenDate: &whenDate, deadline: &deadline, tags: &tags)
            adjustedOffset = adjustedCursorOffset(removalRange: removalRange, currentOffset: adjustedOffset)

            let cleanNSString = cleanText as NSString
            cleanText = cleanNSString.replacingCharacters(in: removalRange, with: "")
        }

        let normalized = collapseInternalDoubleSpaces(cleanText)
        guard normalized != collapseInternalDoubleSpaces(text) else {
            return nil
        }

        return BlockInputMetadataExtraction(
            cleanText: normalized,
            cursorOffset: min(adjustedOffset, (normalized as NSString).length),
            whenDate: whenDate,
            deadline: deadline,
            tags: tags
        )
    }

    private static func assignMetadata(
        trigger: String,
        value: String,
        whenDate: inout String?,
        deadline: inout String?,
        tags: inout [String]
    ) {
        switch trigger {
        case "@":
            if whenDate == nil { whenDate = value }
        case "!":
            if deadline == nil { deadline = value }
        case "#":
            tags.append(value)
        default:
            break
        }
    }

    private static func adjustedCursorOffset(removalRange: NSRange, currentOffset: Int) -> Int {
        guard removalRange.location < currentOffset else {
            return currentOffset
        }
        return currentOffset - min(removalRange.length, currentOffset - removalRange.location)
    }

    func metadataTokenExtraction(
        for block: BlockInputBlock,
        proposedText: String,
        proposedUTF16Offset: Int
    ) -> BlockInputMetadataExtraction? {
        guard case .checklistItem = block.kind else {
            return nil
        }
        return Self.extractMetadataTokens(from: proposedText, cursorUTF16Offset: proposedUTF16Offset)
    }

    private static func collapseInternalDoubleSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "  ", with: " ")
    }

    @discardableResult
    mutating func applyMetadataTokenExtraction(
        blockID: BlockInputBlockID,
        extraction: BlockInputMetadataExtraction
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        blocks[index].text = extraction.cleanText
        blocks[index].whenDate = extraction.whenDate
        blocks[index].deadline = extraction.deadline
        blocks[index].tags = extraction.tags
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: extraction.cursorOffset))
    }
}
