# BlockInputKit

BlockInputKit is a native Swift library for macOS apps that need structured block editing with AppKit-backed text inputs.

The package is SPM-first and designed around real editable blocks: each block owns text content and editing state, while the root editor coordinates focus, selection, reordering, document changes, and undo.

## Installation

Add BlockInputKit as a Swift Package dependency:

```swift
.package(url: "https://github.com/afollestad/BlockInputKit.git", branch: "main")
```

Then add the library product to your macOS target:

```swift
.product(name: "BlockInputKit", package: "BlockInputKit")
```

## Editor Setup

```swift
import AppKit
import BlockInputKit

let document = BlockInputDocument(blocks: [
    BlockInputBlock(kind: .paragraph, text: "Hello"),
    BlockInputBlock(kind: .quote, text: "Each block owns its own text input.")
])

let store = BlockInputMemoryDocumentStore(document: document)
let undoController = BlockInputUndoController()
let completionProvider: (any BlockInputCompletionProvider)? = nil

let configuration = BlockInputConfiguration(
    documentStore: store,
    allowsBlockReordering: true,
    editorHorizontalInset: 20,
    editorVerticalInset: 8,
    dropIndicatorColor: .systemTeal,
    undoController: undoController,
    completionProvider: completionProvider,
    onDocumentMutation: { change in
        print("Applied edit:", change)
    },
    onDocumentChange: { updatedDocument in
        // Full snapshots are useful for persistence, export, and small documents.
        print(updatedDocument.markdown)
    },
    onSelectionChange: { selection in
        print("Selection:", String(describing: selection))
    },
    onFocusChange: { focused in
        print("Focused:", focused)
    }
)
```

## AppKit

```swift
let editor = BlockInputView()
editor.configure(configuration)
```

## SwiftUI

```swift
import BlockInputKit
import SwiftUI

struct EditorScreen: View {
    let configuration: BlockInputConfiguration
    @State private var isEditorFocused = false

    var body: some View {
        BlockInputEditor(
            configuration: configuration,
            isFocused: $isEditorFocused
        )
    }
}
```

## Configuration Options

`BlockInputConfiguration` accepts these host integration options:

- `document`: Initial in-memory document when no custom store is supplied.
- `documentStore`: Host-owned source of truth for block reads and mutations.
- `allowsBlockReordering`: Enables or disables drag reordering.
- `editorHorizontalInset`: Controls the leading and trailing block content inset.
- `editorVerticalInset`: Controls the top and bottom editor content inset.
- `dropIndicatorColor`: Colors drag insertion and selected horizontal-rule affordances.
- `undoController`: Shares text and structural undo coordination with the host.
- `completionProvider`: Supplies mention and slash-command suggestions.
- `onDocumentMutation`: Receives granular edits as they are applied, including marker-only numbered-list updates for marker-adjusting stores.
- `onDocumentChange`: Receives full document snapshots after editor mutations.
- `documentChangeSnapshotDelay`: Coalesces full-document snapshot callbacks for large store-backed documents.
- `onSelectionChange`: Observes cursor, text, and block selection changes.
- `onFocusChange`: Observes AppKit focus changes.

`BlockInputEditor` is the SwiftUI wrapper around `BlockInputView`; pass `isFocused` when SwiftUI state should drive or observe editor focus.

## Markdown Streaming

Use the async Markdown APIs when reading or writing files. File reads are UTF-8 line-by-line, and streaming writes emit chunks in block order without first converting the document to one full Markdown string. Streaming deserialization buffers only the current block and any lookahead needed to match snapshot import behavior; leading frontmatter is retained as a `frontMatter` block, and unsupported block-level constructs are retained as `rawMarkdown` blocks rather than discarded.

Rendered text blocks visually style inline Markdown while preserving the source text for editing and export. Paragraphs, headings, quotes, list items, and checklist items support `*italic text*`, `_italic text_`, `**bold text**`, `***bold italic text***`, `<u>underlined text</u>`, `<ins>underlined text</ins>`, `~~struck text~~`, and inline code spans. Supported spans can also be nested, such as `**_bold italic text_**`, `**<u>bold underlined text</u>**`, and `~~*struck italic text*~~`.

```swift
let url = URL(filePath: "/tmp/note.md")
let document = try await BlockInputDocument.readingMarkdown(from: url)
try await document.writeMarkdown(to: url)

let parsed = await BlockInputDocument.parsingMarkdown("# Heading")
let markdown = await parsed.markdownSnapshot()
```

Custom storage can implement the streaming protocols directly:

```swift
struct DatabaseLineReader: BlockInputMarkdownLineReader {
    mutating func readMarkdownLine() async throws -> String? {
        // Return the next logical line without its trailing line ending, or nil at EOF.
        nil
    }
}

struct ChunkWriter: BlockInputMarkdownWriter {
    mutating func writeMarkdown(_ chunk: String) async throws {
        // Persist this chunk immediately; do not buffer the whole document.
    }
}

var reader = DatabaseLineReader()
let streamed = try await BlockInputDocument.readMarkdown(from: &reader)

var writer = ChunkWriter()
try await streamed.writeMarkdown(to: &writer)
```

## Demo

Run the local demo:

```sh
./scripts/run-demo.sh
```

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
