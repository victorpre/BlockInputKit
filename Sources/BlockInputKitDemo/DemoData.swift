import BlockInputKit
import Foundation

enum DemoData {
    static let largeDocumentBlockCount = 100_000
    static let progressiveLoadBatchLimit = 5_000

    static func mixedDocument() -> BlockInputDocument {
        BlockInputDocument(blocks: [
            BlockInputBlock(kind: .heading(level: 1), text: "BlockInputKit demo"),
            BlockInputBlock(kind: .paragraph, text: "Each visible block owns its own AppKit text input."),
            BlockInputBlock(kind: .quote, text: "Focus, selection, return, delete, and Cmd+A are coordinated across blocks."),
            BlockInputBlock(kind: .horizontalRule),
            BlockInputBlock(kind: .code(language: "swift"), text: "let editor = BlockInputView()\neditor.focusEditor()"),
            BlockInputBlock(kind: .bulletedListItem, text: "Hover rows to reveal reorder handles"),
            BlockInputBlock(kind: .numberedListItem(start: 1), text: "Switch between raw Markdown and rendered blocks"),
            BlockInputBlock(kind: .checklistItem(isChecked: false), text: "Checklist data round-trips through Markdown")
        ])
    }

    static func largeDocument(count: Int = 100_000) -> BlockInputDocument {
        let blocks = (0..<count).map(largeBlock)
        return BlockInputDocument(blocks: blocks)
    }

    static func largeBlock(at index: Int) -> BlockInputBlock {
        let id = BlockInputBlockID(rawValue: "large-\(index)")
        switch index % 8 {
        case 0:
            return BlockInputBlock(id: id, kind: .paragraph, text: "Paragraph block \(index)")
        case 1:
            return BlockInputBlock(id: id, kind: .heading(level: (index % 3) + 1), text: "Heading block \(index)")
        case 2:
            return BlockInputBlock(id: id, kind: .quote, text: "Quote block \(index)")
        case 3:
            return BlockInputBlock(id: id, kind: .bulletedListItem, text: "Bullet block \(index)", indentationLevel: index % 3)
        case 4:
            return BlockInputBlock(id: id, kind: .numberedListItem(start: index + 1), text: "Numbered block \(index)")
        case 5:
            return BlockInputBlock(id: id, kind: .checklistItem(isChecked: index.isMultiple(of: 2)), text: "Checklist block \(index)")
        case 6:
            return BlockInputBlock(id: id, kind: .horizontalRule)
        default:
            return BlockInputBlock(id: id, kind: .code(language: "swift"), text: "let index = \(index)")
        }
    }
}
