import AppKit

extension BlockInputTextView {
    override func cursorUpdate(with event: NSEvent) {
        if applyDetailButtonCursor(for: event) {
            return
        }
        if applyReadOnlyCursor(for: event) {
            return
        }
        if linkHitResult(for: event) != nil {
            NSCursor.pointingHand.set()
            return
        }
        if blockItem?.applyEditableTextSurfaceCursor(at: blockItem?.view.convert(event.locationInWindow, from: nil)) == true {
            return
        }
        super.cursorUpdate(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        if applyDetailButtonCursor(for: event) {
            return
        }
        if applyReadOnlyCursor(for: event) {
            return
        }
        if linkHitResult(for: event) != nil {
            NSCursor.pointingHand.set()
            return
        }
        if blockItem?.applyEditableTextSurfaceCursor(at: blockItem?.view.convert(event.locationInWindow, from: nil)) == true {
            return
        }
        super.mouseMoved(with: event)
    }

    @discardableResult
    func applyDetailButtonCursor(for event: NSEvent) -> Bool {
        guard let blockItem,
              let cursor = blockItem.detailButtonCursor else {
            return false
        }
        let point = blockItem.view.convert(event.locationInWindow, from: nil)
        guard blockItem.containsDetailButtonHitTarget(point) else {
            return false
        }
        cursor.set()
        return true
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
