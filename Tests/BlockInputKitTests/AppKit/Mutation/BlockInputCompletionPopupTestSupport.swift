import AppKit
import Darwin
@testable import BlockInputKit

final class TestScrollWheelEvent: NSEvent {
    private let testScrollingDeltaY: CGFloat

    init(deltaY: CGFloat) {
        testScrollingDeltaY = deltaY
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var scrollingDeltaY: CGFloat {
        testScrollingDeltaY
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
