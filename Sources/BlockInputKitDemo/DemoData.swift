import BlockInputKit
import Foundation

enum DemoData {
    static let markdownSample = """
    BlockInputKit Markdown import

    > Quotes become quote blocks.

    - Bulleted list item
      - Nested bullet

    1. Numbered item

    - [ ] Checklist item
    - [x] Completed checklist item

    ```swift
    let editor = BlockInputView()
    ```
    """

    static func mixedDocument() -> BlockInputDocument {
        BlockInputDocument(blocks: [
            BlockInputBlock(kind: .paragraph, text: "BlockInputKit demo"),
            BlockInputBlock(kind: .paragraph, text: "Each visible block owns its own AppKit text input."),
            BlockInputBlock(kind: .quote, text: "Focus, selection, return, delete, and Cmd+A are coordinated across blocks."),
            BlockInputBlock(kind: .code(language: "swift"), text: "let editor = BlockInputView()\neditor.focusEditor()"),
            BlockInputBlock(kind: .bulletedListItem, text: "Hover rows to reveal reorder handles"),
            BlockInputBlock(kind: .numberedListItem(start: 1), text: "Toggle reordering from the toolbar"),
            BlockInputBlock(kind: .checklistItem(isChecked: false), text: "Checklist data round-trips through Markdown"),
            BlockInputBlock(kind: .paragraph, text: "Try mention query: @av"),
            BlockInputBlock(kind: .paragraph, text: "Try slash query: /code")
        ])
    }

    static func swiftUIDocument() -> BlockInputDocument {
        BlockInputDocument(blocks: [
            BlockInputBlock(kind: .paragraph, text: "SwiftUI wrapper preview"),
            BlockInputBlock(kind: .quote, text: "This side panel embeds BlockInputEditor.")
        ])
    }

    static func largeDocument(count: Int = 100_000) -> BlockInputDocument {
        let blocks = (0..<count).map { index -> BlockInputBlock in
            switch index % 6 {
            case 0:
                return BlockInputBlock(kind: .paragraph, text: "Paragraph block \(index)")
            case 1:
                return BlockInputBlock(kind: .quote, text: "Quote block \(index)")
            case 2:
                return BlockInputBlock(kind: .bulletedListItem, text: "Bullet block \(index)", indentationLevel: index % 3)
            case 3:
                return BlockInputBlock(kind: .numberedListItem(start: index + 1), text: "Numbered block \(index)")
            case 4:
                return BlockInputBlock(kind: .checklistItem(isChecked: index.isMultiple(of: 2)), text: "Checklist block \(index)")
            default:
                return BlockInputBlock(kind: .code(language: "swift"), text: "let index = \(index)")
            }
        }
        return BlockInputDocument(blocks: blocks)
    }
}
