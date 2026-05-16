import BlockInputKit
import Combine
import Foundation

@MainActor
final class DemoModel: ObservableObject {
    @Published var sidebarItems = DemoNote.all.map { DemoSidebarItem(id: .builtIn($0.id)) }
    @Published var selectedItemID: DemoSidebarItemID? = .builtIn(.mixed)
    @Published var editorMode: DemoEditorMode = .rendered
    @Published var allowsReordering = true

    var sessions: [DemoSidebarItemID: DemoNoteSession] = [:]
    var warmTasks: [DemoNoteID: Task<Void, Never>] = [:]

    var currentItemID: DemoSidebarItemID {
        selectedItemID ?? .builtIn(.mixed)
    }

    var currentSession: DemoNoteSession? {
        sessions[currentItemID]
    }

    init() {
        sessions[.builtIn(.mixed)] = DemoNoteSession(note: DemoNote(id: .mixed), document: DemoNoteID.mixed.makeDocument())
        warmRemainingNotesAfterLaunch()
    }

    func cancelPendingWork() {
        warmTasks.values.forEach { $0.cancel() }
        warmTasks.removeAll()
        sessions.values.forEach { $0.cancelPendingWork() }
    }

    func sidebarItems(in section: DemoSidebarSection) -> [DemoSidebarItem] {
        sidebarItems.filter { section.contains($0) }
    }

    func select(_ itemID: DemoSidebarItemID) {
        selectedItemID = itemID
        if case .builtIn(let noteID) = itemID,
           sessions[itemID] == nil {
            startWarmTask(for: noteID)
        }
        if let session = sessions[itemID] {
            prepareVisibleMode(for: session)
        }
    }

    func editorConfiguration(for session: DemoNoteSession) -> BlockInputConfiguration {
        BlockInputConfiguration(
            documentStore: session.store,
            allowsBlockReordering: allowsReordering,
            undoController: session.undoController,
            onDocumentMutation: { [weak self, itemID = session.id] change in
                Task { @MainActor in
                    self?.handleRenderedMutation(change, itemID: itemID)
                }
            },
            onDocumentChange: { [weak self, itemID = session.id] document in
                Task { @MainActor in
                    self?.handleRenderedDocumentChange(document, itemID: itemID)
                }
            }
        )
    }

    func setEditorMode(_ mode: DemoEditorMode) {
        guard mode != editorMode else {
            return
        }
        editorMode = mode
        guard let session = currentSession,
              session.loadingState == .idle else {
            return
        }
        prepareVisibleMode(for: session)
    }

    func prepareVisibleMode(for session: DemoNoteSession) {
        guard session.loadingState == .idle else {
            return
        }
        switch editorMode {
        case .raw:
            prepareRawView(for: session)
        case .rendered:
            prepareRenderedView(for: session)
        }
    }

    func setAllowsReordering(_ allowsReordering: Bool) {
        self.allowsReordering = allowsReordering
    }

    func standardizedFileURL(for url: URL) -> URL {
        URL(fileURLWithPath: url.path).standardizedFileURL
    }
}
