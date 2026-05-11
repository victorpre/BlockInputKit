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
        guard let blockBeforeEdit = document.block(withID: blockID) else {
            return nil
        }
        let selectionBeforeEdit = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: min(proposedUTF16Offset, blockBeforeEdit.utf16Length)
        ))
        let undoSelectionBefore = validSelectionBeforeTypingShortcut(
            selectionBefore,
            blockBeforeEdit: blockBeforeEdit
        ) ?? selectionBeforeEdit
        return performStructuralEdit(
            named: "Format Block",
            selectionBeforeOverride: undoSelectionBefore,
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

private func validSelectionBeforeTypingShortcut(
    _ selection: BlockInputSelection?,
    blockBeforeEdit block: BlockInputBlock
) -> BlockInputSelection? {
    guard let selection else {
        return nil
    }
    switch selection {
    case let .cursor(cursor):
        guard cursor.blockID == block.id,
              cursor.utf16Offset >= 0,
              cursor.utf16Offset <= block.utf16Length else {
            return nil
        }
        return selection
    case let .text(textRange):
        guard textRange.blockID == block.id,
              textRange.range.location >= 0,
              textRange.range.length >= 0,
              textRange.range.location <= block.utf16Length,
              textRange.range.length <= block.utf16Length - textRange.range.location else {
            return nil
        }
        return selection
    case .blocks:
        return nil
    }
}
