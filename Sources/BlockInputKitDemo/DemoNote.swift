import BlockInputKit
import Foundation

enum DemoNoteID: String, CaseIterable, Sendable {
    case mixed
    case large

    var title: String {
        switch self {
        case .mixed:
            "Mixed"
        case .large:
            "100K"
        }
    }

    func makeDocument() -> BlockInputDocument {
        switch self {
        case .mixed:
            DemoData.mixedDocument()
        case .large:
            DemoData.largeDocument()
        }
    }
}

struct DemoNote: Sendable {
    var id: DemoNoteID

    var title: String {
        id.title
    }

    static let all = DemoNoteID.allCases.map(DemoNote.init)
}

enum DemoSidebarItemID: Hashable, Sendable {
    case builtIn(DemoNoteID)
    case file(URL)

    var title: String {
        switch self {
        case .builtIn(let noteID):
            noteID.title
        case .file(let url):
            url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        }
    }
}

struct DemoSidebarItem: Sendable {
    var id: DemoSidebarItemID

    var title: String {
        id.title
    }
}

enum DemoNoteLoadingState {
    case idle
    case loading
    case failed(String)
}

struct DemoNoteWarmState: Sendable {
    var id: DemoNoteID
    var store: BlockInputMemoryDocumentStore
    var rawMarkdown: String

    static func make(for id: DemoNoteID) -> DemoNoteWarmState {
        let document = id.makeDocument()
        return DemoNoteWarmState(
            id: id,
            store: BlockInputMemoryDocumentStore(document: document),
            rawMarkdown: document.markdown
        )
    }
}

final class DemoNoteSession {
    let id: DemoSidebarItemID
    let title: String
    var store: BlockInputMemoryDocumentStore
    var undoController = BlockInputUndoController()
    var rawMarkdown: String
    var loadingState: DemoNoteLoadingState = .idle
    var rawViewNeedsReload = false
    var renderedViewNeedsReload = false
    var documentRevision = 0
    var rawParseGeneration = 0
    var pendingRawParseTask: Task<Void, Never>?
    var pendingMarkdownTask: Task<Void, Never>?
    var pendingLoadTask: Task<Void, Never>?

    init(note: DemoNote, document: BlockInputDocument) {
        id = .builtIn(note.id)
        title = note.title
        store = BlockInputMemoryDocumentStore(document: document)
        rawMarkdown = document.markdown
    }

    init(note: DemoNote, warmState: DemoNoteWarmState) {
        id = .builtIn(note.id)
        title = note.title
        store = warmState.store
        rawMarkdown = warmState.rawMarkdown
    }

    init(fileURL: URL) {
        id = .file(fileURL)
        title = fileURL.lastPathComponent.isEmpty ? fileURL.path : fileURL.lastPathComponent
        store = BlockInputMemoryDocumentStore(document: BlockInputDocument())
        rawMarkdown = ""
        loadingState = .loading
    }

    deinit {
        cancelPendingWork()
    }

    func cancelPendingWork() {
        pendingRawParseTask?.cancel()
        pendingRawParseTask = nil
        pendingMarkdownTask?.cancel()
        pendingMarkdownTask = nil
        pendingLoadTask?.cancel()
        pendingLoadTask = nil
    }
}
