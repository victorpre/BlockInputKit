import Foundation

extension BlockInputView {
    var blockCount: Int {
        documentStore?.loadedBlockCount ?? document.blocks.count
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
        case let .mixed(selection):
            let partialRanges = [selection.leadingTextRange, selection.trailingTextRange].compactMap { $0 }
            let allIDs = selection.blockIDs + partialRanges.map(\.blockID)
            let isStructurallyValid = !allIDs.isEmpty
                && Set(allIDs).count == allIDs.count
                && selection.blockIDs.allSatisfy { index(of: $0) != nil }
                && partialRanges.allSatisfy { $0.range.length > 0 && containsValidTextRange($0) }
            guard isStructurallyValid else {
                return false
            }
            return containsCanonicalMixedSelectionOrder(selection)
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

    private func containsCanonicalMixedSelectionOrder(_ selection: BlockInputMixedSelection) -> Bool {
        let wholeIndexes = selection.blockIDs.compactMap { index(of: $0) }.sorted()
        let leadingIndex = selection.leadingTextRange.flatMap { index(of: $0.blockID) }
        let trailingIndex = selection.trailingTextRange.flatMap { index(of: $0.blockID) }
        if let leadingIndex, let trailingIndex, leadingIndex >= trailingIndex {
            return false
        }
        let firstSelectionIndex = leadingIndex ?? wholeIndexes.first ?? trailingIndex
        let lastSelectionIndex = trailingIndex ?? wholeIndexes.last ?? leadingIndex
        guard let firstSelectionIndex, let lastSelectionIndex else {
            return false
        }
        let expectedWholeIndexes = (firstSelectionIndex...lastSelectionIndex).filter {
            $0 != leadingIndex && $0 != trailingIndex
        }
        return wholeIndexes == expectedWholeIndexes
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
