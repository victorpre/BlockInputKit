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
    dropIndicatorColor: .systemTeal,
    undoController: undoController,
    onDocumentMutation: { change in
        print("Applied edit:", change)
    },
    onDocumentChange: { updatedDocument in
        // Full snapshots are useful for persistence, export, and small documents.
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

- A native sidebar with `Mixed` and `100K` notes.
- A main editor area that can switch between editable raw Markdown and rendered structured blocks.
- A runtime reordering toggle for rendered blocks.
- Mixed paragraph, heading, divider, code, quote, list, numbered list, and checklist data.
- A 100,000-block note for exercising large-document behavior.

## Architecture

- `BlockInputDocument` is the structured document model and Markdown source of truth.
- `BlockInputBlock` models a stable block ID, kind, text, and indentation level.
- `BlockInputView` is the primary AppKit editor surface.
- `BlockInputEditor` wraps `BlockInputView` for SwiftUI hosts and can bridge focus with `Binding<Bool>`.
- `BlockInputDocumentStore` lets hosts provide indexed block reads plus granular block mutations.
- `BlockInputCompletionProvider` keeps mention and slash-command suggestions host-owned.
- `BlockInputUndoController` separates per-block text undo from structural undo.

## Project Layout

- `Sources/BlockInputKit/Core`: document, block, selection, typing shortcut, and store primitives.
- `Sources/BlockInputKit/AppKit`: primary editor surface, with topical subfolders for block items, mutations, reordering, and selection behavior.
- `Sources/BlockInputKit/Markdown`, `Completion`, `Undo`, `SwiftUI`, and `Support`: feature-specific library areas.
- `Sources/BlockInputKitDemo`: demo app for exercising library behavior.
- `Tests/BlockInputKitTests` mirrors the same high-level source areas for focused coverage.

## Current Behavior

- Return inserts a paragraph below paragraph-like blocks; list, checklist, quote, and code blocks can keep editing
  inside the same block, and empty inline items exit to a paragraph below.
- Backspace/Delete removes an empty block and moves focus to the previous block end, or the next remaining block.
- Cmd+A first selects the current block text, then all blocks.
- Tab and Shift+Tab indent and outdent blocks.
- Arrow movement crosses block boundaries at the start or end of a block.
- Markdown typing shortcuts convert leading quote, list, checklist, numbered-list, heading, and `---` markers into block kinds.
- Backspace/Delete at the front of formatted blocks unwraps them into paragraph text with the Markdown marker visible.
- Drag reordering is enabled by default and can be disabled with `allowsBlockReordering`.
- Drag insertion and selected horizontal-rule colors default to the system accent color and can be customized with `dropIndicatorColor`.
- Clicking a horizontal rule selects the rule; Backspace/Delete removes the selected rule block.
- Markdown import/export supports paragraph, heading, horizontal rule, code, quote, bulleted list, numbered list, and checklist blocks.
- File URL insertion helpers and built-in file drops create Markdown link blocks.

## Performance Expectations

BlockInputKit is designed for large documents. The AppKit surface uses `NSCollectionView` so visible items are reused instead of mounting every block view at once. `BlockInputDocumentStore` supports indexed block reads for rendering; large host stores should make `block(at:)`, `block(withID:)`, and `index(of:)` cheap. Common editor edits publish granular store mutations for block replacement, insertion, deletion, and movement through `onDocumentMutation`; use that callback for immediate host syncing in large documents. `onDocumentChange` publishes full document snapshots, and large store-backed editors defer and coalesce those snapshots so hot edit paths do not synchronously materialize every block. Broad structural undo/redo can still publish a full document replacement. The demo includes a 100,000-block loading path to keep large-document behavior visible during development.

## Validation

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/lint.sh
```

## Snapshot Tests

Verify the representative AppKit snapshot suite:

```sh
./scripts/snapshots.sh verify
```

Verify or record a focused snapshot test:

```sh
./scripts/snapshots.sh verify BlockInputKitTests/BlockInputViewSnapshotTests
./scripts/snapshots.sh record BlockInputKitTests/BlockInputViewSnapshotTests
```

When no test identifier is provided, `./scripts/snapshots.sh` defaults to `BlockInputKitTests/BlockInputViewSnapshotTests`.

## License

BlockInputKit is licensed under the [GNU Lesser General Public License v3.0](LICENSE.txt).
