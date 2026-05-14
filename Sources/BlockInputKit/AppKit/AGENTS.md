## AppKit Editor Surface

- Keep AppKit editor behavior coordinated through `BlockInputView` and `BlockInputBlockItem` delegates instead of letting child `NSTextView` instances mutate document structure directly.
- Cover focus, selection, keyboard command, drag/drop, and visual-state changes with mounted AppKit tests when model-only tests could miss visible `NSTextView` or `NSCollectionView` behavior.
- Preserve large-document scrolling assumptions: avoid full layout invalidation for plain scroll-origin changes, and keep item height measurement cached or otherwise bounded to visible/layout-requested rows.
- Read the narrower `AGENTS.md` in `BlockItem`, `Mutation`, `Reordering`, and `Selection` before editing files in those scopes.
