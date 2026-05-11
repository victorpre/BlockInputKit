import Foundation
@testable import BlockInputKit

final class CountingDocumentStore: BlockInputDocumentStore {
    private(set) var document: BlockInputDocument
    private(set) var blockCountReadCount = 0
    private(set) var blockAtReadIndexes: [Int] = []
    private(set) var indexReadIDs: [BlockInputBlockID] = []
    private(set) var replaceDocumentCount = 0

    var blockCount: Int {
        blockCountReadCount += 1
        return document.blocks.count
    }

    init(document: BlockInputDocument) {
        self.document = document
    }

    func resetCounts() {
        blockCountReadCount = 0
        blockAtReadIndexes = []
        indexReadIDs = []
        replaceDocumentCount = 0
    }

    func block(at index: Int) -> BlockInputBlock? {
        blockAtReadIndexes.append(index)
        guard document.blocks.indices.contains(index) else {
            return nil
        }
        return document.blocks[index]
    }

    func index(of id: BlockInputBlockID) -> Int? {
        indexReadIDs.append(id)
        return document.index(of: id)
    }

    func replaceDocument(_ document: BlockInputDocument) {
        replaceDocumentCount += 1
        self.document = document
    }
}

final class StoreBackedCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    private(set) var requestCount = 0
    private(set) var lastContext: BlockInputCompletionContext?

    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        requestCount += 1
        lastContext = context
        return [
            BlockInputCompletionSuggestion(
                id: "mention:store",
                title: "Store",
                insertionText: "@store",
                trigger: context.trigger
            )
        ]
    }
}
