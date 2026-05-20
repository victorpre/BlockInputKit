import AppKit

extension BlockInputView {
    nonisolated func removeNonisolatedEventMonitors() {
        if let selectionExpansionKeyMonitor {
            NSEvent.removeMonitor(selectionExpansionKeyMonitor)
        }
        if let linkModalMouseDownMonitor {
            NSEvent.removeMonitor(linkModalMouseDownMonitor)
        }
        if let completionPopupMouseDownMonitor {
            NSEvent.removeMonitor(completionPopupMouseDownMonitor)
        }
    }

    func installCompletionPopupDismissalMonitor() {
        removeCompletionPopupDismissalMonitor()
        completionPopupMouseDownMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp]
        ) { [weak self] event -> NSEvent? in
            self?.handleCompletionPopupMouseEvent(event) ?? event
        }
    }

    func removeCompletionPopupDismissalMonitor() {
        if let completionPopupMouseDownMonitor {
            NSEvent.removeMonitor(completionPopupMouseDownMonitor)
            self.completionPopupMouseDownMonitor = nil
        }
        completionPopupConsumesNextMouseUp = false
    }

    func handleCompletionPopupMouseEvent(_ event: NSEvent) -> NSEvent? {
        guard let popup = completionPopupView,
              eventBelongsToEditorWindow(event) else {
            return event
        }
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return handleCompletionPopupMouseDown(event, popup: popup)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return handleCompletionPopupMouseUp(event, popup: popup)
        default:
            return event
        }
    }

    func handleCompletionPopupMouseDown(_ event: NSEvent) -> NSEvent? {
        guard let popup = completionPopupView,
              eventBelongsToEditorWindow(event) else {
            return event
        }
        return handleCompletionPopupMouseDown(event, popup: popup)
    }

    private func handleCompletionPopupMouseDown(_ event: NSEvent, popup: BlockInputCompletionPopupView) -> NSEvent? {
        for windowPoint in completionMouseEventWindowPoints(event) {
            let locationInPopup = popup.convert(windowPoint, from: nil)
            guard popup.bounds.contains(locationInPopup) else {
                continue
            }
            // Consume the down/up pair so accepting a row cannot retarget the same click into the block underneath.
            completionPopupConsumesNextMouseUp = true
            _ = popup.routeMouseDown(at: locationInPopup, event: event)
            return nil
        }
        dismissCompletionPopup()
        return event
    }

    private func handleCompletionPopupMouseUp(_ event: NSEvent, popup: BlockInputCompletionPopupView) -> NSEvent? {
        guard completionPopupConsumesNextMouseUp else {
            return event
        }
        completionPopupConsumesNextMouseUp = false
        guard event.type == .leftMouseUp else {
            return nil
        }
        for windowPoint in completionMouseEventWindowPoints(event) {
            let locationInPopup = popup.convert(windowPoint, from: nil)
            guard popup.bounds.contains(locationInPopup) else {
                continue
            }
            _ = popup.routeMouseUp(at: locationInPopup, event: event)
            return nil
        }
        return nil
    }

    private func eventBelongsToEditorWindow(_ event: NSEvent) -> Bool {
        if let eventWindow = event.window {
            return eventWindow === window
        }
        return event.windowNumber == window?.windowNumber
    }

    private func completionMouseEventWindowPoints(_ event: NSEvent) -> [NSPoint] {
        guard let editorWindow = window,
              event.window === editorWindow || event.windowNumber == editorWindow.windowNumber else {
            return [event.locationInWindow]
        }
        let livePoint = editorWindow.mouseLocationOutsideOfEventStream
        guard livePoint != event.locationInWindow else {
            return [event.locationInWindow]
        }
        return [event.locationInWindow, livePoint]
    }
}
