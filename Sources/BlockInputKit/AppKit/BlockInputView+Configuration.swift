import Foundation

extension BlockInputView {
    /// Applies configuration and reloads the editor from its document store.
    public func configure(_ configuration: BlockInputConfiguration) {
        configure(configuration, restoresFocus: true)
    }

    func configure(_ configuration: BlockInputConfiguration, restoresFocus: Bool) {
        let configuredDocumentStore = configuration.documentStore
        let previousDocumentStore = documentStore
        let previousDocument = document
        documentStore = configuredDocumentStore
        let configuredDocument = configuration.document.detachedStorage()
        document = configuredDocument
        isDocumentCacheSynchronized = true
        allowsBlockReordering = configuration.allowsBlockReordering
        editorHorizontalInset = configuration.editorHorizontalInset
        dropIndicatorColor = configuration.dropIndicatorColor
        if let configuredUndoController = configuration.undoController {
            undoController = configuredUndoController
        } else {
            if let previousDocumentStore,
               (previousDocumentStore as AnyObject) !== (configuredDocumentStore as AnyObject),
               shouldResetFallbackUndoController(
                   previousDocumentStore: previousDocumentStore,
                   previousDocument: previousDocument,
                   configuration: configuration,
                   configuredDocument: configuredDocument
               ) {
                fallbackUndoController = BlockInputUndoController()
            }
            undoController = fallbackUndoController
        }
        completionProvider = configuration.completionProvider
        onDocumentMutation = configuration.onDocumentMutation
        onDocumentChange = configuration.onDocumentChange
        documentChangeSnapshotDelay = configuration.documentChangeSnapshotDelay
        onSelectionChange = configuration.onSelectionChange
        onFocusChange = configuration.onFocusChange
        cancelPendingDocumentSnapshot()
        updateDropIndicatorColor()
        hideDropIndicator()
        clearStaleFocusState()
        if restoresFocus {
            reloadDataKeepingFocus()
        } else {
            reloadDataWithoutRestoringFocus()
        }
    }

    func shouldResetFallbackUndoController(
        previousDocumentStore: any BlockInputDocumentStore,
        previousDocument: BlockInputDocument,
        configuration: BlockInputConfiguration,
        configuredDocument: BlockInputDocument
    ) -> Bool {
        if configuration.usesDefaultDocumentStore,
           previousDocumentStore is BlockInputMemoryDocumentStore,
           previousDocument == configuredDocument {
            return false
        }
        return true
    }
}
