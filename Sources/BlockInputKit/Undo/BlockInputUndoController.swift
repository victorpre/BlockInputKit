import Foundation

/// Result of an undo or redo operation, including the selection to restore.
public struct BlockInputUndoResult: Equatable, Sendable {
    public var selection: BlockInputSelection?
    public var actionName: String
    var replacedBlock: BlockInputBlock?

    init(selection: BlockInputSelection?, actionName: String, replacedBlock: BlockInputBlock? = nil) {
        self.selection = selection
        self.actionName = actionName
        self.replacedBlock = replacedBlock
    }
}

/// Coordinates per-block text undo with a separate structural undo stack.
public final class BlockInputUndoController {
    private var textUndoByBlockID: [BlockInputBlockID: [BlockInputTextUndoEntry]] = [:]
    private var textRedoByBlockID: [BlockInputBlockID: [BlockInputTextUndoEntry]] = [:]
    private var structuralUndoStack: [BlockInputStructuralUndoEntry] = []
    private var structuralRedoStack: [BlockInputStructuralUndoEntry] = []

    public init() {}

    /// Records a text edit for a single block.
    ///
    /// List-like blocks may also pass per-line indentation snapshots when the
    /// edit inserts or removes list lines inside the block.
    public func registerTextEdit(
        blockID: BlockInputBlockID,
        beforeText: String,
        afterText: String,
        beforeLineIndentationLevels: [Int]? = nil,
        afterLineIndentationLevels: [Int]? = nil,
        selectionBefore: BlockInputSelection?,
        selectionAfter: BlockInputSelection?
    ) {
        guard beforeText != afterText || beforeLineIndentationLevels != afterLineIndentationLevels else {
            return
        }
        textUndoByBlockID[blockID, default: []].append(BlockInputTextUndoEntry(
            blockID: blockID,
            beforeText: beforeText,
            afterText: afterText,
            beforeLineIndentationLevels: beforeLineIndentationLevels,
            afterLineIndentationLevels: afterLineIndentationLevels,
            selectionBefore: selectionBefore,
            selectionAfter: selectionAfter
        ))
        textRedoByBlockID[blockID] = []
        structuralRedoStack = []
    }

    /// Records a document-level structural edit.
    public func registerStructuralEdit(
        actionName: String,
        beforeDocument: BlockInputDocument,
        afterDocument: BlockInputDocument,
        selectionBefore: BlockInputSelection?,
        selectionAfter: BlockInputSelection?
    ) {
        guard beforeDocument != afterDocument else {
            return
        }
        structuralUndoStack.append(BlockInputStructuralUndoEntry(
            actionName: actionName,
            beforeDocument: beforeDocument,
            afterDocument: afterDocument,
            selectionBefore: selectionBefore,
            selectionAfter: selectionAfter
        ))
        structuralRedoStack = []
        textRedoByBlockID = [:]
    }

    /// Records a structural edit that replaces one block without snapshotting the full document.
    func registerBlockReplacementStructuralEdit(
        actionName: String,
        beforeBlock: BlockInputBlock,
        afterBlock: BlockInputBlock,
        selectionBefore: BlockInputSelection?,
        selectionAfter: BlockInputSelection?
    ) {
        guard beforeBlock != afterBlock else {
            return
        }
        structuralUndoStack.append(BlockInputStructuralUndoEntry(
            actionName: actionName,
            payload: .blockReplacement(beforeBlock: beforeBlock, afterBlock: afterBlock),
            selectionBefore: selectionBefore,
            selectionAfter: selectionAfter
        ))
        structuralRedoStack = []
        textRedoByBlockID = [:]
    }

    /// Undoes the most recent text edit for a block.
    public func undoTextEdit(
        in document: inout BlockInputDocument,
        blockID: BlockInputBlockID
    ) -> BlockInputUndoResult? {
        guard var stack = textUndoByBlockID[blockID],
              let entry = stack.popLast(),
              let index = document.index(of: blockID) else {
            return nil
        }
        textUndoByBlockID[blockID] = stack
        textRedoByBlockID[blockID, default: []].append(entry)
        document.blocks[index].text = entry.beforeText
        if let beforeLineIndentationLevels = entry.beforeLineIndentationLevels {
            document.blocks[index].lineIndentationLevels = beforeLineIndentationLevels
        }
        return BlockInputUndoResult(selection: entry.selectionBefore, actionName: "Text Edit")
    }

    /// Redoes the most recent undone text edit for a block.
    public func redoTextEdit(
        in document: inout BlockInputDocument,
        blockID: BlockInputBlockID
    ) -> BlockInputUndoResult? {
        guard var stack = textRedoByBlockID[blockID],
              let entry = stack.popLast(),
              let index = document.index(of: blockID) else {
            return nil
        }
        textRedoByBlockID[blockID] = stack
        textUndoByBlockID[blockID, default: []].append(entry)
        document.blocks[index].text = entry.afterText
        if let afterLineIndentationLevels = entry.afterLineIndentationLevels {
            document.blocks[index].lineIndentationLevels = afterLineIndentationLevels
        }
        return BlockInputUndoResult(selection: entry.selectionAfter, actionName: "Text Edit")
    }

    /// Undoes the most recent structural edit.
    public func undoStructuralEdit(in document: inout BlockInputDocument) -> BlockInputUndoResult? {
        guard let entry = structuralUndoStack.popLast() else {
            return nil
        }
        structuralRedoStack.append(entry)
        entry.payload.applyUndo(to: &document)
        return BlockInputUndoResult(
            selection: entry.selectionBefore,
            actionName: entry.actionName,
            replacedBlock: entry.payload.replacementBlockForUndo
        )
    }

    /// Redoes the most recent undone structural edit.
    public func redoStructuralEdit(in document: inout BlockInputDocument) -> BlockInputUndoResult? {
        guard let entry = structuralRedoStack.popLast() else {
            return nil
        }
        structuralUndoStack.append(entry)
        entry.payload.applyRedo(to: &document)
        return BlockInputUndoResult(
            selection: entry.selectionAfter,
            actionName: entry.actionName,
            replacedBlock: entry.payload.replacementBlockForRedo
        )
    }
}

private struct BlockInputTextUndoEntry {
    let blockID: BlockInputBlockID
    let beforeText: String
    let afterText: String
    let beforeLineIndentationLevels: [Int]?
    let afterLineIndentationLevels: [Int]?
    let selectionBefore: BlockInputSelection?
    let selectionAfter: BlockInputSelection?
}

private struct BlockInputStructuralUndoEntry {
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

private enum BlockInputStructuralUndoPayload {
    case documentReplacement(beforeDocument: BlockInputDocument, afterDocument: BlockInputDocument)
    case blockReplacement(beforeBlock: BlockInputBlock, afterBlock: BlockInputBlock)

    var replacementBlockForUndo: BlockInputBlock? {
        guard case let .blockReplacement(beforeBlock, _) = self else {
            return nil
        }
        return beforeBlock
    }

    var replacementBlockForRedo: BlockInputBlock? {
        guard case let .blockReplacement(_, afterBlock) = self else {
            return nil
        }
        return afterBlock
    }

    func applyUndo(to document: inout BlockInputDocument) {
        switch self {
        case let .documentReplacement(beforeDocument, _):
            document = beforeDocument
        case let .blockReplacement(beforeBlock, _):
            replace(beforeBlock, in: &document)
        }
    }

    func applyRedo(to document: inout BlockInputDocument) {
        switch self {
        case let .documentReplacement(_, afterDocument):
            document = afterDocument
        case let .blockReplacement(_, afterBlock):
            replace(afterBlock, in: &document)
        }
    }

    private func replace(_ block: BlockInputBlock, in document: inout BlockInputDocument) {
        guard let index = document.index(of: block.id) else {
            return
        }
        document.blocks[index] = block
    }
}
