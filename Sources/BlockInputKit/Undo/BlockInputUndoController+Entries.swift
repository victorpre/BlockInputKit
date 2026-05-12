import Foundation

struct BlockInputTextUndoEntry {
    let blockID: BlockInputBlockID
    let beforeText: String
    let afterText: String
    let beforeLineIndentationLevels: [Int]?
    let afterLineIndentationLevels: [Int]?
    let selectionBefore: BlockInputSelection?
    let selectionAfter: BlockInputSelection?
}

struct BlockInputStructuralUndoEntry {
    let actionName: String
    let payload: BlockInputStructuralUndoPayload
    let selectionBefore: BlockInputSelection?
    let selectionAfter: BlockInputSelection?

    init(
        actionName: String,
        beforeDocument: BlockInputDocument,
        afterDocument: BlockInputDocument,
        selectionBefore: BlockInputSelection?,
        selectionAfter: BlockInputSelection?
    ) {
        self.actionName = actionName
        payload = .documentReplacement(beforeDocument: beforeDocument, afterDocument: afterDocument)
        self.selectionBefore = selectionBefore
        self.selectionAfter = selectionAfter
    }

    init(
        actionName: String,
        payload: BlockInputStructuralUndoPayload,
        selectionBefore: BlockInputSelection?,
        selectionAfter: BlockInputSelection?
    ) {
        self.actionName = actionName
        self.payload = payload
        self.selectionBefore = selectionBefore
        self.selectionAfter = selectionAfter
    }
}

enum BlockInputStructuralUndoPayload {
    case documentReplacement(beforeDocument: BlockInputDocument, afterDocument: BlockInputDocument)
    case blockReplacement(beforeBlock: BlockInputBlock, afterBlock: BlockInputBlock)
    case blockReplacementInsertion(
        beforeBlock: BlockInputBlock,
        afterBlock: BlockInputBlock,
        insertedBlocks: [BlockInputBlock],
        insertionIndex: Int
    )
    case blockReplacementDeletion(
        beforeBlock: BlockInputBlock,
        afterBlock: BlockInputBlock,
        deletedBlocks: [BlockInputBlock],
        deletionIndex: Int
    )
    case blockInsertion(insertedBlocks: [BlockInputBlock], insertionIndex: Int)
    case blockDeletion(deletedBlocks: [BlockInputBlock], deletionIndex: Int)

    var replacementBlockForUndo: BlockInputBlock? {
        switch self {
        case let .blockReplacement(beforeBlock, _),
             let .blockReplacementInsertion(beforeBlock, _, _, _),
             let .blockReplacementDeletion(beforeBlock, _, _, _):
            return beforeBlock
        case .documentReplacement, .blockInsertion, .blockDeletion:
            return nil
        }
    }

    var replacementBlockForRedo: BlockInputBlock? {
        switch self {
        case let .blockReplacement(_, afterBlock),
             let .blockReplacementInsertion(_, afterBlock, _, _),
             let .blockReplacementDeletion(_, afterBlock, _, _):
            return afterBlock
        case .documentReplacement, .blockInsertion, .blockDeletion:
            return nil
        }
    }

    var deletedBlockIDsForUndo: [BlockInputBlockID]? {
        switch self {
        case let .blockInsertion(insertedBlocks, _),
             let .blockReplacementInsertion(_, _, insertedBlocks, _):
            return insertedBlocks.map(\.id)
        case .documentReplacement, .blockReplacement, .blockReplacementDeletion, .blockDeletion:
            return nil
        }
    }

    var insertedBlocksForRedo: [BlockInputBlock]? {
        switch self {
        case let .blockInsertion(insertedBlocks, _),
             let .blockReplacementInsertion(_, _, insertedBlocks, _):
            return insertedBlocks
        case .documentReplacement, .blockReplacement, .blockReplacementDeletion, .blockDeletion:
            return nil
        }
    }

    var insertionIndexForRedo: Int? {
        switch self {
        case let .blockInsertion(_, insertionIndex),
             let .blockReplacementInsertion(_, _, _, insertionIndex):
            return insertionIndex
        case .documentReplacement, .blockReplacement, .blockReplacementDeletion, .blockDeletion:
            return nil
        }
    }

    var insertedBlocksForUndo: [BlockInputBlock]? {
        switch self {
        case let .blockDeletion(deletedBlocks, _),
             let .blockReplacementDeletion(_, _, deletedBlocks, _):
            return deletedBlocks
        case .documentReplacement, .blockReplacement, .blockReplacementInsertion, .blockInsertion:
            return nil
        }
    }

    var insertionIndexForUndo: Int? {
        switch self {
        case let .blockDeletion(_, deletionIndex),
             let .blockReplacementDeletion(_, _, _, deletionIndex):
            return deletionIndex
        case .documentReplacement, .blockReplacement, .blockReplacementInsertion, .blockInsertion:
            return nil
        }
    }

    var deletedBlockIDsForRedo: [BlockInputBlockID]? {
        switch self {
        case let .blockDeletion(deletedBlocks, _),
             let .blockReplacementDeletion(_, _, deletedBlocks, _):
            return deletedBlocks.map(\.id)
        case .documentReplacement, .blockReplacement, .blockReplacementInsertion, .blockInsertion:
            return nil
        }
    }

    var canApplyGranularly: Bool {
        switch self {
        case .documentReplacement:
            return false
        case .blockReplacement, .blockReplacementInsertion, .blockReplacementDeletion, .blockInsertion, .blockDeletion:
            return true
        }
    }

    func undoResult(selection: BlockInputSelection?, actionName: String) -> BlockInputUndoResult {
        BlockInputUndoResult(
            selection: selection,
            actionName: actionName,
            replacedBlock: replacementBlockForUndo,
            insertedBlocks: insertedBlocksForUndo,
            insertionIndex: insertionIndexForUndo,
            deletedBlockIDs: deletedBlockIDsForUndo
        )
    }

    func redoResult(selection: BlockInputSelection?, actionName: String) -> BlockInputUndoResult {
        BlockInputUndoResult(
            selection: selection,
            actionName: actionName,
            replacedBlock: replacementBlockForRedo,
            insertedBlocks: insertedBlocksForRedo,
            insertionIndex: insertionIndexForRedo,
            deletedBlockIDs: deletedBlockIDsForRedo
        )
    }

    func applyUndo(to document: inout BlockInputDocument) {
        switch self {
        case let .documentReplacement(beforeDocument, _):
            document = beforeDocument
        case let .blockReplacement(beforeBlock, _):
            replace(beforeBlock, in: &document)
        case let .blockReplacementInsertion(beforeBlock, _, insertedBlocks, _):
            replace(beforeBlock, in: &document)
            let insertedIDs = Set(insertedBlocks.map(\.id))
            document.blocks.removeAll { insertedIDs.contains($0.id) }
        case let .blockReplacementDeletion(beforeBlock, _, deletedBlocks, deletionIndex):
            replace(beforeBlock, in: &document)
            document.insertBlocks(deletedBlocks, at: deletionIndex)
        case let .blockInsertion(insertedBlocks, _):
            let insertedIDs = Set(insertedBlocks.map(\.id))
            document.blocks.removeAll { insertedIDs.contains($0.id) }
        case let .blockDeletion(deletedBlocks, deletionIndex):
            document.insertBlocks(deletedBlocks, at: deletionIndex)
        }
    }

    func applyRedo(to document: inout BlockInputDocument) {
        switch self {
        case let .documentReplacement(_, afterDocument):
            document = afterDocument
        case let .blockReplacement(_, afterBlock):
            replace(afterBlock, in: &document)
        case let .blockReplacementInsertion(_, afterBlock, insertedBlocks, insertionIndex):
            replace(afterBlock, in: &document)
            document.insertBlocks(insertedBlocks, at: insertionIndex)
        case let .blockReplacementDeletion(_, afterBlock, deletedBlocks, _):
            replace(afterBlock, in: &document)
            let deletedIDs = Set(deletedBlocks.map(\.id))
            document.blocks.removeAll { deletedIDs.contains($0.id) }
        case let .blockInsertion(insertedBlocks, insertionIndex):
            document.insertBlocks(insertedBlocks, at: insertionIndex)
        case let .blockDeletion(deletedBlocks, _):
            let deletedIDs = Set(deletedBlocks.map(\.id))
            document.blocks.removeAll { deletedIDs.contains($0.id) }
        }
    }

    private func replace(_ block: BlockInputBlock, in document: inout BlockInputDocument) {
        guard let index = document.index(of: block.id) else {
            return
        }
        document.blocks[index] = block
    }
}
