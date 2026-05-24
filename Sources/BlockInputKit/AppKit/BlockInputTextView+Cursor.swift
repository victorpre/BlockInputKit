import AppKit

extension BlockInputTextView {
    override func cursorUpdate(with event: NSEvent) {
        if applyReadOnlyCursor(for: event) {
            return
        }
        super.cursorUpdate(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        if applyReadOnlyCursor(for: event) {
            return
        }
        super.mouseMoved(with: event)
    }

    @discardableResult
    func applyReadOnlyCursor(for event: NSEvent) -> Bool {
        guard let cursor = readOnlyCursor(for: event) else {
            return false
        }
        cursor.set()
        return true
    }

    func readOnlyCursor(for event: NSEvent) -> NSCursor? {
        guard blockItem?.isEditable == false else {
            return nil
        }
        if linkHitResult(for: event) != nil {
            return .pointingHand
        }
        guard let cursor = blockItem?.disabledCursorForReadOnly else {
            return nil
        }
        return cursor
    }
}
