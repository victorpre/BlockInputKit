import AppKit

/// Flow layout tuned for large block documents where scrolling must not trigger a full relayout.
final class BlockInputCollectionViewFlowLayout: NSCollectionViewFlowLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        false
    }
}
