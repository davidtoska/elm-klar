# Table split progress

## Baseline

- Branch: codex/table-split, separate managed worktree, base c84c57d.
- npm ci succeeded; npm run check passed before edits.
- 11,357 tests passed, zero failures (151 Elm test/support files).
- Full log and docs-before.json: C:/Users/DavidToska/AppData/Local/Temp/klar-table-split-baseline/.
- Test-file inventory saved alongside the baseline.
- Next: capture all showcase table DOM roots, then commit the harness and plan.

## Decisions

- Preserve opaque public unions rather than replacing them with aliases, because the
  required byte-identical documentation JSON distinguishes these representations.
- No user changes copied from the main checkout; its unrelated work stays there.
