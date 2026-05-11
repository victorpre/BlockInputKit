## AppKit Editor Surface

- Keep AppKit editor behavior coordinated through `BlockInputView` and `BlockInputBlockItem` delegates instead of letting child `NSTextView` instances mutate document structure directly.
- Preserve collection-view reuse assumptions: every item configuration must fully reset text, chrome, selection, drag handles, horizontal-rule state, and callbacks that can survive reuse.
- Keep list marker rendering in `BlockInputMarkerView`; it custom-draws per-line markers so mixed-indent list items do not share one text-field alignment edge.
- Cover focus, selection, keyboard command, drag/drop, and visual-state changes with mounted AppKit tests when model-only tests could miss visible `NSTextView` or `NSCollectionView` behavior.
- Keep document-store synchronization granular when a single block replacement, insertion, deletion, or move accurately describes the mutation; fall back to full document replacement for multi-step structural edits.
