import AppKit

/// Nested text scroller used by a block item.
///
/// Code blocks own horizontal overflow, but mostly vertical wheel sequences should keep moving the editor document.
final class BlockInputBlockItemScrollView: NSScrollView {
    weak var blockItem: BlockInputBlockItem?
    private var isForwardingVerticalScrollSequence = false
    private var verticalScrollSequenceToken = UUID()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureBoundsObservation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureBoundsObservation()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func scrollWheel(with event: NSEvent) {
        if shouldBreakVerticalSequenceForHorizontalScroll(event),
           scrollHorizontallyIfNeeded(for: event) {
            isForwardingVerticalScrollSequence = false
            verticalScrollSequenceToken = UUID()
            return
        }
        if isForwardingVerticalScrollSequence,
           let verticalAncestorScrollView {
            verticalAncestorScrollView.scrollWheel(with: event)
            schedulePhaseLessVerticalScrollSequenceResetIfNeeded(for: event)
            updateVerticalScrollSequenceState(after: event)
            return
        }
        if scrollHorizontallyIfNeeded(for: event) {
            return
        }
        if shouldForwardVerticalScroll(event),
           let verticalAncestorScrollView {
            isForwardingVerticalScrollSequence = true
            schedulePhaseLessVerticalScrollSequenceResetIfNeeded(for: event)
            verticalAncestorScrollView.scrollWheel(with: event)
            updateVerticalScrollSequenceState(after: event)
            return
        }
        updateVerticalScrollSequenceState(after: event)
        super.scrollWheel(with: event)
    }

    private func configureBoundsObservation() {
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )
    }

    @objc
    private func contentBoundsDidChange() {
        guard contentView.bounds.origin.y != 0 else {
            blockItem?.textScrollViewDidChangeVisibleBounds()
            return
        }
        let origin = NSPoint(x: contentView.bounds.origin.x, y: 0)
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
        blockItem?.textScrollViewDidChangeVisibleBounds()
    }

    private func shouldForwardVerticalScroll(_ event: NSEvent) -> Bool {
        guard !event.modifierFlags.contains(.shift) else {
            return false
        }
        let deltaY = abs(verticalScrollDelta(for: event))
        return deltaY > 0 && deltaY >= abs(horizontalRawScrollDelta(for: event))
    }

    private func scrollHorizontallyIfNeeded(for event: NSEvent) -> Bool {
        guard hasHorizontalScroller,
              let horizontalDelta = horizontalScrollDelta(for: event),
              let documentView else {
            return false
        }
        let maximumX = max(0, documentView.frame.width - contentView.bounds.width)
        guard maximumX > 0 else {
            return false
        }
        let proposedX = contentView.bounds.origin.x - horizontalDelta
        let clampedX = min(max(0, proposedX), maximumX)
        guard clampedX != contentView.bounds.origin.x else {
            return true
        }
        contentView.scroll(to: NSPoint(x: clampedX, y: 0))
        reflectScrolledClipView(contentView)
        blockItem?.textScrollViewDidChangeVisibleBounds()
        return true
    }

    private func horizontalScrollDelta(for event: NSEvent) -> CGFloat? {
        let deltaX = horizontalRawScrollDelta(for: event)
        let deltaY = verticalScrollDelta(for: event)
        let rawDelta: CGFloat
        if abs(deltaX) > abs(deltaY) {
            rawDelta = deltaX
        } else if event.modifierFlags.contains(.shift), abs(deltaY) > 0 {
            rawDelta = deltaY
        } else {
            return nil
        }
        if event.hasPreciseScrollingDeltas {
            return rawDelta
        }
        return rawDelta * max(horizontalLineScroll, 1)
    }

    private func shouldBreakVerticalSequenceForHorizontalScroll(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.shift) &&
            (abs(verticalScrollDelta(for: event)) > 0 || abs(horizontalRawScrollDelta(for: event)) > 0)
    }

    private func horizontalRawScrollDelta(for event: NSEvent) -> CGFloat {
        event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.deltaX
    }

    private func verticalScrollDelta(for event: NSEvent) -> CGFloat {
        event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
    }

    private func updateVerticalScrollSequenceState(after event: NSEvent) {
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) ||
            event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
            isForwardingVerticalScrollSequence = false
            verticalScrollSequenceToken = UUID()
        }
    }

    private func schedulePhaseLessVerticalScrollSequenceResetIfNeeded(for event: NSEvent) {
        guard event.phase == [], event.momentumPhase == [] else {
            return
        }
        let token = UUID()
        verticalScrollSequenceToken = token
        DispatchQueue.main.async { [weak self] in
            guard self?.verticalScrollSequenceToken == token else {
                return
            }
            self?.isForwardingVerticalScrollSequence = false
        }
    }

    private var verticalAncestorScrollView: NSScrollView? {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? NSScrollView,
               scrollView !== self,
               scrollView.hasVerticalScroller {
                return scrollView
            }
            candidate = view.superview
        }
        return nil
    }
}
