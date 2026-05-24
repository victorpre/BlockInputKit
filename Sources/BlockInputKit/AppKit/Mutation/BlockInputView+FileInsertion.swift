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

        return insertFileBlocks(insertedBlocks) { document in
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

        return insertFileBlocks(insertedBlocks) { document in
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
        insertionIndex: @escaping (BlockInputDocument) -> Int
    ) -> BlockInputSelection? {
        performStructuralEdit(
            named: "Insert Files",
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
                    return .cursor(BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0))
                }

                return document.insertBlocks(insertedBlocks, at: insertionIndex(document))
            }
        )
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
        let insertedBlocks = fileURLs.compactMap(Self.droppedFileBlock)
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
                let firstBlock = insertedBlocks[0]
                if firstBlock.kind.isImage {
                    return .blocks([firstBlock.id])
                }
                return .cursor(BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0))
            }
        )
    }

    private static func droppedFileBlock(for url: URL) -> BlockInputBlock? {
        imageBlock(for: url) ?? fileLinkBlock(for: url)
    }

    static func fileDropActionName(for blocks: [BlockInputBlock]) -> String {
        guard blocks.allSatisfy(\.kind.isImage) else {
            return "Insert Files"
        }
        return blocks.count == 1 ? "Insert Image" : "Insert Images"
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
        let insertionText = Self.inlineFileLinkInsertionText(for: fileURLs)
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
            actionName: "Insert Files",
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
        let insertionText = Self.inlineFileLinkInsertionText(for: references)
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
            actionName: "Insert Files",
            beforeBlock: beforeBlock,
            afterBlock: block,
            selectionBefore: beforeSelection,
            selectionAfter: afterSelection
        )
        return afterSelection
    }

    private static func inlineFileLinkInsertionText(for fileURLs: [URL]) -> String {
        fileURLs.compactMap(inlineFileLinkMarkdownSource).joined(separator: " ")
    }

    static func inlineFileLinkInsertionText(for references: [BlockInputFileDropReference]) -> String {
        references.compactMap(inlineFileLinkMarkdownSource).joined(separator: " ")
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
