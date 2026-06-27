import AppKit

final class BlockInputAspectFillImageView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    var cornerRadius: CGFloat = 0 {
        didSet {
            layer?.cornerRadius = cornerRadius
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image,
              let imageFrame = aspectFillImageFrame else {
            return
        }
        image.draw(
            in: imageFrame,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private var aspectFillImageFrame: NSRect? {
        guard let image,
              image.size.width > 0,
              image.size.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return nil
        }
        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        return NSRect(
            x: bounds.midX - (drawSize.width / 2),
            y: bounds.midY - (drawSize.height / 2),
            width: drawSize.width,
            height: drawSize.height
        )
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = cornerRadius
    }

    var aspectFillImageFrameForTesting: NSRect? {
        aspectFillImageFrame
    }
}
