import AppKit

extension BlockInputTextView {
    override func draw(_ dirtyRect: NSRect) {
        drawFileLinkChipBackgrounds(in: dirtyRect)
        super.draw(dirtyRect)
    }

    /// Returns true for the exact command-click gesture that should open a link immediately.
    func shouldRequestCommandClickLink(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedModifiers = NSEvent.ModifierFlags([.option, .control, .shift])
        return modifiers.contains(.command) && modifiers.isDisjoint(with: disallowedModifiers)
    }

    /// Routes a completed plain click to link editing after native drag and text selection handling have had first chance.
    func requestLinkClickIfNeeded(with event: NSEvent) -> Bool {
        let disallowedModifiers = NSEvent.ModifierFlags([.option, .control, .shift])
        guard event.clickCount == 1,
              !isDraggingBlockSelection,
              !isUsingNativeMouseSelection,
              event.modifierFlags.isDisjoint(with: disallowedModifiers) else {
            return false
        }
        let location = convert(event.locationInWindow, from: nil)
        let offset = characterIndexForInsertion(at: location)
        return blockItem?.requestLinkClick(selectedRange: NSRange(location: offset, length: 0), event: event) == true
    }

    /// Adds pointing-hand cursor rects over visible link labels only; hidden Markdown delimiters are intentionally ignored.
    func addLinkCursorRects() {
        guard supportsInlineMarkdownLinkRendering,
              let layoutManager,
              let textContainer else {
            return
        }
        let textLength = (string as NSString).length
        guard textLength > 0 else {
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        for linkRange in linkRangesForCurrentText() where linkRange.contentRange.length > 0 {
            let characterRange = string.linkCursorClampedRange(linkRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0 else {
                continue
            }
            addLinkCursorRects(for: glyphRange, layoutManager: layoutManager, textContainer: textContainer)
        }
    }

    func drawFileLinkChipBackgrounds(in dirtyRect: NSRect) {
        guard supportsInlineMarkdownLinkRendering,
              let layoutManager,
              let textContainer else {
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        for linkRange in linkRangesForCurrentText() where linkRange.linkDestination?.isFileURL == true {
            let characterRange = string.linkCursorClampedRange(linkRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0 else {
                continue
            }
            drawFileLinkChipBackground(
                glyphRange: glyphRange,
                dirtyRect: dirtyRect,
                layoutManager: layoutManager,
                textContainer: textContainer
            )
        }
    }

    private func addLinkCursorRects(
        for glyphRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) {
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            _ = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineLinkGlyphRange = NSIntersectionRange(glyphRange, lineGlyphRange)
            if lineLinkGlyphRange.length > 0 {
                let cursorRect = layoutManager.boundingRect(forGlyphRange: lineLinkGlyphRange, in: textContainer)
                    .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                    .insetBy(dx: -1, dy: -1)
                addCursorRect(cursorRect, cursor: .pointingHand)
            }
            glyphIndex = max(glyphIndex + 1, NSMaxRange(lineGlyphRange))
        }
    }

    private func linkRangesForCurrentText() -> [BlockInputInlineMarkdownRange] {
        BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: string,
            excluding: BlockInputCodeParsing.inlineCodeRanges(in: string).map(\.fullRange)
        )
        .filter { $0.style == .link }
    }

    private var supportsInlineMarkdownLinkRendering: Bool {
        guard let kind = blockItem?.renderedBlock?.kind else {
            return false
        }
        return BlockInputBlockItem.supportsInlineMarkdownStyling(kind)
    }

    private func drawFileLinkChipBackground(
        glyphRange: NSRange,
        dirtyRect: NSRect,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) {
        let drawingOffset = textContainerOrigin
        let selectedGlyphRange = NSRange(location: NSNotFound, length: 0)
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: selectedGlyphRange,
            in: textContainer
        ) { enclosingRect, _ in
            let drawRect = NSRect(
                x: enclosingRect.minX + drawingOffset.x - 2,
                y: enclosingRect.minY + drawingOffset.y - 2,
                width: enclosingRect.width + 4,
                height: enclosingRect.height + 4
            )
            guard drawRect.intersects(dirtyRect) else {
                return
            }
            NSColor.controlAccentColor.withAlphaComponent(0.11).setFill()
            NSBezierPath(roundedRect: drawRect, xRadius: 6, yRadius: 6).fill()
            NSColor.controlAccentColor.withAlphaComponent(0.18).setStroke()
            let stroke = NSBezierPath(roundedRect: drawRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
            stroke.lineWidth = 1
            stroke.stroke()
        }
    }
}

private extension String {
    func linkCursorClampedRange(_ range: NSRange) -> NSRange {
        let text = self as NSString
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), max(text.length - location, 0))
        return NSRange(location: location, length: length)
    }
}

private extension NSRange {
    func clamped(toGlyphCount glyphCount: Int) -> NSRange {
        let location = min(max(location, 0), glyphCount)
        let length = min(max(length, 0), max(glyphCount - location, 0))
        return NSRange(location: location, length: length)
    }
}
