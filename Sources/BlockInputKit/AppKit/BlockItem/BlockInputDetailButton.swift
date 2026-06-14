import AppKit

final class BlockInputDetailButton: NSButton {
    var activeCursor: NSCursor? {
        !isHidden && alphaValue > 0 ? .pointingHand : nil
    }

    override var isHidden: Bool {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let activeCursor else { return }
        addCursorRect(bounds, cursor: activeCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        guard let activeCursor else {
            super.cursorUpdate(with: event)
            return
        }
        activeCursor.set()
    }
}
