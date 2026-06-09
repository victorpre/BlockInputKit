import AppKit

final class BlockInputCheckboxView: NSView {
    var isChecked = false {
        didSet {
            needsDisplay = true
        }
    }
    var accentColor = NSColor.controlAccentColor {
        didSet {
            needsDisplay = true
        }
    }
    var isEnabled = true
    weak var target: AnyObject?
    var action: Selector?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let action else { return }
        isChecked.toggle()
        needsDisplay = true
        NSApplication.shared.sendAction(action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let inset: CGFloat = 0.5
        let innerRect = bounds.insetBy(dx: inset, dy: inset)

        if isChecked {
            accentColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()

            let checkPath = NSBezierPath()
            checkPath.lineWidth = 1.4
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round
            checkPath.move(to: NSPoint(x: bounds.minX + bounds.width * 0.25, y: bounds.midY))
            checkPath.line(to: NSPoint(x: bounds.minX + bounds.width * 0.43, y: bounds.maxY - bounds.height * 0.28))
            checkPath.line(to: NSPoint(x: bounds.maxX - bounds.width * 0.22, y: bounds.minY + bounds.height * 0.28))
            NSColor.white.setStroke()
            checkPath.stroke()
        } else {
            NSColor.quaternaryLabelColor.setStroke()
            let path = NSBezierPath(roundedRect: innerRect, xRadius: 4, yRadius: 4)
            path.lineWidth = 1.0
            path.stroke()
        }
    }
}
