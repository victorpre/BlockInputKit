import Foundation

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
    /// This is used by the built-in collection view drop handling. The insertion
    /// index is clamped to the current document, but never before leading
    /// frontmatter because frontmatter is only canonical at index `0`.
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
