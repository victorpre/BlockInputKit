import AppKit

enum BlockInputUndoShortcut {
    case undo
    case redo
}

enum BlockInputEditingShortcut {
    case copy
    case cut
    case paste
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

    var blockInputEditingShortcut: BlockInputEditingShortcut? {
        guard modifierFlags.contains(.command),
              !modifierFlags.contains(.option),
              !modifierFlags.contains(.control),
              !modifierFlags.contains(.shift) else {
            return nil
        }
        switch charactersIgnoringModifiers?.lowercased() {
        case "c":
            return .copy
        case "x":
            return .cut
        case "v":
            return .paste
        default:
            return nil
        }
    }
}
