import Foundation

/// Document storage boundary used by the editor and host app.
///
/// The editor reads blocks by index and stable ID so hosts can keep large
/// documents outside of the view. In the current API, editor mutations publish
/// a full replacement document through `replaceDocument(_:)`.
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
    /// Replaces the document after an editor mutation.
    func replaceDocument(_ document: BlockInputDocument)
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
}
