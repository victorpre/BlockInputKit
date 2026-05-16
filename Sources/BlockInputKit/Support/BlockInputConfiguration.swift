import AppKit

/// Runtime options and host integration points for a block input editor.
public struct BlockInputConfiguration {
    /// Default visual horizontal inset for block content.
    public static let defaultEditorHorizontalInset: CGFloat = 20

    /// Source of truth for the document shown by the editor.
    public var documentStore: any BlockInputDocumentStore {
        didSet {
            usesDefaultDocumentStore = false
        }
    }
    /// Whether the leading drag handle can reorder blocks.
    public var allowsBlockReordering: Bool
    /// Visual horizontal inset used for block content.
    ///
    /// When reordering is enabled, the drag handle is centered inside this inset when possible
    /// and the gutter grows only when the inset is too small for the handle lane.
    public var editorHorizontalInset: CGFloat
    /// Color used for editor accent affordances, including drag insertion and selected horizontal rules.
    public var dropIndicatorColor: NSColor
    /// Undo coordinator used by text and structural editor operations.
    ///
    /// When nil, `BlockInputView` uses a view-owned undo controller.
    public var undoController: BlockInputUndoController?
    /// Host completion source for mentions and slash commands.
    public var completionProvider: (any BlockInputCompletionProvider)?
    /// Called immediately with the granular store mutation applied by the editor.
    public var onDocumentMutation: ((BlockInputDocumentChange) -> Void)?
    /// Called with a full document snapshot after editor mutations.
    ///
    /// Large store-backed editors defer and coalesce this callback; use
    /// `onDocumentMutation` for synchronous per-edit updates.
    public var onDocumentChange: ((BlockInputDocument) -> Void)?
    /// Delay used to coalesce full-document snapshots for large store-backed documents.
    public var documentChangeSnapshotDelay: TimeInterval
    /// Called after the editor updates cursor, text, or block selection.
    public var onSelectionChange: ((BlockInputSelection?) -> Void)?
    /// Called when the editor gains or loses AppKit focus.
    public var onFocusChange: ((Bool) -> Void)?
    var usesDefaultDocumentStore: Bool

    /// Current document snapshot from `documentStore`.
    public var document: BlockInputDocument {
        documentStore.document
    }

    /// Creates configuration. When `documentStore` is supplied, it is the source of truth and `document` is ignored.
    public init(
        document: BlockInputDocument = BlockInputDocument(),
        documentStore: (any BlockInputDocumentStore)? = nil,
        allowsBlockReordering: Bool = true,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset,
        dropIndicatorColor: NSColor = .controlAccentColor,
        undoController: BlockInputUndoController? = nil,
        completionProvider: (any BlockInputCompletionProvider)? = nil,
        onDocumentMutation: ((BlockInputDocumentChange) -> Void)? = nil,
        onDocumentChange: ((BlockInputDocument) -> Void)? = nil,
        documentChangeSnapshotDelay: TimeInterval = 0.25,
        onSelectionChange: ((BlockInputSelection?) -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        usesDefaultDocumentStore = documentStore == nil
        self.documentStore = documentStore ?? BlockInputMemoryDocumentStore(document: document)
        self.allowsBlockReordering = allowsBlockReordering
        self.editorHorizontalInset = editorHorizontalInset
        self.dropIndicatorColor = dropIndicatorColor
        self.undoController = undoController
        self.completionProvider = completionProvider
        self.onDocumentMutation = onDocumentMutation
        self.onDocumentChange = onDocumentChange
        self.documentChangeSnapshotDelay = documentChangeSnapshotDelay
        self.onSelectionChange = onSelectionChange
        self.onFocusChange = onFocusChange
    }
}
