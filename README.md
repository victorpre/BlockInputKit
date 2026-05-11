# BlockInputKit

BlockInputKit is a native Swift library for macOS apps that need structured block editing with AppKit-backed text inputs.

The package is SPM-first, targets macOS 26, and is designed around real editable blocks: each block owns text content and editing state, while the root editor coordinates focus, selection, reordering, document changes, and undo.

## Installation

Add BlockInputKit as a Swift Package dependency:

```swift
.package(url: "https://github.com/afollestad/BlockInputKit.git", branch: "main")
```

Then add the library product to your macOS target:

```swift
.product(name: "BlockInputKit", package: "BlockInputKit")
```

## AppKit

```swift
import AppKit
import BlockInputKit

let document = BlockInputDocument(blocks: [
    BlockInputBlock(kind: .paragraph, text: "Hello"),
    BlockInputBlock(kind: .quote, text: "Each block owns its own text input.")
])

let store = BlockInputMemoryDocumentStore(document: document)
let undoController = BlockInputUndoController()
let editor = BlockInputView()

editor.configure(BlockInputConfiguration(
    documentStore: store,
    allowsBlockReordering: true,
    undoController: undoController,
    onDocumentChange: { updatedDocument in
        print(updatedDocument.markdown)
    }
))
```

## SwiftUI

```swift
import BlockInputKit
import SwiftUI

struct EditorScreen: View {
    private let store = BlockInputMemoryDocumentStore(document: BlockInputDocument(markdown: "- [ ] Ship it"))
    @State private var isEditorFocused = false

    var body: some View {
        BlockInputEditor(
            configuration: BlockInputConfiguration(documentStore: store),
            isFocused: $isEditorFocused
        )
    }
}
```

## Demo

Run the local demo:

```sh
./scripts/run-demo.sh
```

The demo app includes:

- A primary `BlockInputView` editor surface.
- Mixed paragraph, code, quote, list, numbered list, and toggleable checklist data.
- A 100,000-block load path for exercising large-document behavior.
- Markdown import/export, Markdown insertion, and file-link insertion helpers.
- Text and structural undo/redo buttons.
- Hover reorder handles and a runtime reordering toggle.
- Host-provided mention and slash-command completion samples, including accepted-suggestion insertion.
- A SwiftUI `BlockInputEditor` preview with focus-binding controls embedded beside the AppKit editor.

## Architecture

- `BlockInputDocument` is the structured document model and Markdown source of truth.
- `BlockInputBlock` models a stable block ID, kind, text, and indentation level.
- `BlockInputView` is the primary AppKit editor surface.
- `BlockInputEditor` wraps `BlockInputView` for SwiftUI hosts and can bridge focus with `Binding<Bool>`.
- `BlockInputDocumentStore` lets hosts provide indexed block reads plus granular block mutations.
- `BlockInputCompletionProvider` keeps mention and slash-command suggestions host-owned.
- `BlockInputUndoController` separates per-block text undo from structural undo.

## Current Behavior

- Return inserts a new paragraph block below the active block.
- Backspace/Delete removes an empty block and moves focus to the previous block end, or the next remaining block.
- Cmd+A first selects the current block text, then all blocks.
- Tab and Shift+Tab indent and outdent blocks.
- Arrow movement crosses block boundaries at the start or end of a block.
- Drag reordering is enabled by default and can be disabled with `allowsBlockReordering`.
- Markdown import/export supports paragraph, code, quote, bulleted list, numbered list, and checklist blocks.
- File URL insertion helpers create Markdown link blocks for host paste or drop handlers.

## Performance Expectations

BlockInputKit is designed for large documents. The AppKit surface uses `NSCollectionView` so visible items are reused instead of mounting every block view at once, and `BlockInputDocumentStore` supports indexed block reads for rendering. Common editor edits publish granular store mutations for block replacement, insertion, deletion, and movement; broad structural undo/redo can still publish a full document replacement. The demo includes a 100,000-block loading path to keep large-document behavior visible during development.

## Validation

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/lint.sh
```

## License

BlockInputKit is licensed under the [GNU Lesser General Public License v3.0](LICENSE.txt).
