import AppKit

/// Root view that owns row-level cursor rects and preserves first-click inline link routing.
final class BlockInputBlockItemRootView: NSView {
    weak var blockItem: BlockInputBlockItem?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        guard let event else {
            return false
        }
        return blockItem?.textView.linkHitResult(for: event) != nil
    }

    override func mouseDown(with event: NSEvent) {
        if blockItem?.textView.linkHitResult(for: event) != nil {
            blockItem?.textView.mouseDown(with: event)
            return
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let blockItem,
              let cursor = blockItem.reorderHandleCursor else {
            return
        }
        addCursorRect(blockItem.reorderHandleCursorRect, cursor: cursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let blockItem,
              let cursor = blockItem.reorderHandleCursor,
              blockItem.containsReorderHandleHitTarget(point) else {
            super.cursorUpdate(with: event)
            return
        }
        cursor.set()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        menu.blockInputPrependingTextFormattingItems(blockItem?.textFormattingContextMenuItems(for: event) ?? [])
        menu.blockInputPrependingLinkItems(blockItem?.linkContextMenuItems(
            for: event,
            selectedRange: blockItem?.currentSelectedRange ?? NSRange(location: 0, length: 0)
        ) ?? [])
        return menu.items.isEmpty ? nil : menu
    }
}
