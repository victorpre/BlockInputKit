import AppKit

extension BlockInputTextView {
    func handleWordMovementCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveWordLeft(_:)):
            moveWordLeft(nil)
            return true
        case #selector(NSResponder.moveWordBackward(_:)):
            moveWordBackward(nil)
            return true
        case #selector(NSResponder.moveWordRight(_:)):
            moveWordRight(nil)
            return true
        case #selector(NSResponder.moveWordForward(_:)):
            moveWordForward(nil)
            return true
        default:
            return false
        }
    }

    func requestWordMovementFromOwningBlock(_ direction: BlockInputWordMovementDirection) -> Bool {
        let range = selectedRange()
        guard range.length == 0 else {
            return false
        }
        let textLength = (string as NSString).length
        switch direction {
        case .leftward:
            guard range.location <= 0 else {
                return false
            }
        case .rightward:
            guard range.location >= textLength else {
                return false
            }
        }
        let result = blockItem?.requestWordMovement(direction, selectedRange: range) == true
        BlockInputSelectionDebug.emit(
            "text request word direction=\(direction.debugName) range=\(range) result=\(result)"
        )
        return result
    }
}
