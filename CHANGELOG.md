# Changelog

All notable changes to this package are written here. Elm enforces
[semantic versioning](https://semver.org) on package.elm-lang.org: `elm bump`
computes the next version from the changes in the public API.

## 1.0.0

The first release.

- About 90 components for data-intensive applications: a data table with client
  and server mode, searchable selects, pickers for dates, periods and times, a rule
  builder and filter bar, dialogs, drawers, toasts, a command palette, charts,
  trees, timelines and the pieces of an application shell.
- Components for working with data, arranging a workspace, and seeing what changed:
  `Klar.Sortable` (drag or key a list into a new order, with announcements) and
  `Klar.Splitter` (resizable panes); `Klar.ButtonGroup`, `Klar.ToggleGroup`,
  `Klar.SplitButton`, `Klar.Link` (a link that cannot lead anywhere unsafe) and
  `Klar.Kbd`; `Klar.StatusPage` (403, 404, 500, offline), `Klar.BulkBar`,
  `Klar.LeaveGuard` (unsaved changes inside the application) and `Klar.History`
  (undo and redo); `Klar.Markdown` (a safe renderer that tolerates unfinished text) and
  `Klar.MarkdownEditor`; `Klar.Diff` (text, JSON and field diffs) and `Klar.Compare`
  (records side by side); `Klar.Money`, `Klar.MoneyInput` (exact money in minor units,
  never rounded behind the user's back) and `Klar.MaskedInput` (IBAN, organisation
  number, bank account, postal code, phone, with check digits); `Klar.TreeSelect`,
  `Klar.Cascader`, `Klar.Transfer` (typed ids, lazy children, thousands of nodes);
  `Klar.Recurrence` and `Klar.RecurrencePicker` (every second Tuesday, with RFC 5545
  RRULE in and out); `Klar.PermissionMatrix` and `Klar.ApprovalFlow`. No new package
  dependency was added for any of them.
- Built-in text in English and Norwegian Bokmål (`Klar.Locale`).
- An icon library of 500 line icons in one style (24 by 24 grid, 2 pixel stroke, round
  ends), every one an Elm value that carries its own drawing: `Klar.Icon` has the
  everyday icons and `Klar.Icon.Arrows`, `Business`, `Calendar`, `Communication`,
  `Data`, `Developer`, `Devices`, `Documents`, `Editor`, `Interface`, `Logistics`,
  `Media`, `Nature`, `People` and `Science` the rest. `elm make --optimize` leaves out
  the icons an application does not use. `Icon.fromSvg` draws your own icon the same
  way, and `Klar.Icon.Library` lists everything for galleries. See `ICONS.md`.
- One stylesheet, delivered with the package (`Klar.stylesheet`), built on design
  tokens (CSS custom properties).
- Pure helpers with unit tests: dates (`Klar.Date`), formatting (`Klar.Format`),
  search (`Klar.Search`), validation (`Klar.Validate`), the rule engine (`Klar.Rule`).
- A showcase application (`example/`) with a component gallery and a dummy backend.
- Made for applications with very little code of their own: a select hands back
  your own id type (`Select.State CustomerId`), a date can never be invalid
  (`Klar.Date` is opaque), columns, keyboard shortcuts and problems are values and
  not free text (`Table.columnId`, `Shortcut.mod (Shortcut.char 'k')`,
  `Remote.problem Remote.timeout`), a rule field offers only the operators you
  choose (`Rule.withOperators`), and a table speaks your row id type
  (`Table.State OrderId`, `Table.rowIds`, `Table.selectedIds orderRows state`), and so do trees and the side menu
  (`Tree.State RegionId`, `Tree.nodeIds`, `SideNav.State Page`, `SideNav.keys`).
- A guide for building an application, also before the package is published
  ([USING.md](USING.md)), and `scripts/check-app.mjs` to keep a copy of Klar frozen.
