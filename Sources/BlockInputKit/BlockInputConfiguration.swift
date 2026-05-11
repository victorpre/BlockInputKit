import AppKit

/// Runtime options and host integration points for a block input editor.
public struct BlockInputConfiguration {
    /// Source of truth for the document shown by the editor.
    public var documentStore: any BlockInputDocumentStore
    /// Whether the leading drag handle can reorder blocks.
    public var allowsBlockReordering: Bool
    /// Color used for the drag insertion indicator line.
    public var dropIndicatorColor: NSColor
    /// Undo coordinator used by text and structural editor operations.
    public var undoController: BlockInputUndoController?
    /// Host completion source for mentions and slash commands.
    public var completionProvider: (any BlockInputCompletionProvider)?
    /// Called after the editor mutates the document.
    public var onDocumentChange: ((BlockInputDocument) -> Void)?
    /// Called after the editor updates cursor, text, or block selection.
    public var onSelectionChange: ((BlockInputSelection?) -> Void)?
    /// Called when the editor gains or loses AppKit focus.
    public var onFocusChange: ((Bool) -> Void)?

    /// Current document snapshot from `documentStore`.
    public var document: BlockInputDocument {
        documentStore.document
    }

    /// Creates configuration. When `documentStore` is supplied, it is the source of truth and `document` is ignored.
    public init(
        document: BlockInputDocument = BlockInputDocument(),
        documentStore: (any BlockInputDocumentStore)? = nil,
        allowsBlockReordering: Bool = true,
        dropIndicatorColor: NSColor = .controlAccentColor,
        undoController: BlockInputUndoController? = nil,
        completionProvider: (any BlockInputCompletionProvider)? = nil,
        onDocumentChange: ((BlockInputDocument) -> Void)? = nil,
        onSelectionChange: ((BlockInputSelection?) -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.documentStore = documentStore ?? BlockInputMemoryDocumentStore(document: document)
        self.allowsBlockReordering = allowsBlockReordering
        self.dropIndicatorColor = dropIndicatorColor
        self.undoController = undoController
        self.completionProvider = completionProvider
        self.onDocumentChange = onDocumentChange
        self.onSelectionChange = onSelectionChange
        self.onFocusChange = onFocusChange
    }
}
