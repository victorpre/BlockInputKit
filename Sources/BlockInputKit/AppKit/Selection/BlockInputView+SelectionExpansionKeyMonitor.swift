import AppKit

extension BlockInputView {
    func installSelectionExpansionKeyMonitor() {
        selectionExpansionKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.isArrowKey {
                let responder = String(describing: self?.window?.firstResponder.map { type(of: $0) })
                BlockInputSelectionDebug.emit(
                    "monitor key=\(event.debugKeyName) modifiers=\(event.debugModifierNames) responder=\(responder)"
                )
            }
            guard let self,
                  isEditorFirstResponder,
                  handleSelectionExpansionKeyEvent(event) || handleHorizontalSelectionAdjustmentKeyEvent(event) else {
                if event.isArrowKey {
                    BlockInputSelectionDebug.emit("monitor pass selection=\(String(describing: self?.selection))")
                }
                return event
            }
            BlockInputSelectionDebug.emit("monitor consumed selection=\(String(describing: selection))")
            return nil
        }
    }
}
