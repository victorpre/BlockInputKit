import AppKit

private struct BlockInputAcceptedFileDrop: Sendable {
    var context: BlockInputFileDropContext
    var inlineValidation: InlineValidation?
    var storeID: ObjectIdentifier?

    struct InlineValidation: Sendable {
        var blockID: BlockInputBlockID
        var kind: BlockInputBlockKind
        var text: String
    }
}

extension BlockInputView {
    func cancelFileDropTasks() {
        for task in fileDropTasks.values {
            task.cancel()
        }
        fileDropTasks.removeAll()
    }

    private func acceptedFileDrop(
        fileURLs: [URL],
        placement: BlockInputFileDropPlacement
    ) -> BlockInputAcceptedFileDrop? {
        guard isEditable else {
            return nil
        }
        let files = fileURLs.enumerated().compactMap(Self.droppedFile)
        guard !files.isEmpty else {
            return nil
        }
        let inlineValidation: BlockInputAcceptedFileDrop.InlineValidation?
        switch placement {
        case let .inline(blockID, _):
            guard let block = block(withID: blockID),
                  BlockInputBlockItem.supportsInlineMarkdownStyling(block.kind) else {
                return nil
            }
            inlineValidation = .init(blockID: blockID, kind: block.kind, text: block.text)
        case .documentEnd:
            guard !showsProgressiveLoadingRow else {
                return nil
            }
            inlineValidation = nil
        }
        return BlockInputAcceptedFileDrop(
            context: BlockInputFileDropContext(files: files, placement: placement, document: document),
            inlineValidation: inlineValidation,
            storeID: documentStore.map { ObjectIdentifier($0 as AnyObject) }
        )
    }

    func handleDroppedFileURLs(
        _ fileURLs: [URL],
        placement: BlockInputFileDropPlacement
    ) -> Bool {
        guard isEditable else {
            return false
        }
        guard let acceptedDrop = acceptedFileDrop(fileURLs: fileURLs, placement: placement) else {
            return false
        }
        guard let fileDropHandler else {
            return applyDefaultFileDrop(acceptedDrop)
        }
        scheduleFileDrop(acceptedDrop, handler: fileDropHandler)
        return true
    }

    private func scheduleFileDrop(
        _ acceptedDrop: BlockInputAcceptedFileDrop,
        handler: @escaping BlockInputFileDropHandler
    ) {
        let id = UUID()
        fileDropTasks[id] = Task.detached(priority: .userInitiated) { [weak self, acceptedDrop, handler] in
            let result: BlockInputFileDropResult
            do {
                result = try await handler(acceptedDrop.context)
            } catch {
                result = .cancel
            }
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run { [weak self] in
                guard let self else {
                    return
                }
                fileDropTasks[id] = nil
                guard !Task.isCancelled else {
                    return
                }
                _ = applyFileDropResult(result, acceptedDrop: acceptedDrop)
            }
        }
    }

    private func applyFileDropResult(
        _ result: BlockInputFileDropResult,
        acceptedDrop: BlockInputAcceptedFileDrop
    ) -> Bool {
        guard isEditable else {
            return false
        }
        switch result {
        case .useDefault:
            return applyDefaultFileDrop(acceptedDrop)
        case .cancel:
            return false
        case let .insert(references):
            return applyFileDropReferences(references, acceptedDrop: acceptedDrop)
        }
    }

    private func applyDefaultFileDrop(_ acceptedDrop: BlockInputAcceptedFileDrop) -> Bool {
        applyFileDropReferences(acceptedDrop.context.files.map(\.defaultReference), acceptedDrop: acceptedDrop)
    }

    private func applyFileDropReferences(
        _ references: [BlockInputFileDropReference],
        acceptedDrop: BlockInputAcceptedFileDrop
    ) -> Bool {
        guard fileDropTargetIsStillValid(acceptedDrop) else {
            return false
        }
        let references = references.filter { Self.normalizedDropSource($0.source) != nil }
        guard !references.isEmpty else {
            return false
        }
        switch acceptedDrop.context.placement {
        case let .inline(blockID, utf16Offset):
            let imageReferences = references.filter { $0.kind == .image }
            let fileReferences = references.filter { $0.kind == .fileLink }
            let insertedImages = imageReferences.isEmpty ? nil : insertImageReferences(imageReferences, below: blockID)
            let insertedFiles = fileReferences.isEmpty ? nil : insertFileReferencesInline(
                fileReferences,
                into: blockID,
                atUTF16Offset: utf16Offset
            )
            return insertedImages != nil || insertedFiles != nil
        case .documentEnd:
            let blocks = references.compactMap(Self.block(for:))
            guard !blocks.isEmpty else {
                return false
            }
            return insertDroppedFileBlocks(blocks, at: blockCount) != nil
        }
    }

    private func fileDropTargetIsStillValid(_ acceptedDrop: BlockInputAcceptedFileDrop) -> Bool {
        guard acceptedDrop.storeID == documentStore.map({ ObjectIdentifier($0 as AnyObject) }) else {
            return false
        }
        switch acceptedDrop.context.placement {
        case .documentEnd:
            return !showsProgressiveLoadingRow
        case .inline:
            guard let inlineValidation = acceptedDrop.inlineValidation,
                  let block = block(withID: inlineValidation.blockID) else {
                return false
            }
            return block.kind == inlineValidation.kind &&
                block.text == inlineValidation.text &&
                BlockInputBlockItem.supportsInlineMarkdownStyling(block.kind)
        }
    }

    private static func droppedFile(index: Int, url: URL) -> BlockInputDroppedFile? {
        guard url.isFileURL else {
            return nil
        }
        let kind: BlockInputDroppedFileKind = imageBlock(for: url) == nil ? .fileLink : .image
        let label = kind == .image
            ? url.deletingPathExtension().lastPathComponent
            : (url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)
        return BlockInputDroppedFile(
            index: index,
            url: url,
            defaultKind: kind,
            defaultSource: url.absoluteString,
            defaultLabel: label
        )
    }
}
