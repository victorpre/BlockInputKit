import AppKit

/// Visual hit-test result for an inline Markdown link.
///
/// The window-space geometry is captured at mouse-down so mouse-up handling can survive tiny pointer drift, focus
/// changes, and AppKit's occasional remapping of insertion offsets near hidden Markdown source.
struct BlockInputLinkHitResult {
    let range: BlockInputInlineMarkdownRange
    let windowRects: [NSRect]
    let windowLocation: NSPoint
}

extension BlockInputTextView {
    override func draw(_ dirtyRect: NSRect) {
        drawInlineChipBackgrounds(in: dirtyRect)
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
        let isCompletedTrackedLinkClick = event.type == .leftMouseUp && blockSelectionClickLinkRange != nil
        let isSingleClick = event.clickCount == 1 || isCompletedTrackedLinkClick
        guard isSingleClick,
              !isDraggingBlockSelection,
              !isUsingNativeMouseSelection,
              event.modifierFlags.isDisjoint(with: disallowedModifiers) else {
            return false
        }
        let location = convert(event.locationInWindow, from: nil)
        let offset = blockSelectionDragAnchorOffset ?? characterIndexForInsertion(at: location)
        let localRange = NSRange(location: offset, length: 0)
        let selectedRange = blockItem?.sourceSelectedRange(for: self, localRange: localRange) ?? localRange
        let localClickedLinkRange = blockSelectionClickLinkRange ?? linkHitResult(for: event)?.range
        let clickedLinkRange = localClickedLinkRange.flatMap {
            blockItem?.sourceInlineMarkdownRange(for: self, localRange: $0) ?? $0
        }
        return blockItem?.requestLinkClick(
            selectedRange: selectedRange,
            clickedLinkRange: clickedLinkRange,
            event: event
        ) == true
    }

    func inlineChipRange(atWindowLocation windowLocation: NSPoint) -> BlockInputInlineMarkdownRange? {
        guard supportsInlineMarkdownLinkRendering,
              let layoutManager,
              let textContainer else {
            return nil
        }
        layoutManager.ensureLayout(for: textContainer)
        return inlineChipHitResult(
            atWindowLocation: windowLocation,
            layoutManager: layoutManager,
            textContainer: textContainer
        )?.range
    }

    func linkHitResult(for event: NSEvent) -> BlockInputLinkHitResult? {
        for windowLocation in linkEventWindowLocations(event) {
            if let hit = linkHitResult(atWindowLocation: windowLocation) {
                return hit
            }
        }
        return nil
    }

    func linkHitResult(atWindowLocation windowLocation: NSPoint) -> BlockInputLinkHitResult? {
        guard supportsInlineMarkdownLinkRendering,
              let layoutManager,
              let textContainer else {
            return nil
        }
        let location = convert(windowLocation, from: nil)
        layoutManager.ensureLayout(for: textContainer)
        if let chipHit = inlineChipHitResult(
            atWindowLocation: windowLocation,
            layoutManager: layoutManager,
            textContainer: textContainer
        ) {
            return chipHit
        }
        if let regularHit = regularLinkHitResult(
            atWindowLocation: windowLocation,
            layoutManager: layoutManager,
            textContainer: textContainer
        ) {
            return regularHit
        }
        let offset = characterIndexForInsertion(at: location)
        for linkRange in linkRangesForCurrentText() where linkRange.inlineChipKind(in: string) == nil {
            guard linkRange.contentRange.containsOrTouches(offset) else {
                continue
            }
            let characterRange = string.linkCursorClampedRange(linkRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0 else {
                continue
            }
            return BlockInputLinkHitResult(
                range: linkRange,
                windowRects: linkCursorRects(
                    glyphRange: glyphRange,
                    layoutManager: layoutManager,
                    textContainer: textContainer
                ).map { convert($0, to: nil) },
                windowLocation: windowLocation
            )
        }
        return nil
    }

    func linkEventWindowLocations(_ event: NSEvent) -> [NSPoint] {
        guard let window,
              event.window === window || event.windowNumber == window.windowNumber else {
            return [event.locationInWindow]
        }
        let livePoint = window.mouseLocationOutsideOfEventStream
        guard livePoint != event.locationInWindow else {
            return [event.locationInWindow]
        }
        return [event.locationInWindow, livePoint]
    }

    private func regularLinkHitResult(
        atWindowLocation windowLocation: NSPoint,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> BlockInputLinkHitResult? {
        let location = convert(windowLocation, from: nil)
        for linkRange in linkRangesForCurrentText() where linkRange.inlineChipKind(in: string) == nil {
            let characterRange = string.linkCursorClampedRange(linkRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0 else {
                continue
            }
            let cursorRects = linkCursorRects(
                glyphRange: glyphRange,
                layoutManager: layoutManager,
                textContainer: textContainer
            )
            if cursorRects.contains(where: { $0.contains(location) }) {
                return BlockInputLinkHitResult(
                    range: linkRange,
                    windowRects: cursorRects.map { convert($0, to: nil) },
                    windowLocation: windowLocation
                )
            }
        }
        return nil
    }

    private func inlineChipHitResult(
        atWindowLocation windowLocation: NSPoint,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> BlockInputLinkHitResult? {
        let location = convert(windowLocation, from: nil)
        for linkRange in linkRangesForCurrentText() {
            guard let chipKind = linkRange.inlineChipKind(in: string) else {
                continue
            }
            let characterRange = string.linkCursorClampedRange(linkRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0 else {
                continue
            }
            let backgroundRects = inlineChipBackgroundRects(
                glyphRange: glyphRange,
                layoutManager: layoutManager,
                textContainer: textContainer,
                extraLeftPadding: chipIconPadding(for: chipKind),
                leadingMargin: Self.chipLeadingMargin(for: chipKind)
            )
            if backgroundRects.contains(where: { $0.contains(location) }) {
                return BlockInputLinkHitResult(
                    range: linkRange,
                    windowRects: backgroundRects.map { convert($0, to: nil) },
                    windowLocation: windowLocation
                )
            }
        }
        return nil
    }

    /// Adds pointing-hand cursor rects over visible links; chips use their padded visual rects.
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
            if let chipKind = linkRange.inlineChipKind(in: string) {
                for cursorRect in inlineChipBackgroundRects(
                    glyphRange: glyphRange,
                    layoutManager: layoutManager,
                    textContainer: textContainer,
                    extraLeftPadding: chipIconPadding(for: chipKind),
                    leadingMargin: Self.chipLeadingMargin(for: chipKind)
                ) {
                    addCursorRect(cursorRect, cursor: .pointingHand)
                }
            } else {
                for cursorRect in linkCursorRects(
                    glyphRange: glyphRange,
                    layoutManager: layoutManager,
                    textContainer: textContainer
                ) {
                    addCursorRect(cursorRect, cursor: .pointingHand)
                }
            }
        }
    }

    func drawInlineChipBackgrounds(in dirtyRect: NSRect) {
        guard supportsInlineMarkdownLinkRendering,
              let layoutManager,
              let textContainer else {
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        for chipRange in inlineChipVisualRangesForCurrentText() {
            guard let chipStyle = inlineChipStyle(for: chipRange),
                  let chipKind = chipRange.inlineChipKind(in: string) else {
                continue
            }
            let characterRange = string.linkCursorClampedRange(chipRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0 else {
                continue
            }
            let iconPadding = chipIconPadding(for: chipKind)
            let chipLeadingMargin = Self.chipLeadingMargin(for: chipKind)
            for drawRect in inlineChipBackgroundRects(
                glyphRange: glyphRange,
                layoutManager: layoutManager,
                textContainer: textContainer,
                extraLeftPadding: iconPadding,
                leadingMargin: chipLeadingMargin
            ) where drawRect.intersects(dirtyRect) {
                drawInlineChipBackground(in: drawRect, style: chipStyle)
                if iconPadding > 0 {
                    switch chipKind {
                    case .dueDateOverdue, .dueDateToday, .dueDateUpcoming:
                        drawDueDateIcon(in: drawRect, leadingMargin: chipLeadingMargin, color: dueDateIconColor(for: chipKind))
                    case .whenDateOverdue, .whenDateToday, .whenDateUpcoming:
                        drawWhenDateIcon(in: drawRect, leadingMargin: chipLeadingMargin, color: whenDateIconColor(for: chipKind))
                    default:
                        break
                    }
                }
            }
        }
    }

    func inlineChipBackgroundRects() -> [NSRect] {
        guard supportsInlineMarkdownLinkRendering,
              let layoutManager,
              let textContainer else {
            return []
        }
        layoutManager.ensureLayout(for: textContainer)
        return inlineChipVisualRangesForCurrentText().flatMap { chipRange -> [NSRect] in
            let characterRange = string.linkCursorClampedRange(chipRange.contentRange)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                .clamped(toGlyphCount: layoutManager.numberOfGlyphs)
            guard glyphRange.length > 0,
                  let chipKind = chipRange.inlineChipKind(in: string) else {
                return []
            }
            return inlineChipBackgroundRects(
                glyphRange: glyphRange,
                layoutManager: layoutManager,
                textContainer: textContainer,
                extraLeftPadding: chipIconPadding(for: chipKind),
                leadingMargin: Self.chipLeadingMargin(for: chipKind)
            )
        }
    }

    func inlineChipBackgroundRectsForTesting() -> [NSRect] {
        inlineChipBackgroundRects()
    }

    private func linkCursorRects(
        glyphRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> [NSRect] {
        var cursorRects: [NSRect] = []
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineFragmentRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineLinkGlyphRange = NSIntersectionRange(glyphRange, lineGlyphRange)
            if lineLinkGlyphRange.length > 0 {
                let labelRect = layoutManager.boundingRect(forGlyphRange: lineLinkGlyphRange, in: textContainer)
                let cursorRect = NSRect(
                    x: labelRect.minX + textContainerOrigin.x,
                    y: lineFragmentRect.minY + textContainerOrigin.y,
                    width: labelRect.width,
                    height: lineFragmentRect.height
                )
                .insetBy(dx: -1, dy: -1)
                cursorRects.append(cursorRect)
            }
            glyphIndex = max(glyphIndex + 1, NSMaxRange(lineGlyphRange))
        }
        return cursorRects
    }

    private func linkRangesForCurrentText() -> [BlockInputInlineMarkdownRange] {
        inlineMarkdownRangesForCurrentText().filter { $0.style == .link }
    }

    private func inlineChipVisualRangesForCurrentText() -> [BlockInputInlineMarkdownRange] {
        let isChecklist = blockItem?.renderedBlock?.kind.isChecklist == true
        return inlineMarkdownRangesForCurrentText().filter {
            switch $0.style {
            case .hashtag, .dueDate, .whenDate:
                return isChecklist
            default:
                return $0.inlineChipKind(in: string) != nil
            }
        }
    }

    private func inlineChipStyle(for range: BlockInputInlineMarkdownRange) -> BlockInputInlineChipStyle? {
        guard let kind = range.inlineChipKind(in: string) else {
            return nil
        }
        return blockItem?.style.inlineChipStyle(for: kind)
    }

    private func inlineMarkdownRangesForCurrentText() -> [BlockInputInlineMarkdownRange] {
        BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: string,
            excluding: BlockInputCodeParsing.inlineCodeRanges(in: string).map(\.fullRange),
            fileBaseURL: blockItem?.fileBaseURL,
            rawSlashCommandChips: rendersRawSlashCommandChips,
            slashCommandAvailability: blockItem?.slashCommandAvailability ?? .documentStart,
            isDocumentStartBlock: blockItem?.isDocumentStartBlock == true
        )
    }

    private var supportsInlineMarkdownLinkRendering: Bool {
        blockItem?.supportsInlineMarkdownLinkRendering(for: self) == true
    }

    private var rendersRawSlashCommandChips: Bool {
        guard blockItem?.isTableCellTextView(self) != true else {
            return false
        }
        return blockItem?.rawSlashCommandChips == true
    }

    private func inlineChipBackgroundRects(
        glyphRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        extraLeftPadding: CGFloat = 0,
        leadingMargin: CGFloat = 0
    ) -> [NSRect] {
        let drawingOffset = textContainerOrigin
        let baseLineHeight = inlineChipBaseLineHeight(layoutManager: layoutManager)
        var rects: [NSRect] = []
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineFragmentUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineChipGlyphRange = NSIntersectionRange(glyphRange, lineGlyphRange)
            if lineChipGlyphRange.length > 0 {
                let labelRect = layoutManager.boundingRect(forGlyphRange: lineChipGlyphRange, in: textContainer)
                let verticalPadding: CGFloat = 2
                let visualHeight = max(baseLineHeight, labelRect.height) + (verticalPadding * 2)
                let visualY = lineFragmentUsedRect.midY - (visualHeight / 2)

                rects.append(NSRect(
                    x: labelRect.minX + drawingOffset.x - 2 - extraLeftPadding - leadingMargin,
                    y: visualY + drawingOffset.y,
                    width: labelRect.width + 4 + extraLeftPadding + leadingMargin,
                    height: visualHeight
                ))
            }
            glyphIndex = max(glyphIndex + 1, NSMaxRange(lineGlyphRange))
        }
        return rects
    }

    private func inlineChipBaseLineHeight(layoutManager: NSLayoutManager) -> CGFloat {
        let baseFont = blockItem?.renderedBlock.map {
            BlockInputBlockItem.font(for: $0.kind, style: blockItem?.style ?? .default)
        } ?? font
        guard let baseFont else {
            return 0
        }
        return ceil(max(layoutManager.defaultLineHeight(for: baseFont), baseFont.boundingRectForFont.height))
    }
    private static let dueDateIconTextGap: CGFloat = 4
    private static let dueDateChipLeadingMargin: CGFloat = 6

    private func chipIconPadding(for chipKind: BlockInputInlineChipKind) -> CGFloat {
        switch chipKind {
        case .dueDateOverdue, .dueDateToday, .dueDateUpcoming:
            return dueDateIconSize + Self.dueDateIconTextGap
        case .whenDateOverdue, .whenDateToday, .whenDateUpcoming:
            return whenDateIconSize + Self.dueDateIconTextGap
        default:
            return 0
        }
    }

    private static func chipLeadingMargin(for chipKind: BlockInputInlineChipKind) -> CGFloat {
        switch chipKind {
        case .dueDateOverdue, .dueDateToday, .dueDateUpcoming:
            return Self.dueDateChipLeadingMargin
        case .whenDateOverdue, .whenDateToday, .whenDateUpcoming:
            return Self.dueDateChipLeadingMargin
        default:
            return 0
        }
    }

    private var dueDateIconSize: CGFloat {
        let baseFont = blockItem?.renderedBlock.map {
            BlockInputBlockItem.font(for: $0.kind, style: blockItem?.style ?? .default)
        } ?? font
        guard let baseFont else {
            return 10
        }
        return ceil(max(baseFont.pointSize * 0.94, 1) * 0.75)
    }

    private func drawDueDateIcon(in rect: NSRect, leadingMargin: CGFloat = 0, color: NSColor) {
        let size = dueDateIconSize
        let iconRect = NSRect(
            x: rect.minX + 2 + leadingMargin,
            y: rect.midY - size / 2,
            width: size,
            height: size
        )
        if let icon = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            let configured = icon.withSymbolConfiguration(config)
            let tinted = configured?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
            tinted?.draw(in: iconRect)
        }
    }

    private func dueDateIconColor(for chipKind: BlockInputInlineChipKind) -> NSColor {
        switch chipKind {
        case .dueDateOverdue, .dueDateToday:
            return dueDateAlertColor
        case .dueDateUpcoming:
            return .secondaryLabelColor
        default:
            return .labelColor
        }
    }

    private var whenDateIconSize: CGFloat {
        let baseFont = blockItem?.renderedBlock.map {
            BlockInputBlockItem.font(for: $0.kind, style: blockItem?.style ?? .default)
        } ?? font
        guard let baseFont else {
            return 10
        }
        return ceil(max(baseFont.pointSize * 0.94, 1) * 0.75)
    }

    private func drawWhenDateIcon(in rect: NSRect, leadingMargin: CGFloat = 0, color: NSColor) {
        let size = whenDateIconSize
        let iconRect = NSRect(
            x: rect.minX + 2 + leadingMargin,
            y: rect.midY - size / 2,
            width: size,
            height: size
        )
        if let icon = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            let configured = icon.withSymbolConfiguration(config)
            let tinted = configured?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
            tinted?.draw(in: iconRect)
        }
    }

    private func whenDateIconColor(for chipKind: BlockInputInlineChipKind) -> NSColor {
        switch chipKind {
        case .whenDateOverdue:
            return dueDateAlertColor
        case .whenDateToday:
            return whenDateTodayColor
        case .whenDateUpcoming:
            return .secondaryLabelColor
        default:
            return .labelColor
        }
    }

    private func drawInlineChipBackground(in rect: NSRect, style: BlockInputInlineChipStyle) {
        if let fillColor = style.fillColor {
            fillColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: style.cornerRadius, yRadius: style.cornerRadius).fill()
        }
        if let strokeColor = style.strokeColor {
            strokeColor.setStroke()
            let stroke = NSBezierPath(
                roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                xRadius: style.cornerRadius,
                yRadius: style.cornerRadius
            )
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
