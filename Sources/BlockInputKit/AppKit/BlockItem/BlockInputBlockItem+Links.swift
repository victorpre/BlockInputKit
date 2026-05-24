import AppKit

extension BlockInputBlockItem {
    /// Asks the editor to handle URL paste so source mutation, selection, and undo stay editor-owned.
    func requestPasteURL(_ urlString: String, selectedRange: NSRange) -> Bool {
        guard isEditable,
              let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestPasteURL: urlString,
            selectedRange: selectedRange
        ) ?? false
    }

    /// Asks the editor to handle local file drops so source mutation, selection, and undo stay editor-owned.
    func requestInsertFileURLs(_ fileURLs: [URL], atUTF16Offset utf16Offset: Int) -> Bool {
        guard isEditable,
              let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestInsertFileURLs: fileURLs,
            atUTF16Offset: utf16Offset
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
    func requestLinkClick(
        selectedRange: NSRange,
        clickedLinkRange: BlockInputInlineMarkdownRange?,
        event: NSEvent
    ) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didClickLinkAt: selectedRange,
            clickedLinkRange: clickedLinkRange,
            event: event
        ) ?? false
    }

    func inlineChipRange(atWindowLocation windowLocation: NSPoint) -> BlockInputInlineMarkdownRange? {
        textView.inlineChipRange(atWindowLocation: windowLocation)
    }
}
