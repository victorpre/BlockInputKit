import SwiftUI

/// SwiftUI wrapper around `BlockInputView`.
public struct BlockInputEditor: NSViewRepresentable {
    private let configuration: BlockInputConfiguration

    public init(configuration: BlockInputConfiguration = BlockInputConfiguration()) {
        self.configuration = configuration
    }

    public func makeNSView(context: Context) -> BlockInputView {
        let view = BlockInputView()
        view.configure(configuration)
        return view
    }

    public func updateNSView(_ nsView: BlockInputView, context: Context) {
        nsView.configure(configuration)
    }
}
