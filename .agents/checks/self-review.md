---
name: self-review
description: Perform a BlockInputKit self review or audit of current changes. Use when the user asks for a self review, audit, review of uncommitted changes, or a final quality pass before commit or PR in the BlockInputKit repo.
---

# Self Review

## Overview

Perform a repo-aware quality audit of the current BlockInputKit changes before they are committed or handed off. Prioritize concrete bugs, regressions, stale guidance, missing validation, and low-risk fixes.

## Steps

1. First say exactly: `Performing a self review...`
2. Inspect `git status --short` and the relevant diffs.
3. Read the nearest `AGENTS.md` files for changed paths when they were not already read in the current turn.
4. Review changes for:
   - Bugs.
   - Edge cases.
   - Regressions, including unintended behavior changes across the block model, AppKit editor, and SwiftUI wrapper.
   - Performance risks, especially changes that could mount too many block views or add document-scale linear work to common typing paths.
   - Dead or stale code.
   - Any external code that is now unused due to these changes.
   - File-size pressure.
   - Missing unit, AppKit, or snapshot-style test coverage.
   - Missing docs for changed `public` or `open` APIs, including types, enum cases, properties, functions, initializers,
     typealiases, and configuration hooks.
   - Missing class docs or code comments where non-public API intent is not obvious.
   - Missing or stale `AGENTS.md` guidance.
   - Lint risks and Swift style issues.
   - Accessibility issues in UI changes.
5. Confirm validation when editor, focus, keyboard, virtualization, or rendering behavior is affected.
6. Fix low-risk issues directly. If a specific commit SHA was given to the skill, amend directly into the commit.
7. Ask before risky or broad changes.
8. After fixing anything, automatically start another pass from step 2 with fresh status and diffs.
9. Report findings first, ordered by severity and grounded in file/line references.

## Looping Requirement

Treat every fixed issue as a reason to run the skill again automatically. Continue the inspect, review, fix,
and validate cycle until a complete fresh pass finds nothing else worth addressing, the user interrupts or
redirects the work, or the remaining changes are risky or broad enough to require approval.

Do not wait for the user to ask for "another pass" after making fixes. If the loop stops because approval is
needed or validation cannot be completed, report the blocker and the remaining work explicitly.

## Output

Use the normal code-review shape:

- Findings first, with tight file and line references.
- Then open questions or assumptions.
- Then a brief summary of any fixes made and validation run.

If there are no findings, say that clearly and mention residual validation gaps.
