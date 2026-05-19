import AppKit

extension BlockInputView {
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestPasteURL urlString: String,
        selectedRange: NSRange
    ) -> Bool {
        // The mounted text view sees paste first, so mirror its selection into the editor before mutating source.
        if selectedRange.length > 0 {
            applySelection(.text(BlockInputTextRange(blockID: blockID, range: selectedRange)), notify: false)
        } else {
            applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: selectedRange.location)), notify: false)
        }
        return pasteURLString(urlString, selectedRange: selectedRange)
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestLinkContextMenuItemsFor event: NSEvent,
        selectedRange: NSRange
    ) -> [NSMenuItem] {
        linkContextMenuItems(blockID: blockID, selectedRange: selectedRange, event: event)
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didClickLinkAt selectedRange: NSRange,
        event: NSEvent
    ) -> Bool {
        handleLinkClick(blockID: blockID, selectedRange: selectedRange, event: event)
    }
}
