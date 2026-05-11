import Foundation

@MainActor
protocol BlockInputBlockItemDelegate: AnyObject {
    func blockItemDidBeginEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didChangeText text: String,
        selectionBefore: BlockInputSelection?
    )
    func blockItem(_ item: BlockInputBlockItem, didChangeSelectionIn blockID: BlockInputBlockID)
    func blockItemDidRequestReturn(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestDeleteEmptyBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestSelectAll(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestIndent(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestOutdent(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestMoveToPreviousBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestMoveToNextBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
}
