## AppKit Editor Surface

- Keep AppKit editor behavior coordinated through `BlockInputView` and `BlockInputBlockItem` delegates instead of letting child `NSTextView` instances mutate document structure directly.
- Route local file drops through mounted text views for inline chip insertion; collection-view file drops are only for appending from bottom blank space, while block-ID drops stay reserved for block reordering.
- Keep live completion UI editor-owned; mounted text views should route completion keys through `BlockInputView`/`BlockInputBlockItem` delegates, while suggestions remain host-provided through `completionProvider`.
- Keep completion overlay hosting explicit: `.overlay` customization should use `BlockInputCompletionPopupConfiguration.overlayProvider`, returning both the popup parent view and the frame in that parent's coordinate space.
- Keep link/image modal overlay hosting explicit: `BlockInputConfiguration.modalOverlayProvider` should return both the modal parent view and frame in that parent's coordinate space.
- Keep host image preview attachments preview-only: open/remove actions should route through `BlockInputImagePreviewAttachment` callbacks, while Markdown-derived preview removals remain the only strip path that edits document text.
- Keep inline link/chip clicks routed through visual hit geometry across the collection view, item root, scroll view, clip view, and text view; first-click behavior must not depend on the text view already being focused.
- Keep inline chip background metrics vertically aligned with partial and whole text selection chrome; selected file-chip snapshots guard this visual contract.
- Cover focus, selection, keyboard command, drag/drop, and visual-state changes with mounted AppKit tests when model-only tests could miss visible `NSTextView` or `NSCollectionView` behavior.
- Preserve large-document scrolling assumptions: avoid full layout invalidation for plain scroll-origin changes, and keep item height measurement cached or otherwise bounded to visible/layout-requested rows.
- Preserve collection-view resize sequencing: when the document/clip width changes, resync visible item frames before any layout pass, keep `NSCollectionViewFlowLayout` out of automatic bounds-change invalidation, and leave a small guard band below the usable width so live resize never validates an item width at the container boundary.
- Preserve progressive store assumptions: render only `loadedBlockCount` blocks, load only the next visible/preloaded batch from the loading row, keep complete save/export snapshots independent from editor row population, and append loaded batches without reloading the full collection.
- For nested horizontal code-block scrolling, route mostly vertical wheel events to the editor scroll view, keep the editor clip-view `x` origin clamped to zero, and keep selection/caret chrome valid after horizontal panning.
- For nested horizontal table scrolling, keep the table scroll view horizontal-only with `y = 0` clip-view protection; forward mostly vertical wheel sequences to the nearest vertical ancestor and keep horizontal-dominant events local.
- Map public table cursor/text selections into a table cell only when the source range is wholly inside one cell; otherwise promote to whole-table/block selection.
- When editing the resize/width path above, verify the focused `BlockInputViewNarrowResizeTests` and zero-width regression tests before considering the change done.
- Read the narrower `AGENTS.md` in `BlockItem`, `Mutation`, `Reordering`, and `Selection` before editing files in those scopes.
