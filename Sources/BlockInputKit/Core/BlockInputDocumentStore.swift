import Foundation

/// Document storage boundary used by the editor and host app.
///
/// The editor reads blocks by index and stable ID so hosts can keep large
/// documents outside of the view. Hosts can override the granular mutation
/// methods to avoid full document replacement on common editor operations.
public protocol BlockInputDocumentStore: AnyObject {
    /// Current document snapshot.
    var document: BlockInputDocument { get }
    /// Number of blocks available to the editor.
    var blockCount: Int { get }

    /// Returns the block at an ordered index.
    func block(at index: Int) -> BlockInputBlock?
    /// Returns the block with a stable ID.
    func block(withID id: BlockInputBlockID) -> BlockInputBlock?
    /// Returns the ordered index for a stable block ID.
    func index(of id: BlockInputBlockID) -> Int?
    /// Replaces the full document after broad structural mutations.
    func replaceDocument(_ document: BlockInputDocument)
    /// Replaces one block after a text or formatting mutation.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when the
    /// block exists and changes the current document.
    func replaceBlock(_ block: BlockInputBlock)
    /// Inserts blocks at an ordered index.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when the
    /// insertion changes the current document.
    func insertBlocks(_ blocks: [BlockInputBlock], at index: Int)
    /// Deletes blocks by stable ID.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when at
    /// least one block is removed.
    func deleteBlocks(withIDs ids: [BlockInputBlockID])
    /// Moves one block to a final ordered index.
    ///
    /// The default implementation calls `replaceDocument(_:)` only when the
    /// block exists and its index changes.
    func moveBlock(withID id: BlockInputBlockID, to index: Int)
}

public extension BlockInputDocumentStore {
    var blockCount: Int {
        document.blocks.count
    }

    func block(at index: Int) -> BlockInputBlock? {
        guard document.blocks.indices.contains(index) else {
            return nil
        }
        return document.blocks[index]
    }

    func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        document.block(withID: id)
    }

    func index(of id: BlockInputBlockID) -> Int? {
        document.index(of: id)
    }

    func replaceBlock(_ block: BlockInputBlock) {
        var updatedDocument = document
        guard let index = updatedDocument.index(of: block.id) else {
            return
        }
        guard updatedDocument.blocks[index] != block else {
            return
        }
        updatedDocument.blocks[index] = block
        replaceDocument(updatedDocument)
    }

    func insertBlocks(_ blocks: [BlockInputBlock], at index: Int) {
        var updatedDocument = document
        guard updatedDocument.insertBlocks(blocks, at: index) != nil else {
            return
        }
        replaceDocument(updatedDocument)
    }

    func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        guard !ids.isEmpty else {
            return
        }
        var updatedDocument = document
        let beforeDocument = updatedDocument
        let deletedIDs = Set(ids)
        updatedDocument.blocks.removeAll { deletedIDs.contains($0.id) }
        guard updatedDocument != beforeDocument else {
            return
        }
        replaceDocument(updatedDocument)
    }

    func moveBlock(withID id: BlockInputBlockID, to index: Int) {
        var updatedDocument = document
        guard updatedDocument.moveBlock(blockID: id, to: index) != nil else {
            return
        }
        replaceDocument(updatedDocument)
    }
}

/// In-memory store for simple editors and tests.
public final class BlockInputMemoryDocumentStore: BlockInputDocumentStore {
    /// Current document snapshot.
    public private(set) var document: BlockInputDocument

    public init(document: BlockInputDocument = BlockInputDocument()) {
        self.document = document
    }

    public func replaceDocument(_ document: BlockInputDocument) {
        self.document = document
    }

    public func replaceBlock(_ block: BlockInputBlock) {
        guard let index = document.index(of: block.id) else {
            return
        }
        document.blocks[index] = block
    }

    public func insertBlocks(_ blocks: [BlockInputBlock], at index: Int) {
        document.insertBlocks(blocks, at: index)
    }

    public func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        guard !ids.isEmpty else {
            return
        }
        let deletedIDs = Set(ids)
        document.blocks.removeAll { deletedIDs.contains($0.id) }
    }

    public func moveBlock(withID id: BlockInputBlockID, to index: Int) {
        document.moveBlock(blockID: id, to: index)
    }
}
