import AppKit

extension BlockInputView {
    func handleWordMovementShortcut(_ event: NSEvent) -> Bool {
        guard let direction = event.blockInputWordMovementDirection else {
            return false
        }
        if window?.firstResponder is BlockInputTextView {
            return false
        }
        return moveWordFromCurrentSelection(direction)
    }

    func handleWordMovementCommand(_ selector: Selector) -> Bool {
        guard !(window?.firstResponder is BlockInputTextView) else {
            return false
        }
        switch selector {
        case #selector(NSResponder.moveWordLeft(_:)),
             #selector(NSResponder.moveWordBackward(_:)):
            return moveWordFromCurrentSelection(.leftward)
        case #selector(NSResponder.moveWordRight(_:)),
             #selector(NSResponder.moveWordForward(_:)):
            return moveWordFromCurrentSelection(.rightward)
        default:
            return false
        }
    }

    func moveWord(
        from blockID: BlockInputBlockID,
        selectedRange: NSRange,
        direction: BlockInputWordMovementDirection
    ) -> Bool {
        refreshDocumentFromStore()
        guard let index = index(of: blockID),
              let block = block(at: index),
              selectedRange.length == 0 else {
            return false
        }
        let offset = min(max(selectedRange.location, 0), block.utf16Length)
        switch direction {
        case .leftward:
            guard offset <= 0 else {
                return false
            }
        case .rightward:
            guard offset >= block.utf16Length else {
                return false
            }
        }
        return moveWordToAdjacentBlock(from: index, direction: direction)
    }

    private func moveWordFromCurrentSelection(_ direction: BlockInputWordMovementDirection) -> Bool {
        refreshDocumentFromStore()
        guard let boundary = wordMovementBoundary(for: direction),
              let index = index(of: boundary.blockID),
              let block = block(at: index) else {
            return false
        }
        guard block.kind != .horizontalRule else {
            return moveWordToAdjacentBlock(from: index, direction: direction)
        }
        let offset = min(max(boundary.utf16Offset, 0), block.utf16Length)
        if canMoveWordWithinBlock(block, from: offset, direction: direction) {
            focusAndMoveWord(block: block, initialUTF16Offset: offset, direction: direction)
            return true
        }
        return moveWordToAdjacentBlock(from: index, direction: direction)
    }

    private func moveWordToAdjacentBlock(
        from index: Int,
        direction: BlockInputWordMovementDirection
    ) -> Bool {
        let targetIndex = direction == .leftward ? index - 1 : index + 1
        guard let targetBlock = block(at: targetIndex) else {
            return false
        }
        if targetBlock.kind == .horizontalRule {
            selectHorizontalRuleForWordMovement(targetBlock, at: targetIndex)
            return true
        }
        let offset = direction == .leftward ? targetBlock.utf16Length : 0
        focusAndMoveWord(block: targetBlock, initialUTF16Offset: offset, direction: direction)
        return true
    }

    private func canMoveWordWithinBlock(
        _ block: BlockInputBlock,
        from offset: Int,
        direction: BlockInputWordMovementDirection
    ) -> Bool {
        switch direction {
        case .leftward:
            return offset > 0
        case .rightward:
            return offset < block.utf16Length
        }
    }

    private func focusAndMoveWord(
        block: BlockInputBlock,
        initialUTF16Offset offset: Int,
        direction: BlockInputWordMovementDirection
    ) {
        blockSelectionExpansion = nil
        horizontalSelectionExpansion = nil
        preferredNavigationX = nil
        guard let item = visibleItem(for: block.id) else {
            focus(blockID: block.id, utf16Offset: offset)
            return
        }
        let selectedRange = item.focusAndMoveWord(initialUTF16Offset: offset, direction: direction)
        applySelection(
            .cursor(BlockInputCursor(blockID: block.id, utf16Offset: selectedRange.location)),
            notify: true
        )
    }

    private func selectHorizontalRuleForWordMovement(_ block: BlockInputBlock, at index: Int) {
        selectedHorizontalRuleIndex = index
        blockSelectionExpansion = nil
        horizontalSelectionExpansion = nil
        preferredNavigationX = nil
        applySelection(.blocks([block.id]), notify: true)
        if let item = visibleItem(for: block.id, refreshConfiguration: false) {
            selectOnlyVisibleBlockItem(item)
        }
        window?.makeFirstResponder(self)
        publishFocusChange(true)
    }

    private func wordMovementBoundary(for direction: BlockInputWordMovementDirection) -> BlockInputDocumentTextBoundary? {
        switch selection {
        case let .cursor(cursor):
            return BlockInputDocumentTextBoundary(blockID: cursor.blockID, utf16Offset: cursor.utf16Offset)
        case let .text(textRange):
            let offset = direction == .leftward ? textRange.range.location : NSMaxRange(textRange.range)
            return BlockInputDocumentTextBoundary(blockID: textRange.blockID, utf16Offset: offset)
        case let .blocks(blockIDs):
            return wordMovementBoundary(forWholeBlockIDs: blockIDs, direction: direction)
        case let .mixed(selection):
            return wordMovementBoundary(forMixedSelection: selection, direction: direction)
        case nil:
            return nil
        }
    }

    private func wordMovementBoundary(
        forWholeBlockIDs blockIDs: [BlockInputBlockID],
        direction: BlockInputWordMovementDirection
    ) -> BlockInputDocumentTextBoundary? {
        let indexes = blockIDs.compactMap { index(of: $0) }.sorted()
        guard let boundaryIndex = direction == .leftward ? indexes.first : indexes.last,
              let block = block(at: boundaryIndex) else {
            return nil
        }
        let offset = direction == .leftward ? 0 : block.utf16Length
        return BlockInputDocumentTextBoundary(blockID: block.id, utf16Offset: offset)
    }

    private func wordMovementBoundary(
        forMixedSelection selection: BlockInputMixedSelection,
        direction: BlockInputWordMovementDirection
    ) -> BlockInputDocumentTextBoundary? {
        let candidates = mixedWordMovementBoundaryCandidates(selection)
        guard let boundary = direction == .leftward
            ? candidates.min(by: isEarlierWordMovementCandidate)
            : candidates.max(by: isEarlierWordMovementCandidate) else {
            return nil
        }
        return boundary.boundary
    }

    private func mixedWordMovementBoundaryCandidates(
        _ selection: BlockInputMixedSelection
    ) -> [(index: Int, boundary: BlockInputDocumentTextBoundary)] {
        var candidates: [(index: Int, boundary: BlockInputDocumentTextBoundary)] = []
        for blockID in selection.blockIDs {
            guard let index = index(of: blockID),
                  let block = block(at: index) else {
                continue
            }
            candidates.append((
                index,
                BlockInputDocumentTextBoundary(blockID: blockID, utf16Offset: 0)
            ))
            candidates.append((
                index,
                BlockInputDocumentTextBoundary(blockID: blockID, utf16Offset: block.utf16Length)
            ))
        }
        if let range = selection.leadingTextRange,
           let index = index(of: range.blockID) {
            candidates.append((
                index,
                BlockInputDocumentTextBoundary(blockID: range.blockID, utf16Offset: range.range.location)
            ))
            candidates.append((
                index,
                BlockInputDocumentTextBoundary(blockID: range.blockID, utf16Offset: NSMaxRange(range.range))
            ))
        }
        if let range = selection.trailingTextRange,
           let index = index(of: range.blockID) {
            candidates.append((
                index,
                BlockInputDocumentTextBoundary(blockID: range.blockID, utf16Offset: range.range.location)
            ))
            candidates.append((
                index,
                BlockInputDocumentTextBoundary(blockID: range.blockID, utf16Offset: NSMaxRange(range.range))
            ))
        }
        return candidates
    }

    private func isEarlierWordMovementCandidate(
        _ lhs: (index: Int, boundary: BlockInputDocumentTextBoundary),
        _ rhs: (index: Int, boundary: BlockInputDocumentTextBoundary)
    ) -> Bool {
        lhs.index < rhs.index ||
            (lhs.index == rhs.index && lhs.boundary.utf16Offset < rhs.boundary.utf16Offset)
    }

}

extension BlockInputWordMovementDirection {
    var debugName: String {
        switch self {
        case .leftward:
            return "left"
        case .rightward:
            return "right"
        }
    }
}
