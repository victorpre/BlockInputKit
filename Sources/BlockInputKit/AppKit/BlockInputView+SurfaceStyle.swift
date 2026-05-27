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
                scrollView.contentView.backgroundColor = scrollBackgroundColor
                scrollView.contentView.drawsBackground = true
            } else {
                scrollView.backgroundColor = .clear
                scrollView.drawsBackground = false
                scrollView.contentView.backgroundColor = .clear
                scrollView.contentView.drawsBackground = false
            }
            collectionView.backgroundColors = style.editorSurface.collectionBackgroundColor.map { [$0] } ?? []
        }
    }

    private func applyRootLayerSurfaceStyle() {
        guard let layer else {
            return
        }
        guard let chrome = style.editorSurface.chrome else {
            removeEditorChromeLayers()
            layer.backgroundColor = style.editorSurface.editorBackgroundColor?.cgColor
            layer.borderColor = nil
            layer.borderWidth = 0
            layer.cornerRadius = 0
            layer.maskedCorners = BlockInputEditorChromeCorners.all.caCornerMask
            layer.masksToBounds = false
            return
        }

        let fillColor = chrome.fillColor ?? style.editorSurface.editorBackgroundColor
        layer.backgroundColor = nil
        layer.borderColor = nil
        layer.borderWidth = 0
        layer.cornerRadius = 0
        layer.maskedCorners = BlockInputEditorChromeCorners.all.caCornerMask
        layer.masksToBounds = false
        installEditorChromeLayersIfNeeded()
        editorChromeFillLayer.fillColor = fillColor?.cgColor
        editorChromeStrokeLayer.fillColor = nil
        editorChromeStrokeLayer.strokeColor = chrome.strokeColor?.cgColor
        editorChromeStrokeLayer.lineWidth = chrome.strokeColor == nil ? 0 : chrome.borderWidth
        layer.mask = chrome.clipsContentToShape ? editorChromeMaskLayer : nil
        updateEditorChromeLayers()
    }

    func updateEditorChromeLayers() {
        guard style.editorSurface.chrome != nil else {
            return
        }
        let currentBounds = bounds
        editorChromeFillLayer.frame = currentBounds
        editorChromeStrokeLayer.frame = currentBounds
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
        editorChromeStrokeLayer.path = chromePath
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
        if editorChromeStrokeLayer.superlayer == nil {
            layer.insertSublayer(editorChromeStrokeLayer, above: editorChromeFillLayer)
        }
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

        let topLeft = roundedCorners.contains(.topLeft) ? radius : 0
        let topRight = roundedCorners.contains(.topRight) ? radius : 0
        let bottomRight = roundedCorners.contains(.bottomRight) ? radius : 0
        let bottomLeft = roundedCorners.contains(.bottomLeft) ? radius : 0
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
