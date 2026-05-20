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
        let insertedBlocks = fileURLs.compactMap(Self.fileLinkBlock)
        guard !insertedBlocks.isEmpty else {
            return nil
        }

        return insertFileBlocks(insertedBlocks) { document in
            self.fileInsertionIndex(at: insertionIndex, in: document)
        }
    }

    private static func fileLinkBlock(for url: URL) -> BlockInputBlock? {
        guard url.isFileURL else {
            return nil
        }
        let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        return BlockInputBlock(text: "[\(escapedMarkdownLinkText(displayName))](<\(escapedMarkdownDestination(url.absoluteString))>)")
    }

    private static func escapedMarkdownLinkText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func escapedMarkdownDestination(_ text: String) -> String {
        text
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
    @discardableResult
    func insertFileURLsInline(
        _ fileURLs: [URL],
        into blockID: BlockInputBlockID,
        atUTF16Offset utf16Offset: Int,
        item: BlockInputBlockItem
    ) -> BlockInputSelection? {
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

    private static func inlineFileLinkInsertionText(for fileURLs: [URL]) -> String {
        fileURLs.compactMap(inlineFileLinkMarkdownSource).joined(separator: " ")
    }

    private static func inlineFileLinkMarkdownSource(for url: URL) -> String? {
        guard url.isFileURL else {
            return nil
        }
        let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        return BlockInputLinkURL.markdownLink(label: displayName, destination: url.absoluteString)
    }
}
