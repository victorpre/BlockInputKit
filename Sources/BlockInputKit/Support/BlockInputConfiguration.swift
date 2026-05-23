import AppKit

/// Host-provided popup placement inside an overlay surface.
///
/// Return this from `BlockInputCompletionPopupConfiguration.overlayProvider` to choose both the destination parent
/// view for the popup and the frame it should occupy inside that parent.
public struct BlockInputCompletionPopupOverlay {
    /// Parent view that should own the popup.
    public var container: NSView
    /// Popup frame in `container` coordinates.
    public var frame: NSRect

    /// Creates overlay placement with an owning container and popup frame.
    public init(container: NSView, frame: NSRect) {
        self.container = container
        self.frame = frame
    }
}

/// Layout values supplied when a host customizes overlay popup presentation.
public struct BlockInputCompletionPopupOverlayContext {
    /// Editor requesting the popup.
    public var editorView: BlockInputView
    /// Default parent view chosen by the editor when the host does not override popup placement.
    public var defaultContainer: NSView
    /// Default popup frame in `defaultContainer` coordinates.
    public var defaultFrame: NSRect
    /// Measured popup size before host adjustment.
    public var popupSize: NSSize

    /// Creates host overlay-placement context for a completion popup request.
    public init(
        editorView: BlockInputView,
        defaultContainer: NSView,
        defaultFrame: NSRect,
        popupSize: NSSize
    ) {
        self.editorView = editorView
        self.defaultContainer = defaultContainer
        self.defaultFrame = defaultFrame
        self.popupSize = popupSize
    }

    /// Converts the editor bounds into a candidate popup container.
    @MainActor
    public func editorFrame(in container: NSView) -> NSRect {
        container.convert(editorView.bounds, from: editorView)
    }
}

/// Built-in completion popup behavior and host integration points.
public struct BlockInputCompletionPopupConfiguration {
    /// Where the editor-owned completion popup should be shown.
    public var placement: BlockInputCompletionPopupPlacement
    /// Optional host override for overlay popup presentation.
    ///
    /// Return both the parent view and popup frame in that parent's coordinate space. Keeping the container and frame
    /// together lets hosts rehost the popup into another surface while aligning it to that surface. When nil, the
    /// editor falls back to the window content view, then its superview, then itself, and anchors the popup above the
    /// editor.
    public var overlayProvider: (@MainActor (BlockInputCompletionPopupOverlayContext) -> BlockInputCompletionPopupOverlay?)?

    /// Creates built-in completion popup behavior.
    public init(
        placement: BlockInputCompletionPopupPlacement = .caret,
        overlayProvider: (@MainActor (BlockInputCompletionPopupOverlayContext) -> BlockInputCompletionPopupOverlay?)? = nil
    ) {
        self.placement = placement
        self.overlayProvider = overlayProvider
    }
}

/// Slash-command chip click gesture routed to the host.
public enum BlockInputSlashCommandChipClickKind: Equatable {
    /// A primary mouse click without the Command modifier.
    case plainClick
    /// A primary mouse click with the Command modifier.
    case commandClick
}

/// Host decision for a slash-command chip click.
public enum BlockInputSlashCommandChipClickAction: Equatable {
    /// Open the editor's existing link modal for this chip.
    case showLinkModal
    /// Open the chip URI through the editor URL opener.
    case openURL
    /// The host handled the click and the editor should not perform fallback behavior.
    case hostHandled
}

/// Context sent when a slash-command chip is clicked.
public struct BlockInputSlashCommandChipClickContext {
    /// Visible chip label, including its leading `/`.
    public var label: String
    /// Host-owned slash-command URI.
    public var uri: URL
    /// Block that contains the clicked chip.
    public var blockID: BlockInputBlockID
    /// Full Markdown source range for the clicked chip.
    public var sourceRange: NSRange
    /// Editor view routing the click.
    public var editorView: BlockInputView
    /// Original AppKit mouse event.
    public var event: NSEvent
    /// Normalized click kind.
    public var clickKind: BlockInputSlashCommandChipClickKind

    /// Creates host click context for a slash-command chip.
    public init(
        label: String,
        uri: URL,
        blockID: BlockInputBlockID,
        sourceRange: NSRange,
        editorView: BlockInputView,
        event: NSEvent,
        clickKind: BlockInputSlashCommandChipClickKind
    ) {
        self.label = label
        self.uri = uri
        self.blockID = blockID
        self.sourceRange = sourceRange
        self.editorView = editorView
        self.event = event
        self.clickKind = clickKind
    }
}

/// Runtime options and host integration points for a block input editor.
public struct BlockInputConfiguration {
    /// Default visual horizontal inset for block content.
    public static let defaultEditorHorizontalInset: CGFloat = 20
    /// Default visual vertical inset for the editor content.
    public static let defaultEditorVerticalInset: CGFloat = 8

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
    /// Visual vertical inset used above and below editor content.
    public var editorVerticalInset: CGFloat
    /// Color used for editor accent affordances, including drag insertion and selected horizontal rules.
    public var dropIndicatorColor: NSColor
    /// Visual styling for editor text, code, and selection chrome.
    public var style: BlockInputStyle
    /// Image loader used for image block bytes and natural dimensions.
    public var imageLoader: any BlockInputImageLoading
    /// Optional disk cache used by the default loader for remote image bytes and dimensions.
    public var imageDiskCache: (any BlockInputImageDiskCaching)?
    /// Base URL used to resolve relative image sources before loading.
    public var imageBaseURL: URL?
    /// Base URL used to resolve relative file-link sources inserted by file drop hooks.
    public var fileBaseURL: URL?
    /// Whether remote `http` and `https` image URLs should be loaded.
    public var allowsRemoteImageLoading: Bool
    /// Maximum source image payload accepted by the default image loader.
    public var maximumImageSourceBytes: Int
    /// Maximum decoded width or height accepted by the default image loader.
    public var maximumImagePixelDimension: Int
    /// Placeholder aspect ratio used before dimensions are known.
    public var defaultImagePlaceholderAspectRatio: CGFloat
    /// Undo coordinator used by text and structural editor operations.
    ///
    /// When nil, `BlockInputView` uses a view-owned undo controller.
    public var undoController: BlockInputUndoController?
    /// Optional command bridge for hosts without direct access to the mounted AppKit editor.
    public var commandDispatcher: BlockInputEditorCommandDispatcher?
    /// Registered host keyboard shortcuts to intercept before built-in editor behavior.
    ///
    /// Only shortcuts present in this dictionary are intercepted. Handlers run on the main actor after modal,
    /// completion, and IME priority, but before editor defaults. Return `.ignored` to resume the editor's normal behavior
    /// for the original event, or `.performDefault(.returnKey)` to explicitly run plain Return behavior.
    public var keyboardShortcuts: [BlockInputKeyboardShortcut: BlockInputKeyboardShortcutHandler]
    /// Host completion source for mentions and slash commands.
    public var completionProvider: (any BlockInputCompletionProvider)?
    /// Optional host hook for resolving local file drops before insertion.
    public var fileDropHandler: BlockInputFileDropHandler?
    /// Where live slash-command completion is allowed to open.
    public var slashCommandAvailability: BlockInputSlashCommandAvailability
    /// Optional host router for slash-command chip clicks.
    public var slashCommandChipClickHandler:
        (@MainActor (BlockInputSlashCommandChipClickContext) -> BlockInputSlashCommandChipClickAction)?
    /// Built-in completion popup behavior, including caret anchoring and optional overlay hosting.
    public var completionPopupConfiguration: BlockInputCompletionPopupConfiguration
    /// Convenience access to `completionPopupConfiguration.placement`.
    public var completionPopupPlacement: BlockInputCompletionPopupPlacement {
        get { completionPopupConfiguration.placement }
        set { completionPopupConfiguration.placement = newValue }
    }
    /// Called immediately with the granular store mutation applied by the editor.
    ///
    /// Marker-adjusting stores may receive marker-only numbered-list changes instead of a replacement for every
    /// list item whose visible marker changed.
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

    /// Current loaded document snapshot from `documentStore`.
    ///
    /// Progressive stores expose only loaded blocks here; callers that need a complete save snapshot should call
    /// `BlockInputDocumentStore.completeDocumentSnapshot(limit:)`.
    public var document: BlockInputDocument {
        BlockInputDocument(blocks: (0..<documentStore.loadedBlockCount).compactMap { documentStore.block(at: $0) })
    }

    /// Creates configuration. When `documentStore` is supplied, it is the source of truth and `document` is ignored.
    public init(
        document: BlockInputDocument = BlockInputDocument(),
        documentStore: (any BlockInputDocumentStore)? = nil,
        allowsBlockReordering: Bool = true,
        editorHorizontalInset: CGFloat = BlockInputConfiguration.defaultEditorHorizontalInset,
        editorVerticalInset: CGFloat = BlockInputConfiguration.defaultEditorVerticalInset,
        dropIndicatorColor: NSColor = .controlAccentColor,
        style: BlockInputStyle = .default,
        imageLoader: any BlockInputImageLoading = BlockInputDefaultImageLoader(),
        imageDiskCache: (any BlockInputImageDiskCaching)? = BlockInputDefaultImageDiskCache(),
        imageBaseURL: URL? = nil,
        fileBaseURL: URL? = nil,
        allowsRemoteImageLoading: Bool = true,
        maximumImageSourceBytes: Int = 20 * 1024 * 1024,
        maximumImagePixelDimension: Int = 8_192,
        defaultImagePlaceholderAspectRatio: CGFloat = 16.0 / 9.0,
        undoController: BlockInputUndoController? = nil,
        commandDispatcher: BlockInputEditorCommandDispatcher? = nil,
        keyboardShortcuts: [BlockInputKeyboardShortcut: BlockInputKeyboardShortcutHandler] = [:],
        completionProvider: (any BlockInputCompletionProvider)? = nil,
        fileDropHandler: BlockInputFileDropHandler? = nil,
        slashCommandAvailability: BlockInputSlashCommandAvailability = .documentStart,
        slashCommandChipClickHandler:
            (@MainActor (BlockInputSlashCommandChipClickContext) -> BlockInputSlashCommandChipClickAction)? = nil,
        completionPopupPlacement: BlockInputCompletionPopupPlacement = .caret,
        completionPopupConfiguration: BlockInputCompletionPopupConfiguration? = nil,
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
        self.editorVerticalInset = editorVerticalInset
        self.dropIndicatorColor = dropIndicatorColor
        self.style = style
        self.imageLoader = imageLoader
        self.imageDiskCache = imageDiskCache
        self.imageBaseURL = imageBaseURL
        self.fileBaseURL = fileBaseURL
        self.allowsRemoteImageLoading = allowsRemoteImageLoading
        self.maximumImageSourceBytes = max(1, maximumImageSourceBytes)
        self.maximumImagePixelDimension = max(1, maximumImagePixelDimension)
        self.defaultImagePlaceholderAspectRatio = max(0.01, defaultImagePlaceholderAspectRatio)
        self.undoController = undoController
        self.commandDispatcher = commandDispatcher
        self.keyboardShortcuts = keyboardShortcuts
        self.completionProvider = completionProvider
        self.fileDropHandler = fileDropHandler
        self.slashCommandAvailability = slashCommandAvailability
        self.slashCommandChipClickHandler = slashCommandChipClickHandler
        self.completionPopupConfiguration = completionPopupConfiguration ?? BlockInputCompletionPopupConfiguration(
            placement: completionPopupPlacement
        )
        self.onDocumentMutation = onDocumentMutation
        self.onDocumentChange = onDocumentChange
        self.documentChangeSnapshotDelay = documentChangeSnapshotDelay
        self.onSelectionChange = onSelectionChange
        self.onFocusChange = onFocusChange
    }
}
