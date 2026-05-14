import AppKit

extension BlockInputView {
    func contractSelectionIfNeeded(
        direction: BlockInputVerticalMovementDirection,
        firstIndex: Int,
        lastIndex: Int
    ) -> Bool {
        guard let expansion = blockSelectionExpansion,
              expansion.direction != direction,
              let anchorIndex = index(of: expansion.anchorBlockID) else {
            return false
        }
        if firstIndex...lastIndex ~= anchorIndex {
            switch selection {
            case .blocks:
                return shrinkBlockSelection(
                    anchorIndex: anchorIndex,
                    direction: expansion.direction,
                    firstIndex: firstIndex,
                    lastIndex: lastIndex
                )
            case let .mixed(mixedSelection):
                return shrinkMixedSelection(mixedSelection, direction: expansion.direction, anchorIndex: anchorIndex)
            case .cursor, .text, nil:
                return false
            }
        }
        return restoreExcludedAnchorSelectionIfNeeded(
            anchorIndex: anchorIndex,
            direction: expansion.direction,
            firstIndex: firstIndex,
            lastIndex: lastIndex
        )
    }

    private func shrinkBlockSelection(
        anchorIndex: Int,
        direction: BlockInputVerticalMovementDirection,
        firstIndex: Int,
        lastIndex: Int
    ) -> Bool {
        let shrunkenBounds: ClosedRange<Int>
        switch direction {
        case .upward:
            guard firstIndex < anchorIndex else {
                return restoreAnchorTextSelection(at: anchorIndex, direction: direction)
            }
            shrunkenBounds = (firstIndex + 1)...lastIndex
        case .downward:
            guard anchorIndex < lastIndex else {
                return restoreAnchorTextSelection(at: anchorIndex, direction: direction)
            }
            shrunkenBounds = firstIndex...(lastIndex - 1)
        }
        guard shrunkenBounds.lowerBound != shrunkenBounds.upperBound else {
            return restoreAnchorTextSelection(at: anchorIndex, direction: direction)
        }
        let selectedIDs = shrunkenBounds.compactMap { block(at: $0)?.id }
        guard !selectedIDs.isEmpty else {
            return false
        }
        applySelection(.blocks(selectedIDs), notify: true)
        scrollBlockSelectionBoundaryToVisible(direction == .upward ? shrunkenBounds.lowerBound : shrunkenBounds.upperBound)
        window?.makeFirstResponder(self)
        publishFocusChange(true)
        return true
    }

    private func shrinkMixedSelection(
        _ selection: BlockInputMixedSelection,
        direction: BlockInputVerticalMovementDirection,
        anchorIndex: Int
    ) -> Bool {
        let sortedBlockIDs = selection.blockIDs.sorted { lhs, rhs in
            (index(of: lhs) ?? Int.max) < (index(of: rhs) ?? Int.max)
        }
        guard !sortedBlockIDs.isEmpty else {
            return restoreMixedAnchorTextSelection(selection, direction: direction, anchorIndex: anchorIndex)
        }

        let blockIDToRemove = direction == .upward ? sortedBlockIDs.first : sortedBlockIDs.last
        guard let blockIDToRemove,
              let removedIndex = index(of: blockIDToRemove) else {
            return false
        }
        let remainingBlockIDs = sortedBlockIDs.filter { $0 != blockIDToRemove }
        let nextSelection = mixedSelectionAfterDemotingActiveEdge(
            selection,
            direction: direction,
            removedBlockID: blockIDToRemove,
            removedIndex: removedIndex,
            remainingBlockIDs: remainingBlockIDs
        )
        guard !remainingBlockIDs.isEmpty else {
            if nextSelection.hasPartialTextRange {
                return applyContractedMixedSelection(nextSelection, scrollIndex: removedIndex)
            }
            return restoreMixedAnchorTextSelection(selection, direction: direction, anchorIndex: anchorIndex)
        }

        return applyContractedMixedSelection(nextSelection, scrollIndex: removedIndex)
    }

    private func mixedSelectionAfterDemotingActiveEdge(
        _ selection: BlockInputMixedSelection,
        direction: BlockInputVerticalMovementDirection,
        removedBlockID: BlockInputBlockID,
        removedIndex: Int,
        remainingBlockIDs: [BlockInputBlockID]
    ) -> BlockInputMixedSelection {
        switch direction {
        case .upward:
            let leadingTextRange = selection.leadingTextRange == nil ? nil : partialTargetRange(
                for: removedBlockID,
                at: removedIndex,
                direction: .upward,
                preferredTextContainerX: preferredNavigationX
            )
            return BlockInputMixedSelection(
                blockIDs: remainingBlockIDs,
                leadingTextRange: leadingTextRange,
                trailingTextRange: selection.trailingTextRange
            )
        case .downward:
            let trailingTextRange = selection.trailingTextRange == nil ? nil : partialTargetRange(
                for: removedBlockID,
                at: removedIndex,
                direction: .downward,
                preferredTextContainerX: preferredNavigationX
            )
            return BlockInputMixedSelection(
                blockIDs: remainingBlockIDs,
                leadingTextRange: selection.leadingTextRange,
                trailingTextRange: trailingTextRange
            )
        }
    }

    private func applyContractedMixedSelection(_ selection: BlockInputMixedSelection, scrollIndex: Int) -> Bool {
        let preferredTextContainerX = preferredNavigationX
        applySelection(.mixed(selection), notify: true)
        preferredNavigationX = preferredTextContainerX
        scrollBlockSelectionBoundaryToVisible(scrollIndex)
        window?.makeFirstResponder(self)
        publishFocusChange(true)
        return true
    }

    private func restoreMixedAnchorTextSelection(
        _ selection: BlockInputMixedSelection,
        direction: BlockInputVerticalMovementDirection,
        anchorIndex: Int
    ) -> Bool {
        let textRange = direction == .upward ? selection.trailingTextRange : selection.leadingTextRange
        guard let textRange else {
            return restoreAnchorTextSelection(at: anchorIndex, direction: direction)
        }
        applySelection(.text(textRange), notify: true)
        restoreVisibleTextSelection(textRange)
        blockSelectionExpansion = BlockInputBlockSelectionExpansion(anchorBlockID: textRange.blockID, direction: direction)
        publishFocusChange(true)
        return true
    }

    private func restoreExcludedAnchorSelectionIfNeeded(
        anchorIndex: Int,
        direction: BlockInputVerticalMovementDirection,
        firstIndex: Int,
        lastIndex: Int
    ) -> Bool {
        switch direction {
        case .upward:
            guard lastIndex + 1 == anchorIndex else {
                return false
            }
            return restoreAnchorCursorSelection(at: anchorIndex, direction: direction)
        case .downward:
            guard firstIndex - 1 == anchorIndex else {
                return false
            }
            return restoreAnchorCursorSelection(at: anchorIndex, direction: direction)
        }
    }

    private func restoreAnchorCursorSelection(at anchorIndex: Int, direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let block = block(at: anchorIndex),
              block.kind != .horizontalRule else {
            return false
        }
        let cursor = BlockInputCursor(
            blockID: block.id,
            utf16Offset: direction == .upward ? 0 : block.utf16Length
        )
        applySelection(.cursor(cursor), notify: true)
        focusVisibleItem(for: cursor)
        blockSelectionExpansion = nil
        publishFocusChange(true)
        return true
    }

    private func restoreAnchorTextSelection(at anchorIndex: Int, direction: BlockInputVerticalMovementDirection) -> Bool {
        guard let block = block(at: anchorIndex),
              block.kind != .horizontalRule else {
            return false
        }
        let textRange = BlockInputTextRange(
            blockID: block.id,
            range: NSRange(location: 0, length: block.utf16Length)
        )
        applySelection(.text(textRange), notify: true)
        restoreVisibleTextSelection(textRange)
        // Visible selection restoration can synchronously re-report `.text`.
        // Re-save the contraction anchor afterward so the next AppKit-routed key
        // can expand from this full text selection again.
        blockSelectionExpansion = BlockInputBlockSelectionExpansion(anchorBlockID: block.id, direction: direction)
        publishFocusChange(true)
        return true
    }
}

private extension BlockInputMixedSelection {
    var hasPartialTextRange: Bool {
        leadingTextRange != nil || trailingTextRange != nil
    }
}
