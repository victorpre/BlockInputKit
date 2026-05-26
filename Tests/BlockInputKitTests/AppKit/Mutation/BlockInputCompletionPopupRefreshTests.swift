import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputCompletionPopupRefreshTests: XCTestCase {
    func testOverlayPopupKeepsRowsVisibleWhileQueryRefreshes() async throws {
        let provider = DelayedRefreshPopupCompletionProvider(initialSuggestions: [
            .fileLink(label: "README.md", fileURL: URL(fileURLWithPath: "/tmp/README.md"))
        ])
        let mounted = try await startCompletion(text: "@read", provider: provider)
        let popup = try XCTUnwrap(mounted.view.completionPopupView)
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)

        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting, ["README.md"])

        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.insertText("m", replacementRange: textView.selectedRange())
        while !provider.isWaitingForRefresh {
            await Task.yield()
        }

        XCTAssertTrue(mounted.view.completionPopupView === popup)
        XCTAssertEqual(mounted.view.completionSession?.token.query, "readm")
        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting, ["README.md"])

        provider.resumeRefresh(with: [
            .fileLink(label: "README-more.md", fileURL: URL(fileURLWithPath: "/tmp/README-more.md"))
        ])
        await mounted.view.completionRequestTask?.value

        XCTAssertTrue(mounted.view.completionPopupView === popup)
        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting, ["README-more.md"])
    }

    func testOverlayPopupShowsLoadingDuringEmptyQueryRefresh() async throws {
        let provider = DelayedRefreshPopupCompletionProvider(initialSuggestions: [])
        let mounted = try await startCompletion(text: "@missing", provider: provider)
        let popup = try XCTUnwrap(mounted.view.completionPopupView)
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)

        XCTAssertEqual(mounted.view.completionSession?.isLoading, false)
        XCTAssertTrue(try loadingField(in: popup).isHidden)
        XCTAssertFalse(try emptyField(in: popup).isHidden)

        mounted.window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.insertText("x", replacementRange: textView.selectedRange())
        while !provider.isWaitingForRefresh {
            await Task.yield()
        }

        XCTAssertEqual(mounted.view.completionSession?.isLoading, true)
        XCTAssertFalse(try loadingField(in: popup).isHidden)
        XCTAssertTrue(try emptyField(in: popup).isHidden)

        provider.resumeRefresh(with: [])
        await mounted.view.completionRequestTask?.value

        XCTAssertEqual(mounted.view.completionSession?.isLoading, false)
        XCTAssertTrue(try loadingField(in: popup).isHidden)
        XCTAssertFalse(try emptyField(in: popup).isHidden)
    }

    private func startCompletion(
        text: String,
        provider: any BlockInputCompletionProvider
    ) async throws -> (view: BlockInputView, window: NSWindow) {
        let mounted = makeMountedBlockInputView(configuration: BlockInputConfiguration(
            document: BlockInputDocument(blocks: [
                BlockInputBlock(id: "block", text: text)
            ]),
            completionProvider: provider,
            completionPopupPlacement: .overlay
        ))
        let item = try XCTUnwrap(mounted.view.visibleBlockItemForTesting(at: 0))
        let textView = try XCTUnwrap(item.testingTextView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        mounted.view.refreshCompletionSession(item: item, blockID: "block")
        await mounted.view.completionRequestTask?.value
        mounted.view.layoutSubtreeIfNeeded()
        return mounted
    }

    private func loadingField(in popup: BlockInputCompletionPopupView) throws -> NSTextField {
        try textField("Loading suggestions...", in: popup)
    }

    private func emptyField(in popup: BlockInputCompletionPopupView) throws -> NSTextField {
        try textField("No matches", in: popup)
    }

    private func textField(_ value: String, in popup: BlockInputCompletionPopupView) throws -> NSTextField {
        try XCTUnwrap(popup.subviews.compactMap { $0 as? NSTextField }.first { $0.stringValue == value })
    }
}
