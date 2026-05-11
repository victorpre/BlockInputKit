import Foundation

extension BlockInputView {
    enum StoreSyncAction {
        case replaceDocument
        case replaceBlock(BlockInputBlock)
        case insertBlocks([BlockInputBlock], insertionIndex: Int)
        case deleteBlocks([BlockInputBlockID])
        case moveBlock(BlockInputBlockID, targetIndex: Int)
    }

    func publishDocumentChange() {
        onDocumentChange?(document)
    }

    func syncDocumentStore(_ action: StoreSyncAction) {
        guard let documentStore else {
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
        }
    }

    func refreshDocumentFromStore() {
        if let documentStore {
            document = documentStore.document
        }
    }

    func performStructuralEdit(
        named actionName: String,
        storeSyncAction: (
            _ beforeDocument: BlockInputDocument,
            _ afterDocument: BlockInputDocument,
            _ afterSelection: BlockInputSelection
        ) -> StoreSyncAction = { _, _, _ in .replaceDocument },
        edit: (inout BlockInputDocument) -> BlockInputSelection?
    ) -> BlockInputSelection? {
        refreshDocumentFromStore()
        let beforeDocument = document
        let beforeSelection = selection
        guard let afterSelection = edit(&document) else {
            return nil
        }
        guard beforeDocument != document else {
            applySelection(afterSelection, notify: beforeSelection != afterSelection)
            return nil
        }
        syncDocumentStore(storeSyncAction(beforeDocument, document, afterSelection))
        applySelection(afterSelection, notify: true)
        undoController?.registerStructuralEdit(
            actionName: actionName,
            beforeDocument: beforeDocument,
            afterDocument: document,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        reloadDataKeepingFocus()
        publishDocumentChange()
        return afterSelection
    }

    func applyUndoResult(_ result: BlockInputUndoResult, storeSyncAction: StoreSyncAction = .replaceDocument) {
        syncDocumentStore(storeSyncAction)
        let restoredSelection = result.selection.flatMap { selection -> BlockInputSelection? in
            containsValidSelection(selection) ? selection : nil
        }
        applySelection(restoredSelection, notify: true)
        reloadDataKeepingFocus()
        publishDocumentChange()
    }
}
