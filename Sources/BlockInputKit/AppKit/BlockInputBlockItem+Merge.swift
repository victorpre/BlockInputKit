import Foundation

extension BlockInputBlockItem {
    func requestMergeWithPreviousBlock() -> Bool {
        guard let blockID else {
            return false
        }
        return delegate?.blockItemDidRequestMergeWithPreviousBlock(self, blockID: blockID) ?? false
    }
}
