## Block Item Reuse

- Preserve collection-view reuse assumptions: every item configuration must fully reset text, chrome, selection, drag handles, horizontal-rule state, and callbacks that can survive reuse.
- Suppress item delegate callbacks during programmatic block-item configuration; visible-row reuse in large documents must not report caret movement or force store index rebuilds.

## Chrome And Metrics

- Keep list marker rendering in `BlockInputMarkerView`; it custom-draws per-line markers so mixed-indent list items do not share one text-field alignment edge.
- Keep code-block background and whole-block selection widths aligned; code surfaces hug content with the AppKit code-surface minimum instead of filling the full row.
- Keep item height measurement cached or otherwise bounded to visible/layout-requested rows.
- When shared row chrome metrics, default insets, or marker alignment change, record and verify the AppKit snapshot suite.
