import Foundation

extension BlockInputView {
    var blockCount: Int {
        documentStore?.blockCount ?? document.blocks.count
    }

    func block(at index: Int) -> BlockInputBlock? {
        guard let documentStore else {
            return document.blocks[safe: index]
        }
        return documentStore.block(at: index)
    }

    func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        guard let documentStore else {
            return document.block(withID: id)
        }
        return documentStore.block(withID: id)
    }

    func index(of id: BlockInputBlockID) -> Int? {
        guard let documentStore else {
            return document.index(of: id)
        }
        return documentStore.index(of: id)
    }

    func containsValidSelection(_ selection: BlockInputSelection) -> Bool {
        switch selection {
        case let .cursor(cursor):
            return containsValidCursor(cursor)
        case let .text(range):
            return containsValidTextRange(range)
        case let .blocks(blockIDs):
            return !blockIDs.isEmpty
                && Set(blockIDs).count == blockIDs.count
                && blockIDs.allSatisfy { index(of: $0) != nil }
        }
    }

    func containsValidCursor(_ cursor: BlockInputCursor) -> Bool {
        guard let block = block(withID: cursor.blockID) else {
            return false
        }
        return cursor.utf16Offset >= 0 && cursor.utf16Offset <= block.utf16Length
    }

    func containsValidTextRange(_ textRange: BlockInputTextRange) -> Bool {
        guard let block = block(withID: textRange.blockID),
              textRange.range.location >= 0,
              textRange.range.length >= 0 else {
            return false
        }
        return textRange.range.location <= block.utf16Length
            && textRange.range.length <= block.utf16Length - textRange.range.location
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
