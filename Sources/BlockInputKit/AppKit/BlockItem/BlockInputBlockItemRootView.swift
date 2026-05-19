import AppKit

/// Root view that owns row-level cursor rects for the drag handle's expanded hit target.
final class BlockInputBlockItemRootView: NSView {
    weak var blockItem: BlockInputBlockItem?

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
        return menu.items.isEmpty ? nil : menu
    }
}
