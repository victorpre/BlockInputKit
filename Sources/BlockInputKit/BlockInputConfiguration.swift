import Foundation

public struct BlockInputConfiguration {
    public var document: BlockInputDocument
    public var allowsBlockReordering: Bool
    public var undoController: BlockInputUndoController?
    public var onDocumentChange: ((BlockInputDocument) -> Void)?
    public var onSelectionChange: ((BlockInputSelection?) -> Void)?

    public init(
        document: BlockInputDocument = BlockInputDocument(),
        allowsBlockReordering: Bool = true,
        undoController: BlockInputUndoController? = nil,
        onDocumentChange: ((BlockInputDocument) -> Void)? = nil,
        onSelectionChange: ((BlockInputSelection?) -> Void)? = nil
    ) {
        self.document = document
        self.allowsBlockReordering = allowsBlockReordering
        self.undoController = undoController
        self.onDocumentChange = onDocumentChange
        self.onSelectionChange = onSelectionChange
    }
}
