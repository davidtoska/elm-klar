# Changelog

Elm checks the version of every release against its public API (`elm bump`, `elm diff`):
adding is a minor release, changing or removing is a major one.

## 1.0.0

Added `Kanban` with version-checked moves and WIP limits, `CommentThread` with
safe Markdown replies and acknowledgements that preserve newer drafts,
`UploadQueue` with validated staging and honest byte progress, `CodeBlock` with
exact source/download and bounded JSON/Elm highlighting, and `QuantityInput` with
typed units and unchanged raw input. The Workflow toolkit gallery exercises their
edge cases. No new dependencies, ports, JavaScript or network layer were added.

Added five workbench components: `CardList` with page-safe selection, `WorkQueue`
with keyboard navigation and a detail pane, `AuditLog` with expandable diffs,
`ConflictResolver` with exact three-way merging and version-bound decisions, and
`NotificationCenter` with explicit read/dismiss actions. All handle every `Remote`
state and English/Norwegian text, use the existing theme tokens and add no dependencies.
The gallery and standalone `ReviewDesk` example demonstrate them together.

The first release: more than a hundred components for data-intensive applications in plain
Elm, with built-in text in English and Norwegian Bokmål, ten themes with a light and a dark
mode, and 500 icons as Elm values.
