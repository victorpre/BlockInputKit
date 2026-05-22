import AppKit

struct BlockInputImageContext: Equatable {
    let blockID: BlockInputBlockID
    let selectedRange: NSRange
    let sourceText: String
    let anchorWindowRect: NSRect
}

private struct BlockInputImageDeletionContext {
    let blockID: BlockInputBlockID
    let index: Int?
}

extension BlockInputView {
    func imageContextMenuItems(blockID: BlockInputBlockID, selectedRange: NSRange, event: NSEvent) -> [NSMenuItem] {
        guard let block = block(withID: blockID) else {
            return []
        }
        if case .image = block.kind {
            let deleteItem = NSMenuItem(title: "Delete Image", action: #selector(blockInputDeleteImageFromMenu(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = BlockInputImageDeletionContext(
                blockID: blockID,
                index: indexPathForContextEvent(event)?.item
            )
            return [deleteItem]
        }
        guard let context = imageContext(blockID: blockID, selectedRange: selectedRange, event: event) else {
            return []
        }
        let insertItem = NSMenuItem(title: "Insert Image", action: #selector(blockInputInsertImageFromMenu(_:)), keyEquivalent: "")
        insertItem.target = self
        insertItem.representedObject = context
        return [insertItem]
    }

    @objc(blockInputInsertImageFromMenu:)
    func blockInputInsertImageFromMenu(_ sender: Any?) {
        guard let context = (sender as? NSMenuItem)?.representedObject as? BlockInputImageContext else {
            return
        }
        showImageModal(context: context)
    }

    @objc(blockInputDeleteImageFromMenu:)
    func blockInputDeleteImageFromMenu(_ sender: Any?) {
        guard let context = (sender as? NSMenuItem)?.representedObject as? BlockInputImageDeletionContext else {
            return
        }
        selectedHorizontalRuleIndex = context.index
        applySelection(.blocks([context.blockID]), notify: false)
        _ = deleteSelectedHorizontalRuleForBackspaceOrDelete()
    }

    func showImageModal(context: BlockInputImageContext) {
        let modal = imageModalView ?? BlockInputImageModalView()
        modal.configure()
        configureImageModalActions(modal, context: context)
        imageModalView = modal
        imageModalContext = context
        if modal.superview == nil {
            addSubview(modal)
        }
        positionImageModal(modal, anchoredTo: context.anchorWindowRect)
        modal.focusInitialField()
    }

    func dismissImageModal(restoreFocus: Bool) {
        let context = imageModalContext
        imageModalView?.removeFromSuperview()
        imageModalView = nil
        imageModalContext = nil
        guard restoreFocus,
              let context else {
            return
        }
        focus(blockID: context.blockID, utf16Offset: context.selectedRange.location)
    }

    func imageModalContainsCurrentResponder() -> Bool {
        guard let responder = window?.firstResponder,
              let modal = imageModalView else {
            return false
        }
        return modal.containsResponder(responder)
    }

    @discardableResult
    func insertImage(_ image: BlockInputImage, context: BlockInputImageContext) -> BlockInputSelection? {
        guard let index = index(of: context.blockID),
              let block = block(at: index),
              block.text == context.sourceText else {
            return nil
        }
        if !block.kind.supportsImageSyntaxSplitting {
            return insertImageBlocks([BlockInputBlock(kind: .image(image))], at: index + 1)
        }
        return splitBlockAndInsertImage(image, block: block, index: index, selectedRange: context.selectedRange)
    }

    @discardableResult
    func insertImageFileURLs(_ fileURLs: [URL], below blockID: BlockInputBlockID) -> BlockInputSelection? {
        let imageBlocks = fileURLs.compactMap(Self.imageBlock(for:))
        guard !imageBlocks.isEmpty,
              let index = index(of: blockID) else {
            return nil
        }
        return insertImageBlocks(imageBlocks, at: index + 1)
    }

    static func imageBlock(for url: URL) -> BlockInputBlock? {
        guard url.isFileURL,
              imageFileExtensions.contains(url.pathExtension.lowercased()) else {
            return nil
        }
        return BlockInputBlock(kind: .image(BlockInputImage(source: url.absoluteString, altText: url.deletingPathExtension().lastPathComponent)))
    }

    private func configureImageModalActions(_ modal: BlockInputImageModalView, context: BlockInputImageContext) {
        modal.onInsert = { [weak self] urlString, altText in
            guard let self,
                  let source = BlockInputImageModalView.validImageURLString(urlString) else {
                return
            }
            _ = insertImage(BlockInputImage(source: source, altText: altText), context: context)
            dismissImageModal(restoreFocus: false)
        }
        modal.onCancel = { [weak self] in
            self?.dismissImageModal(restoreFocus: true)
        }
        modal.onFocusCheck = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard self?.imageModalContainsCurrentResponder() == false else {
                    return
                }
                self?.dismissImageModal(restoreFocus: false)
            }
        }
    }

    private func imageContext(blockID: BlockInputBlockID, selectedRange: NSRange, event: NSEvent) -> BlockInputImageContext? {
        guard let block = block(withID: blockID),
              block.kind.supportsImageSyntaxSplitting,
              let item = visibleItem(for: blockID, refreshConfiguration: false) else {
            return nil
        }
        let clickedOffset = item.utf16Offset(atWindowLocation: event.locationInWindow)
        let range = selectedRange.containsOrTouches(clickedOffset)
            ? selectedRange
            : NSRange(location: clickedOffset, length: 0)
        return BlockInputImageContext(
            blockID: blockID,
            selectedRange: clampedRange(range, in: block.text),
            sourceText: block.text,
            anchorWindowRect: item.anchorWindowRect(forUTF16Range: range)
        )
    }

    private func splitBlockAndInsertImage(
        _ image: BlockInputImage,
        block: BlockInputBlock,
        index: Int,
        selectedRange: NSRange
    ) -> BlockInputSelection? {
        let range = clampedRange(selectedRange, in: block.text)
        let text = block.text as NSString
        let prefix = text.substring(to: range.location)
        let suffix = text.substring(from: NSMaxRange(range))
        var replacementBlocks: [BlockInputBlock] = []
        if !prefix.isEmpty {
            replacementBlocks.append(textFragmentBlock(id: block.id, kind: block.kind, text: prefix, template: block))
        }
        let imageBlockID = prefix.isEmpty ? block.id : BlockInputBlockID.unique()
        replacementBlocks.append(BlockInputBlock(id: imageBlockID, kind: .image(image)))
        if !suffix.isEmpty {
            replacementBlocks.append(textFragmentBlock(kind: block.kind, text: suffix, template: block))
        }
        return replaceBlock(block, at: index, with: replacementBlocks, actionName: "Insert Image")
    }

    private func replaceBlock(
        _ beforeBlock: BlockInputBlock,
        at index: Int,
        with replacementBlocks: [BlockInputBlock],
        actionName: String
    ) -> BlockInputSelection? {
        guard let afterBlock = replacementBlocks.first else {
            return nil
        }
        let insertedBlocks = Array(replacementBlocks.dropFirst())
        let beforeSelection = selection
        let insertionIndex = index + 1
        if canSynchronizeCacheForGranularInsertion(insertedBlockCount: insertedBlocks.count) {
            guard replaceCachedBlock(afterBlock, at: index),
                  document.insertBlocks(insertedBlocks, at: insertionIndex) != nil else {
                return nil
            }
        } else {
            markDocumentCacheUnsynchronized()
        }
        let imageBlock = replacementBlocks.first { $0.kind.isImage }
        let afterSelection = imageBlock.map { BlockInputSelection.blocks([$0.id]) }
        syncDocumentStore(.replaceBlock(afterBlock))
        if !insertedBlocks.isEmpty {
            syncDocumentStore(.insertBlocks(insertedBlocks, insertionIndex: insertionIndex))
        }
        applySelection(afterSelection, notify: true)
        undoController?.registerBlockReplacementInsertionStructuralEdit(BlockInputReplaceInsertEdit(
            actionName: actionName,
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            insertedBlocks: insertedBlocks,
            insertionIndex: insertionIndex,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        ))
        reloadDataKeepingFocus()
        publishDocumentChange()
        return afterSelection
    }

    private func insertImageBlocks(_ imageBlocks: [BlockInputBlock], at insertionIndex: Int) -> BlockInputSelection? {
        performStructuralEdit(
            named: imageBlocks.count == 1 ? "Insert Image" : "Insert Images",
            storeSyncAction: { _, _, _ in .insertBlocks(imageBlocks, insertionIndex: insertionIndex) },
            edit: { document in
                guard document.insertBlocks(imageBlocks, at: insertionIndex) != nil,
                      let firstImage = imageBlocks.first else {
                    return nil
                }
                return .blocks([firstImage.id])
            }
        )
    }

    private func indexPathForContextEvent(_ event: NSEvent) -> IndexPath? {
        let collectionLocation = collectionView.convert(event.locationInWindow, from: nil)
        return collectionView.indexPathForItem(at: collectionLocation)
    }

    private func textFragmentBlock(
        id: BlockInputBlockID = .unique(),
        kind: BlockInputBlockKind,
        text: String,
        template: BlockInputBlock
    ) -> BlockInputBlock {
        BlockInputBlock(
            id: id,
            kind: kind,
            text: text,
            indentationLevel: template.indentationLevel,
            lineIndentationLevels: template.lineIndentationLevels
        )
    }

    private func positionImageModal(_ modal: BlockInputImageModalView, anchoredTo windowRect: NSRect) {
        let anchor = convert(windowRect.origin, from: nil)
        let modalSize = modal.fittingSize == .zero ? modal.frame.size : modal.fittingSize
        let width = max(modalSize.width, 300)
        let height = max(modalSize.height, 148)
        let modalOriginX = min(max(anchor.x - 12, bounds.minX + 12), max(bounds.minX + 12, bounds.maxX - width - 12))
        let preferredY = anchor.y - height - 8
        let modalOriginY = preferredY >= bounds.minY + 12
            ? preferredY
            : min(max(anchor.y + 18, bounds.minY + 12), max(bounds.minY + 12, bounds.maxY - height - 12))
        modal.frame = NSRect(x: modalOriginX, y: modalOriginY, width: width, height: height)
    }
}

private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
    let length = (text as NSString).length
    let location = min(max(range.location, 0), length)
    let end = min(max(NSMaxRange(range), location), length)
    return NSRange(location: location, length: end - location)
}

private let imageFileExtensions: Set<String> = [
    "apng", "avif", "bmp", "gif", "heic", "heif", "ico", "jpeg", "jpg", "png", "tif", "tiff", "webp"
]
