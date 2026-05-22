import AppKit

extension BlockInputView {
    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestPasteURL urlString: String,
        selectedRange: NSRange
    ) -> Bool {
        // The mounted text view sees paste first, so mirror its selection into the editor before mutating source.
        if selectedRange.length > 0 {
            applySelection(.text(BlockInputTextRange(blockID: blockID, range: selectedRange)), notify: false)
        } else {
            applySelection(.cursor(BlockInputCursor(blockID: blockID, utf16Offset: selectedRange.location)), notify: false)
        }
        return pasteURLString(urlString, selectedRange: selectedRange)
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestLinkContextMenuItemsFor event: NSEvent,
        selectedRange: NSRange
    ) -> [NSMenuItem] {
        linkContextMenuItems(blockID: blockID, selectedRange: selectedRange, event: event)
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didRequestInsertFileURLs fileURLs: [URL],
        atUTF16Offset utf16Offset: Int
    ) -> Bool {
        let imageURLs = fileURLs.filter { Self.imageBlock(for: $0) != nil }
        let otherURLs = fileURLs.filter { Self.imageBlock(for: $0) == nil }
        let insertedImages = imageURLs.isEmpty ? nil : insertImageFileURLs(imageURLs, below: blockID)
        let insertedFiles = otherURLs.isEmpty ? nil : insertFileURLsInline(otherURLs, into: blockID, atUTF16Offset: utf16Offset, item: item)
        return insertedImages != nil || insertedFiles != nil
    }

    func blockItem(
        _ item: BlockInputBlockItem,
        blockID: BlockInputBlockID,
        didClickLinkAt selectedRange: NSRange,
        clickedLinkRange: BlockInputInlineMarkdownRange?,
        event: NSEvent
    ) -> Bool {
        handleLinkClick(blockID: blockID, selectedRange: selectedRange, clickedLinkRange: clickedLinkRange, event: event)
    }

    func blockItem(_ item: BlockInputBlockItem, blockID: BlockInputBlockID, didResizeImageToWidth width: Int, height: Int) {
        guard let index = index(of: blockID),
              var block = block(at: index),
              case var .image(image) = block.kind else {
            return
        }
        let beforeBlock = block
        let beforeSelection = selection
        image.width = width
        image.height = height
        image.sourceStyle = .html
        block.kind = .image(image)
        let afterSelection = BlockInputSelection.blocks([blockID])
        _ = applyGranularBlockReplacement(block, at: index, selection: afterSelection)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: "Resize Image",
            beforeBlock: beforeBlock,
            afterBlock: block,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
    }
}
