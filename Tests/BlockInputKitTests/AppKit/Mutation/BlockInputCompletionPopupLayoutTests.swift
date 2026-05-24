import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputCompletionPopupLayoutTests: XCTestCase {
    func testPopupRowGivesDetailTextEnoughWidth() async throws {
        let provider = PopupCompletionProvider(suggestions: [
            .slashCommand(
                id: "heading",
                title: "Heading",
                uri: "demo://heading",
                label: "heading",
                detailText: "Command"
            )
        ])
        let mounted = try await startCompletion(text: "/", provider: provider)
        let popup = try XCTUnwrap(mounted.view.completionPopupView)
        popup.layoutSubtreeIfNeeded()

        let row = try rowView(label: "Heading, Command", in: popup)
        let detailField = try textField(label: "Command", in: row)

        XCTAssertGreaterThanOrEqual(detailField.frame.width, ceil(detailField.intrinsicContentSize.width) + 4)
        XCTAssertEqual(detailField.lineBreakMode, .byTruncatingTail)
    }

    private func startCompletion(
        text: String,
        provider: any BlockInputCompletionProvider
    ) async throws -> (view: BlockInputView, window: NSWindow) {
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "block", text: text)
            ]),
            completionProvider: provider
        ))
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        mounted.view.refreshCompletionSession(item: item, blockID: "block")
        await mounted.view.completionRequestTask?.value
        mounted.view.layoutSubtreeIfNeeded()
        return mounted
    }

    private func rowView(label: String, in popup: NSView) throws -> NSView {
        try XCTUnwrap(popup.subviews.first { $0.accessibilityLabel() == label })
    }

    private func textField(label: String, in row: NSView) throws -> NSTextField {
        try XCTUnwrap(row.subviews.compactMap { $0 as? NSTextField }.first { $0.stringValue == label })
    }
}
