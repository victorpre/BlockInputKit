import AppKit

extension BlockInputView {
    func changedBlocksByID(
        before beforeDocument: BlockInputDocument,
        after afterDocument: BlockInputDocument
    ) -> [BlockInputBlock] {
        var beforeBlocksByID: [BlockInputBlockID: BlockInputBlock] = [:]
        for block in beforeDocument.blocks where beforeBlocksByID[block.id] == nil {
            beforeBlocksByID[block.id] = block
        }
        return afterDocument.blocks.filter { beforeBlocksByID[$0.id] != $0 }
    }
}

extension BlockInputView.StoreSyncAction {
    func documentChange(document: BlockInputDocument) -> BlockInputDocumentChange {
        switch self {
        case .replaceDocument:
            return .replaceDocument(document)
        case let .replaceBlock(block):
            return .replaceBlock(block)
        case let .insertBlocks(blocks, insertionIndex):
            return .insertBlocks(blocks, index: insertionIndex)
        case let .deleteBlocks(blockIDs):
            return .deleteBlocks(blockIDs)
        case let .moveBlock(blockID, targetIndex),
             let .moveBlockAndReplaceChangedBlocks(blockID, targetIndex, _):
            return .moveBlock(blockID, index: targetIndex)
        }
    }
}

extension BlockInputView {
    func defaultStoreSyncAction(for result: BlockInputUndoResult) -> StoreSyncAction {
        if result.replacedBlock != nil,
           result.insertedBlocks != nil || result.deletedBlockIDs != nil {
            return .replaceDocument
        }
        if let replacedBlock = result.replacedBlock {
            return .replaceBlock(replacedBlock)
        }
        if let insertedBlocks = result.insertedBlocks,
           let insertionIndex = result.insertionIndex {
            return .insertBlocks(insertedBlocks, insertionIndex: insertionIndex)
        }
        if let deletedBlockIDs = result.deletedBlockIDs {
            return .deleteBlocks(deletedBlockIDs)
        }
        return .replaceDocument
    }
}
