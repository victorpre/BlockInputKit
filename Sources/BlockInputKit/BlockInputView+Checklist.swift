import Foundation

public extension BlockInputView {
    /// Toggles the active checklist item, or a specific checklist item by ID.
    ///
    /// The edit is recorded on the structural undo stack because it changes block
    /// metadata rather than the block's owned text.
    @discardableResult
    func toggleChecklistItem(blockID: BlockInputBlockID? = nil) -> BlockInputSelection? {
        refreshDocumentFromStore()
        guard let targetBlockID = blockID ?? activeBlockID else {
            return nil
        }
        return performStructuralEdit(
            named: "Toggle Checklist",
            storeSyncAction: { _, afterDocument, _ in
                afterDocument.block(withID: targetBlockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
            },
            edit: { document in
                document.toggleChecklistItem(blockID: targetBlockID)
            }
        )
    }
}
