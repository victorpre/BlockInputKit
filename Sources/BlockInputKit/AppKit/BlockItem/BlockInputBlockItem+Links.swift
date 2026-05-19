import AppKit

extension BlockInputBlockItem {
    /// Asks the editor to handle URL paste so source mutation, selection, and undo stay editor-owned.
    func requestPasteURL(_ urlString: String, selectedRange: NSRange) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestPasteURL: urlString,
            selectedRange: selectedRange
        ) ?? false
    }

    /// Builds link menu items from the editor because the decision depends on global selection state and block source.
    func linkContextMenuItems(for event: NSEvent, selectedRange: NSRange) -> [NSMenuItem] {
        guard let blockID else {
            return []
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestLinkContextMenuItemsFor: event,
            selectedRange: selectedRange
        ) ?? []
    }

    /// Routes link clicks through the editor so plain-click editing and command-click opening share validation.
    func requestLinkClick(selectedRange: NSRange, event: NSEvent) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didClickLinkAt: selectedRange,
            event: event
        ) ?? false
    }
}
