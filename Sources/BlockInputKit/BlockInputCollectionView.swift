import AppKit

/// Collection view hook that clears editor drag state when AppKit ends a drag outside delegate callbacks.
final class BlockInputCollectionView: NSCollectionView {
    weak var blockInputView: BlockInputView?

    override func draggingExited(_ sender: NSDraggingInfo?) {
        super.draggingExited(sender)
        blockInputView?.hideDropIndicator()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        super.draggingEnded(sender)
        blockInputView?.hideDropIndicator()
    }
}
