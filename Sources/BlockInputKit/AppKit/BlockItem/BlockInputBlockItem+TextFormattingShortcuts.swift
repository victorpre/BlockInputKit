import AppKit

extension BlockInputBlockItem {
    func requestTextFormattingShortcut(_ shortcut: BlockInputTextFormattingShortcut) -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItem(self, blockID: blockID, didRequestTextFormattingShortcut: shortcut) ?? false
    }
}
