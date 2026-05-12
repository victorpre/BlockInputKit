import AppKit

/// Draws per-line block markers aligned to the text view's line fragments.
final class BlockInputMarkerView: NSTextField {
    struct MarkerLine: Equatable {
        var text: String
        var indentationLevel: Int
        var checkboxState: CheckboxState?

        init(
            text: String,
            indentationLevel: Int,
            checkboxState: CheckboxState? = nil
        ) {
            self.text = text
            self.indentationLevel = indentationLevel
            self.checkboxState = checkboxState
        }
    }

    enum CheckboxState: Equatable {
        case unchecked
        case checked
    }

    private static let textMarkerVerticalAdjustment: CGFloat = -1

    private(set) var markerLines: [MarkerLine] = []
    private(set) var markerLineYOffsets: [CGFloat] = []

    override var isFlipped: Bool {
        true
    }

    func setMarkerLines(_ markerLines: [MarkerLine]) {
        self.markerLines = markerLines
        markerLineYOffsets = []
        stringValue = markerLines.map(\.text).joined(separator: "\n")
        needsDisplay = true
    }

    func setMarkerLineYOffsets(_ markerLineYOffsets: [CGFloat]) {
        self.markerLineYOffsets = markerLineYOffsets
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !markerLines.isEmpty else {
            super.draw(dirtyRect)
            return
        }
        let resolvedFont = font ?? .preferredFont(forTextStyle: .body)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont,
            .foregroundColor: textColor ?? NSColor.tertiaryLabelColor
        ]
        let lineHeight = ceil(resolvedFont.ascender - resolvedFont.descender + resolvedFont.leading)
        for (lineIndex, markerLine) in markerLines.enumerated() {
            let lineY = yOffset(forLineAt: lineIndex, lineHeight: lineHeight)
            if drawChecklistMarker(markerLine, lineY: lineY, lineHeight: lineHeight) {
                continue
            }
            guard !markerLine.text.isEmpty else {
                continue
            }
            if drawUnorderedListMarker(markerLine, lineY: lineY, lineHeight: lineHeight) {
                continue
            }
            let markerSize = (markerLine.text as NSString).size(withAttributes: attributes)
            let xPosition = Self.markerGlyphXPosition(indentationLevel: markerLine.indentationLevel, markerWidth: markerSize.width)
            let yPosition = Self.textMarkerYPosition(lineY: lineY, lineHeight: lineHeight, markerHeight: markerSize.height)
            (markerLine.text as NSString).draw(
                at: NSPoint(x: xPosition, y: yPosition),
                withAttributes: attributes
            )
        }
    }

    private func yOffset(forLineAt lineIndex: Int, lineHeight: CGFloat) -> CGFloat {
        guard markerLineYOffsets.indices.contains(lineIndex) else {
            return CGFloat(lineIndex) * lineHeight
        }
        return markerLineYOffsets[lineIndex]
    }

    private func drawUnorderedListMarker(_ markerLine: MarkerLine, lineY: CGFloat, lineHeight: CGFloat) -> Bool {
        guard let markerStyle = UnorderedMarkerStyle(text: markerLine.text) else {
            return false
        }
        let color = textColor ?? NSColor.tertiaryLabelColor
        let markerSize = markerStyle.size
        let markerFrame = NSRect(
            x: Self.markerGlyphXPosition(indentationLevel: markerLine.indentationLevel, markerWidth: markerSize),
            y: lineY + max(0, (lineHeight - markerSize) / 2),
            width: markerSize,
            height: markerSize
        )
        color.set()
        switch markerStyle {
        case .filledCircle:
            NSBezierPath(ovalIn: markerFrame).fill()
        case .hollowCircle:
            let path = NSBezierPath(ovalIn: markerFrame.insetBy(dx: 0.75, dy: 0.75))
            path.lineWidth = 1.5
            path.stroke()
        case .filledSquare:
            NSBezierPath(rect: markerFrame).fill()
        }
        return true
    }

    private func drawChecklistMarker(_ markerLine: MarkerLine, lineY: CGFloat, lineHeight: CGFloat) -> Bool {
        guard let checkboxState = markerLine.checkboxState else {
            return false
        }
        let markerSize: CGFloat = 16
        let markerFrame = NSRect(
            x: Self.markerGlyphXPosition(indentationLevel: markerLine.indentationLevel, markerWidth: markerSize),
            y: lineY + max(0, (lineHeight - markerSize) / 2),
            width: markerSize,
            height: markerSize
        )
        let fillColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.28)
        fillColor.setFill()
        NSBezierPath(roundedRect: markerFrame, xRadius: 5, yRadius: 5).fill()
        if checkboxState == .checked {
            let checkPath = NSBezierPath()
            checkPath.lineWidth = 1.8
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round
            checkPath.move(to: NSPoint(x: markerFrame.minX + 4, y: markerFrame.midY))
            checkPath.line(to: NSPoint(x: markerFrame.minX + 7, y: markerFrame.maxY - 4))
            checkPath.line(to: NSPoint(x: markerFrame.maxX - 4, y: markerFrame.minY + 4))
            (textColor ?? NSColor.labelColor).withAlphaComponent(0.75).setStroke()
            checkPath.stroke()
        }
        return true
    }

    static func markerGlyphXPosition(indentationLevel: Int, markerWidth: CGFloat) -> CGFloat {
        let indent = BlockInputBlockItem.contentIndent(forIndentationLevel: indentationLevel)
        let centeredOffset = max(0, (BlockInputBlockItem.markerChromeWidth - markerWidth) / 2)
        return indent + centeredOffset
    }

    static func textMarkerYPosition(lineY: CGFloat, lineHeight: CGFloat, markerHeight: CGFloat) -> CGFloat {
        lineY + max(0, (lineHeight - markerHeight) / 2) + textMarkerVerticalAdjustment
    }
}

private enum UnorderedMarkerStyle {
    case filledCircle
    case hollowCircle
    case filledSquare

    init?(text: String) {
        switch text {
        case "•":
            self = .filledCircle
        case "◦":
            self = .hollowCircle
        case "▪":
            self = .filledSquare
        default:
            return nil
        }
    }

    var size: CGFloat {
        switch self {
        case .filledCircle:
            return 7.5
        case .hollowCircle:
            return 8.5
        case .filledSquare:
            return 7
        }
    }
}
