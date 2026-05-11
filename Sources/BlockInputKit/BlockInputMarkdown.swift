import Foundation

enum BlockInputMarkdownImporter {
    static func document(from markdown: String) -> BlockInputDocument {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [BlockInputBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                index += 1
                continue
            }

            if let language = codeFenceLanguage(in: line) {
                let parsed = parseCodeBlock(lines: lines, startIndex: index, language: language)
                blocks.append(parsed.block)
                index = parsed.nextIndex
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "---" {
                blocks.append(BlockInputBlock(kind: .horizontalRule))
                index += 1
                continue
            }

            if let heading = parseHeading(line) {
                blocks.append(heading)
                index += 1
                continue
            }

            if line.hasPrefix(">") {
                let parsed = parseQuote(lines: lines, startIndex: index)
                blocks.append(parsed.block)
                index = parsed.nextIndex
                continue
            }

            if let listBlock = parseListBlock(line) {
                blocks.append(listBlock)
                index += 1
                continue
            }

            let parsed = parseParagraph(lines: lines, startIndex: index)
            blocks.append(parsed.block)
            index = parsed.nextIndex
        }

        return BlockInputDocument(blocks: blocks)
    }

    private static func codeFenceLanguage(in line: String) -> String?? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") else {
            return nil
        }
        let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return language.isEmpty ? .some(nil) : .some(language)
    }

    private static func parseCodeBlock(
        lines: [String],
        startIndex: Int,
        language: String?
    ) -> (block: BlockInputBlock, nextIndex: Int) {
        var content: [String] = []
        var index = startIndex + 1
        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                return (BlockInputBlock(kind: .code(language: language), text: content.joined(separator: "\n")), index + 1)
            }
            content.append(lines[index])
            index += 1
        }
        return (BlockInputBlock(kind: .code(language: language), text: content.joined(separator: "\n")), index)
    }

    private static func parseQuote(lines: [String], startIndex: Int) -> (block: BlockInputBlock, nextIndex: Int) {
        var content: [String] = []
        var index = startIndex
        while index < lines.count, lines[index].hasPrefix(">") {
            content.append(lines[index].droppingPrefix(">").droppingPrefix(" "))
            index += 1
        }
        return (BlockInputBlock(kind: .quote, text: content.joined(separator: "\n")), index)
    }

    private static func parseParagraph(lines: [String], startIndex: Int) -> (block: BlockInputBlock, nextIndex: Int) {
        var content: [String] = []
        var index = startIndex
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                codeFenceLanguage(in: line) != nil ||
                line.trimmingCharacters(in: .whitespaces) == "---" ||
                parseHeading(line) != nil ||
                line.hasPrefix(">") ||
                parseListBlock(line) != nil {
                break
            }
            content.append(line)
            index += 1
        }
        return (BlockInputBlock(kind: .paragraph, text: content.joined(separator: "\n")), index)
    }

    private static func parseHeading(_ line: String) -> BlockInputBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level),
              trimmed.dropFirst(level).first == " " else {
            return nil
        }
        return BlockInputBlock(kind: .heading(level: level), text: String(trimmed.dropFirst(level + 1)))
    }

    private static func parseListBlock(_ line: String) -> BlockInputBlock? {
        let indentationLevel = line.prefix { $0 == " " }.count / 2
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- [ ] ") {
            return BlockInputBlock(
                kind: .checklistItem(isChecked: false),
                text: String(trimmed.dropFirst(6)),
                indentationLevel: indentationLevel
            )
        }
        if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return BlockInputBlock(
                kind: .checklistItem(isChecked: true),
                text: String(trimmed.dropFirst(6)),
                indentationLevel: indentationLevel
            )
        }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return BlockInputBlock(
                kind: .bulletedListItem,
                text: String(trimmed.dropFirst(2)),
                indentationLevel: indentationLevel
            )
        }
        if let numbered = parseNumberedList(trimmed) {
            return BlockInputBlock(
                kind: .numberedListItem(start: numbered.start),
                text: numbered.text,
                indentationLevel: indentationLevel
            )
        }
        return nil
    }

    private static func parseNumberedList(_ line: String) -> (start: Int, text: String)? {
        var digits = ""
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor].isNumber {
            digits.append(line[cursor])
            cursor = line.index(after: cursor)
        }
        guard !digits.isEmpty,
              cursor < line.endIndex,
              line[cursor] == "." else {
            return nil
        }
        cursor = line.index(after: cursor)
        guard cursor < line.endIndex, line[cursor] == " " else {
            return nil
        }
        let textStart = line.index(after: cursor)
        return (Int(digits) ?? 1, String(line[textStart...]))
    }
}

enum BlockInputMarkdownSerializer {
    static func markdown(from document: BlockInputDocument) -> String {
        document.blocks.map(markdownBlock).joined(separator: "\n\n")
    }

    private static func markdownBlock(_ block: BlockInputBlock) -> String {
        let indent = String(repeating: "  ", count: block.indentationLevel)
        switch block.kind {
        case .paragraph:
            return block.text
        case .heading(let level):
            return "\(String(repeating: "#", count: min(max(level, 1), 6))) \(block.text)"
        case .code(let language):
            let fence = "```" + (language ?? "")
            return "\(fence)\n\(block.text)\n```"
        case .horizontalRule:
            return "---"
        case .quote:
            return block.text.components(separatedBy: .newlines).map { "> \($0)" }.joined(separator: "\n")
        case .bulletedListItem:
            return "\(indent)- \(block.text)"
        case .numberedListItem(let start):
            return "\(indent)\(start). \(block.text)"
        case .checklistItem(let isChecked):
            return "\(indent)- [\(isChecked ? "x" : " ")] \(block.text)"
        }
    }
}

private extension String {
    func droppingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
