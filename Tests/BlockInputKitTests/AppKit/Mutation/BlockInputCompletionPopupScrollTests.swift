import AppKit
import XCTest
@testable import BlockInputKit

@MainActor
final class BlockInputCompletionPopupScrollTests: XCTestCase {
    func testPopupCentersHighlightedSuggestionWhenConfigured() {
        let popup = makePopup(suggestions: popupFileSuggestions(count: 12), highlightedIndex: 7)

        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting, [
            "File4.md",
            "File5.md",
            "File6.md",
            "File7.md",
            "File8.md",
            "File9.md"
        ])
        XCTAssertEqual(popup.visibleSuggestionIndexesForTesting, [4, 5, 6, 7, 8, 9])
    }

    func testPopupSessionChangeResetsVisibleWindowForSameSuggestionIDs() {
        let suggestions = popupFileSuggestions(count: 8)
        let popup = makePopup(suggestions: suggestions, sessionID: UUID())
        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: -1)
        ))
        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting.first, "File1.md")

        popup.configure(
            state: BlockInputCompletionPopupState(
                suggestions: suggestions,
                highlightedIndex: 0,
                isLoading: false,
                sessionID: UUID()
            ),
            onSelect: { _ in },
            onHighlight: { _ in }
        )

        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting.first, "File0.md")
    }

    func testPopupRowScrollWheelRoutesToPopup() throws {
        let popup = makePopup(suggestions: popupFileSuggestions(count: 8))
        let row = try rowView(label: "File5.md", in: popup)

        row.scrollWheel(with: TestScrollWheelEvent(deltaY: -1))

        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting.first, "File1.md")
    }

    func testPopupChromeScrollWheelRoutesToPopup() {
        let popup = makePopup(suggestions: popupFileSuggestions(count: 8))

        popup.scrollWheel(with: TestScrollWheelEvent(deltaY: -1))

        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting.first, "File1.md")
    }

    func testPopupConsumesBoundaryAndHorizontalWheelEvents() {
        let popup = makePopup(
            suggestions: popupFileSuggestions(count: 8),
            onHighlight: { _ in XCTFail("Boundary wheel should not change highlight") }
        )

        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: 1)
        ))
        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: 0, deltaX: 8)
        ))
        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting.first, "File0.md")
    }

    func testPopupConsumesWheelEventsWhenNotScrollable() {
        let popup = makePopup(suggestions: popupFileSuggestions(count: 2))
        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: -1)
        ))
        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: 0)
        ))

        popup.configure(
            state: BlockInputCompletionPopupState(suggestions: [], highlightedIndex: 0, isLoading: false),
            onSelect: { _ in },
            onHighlight: { _ in }
        )
        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: -1)
        ))

        popup.configure(
            state: BlockInputCompletionPopupState(suggestions: [], highlightedIndex: 0, isLoading: true),
            onSelect: { _ in },
            onHighlight: { _ in }
        )
        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: -1)
        ))
    }

    func testPopupUsesDeltaYFallbackForWheelDirection() {
        let popup = makePopup(suggestions: popupFileSuggestions(count: 8))

        XCTAssertTrue(popup.routeScrollWheel(
            at: NSPoint(x: popup.bounds.midX, y: popup.bounds.midY),
            event: TestScrollWheelEvent(deltaY: 0, fallbackDeltaY: -1)
        ))

        XCTAssertEqual(popup.visibleSuggestionTitlesForTesting.first, "File1.md")
    }

    func testInitialStationaryHoverDoesNotSelectBottomRowWhenLoadingResolves() throws {
        let window = CompletionPopupMouseLocationWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 256),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        let popup = BlockInputCompletionPopupView(frame: NSRect(x: 0, y: 0, width: 320, height: 256))
        window.contentView = popup
        let sessionID = UUID()
        popup.configure(
            state: BlockInputCompletionPopupState(suggestions: [], highlightedIndex: 0, isLoading: true, sessionID: sessionID),
            onSelect: { _ in },
            onHighlight: { _ in }
        )
        let bottomRowWindowPoint = NSPoint(x: 80, y: 28)
        window.testMouseLocationOutsideOfEventStream = bottomRowWindowPoint

        popup.configure(
            state: BlockInputCompletionPopupState(
                suggestions: popupFileSuggestions(count: 8),
                highlightedIndex: 0,
                isLoading: false,
                sessionID: sessionID
            ),
            onSelect: { _ in },
            onHighlight: { _ in XCTFail("Stationary hover should not update highlight") }
        )
        popup.layoutSubtreeIfNeeded()
        let bottomRow = try rowView(label: "File5.md", in: popup)
        bottomRow.mouseEntered(with: try mouseMovedEvent(location: bottomRowWindowPoint, windowNumber: window.windowNumber))
    }

    private func makePopup(
        suggestions: [BlockInputCompletionSuggestion],
        highlightedIndex: Int = 0,
        sessionID: UUID = UUID(),
        onHighlight: @escaping (Int) -> Void = { _ in }
    ) -> BlockInputCompletionPopupView {
        let popup = BlockInputCompletionPopupView(frame: NSRect(x: 0, y: 0, width: 320, height: 256))
        popup.configure(
            state: BlockInputCompletionPopupState(
                suggestions: suggestions,
                highlightedIndex: highlightedIndex,
                isLoading: false,
                sessionID: sessionID
            ),
            onSelect: { _ in },
            onHighlight: onHighlight
        )
        popup.layoutSubtreeIfNeeded()
        return popup
    }

    private func rowView(label: String, in popup: NSView) throws -> NSView {
        try XCTUnwrap(popup.subviews.first { $0.accessibilityLabel() == label })
    }

    private func popupFileSuggestions(count: Int) -> [BlockInputCompletionSuggestion] {
        (0..<count).map { index in
            .fileLink(label: "File\(index).md", fileURL: URL(fileURLWithPath: "/tmp/File\(index).md"))
        }
    }
}
