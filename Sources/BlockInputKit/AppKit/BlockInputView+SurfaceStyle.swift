import AppKit
import QuartzCore

extension BlockInputView {
    func applyEditorSurfaceStyle() {
        wantsLayer = true
        effectiveAppearance.performAsCurrentDrawingAppearance {
            applyRootLayerSurfaceStyle()
            if let scrollBackgroundColor = style.editorSurface.scrollBackgroundColor {
                scrollView.backgroundColor = scrollBackgroundColor
                scrollView.drawsBackground = true
                scrollView.layer?.backgroundColor = scrollBackgroundColor.cgColor
                scrollView.contentView.backgroundColor = scrollBackgroundColor
                scrollView.contentView.drawsBackground = true
                scrollView.contentView.layer?.backgroundColor = scrollBackgroundColor.cgColor
            } else {
                scrollView.backgroundColor = .clear
                scrollView.drawsBackground = false
                scrollView.layer?.backgroundColor = NSColor.clear.cgColor
                scrollView.contentView.backgroundColor = .clear
                scrollView.contentView.drawsBackground = false
                scrollView.contentView.layer?.backgroundColor = NSColor.clear.cgColor
            }
            collectionView.backgroundColors = style.editorSurface.collectionBackgroundColor.map { [$0] } ?? []
            collectionView.layer?.backgroundColor = (style.editorSurface.collectionBackgroundColor ?? .clear).cgColor
        }
    }

    private func applyRootLayerSurfaceStyle() {
        guard let layer else {
            return
        }
        guard let chrome = style.editorSurface.chrome else {
            removeEditorChromeLayers()
            editorChromeView.configure(chrome: nil, fallbackFillColor: nil)
            editorChromeStrokeOverlayView.configure(chrome: nil, fallbackFillColor: nil)
            layer.backgroundColor = style.editorSurface.editorBackgroundColor?.cgColor
            layer.borderColor = nil
            layer.borderWidth = 0
            layer.cornerRadius = 0
            layer.maskedCorners = BlockInputEditorChromeCorners.all.caCornerMask
            layer.masksToBounds = false
            return
        }

        let fillColor = chrome.fillColor ?? style.editorSurface.editorBackgroundColor
        editorChromeView.configure(chrome: chrome, fallbackFillColor: style.editorSurface.editorBackgroundColor)
        editorChromeStrokeOverlayView.configure(chrome: chrome, fallbackFillColor: nil)
        layer.backgroundColor = nil
        layer.borderColor = nil
        layer.borderWidth = 0
        layer.cornerRadius = 0
        layer.maskedCorners = BlockInputEditorChromeCorners.all.caCornerMask
        layer.masksToBounds = false
        installEditorChromeLayersIfNeeded()
        editorChromeFillLayer.fillColor = fillColor?.cgColor
        editorChromeStrokeLayer.fillColor = nil
        editorChromeStrokeLayer.strokeColor = nil
        editorChromeStrokeLayer.lineWidth = 0
        layer.mask = chrome.clipsContentToShape ? editorChromeMaskLayer : nil
        updateEditorChromeLayers()
    }

    func updateEditorChromeLayers() {
        guard style.editorSurface.chrome != nil else {
            return
        }
        let currentBounds = bounds
        editorChromeFillLayer.frame = currentBounds
        editorChromeStrokeLayer.frame = .zero
        editorChromeMaskLayer.frame = currentBounds

        guard currentBounds.width > 0, currentBounds.height > 0,
              let chrome = style.editorSurface.chrome else {
            editorChromeFillLayer.path = nil
            editorChromeStrokeLayer.path = nil
            editorChromeMaskLayer.path = nil
            return
        }

        let strokeInset = chrome.strokeColor == nil ? 0 : chrome.borderWidth / 2
        let chromePath = CGPath.blockInputEditorChromePath(
            in: currentBounds.insetBy(dx: strokeInset, dy: strokeInset),
            radius: chrome.cornerRadius,
            roundedCorners: chrome.roundedCorners
        )
        editorChromeFillLayer.path = chromePath
        editorChromeStrokeLayer.path = nil
        editorChromeMaskLayer.path = CGPath.blockInputEditorChromePath(
            in: currentBounds,
            radius: chrome.cornerRadius,
            roundedCorners: chrome.roundedCorners
        )
    }

    private func installEditorChromeLayersIfNeeded() {
        guard let layer else {
            return
        }
        if editorChromeFillLayer.superlayer == nil {
            layer.insertSublayer(editorChromeFillLayer, at: 0)
        }
        editorChromeStrokeLayer.removeFromSuperlayer()
    }

    private func removeEditorChromeLayers() {
        editorChromeFillLayer.removeFromSuperlayer()
        editorChromeStrokeLayer.removeFromSuperlayer()
        if layer?.mask === editorChromeMaskLayer {
            layer?.mask = nil
        }
        editorChromeFillLayer.path = nil
        editorChromeStrokeLayer.path = nil
        editorChromeMaskLayer.path = nil
    }
}

private extension BlockInputEditorChromeCorners {
    var caCornerMask: CACornerMask {
        var mask: CACornerMask = []
        if contains(.topLeft) {
            mask.insert(.layerMinXMinYCorner)
        }
        if contains(.topRight) {
            mask.insert(.layerMaxXMinYCorner)
        }
        if contains(.bottomLeft) {
            mask.insert(.layerMinXMaxYCorner)
        }
        if contains(.bottomRight) {
            mask.insert(.layerMaxXMaxYCorner)
        }
        return mask
    }
}

final class BlockInputEditorChromeView: NSView {
    var drawsFill = true
    var drawsStroke = true
    var strokePassCount = 1

    private var chrome: BlockInputEditorChromeStyle?
    private var fallbackFillColor: NSColor?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(chrome: BlockInputEditorChromeStyle?, fallbackFillColor: NSColor?) {
        self.chrome = chrome
        self.fallbackFillColor = fallbackFillColor
        isHidden = chrome == nil
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0,
              let chrome else {
            return
        }

        effectiveAppearance.performAsCurrentDrawingAppearance {
            if drawsFill, let fillColor = chrome.fillColor ?? fallbackFillColor {
                fillColor.setFill()
                NSBezierPath.blockInputEditorChromePath(
                    in: bounds,
                    radius: chrome.cornerRadius,
                    roundedCorners: chrome.roundedCorners
                )
                .fill()
            }

            if drawsStroke,
               let strokeColor = chrome.strokeColor,
               chrome.borderWidth > 0,
               !chrome.strokedEdges.isEmpty {
                strokeColor.setStroke()
                let strokeInset = chrome.borderWidth / 2
                let strokeRect = bounds.insetBy(dx: strokeInset, dy: strokeInset)
                let path = chrome.strokedEdges == .all
                    ? NSBezierPath.blockInputEditorChromePath(
                        in: strokeRect,
                        radius: chrome.cornerRadius,
                        roundedCorners: chrome.roundedCorners
                    )
                    : NSBezierPath.blockInputEditorChromeStrokePath(
                        in: strokeRect,
                        radius: chrome.cornerRadius,
                        roundedCorners: chrome.roundedCorners,
                        strokedEdges: chrome.strokedEdges
                    )
                path.lineWidth = chrome.borderWidth
                for _ in 0..<max(0, strokePassCount) {
                    path.stroke()
                }
            }
        }
    }
}

private extension NSBezierPath {
    static func blockInputEditorChromePath(
        in rect: NSRect,
        radius: CGFloat,
        roundedCorners: BlockInputEditorChromeCorners
    ) -> NSBezierPath {
        let radius = min(max(0, radius), min(rect.width, rect.height) / 2)
        let path = NSBezierPath()
        guard rect.width > 0, rect.height > 0 else {
            return path
        }

        let topLeft = roundedCorners.contains(.topLeft) ? radius : 0
        let topRight = roundedCorners.contains(.topRight) ? radius : 0
        let bottomRight = roundedCorners.contains(.bottomRight) ? radius : 0
        let bottomLeft = roundedCorners.contains(.bottomLeft) ? radius : 0
        let curveFactor: CGFloat = 0.45

        path.move(to: NSPoint(x: rect.minX + bottomLeft, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - bottomRight, y: rect.minY))
        if bottomRight > 0 {
            path.curve(
                to: NSPoint(x: rect.maxX, y: rect.minY + bottomRight),
                controlPoint1: NSPoint(x: rect.maxX - bottomRight * curveFactor, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + bottomRight * curveFactor)
            )
        }

        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - topRight))
        if topRight > 0 {
            path.curve(
                to: NSPoint(x: rect.maxX - topRight, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - topRight * curveFactor),
                controlPoint2: NSPoint(x: rect.maxX - topRight * curveFactor, y: rect.maxY)
            )
        }

        path.line(to: NSPoint(x: rect.minX + topLeft, y: rect.maxY))
        if topLeft > 0 {
            path.curve(
                to: NSPoint(x: rect.minX, y: rect.maxY - topLeft),
                controlPoint1: NSPoint(x: rect.minX + topLeft * curveFactor, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - topLeft * curveFactor)
            )
        }

        path.line(to: NSPoint(x: rect.minX, y: rect.minY + bottomLeft))
        if bottomLeft > 0 {
            path.curve(
                to: NSPoint(x: rect.minX + bottomLeft, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + bottomLeft * curveFactor),
                controlPoint2: NSPoint(x: rect.minX + bottomLeft * curveFactor, y: rect.minY)
            )
        }
        path.close()
        return path
    }

    static func blockInputEditorChromeStrokePath(
        in rect: NSRect,
        radius: CGFloat,
        roundedCorners: BlockInputEditorChromeCorners,
        strokedEdges: BlockInputEditorChromeEdges
    ) -> NSBezierPath {
        let radius = min(max(0, radius), min(rect.width, rect.height) / 2)
        let path = NSBezierPath()
        guard rect.width > 0, rect.height > 0 else {
            return path
        }

        let radii = BlockInputEditorChromeStrokeRadii(radius: radius, roundedCorners: roundedCorners)
        path.blockInputAppendBottomStroke(in: rect, radii: radii, strokedEdges: strokedEdges)
        path.blockInputAppendRightStroke(in: rect, radii: radii, strokedEdges: strokedEdges)
        path.blockInputAppendTopStroke(in: rect, radii: radii, strokedEdges: strokedEdges)
        path.blockInputAppendLeftStroke(in: rect, radii: radii, strokedEdges: strokedEdges)
        return path
    }

    private func blockInputAppendBottomStroke(
        in rect: NSRect,
        radii: BlockInputEditorChromeStrokeRadii,
        strokedEdges: BlockInputEditorChromeEdges
    ) {
        guard strokedEdges.contains(.bottom) || strokedEdges.contains(.right) else {
            return
        }
        if strokedEdges.contains(.bottom) {
            move(to: NSPoint(x: rect.minX + radii.bottomLeft, y: rect.minY))
            line(to: NSPoint(x: rect.maxX - radii.bottomRight, y: rect.minY))
        }
        if radii.bottomRight > 0, strokedEdges.contains(.bottom), strokedEdges.contains(.right) {
            curve(
                to: NSPoint(x: rect.maxX, y: rect.minY + radii.bottomRight),
                controlPoint1: NSPoint(x: rect.maxX - radii.bottomRight * Self.blockInputEditorChromeCurveFactor, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + radii.bottomRight * Self.blockInputEditorChromeCurveFactor)
            )
        } else if strokedEdges.contains(.right) {
            move(to: NSPoint(x: rect.maxX, y: rect.minY + radii.bottomRight))
        }
    }

    private func blockInputAppendRightStroke(
        in rect: NSRect,
        radii: BlockInputEditorChromeStrokeRadii,
        strokedEdges: BlockInputEditorChromeEdges
    ) {
        guard strokedEdges.contains(.right) || strokedEdges.contains(.top) else {
            return
        }
        if strokedEdges.contains(.right) {
            line(to: NSPoint(x: rect.maxX, y: rect.maxY - radii.topRight))
        }
        if radii.topRight > 0, strokedEdges.contains(.right), strokedEdges.contains(.top) {
            curve(
                to: NSPoint(x: rect.maxX - radii.topRight, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - radii.topRight * Self.blockInputEditorChromeCurveFactor),
                controlPoint2: NSPoint(x: rect.maxX - radii.topRight * Self.blockInputEditorChromeCurveFactor, y: rect.maxY)
            )
        } else if strokedEdges.contains(.top) {
            move(to: NSPoint(x: rect.maxX - radii.topRight, y: rect.maxY))
        }
    }

    private func blockInputAppendTopStroke(
        in rect: NSRect,
        radii: BlockInputEditorChromeStrokeRadii,
        strokedEdges: BlockInputEditorChromeEdges
    ) {
        guard strokedEdges.contains(.top) || strokedEdges.contains(.left) else {
            return
        }
        if strokedEdges.contains(.top) {
            line(to: NSPoint(x: rect.minX + radii.topLeft, y: rect.maxY))
        }
        if radii.topLeft > 0, strokedEdges.contains(.top), strokedEdges.contains(.left) {
            curve(
                to: NSPoint(x: rect.minX, y: rect.maxY - radii.topLeft),
                controlPoint1: NSPoint(x: rect.minX + radii.topLeft * Self.blockInputEditorChromeCurveFactor, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - radii.topLeft * Self.blockInputEditorChromeCurveFactor)
            )
        } else if strokedEdges.contains(.left) {
            move(to: NSPoint(x: rect.minX, y: rect.maxY - radii.topLeft))
        }
    }

    private func blockInputAppendLeftStroke(
        in rect: NSRect,
        radii: BlockInputEditorChromeStrokeRadii,
        strokedEdges: BlockInputEditorChromeEdges
    ) {
        guard strokedEdges.contains(.left) else {
            return
        }
        line(to: NSPoint(x: rect.minX, y: rect.minY + radii.bottomLeft))
        if radii.bottomLeft > 0, strokedEdges.contains(.bottom) {
            curve(
                to: NSPoint(x: rect.minX + radii.bottomLeft, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + radii.bottomLeft * Self.blockInputEditorChromeCurveFactor),
                controlPoint2: NSPoint(x: rect.minX + radii.bottomLeft * Self.blockInputEditorChromeCurveFactor, y: rect.minY)
            )
        }
    }

    private static var blockInputEditorChromeCurveFactor: CGFloat { 0.45 }
}

private struct BlockInputEditorChromeStrokeRadii {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomRight: CGFloat
    let bottomLeft: CGFloat

    init(radius: CGFloat, roundedCorners: BlockInputEditorChromeCorners) {
        topLeft = roundedCorners.contains(.topLeft) ? radius : 0
        topRight = roundedCorners.contains(.topRight) ? radius : 0
        bottomRight = roundedCorners.contains(.bottomRight) ? radius : 0
        bottomLeft = roundedCorners.contains(.bottomLeft) ? radius : 0
    }
}

private extension CGPath {
    static func blockInputEditorChromePath(
        in rect: CGRect,
        radius: CGFloat,
        roundedCorners: BlockInputEditorChromeCorners
    ) -> CGPath {
        let radius = min(max(0, radius), min(rect.width, rect.height) / 2)
        let path = CGMutablePath()
        guard rect.width > 0, rect.height > 0 else {
            return path
        }

        // `CAShapeLayer.render(in:)` maps the path's maxY edge to the visual
        // top in AppKit-backed layers, so translate visual corner options to
        // the path-space edge they actually draw on.
        let topLeft = roundedCorners.contains(.bottomLeft) ? radius : 0
        let topRight = roundedCorners.contains(.bottomRight) ? radius : 0
        let bottomRight = roundedCorners.contains(.topRight) ? radius : 0
        let bottomLeft = roundedCorners.contains(.topLeft) ? radius : 0
        let curveFactor: CGFloat = 0.45

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + topRight),
                control1: CGPoint(x: rect.maxX - topRight * curveFactor, y: rect.minY),
                control2: CGPoint(x: rect.maxX, y: rect.minY + topRight * curveFactor)
            )
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addCurve(
                to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY),
                control1: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight * curveFactor),
                control2: CGPoint(x: rect.maxX - bottomRight * curveFactor, y: rect.maxY)
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft),
                control1: CGPoint(x: rect.minX + bottomLeft * curveFactor, y: rect.maxY),
                control2: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft * curveFactor)
            )
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addCurve(
                to: CGPoint(x: rect.minX + topLeft, y: rect.minY),
                control1: CGPoint(x: rect.minX, y: rect.minY + topLeft * curveFactor),
                control2: CGPoint(x: rect.minX + topLeft * curveFactor, y: rect.minY)
            )
        }
        path.closeSubpath()
        return path
    }
}
