import AppKit

extension BlockInputBlockItem {
    func requestCompletionKeyDown(_ event: NSEvent) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestCompletionKeyDown: event
        ) ?? false
    }

    func requestCompletionCommand(_ selector: Selector) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(
            self,
            blockID: blockID,
            didRequestCompletionCommand: selector
        ) ?? false
    }
}
