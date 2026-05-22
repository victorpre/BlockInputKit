import AppKit

final class BlockInputImageBlockView: NSView {
    private let imageView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var resizeStart: ResizeState?
    var onResize: ((Int, Int) -> Void)?
    var resizeDimensions: BlockInputImageDimensions?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configurePlaceholder(style: BlockInputStyle) {
        isHidden = false
        imageView.image = nil
        imageView.isHidden = true
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        applySurfaceStyle(style)
    }

    func configureLoadedImage(_ image: NSImage, style: BlockInputStyle, resizeDimensions: BlockInputImageDimensions?) {
        isHidden = false
        imageView.image = image
        self.resizeDimensions = resizeDimensions
        imageView.isHidden = false
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        applySurfaceStyle(style)
    }

    func configureFailure(style: BlockInputStyle) {
        isHidden = false
        imageView.image = nil
        imageView.isHidden = true
        statusLabel.stringValue = "Image failed to load"
        statusLabel.isHidden = false
        applySurfaceStyle(style)
    }

    func resetForReuse() {
        imageView.image = nil
        imageView.isHidden = true
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        isHidden = true
        toolTip = nil
        setAccessibilityLabel(nil)
        resizeDimensions = nil
        resizeStart = nil
        onResize = nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard resizeDimensions != nil else {
            return
        }
        addCursorRect(NSRect(x: bounds.maxX - 8, y: 0, width: 8, height: bounds.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: 0, y: 0, width: bounds.width, height: 8), cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        guard let dimensions = resizeDimensions,
              let edge = resizeEdge(at: convert(event.locationInWindow, from: nil)) else {
            super.mouseDown(with: event)
            return
        }
        resizeStart = ResizeState(edge: edge, origin: event.locationInWindow, dimensions: displayedResizeDimensions(for: dimensions))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let resizeStart else {
            super.mouseDragged(with: event)
            return
        }
        let deltaX = event.locationInWindow.x - resizeStart.origin.x
        let deltaY = event.locationInWindow.y - resizeStart.origin.y
        let width = resizeStart.edge == .right
            ? min(resizeStart.dimensions.width + Int(deltaX.rounded()), maximumResizeWidth)
            : resizeStart.dimensions.width
        let height = resizeStart.edge == .bottom ? resizeStart.dimensions.height - Int(deltaY.rounded()) : resizeStart.dimensions.height
        let resized = BlockInputImageDimensions(width: max(24, width), height: max(24, height))
        resizeDimensions = resized
        onResize?(resized.width, resized.height)
    }

    override func mouseUp(with event: NSEvent) {
        resizeStart = nil
        super.mouseUp(with: event)
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityRole(.image)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func applySurfaceStyle(_ style: BlockInputStyle) {
        layer?.backgroundColor = (style.imageBlock.placeholderColor ?? NSColor.quaternaryLabelColor.withAlphaComponent(0.28)).cgColor
        layer?.borderColor = (style.imageBlock.borderColor ?? NSColor.separatorColor.withAlphaComponent(0.6)).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = style.imageBlock.cornerRadius ?? 6
    }

    var loadedImageForTesting: NSImage? {
        imageView.image
    }

    var statusTextForTesting: String {
        statusLabel.stringValue
    }

    private func resizeEdge(at point: NSPoint) -> ResizeEdge? {
        if point.x >= bounds.maxX - 8 {
            return .right
        }
        if point.y <= bounds.minY + 8 {
            return .bottom
        }
        return nil
    }

    private var maximumResizeWidth: Int {
        guard bounds.width.isFinite,
              bounds.width > 0 else {
            return Int.max
        }
        return max(24, Int(bounds.width.rounded()))
    }

    private func displayedResizeDimensions(for dimensions: BlockInputImageDimensions) -> BlockInputImageDimensions {
        let width = max(CGFloat(dimensions.width), 1)
        let height = max(CGFloat(dimensions.height), 1)
        guard bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0 else {
            return dimensions
        }
        // Resize gestures operate in rendered editor coordinates. Without this scale-down, a huge source image must be
        // dragged hundreds or thousands of points before the visible full-width rendering changes.
        let scale = min(bounds.width / width, bounds.height / height)
        guard scale.isFinite,
              scale > 0 else {
            return dimensions
        }
        return BlockInputImageDimensions(
            width: max(1, Int((width * scale).rounded())),
            height: max(1, Int((height * scale).rounded()))
        )
    }
}

private struct ResizeState {
    var edge: ResizeEdge
    var origin: NSPoint
    var dimensions: BlockInputImageDimensions
}

private enum ResizeEdge {
    case right
    case bottom
}
