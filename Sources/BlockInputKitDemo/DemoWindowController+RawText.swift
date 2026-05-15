import AppKit
import BlockInputKit

extension DemoWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === rawTextView else {
            return
        }
        handleRawTextDidChange()
    }

    func handleRawTextDidChange() {
        guard !isApplyingRawText,
              let session = currentSession,
              rawTextItemID == session.id else {
            return
        }
        session.rawMarkdown = rawTextView.string
        session.rawViewNeedsReload = false
        session.renderedViewNeedsReload = true
        session.documentRevision += 1
        markSessionDirty(session, rawEdit: true)
        session.pendingMarkdownTask?.cancel()
        session.pendingMarkdownTask = nil
        scheduleRawParse(for: session, delay: 0.35)
    }

    func scheduleRawParse(for session: DemoNoteSession, delay: TimeInterval) {
        let markdown = session.rawMarkdown
        let itemID = session.id
        session.rawParseGeneration += 1
        let generation = session.rawParseGeneration
        session.pendingRawParseTask?.cancel()
        session.pendingRawParseTask = Task { [weak self, markdown, itemID, generation] in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            if nanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else {
                return
            }
            let document = await Task.detached(priority: .userInitiated) {
                BlockInputDocument(markdown: markdown)
            }.value
            self?.applyRawDocument(document, itemID: itemID, generation: generation)
        }
    }

    private func applyRawDocument(_ document: BlockInputDocument, itemID: DemoSidebarItemID, generation: Int) {
        guard let session = sessions[itemID],
              session.rawParseGeneration == generation else {
            return
        }
        session.pendingRawParseTask = nil
        session.store.replaceDocument(document)
        session.undoController = BlockInputUndoController()
        session.renderedViewNeedsReload = true
        if currentItemID == itemID {
            if editorMode == .rendered {
                configureEditor(for: session)
            }
        }
    }
}
