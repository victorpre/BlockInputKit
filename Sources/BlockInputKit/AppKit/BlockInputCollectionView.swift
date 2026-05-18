import AppKit

/// Collection view hook that clears editor drag state when AppKit ends a drag outside delegate callbacks.
final class BlockInputCollectionView: NSCollectionView {
    weak var blockInputView: BlockInputView?
    private weak var blockSelectionDragItem: BlockInputBlockItem?

    override func layout() {
        super.layout()
        blockInputView?.scheduleProgressivePreloadCheck()
    }

    override func mouseDown(with event: NSEvent) {
        blockSelectionDragItem = itemForBlockSelectionDrag(at: event.locationInWindow)
        blockSelectionDragItem?.beginBlockSelectionDrag()
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let blockSelectionDragItem,
              blockSelectionDragItem.updateBlockSelectionDrag(with: event) else {
            super.mouseDragged(with: event)
            return
        }
    }

    override func mouseUp(with event: NSEvent) {
        blockSelectionDragItem?.finishBlockSelectionDrag()
        blockSelectionDragItem = nil
        super.mouseUp(with: event)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        super.draggingExited(sender)
        blockInputView?.hideDropIndicator()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        super.draggingEnded(sender)
        blockInputView?.hideDropIndicator()
    }

    private func itemForBlockSelectionDrag(at windowLocation: NSPoint) -> BlockInputBlockItem? {
        let location = convert(windowLocation, from: nil)
        guard let indexPath = indexPathForItem(at: location),
              let item = item(at: indexPath) as? BlockInputBlockItem else {
            return nil
        }
        return item
    }
}
