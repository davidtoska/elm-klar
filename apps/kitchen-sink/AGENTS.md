# Documentation-only consumer

Use `../../AI.md`, search `../../ai/klar-index.json`, and open only the module documentation needed under `../../ai/modules/`. The complete programs named in `AI.md` under `../../example/src/Examples/` are also permitted guidance. Never open Klar source, private modules or the showcase implementation. Compiler diagnostics are permitted; do not follow them into library implementation.

Keep changes inside this application. Record all discovered library or documentation issues and improvement suggestions in `FINDINGS.md`; do not repair the library during this experiment. Separate confirmed findings from app mistakes and untested assumptions.

Use only exposed Klar modules, public API types, Klar layout and text primitives, and the standard AppShell/overlay architecture. No CSS, class names or style attributes in app views. Keep transport in the application boundary; `elm/http` and JavaScript transport ports are allowed here.

Edit application generator files, run `npm run generate`, then `npm run verify`. The verification server uses a fresh SQLite database on port 8091. Never commit, push, tag or publish unless the owner asks.
