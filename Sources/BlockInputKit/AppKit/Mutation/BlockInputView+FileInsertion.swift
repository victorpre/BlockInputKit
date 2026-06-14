import AppKit

public extension BlockInputView {
    /// Inserts file URLs as Markdown link paragraph blocks.
    ///
    /// Host apps can call this from paste or drop handlers after resolving file URLs from
    /// their own pasteboard or drag session. Non-file URLs are ignored.
    @discardableResult
    func insertFileURLs(
        _ fileURLs: [URL],
        below blockID: BlockInputBlockID? = nil
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        let insertedBlocks = fileURLs.compactMap(Self.fileLinkBlock)
        guard !insertedBlocks.isEmpty else {
            return nil
        }

        let targetBlockID = blockID ?? activeBlockID
        if let targetBlockID, index(of: targetBlockID) == nil {
            return nil
        }

        return insertFileBlocks(insertedBlocks, actionName: "Insert Files") { document in
            self.fileInsertionIndex(below: targetBlockID, in: document)
        }
    }

    /// Inserts file URLs as Markdown link paragraph blocks at a document index.
    ///
    /// The insertion index is clamped to the current document, but never before
    /// leading frontmatter because frontmatter is only canonical at index `0`.
    @discardableResult
    func insertFileURLs(
        _ fileURLs: [URL],
        at insertionIndex: Int
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        let insertedBlocks = fileURLs.compactMap(Self.fileLinkBlock)
        guard !insertedBlocks.isEmpty else {
            return nil
        }

        return insertFileBlocks(insertedBlocks, actionName: "Insert Files") { document in
            self.fileInsertionIndex(at: insertionIndex, in: document)
        }
    }

    /// Inserts local file URLs using the same image-aware block mapping as file drops.
    ///
    /// Image files are inserted according to `BlockInputConfiguration.imagePresentation`:
    /// the default `.inlineBlocks` creates image blocks, while `.textLinksWithPreviewStrip`
    /// creates Markdown image text blocks. Other file URLs are inserted as Markdown file-link
    /// paragraph blocks. Non-file URLs are ignored.
    @discardableResult
    func insertLocalFileURLs(
        _ fileURLs: [URL],
        below blockID: BlockInputBlockID? = nil
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        // Keep picker insertion aligned with drop behavior so host apps do not need
        // to duplicate BlockInputKit's file/image classification rules.
        let insertedBlocks = fileURLs.compactMap(droppedFileBlock)
        guard !insertedBlocks.isEmpty else {
            return nil
        }

        let targetBlockID = blockID ?? activeBlockID
        if let targetBlockID, index(of: targetBlockID) == nil {
            return nil
        }

        return insertFileBlocks(insertedBlocks, actionName: Self.fileDropActionName(for: insertedBlocks)) { document in
            self.fileInsertionIndex(below: targetBlockID, in: document)
        }
    }

    /// Inserts local file URLs at a document index using image-aware block mapping.
    ///
    /// Image files follow `BlockInputConfiguration.imagePresentation`: inline image blocks by default, or Markdown image
    /// text blocks when `.textLinksWithPreviewStrip` is configured.
    ///
    /// The insertion index is clamped to the current document, but never before
    /// leading frontmatter because frontmatter is only canonical at index `0`.
    @discardableResult
    func insertLocalFileURLs(
        _ fileURLs: [URL],
        at insertionIndex: Int
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        let insertedBlocks = fileURLs.compactMap(droppedFileBlock)
        guard !insertedBlocks.isEmpty else {
            return nil
        }

        return insertFileBlocks(insertedBlocks, actionName: Self.fileDropActionName(for: insertedBlocks)) { document in
            self.fileInsertionIndex(at: insertionIndex, in: document)
        }
    }

    internal static func fileLinkBlock(for url: URL) -> BlockInputBlock? {
        guard url.isFileURL else {
            return nil
        }
        let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        return fileLinkBlock(label: displayName, source: url.absoluteString)
    }

    internal static func fileLinkBlock(label: String, source: String) -> BlockInputBlock? {
        guard let normalized = normalizedDropSource(source) else {
            return nil
        }
        let resolvedLabel = label.isEmpty ? normalized : label
        return BlockInputBlock(text: markdownFileLinkBlockSource(label: resolvedLabel, destination: normalized))
    }

    private static func markdownFileLinkBlockSource(label: String, destination: String) -> String {
        "[\(BlockInputLinkURL.escapedLabel(label))](<\(escapedFileLinkBlockDestination(destination))>)"
    }

    private static func escapedFileLinkBlockDestination(_ destination: String) -> String {
        destination
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "<", with: "\\<")
            .replacingOccurrences(of: ">", with: "\\>")
    }

    private func fileInsertionIndex(
        below targetBlockID: BlockInputBlockID?,
        in document: BlockInputDocument
    ) -> Int {
        guard let targetBlockID, let index = document.index(of: targetBlockID) else {
            return document.blocks.count
        }
        return index + 1
    }

    private func fileInsertionIndex(at insertionIndex: Int, in document: BlockInputDocument) -> Int {
        let clampedIndex = min(max(insertionIndex, 0), document.blocks.count)
        guard document.blocks.first?.kind == .frontMatter,
              clampedIndex == 0 else {
            return clampedIndex
        }
        return 1
    }

    private func insertFileBlocks(
        _ insertedBlocks: [BlockInputBlock],
        actionName: String,
        insertionIndex: @escaping (BlockInputDocument) -> Int
    ) -> BlockInputSelection? {
        performStructuralEdit(
            named: actionName,
            storeSyncAction: { beforeDocument, _, _ in
                if beforeDocument.blocks.count == 1,
                   beforeDocument.blocks[0].kind == .paragraph,
                   beforeDocument.blocks[0].isEmpty {
                    return .replaceDocument
                }
                return .insertBlocks(insertedBlocks, insertionIndex: insertionIndex(beforeDocument))
            },
            edit: { document in
                if document.blocks.count == 1,
                   document.blocks[0].kind == .paragraph,
                   document.blocks[0].isEmpty {
                    document.blocks = insertedBlocks
                    guard let firstBlock = insertedBlocks.first else {
                        return nil
                    }
                    return Self.fileInsertionSelection(for: firstBlock)
                }

                let selection = document.insertBlocks(insertedBlocks, at: insertionIndex(document))
                guard let firstBlock = insertedBlocks.first else {
                    return selection
                }
                return Self.fileInsertionSelection(for: firstBlock)
            }
        )
    }

    private static func fileInsertionSelection(for firstBlock: BlockInputBlock) -> BlockInputSelection {
        if firstBlock.kind.isImage {
            return .blocks([firstBlock.id])
        }
        return .cursor(BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0))
    }
}

extension BlockInputView {
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.filter(\.isFileURL) ?? []
    }

    @discardableResult
    func insertDroppedFileURLs(_ fileURLs: [URL], at insertionIndex: Int) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        let insertedBlocks = fileURLs.compactMap(droppedFileBlock)
        guard !insertedBlocks.isEmpty else {
            return nil
        }
        return insertDroppedFileBlocks(insertedBlocks, at: insertionIndex)
    }

    @discardableResult
    func insertDroppedFileBlocks(_ insertedBlocks: [BlockInputBlock], at insertionIndex: Int) -> BlockInputSelection? {
        guard isEditable,
              !insertedBlocks.isEmpty else {
            return nil
        }
        return performStructuralEdit(
            named: Self.fileDropActionName(for: insertedBlocks),
            storeSyncAction: { beforeDocument, _, _ in
                .insertBlocks(insertedBlocks, insertionIndex: self.fileInsertionIndex(at: insertionIndex, in: beforeDocument))
            },
            edit: { document in
                let clampedIndex = self.fileInsertionIndex(at: insertionIndex, in: document)
                document.blocks.insert(contentsOf: insertedBlocks, at: clampedIndex)
                return Self.fileInsertionSelection(for: insertedBlocks[0])
            }
        )
    }

    private func droppedFileBlock(for url: URL) -> BlockInputBlock? {
        if imagePresentation == .textLinksWithPreviewStrip,
           let imageTextBlock = Self.imageTextBlock(for: url) {
            return imageTextBlock
        }
        return Self.imageBlock(for: url) ?? Self.fileLinkBlock(for: url)
    }

    static func fileDropActionName(for blocks: [BlockInputBlock]) -> String {
        guard blocks.allSatisfy(isImageInsertionBlock) else {
            return "Insert Files"
        }
        return blocks.count == 1 ? "Insert Image" : "Insert Images"
    }

    private static func isImageInsertionBlock(_ block: BlockInputBlock) -> Bool {
        if block.kind.isImage {
            return true
        }
        let matches = BlockInputImageSyntaxParser.imageMatches(in: block.text)
        guard matches.count == 1,
              let match = matches.first,
              match.range.location == 0,
              match.range.length == (block.text as NSString).length else {
            return false
        }
        return true
    }

    @discardableResult
    func insertFileURLsInline(
        _ fileURLs: [URL],
        into blockID: BlockInputBlockID,
        atUTF16Offset utf16Offset: Int,
        item: BlockInputBlockItem
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        let insertionText = inlineFileInsertionText(for: fileURLs)
        guard !insertionText.isEmpty,
              item.representedBlockID == blockID,
              let index = index(of: blockID),
              var block = block(at: index),
              block.id == blockID,
              BlockInputBlockItem.supportsInlineMarkdownStyling(block.kind) else {
            return nil
        }
        let beforeBlock = block
        let beforeSelection = selection
        let insertionOffset = min(max(utf16Offset, 0), block.utf16Length)
        let mutableText = NSMutableString(string: block.text)
        mutableText.insert(insertionText, at: insertionOffset)
        block.text = mutableText as String
        let afterOffset = insertionOffset + (insertionText as NSString).length
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: afterOffset
        ))
        _ = applyGranularBlockReplacement(block, at: index, selection: afterSelection)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: inlineFileInsertionActionName(for: fileURLs),
            beforeBlock: beforeBlock,
            afterBlock: block,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        return afterSelection
    }

    @discardableResult
    func insertFileReferencesInline(
        _ references: [BlockInputFileDropReference],
        into blockID: BlockInputBlockID,
        atUTF16Offset utf16Offset: Int
    ) -> BlockInputSelection? {
        guard isEditable else {
            return nil
        }
        let insertionText = inlineFileInsertionText(for: references)
        guard !insertionText.isEmpty,
              let index = index(of: blockID),
              var block = block(at: index),
              block.id == blockID,
              BlockInputBlockItem.supportsInlineMarkdownStyling(block.kind) else {
            return nil
        }
        let beforeBlock = block
        let beforeSelection = selection
        let insertionOffset = min(max(utf16Offset, 0), block.utf16Length)
        let mutableText = NSMutableString(string: block.text)
        mutableText.insert(insertionText, at: insertionOffset)
        block.text = mutableText as String
        let afterOffset = insertionOffset + (insertionText as NSString).length
        let afterSelection = BlockInputSelection.cursor(BlockInputCursor(
            blockID: blockID,
            utf16Offset: afterOffset
        ))
        _ = applyGranularBlockReplacement(block, at: index, selection: afterSelection)
        undoController?.registerBlockReplacementStructuralEdit(
            actionName: inlineFileInsertionActionName(for: references),
            beforeBlock: beforeBlock,
            afterBlock: block,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        return afterSelection
    }

    private func inlineFileInsertionText(for fileURLs: [URL]) -> String {
        fileURLs.compactMap { url in
            if imagePresentation == .textLinksWithPreviewStrip,
               let imageTextBlock = Self.imageTextBlock(for: url) {
                return imageTextBlock.text
            }
            return Self.inlineFileLinkMarkdownSource(for: url)
        }.joined(separator: " ")
    }

    private func inlineFileInsertionText(for references: [BlockInputFileDropReference]) -> String {
        references.compactMap { reference in
            if imagePresentation == .textLinksWithPreviewStrip,
               let imageTextBlock = Self.imageTextBlock(for: reference) {
                return imageTextBlock.text
            }
            return Self.inlineFileLinkMarkdownSource(for: reference)
        }.joined(separator: " ")
    }

    private func inlineFileInsertionActionName(for fileURLs: [URL]) -> String {
        guard imagePresentation == .textLinksWithPreviewStrip,
              !fileURLs.isEmpty,
              fileURLs.allSatisfy({ Self.imageTextBlock(for: $0) != nil }) else {
            return "Insert Files"
        }
        return fileURLs.count == 1 ? "Insert Image" : "Insert Images"
    }

    private func inlineFileInsertionActionName(for references: [BlockInputFileDropReference]) -> String {
        guard imagePresentation == .textLinksWithPreviewStrip,
              !references.isEmpty,
              references.allSatisfy({ Self.imageTextBlock(for: $0) != nil }) else {
            return "Insert Files"
        }
        return references.count == 1 ? "Insert Image" : "Insert Images"
    }

    private static func inlineFileLinkMarkdownSource(for url: URL) -> String? {
        guard url.isFileURL else {
            return nil
        }
        let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        return BlockInputLinkURL.markdownLink(label: displayName, destination: url.absoluteString)
    }

    static func inlineFileLinkMarkdownSource(for reference: BlockInputFileDropReference) -> String? {
        guard reference.kind == .fileLink,
              let source = normalizedDropSource(reference.source) else {
            return nil
        }
        let label = reference.label.isEmpty ? source : reference.label
        return BlockInputLinkURL.markdownLink(label: label, destination: source)
    }

    static func block(for reference: BlockInputFileDropReference) -> BlockInputBlock? {
        guard let source = normalizedDropSource(reference.source) else {
            return nil
        }
        switch reference.kind {
        case .fileLink:
            return fileLinkBlock(label: reference.label, source: source)
        case .image:
            return BlockInputBlock(kind: .image(BlockInputImage(source: source, altText: reference.label)))
        }
    }

    static func normalizedDropSource(_ source: String) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isNewline) else {
            return nil
        }
        return trimmed
    }
}
