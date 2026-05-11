import AppKit
@testable import BlockInputKit

extension BlockInputBlockItem {
    static func configuredForTesting(
        block: BlockInputBlock,
        allowsReordering: Bool,
        isSelected: Bool = false,
        delegate: BlockInputBlockItemDelegate
    ) -> BlockInputBlockItem {
        let item = BlockInputBlockItem()
        item.loadView()
        item.viewDidLoad()
        item.configure(
            block: block,
            allowsReordering: allowsReordering,
            accentColor: .controlAccentColor,
            isSelected: isSelected,
            delegate: delegate
        )
        return item
    }

    var testingTextView: BlockInputTextView? {
        view.firstDescendant(of: BlockInputTextView.self)
    }

    var testingTextScrollView: NSScrollView? {
        view.firstDescendant(of: NSScrollView.self)
    }

    var testingHandleView: NSTextField? {
        view.firstDescendant(of: NSTextField.self) { textField in
            textField.stringValue == "::"
        }
    }

    var testingKindLabel: NSTextField? {
        let handleView = testingHandleView
        return view.firstDescendant(of: NSTextField.self) { textField in
            guard let handleView else {
                return true
            }
            return textField !== handleView
        }
    }

    var testingHandleWidthConstraint: NSLayoutConstraint? {
        guard let handleView = testingHandleView else {
            return nil
        }
        return (handleView.constraints + view.constraints).first { constraint in
            (constraint.firstItem as? NSView) === handleView
                && constraint.firstAttribute == .width
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

    var testingHorizontalRuleSelectionView: BlockInputHorizontalRuleView? {
        view.firstDescendant(of: BlockInputHorizontalRuleView.self)
    }
}

extension BlockInputHorizontalRuleView {
    var testingLineView: NSView? {
        subviews.first
    }

    var testingLineHeight: CGFloat? {
        testingLineView?.constraints.first { constraint in
            constraint.firstAttribute == .height
        }?.constant
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
