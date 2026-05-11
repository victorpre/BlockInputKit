import Foundation

/// Structured block document used as the editor's model and Markdown source of truth.
public struct BlockInputDocument: Equatable, Codable, Sendable {
    /// Ordered blocks in the document. The document always contains at least one block.
    public var blocks: [BlockInputBlock] {
        didSet {
            if blocks.isEmpty {
                blocks = [.emptyParagraph()]
            }
        }
    }

    public init(blocks: [BlockInputBlock] = [.emptyParagraph()]) {
        self.blocks = blocks.isEmpty ? [.emptyParagraph()] : blocks
    }

    /// Parses a Markdown snapshot into structured blocks.
    public init(markdown: String) {
        self = BlockInputMarkdownImporter.document(from: markdown)
    }

    /// Serializes the structured blocks into Markdown.
    public var markdown: String {
        BlockInputMarkdownSerializer.markdown(from: self)
    }

    /// Returns true when every block is empty.
    public var isEffectivelyEmpty: Bool {
        blocks.allSatisfy(\.isEmpty)
    }

    /// Returns a block by stable ID.
    public func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        blocks.first { $0.id == id }
    }

    /// Returns the ordered index for a stable block ID.
    public func index(of id: BlockInputBlockID) -> Int? {
        blocks.firstIndex { $0.id == id }
    }

    /// Inserts a block at a clamped document index and returns the cursor selection for it.
    @discardableResult
    public mutating func insertBlock(
        _ block: BlockInputBlock = .emptyParagraph(),
        at index: Int
    ) -> BlockInputSelection {
        let insertionIndex = min(max(index, 0), blocks.count)
        blocks.insert(block, at: insertionIndex)
        return .cursor(BlockInputCursor(blockID: block.id, utf16Offset: 0))
    }

    /// Inserts a new block below an existing block and returns the cursor selection for it.
    @discardableResult
    public mutating func insertBlockBelow(
        blockID: BlockInputBlockID,
        kind: BlockInputBlockKind = .paragraph
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        let block = BlockInputBlock(kind: kind)
        return insertBlock(block, at: index + 1)
    }

    /// Applies Return key semantics for a block editor.
    @discardableResult
    public mutating func handleReturn(in blockID: BlockInputBlockID) -> BlockInputSelection? {
        insertBlockBelow(blockID: blockID)
    }

    /// Deletes a block and returns the cursor selection that should receive focus next.
    @discardableResult
    public mutating func deleteBlock(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }

        if blocks.count == 1 {
            let replacement = BlockInputBlock(id: blocks[index].id, kind: .paragraph)
            blocks = [replacement]
            return .cursor(BlockInputCursor(blockID: replacement.id, utf16Offset: 0))
        }

        blocks.remove(at: index)
        if blocks.indices.contains(index - 1) {
            let previous = blocks[index - 1]
            return .cursor(BlockInputCursor(blockID: previous.id, utf16Offset: previous.utf16Length))
        }
        if let next = blocks.first {
            return .cursor(BlockInputCursor(blockID: next.id, utf16Offset: 0))
        }
        return nil
    }

    /// Applies Backspace/Delete key semantics for an empty block.
    @discardableResult
    public mutating func deleteEmptyBlockForBackspaceOrDelete(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let block = block(withID: blockID), block.isEmpty else {
            return nil
        }
        return deleteBlock(blockID: blockID)
    }

    /// Moves a block to a document index and returns a block selection for the moved block.
    @discardableResult
    public mutating func moveBlock(blockID: BlockInputBlockID, to targetIndex: Int) -> BlockInputSelection? {
        guard let sourceIndex = index(of: blockID) else {
            return nil
        }
        let finalTargetIndex = min(max(targetIndex, 0), blocks.count - 1)
        guard finalTargetIndex != sourceIndex else {
            return nil
        }
        let block = blocks.remove(at: sourceIndex)
        blocks.insert(block, at: finalTargetIndex)
        return .blocks([block.id])
    }

    /// Increases a block's nesting level.
    @discardableResult
    public mutating func indentBlock(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        blocks[index].indentationLevel += 1
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

    /// Decreases a block's nesting level.
    @discardableResult
    public mutating func outdentBlock(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        guard blocks[index].indentationLevel > 0 else {
            return nil
        }
        blocks[index].indentationLevel = max(0, blocks[index].indentationLevel - 1)
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

    /// Changes a block's semantic kind.
    @discardableResult
    public mutating func changeBlockKind(
        blockID: BlockInputBlockID,
        to kind: BlockInputBlockKind
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        guard blocks[index].kind != kind else {
            return nil
        }
        blocks[index].kind = kind
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

    /// Replaces a UTF-16 range in a block's text and returns the resulting cursor selection.
    @discardableResult
    public mutating func replaceText(
        in blockID: BlockInputBlockID,
        range: NSRange,
        replacement: String
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        let edit = blocks[index].text.replacingUTF16Characters(in: range, with: replacement)
        blocks[index].text = edit.text
        return .cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: edit.selectionOffset
        ))
    }

    /// Implements Cmd+A escalation from current block text selection to all blocks.
    public func selectAll(
        currentBlockID: BlockInputBlockID,
        currentSelection: BlockInputSelection?
    ) -> BlockInputSelection? {
        let allBlockIDs = blocks.map(\.id)
        if currentSelection == .blocks(allBlockIDs) {
            return .blocks(allBlockIDs)
        }
        guard let block = block(withID: currentBlockID) else {
            return nil
        }
        let fullRange = BlockInputTextRange(
            blockID: currentBlockID,
            range: NSRange(location: 0, length: block.utf16Length)
        )
        if currentSelection == .text(fullRange) {
            return .blocks(allBlockIDs)
        }
        return .text(fullRange)
    }
}

public extension BlockInputBlock {
    /// Creates a new empty paragraph block.
    static func emptyParagraph() -> Self {
        BlockInputBlock(kind: .paragraph)
    }
}

private extension String {
    func replacingUTF16Characters(in range: NSRange, with replacement: String) -> (text: String, selectionOffset: Int) {
        let mutable = NSMutableString(string: self)
        let location = min(max(range.location, 0), mutable.length)
        let length = min(max(range.length, 0), max(mutable.length - location, 0))
        mutable.replaceCharacters(in: NSRange(location: location, length: length), with: replacement)
        return (mutable as String, location + (replacement as NSString).length)
    }
}
