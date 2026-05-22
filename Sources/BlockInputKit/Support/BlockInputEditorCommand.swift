import Foundation

/// Controls whether insert commands mutate immediately or present editor UI.
public enum BlockInputCommandPresentation: String, Equatable, Codable, Sendable {
    /// Mutate directly when enough command data is supplied; otherwise present editor UI.
    case automatic
    /// Present editor UI even when command data is supplied.
    case modal
}

/// Payload for programmatic link insertion.
public struct BlockInputInsertLinkCommand: Equatable, Codable, Sendable {
    /// Optional label to place in the link modal or inserted Markdown.
    public var text: String?
    /// Optional destination URL string.
    public var urlString: String?
    /// Presentation behavior for the command.
    public var presentation: BlockInputCommandPresentation

    /// Creates a link insertion command payload.
    public init(
        text: String? = nil,
        urlString: String? = nil,
        presentation: BlockInputCommandPresentation = .automatic
    ) {
        self.text = text
        self.urlString = urlString
        self.presentation = presentation
    }
}

/// Payload for programmatic image insertion.
public struct BlockInputInsertImageCommand: Equatable, Codable, Sendable {
    /// Optional image source URL string.
    public var source: String?
    /// Optional image alternate text.
    public var altText: String?
    /// Presentation behavior for the command.
    public var presentation: BlockInputCommandPresentation

    /// Creates an image insertion command payload.
    public init(
        source: String? = nil,
        altText: String? = nil,
        presentation: BlockInputCommandPresentation = .automatic
    ) {
        self.source = source
        self.altText = altText
        self.presentation = presentation
    }
}

/// Programmatic editor commands that mirror BlockInputKit-owned shortcut and context-menu actions.
public enum BlockInputEditorCommand: Equatable, Codable, Sendable {
    /// Undo the most recent editor text or structural edit.
    case undo
    /// Redo the most recently undone editor text or structural edit.
    case redo
    /// Select all editable document content from the current editor context.
    case selectAll
    /// Copy the active text, block, or mixed selection to the pasteboard.
    case copy
    /// Cut the active text, block, or mixed selection to the pasteboard.
    case cut
    /// Paste pasteboard content into the active text selection or caret.
    case paste
    /// Toggle bold inline formatting for the active text selection.
    case bold
    /// Toggle italic inline formatting for the active text selection.
    case italic
    /// Toggle underline inline formatting for the active text selection.
    case underline
    /// Toggle strikethrough inline formatting for the active text selection.
    case strikethrough
    /// Insert or edit a Markdown link using the supplied command payload.
    case insertLink(BlockInputInsertLinkCommand = BlockInputInsertLinkCommand())
    /// Remove the active Markdown link when the current context targets one.
    case removeLink
    /// Insert an image block using the supplied command payload.
    case insertImage(BlockInputInsertImageCommand = BlockInputInsertImageCommand())
    /// Delete the active image block when the current context targets one.
    case deleteImage
    /// Insert a default table after the active block when table insertion is available.
    case insertTable
    /// Insert a body row next to the active table cell.
    case insertRow
    /// Insert a column next to the active table cell.
    case insertColumn
    /// Delete the active table body row, preserving a final empty body row.
    case deleteRow
    /// Delete the active table column.
    case deleteColumn
    /// Delete the active table block.
    case deleteTable
}

/// Availability or toggle state for a command.
public enum BlockInputEditorCommandState: String, Equatable, Codable, Sendable {
    /// The command cannot run in the current editor context.
    case unavailable
    /// The command is available and its toggle state is inactive, or it is a non-toggle command.
    case off
    /// The command is available and its toggle state is active.
    case on
}

/// SwiftUI-friendly command bridge bound to the currently mounted editor view.
@MainActor
public final class BlockInputEditorCommandDispatcher {
    private weak var editorView: BlockInputView?

    /// Creates an unbound dispatcher. Pass it through ``BlockInputConfiguration`` to bind it to a mounted editor.
    public init() {}

    /// Performs a command on the mounted editor.
    @discardableResult
    public func perform(_ command: BlockInputEditorCommand) -> Bool {
        editorView?.performCommand(command) ?? false
    }

    /// Returns whether the mounted editor can currently perform a command.
    public func canPerform(_ command: BlockInputEditorCommand) -> Bool {
        editorView?.canPerformCommand(command) ?? false
    }

    /// Returns the mounted editor's current command state.
    public func state(for command: BlockInputEditorCommand) -> BlockInputEditorCommandState {
        editorView?.state(for: command) ?? .unavailable
    }

    func bind(to editorView: BlockInputView) {
        self.editorView = editorView
    }

    func unbind(from editorView: BlockInputView) {
        guard self.editorView === editorView else {
            return
        }
        self.editorView = nil
    }
}
