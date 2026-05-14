## Syntax Highlighting

- Keep the lite highlighter dependency-free and regex-based; do not add external parser or highlighter packages here.
- Keep highlighting bounded for large visible documents; avoid document-wide work from row height measurement paths.
- Preserve original language hints for Markdown export and clipboard behavior; normalize aliases only for highlighter lookup.
- Keep parsing helpers shared and side-effect free so AppKit rendering, Return shortcuts, and Markdown paths can use the same rules.
