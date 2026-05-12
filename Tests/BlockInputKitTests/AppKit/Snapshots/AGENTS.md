## AppKit Snapshot Tests

- Keep snapshot matrices minimal: prefer representative documents over one fixture per block kind.
- Make fixtures deterministic by pinning view size, appearance, accent color, and visible document content.
- Record new baselines intentionally with `./scripts/snapshots.sh record` and verify with `./scripts/snapshots.sh verify`.
- Keep snapshot helpers local to this folder unless non-snapshot AppKit tests need them.
