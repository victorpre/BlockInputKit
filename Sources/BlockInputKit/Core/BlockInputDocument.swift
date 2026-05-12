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

    /// Deletes a block and returns the cursor selection that should receive focus next.
    @discardableResult
    public mutating func deleteBlock(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        return deleteBlock(at: index)
    }

    /// Deletes the block at an ordered index and returns the cursor selection that should receive focus next.
    @discardableResult
    public mutating func deleteBlock(at index: Int) -> BlockInputSelection? {
        guard blocks.indices.contains(index) else {
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

    /// Deletes selected whole blocks and returns the cursor selection that should receive focus next.
    @discardableResult
    public mutating func deleteBlocks(blockIDs: [BlockInputBlockID]) -> BlockInputSelection? {
        let selectedBlockIDs = Set(blockIDs)
        let deletionIndices = blocks.indices.filter { selectedBlockIDs.contains(blocks[$0].id) }
        guard let firstDeletionIndex = deletionIndices.first else {
            return nil
        }

        if deletionIndices.count == blocks.count {
            let replacement = BlockInputBlock(id: blocks[firstDeletionIndex].id, kind: .paragraph)
            blocks = [replacement]
            return .cursor(BlockInputCursor(blockID: replacement.id, utf16Offset: 0))
        }

        for index in deletionIndices.reversed() {
            blocks.remove(at: index)
        }
        if blocks.indices.contains(firstDeletionIndex - 1) {
            let previous = blocks[firstDeletionIndex - 1]
            return .cursor(BlockInputCursor(blockID: previous.id, utf16Offset: previous.utf16Length))
        }
        if blocks.indices.contains(firstDeletionIndex) {
            let next = blocks[firstDeletionIndex]
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

    /// Merges a paragraph into the previous text block and returns the join-point cursor selection.
    @discardableResult
    public mutating func mergeBlockIntoPrevious(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID),
              index > 0,
              blocks[index].kind == .paragraph,
              blocks[index - 1].kind != .horizontalRule else {
            return nil
        }
        let cursorOffset = blocks[index - 1].utf16Length
        let mergedText = blocks[index - 1].text + blocks[index].text
        blocks[index - 1].text = mergedText
        blocks.remove(at: index)
        return .cursor(BlockInputCursor(blockID: blocks[index - 1].id, utf16Offset: cursorOffset))
    }

    /// Increases a block's nesting level.
    @discardableResult
    public mutating func indentBlock(
        blockID: BlockInputBlockID,
        activeUTF16Offset: Int? = nil
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        guard blocks[index].kind.supportsIndentation else {
            return nil
        }
        if let activeUTF16Offset,
           blocks[index].text.contains("\n") || !blocks[index].lineIndentationLevels.isEmpty {
            let lineIndex = blocks[index].lineIndex(containingUTF16Offset: activeUTF16Offset)
            blocks[index].setIndentationLevel(
                blocks[index].indentationLevel(forLine: lineIndex) + 1,
                forLine: lineIndex
            )
            normalizeNumberedListStartsIfNeeded(around: index)
            return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: activeUTF16Offset))
        }
        blocks[index].indentationLevel += 1
        normalizeNumberedListStartsIfNeeded(around: index)
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

    /// Decreases a block's nesting level.
    @discardableResult
    public mutating func outdentBlock(
        blockID: BlockInputBlockID,
        activeUTF16Offset: Int? = nil
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        guard blocks[index].kind.supportsIndentation else {
            return nil
        }
        if let activeUTF16Offset,
           blocks[index].text.contains("\n") || !blocks[index].lineIndentationLevels.isEmpty {
            let lineIndex = blocks[index].lineIndex(containingUTF16Offset: activeUTF16Offset)
            let currentLevel = blocks[index].indentationLevel(forLine: lineIndex)
            guard currentLevel > 0 else {
                return nil
            }
            blocks[index].setIndentationLevel(currentLevel - 1, forLine: lineIndex)
            normalizeNumberedListStartsIfNeeded(around: index)
            return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: activeUTF16Offset))
        }
        guard blocks[index].indentationLevel > 0 else {
            return nil
        }
        blocks[index].indentationLevel = max(0, blocks[index].indentationLevel - 1)
        normalizeNumberedListStartsIfNeeded(around: index)
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

    /// Toggles a checklist item and returns a cursor selection for that block.
    @discardableResult
    public mutating func toggleChecklistItem(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID),
              case let .checklistItem(isChecked) = blocks[index].kind else {
            return nil
        }
        blocks[index].kind = .checklistItem(isChecked: !isChecked)
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
        if blocks[index].kind == .horizontalRule {
            return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: 0))
        }
        let beforeBlock = blocks[index]
        let editRange = beforeBlock.text.clampedUTF16Range(range)
        let edit = beforeBlock.text.replacingUTF16Characters(in: editRange, with: replacement)
        blocks[index].text = edit.text
        if let lineIndentationLevels = beforeBlock.lineIndentationLevelsAfterReplacingText(
            utf16Offset: editRange.location,
            selectedUTF16Length: editRange.length,
            updatedText: edit.text
        ) {
            blocks[index].lineIndentationLevels = lineIndentationLevels
        }
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
        if block.kind == .horizontalRule,
           currentSelection == .blocks([currentBlockID]) {
            return .blocks(allBlockIDs)
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

private extension String {
    func clampedUTF16Range(_ range: NSRange) -> NSRange {
        let text = self as NSString
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), max(text.length - location, 0))
        return NSRange(location: location, length: length)
    }

    func replacingUTF16Characters(in range: NSRange, with replacement: String) -> (text: String, selectionOffset: Int) {
        let mutable = NSMutableString(string: self)
        let clampedRange = clampedUTF16Range(range)
        mutable.replaceCharacters(in: clampedRange, with: replacement)
        return (mutable as String, clampedRange.location + (replacement as NSString).length)
    }
}
