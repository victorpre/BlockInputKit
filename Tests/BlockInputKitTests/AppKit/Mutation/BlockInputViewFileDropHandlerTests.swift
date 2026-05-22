import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputViewFileDropHandlerTests: XCTestCase {
    func testAsyncDropHookInsertsRelativeInlineFileChip() async throws {
        let blockID = BlockInputBlockID(rawValue: "block")
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Open docs")
            ]),
            fileBaseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true),
            fileDropHandler: { context in
                XCTAssertEqual(context.files.map(\.defaultKind), [.fileLink])
                XCTAssertEqual(context.placement, .inline(blockID: blockID, utf16Offset: 5))
                return .insert([
                    BlockInputFileDropReference(kind: .fileLink, source: "assets/README.md", label: "README.md")
                ])
            }
        ))
        let textView = try textView(in: mounted.view)

        XCTAssertTrue(textView.performDragOperation(BlockInputDraggingInfo(
            fileURLs: [URL(fileURLWithPath: "/tmp/README.md")],
            location: try windowLocation(forUTF16Offset: 5, in: textView)
        )))
        await drainFileDropTasks(in: mounted.view)

        XCTAssertEqual(mounted.view.document.blocks[0].text, "Open [README.md](assets/README.md)docs")
        let linkRange = try XCTUnwrap(relativeFileLinkRange(in: mounted.view.document.blocks[0].text, fileBaseURL: mounted.view.fileBaseURL))
        XCTAssertEqual(linkRange.inlineChipKind(in: mounted.view.document.blocks[0].text), .fileLink)
    }

    func testAsyncDropHookInsertsRelativeImageBlock() async throws {
        let blockID = BlockInputBlockID(rawValue: "block")
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: blockID, text: "Before after")
            ]),
            fileDropHandler: { _ in
                .insert([
                    BlockInputFileDropReference(kind: .image, source: "assets/Photo (1).png", label: "Copied")
                ])
            }
        ))
        let textView = try textView(in: mounted.view)

        XCTAssertTrue(textView.performDragOperation(BlockInputDraggingInfo(
            fileURLs: [URL(fileURLWithPath: "/tmp/Photo.png")],
            location: try windowLocation(forUTF16Offset: 6, in: textView)
        )))
        await drainFileDropTasks(in: mounted.view)

        XCTAssertEqual(mounted.view.document.blocks.count, 2)
        XCTAssertEqual(mounted.view.document.blocks[1].kind, .image(BlockInputImage(source: "assets/Photo (1).png", altText: "Copied")))
    }

    func testAsyncDropHookCancelDoesNotMutate() async throws {
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "block", text: "Open docs")
            ]),
            fileDropHandler: { _ in .cancel }
        ))
        let textView = try textView(in: mounted.view)

        XCTAssertTrue(textView.performDragOperation(BlockInputDraggingInfo(
            fileURLs: [URL(fileURLWithPath: "/tmp/README.md")],
            location: try windowLocation(forUTF16Offset: 5, in: textView)
        )))
        await drainFileDropTasks(in: mounted.view)

        XCTAssertEqual(mounted.view.document.blocks[0].text, "Open docs")
    }

    func testAsyncDropHookUseDefaultPreservesBuiltInInsertion() async throws {
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "block", text: "Open docs")
            ]),
            fileDropHandler: { _ in .useDefault }
        ))
        let textView = try textView(in: mounted.view)

        XCTAssertTrue(textView.performDragOperation(BlockInputDraggingInfo(
            fileURLs: [URL(fileURLWithPath: "/tmp/README.md")],
            location: try windowLocation(forUTF16Offset: 5, in: textView)
        )))
        await drainFileDropTasks(in: mounted.view)

        XCTAssertEqual(mounted.view.document.blocks[0].text, "Open [README.md](file:///tmp/README.md)docs")
    }

    private func textView(in view: BlockInputView) throws -> BlockInputTextView {
        let item = try XCTUnwrap(view.visibleBlockItemForTesting(at: 0))
        return try XCTUnwrap(item.testingTextView)
    }

    private func drainFileDropTasks(in view: BlockInputView) async {
        while !view.fileDropTasks.isEmpty {
            await Task.yield()
        }
        await Task.yield()
    }

    private func relativeFileLinkRange(in text: String, fileBaseURL: URL?) -> BlockInputInlineMarkdownRange? {
        BlockInputInlineMarkdownParsing.inlineMarkdownRanges(
            in: text,
            excluding: [],
            fileBaseURL: fileBaseURL
        )
        .first { $0.style == .link }
    }
}
