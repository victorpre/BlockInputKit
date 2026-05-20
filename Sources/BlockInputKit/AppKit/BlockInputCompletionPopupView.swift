import AppKit

private let completionPopupCornerRadius: CGFloat = 10
private let completionRowCornerRadius: CGFloat = 6
private let completionRowHeight: CGFloat = 36
private let completionRowSpacing: CGFloat = 4
private let completionPopupInset: CGFloat = 8
private let completionMaxVisibleRows = 6

struct BlockInputCompletionPopupState: Equatable {
    var suggestions: [BlockInputCompletionSuggestion]
    var highlightedIndex: Int
    var isLoading: Bool
}

/// AppKit-rendered completion popup with explicit event-routing entry points.
///
/// The popup may be owned by the editor or rehosted into a host overlay container, so callers can route mouse events
/// by converted coordinates instead of relying on normal AppKit responder targeting.
@MainActor
final class BlockInputCompletionPopupView: NSView {
    private var state = BlockInputCompletionPopupState(suggestions: [], highlightedIndex: 0, isLoading: false)
    private var rowViews: [BlockInputCompletionPopupRowView] = []
    private let loadingIndicator = NSProgressIndicator()
    private let loadingField = NSTextField(labelWithString: "Loading suggestions...")
    private let emptyField = NSTextField(labelWithString: "No matches")
    private var visibleStartIndex = 0
    private var visibleSuggestionIDs: [String] = []
    private var onSelect: (BlockInputCompletionSuggestion) -> Void = { _ in }
    private var onHighlight: (Int) -> Void = { _ in }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.measuredHeight(for: state))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(
        state: BlockInputCompletionPopupState,
        onSelect: @escaping (BlockInputCompletionSuggestion) -> Void,
        onHighlight: @escaping (Int) -> Void
    ) {
        self.state = state
        self.onSelect = onSelect
        self.onHighlight = onHighlight
        rebuild()
    }

    override func layout() {
        super.layout()
        let contentWidth = max(0, bounds.width - completionPopupInset * 2)
        let indicatorSize = NSSize(width: 16, height: 16)
        loadingIndicator.frame = NSRect(
            x: completionPopupInset + 4,
            y: floor((bounds.height - indicatorSize.height) / 2),
            width: indicatorSize.width,
            height: indicatorSize.height
        )
        loadingField.frame = NSRect(
            x: loadingIndicator.frame.maxX + 10,
            y: floor((bounds.height - loadingField.intrinsicContentSize.height) / 2),
            width: max(0, contentWidth - 34),
            height: loadingField.intrinsicContentSize.height
        )
        emptyField.frame = NSRect(
            x: completionPopupInset + 4,
            y: floor((bounds.height - emptyField.intrinsicContentSize.height) / 2),
            width: max(0, contentWidth - 8),
            height: emptyField.intrinsicContentSize.height
        )
        for (offset, row) in rowViews.enumerated() {
            let yOffset = completionPopupInset +
                CGFloat(max(0, rowViews.count - offset - 1)) * (completionRowHeight + completionRowSpacing)
            row.frame = NSRect(x: completionPopupInset, y: yOffset, width: contentWidth, height: completionRowHeight)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(point) else {
            return nil
        }
        for row in rowViews.reversed() {
            let rowPoint = row.convert(point, from: self)
            if row.bounds.contains(rowPoint) {
                return row
            }
        }
        return self
    }

    override func mouseMoved(with event: NSEvent) {
        if routeMouseMoved(at: convert(event.locationInWindow, from: nil), event: event) {
            return
        }
        super.mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if routeMouseDown(at: convert(event.locationInWindow, from: nil), event: event) {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if routeMouseUp(at: convert(event.locationInWindow, from: nil), event: event) {
            return
        }
        super.mouseUp(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if routeScrollWheel(at: convert(event.locationInWindow, from: nil), event: event) {
            return
        }
        super.scrollWheel(with: event)
    }

    @discardableResult
    func routeMouseMoved(at point: NSPoint, event: NSEvent) -> Bool {
        guard !isHidden, bounds.contains(point) else {
            return false
        }
        row(at: point)?.mouseMoved(with: event)
        return true
    }

    @discardableResult
    func routeMouseDown(at point: NSPoint, event: NSEvent) -> Bool {
        guard !isHidden, bounds.contains(point) else {
            return false
        }
        row(at: point)?.mouseDown(with: event)
        return true
    }

    @discardableResult
    func routeMouseUp(at point: NSPoint, event: NSEvent) -> Bool {
        guard !isHidden, bounds.contains(point) else {
            return false
        }
        row(at: point)?.mouseUp(with: event)
        return true
    }

    @discardableResult
    func routeScrollWheel(at point: NSPoint, event: NSEvent) -> Bool {
        guard !isHidden, bounds.contains(point) else {
            return false
        }
        scrollVisibleSuggestions(deltaY: event.scrollingDeltaY)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        completionPopupFillColor().setFill()
        NSBezierPath(roundedRect: bounds, xRadius: completionPopupCornerRadius, yRadius: completionPopupCornerRadius).fill()
        NSColor.separatorColor.withAlphaComponent(0.24).setStroke()
        let stroke = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: completionPopupCornerRadius,
            yRadius: completionPopupCornerRadius
        )
        stroke.lineWidth = 1
        stroke.stroke()
    }

    static func measuredHeight(for state: BlockInputCompletionPopupState?) -> CGFloat {
        guard let state else {
            return 0
        }
        if state.isLoading || state.suggestions.isEmpty {
            return 46
        }
        let visibleRows = min(completionMaxVisibleRows, state.suggestions.count)
        return completionPopupInset * 2 +
            CGFloat(visibleRows) * completionRowHeight +
            CGFloat(max(0, visibleRows - 1)) * completionRowSpacing
    }

    private func setup() {
        wantsLayer = true
        shadow = NSShadow()
        shadow?.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow?.shadowBlurRadius = 14
        shadow?.shadowOffset = NSSize(width: 0, height: -5)

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isIndeterminate = true
        loadingIndicator.startAnimation(nil)

        [loadingField, emptyField].forEach {
            $0.font = .systemFont(ofSize: 12, weight: .medium)
            $0.textColor = .secondaryLabelColor
        }
        [loadingIndicator, loadingField, emptyField].forEach(addSubview)
    }

    private func rebuild() {
        rowViews.forEach { $0.removeFromSuperview() }
        rowViews = []
        isHidden = false
        loadingIndicator.isHidden = !state.isLoading
        loadingField.isHidden = !state.isLoading
        emptyField.isHidden = state.isLoading || !state.suggestions.isEmpty

        if !state.isLoading {
            rowViews = visibleSuggestionRows(anchorHighlightedSuggestion: true).map { index, suggestion in
                makeRow(index: index, suggestion: suggestion)
            }
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
        needsDisplay = true
    }

    private func row(at point: NSPoint) -> BlockInputCompletionPopupRowView? {
        layoutSubtreeIfNeeded()
        return rowViews.reversed().first { row in
            row.bounds.contains(row.convert(point, from: self))
        }
    }

    private func scrollVisibleSuggestions(deltaY: CGFloat) {
        guard state.suggestions.count > completionMaxVisibleRows,
              deltaY != 0 else {
            return
        }
        let maximumStartIndex = max(0, state.suggestions.count - completionMaxVisibleRows)
        let direction = deltaY < 0 ? 1 : -1
        let nextStartIndex = min(max(0, visibleStartIndex + direction), maximumStartIndex)
        guard nextStartIndex != visibleStartIndex else {
            return
        }
        visibleStartIndex = nextStartIndex
        let visibleRange = nextStartIndex..<(nextStartIndex + completionMaxVisibleRows)
        if !visibleRange.contains(state.highlightedIndex) {
            let nextHighlightedIndex = direction > 0
                ? nextStartIndex
                : min(nextStartIndex + completionMaxVisibleRows - 1, state.suggestions.count - 1)
            onHighlight(nextHighlightedIndex)
            return
        }
        rowViews.forEach { $0.removeFromSuperview() }
        rowViews = visibleSuggestionRows(anchorHighlightedSuggestion: false).map { index, suggestion in
            makeRow(index: index, suggestion: suggestion)
        }
        needsLayout = true
        needsDisplay = true
    }

    private func makeRow(
        index: Int,
        suggestion: BlockInputCompletionSuggestion
    ) -> BlockInputCompletionPopupRowView {
        let row = BlockInputCompletionPopupRowView()
        row.configure(
            suggestion: suggestion,
            index: index,
            isHighlighted: index == state.highlightedIndex,
            onSelect: { [weak self] in self?.onSelect(suggestion) },
            onHighlight: { [weak self] index in self?.onHighlight(index) }
        )
        addSubview(row)
        return row
    }

    private func visibleSuggestionRows(
        anchorHighlightedSuggestion: Bool
    ) -> ArraySlice<(Int, BlockInputCompletionSuggestion)> {
        let indexedSuggestions = state.suggestions.enumerated().map { ($0.offset, $0.element) }
        let suggestionIDs = state.suggestions.map(\.id)
        if visibleSuggestionIDs != suggestionIDs {
            visibleStartIndex = 0
            visibleSuggestionIDs = suggestionIDs
        }

        guard indexedSuggestions.count > completionMaxVisibleRows else {
            visibleStartIndex = 0
            return indexedSuggestions[...]
        }

        let maximumStartIndex = max(0, indexedSuggestions.count - completionMaxVisibleRows)
        if anchorHighlightedSuggestion {
            if state.highlightedIndex < visibleStartIndex {
                visibleStartIndex = state.highlightedIndex
            } else if state.highlightedIndex >= visibleStartIndex + completionMaxVisibleRows {
                visibleStartIndex = state.highlightedIndex - completionMaxVisibleRows + 1
            }
        }
        visibleStartIndex = min(max(0, visibleStartIndex), maximumStartIndex)
        return indexedSuggestions[visibleStartIndex..<(visibleStartIndex + completionMaxVisibleRows)]
    }

    private func completionPopupFillColor() -> NSColor {
        switch effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
        case .darkAqua:
            return NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.17, alpha: 1)
        default:
            return NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        }
    }
}

@MainActor
private final class BlockInputCompletionPopupRowView: NSView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")
    private let detailField = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var index = 0
    private var isHighlighted = false
    private var onSelect: () -> Void = {}
    private var onHighlight: (Int) -> Void = { _ in }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(
        suggestion: BlockInputCompletionSuggestion,
        index: Int,
        isHighlighted: Bool,
        onSelect: @escaping () -> Void,
        onHighlight: @escaping (Int) -> Void
    ) {
        self.index = index
        self.isHighlighted = isHighlighted
        self.onSelect = onSelect
        self.onHighlight = onHighlight
        titleField.stringValue = suggestion.title
        subtitleField.stringValue = suggestion.subtitle ?? ""
        detailField.stringValue = suggestion.detailText ?? ""
        iconView.image = suggestion.iconSystemName.flatMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: suggestion.title)
        } ?? NSImage(systemSymbolName: "text.cursor", accessibilityDescription: suggestion.title)
        setAccessibilityLabel(accessibilityLabel(for: suggestion))
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let iconSize: CGFloat = 14
        iconView.frame = NSRect(
            x: 10,
            y: floor((bounds.height - iconSize) / 2),
            width: iconSize,
            height: iconSize
        )
        let contentX: CGFloat = 32
        let detailWidth = min(max(0, detailField.intrinsicContentSize.width), max(0, bounds.width * 0.34))
        let detailX = bounds.maxX - detailWidth - 10
        detailField.frame = NSRect(
            x: detailX,
            y: floor((bounds.height - detailField.intrinsicContentSize.height) / 2),
            width: detailWidth,
            height: detailField.intrinsicContentSize.height
        )
        let titleWidth = max(0, detailX - contentX - 8)
        let hasSubtitle = !subtitleField.stringValue.isEmpty
        if hasSubtitle {
            titleField.frame = NSRect(x: contentX, y: 19, width: titleWidth, height: 16)
            subtitleField.frame = NSRect(x: contentX, y: 5, width: titleWidth, height: 13)
        } else {
            titleField.frame = NSRect(
                x: contentX,
                y: floor((bounds.height - titleField.intrinsicContentSize.height) / 2),
                width: titleWidth,
                height: titleField.intrinsicContentSize.height
            )
            subtitleField.frame = NSRect(x: contentX, y: bounds.maxY, width: titleWidth, height: 0)
        }
        subtitleField.isHidden = !hasSubtitle
        detailField.isHidden = detailField.stringValue.isEmpty
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        highlightPointerRow()
    }

    override func mouseMoved(with event: NSEvent) {
        highlightPointerRow()
    }

    override func mouseDown(with event: NSEvent) {
        highlightPointerRow()
    }

    override func mouseUp(with event: NSEvent) {
        highlightPointerRow()
        onSelect()
    }

    override func accessibilityPerformPress() -> Bool {
        onSelect()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isHighlighted else {
            return
        }
        NSColor.controlAccentColor.withAlphaComponent(0.13).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: completionRowCornerRadius, yRadius: completionRowCornerRadius).fill()
    }

    private func setup() {
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingMiddle
        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingMiddle
        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .tertiaryLabelColor
        detailField.alignment = .right
        detailField.lineBreakMode = .byTruncatingMiddle
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        [iconView, titleField, subtitleField, detailField].forEach(addSubview)
    }

    private func highlightPointerRow() {
        guard !isHighlighted else {
            return
        }
        isHighlighted = true
        onHighlight(index)
        needsDisplay = true
    }

    private func accessibilityLabel(for suggestion: BlockInputCompletionSuggestion) -> String {
        [suggestion.title, suggestion.subtitle, suggestion.detailText]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
    }
}
