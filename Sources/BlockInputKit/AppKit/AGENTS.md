## AppKit Editor Surface

- Keep AppKit editor behavior coordinated through `BlockInputView` and `BlockInputBlockItem` delegates instead of letting child `NSTextView` instances mutate document structure directly.
- Preserve collection-view reuse assumptions: every item configuration must fully reset text, chrome, selection, drag handles, horizontal-rule state, and callbacks that can survive reuse.
- Keep list marker rendering in `BlockInputMarkerView`; it custom-draws per-line markers so mixed-indent list items do not share one text-field alignment edge.
- Cover focus, selection, keyboard command, drag/drop, and visual-state changes with mounted AppKit tests when model-only tests could miss visible `NSTextView` or `NSCollectionView` behavior.
- Keep document-store synchronization granular when a single block replacement, insertion, deletion, or move accurately describes the mutation; fall back to full document replacement for multi-step structural edits.
- Preserve large-document scrolling assumptions: avoid full layout invalidation for plain scroll-origin changes, and keep item height measurement cached or otherwise bounded to visible/layout-requested rows.
- Suppress item delegate callbacks during programmatic block-item configuration; visible-row reuse in large documents must not report caret movement or force store index rebuilds.
- Keep large-document structural undo/redo on granular store operations when the undo payload describes a single block replacement, insertion, or deletion.
- Publish large-document edit notifications through `onDocumentMutation` for hot paths; keep full `onDocumentChange` snapshots deferred/coalesced so Return, Delete, Undo, and Redo do not read `documentStore.document` synchronously.
- When remapping mounted collection items after large-document insert/delete, resize each item for its new block before manually reflowing visible rows; otherwise mixed paragraph/heading runs can show uneven spacing or clipped text.
- Keep large-document same-row replacements, such as empty quote to paragraph, on mounted item reconfiguration instead of `reloadItems`; benchmark this with `--benchmark-100k-mutations`.
- Keep multiline quote/code exits on granular replacement-plus-insertion operations; pressing Return on an empty inline line should not fall back to full document structural edits.
- For non-large replacement-plus-insertion edits, do not mix `reloadItems` and `insertItems` after the document count has changed; reload the visible layout coherently to avoid overlapping rows.
- Keep front-of-paragraph Backspace/Delete merges granular: replace the previous block and delete the current block.
