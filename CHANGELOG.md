# Changelog

Elm checks the version of every release against its public API (`elm bump`, `elm diff`):
adding is a minor release, changing or removing is a major one.

## 1.0.0

Added five workbench components: `CardList` with page-safe selection, `WorkQueue`
with keyboard navigation and a detail pane, `AuditLog` with expandable diffs,
`ConflictResolver` with exact three-way merging and version-bound decisions, and
`NotificationCenter` with explicit read/dismiss actions. All handle every `Remote`
state and English/Norwegian text, use the existing theme tokens and add no dependencies.
The gallery and standalone `ReviewDesk` example demonstrate them together.

The first release: more than a hundred components for data-intensive applications in plain
Elm, with built-in text in English and Norwegian Bokmål, ten themes with a light and a dark
mode, and 500 icons as Elm values.
