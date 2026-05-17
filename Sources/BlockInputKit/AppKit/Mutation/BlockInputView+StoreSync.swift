import AppKit

extension BlockInputView {
    func syncDocumentStore(_ action: StoreSyncAction) {
        guard let documentStore else {
            return
        }
        guard canSynchronizeDocumentStore(action) else {
            return
        }
        switch action {
        case .replaceDocument:
            documentStore.replaceDocument(document)
        case let .replaceBlock(block):
            documentStore.replaceBlock(block)
        case let .insertBlocks(blocks, insertionIndex):
            documentStore.insertBlocks(blocks, at: insertionIndex)
        case let .deleteBlocks(blockIDs):
            documentStore.deleteBlocks(withIDs: blockIDs)
        case let .moveBlock(blockID, targetIndex):
            documentStore.moveBlock(withID: blockID, to: targetIndex)
        case let .moveBlockAndReplaceChangedBlocks(blockID, targetIndex, changedBlocks):
            if let memoryStore = documentStore as? BlockInputMemoryDocumentStore {
                memoryStore.moveBlockWithoutNormalizing(withID: blockID, to: targetIndex)
            } else {
                documentStore.moveBlock(withID: blockID, to: targetIndex)
            }
            publishDocumentMutation(.moveBlock(blockID, index: targetIndex))
            for block in changedBlocks {
                documentStore.replaceBlock(block)
                publishDocumentMutation(.replaceBlock(block))
            }
            return
        }
        publishDocumentMutation(action.documentChange(document: document))
    }

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
    func canSynchronizeDocumentStore(_ action: StoreSyncAction) -> Bool {
        guard case .replaceDocument = action,
              let documentStore else {
            return true
        }
        return documentStore.isComplete
    }

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
