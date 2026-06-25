import Foundation

/// Host-owned image shown in the editor's preview strip without inserting Markdown into the document.
public struct BlockInputImagePreviewAttachment: Sendable {
    /// Stable host identifier for this preview item.
    public var id: String
    /// Local image file to thumbnail.
    public var fileURL: URL
    /// User-visible label used for accessibility and fallback thumbnail text.
    public var label: String
    /// Called when the preview tile is opened.
    public var open: @MainActor @Sendable (BlockInputImagePreviewAttachment) -> Void
    /// Called when the preview tile's remove control is pressed.
    public var remove: @MainActor @Sendable (BlockInputImagePreviewAttachment) -> Void

    /// Creates a host-owned image preview item.
    public init(
        id: String,
        fileURL: URL,
        label: String,
        open: @escaping @MainActor @Sendable (BlockInputImagePreviewAttachment) -> Void,
        remove: @escaping @MainActor @Sendable (BlockInputImagePreviewAttachment) -> Void
    ) {
        self.id = id
        self.fileURL = fileURL
        self.label = label
        self.open = open
        self.remove = remove
    }
}
