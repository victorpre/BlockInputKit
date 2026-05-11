import AppKit
@testable import BlockInputKit

@MainActor
func makeMountedBlockInputView(configuration: BlockInputConfiguration) -> (view: BlockInputView, window: NSWindow) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let view = BlockInputView(frame: window.contentView?.bounds ?? window.frame)
    window.contentView = view
    view.configure(configuration)
    view.layoutSubtreeIfNeeded()
    view.collectionView.layoutSubtreeIfNeeded()
    return (view, window)
}

@MainActor
func makeMountedBlockInputView(
    document: BlockInputDocument,
    undoController: BlockInputUndoController = BlockInputUndoController()
) -> (view: BlockInputView, window: NSWindow) {
    makeMountedBlockInputView(configuration: BlockInputConfiguration(
        document: document,
        undoController: undoController
    ))
}

@MainActor
func makeMountedBlockInputView(blocks: [BlockInputBlock]) -> (view: BlockInputView, window: NSWindow) {
    makeMountedBlockInputView(document: BlockInputDocument(blocks: blocks))
}

extension BlockInputView {
    func visibleBlockItemForTesting(at item: Int) -> BlockInputBlockItem? {
        collectionView.scrollToItems(at: [IndexPath(item: item, section: 0)], scrollPosition: .nearestVerticalEdge)
        collectionView.layoutSubtreeIfNeeded()
        return collectionView.item(at: IndexPath(item: item, section: 0)) as? BlockInputBlockItem
    }
}
