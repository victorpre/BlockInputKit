import AppKit

enum DemoEditorMode: Int, CaseIterable {
    case raw
    case rendered

    var title: String {
        switch self {
        case .raw:
            "Raw"
        case .rendered:
            "Rendered"
        }
    }

    var segment: Int {
        rawValue
    }

    init?(segment: Int) {
        self.init(rawValue: segment)
    }
}

let sidebarColumnIdentifier = NSUserInterfaceItemIdentifier("DemoNoteColumn")
let sidebarCellIdentifier = NSUserInterfaceItemIdentifier("DemoNoteCell")
