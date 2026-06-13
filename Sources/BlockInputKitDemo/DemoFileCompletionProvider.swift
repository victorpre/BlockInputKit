import BlockInputKit
import Foundation

final class DemoFileCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    private let maxCandidateMatches = 500
    private static let slashCommands = [
        DemoSlashCommand(
            title: "Heading",
            label: "heading",
            uri: "blockinputkit-demo://commands/heading",
            argumentHint: "Heading text"
        ),
        DemoSlashCommand(
            title: "Checklist",
            label: "checklist",
            uri: "blockinputkit-demo://commands/checklist",
            argumentHint: "Task"
        ),
        DemoSlashCommand(
            title: "Quote",
            label: "quote",
            uri: "blockinputkit-demo://commands/quote",
            argumentHint: "Quote text"
        )
    ]
    private let slashCommandArgumentHints = BlockInputSlashCommandArgumentHints(
        commandHints: DemoFileCompletionProvider.slashCommands.map { (command: $0.label, hint: $0.argumentHint) },
        requiresDocumentStart: false
    )
    private let launchDirectory: URL
    private let fileManager: FileManager

    init(
        launchDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.launchDirectory = launchDirectory.standardizedFileURL
        self.fileManager = fileManager
    }

    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        switch context.trigger {
        case .mention:
            let dates = dateSuggestions(for: context)
            let files = fileSuggestions(for: context)
            return dates + files
        case .slashCommand:
            return slashCommandSuggestions(for: context)
        }
    }

    func inlineHint(for context: BlockInputInlineHintContext) -> BlockInputInlineHint? {
        slashCommandArgumentHints.inlineHint(for: context)
    }

    private func fileSuggestions(for context: BlockInputCompletionContext) -> [BlockInputCompletionSuggestion] {
        let scope = completionScope(for: context)
        let query = scope.query.lowercased()
        return fileCandidates(under: scope.baseDirectory, matching: query)
            .prefix(50)
            .map { candidate in
                let title = label(for: candidate, scope: scope)
                return BlockInputCompletionSuggestion.fileLink(
                    id: candidate.url.path,
                    title: title,
                    subtitle: candidate.url.deletingLastPathComponent().path,
                    fileURL: candidate.url,
                    detailText: candidate.isDirectory ? "Folder" : nil
                )
            }
    }

    private func dateSuggestions(for context: BlockInputCompletionContext) -> [BlockInputCompletionSuggestion] {
        let query = context.query.lowercased()
        return commonDateEntries().filter { entry in
            query.isEmpty
                || Self.isoDateFormatter.string(from: entry.date).lowercased().contains(query)
                || Self.longDateFormatter.string(from: entry.date).lowercased().contains(query)
                || Self.relativeDateFormatter.string(from: entry.date).lowercased().contains(query)
                || Self.shortDateFormatter.string(from: entry.date).lowercased().contains(query)
                || entry.label?.lowercased().contains(query) == true
        }.map { entry in
            let relativeTitle = Self.relativeDateFormatter.string(from: entry.date)
            let subtitle = Self.mediumDateFormatter.string(from: entry.date)
            let title = entry.label ?? (relativeTitle != subtitle ? relativeTitle : Self.longDateFormatter.string(from: entry.date))
            return BlockInputCompletionSuggestion.date(
                title: title,
                subtitle: subtitle,
                date: entry.date,
                style: .long
            )
        }
    }

    private func commonDateEntries() -> [DemoCommonDateEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DemoCommonDateEntry] = [DemoCommonDateEntry(date: today)]
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            entries.append(DemoCommonDateEntry(date: yesterday))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            entries.append(DemoCommonDateEntry(date: tomorrow))
        }
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (9 - weekday) % 7
        let daysUntilFriday = (13 - weekday) % 7
        if daysUntilMonday > 0,
           let nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday, to: today) {
            entries.append(DemoCommonDateEntry(date: nextMonday))
        }
        if daysUntilFriday > 0,
           let nextFriday = calendar.date(byAdding: .day, value: daysUntilFriday, to: today) {
            entries.append(DemoCommonDateEntry(date: nextFriday))
        }
        if let nextWeek = calendar.date(byAdding: .day, value: 7, to: today) {
            entries.append(DemoCommonDateEntry(date: nextWeek, label: "Next Week"))
        }
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) {
            entries.append(DemoCommonDateEntry(date: nextMonth, label: "Next Month"))
        }
        return entries
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private static let relativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private func slashCommandSuggestions(for context: BlockInputCompletionContext) -> [BlockInputCompletionSuggestion] {
        let query = context.query.lowercased()
        return Self.slashCommands
            .filter { command in
                query.isEmpty ||
                    command.title.lowercased().contains(query) ||
                    command.label.lowercased().contains(query)
            }
            .map { command in
                BlockInputCompletionSuggestion.slashCommand(
                    id: command.uri,
                    title: command.title,
                    uri: command.uri,
                    label: command.label,
                    insertionStyle: .rawToken,
                    detailText: "Command"
                )
            }
    }

    private func completionScope(for context: BlockInputCompletionContext) -> DemoFileCompletionScope {
        if context.rawQuery.hasPrefix("/") {
            return absoluteCompletionScope(for: context.rawQuery)
        }
        return DemoFileCompletionScope(
            baseDirectory: baseDirectory(for: context.fileQuery),
            query: context.query,
            fileQuery: context.fileQuery,
            usesAbsoluteLabels: false
        )
    }

    private func absoluteCompletionScope(for rawQuery: String) -> DemoFileCompletionScope {
        let typedURL = URL(fileURLWithPath: rawQuery, isDirectory: rawQuery.hasSuffix("/")).standardizedFileURL
        var directory = rawQuery.hasSuffix("/") ? typedURL : typedURL.deletingLastPathComponent()
        var query = rawQuery.hasSuffix("/") ? "" : typedURL.lastPathComponent
        while !directoryExists(directory), directory.path != "/" {
            query = [directory.lastPathComponent, query]
                .filter { !$0.isEmpty }
                .joined(separator: "/")
            directory.deleteLastPathComponent()
        }
        if !directoryExists(directory) {
            directory = URL(fileURLWithPath: "/", isDirectory: true)
        }
        return DemoFileCompletionScope(
            baseDirectory: directory.standardizedFileURL,
            query: query,
            fileQuery: nil,
            usesAbsoluteLabels: true
        )
    }

    private func baseDirectory(for fileQuery: BlockInputCompletionFileQuery?) -> URL {
        var directory = launchDirectory
        for _ in 0..<(fileQuery?.levelsUp ?? 0) {
            directory.deleteLastPathComponent()
        }
        return directory.standardizedFileURL
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func fileCandidates(under baseDirectory: URL, matching query: String) -> [DemoFileCompletionCandidate] {
        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        var candidates: [DemoFileCompletionCandidate] = []
        for case let url as URL in enumerator {
            guard !Task.isCancelled else {
                break
            }
            let relativePath = relativePath(for: url, under: baseDirectory)
            guard !relativePath.isEmpty else {
                continue
            }
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            let candidate = DemoFileCompletionCandidate(
                url: url.standardizedFileURL,
                relativePath: relativePath,
                isDirectory: resourceValues?.isDirectory == true
            )
            guard candidate.matches(query: query) else {
                continue
            }
            candidates.append(candidate)
            if candidates.count >= maxCandidateMatches {
                break
            }
        }
        return candidates.sorted { lhs, rhs in
            lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
    }

    private func label(for candidate: DemoFileCompletionCandidate, scope: DemoFileCompletionScope) -> String {
        if scope.usesAbsoluteLabels {
            return candidate.url.path
        }
        guard let reference = scope.fileQuery?.directoryReference else {
            return candidate.relativePath
        }
        switch reference {
        case .current:
            return "./\(candidate.relativePath)"
        case .parent:
            return "../\(candidate.relativePath)"
        case .grandparent:
            return ".../\(candidate.relativePath)"
        }
    }

    private func relativePath(for url: URL, under baseDirectory: URL) -> String {
        let basePath = baseDirectory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if basePath == "/" {
            return path.replacingPrefix("/", with: "")
        }
        return path.replacingPrefix(basePath + "/", with: "")
    }
}

private struct DemoFileCompletionScope {
    var baseDirectory: URL
    var query: String
    var fileQuery: BlockInputCompletionFileQuery?
    var usesAbsoluteLabels: Bool
}

private struct DemoSlashCommand {
    var title: String
    var label: String
    var uri: String
    var argumentHint: String
}

private struct DemoFileCompletionCandidate {
    var url: URL
    var relativePath: String
    var isDirectory: Bool

    func matches(query: String) -> Bool {
        query.isEmpty ||
            relativePath.lowercased().contains(query) ||
            url.path.lowercased().contains(query) ||
            url.lastPathComponent.lowercased().contains(query)
    }
}

private struct DemoCommonDateEntry {
    var date: Date
    var label: String?
}

private extension String {
    func replacingPrefix(_ prefix: String, with replacement: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return replacement + String(dropFirst(prefix.count))
    }
}
