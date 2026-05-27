import AppKit

/// Vertical-only editor scroll owner. Nested block views may scroll horizontally, but the document clip view must not.
final class BlockInputDocumentScrollView: NSScrollView {
    var onContentBoundsDidChange: (() -> Void)?
    weak var blockInputView: BlockInputView?

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

    private func configureBoundsObservation() {
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        blockInputView?.addDisabledCursorRectIfNeeded(to: self)
    }

    override func layout() {
        super.layout()
        blockInputView?.updateCollectionViewWidthForVisibleBounds()
        blockInputView?.clampVerticalScrollOffsetIfNeeded()
    }

    @objc
    private func contentBoundsDidChange() {
        defer {
            onContentBoundsDidChange?()
        }
        guard contentView.bounds.origin.x != 0 else {
            return
        }
        contentView.scroll(to: NSPoint(x: 0, y: contentView.bounds.origin.y))
        reflectScrolledClipView(contentView)
    }
}
