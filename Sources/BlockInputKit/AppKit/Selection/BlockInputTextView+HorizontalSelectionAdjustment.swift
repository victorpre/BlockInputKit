import AppKit

extension BlockInputTextView {
    func handleHorizontalSelectionAdjustmentCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(moveLeftAndModifySelection(_:)),
             #selector(moveBackwardAndModifySelection(_:)):
            return requestHorizontalSelectionAdjustmentFromOwningBlock(.leftward)
        case #selector(moveRightAndModifySelection(_:)),
             #selector(moveForwardAndModifySelection(_:)):
            return requestHorizontalSelectionAdjustmentFromOwningBlock(.rightward)
        default:
            return false
        }
    }

    func handleHorizontalSelectionAdjustmentShortcut(_ event: NSEvent) -> Bool {
        guard let direction = event.horizontalSelectionAdjustmentDirection else {
            return false
        }
        return requestHorizontalSelectionAdjustmentFromOwningBlock(direction)
    }

    func requestHorizontalSelectionAdjustmentFromOwningBlock(_ direction: BlockInputHorizontalMovementDirection) -> Bool {
        let result = blockItem?.requestHorizontalSelectionAdjustment(direction) == true
        BlockInputSelectionDebug.emit(
            "text request horizontal direction=\(direction.debugName) range=\(selectedRange()) result=\(result)"
        )
        return result
    }
}
