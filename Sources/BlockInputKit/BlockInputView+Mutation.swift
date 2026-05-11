import Foundation

extension BlockInputView {
    func publishDocumentChange(syncStore: Bool = true) {
        if syncStore {
            syncDocumentStore()
        }
        onDocumentChange?(document)
    }

    func syncDocumentStore() {
        documentStore?.replaceDocument(document)
    }

    func refreshDocumentFromStore() {
        if let documentStore {
            document = documentStore.document
        }
    }

    func performStructuralEdit(
        named actionName: String,
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
        syncDocumentStore()
        applySelection(afterSelection, notify: true)
        undoController?.registerStructuralEdit(
            actionName: actionName,
            beforeDocument: beforeDocument,
            afterDocument: document,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        reloadDataKeepingFocus()
        publishDocumentChange(syncStore: false)
        return afterSelection
    }

    func applyUndoResult(_ result: BlockInputUndoResult) {
        syncDocumentStore()
        let restoredSelection = result.selection.flatMap { selection -> BlockInputSelection? in
            containsValidSelection(selection) ? selection : nil
        }
        applySelection(restoredSelection, notify: true)
        reloadDataKeepingFocus()
        publishDocumentChange(syncStore: false)
    }
}
