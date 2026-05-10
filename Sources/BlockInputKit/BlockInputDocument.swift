import Foundation

public struct BlockInputDocument: Equatable, Codable, Sendable {
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

    public init(markdown: String) {
        self = BlockInputMarkdownImporter.document(from: markdown)
    }

    public var markdown: String {
        BlockInputMarkdownSerializer.markdown(from: self)
    }

    public var isEffectivelyEmpty: Bool {
        blocks.allSatisfy(\.isEmpty)
    }

    public func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        blocks.first { $0.id == id }
    }

    public func index(of id: BlockInputBlockID) -> Int? {
        blocks.firstIndex { $0.id == id }
    }

    @discardableResult
    public mutating func insertBlock(
        _ block: BlockInputBlock = .emptyParagraph(),
        at index: Int
    ) -> BlockInputSelection {
        let insertionIndex = min(max(index, 0), blocks.count)
        blocks.insert(block, at: insertionIndex)
        return .cursor(BlockInputCursor(blockID: block.id, utf16Offset: 0))
    }

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

    @discardableResult
    public mutating func handleReturn(in blockID: BlockInputBlockID) -> BlockInputSelection? {
        insertBlockBelow(blockID: blockID)
    }

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

    @discardableResult
    public mutating func deleteEmptyBlockForBackspaceOrDelete(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let block = block(withID: blockID), block.isEmpty else {
            return nil
        }
        return deleteBlock(blockID: blockID)
    }

    @discardableResult
    public mutating func moveBlock(blockID: BlockInputBlockID, to targetIndex: Int) -> BlockInputSelection? {
        guard let sourceIndex = index(of: blockID) else {
            return nil
        }
        let block = blocks.remove(at: sourceIndex)
        blocks.insert(block, at: min(max(targetIndex, 0), blocks.count))
        return .blocks([block.id])
    }

    @discardableResult
    public mutating func indentBlock(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        blocks[index].indentationLevel += 1
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

    @discardableResult
    public mutating func outdentBlock(blockID: BlockInputBlockID) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        blocks[index].indentationLevel = max(0, blocks[index].indentationLevel - 1)
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

    @discardableResult
    public mutating func changeBlockKind(
        blockID: BlockInputBlockID,
        to kind: BlockInputBlockKind
    ) -> BlockInputSelection? {
        guard let index = index(of: blockID) else {
            return nil
        }
        blocks[index].kind = kind
        return .cursor(BlockInputCursor(blockID: blockID, utf16Offset: blocks[index].utf16Length))
    }

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

    public func selectAll(
        currentBlockID: BlockInputBlockID,
        currentSelection: BlockInputSelection?
    ) -> BlockInputSelection? {
        guard let block = block(withID: currentBlockID) else {
            return nil
        }
        let fullRange = BlockInputTextRange(
            blockID: currentBlockID,
            range: NSRange(location: 0, length: block.utf16Length)
        )
        if currentSelection == .text(fullRange) {
            return .blocks(blocks.map(\.id))
        }
        return .text(fullRange)
    }
}

public extension BlockInputBlock {
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
