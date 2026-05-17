import AppKit

extension BlockInputBlockItem {
    var reorderHandleCursor: NSCursor? {
        handleView.activeCursor
    }

    var reorderHandleCursorRect: NSRect {
        guard handleView.isEnabled,
              !handleView.isHidden else {
            return .zero
        }
        let hitRect = handleView.frame.insetBy(dx: -Self.handleHitOutset, dy: -Self.handleHitOutset)
        return hitRect.intersection(view.bounds)
    }

    func containsReorderHandleHitTarget(_ point: NSPoint) -> Bool {
        reorderHandleCursor != nil && reorderHandleCursorRect.contains(point)
    }
}
