import AppKit
import CoreGraphics
import Foundation

enum BlockInputVerticalMovementDirection: Equatable {
    case upward
    case downward
}

/// Logical Shift+Left/Right direction after AppKit key events are normalized.
enum BlockInputHorizontalMovementDirection: Equatable {
    case leftward
    case rightward
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
    func blockItemDidRevealReorderHandle(_ item: BlockInputBlockItem)
    func blockItemDidRequestSelectAll(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestUndoShortcut shortcut: BlockInputUndoShortcut
    ) -> Bool
    func blockItemDidRequestSelectHorizontalRule(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidRequestToggleChecklist(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
    func blockItemDidBeginReordering(_ item: BlockInputBlockItem, blockID: BlockInputBlockID)
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
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didDragSelectBlocksWith event: NSEvent,
        selectedRange: NSRange?
    ) -> Bool
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestExpandSelection direction: BlockInputVerticalMovementDirection,
        selectedRange: NSRange,
        preferredTextContainerX: CGFloat?
    ) -> Bool
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestExpandActiveBlockSelection direction: BlockInputVerticalMovementDirection
    ) -> Bool
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestHorizontalSelectionAdjustment direction: BlockInputHorizontalMovementDirection,
        selectedRange: NSRange
    ) -> Bool
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestCollapseSelection direction: BlockInputVerticalMovementDirection
    ) -> Bool
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestDocumentBoundary direction: BlockInputVerticalMovementDirection
    ) -> Bool
    func blockItemDidRequestCancelSelection(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
    func blockItemDidRequestMouseDownCancelSelection(_ item: BlockInputBlockItem, blockID: BlockInputBlockID) -> Bool
}
