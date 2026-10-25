# Changelog

## Unreleased - first publication

Klar is under development; no stable release history is recorded yet. The first
release will establish the public API. Current contracts and examples live in the
[module documentation](ai/modules/README.md); outstanding work is in [ROADMAP.md](ROADMAP.md).

- Data-intensive Elm interfaces: tables, server lists, pickers, forms, exact money,
  dates and recurrence, charts, overlays, navigation, review and workflow components.
- Shared remote-data and form-submission lifecycles, typed identities, keyboard and
  focus handling, English/Norwegian text and themes with automated contrast checks.
- A component showcase, complete example programs, simulated failure/retry paths
  and a generated AI reference derived from the public Elm documentation.
- Only official `elm/*` library dependencies: `core`, `html`, `browser`, `json`,
  `time`, `url` (application navigation and leave guards) and `file` (file controls
  hand values to applications; table CSV export uses `File.Download.string`).
  The library has no ports, JavaScript or transport dependency. Applications own
  persistence, networking and external integrations.

After publication, record changes and migration guidance by released version.
