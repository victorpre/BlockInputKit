import Foundation

extension BlockInputView {
    func applyTypingShortcutIfNeeded(
        blockID: BlockInputBlockID,
        proposedText: String,
        proposedUTF16Offset: Int
    ) -> BlockInputSelection? {
        guard let shortcut = document.typingShortcut(
            for: blockID,
            proposedText: proposedText,
            proposedUTF16Offset: proposedUTF16Offset
        ) else {
            return nil
        }
        return performStructuralEdit(
            named: "Format Block",
            storeSyncAction: { _, afterDocument, _ in
                afterDocument.block(withID: blockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
            },
            edit: { document in
                document.applyTypingShortcut(blockID: blockID, shortcut: shortcut)
            }
        )
    }

    func unwrapBlockToParagraph(blockID: BlockInputBlockID) -> BlockInputSelection? {
        performStructuralEdit(
            named: "Unformat Block",
            storeSyncAction: { _, afterDocument, _ in
                afterDocument.block(withID: blockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
            },
            edit: { document in
                document.unwrapBlockToParagraph(blockID: blockID)
            }
        )
    }
}
