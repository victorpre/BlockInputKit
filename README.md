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
    style: BlockInputStyle(
        baseText: BlockInputTextStyle(
            font: .systemFont(ofSize: 16),
            foregroundColor: .labelColor
        ),
        selectionBackgroundColor: .selectedContentBackgroundColor.withAlphaComponent(0.72),
        inlineCode: BlockInputInlineCodeStyle(
            backgroundColor: .quaternaryLabelColor
        ),
        codeBlock: BlockInputCodeBlockStyle(
            font: .monospacedSystemFont(ofSize: 13, weight: .regular),
            cornerRadius: 6
        )
    ),
    undoController: undoController,
    completionProvider: completionProvider,
    slashCommandAvailability: .documentStart,
    completionPopupConfiguration: BlockInputCompletionPopupConfiguration(placement: .caret),
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
- `style`: Configures base text, selection backgrounds, inline code, and fenced code block styling.
- `undoController`: Shares text and structural undo coordination with the host.
- `completionProvider`: Supplies mention and slash-command suggestions.
- `slashCommandAvailability`: Controls whether `/` completion opens only when `/` starts block index `0` at UTF-16 offset `0`, or after token boundaries anywhere.
- `slashCommandChipClickHandler`: Lets the host route slash-command chip clicks to a modal, URL open, or host-owned action.
- `completionPopupConfiguration`: Configures live completion placement. Use `.caret` for a caret-anchored popup, or `.overlay` for a hostable overlay. Overlay placement can provide both the destination parent view and the popup frame inside that parent.
- `onDocumentMutation`: Receives granular edits as they are applied, including marker-only numbered-list updates for marker-adjusting stores.
- `onDocumentChange`: Receives full document snapshots after editor mutations.
- `documentChangeSnapshotDelay`: Coalesces full-document snapshot callbacks for large store-backed documents.
- `onSelectionChange`: Observes cursor, text, and block selection changes.
- `onFocusChange`: Observes AppKit focus changes.

`BlockInputEditor` is the SwiftUI wrapper around `BlockInputView`; pass `isFocused` when SwiftUI state should drive or observe editor focus.

## Completion And File Mentions

`completionProvider` remains the host suggestion API. When it is `nil`, typing `@` or `/` does not open a popup. When it is set, typing `@` in inline-markdown-capable text opens mention completion, and typing `/` opens slash-command completion according to `slashCommandAvailability`. The provider receives `BlockInputCompletionContext.trigger` as `.mention` or `.slashCommand`.

`completionPopupConfiguration.overlayProvider` is optional. Hosts that use `.overlay` can return a `BlockInputCompletionPopupOverlay` containing both:

- `container`: the stable parent `NSView` that should own the popup.
- `frame`: the popup frame in that container's coordinate space.

The provider receives a `BlockInputCompletionPopupOverlayContext` with the editor view, default container, default frame, and popup size. This lets hosts rehost the popup into a larger surface and align it to another view, such as bottom-aligning it inside a transcript viewport. The returned frame must be in the returned container's coordinate space, so choose the container and frame together. When no overlay provider is supplied, the editor falls back to the window content view, then the editor superview, then itself, and anchors the popup above the editor. The older `completionPopupPlacement` initializer parameter remains available as a convenience for setting `completionPopupConfiguration.placement`.

For example, a host can place the overlay at the top of the editor by choosing the editor as the popup container and returning a frame in editor coordinates:

```swift
BlockInputCompletionPopupConfiguration(placement: .overlay) { context in
    let container = context.editorView
    let editorFrame = container.bounds
    let popupHeight = context.popupSize.height
    let y = container.isFlipped
        ? editorFrame.minY + 12
        : editorFrame.maxY - popupHeight - 12
    let frame = NSRect(
        x: editorFrame.minX,
        y: y,
        width: editorFrame.width,
        height: popupHeight
    )
    return BlockInputCompletionPopupOverlay(container: container, frame: frame)
}
```

The context includes:

- `replacementRange`: The UTF-16 source range that accepting a suggestion should replace.
- `rawQuery`: The text after `@` or `/` before editor-owned normalization.
- `fileQuery`: Optional parsed file intent for `.`, `..`, and `...` prefixes. These represent current, parent, and grandparent directory references, with `levelsUp` and `remainder` populated for host resolution. Absolute path queries are preserved in `rawQuery` for hosts that want to resolve `/...` directly.

Hosts can return any `BlockInputCompletionSuggestion`. For file mentions in paragraphs or headings, use `BlockInputCompletionSuggestion.fileLink(fileURL:)` to insert a Markdown file link. The helper escapes link labels and destinations, writes the absolute `file://` destination, and defaults the visible label to the file name. Pass `label:` when a custom label should persist, such as a relative mention:

```markdown
[../README.md](file:///resolved/README.md)
```

File links always render as chips. The Markdown source is preserved for editing and export. File links use the same click behavior as other links: plain click opens the link modal, and Cmd-click opens through the editor URL opener hook.

For slash commands, return suggestions when `context.trigger == .slashCommand`. `.documentStart` only opens when `/` starts block index `0` at UTF-16 offset `0`; `.anywhere` uses the same token boundaries as mentions. `BlockInputCompletionSuggestion.slashCommand(...)` builds Markdown with a host-owned URI and a visible label that starts with `/`:

```swift
BlockInputCompletionSuggestion.slashCommand(
    title: "Insert table",
    uri: "myapp://commands/table",
    label: "table"
)
```

Hosts may also provide custom `insertionText`. A link renders as a slash-command chip when its visible label starts with `/`; the URI scheme is host-owned. `file://` links keep file-chip behavior even when their visible label starts with `/`. Configure `slashCommandChipClickHandler` when slash chips should run host behavior, open their URI directly, or show the built-in link modal.

Dragging local files onto supported text blocks inserts file chips at the drop caret. Paragraphs, headings, quotes, list items, and checklist items accept inline file drops; code, frontmatter, raw Markdown, horizontal rules, row whitespace, and unloaded progressive rows reject them.

## Tables

GFM-style pipe tables parse and render as `.table` blocks. A table requires a header row and delimiter row; body rows are optional. The block stores normalized Markdown in `BlockInputBlock.text`, including delimiter alignment, padded cells, escaped literal `|`, and single-line cell text. Newlines typed or pasted into a cell collapse to spaces on export.

Typing or pasting a complete valid pipe table into an applicable non-table text block converts that whole block into a table. Markdown typed or pasted inside an existing table cell stays cell text and does not recursively create a table.

Cells are editable text views. Bold, italic, underline, strikethrough, Insert Link, Remove Link, URL paste, plain link click, and Cmd-click URL opening use the same inline Markdown mutation and link paths as normal text blocks after the selected source range is proven to be inside one cell. Formatting is not applied to table delimiters, pipes, padding, separator rows, or ranges crossing cells. Mention/slash completion and local file-drop insertion are intentionally disabled inside table cells.

Keyboard behavior inside cells:

- `Tab` and `Shift+Tab` move left-to-right or right-to-left through cells, falling through at table boundaries.
- `Return` and `Shift+Return` move vertically when another cell exists; at table boundaries they insert a paragraph below or above the table.
- Backspace/Delete in an empty body cell selects that row first, then removes it on the next press. Removing the last body row leaves one empty body row. Empty header cells can select the header row, but the header row is not removed.
- `Cmd+A` first selects the current cell contents, then the whole table block, then all blocks.

Right-click menus show table actions directly below `Insert Link`: `Insert Table`, `Delete Row`, `Delete Column`, then `Delete Table`, omitting actions that do not apply. `Insert Table` adds a two-column table below paragraphs, headings, quotes, bulleted lists, numbered lists, and checklists. `Delete Row` is shown only for removable body rows, `Delete Column` only when more than one column exists, and `Delete Table` only inside tables.

Whole-table and mixed selections copy/cut normalized table Markdown. Partial cell selections copy/cut only selected cell text. Public cursor/text selections whose UTF-16 source range is wholly inside one cell focus that cell; selections crossing cells or table syntax become whole-table/block selections. SwiftUI `BlockInputEditor(isFocused:)` restores focus into a table cell when the active selection maps to cell content.

Columns measure content with padding, clamp from `120 pt` to `420 pt`, and wrap after the maximum width. Row height follows the tallest wrapped cell, so typing that wraps cell text resizes the table and moves following blocks immediately. Wide tables use an internal horizontal-only `NSScrollView` with overlay/autohiding scrollers, no vertical elasticity, `y = 0` clip-view protection, and Alveary-matched wheel routing: mostly vertical wheel sequences forward to the nearest vertical editor scroll view while horizontal-dominant events stay local.

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

The demo app provides file mention suggestions from `FileManager.default.currentDirectoryPath`, so suggestions are relative to the directory where the demo is launched. Dot-prefixed queries resolve against current, parent, or grandparent directories, and absolute path queries search from the nearest existing directory. It also provides a small fixed slash-command list with `.anywhere` availability so `/` completion can open after token boundaries in any supported text block. Its toolbar includes a `Caret`/`Overlay` completion placement segmented control. Overlay mode uses `overlayProvider` to top-align the popup inside the editor without reserving extra space above it.

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
