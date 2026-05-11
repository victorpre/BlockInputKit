import Foundation

/// Result of an undo or redo operation, including the selection to restore.
public struct BlockInputUndoResult: Equatable, Sendable {
    public var selection: BlockInputSelection?
    public var actionName: String
}

/// Coordinates per-block text undo with a separate structural undo stack.
public final class BlockInputUndoController {
    private var textUndoByBlockID: [BlockInputBlockID: [BlockInputTextUndoEntry]] = [:]
    private var textRedoByBlockID: [BlockInputBlockID: [BlockInputTextUndoEntry]] = [:]
    private var structuralUndoStack: [BlockInputStructuralUndoEntry] = []
    private var structuralRedoStack: [BlockInputStructuralUndoEntry] = []

    public init() {}

    /// Records a text edit for a single block.
    public func registerTextEdit(
        blockID: BlockInputBlockID,
        beforeText: String,
        afterText: String,
        selectionBefore: BlockInputSelection?,
        selectionAfter: BlockInputSelection?
    ) {
        guard beforeText != afterText else {
            return
        }
        textUndoByBlockID[blockID, default: []].append(BlockInputTextUndoEntry(
            blockID: blockID,
            beforeText: beforeText,
            afterText: afterText,
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
        return BlockInputUndoResult(selection: entry.selectionAfter, actionName: "Text Edit")
    }

    /// Undoes the most recent structural edit.
    public func undoStructuralEdit(in document: inout BlockInputDocument) -> BlockInputUndoResult? {
        guard let entry = structuralUndoStack.popLast() else {
            return nil
        }
        structuralRedoStack.append(entry)
        document = entry.beforeDocument
        return BlockInputUndoResult(selection: entry.selectionBefore, actionName: entry.actionName)
    }

    /// Redoes the most recent undone structural edit.
    public func redoStructuralEdit(in document: inout BlockInputDocument) -> BlockInputUndoResult? {
        guard let entry = structuralRedoStack.popLast() else {
            return nil
        }
        structuralUndoStack.append(entry)
        document = entry.afterDocument
        return BlockInputUndoResult(selection: entry.selectionAfter, actionName: entry.actionName)
    }
}

private struct BlockInputTextUndoEntry {
    let blockID: BlockInputBlockID
    let beforeText: String
    let afterText: String
    let selectionBefore: BlockInputSelection?
    let selectionAfter: BlockInputSelection?
}

private struct BlockInputStructuralUndoEntry {
    let actionName: String
    let beforeDocument: BlockInputDocument
    let afterDocument: BlockInputDocument
    let selectionBefore: BlockInputSelection?
    let selectionAfter: BlockInputSelection?
}
