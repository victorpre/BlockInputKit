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

            guard assignMetadata(trigger: trigger, value: value, whenDate: &whenDate, deadline: &deadline, tags: &tags) else {
                continue
            }

            adjustedOffset = adjustedCursorOffset(removalRange: removalRange, currentOffset: adjustedOffset)

            let cleanNSString = cleanText as NSString
            cleanText = cleanNSString.replacingCharacters(in: removalRange, with: "")
        }

        guard whenDate != nil || deadline != nil || !tags.isEmpty else {
            return nil
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

    @discardableResult
    private static func assignMetadata(
        trigger: String,
        value: String,
        whenDate: inout String?,
        deadline: inout String?,
        tags: inout [String]
    ) -> Bool {
        switch trigger {
        case "@":
            guard let date = BlockInputDateResolver.resolveDate(from: value) else {
                return false
            }
            let isoString = BlockInputDateResolver.isoDateString(from: date)
            guard BlockInputDateResolver.categorize(dateString: isoString) != .past else {
                return false
            }
            if whenDate == nil {
                whenDate = isoString
            }
            return true
        case "!":
            guard let date = BlockInputDateResolver.resolveDate(from: value) else {
                return false
            }
            if deadline == nil {
                deadline = BlockInputDateResolver.isoDateString(from: date)
            }
            return true
        case "#":
            tags.append(value)
            return true
        default:
            return false
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
