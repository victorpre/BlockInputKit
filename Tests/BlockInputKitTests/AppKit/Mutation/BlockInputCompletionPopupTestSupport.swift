import AppKit
import Darwin
@testable import BlockInputKit

final class TestScrollWheelEvent: NSEvent {
    private weak var testWindow: NSWindow?
    private let testWindowNumber: Int
    private let testLocationInWindow: NSPoint
    private let testScrollingDeltaY: CGFloat
    private let testScrollingDeltaX: CGFloat
    private let testDeltaY: CGFloat

    init(
        window: NSWindow? = nil,
        windowNumber: Int = 0,
        location: NSPoint = .zero,
        deltaY: CGFloat,
        deltaX: CGFloat = 0,
        fallbackDeltaY: CGFloat? = nil
    ) {
        testWindow = window
        testWindowNumber = windowNumber
        testLocationInWindow = location
        testScrollingDeltaY = deltaY
        testScrollingDeltaX = deltaX
        testDeltaY = fallbackDeltaY ?? deltaY
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var scrollingDeltaY: CGFloat {
        testScrollingDeltaY
    }

    override var scrollingDeltaX: CGFloat {
        testScrollingDeltaX
    }

    override var deltaY: CGFloat {
        testDeltaY
    }

    override var type: NSEvent.EventType {
        .scrollWheel
    }

    override var window: NSWindow? {
        testWindow
    }

    override var windowNumber: Int {
        testWindowNumber
    }

    override var locationInWindow: NSPoint {
        testLocationInWindow
    }
}

final class CompletionPopupMouseLocationWindow: NSWindow {
    var testMouseLocationOutsideOfEventStream: NSPoint = .zero

    override var mouseLocationOutsideOfEventStream: NSPoint {
        testMouseLocationOutsideOfEventStream
    }
}

final class PopupCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    private let suggestions: [BlockInputCompletionSuggestion]
    private(set) var contexts: [BlockInputCompletionContext] = []

    var lastContext: BlockInputCompletionContext? {
        contexts.last
    }

    init(suggestions: [BlockInputCompletionSuggestion]) {
        self.suggestions = suggestions
    }

    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        contexts.append(context)
        return suggestions
    }
}

final class ThreadCapturingPopupCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    private let suggestions: [BlockInputCompletionSuggestion]
    private(set) var requestRanOnMainThread: Bool?

    init(suggestions: [BlockInputCompletionSuggestion]) {
        self.suggestions = suggestions
    }

    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        requestRanOnMainThread = pthread_main_np() == 1
        return suggestions
    }
}

final class DelayedPopupCompletionProvider: BlockInputCompletionProvider, @unchecked Sendable {
    private let suggestions: [BlockInputCompletionSuggestion]
    private var continuation: CheckedContinuation<[BlockInputCompletionSuggestion], Never>?

    var isWaiting: Bool {
        continuation != nil
    }

    init(suggestions: [BlockInputCompletionSuggestion]) {
        self.suggestions = suggestions
    }

    func suggestions(for context: BlockInputCompletionContext) async -> [BlockInputCompletionSuggestion] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume(returning: suggestions)
        continuation = nil
    }
}
