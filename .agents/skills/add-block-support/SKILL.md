---
name: add-block-support
description: >-
  Add or extend support for a BlockInputKit block type. Use when the user asks
  to add a new block kind/type, support a new Markdown block, add editor
  rendering for a block, make a block selectable/editable/reorderable,
  implement frontmatter/code/list/quote-like block behavior, or implicitly
  requests block support through phrases like "add support for X blocks",
  "new block", "block type", "block kind", "Markdown construct", "editor
  should handle X", or "render/edit X as a block".
---

# Add Block Support

## Overview

Add block support end to end across the model, Markdown, AppKit editor, stores, docs, tests, and snapshots. Do not stop at the enum case or parser: block behavior usually crosses typing shortcuts, selection, clipboard, undo, reordering, store sync, and visual reuse.

## Workflow

1. Read the repo root `AGENTS.md` and the nearest scoped guidance before editing affected paths.
2. Inspect existing companion files for similar block kinds before choosing structure.
3. Write down the intended block semantics:
   - Is it text-backed, chrome-only, or mixed?
   - Is it canonical only at a position such as document start?
   - Does empty content count as meaningful?
   - Does export need raw formatting preservation?
   - Should validation block editing, or only show advisory UI?
4. Implement the smallest cohesive slice, then run focused tests.
5. Self-review the change against the checklist below before broad validation.

## Implementation Checklist

- **Public API:** Add or update `BlockInputBlockKind`, block properties, Codable behavior, public validation/result types, and doc comments. Call out exhaustive-switch compatibility when adding public enum cases.
- **Core behavior:** Update emptiness, insertion, deletion, merge, Return, unformat/recovery, indentation, typing shortcuts, selection expansion, and reordering helpers. Keep canonical-position rules shared through helpers so stores and AppKit do not drift.
- **Markdown:** Update snapshot import/export and streaming import/export together. Preserve raw source when the feature promises it; strip or reconstruct only the intended syntax markers. Cover unclosed, non-leading, delimiter-like, trailing-newline, and round-trip cases.
- **AppKit rendering:** Wire fonts, metrics, chrome, hit testing, accessibility, reuse reset, selection chrome, height measurement, snapshots, and dark/light appearances. Reset stale attributes and chrome every configure/reuse path.
- **Editing commands:** Cover keyboard shortcuts, Return, Backspace/Delete, Tab/indent where relevant, paste/completion insertion, undo/redo, and text-view delegate paths. Ensure model-only behavior and mounted `NSTextView` behavior agree.
- **Selection and clipboard:** Decide whether partial text, full-body text, mixed selections, and whole-block selections copy/export raw text or Markdown syntax. Cover Shift+Arrow, mouse drag, Cmd+A escalation, cut, copy, and paste.
- **Stores and large docs:** Update `BlockInputDocumentStore`, memory/progressive stores, demo generated stores, granular mutations, complete snapshots, and deferred `onDocumentChange` paths. Avoid full-document materialization on hot editor paths.
- **Reordering:** Decide whether the block can move, whether other blocks can move around it, how drag/drop behaves, and whether collection-view and model moves share the same policy.
- **Validation:** Keep advisory validation non-blocking unless the user explicitly asks otherwise. It must not block editing, undo, paste, completion, import/export, store sync, or snapshots.
- **Docs and guidance:** Update `README.md` when supported Markdown behavior or block kinds change. Update scoped `AGENTS.md` only for durable future-agent guidance.

## Test Checklist

Add focused coverage where behavior exists:

- Core Codable, validation, raw text preservation, emptiness, Return/delete/merge/unformat, insertion, reordering, and typing shortcuts.
- Markdown snapshot and streaming import/export, including formatting-sensitive round trips.
- Store snapshots and granular mutations, including memory, progressive, generated/demo stores, and complete snapshots.
- AppKit mounted tests for rendering, reuse, text attributes, height, keyboard commands, undo/redo, paste/completion, file insertion/drop, and store-backed mutations.
- Selection/clipboard tests for partial, full-body, whole-block, mixed, keyboard, and mouse-drag paths.
- Snapshot tests when chrome, metrics, colors, or default visual output changes. Record intentionally, then verify.

## Validation

Prefer focused tests while iterating. Before handoff after block-support changes, run the ordered validation that applies to the touched surface:

```sh
rtk proxy git diff --check
rtk ./scripts/lint.sh
rtk ./scripts/build.sh
rtk ./scripts/test.sh
rtk ./scripts/snapshots.sh verify
```

Record snapshots only when the visual diff is intentional:

```sh
rtk ./scripts/snapshots.sh record
rtk ./scripts/snapshots.sh verify
```
