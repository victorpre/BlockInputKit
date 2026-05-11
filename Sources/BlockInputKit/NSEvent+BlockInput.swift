import AppKit

extension NSEvent {
    var blockInputIsSelectAllShortcut: Bool {
        modifierFlags.contains(.command)
            && !modifierFlags.contains(.option)
            && !modifierFlags.contains(.control)
            && !modifierFlags.contains(.shift)
            && charactersIgnoringModifiers?.lowercased() == "a"
    }
}
