import Foundation

/// Editor presentation mode for image content.
public enum BlockInputImagePresentation: Equatable, Sendable {
    /// Render `BlockInputImage` values as inline standalone image blocks.
    case inlineBlocks
    /// Insert new images as textual Markdown links.
    ///
    /// Prebuilt `.image` blocks remain image blocks. Pair this with
    /// `BlockInputMarkdownImageParsingMode.preserveSourceText` when loading
    /// Markdown that should keep image syntax editable as text.
    case textLinks
    /// Deprecated spelling for the former editor-owned preview-strip mode.
    ///
    /// This is treated the same as `.textLinks`. Hosts that need previews should render them outside BlockInputKit.
    @available(*, deprecated, renamed: "textLinks")
    case textLinksWithPreviewStrip
}

extension BlockInputImagePresentation {
    var usesTextLinks: Bool {
        self != .inlineBlocks
    }
}
