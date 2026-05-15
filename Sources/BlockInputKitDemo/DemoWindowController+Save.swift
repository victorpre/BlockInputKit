import AppKit
import BlockInputKit
import UniformTypeIdentifiers

extension DemoWindowController {
    @objc func saveDocument(_ sender: Any?) {
        guard let session = currentSession,
              case .idle = session.loadingState else {
            return
        }
        guard session.fileURL != nil else {
            saveDocumentAs(sender)
            return
        }
        requestSave(for: session, rawEdit: false, immediate: true)
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard let session = currentSession,
              case .idle = session.loadingState else {
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown")
        ].compactMap { $0 }
        panel.nameFieldStringValue = defaultSaveName(for: session)
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK,
                  let url = panel.url else {
                return
            }
            Task { @MainActor in
                self?.saveCurrentSessionAs(url)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    func markSessionDirty(_ session: DemoNoteSession, rawEdit: Bool) {
        guard session.loadingState == .idle else {
            return
        }
        session.isDirty = true
        session.saveGeneration += 1
        session.saveQueuedRawWrite = rawEdit
        session.saveState = .idle
        if currentItemID == session.id {
            updateSaveStatus(for: session)
        }
        guard session.fileURL != nil else {
            return
        }
        scheduleAutosave(for: session, rawEdit: rawEdit)
    }

    func updateSaveStatus(for session: DemoNoteSession) {
        switch session.saveState {
        case .idle:
            if session.fileURL == nil {
                saveStatusLabel.stringValue = ""
            } else if session.isDirty {
                saveStatusLabel.stringValue = "Edited"
            } else {
                saveStatusLabel.stringValue = "Saved"
            }
        case .saving:
            saveStatusLabel.stringValue = "Saving..."
        case .failed(let message):
            saveStatusLabel.stringValue = message
        }
    }

    private func scheduleAutosave(for session: DemoNoteSession, rawEdit: Bool) {
        session.pendingAutosaveTask?.cancel()
        let itemID = session.id
        let generation = session.saveGeneration
        session.pendingAutosaveTask = Task { [weak self, itemID, generation, rawEdit] in
            do {
                try await Task.sleep(nanoseconds: 900_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            self?.startAutosave(itemID: itemID, generation: generation, rawEdit: rawEdit)
        }
    }

    private func startAutosave(itemID: DemoSidebarItemID, generation: Int, rawEdit: Bool) {
        guard let session = sessions[itemID],
              session.saveGeneration == generation,
              session.isDirty else {
            return
        }
        requestSave(for: session, rawEdit: rawEdit, immediate: false)
    }

    private func requestSave(for session: DemoNoteSession, rawEdit: Bool, immediate: Bool) {
        guard let url = session.fileURL else {
            return
        }
        let shouldWriteRaw = session.saveQueuedRawWrite || rawEdit
        if immediate {
            session.pendingAutosaveTask?.cancel()
            session.pendingAutosaveTask = nil
        }
        guard session.activeSaveTask == nil else {
            session.saveQueuedAfterActive = true
            session.saveQueuedRawWrite = shouldWriteRaw
            return
        }
        startSave(for: session, to: url, generation: session.saveGeneration, rawEdit: shouldWriteRaw)
    }

    private func startSave(for session: DemoNoteSession, to url: URL, generation: Int, rawEdit: Bool) {
        let itemID = session.id
        let rawMarkdown = session.rawMarkdown
        let document = session.store.backgroundDocumentSnapshot()
        session.saveState = .saving
        session.saveQueuedAfterActive = false
        session.saveQueuedRawWrite = false
        if currentItemID == itemID {
            updateSaveStatus(for: session)
        }
        session.activeSaveTask = Task { [weak self, itemID, url, generation, rawEdit, rawMarkdown, document] in
            do {
                if rawEdit {
                    try await Self.writeRawMarkdown(rawMarkdown, to: url)
                } else {
                    try await document.writeMarkdown(to: url)
                }
                guard !Task.isCancelled else {
                    return
                }
                self?.completeSave(itemID: itemID, generation: generation, rawEdit: rawEdit, result: .success(()))
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self?.completeSave(itemID: itemID, generation: generation, rawEdit: rawEdit, result: .failure(error))
            }
        }
    }

    private func completeSave(itemID: DemoSidebarItemID, generation: Int, rawEdit: Bool, result: Result<Void, Error>) {
        guard let session = sessions[itemID] else {
            return
        }
        session.activeSaveTask = nil
        switch result {
        case .success:
            if session.saveGeneration == generation {
                session.isDirty = false
                session.saveState = .idle
            } else {
                session.isDirty = true
                session.saveState = .idle
                requestSave(for: session, rawEdit: false, immediate: true)
                return
            }
        case .failure(let error):
            session.isDirty = true
            guard session.saveGeneration == generation else {
                session.saveState = .idle
                requestSave(for: session, rawEdit: false, immediate: true)
                return
            }
            session.saveQueuedRawWrite = rawEdit
            session.saveState = .failed("Save failed: \(error.localizedDescription)")
        }
        if session.saveQueuedAfterActive,
           session.isDirty {
            requestSave(for: session, rawEdit: false, immediate: true)
            return
        }
        if currentItemID == itemID {
            updateSaveStatus(for: session)
        }
    }

    private func saveCurrentSessionAs(_ url: URL) {
        guard let session = currentSession else {
            return
        }
        let hadPendingRawParse = session.pendingRawParseTask != nil
        let fileURL = standardizedSaveURL(for: url)
        let targetSession: DemoNoteSession
        if session.fileURL == nil {
            targetSession = copySession(session, to: fileURL)
            installFileBackedSession(targetSession)
            selectSidebarItem(targetSession.id)
        } else {
            targetSession = session
            retargetFileSession(session, to: fileURL)
        }
        targetSession.isDirty = true
        targetSession.saveGeneration += 1
        if hadPendingRawParse {
            scheduleRawParse(for: targetSession, delay: 0)
        }
        requestSave(for: targetSession, rawEdit: false, immediate: true)
        updateSaveStatus(for: targetSession)
    }

    private func installFileBackedSession(_ session: DemoNoteSession) {
        sessions[session.id] = session
        if let row = sidebarItems.firstIndex(where: { $0.id == session.id }) {
            sidebarTableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
            return
        }
        sidebarItems.append(DemoSidebarItem(id: session.id))
        sidebarTableView.insertRows(at: IndexSet(integer: sidebarItems.count - 1), withAnimation: .effectFade)
    }

    private func retargetFileSession(_ session: DemoNoteSession, to url: URL) {
        let oldID = session.id
        let newID = DemoSidebarItemID.file(url)
        guard oldID != newID else {
            return
        }
        session.pendingAutosaveTask?.cancel()
        session.pendingAutosaveTask = nil
        session.activeSaveTask?.cancel()
        session.activeSaveTask = nil
        session.saveQueuedAfterActive = false
        sessions[oldID] = nil
        if let existing = sessions[newID],
           existing !== session {
            existing.cancelPendingWork()
        }
        session.id = newID
        session.title = newID.title
        sessions[newID] = session
        if rawTextItemID == oldID {
            rawTextItemID = newID
        }
        currentItemID = newID
        let oldRow = sidebarItems.firstIndex(where: { $0.id == oldID })
        let existingRow = sidebarItems.firstIndex(where: { $0.id == newID })
        if let existingRow,
           existingRow != oldRow {
            if let oldRow {
                sidebarItems.remove(at: oldRow)
                sidebarTableView.removeRows(at: IndexSet(integer: oldRow), withAnimation: .effectFade)
            }
            sidebarTableView.reloadData()
        } else if let oldRow {
            sidebarItems[oldRow].id = newID
            sidebarTableView.reloadData(forRowIndexes: IndexSet(integer: oldRow), columnIndexes: IndexSet(integer: 0))
        } else {
            installFileBackedSession(session)
        }
        configureEditor(for: session)
        selectSidebarItem(newID)
    }

    private func copySession(_ session: DemoNoteSession, to url: URL) -> DemoNoteSession {
        let document = session.store.backgroundDocumentSnapshot()
        let copy = DemoNoteSession(fileURL: url)
        copy.loadingState = .idle
        copy.store = BlockInputMemoryDocumentStore(document: document)
        copy.undoController = BlockInputUndoController()
        copy.rawMarkdown = session.rawMarkdown
        copy.documentRevision = session.documentRevision
        copy.rawParseGeneration = session.rawParseGeneration
        copy.saveQueuedRawWrite = session.saveQueuedRawWrite
        copy.rawViewNeedsReload = true
        copy.renderedViewNeedsReload = true
        return copy
    }

    private func defaultSaveName(for session: DemoNoteSession) -> String {
        if let fileURL = session.fileURL {
            return fileURL.lastPathComponent
        }
        return "\(session.title).md"
    }

    private func standardizedSaveURL(for url: URL) -> URL {
        URL(fileURLWithPath: url.path).standardizedFileURL
    }

    private static func writeRawMarkdown(_ markdown: String, to url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        }.value
    }
}
