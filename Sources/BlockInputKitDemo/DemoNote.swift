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
    let note: DemoNote
    var store: BlockInputMemoryDocumentStore
    var undoController = BlockInputUndoController()
    var rawMarkdown: String
    var rawViewNeedsReload = false
    var renderedViewNeedsReload = false
    var documentRevision = 0
    var rawParseGeneration = 0
    var pendingRawParseTask: Task<Void, Never>?
    var pendingMarkdownTask: Task<Void, Never>?

    init(note: DemoNote, document: BlockInputDocument) {
        self.note = note
        store = BlockInputMemoryDocumentStore(document: document)
        rawMarkdown = document.markdown
    }

    init(note: DemoNote, warmState: DemoNoteWarmState) {
        self.note = note
        store = warmState.store
        rawMarkdown = warmState.rawMarkdown
    }

    deinit {
        cancelPendingWork()
    }

    func cancelPendingWork() {
        pendingRawParseTask?.cancel()
        pendingRawParseTask = nil
        pendingMarkdownTask?.cancel()
        pendingMarkdownTask = nil
    }
}
