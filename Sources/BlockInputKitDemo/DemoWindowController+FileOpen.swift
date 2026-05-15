import AppKit
import BlockInputKit
import UniformTypeIdentifiers

extension DemoWindowController {
    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown")
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK,
                  let url = panel.url else {
                return
            }
            Task { @MainActor in
                self?.openMarkdownFile(at: url)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    func openMarkdownFile(at url: URL) {
        let fileURL = standardizedFileURL(for: url)
        let itemID = DemoSidebarItemID.file(fileURL)
        if !sidebarItems.contains(where: { $0.id == itemID }) {
            sidebarItems.append(DemoSidebarItem(id: itemID))
            sidebarTableView.insertRows(at: IndexSet(integer: sidebarItems.count - 1), withAnimation: .effectFade)
        }
        if let session = sessions[itemID] {
            if case .failed = session.loadingState {
                startFileLoad(for: session, url: fileURL)
            }
        } else {
            let session = DemoNoteSession(fileURL: fileURL)
            sessions[itemID] = session
            startFileLoad(for: session, url: fileURL)
        }
        selectSidebarItem(itemID)
    }

    private func startFileLoad(for session: DemoNoteSession, url: URL) {
        let itemID = session.id
        session.pendingLoadTask?.cancel()
        session.loadingState = .loading
        session.pendingLoadTask = Task { [weak self, itemID, url] in
            do {
                let document = try await BlockInputDocument.readingMarkdown(from: url)
                let rawMarkdown = await document.markdownSnapshot()
                guard !Task.isCancelled else {
                    return
                }
                self?.installLoadedFileDocument(document, rawMarkdown: rawMarkdown, itemID: itemID)
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self?.installFileLoadError(error, itemID: itemID)
            }
        }
    }

    private func installLoadedFileDocument(_ document: BlockInputDocument, rawMarkdown: String, itemID: DemoSidebarItemID) {
        guard let session = sessions[itemID] else {
            return
        }
        session.pendingLoadTask = nil
        session.loadingState = .idle
        session.store.replaceDocument(document)
        session.undoController = BlockInputUndoController()
        session.rawMarkdown = rawMarkdown
        session.rawViewNeedsReload = true
        session.renderedViewNeedsReload = true
        if currentItemID == itemID {
            applySelectedNote(preloadBothViews: false)
        }
    }

    private func installFileLoadError(_ error: Error, itemID: DemoSidebarItemID) {
        guard let session = sessions[itemID] else {
            return
        }
        session.pendingLoadTask = nil
        session.loadingState = .failed("Could not load \(itemID.title): \(error.localizedDescription)")
        if currentItemID == itemID {
            applySelectedNote(preloadBothViews: false)
        }
    }

    func selectSidebarItem(_ itemID: DemoSidebarItemID) {
        guard let row = sidebarItems.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        sidebarTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        sidebarTableView.scrollRowToVisible(row)
        currentItemID = itemID
        applySelectedNote(preloadBothViews: false)
    }

    private func standardizedFileURL(for url: URL) -> URL {
        URL(fileURLWithPath: url.path).standardizedFileURL
    }
}
