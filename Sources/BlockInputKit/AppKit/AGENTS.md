## AppKit Editor Surface

- Keep AppKit editor behavior coordinated through `BlockInputView` and `BlockInputBlockItem` delegates instead of letting child `NSTextView` instances mutate document structure directly.
- Keep live completion UI editor-owned; mounted text views should route completion keys through `BlockInputView`/`BlockInputBlockItem` delegates, while suggestions remain host-provided through `completionProvider`.
- Keep completion overlay hosting explicit: `.overlay` customization should use `BlockInputCompletionPopupConfiguration.overlayProvider`, returning both the popup parent view and the frame in that parent's coordinate space.
- Cover focus, selection, keyboard command, drag/drop, and visual-state changes with mounted AppKit tests when model-only tests could miss visible `NSTextView` or `NSCollectionView` behavior.
- Preserve large-document scrolling assumptions: avoid full layout invalidation for plain scroll-origin changes, and keep item height measurement cached or otherwise bounded to visible/layout-requested rows.
- Preserve progressive store assumptions: render only `loadedBlockCount` blocks, load only the next visible/preloaded batch from the loading row, keep complete save/export snapshots independent from editor row population, and append loaded batches without reloading the full collection.
- For nested horizontal code-block scrolling, route mostly vertical wheel events to the editor scroll view, keep the editor clip-view `x` origin clamped to zero, and keep selection/caret chrome valid after horizontal panning.
- Read the narrower `AGENTS.md` in `BlockItem`, `Mutation`, `Reordering`, and `Selection` before editing files in those scopes.
