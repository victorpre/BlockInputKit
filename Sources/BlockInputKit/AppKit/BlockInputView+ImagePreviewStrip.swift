import AppKit

extension BlockInputView {
    func setupImagePreviewStrip() -> (height: NSLayoutConstraint, scrollTop: NSLayoutConstraint) {
        imagePreviewStripView.onOpen = { [weak self] item in
            self?.openImagePreviewItem(item)
        }
        imagePreviewStripView.onRemove = { [weak self] item in
            self?.removeImagePreviewItem(item)
        }
        imagePreviewStripView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imagePreviewStripView)

        let heightConstraint = imagePreviewStripView.heightAnchor.constraint(equalToConstant: 0)
        let scrollTopConstraint = scrollView.topAnchor.constraint(equalTo: topAnchor)
        imagePreviewStripHeightConstraint = heightConstraint
        self.scrollViewTopConstraint = scrollTopConstraint
        return (heightConstraint, scrollTopConstraint)
    }

    func refreshImagePreviewStrip() {
        guard shouldBuildImagePreviewStripItems else {
            if !imagePreviewStripView.isHidden || imagePreviewStripHeightConstraint?.constant != 0 || !imagePreviewStripView.isEmpty {
                imagePreviewStripView.configureItems([])
                updateImagePreviewStripHeight(0)
                imagePreviewStripView.isHidden = true
            }
            return
        }
        let items = imagePreviewItemsInLoadedBlocks()
        imagePreviewStripView.isHidden = items.isEmpty
        imagePreviewStripView.configureStyle(style.imagePreviewStrip)
        imagePreviewStripView.configureContentHorizontalInset(editorHorizontalInset)
        imagePreviewStripView.configureImageLoading(imageLoadingContext)
        imagePreviewStripView.configureItems(items)
        updateImagePreviewStripHeight(items.isEmpty ? 0 : style.imagePreviewStrip.preferredHeight)
    }

    func imagePreviewStripPreferredHeightForLoadedBlocks() -> CGFloat {
        guard shouldBuildImagePreviewStripItems else {
            return 0
        }
        guard !imagePreviewItemsInLoadedBlocks().isEmpty else {
            return 0
        }
        return style.imagePreviewStrip.preferredHeight
    }

    func openImagePreviewItem(_ item: BlockInputImagePreviewItem) {
        switch item {
        case let .occurrence(occurrence):
            openImagePreviewOccurrence(occurrence)
        case let .attachment(attachment):
            guard let previewAttachment = imagePreviewAttachment(matching: attachment) else {
                return
            }
            previewAttachment.open(previewAttachment)
        }
    }

    func openImagePreviewOccurrence(_ occurrence: BlockInputImagePreviewOccurrence) {
        guard let resolvedURL = occurrence.image.resolvedURL(relativeTo: imageBaseURL),
              let url = BlockInputLinkURL.supportedURL(from: resolvedURL.absoluteString) else {
            return
        }
        _ = linkURLOpener(url)
    }

    func removeImagePreviewItem(_ item: BlockInputImagePreviewItem) {
        switch item {
        case let .occurrence(occurrence):
            removeImagePreviewOccurrence(occurrence)
        case let .attachment(attachment):
            guard let previewAttachment = imagePreviewAttachment(matching: attachment) else {
                return
            }
            previewAttachment.remove(previewAttachment)
        }
    }

    func removeImagePreviewOccurrence(_ occurrence: BlockInputImagePreviewOccurrence) {
        guard isEditable,
              let index = index(of: occurrence.blockID),
              var block = block(at: index),
              block.kind.supportsImageSyntaxSplitting else {
            return
        }
        let text = block.text as NSString
        guard NSMaxRange(occurrence.sourceRange) <= text.length,
              text.substring(with: occurrence.sourceRange) == occurrence.sourceText else {
            return
        }
        let beforeBlock = block
        let beforeSelection = selection
        let removalRange = imagePreviewOccurrenceRemovalRange(occurrence.sourceRange, in: text)
        let replacementText = NSMutableString(string: block.text)
        replacementText.replaceCharacters(in: removalRange, with: "")
        block.text = replacementText as String
        let afterOffset = min(occurrence.sourceRange.location, replacementText.length)
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: block.id,
            utf16Offset: afterOffset
        ))
        guard applyGranularBlockReplacement(block, at: index, selection: afterSelection) else {
            return
        }
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: "Remove Image",
            beforeBlock: beforeBlock,
            afterBlock: block,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
    }

    private func imagePreviewOccurrenceRemovalRange(_ sourceRange: NSRange, in text: NSString) -> NSRange {
        let trailingLocation = NSMaxRange(sourceRange)
        if trailingLocation < text.length,
           text.character(at: trailingLocation) == spaceCharacter {
            return NSRange(location: sourceRange.location, length: sourceRange.length + 1)
        }
        let leadingLocation = sourceRange.location - 1
        if leadingLocation >= 0,
           text.character(at: leadingLocation) == spaceCharacter {
            return NSRange(location: leadingLocation, length: sourceRange.length + 1)
        }
        return sourceRange
    }

    private func imagePreviewAttachment(matching snapshot: BlockInputImagePreviewAttachmentSnapshot) -> BlockInputImagePreviewAttachment? {
        imagePreviewAttachments.first { $0.id == snapshot.id }
    }

    private var shouldBuildImagePreviewStripItems: Bool {
        imagePresentation == .textLinksWithPreviewStrip || !imagePreviewAttachments.isEmpty
    }

    private func updateImagePreviewStripHeight(_ height: CGFloat) {
        imagePreviewStripHeightConstraint?.constant = height
        scrollViewTopConstraint?.constant = height
        applyEditorSectionInset()
        imagePreviewStripView.needsLayout = true
        collectionView.collectionViewLayout?.invalidateLayout()
        updatePlaceholderLayout()
        invalidatePreferredHeight()
        layoutSubtreeIfNeeded()
    }

    private func imagePreviewItemsInLoadedBlocks() -> [BlockInputImagePreviewItem] {
        var items = imagePreviewAttachments.map {
            BlockInputImagePreviewItem.attachment(BlockInputImagePreviewAttachmentSnapshot($0))
        }
        guard imagePresentation == .textLinksWithPreviewStrip else {
            return items
        }
        for index in 0..<blockCount {
            guard let block = block(at: index),
                  block.kind.supportsImageSyntaxSplitting else {
                continue
            }
            let source = block.text as NSString
            for match in BlockInputImageSyntaxParser.imageMatches(in: block.text) {
                guard NSMaxRange(match.range) <= source.length else {
                    continue
                }
                items.append(.occurrence(BlockInputImagePreviewOccurrence(
                    blockID: block.id,
                    sourceRange: match.range,
                    sourceText: source.substring(with: match.range),
                    image: match.image
                )))
            }
        }
        return items
    }
}

private let spaceCharacter: unichar = 0x20
