import CoreGraphics
import Foundation

enum BlockInputVerticalMovementDirection: Equatable {
    case upward
    case downward
}

@MainActor
protocol BlockInputBlockItemDelegate: AnyObject {
    func blockItemDidBeginEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidEndEditing(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didChangeText text: String,
        selectionBefore: BlockInputSelection?
    )
    func blockItem(_ item: BlockInputBlockItem, didChangeSelectionIn blockID: BlockInputBlockID)
    func blockItemDidRequestReturn(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestMergeWithPreviousBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestDeleteEmptyBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestUnwrapBlock(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestSelectAll(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestUndoShortcut shortcut: BlockInputUndoShortcut
    ) -> Bool
    func blockItemDidRequestSelectHorizontalRule(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestToggleChecklist(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestIndent(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        selectedRange: NSRange
    )
    func blockItemDidRequestOutdent(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        selectedRange: NSRange
    )
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestVerticalMovement direction: BlockInputVerticalMovementDirection,
        preferredTextContainerX: CGFloat?
    ) -> Bool
}
