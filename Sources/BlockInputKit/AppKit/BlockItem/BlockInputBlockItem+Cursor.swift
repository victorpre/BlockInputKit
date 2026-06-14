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

    var detailButtonCursor: NSCursor? {
        detailButton.activeCursor
    }

    var detailButtonCursorRect: NSRect {
        guard !detailButton.isHidden,
              detailButton.alphaValue > 0 else {
            return .zero
        }
        return detailButton.frame.intersection(view.bounds)
    }

    func editableTextSurfaceCursorRects(in hostView: NSView) -> [NSRect] {
        guard usesEditableTextSurfaceCursor else {
            return []
        }
        let hostBounds = hostView.bounds
        guard !hostBounds.isEmpty else {
            return []
        }
        let detailButtonRect = hostView.convert(detailButtonCursorRect, from: view).intersection(hostBounds)
        return hostBounds.subtracting(detailButtonRect)
    }

    func containsDetailButtonHitTarget(_ point: NSPoint) -> Bool {
        detailButtonCursor != nil && detailButtonCursorRect.contains(point)
    }

    var usesEditableTextSurfaceCursor: Bool {
        guard isEditable,
              renderedBlock?.kind != .horizontalRule,
              !isImageBlock,
              tableView.isHidden else {
            return false
        }
        return true
    }

    func addEditableTextSurfaceCursorRectIfNeeded(to view: NSView) {
        editableTextSurfaceCursorRects(in: view).forEach { cursorRect in
            view.addCursorRect(cursorRect, cursor: .iBeam)
        }
    }

    func applyEditableTextSurfaceCursor(at point: NSPoint?) -> Bool {
        guard usesEditableTextSurfaceCursor else {
            return false
        }
        if let point {
            if containsReorderHandleHitTarget(point) || containsDetailButtonHitTarget(point) {
                return false
            }
        }
        NSCursor.iBeam.set()
        return true
    }

    @discardableResult
    func routeEditableTextSurfaceMouseDown(_ event: NSEvent, atRootPoint point: NSPoint? = nil) -> Bool {
        guard usesEditableTextSurfaceCursor else {
            return false
        }
        if let point, containsReorderHandleHitTarget(point) || containsDetailButtonHitTarget(point) {
            return false
        }
        textView.mouseDown(with: event)
        return true
    }
}

private extension NSRect {
    func subtracting(_ exclusion: NSRect) -> [NSRect] {
        let clippedExclusion = intersection(exclusion)
        guard !isEmpty else {
            return []
        }
        guard !clippedExclusion.isEmpty else {
            return [self]
        }

        var rects: [NSRect] = []

        if clippedExclusion.minY > minY {
            rects.append(NSRect(
                x: minX,
                y: minY,
                width: width,
                height: clippedExclusion.minY - minY
            ))
        }

        if clippedExclusion.maxY < maxY {
            rects.append(NSRect(
                x: minX,
                y: clippedExclusion.maxY,
                width: width,
                height: maxY - clippedExclusion.maxY
            ))
        }

        let middleHeight = clippedExclusion.height
        if clippedExclusion.minX > minX {
            rects.append(NSRect(
                x: minX,
                y: clippedExclusion.minY,
                width: clippedExclusion.minX - minX,
                height: middleHeight
            ))
        }

        if clippedExclusion.maxX < maxX {
            rects.append(NSRect(
                x: clippedExclusion.maxX,
                y: clippedExclusion.minY,
                width: maxX - clippedExclusion.maxX,
                height: middleHeight
            ))
        }

        return rects.filter { !$0.isEmpty }
    }
}
