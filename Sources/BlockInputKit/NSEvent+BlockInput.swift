import AppKit

enum BlockInputUndoShortcut {
    case undo
    case redo
}

extension NSEvent {
    var blockInputIsSelectAllShortcut: Bool {
        modifierFlags.contains(.command)
            && !modifierFlags.contains(.option)
            && !modifierFlags.contains(.control)
            && !modifierFlags.contains(.shift)
            && charactersIgnoringModifiers?.lowercased() == "a"
    }

    var blockInputUndoShortcut: BlockInputUndoShortcut? {
        guard modifierFlags.contains(.command),
              !modifierFlags.contains(.option),
              !modifierFlags.contains(.control),
              charactersIgnoringModifiers?.lowercased() == "z" else {
            return nil
        }
        return modifierFlags.contains(.shift) ? .redo : .undo
    }
}
