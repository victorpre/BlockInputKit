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

        return performStructuralEdit(named: "Insert Files") { document in
            if document.blocks.count == 1,
               document.blocks[0].kind == .paragraph,
               document.blocks[0].isEmpty {
                document.blocks = insertedBlocks
                guard let firstBlock = insertedBlocks.first else {
                    return nil
                }
                return .cursor(BlockInputCursor(blockID: firstBlock.id, utf16Offset: 0))
            }

            let insertionIndex = fileInsertionIndex(below: targetBlockID, in: document)
            return document.insertBlocks(insertedBlocks, at: insertionIndex)
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
}
