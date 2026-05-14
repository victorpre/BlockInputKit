import Foundation

public extension BlockInputView {
    /// Parses Markdown into blocks and inserts them below a block, or below the active block by default.
    ///
    /// If the document only contains the default empty paragraph, the parsed blocks replace
    /// that placeholder. The edit is recorded on the structural undo stack.
    @discardableResult
    func insertMarkdown(
        _ markdown: String,
        below blockID: BlockInputBlockID? = nil
    ) -> BlockInputSelection? {
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMarkdown.isEmpty else {
            return nil
        }

        let insertedBlocks = BlockInputDocument(markdown: markdown).blocks
        let targetBlockID = blockID ?? activeBlockID
        if let targetBlockID, index(of: targetBlockID) == nil {
            return nil
        }

        return performStructuralEdit(
            named: "Insert Markdown",
            storeSyncAction: { beforeDocument, _, _ in
                if beforeDocument.blocks.count == 1,
                   beforeDocument.blocks[0].kind == .paragraph,
                   beforeDocument.blocks[0].isEmpty {
                    return .replaceDocument
                }
                let insertionIndex = markdownInsertionIndex(below: targetBlockID, in: beforeDocument)
                    ?? beforeDocument.blocks.count
                return .insertBlocks(insertedBlocks, insertionIndex: insertionIndex)
            },
            edit: { document in
                if document.blocks.count == 1,
                   document.blocks[0].kind == .paragraph,
                   document.blocks[0].isEmpty {
                    document.blocks = insertedBlocks
                    guard let firstBlock = insertedBlocks.first else {
                        return nil
                    }
                    return .cursor(BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0))
                }

                guard let insertionIndex = markdownInsertionIndex(below: targetBlockID, in: document) else {
                    return nil
                }
                return document.insertBlocks(insertedBlocks, at: insertionIndex)
            }
        )
    }

    private func markdownInsertionIndex(
        below targetBlockID: BlockInputBlockID?,
        in document: BlockInputDocument
    ) -> Int? {
        if let targetBlockID {
            return document.index(of: targetBlockID).map { $0 + 1 }
        }
        return document.blocks.count
    }
}
