import AppKit

extension BlockInputView {
    var shouldDeferDocumentChangeSnapshot: Bool {
        documentStore != nil && blockCount > largeDocumentCacheMutationLimit
    }

    func publishDocumentMutation(_ change: BlockInputDocumentChange) {
        onDocumentMutation?(change)
    }

    func cancelPendingDocumentSnapshot() {
        documentSnapshotGeneration += 1
        pendingDocumentSnapshotWorkItem?.cancel()
        pendingDocumentSnapshotWorkItem = nil
    }

    func scheduleDeferredDocumentSnapshot() {
        documentSnapshotGeneration += 1
        let generation = documentSnapshotGeneration
        pendingDocumentSnapshotWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.startDeferredDocumentSnapshot(generation: generation)
            }
        }
        pendingDocumentSnapshotWorkItem = workItem
        let delay = max(0, documentChangeSnapshotDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func startDeferredDocumentSnapshot(generation: Int) {
        guard generation == documentSnapshotGeneration,
              onDocumentChange != nil else {
            return
        }
        if let backgroundStore = documentStore as? any BlockInputBackgroundSnapshotStore {
            DispatchQueue.global(qos: .utility).async { [backgroundStore] in
                let snapshot = backgroundStore.backgroundDocumentSnapshot()
                DispatchQueue.main.async { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self,
                              generation == self.documentSnapshotGeneration else {
                            return
                        }
                        self.onDocumentChange?(snapshot)
                    }
                }
            }
            return
        }
        onDocumentChange?((documentStore?.document ?? document).detachedStorage())
    }
}
