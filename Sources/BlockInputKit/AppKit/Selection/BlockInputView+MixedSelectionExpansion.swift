import AppKit

extension BlockInputView {
    func promoteCaretSelectionAcrossBlockBoundary(
        from blockID: BlockInputBlockID,
        selectedRange: NSRange,
        currentBlock: BlockInputBlock,
        direction: BlockInputVerticalMovementDirection,
        preferredTextContainerX: CGFloat?
    ) -> Bool {
        guard let index = index(of: blockID) else {
            return false
        }
        let textLength = currentBlock.utf16Length
        let offset = min(max(selectedRange.location, 0), textLength)
        let isSingleLine = !currentBlock.text.contains(where: { $0 == "\n" || $0 == "\r" })
        let isDocumentBoundaryDirection = (direction == .upward && offset == 0) || (direction == .downward && offset == textLength)
        guard isSingleLine || isDocumentBoundaryDirection else {
            return false
        }
        switch direction {
        case .upward:
            return promoteCaretSelectionUpward(
                from: blockID,
                index: index,
                offset: offset,
                preferredTextContainerX: preferredTextContainerX
            )
        case .downward:
            return promoteCaretSelectionDownward(
                from: blockID,
                index: index,
                offset: offset,
                textLength: textLength,
                preferredTextContainerX: preferredTextContainerX
            )
        }
    }

    private func promoteCaretSelectionUpward(
        from blockID: BlockInputBlockID,
        index: Int,
        offset: Int,
        preferredTextContainerX: CGFloat?
    ) -> Bool {
        guard index > 0, let previousID = block(at: index - 1)?.id else {
            return false
        }
        if offset <= 0 {
            return applyPromotedSelection(.blocks([previousID]), anchorBlockID: blockID, direction: .upward, scrollIndex: index - 1)
        }
        let range = BlockInputTextRange(blockID: blockID, range: NSRange(location: 0, length: offset))
        let targetRange = partialTargetRange(
            for: previousID,
            at: index - 1,
            direction: .upward,
            preferredTextContainerX: preferredTextContainerX
        )
        return applyPromotedSelection(
            .mixed(BlockInputMixedSelection(
                blockIDs: targetRange == nil ? [previousID] : [],
                leadingTextRange: targetRange,
                trailingTextRange: range
            )),
            anchorBlockID: blockID,
            direction: .upward,
            scrollIndex: index - 1,
            preferredTextContainerX: preferredTextContainerX
        )
    }

    private func promoteCaretSelectionDownward(
        from blockID: BlockInputBlockID,
        index: Int,
        offset: Int,
        textLength: Int,
        preferredTextContainerX: CGFloat?
    ) -> Bool {
        guard index + 1 < blockCount, let nextID = block(at: index + 1)?.id else {
            return false
        }
        if offset >= textLength {
            return applyPromotedSelection(.blocks([nextID]), anchorBlockID: blockID, direction: .downward, scrollIndex: index + 1)
        }
        let range = BlockInputTextRange(blockID: blockID, range: NSRange(location: offset, length: textLength - offset))
        let targetRange = partialTargetRange(
            for: nextID,
            at: index + 1,
            direction: .downward,
            preferredTextContainerX: preferredTextContainerX
        )
        return applyPromotedSelection(
            .mixed(BlockInputMixedSelection(
                blockIDs: targetRange == nil ? [nextID] : [],
                leadingTextRange: range,
                trailingTextRange: targetRange
            )),
            anchorBlockID: blockID,
            direction: .downward,
            scrollIndex: index + 1,
            preferredTextContainerX: preferredTextContainerX
        )
    }

    func expandMixedSelectionContinuing(
        _ mixedSelection: BlockInputMixedSelection,
        expandedBounds: ClosedRange<Int>,
        direction: BlockInputVerticalMovementDirection
    ) -> Bool {
        // When selection started inside a block, the active edge crosses block boundaries at a stable X position.
        // The old partial endpoint becomes a whole middle block only after the next Shift+Arrow continues past it.
        var blockIDs = mixedSelection.blockIDs
        var leadingTextRange = mixedSelection.leadingTextRange
        var trailingTextRange = mixedSelection.trailingTextRange
        let preferredTextContainerX = preferredNavigationX
        let targetIndex = direction == .upward ? expandedBounds.lowerBound : expandedBounds.upperBound
        guard let targetID = block(at: targetIndex)?.id else {
            return false
        }

        switch direction {
        case .upward:
            if let leadingBlockID = leadingTextRange?.blockID, !blockIDs.contains(leadingBlockID) {
                blockIDs.append(leadingBlockID)
            }
            leadingTextRange = partialTargetRange(
                for: targetID,
                at: targetIndex,
                direction: direction,
                preferredTextContainerX: preferredTextContainerX
            )
            if leadingTextRange == nil, !blockIDs.contains(targetID) {
                blockIDs.append(targetID)
            }
        case .downward:
            if let trailingBlockID = trailingTextRange?.blockID, !blockIDs.contains(trailingBlockID) {
                blockIDs.append(trailingBlockID)
            }
            trailingTextRange = partialTargetRange(
                for: targetID,
                at: targetIndex,
                direction: direction,
                preferredTextContainerX: preferredTextContainerX
            )
            if trailingTextRange == nil, !blockIDs.contains(targetID) {
                blockIDs.append(targetID)
            }
        }

        applySelection(.mixed(BlockInputMixedSelection(
            blockIDs: blockIDs.sortedByDocumentOrder(in: self),
            leadingTextRange: leadingTextRange,
            trailingTextRange: trailingTextRange
        )), notify: true)
        preferredNavigationX = preferredTextContainerX
        scrollBlockSelectionBoundaryToVisible(targetIndex)
        window?.makeFirstResponder(self)
        publishFocusChange(true)
        return true
    }

    func partialTargetRange(
        for blockID: BlockInputBlockID,
        at index: Int,
        direction: BlockInputVerticalMovementDirection,
        preferredTextContainerX: CGFloat?
    ) -> BlockInputTextRange? {
        // Mirror NSTextView vertical selection: the newly crossed block is selected only up to the caret's X position.
        guard let block = block(at: index),
              block.id == blockID,
              block.kind != .horizontalRule else {
            return nil
        }
        let targetItem = visibleItem(for: blockID)
        let linePosition: BlockInputBlockItem.TextLinePosition = direction == .upward ? .last : .first
        let offset = targetItem?.utf16Offset(
            closestToTextContainerX: preferredTextContainerX,
            linePosition: linePosition
        ) ?? (direction == .upward ? block.utf16Length : 0)
        let range: NSRange
        switch direction {
        case .upward:
            range = NSRange(location: offset, length: block.utf16Length - offset)
        case .downward:
            range = NSRange(location: 0, length: offset)
        }
        guard range.length > 0 else {
            return nil
        }
        return BlockInputTextRange(blockID: blockID, range: range)
    }
}

private extension Array where Element == BlockInputBlockID {
    @MainActor
    func sortedByDocumentOrder(in view: BlockInputView) -> [BlockInputBlockID] {
        sorted { lhs, rhs in
            (view.index(of: lhs) ?? Int.max) < (view.index(of: rhs) ?? Int.max)
        }
    }
}
