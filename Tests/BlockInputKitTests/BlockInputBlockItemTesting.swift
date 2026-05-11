import AppKit
@testable import BlockInputKit

extension BlockInputBlockItem {
    static func configuredForTesting(
        block: BlockInputBlock,
        allowsReordering: Bool,
        delegate: BlockInputBlockItemDelegate
    ) -> BlockInputBlockItem {
        let item = BlockInputBlockItem()
        item.loadView()
        item.viewDidLoad()
        item.configure(block: block, allowsReordering: allowsReordering, delegate: delegate)
        return item
    }

    var testingTextView: BlockInputTextView? {
        view.firstDescendant(of: BlockInputTextView.self)
    }

    var testingHandleView: NSTextField? {
        view.firstDescendant(of: NSTextField.self) { textField in
            textField.stringValue == "::"
        }
    }

    var testingChecklistButton: NSButton? {
        view.firstDescendant(of: NSButton.self) { button in
            button.toolTip == "Toggle checklist item"
        }
    }

    var testingHorizontalRuleView: NSView? {
        view.firstDescendant(of: NSView.self) { view in
            view.identifier?.rawValue == "BlockInputHorizontalRuleView"
        }
    }
}

private extension NSView {
    func firstDescendant<View: NSView>(
        of type: View.Type,
        where matches: (View) -> Bool = { _ in true }
    ) -> View? {
        if let view = self as? View, matches(view) {
            return view
        }
        for subview in subviews {
            if let match = subview.firstDescendant(of: type, where: matches) {
                return match
            }
        }
        return nil
    }
}
