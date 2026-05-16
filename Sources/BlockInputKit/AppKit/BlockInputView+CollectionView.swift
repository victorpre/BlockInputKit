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
            editorHorizontalInset: editorHorizontalInset,
            accentColor: dropIndicatorColor,
            isSelected: isBlockSelected(block.id),
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
        let textWidth = BlockInputBlockItem.measuredTextWidth(
            for: availableWidth,
            block: block,
            allowsReordering: allowsBlockReordering,
            editorHorizontalInset: editorHorizontalInset
        )
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
        _ = cancelMultiBlockSelectionForReorderStart()
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
        if canAcceptBlockReorderDrop(draggingInfo) {
            let insertionIndex = resolvedDropInsertionIndex(
                from: draggingInfo,
                proposedItemIndex: proposedDropIndexPath.pointee.item
            )
            let blockID = draggingInfo.draggingPasteboard.string(forType: .blockInputBlockID)
                .map(BlockInputBlockID.init(rawValue:))
            let location = collectionView.convert(draggingInfo.draggingLocation, from: nil)
            let targetIndex = blockID.flatMap {
                collectionDropTargetIndex(
                    forBlockID: $0,
                    proposedItemIndex: insertionIndex,
                    location: location
                )
            }
            guard let blockID, let targetIndex, index(of: blockID) != targetIndex else {
                hideDropIndicator()
                return []
            }
            let indicatorIndex = dropIndicatorInsertionIndex(forBlockID: blockID, targetIndex: targetIndex)
            proposedDropIndexPath.pointee = NSIndexPath(forItem: indicatorIndex, inSection: 0)
            proposedDropOperation.pointee = .before
            showDropIndicator(atInsertionIndex: indicatorIndex)
            return .move
        }
        if canAcceptFileDrop(draggingInfo) {
            let insertionIndex = resolvedDropInsertionIndex(
                from: draggingInfo,
                proposedItemIndex: proposedDropIndexPath.pointee.item
            )
            proposedDropIndexPath.pointee = NSIndexPath(forItem: insertionIndex, inSection: 0)
            proposedDropOperation.pointee = .before
            showDropIndicator(atInsertionIndex: insertionIndex)
            return .copy
        }
        hideDropIndicator()
        return []
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        hideDropIndicator()
        let insertionIndex = resolvedDropInsertionIndex(
            from: draggingInfo,
            proposedItemIndex: indexPath.item
        )
        if canAcceptBlockReorderDrop(draggingInfo) {
            guard let rawID = draggingInfo.draggingPasteboard.string(forType: .blockInputBlockID) else {
                return false
            }
            let blockID = BlockInputBlockID(rawValue: rawID)
            guard let sourceIndex = index(of: blockID),
                  let targetIndex = collectionDropTargetIndex(
                      forBlockID: blockID,
                      proposedItemIndex: insertionIndex,
                      location: collectionView.convert(draggingInfo.draggingLocation, from: nil)
                  ),
                  targetIndex != sourceIndex else {
                return false
            }
            return moveBlock(blockID: blockID, to: targetIndex) != nil
        }
        let fileURLs = fileURLs(from: draggingInfo.draggingPasteboard)
        if !fileURLs.isEmpty {
            return insertFileURLs(fileURLs, at: insertionIndex) != nil
        }
        return false
    }

    func collectionDropTargetIndex(
        forBlockID blockID: BlockInputBlockID,
        proposedItemIndex: Int,
        location: NSPoint? = nil
    ) -> Int? {
        guard let sourceIndex = index(of: blockID) else {
            return nil
        }
        if sourceIndex < proposedItemIndex {
            if proposedItemIndex == sourceIndex + 1 {
                guard location == nil else {
                    return sourceIndex
                }
            }
            let adjustedIndex = max(0, proposedItemIndex - 1)
            if adjustedIndex == sourceIndex, proposedItemIndex < blockCount {
                return proposedItemIndex
            }
            return adjustedIndex
        }
        return proposedItemIndex
    }

    func dropIndicatorInsertionIndex(
        forBlockID blockID: BlockInputBlockID,
        targetIndex: Int
    ) -> Int {
        guard let sourceIndex = index(of: blockID),
              sourceIndex < targetIndex else {
            return clampedInsertionIndex(targetIndex)
        }
        return clampedInsertionIndex(targetIndex + 1)
    }

    func canAcceptBlockReorderDrop(_ draggingInfo: NSDraggingInfo) -> Bool {
        guard allowsBlockReordering,
              let rawID = draggingInfo.draggingPasteboard.string(forType: .blockInputBlockID),
              index(of: BlockInputBlockID(rawValue: rawID)) != nil else {
            return false
        }
        return true
    }

    func canAcceptFileDrop(_ draggingInfo: NSDraggingInfo) -> Bool {
        !fileURLs(from: draggingInfo.draggingPasteboard).isEmpty
    }

    func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.filter(\.isFileURL) ?? []
    }

    func resolvedDropInsertionIndex(
        from draggingInfo: NSDraggingInfo,
        proposedItemIndex: Int
    ) -> Int {
        let location = collectionView.convert(draggingInfo.draggingLocation, from: nil)
        return dropInsertionIndex(forLocation: location, fallbackIndex: proposedItemIndex)
    }

    func dropInsertionIndex(forLocation location: NSPoint, fallbackIndex: Int) -> Int {
        let fallbackIndex = clampedInsertionIndex(fallbackIndex)
        guard blockCount > 0 else {
            return 0
        }

        // Resolve against visible layout attributes only so drag validation stays cheap for large documents.
        let searchRect = collectionView.visibleRect.insetBy(dx: 0, dy: -80)
        let attributes = collectionView.collectionViewLayout?
            .layoutAttributesForElements(in: searchRect)
            .filter { $0.representedElementCategory == .item }
            .compactMap { attribute -> (indexPath: IndexPath, frame: NSRect)? in
                guard let indexPath = attribute.indexPath else {
                    return nil
                }
                return (indexPath, attribute.frame)
            }
            .sorted { $0.frame.minY < $1.frame.minY } ?? []
        guard !attributes.isEmpty else {
            return fallbackIndex
        }

        for attribute in attributes where location.y < attribute.frame.midY {
            return clampedInsertionIndex(attribute.indexPath.item)
        }
        guard let lastItem = attributes.last?.indexPath.item else {
            return fallbackIndex
        }
        return clampedInsertionIndex(lastItem + 1)
    }

    func showDropIndicator(atInsertionIndex insertionIndex: Int) {
        guard let frame = dropIndicatorFrame(forInsertionIndex: insertionIndex) else {
            hideDropIndicator()
            return
        }
        dropIndicatorView.frame = frame
        dropIndicatorView.isHidden = false
        if dropIndicatorView.superview == nil {
            collectionView.addSubview(dropIndicatorView, positioned: .above, relativeTo: nil)
        }
    }

    func hideDropIndicator() {
        dropIndicatorView.isHidden = true
    }

    func updateDropIndicatorColor() {
        dropIndicatorView.layer?.backgroundColor = dropIndicatorColor.cgColor
    }

    func dropIndicatorFrame(forInsertionIndex insertionIndex: Int) -> NSRect? {
        guard blockCount > 0 else {
            return NSRect(x: 12, y: 8, width: max(collectionView.bounds.width - 24, 1), height: 2)
        }

        let yPosition: CGFloat
        if insertionIndex < blockCount,
           let attributes = collectionView.layoutAttributesForItem(
            at: IndexPath(item: clampedInsertionIndex(insertionIndex), section: 0)
           ) {
            yPosition = attributes.frame.minY
        } else if let attributes = collectionView.layoutAttributesForItem(
            at: IndexPath(item: blockCount - 1, section: 0)
        ) {
            yPosition = attributes.frame.maxY
        } else {
            return nil
        }

        return NSRect(
            x: 12,
            y: yPosition - 1,
            width: max(collectionView.bounds.width - 24, 1),
            height: 2
        )
    }

    private func clampedInsertionIndex(_ index: Int) -> Int {
        min(max(index, 0), blockCount)
    }
}
