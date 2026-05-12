@testable import BlockInputKit

final class DocumentReadCountingStore: BlockInputDocumentStore {
    private var storedDocument: BlockInputDocument
    private(set) var documentReadCount = 0
    private(set) var indexLookupCount = 0
    private(set) var replaceDocumentCount = 0
    private(set) var replacedBlockIDs: [BlockInputBlockID] = []
    private(set) var insertedBlockBatches: [(blocks: [BlockInputBlock], index: Int)] = []
    private(set) var deletedBlockIDs: [[BlockInputBlockID]] = []

    var document: BlockInputDocument {
        documentReadCount += 1
        return storedDocument
    }

    var blockCount: Int {
        storedDocument.blocks.count
    }

    init(document: BlockInputDocument) {
        storedDocument = document
    }

    func resetCounts() {
        documentReadCount = 0
        indexLookupCount = 0
        replaceDocumentCount = 0
        replacedBlockIDs = []
        insertedBlockBatches = []
        deletedBlockIDs = []
    }

    func block(at index: Int) -> BlockInputBlock? {
        guard storedDocument.blocks.indices.contains(index) else {
            return nil
        }
        return storedDocument.blocks[index]
    }

    func block(withID id: BlockInputBlockID) -> BlockInputBlock? {
        storedDocument.block(withID: id)
    }

    func index(of id: BlockInputBlockID) -> Int? {
        indexLookupCount += 1
        return storedDocument.index(of: id)
    }

    func replaceDocument(_ document: BlockInputDocument) {
        replaceDocumentCount += 1
        storedDocument = document
    }

    func replaceBlock(_ block: BlockInputBlock) {
        replacedBlockIDs.append(block.id)
        guard let index = storedDocument.index(of: block.id) else {
            return
        }
        storedDocument.blocks[index] = block
    }

    func insertBlocks(_ blocks: [BlockInputBlock], at index: Int) {
        insertedBlockBatches.append((blocks, index))
        storedDocument.insertBlocks(blocks, at: index)
    }

    func deleteBlocks(withIDs ids: [BlockInputBlockID]) {
        deletedBlockIDs.append(ids)
        let deletedIDs = Set(ids)
        storedDocument.blocks.removeAll { deletedIDs.contains($0.id) }
    }
}
