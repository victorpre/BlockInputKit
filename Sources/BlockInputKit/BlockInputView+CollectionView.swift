import AppKit

extension BlockInputView: NSCollectionViewDataSource {
    public func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        blockCount
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: BlockInputBlockItem.reuseIdentifier,
            for: indexPath
        )
        guard let blockItem = item as? BlockInputBlockItem else {
            return item
        }
        guard let block = block(at: indexPath.item) else {
            blockItem.clearConfiguration()
            return blockItem
        }
        blockItem.configure(
            block: block,
            allowsReordering: allowsBlockReordering,
            delegate: self
        )
        return blockItem
    }
}

extension BlockInputView: NSCollectionViewDelegateFlowLayout {
    public func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> NSSize {
        let sectionInset = (collectionViewLayout as? NSCollectionViewFlowLayout)?.sectionInset
            ?? NSEdgeInsetsZero
        let horizontalInsets = sectionInset.left + sectionInset.right
        let availableWidth = max(collectionView.bounds.width - horizontalInsets, 1)
        guard let block = block(at: indexPath.item) else {
            return NSSize(width: availableWidth, height: 32)
        }
        let textWidth = max(availableWidth - BlockInputBlockItem.horizontalChromeWidth, 120)
        let height = BlockInputBlockItem.height(for: block, textWidth: textWidth)
        return NSSize(width: availableWidth, height: height)
    }
}

extension BlockInputView: NSCollectionViewDelegate {
    public func collectionView(
        _ collectionView: NSCollectionView,
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> NSPasteboardWriting? {
        guard allowsBlockReordering else {
            return nil
        }
        guard let block = block(at: indexPath.item) else {
            return nil
        }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(block.id.rawValue, forType: .blockInputBlockID)
        return pasteboardItem
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        draggingSession session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint,
        forItemsAt indexPaths: Set<IndexPath>
    ) {
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .none
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        guard canAcceptBlockReorderDrop(draggingInfo) else {
            return []
        }
        proposedDropOperation.pointee = .before
        return .move
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        guard canAcceptBlockReorderDrop(draggingInfo),
              let rawID = draggingInfo.draggingPasteboard.string(forType: .blockInputBlockID),
              let targetIndex = collectionDropTargetIndex(
                forBlockID: BlockInputBlockID(rawValue: rawID),
                proposedItemIndex: indexPath.item
              ) else {
            return false
        }
        return moveBlock(blockID: BlockInputBlockID(rawValue: rawID), to: targetIndex) != nil
    }

    func collectionDropTargetIndex(
        forBlockID blockID: BlockInputBlockID,
        proposedItemIndex: Int
    ) -> Int? {
        guard let sourceIndex = index(of: blockID) else {
            return nil
        }
        if sourceIndex < proposedItemIndex {
            return max(0, proposedItemIndex - 1)
        }
        return proposedItemIndex
    }

    func canAcceptBlockReorderDrop(_ draggingInfo: NSDraggingInfo) -> Bool {
        guard allowsBlockReordering,
              let rawID = draggingInfo.draggingPasteboard.string(forType: .blockInputBlockID),
              index(of: BlockInputBlockID(rawValue: rawID)) != nil else {
            return false
        }
        return true
    }
}
