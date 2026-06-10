import Foundation

/// Inline Markdown link variants that render as chips instead of normal links.
enum BlockInputInlineChipKind: Equatable {
    case fileLink
    case slashCommand
    case rawSlashCommand
    case hashtag
    case dueDateOverdue
    case dueDateToday
    case dueDateUpcoming
}

extension BlockInputInlineMarkdownRange {
    func inlineChipKind(in text: String) -> BlockInputInlineChipKind? {
        if style == .dueDate {
            return dueDateChipKind(in: text)
        }
        if style == .hashtag {
            return .hashtag
        }
        if style == .rawSlashCommand {
            return .rawSlashCommand
        }
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
        if style == .rawSlashCommand {
            return linkLabel(in: text)
        }
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

    private func dueDateChipKind(in text: String) -> BlockInputInlineChipKind? {
        let nsText = text as NSString
        guard contentRange.length == 10,
              nsText.length >= NSMaxRange(contentRange) else {
            return nil
        }
        let dateString = nsText.substring(with: contentRange)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: dateString) else {
            return nil
        }
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: date)
        if dueDay < today {
            return .dueDateOverdue
        } else if dueDay == today {
            return .dueDateToday
        } else {
            return .dueDateUpcoming
        }
    }
}

extension BlockInputStyle {
    func inlineChipStyle(for kind: BlockInputInlineChipKind) -> BlockInputInlineChipStyle {
        switch kind {
        case .fileLink:
            return fileChip
        case .slashCommand:
            return slashCommandChip
        case .rawSlashCommand:
            return rawSlashCommandChip
        case .hashtag:
            return hashtagChip
        case .dueDateOverdue:
            return dueDateOverdueChip
        case .dueDateToday:
            return dueDateTodayChip
        case .dueDateUpcoming:
            return dueDateUpcomingChip
        }
    }
}
