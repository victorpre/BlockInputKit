import AppKit
import SwiftUI

public enum BlockInputKit {
    public static let version = "0.1.0"
}

public final class BlockInputView: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

public struct BlockInputEditor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> BlockInputView {
        BlockInputView()
    }

    public func updateNSView(_ nsView: BlockInputView, context: Context) {}
}
