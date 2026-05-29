import AppKit

extension BlockInputTextView {
    /// Keeps plain left/right movement aligned with the visible link/chip boundary, not hidden Markdown source bytes.
    func handleLinkBoundaryMovementCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveLeft(_:)):
            return moveAcrossHiddenLinkBoundary(.leftward)
        case #selector(moveRight(_:)):
            return moveAcrossHiddenLinkBoundary(.rightward)
        default:
            return false
        }
    }

    func handleLinkBoundaryMovementShortcut(_ event: NSEvent) -> Bool {
        guard let direction = event.plainHorizontalMovementDirection else {
            return false
        }
        return moveAcrossHiddenLinkBoundary(direction)
    }

    private func moveAcrossHiddenLinkBoundary(_ direction: BlockInputHorizontalMovementDirection) -> Bool {
        let selectedRange = selectedRange()
        guard selectedRange.length == 0,
              let renderedBlock = blockItem?.renderedBlock,
              BlockInputBlockItem.supportsInlineMarkdownStyling(renderedBlock.kind),
              let target = hiddenLinkBoundaryTarget(
                from: selectedRange.location,
                direction: direction,
                text: string
              ) else {
            return false
        }
        setSelectedRanges([NSValue(range: target.range)], affinity: target.affinity, stillSelecting: false)
        scrollRangeToVisible(target.range)
        return true
    }

    private func hiddenLinkBoundaryTarget(
        from offset: Int,
        direction: BlockInputHorizontalMovementDirection,
        text: String
    ) -> HiddenLinkBoundaryTarget? {
        let inlineCodeRanges = BlockInputCodeParsing.inlineCodeRanges(in: text).map(\.fullRange)
        let linkRanges = BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: text,
            excluding: inlineCodeRanges,
            fileBaseURL: blockItem?.fileBaseURL
        )
            .filter { $0.style == .link }
        switch direction {
        case .leftward:
            if let range = linkRanges.last(where: { range in
                range.contentRange.location == offset && range.fullRange.location < offset
            }) {
                return HiddenLinkBoundaryTarget(
                    range: NSRange(location: range.fullRange.location, length: 0),
                    affinity: .upstream
                )
            }
            return linkRanges.last { range in
                range.fullRange.location == offset && range.fullRange.location < NSMaxRange(range.fullRange)
            }.map { range in
                HiddenLinkBoundaryTarget(
                    range: NSRange(location: max(range.fullRange.location - 1, 0), length: 0),
                    affinity: .upstream
                )
            }
        case .rightward:
            if let range = linkRanges.first(where: { range in
                NSMaxRange(range.contentRange) == offset && NSMaxRange(range.fullRange) > offset
            }) {
                return HiddenLinkBoundaryTarget(
                    range: NSRange(location: NSMaxRange(range.fullRange), length: 0),
                    affinity: .downstream
                )
            }
            let textLength = (text as NSString).length
            return linkRanges.first { range in
                NSMaxRange(range.fullRange) == offset && range.fullRange.location < NSMaxRange(range.fullRange)
            }.map { range in
                HiddenLinkBoundaryTarget(
                    range: NSRange(location: min(NSMaxRange(range.fullRange) + 1, textLength), length: 0),
                    affinity: .downstream
                )
            }
        }
    }
}

private struct HiddenLinkBoundaryTarget {
    let range: NSRange
    let affinity: NSSelectionAffinity
}
