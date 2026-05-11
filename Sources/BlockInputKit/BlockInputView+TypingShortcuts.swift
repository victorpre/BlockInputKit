import Foundation

extension BlockInputView {
    func applyTypingShortcutIfNeeded(
        blockID: BlockInputBlockID,
        proposedText: String,
        proposedUTF16Offset: Int,
        selectionBefore: BlockInputSelection?
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
            selectionBeforeOverride: selectionBefore,
            storeSyncAction: { _, afterDocument, _ in
                guard let block = afterDocument.block(withID: blockID),
                      block.kind != .horizontalRule else {
                    return .replaceDocument
                }
                return afterDocument.block(withID: blockID).map(StoreSyncAction.replaceBlock) ?? .replaceDocument
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
