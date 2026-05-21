import AppKit

/// Visual styling used by AppKit block editor surfaces.
public struct BlockInputStyle: @unchecked Sendable {
    /// Current built-in visual style.
    public static var `default`: BlockInputStyle { BlockInputStyle() }

    /// Base text styling for paragraphs, lists, quotes, and scaled block typography.
    public var baseText: BlockInputTextStyle
    /// Background color used for editor-owned block and text selection chrome.
    public var selectionBackgroundColor: NSColor
    /// Styling for inline single-line code spans.
    public var inlineCode: BlockInputInlineCodeStyle
    /// Styling for fenced code block surfaces.
    public var codeBlock: BlockInputCodeBlockStyle

    /// Creates editor styling with optional overrides for built-in visual defaults.
    public init(
        baseText: BlockInputTextStyle = BlockInputTextStyle(),
        selectionBackgroundColor: NSColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.72),
        inlineCode: BlockInputInlineCodeStyle = BlockInputInlineCodeStyle(),
        codeBlock: BlockInputCodeBlockStyle = BlockInputCodeBlockStyle()
    ) {
        self.baseText = baseText
        self.selectionBackgroundColor = selectionBackgroundColor
        self.inlineCode = inlineCode
        self.codeBlock = codeBlock
    }
}

/// Font and foreground color styling for normal editor text.
public struct BlockInputTextStyle: @unchecked Sendable {
    /// Base font for body text. When nil, the editor uses its built-in body font.
    public var font: NSFont?
    /// Base foreground color. When nil, the editor uses the system label color.
    public var foregroundColor: NSColor?

    /// Creates normal text styling overrides.
    public init(font: NSFont? = nil, foregroundColor: NSColor? = nil) {
        self.font = font
        self.foregroundColor = foregroundColor
    }
}

/// Font, foreground, and background styling for inline code spans.
public struct BlockInputInlineCodeStyle: @unchecked Sendable {
    /// Inline code font. When nil, inline code uses a scaled monospaced variant of the surrounding text font.
    public var font: NSFont?
    /// Inline code foreground color. When nil, inline code inherits the base text foreground color.
    public var foregroundColor: NSColor?
    /// Inline code background color. When nil, inline code uses the built-in subtle background color.
    public var backgroundColor: NSColor?

    /// Creates inline code styling overrides.
    public init(font: NSFont? = nil, foregroundColor: NSColor? = nil, backgroundColor: NSColor? = nil) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
}

/// Font, foreground, background, and rounding styling for fenced code block surfaces.
public struct BlockInputCodeBlockStyle: @unchecked Sendable {
    /// Fenced code block font. When nil, code blocks use the built-in monospaced font.
    public var font: NSFont?
    /// Fenced code block foreground color. When nil, code text uses syntax highlighting with the base text color fallback.
    public var foregroundColor: NSColor?
    /// Fenced code block background color. When nil, code blocks use the built-in appearance-aware surface color.
    public var backgroundColor: NSColor?
    /// Fenced code block corner radius. When nil, code blocks use the built-in radius.
    public var cornerRadius: CGFloat?

    /// Creates fenced code block styling overrides.
    public init(
        font: NSFont? = nil,
        foregroundColor: NSColor? = nil,
        backgroundColor: NSColor? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
    }
}
