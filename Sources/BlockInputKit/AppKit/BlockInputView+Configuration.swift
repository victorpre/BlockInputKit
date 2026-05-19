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
        let wasDocumentCacheSynchronized = isDocumentCacheSynchronized
        let documentStoreChanged = previousDocumentStore.map {
            ($0 as AnyObject) !== (configuredDocumentStore as AnyObject)
        } ?? false
        if documentStoreChanged {
            detachDocumentStoreObservation()
        }
        documentStore = configuredDocumentStore
        let reusesLargeDocumentCache = previousDocumentStore != nil
            && !documentStoreChanged
            && configuredDocumentStore.loadedBlockCount > largeDocumentCacheMutationLimit
        let configuredDocument = reusesLargeDocumentCache ? previousDocument : configuration.document.detachedStorage()
        document = configuredDocument
        isDocumentCacheSynchronized = reusesLargeDocumentCache ? wasDocumentCacheSynchronized : true
        allowsBlockReordering = configuration.allowsBlockReordering
        editorHorizontalInset = configuration.editorHorizontalInset
        editorVerticalInset = configuration.editorVerticalInset
        dropIndicatorColor = configuration.dropIndicatorColor
        style = configuration.style
        configureUndoController(
            previousDocumentStore: previousDocumentStore,
            previousDocument: previousDocument,
            documentStoreChanged: documentStoreChanged,
            configuration: configuration,
            configuredDocument: configuredDocument
        )
        completionProvider = configuration.completionProvider
        onDocumentMutation = configuration.onDocumentMutation
        onDocumentChange = configuration.onDocumentChange
        documentChangeSnapshotDelay = configuration.documentChangeSnapshotDelay
        onSelectionChange = configuration.onSelectionChange
        onFocusChange = configuration.onFocusChange
        if documentStoreChanged || configuration.onDocumentChange == nil {
            cancelPendingDocumentSnapshot()
        }
        updateDropIndicatorColor()
        hideDropIndicator()
        clearStaleFocusState()
        if restoresFocus {
            reloadDataKeepingFocus()
        } else {
            reloadDataWithoutRestoringFocus()
        }
        attachDocumentStoreObservationIfNeeded()
    }

    func configureUndoController(
        previousDocumentStore: (any BlockInputDocumentStore)?,
        previousDocument: BlockInputDocument,
        documentStoreChanged: Bool,
        configuration: BlockInputConfiguration,
        configuredDocument: BlockInputDocument
    ) {
        if let configuredUndoController = configuration.undoController {
            undoController = configuredUndoController
        } else {
            if let previousDocumentStore,
               documentStoreChanged,
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

extension BlockInputView {
    func detachDocumentStoreObservation() {
        pendingProgressivePreloadWorkItem?.cancel()
        pendingProgressivePreloadWorkItem = nil
        progressiveLoadTask?.cancel()
        progressiveLoadTask = nil
        documentStoreObservation?.cancel()
        documentStoreObservation = nil
        progressiveStoreError = nil
    }

    func attachDocumentStoreObservationIfNeeded() {
        guard documentStoreObservation == nil,
              let documentStore else {
            return
        }
        let observedStore = documentStore as AnyObject
        documentStoreObservation = documentStore.observeChanges { [weak self, weak observedStore] change in
            guard let self,
                  let observedStore,
                  self.isCurrentDocumentStore(observedStore) else {
                return
            }
            self.handleDocumentStoreChange(change)
        }
    }
}
