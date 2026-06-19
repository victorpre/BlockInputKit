import AppKit

extension BlockInputView {
    func updateCollectionViewWidthForVisibleBounds() {
        let visibleWidth = resolvedCollectionViewportWidth()
        guard visibleWidth > 0,
              abs(collectionView.frame.width - visibleWidth) > 0.5 || abs(collectionView.bounds.width - visibleWidth) > 0.5 else {
            return
        }
        let visibleHeight = max(scrollView.contentView.bounds.height, 0)
        var frame = collectionView.frame
        frame.size.width = visibleWidth
        frame.size.height = max(frame.height, visibleHeight)
        collectionView.frame = frame
        updateVisibleItemWidthsForCurrentWidth()
        collectionView.collectionViewLayout?.invalidateLayout()
        collectionView.needsLayout = true
        updatePlaceholderLayout()
        invalidatePreferredHeight()
    }

    func resolvedCollectionViewportWidth() -> CGFloat {
        let candidateWidths = [
            collectionView.visibleRect.width,
            scrollView.contentView.bounds.width,
            scrollView.bounds.width,
            bounds.width,
            collectionView.frame.width,
            collectionView.bounds.width
        ]
        return candidateWidths
            .filter { $0 > 0 }
            .min() ?? 0
    }

    func updateVisibleItemWidthsForCurrentWidth() {
        let itemWidth = currentCollectionItemWidth()
        guard itemWidth > 0 else {
            return
        }
        let indexedItems = collectionView.visibleItems().compactMap { item -> (index: Int, item: BlockInputBlockItem)? in
            guard let blockItem = item as? BlockInputBlockItem,
                  let index = collectionView.indexPath(for: blockItem)?.item,
                  block(at: index) != nil else {
                return nil
            }
            return (index, blockItem)
        }.sorted { $0.index < $1.index }
        let staleItems = indexedItems.filter {
            abs($0.item.view.frame.minX) > 0.5 ||
                abs($0.item.view.frame.width - itemWidth) > 0.5
        }
        guard let firstIndex = staleItems.first?.index else {
            return
        }
        for indexedItem in staleItems {
            guard let block = block(at: indexedItem.index) else {
                continue
            }
            var itemFrame = indexedItem.item.view.frame
            itemFrame.origin.x = 0
            itemFrame.size.width = itemWidth
            indexedItem.item.view.frame = itemFrame
            resizeVisibleItem(indexedItem.item, for: block)
            indexedItem.item.view.needsLayout = true
            indexedItem.item.view.layoutSubtreeIfNeeded()
        }
        reflowVisibleItemsAfterHeightChange(startingAt: firstIndex)
    }

    func currentCollectionItemWidth(viewportWidth: CGFloat? = nil) -> CGFloat {
        let sectionInset = layout.sectionInset
        let scrollViewInsets = collectionView.enclosingScrollView?.contentInsets ?? NSEdgeInsetsZero
        let horizontalInsets = sectionInset.left + sectionInset.right + scrollViewInsets.left + scrollViewInsets.right
        let resolvedWidth = viewportWidth ?? resolvedCollectionViewportWidth()
        return max(resolvedWidth - horizontalInsets - 4, 1)
    }
}
