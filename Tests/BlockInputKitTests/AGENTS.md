## Test Organization

- Mirror source areas at the folder level when adding test files: `Core`, `AppKit`, `Markdown`, `Completion`, `Undo`, `SwiftUI`, and `Support`.
- Put shared test helpers beside the tests that use them most; promote them only when multiple folders need the same helper.
- For keyboard behavior, cover the document model and the AppKit delegate or mounted-view path when both can diverge.
- For document-store behavior, assert the granular store operation used by the editor, not only the final document snapshot.
