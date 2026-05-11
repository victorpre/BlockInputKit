import AppKit

/// Draws per-line block markers aligned to the text view's line fragments.
final class BlockInputMarkerView: NSTextField {
    struct MarkerLine: Equatable {
        var text: String
        var indentationLevel: Int
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
        for (lineIndex, markerLine) in markerLines.enumerated() where !markerLine.text.isEmpty {
            let lineY = yOffset(forLineAt: lineIndex, lineHeight: lineHeight)
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
