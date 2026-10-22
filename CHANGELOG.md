# Changelog

All notable changes to this package are written here. Elm enforces
[semantic versioning](https://semver.org) on package.elm-lang.org: `elm bump`
computes the next version from the changes in the public API.

## 1.0.0

The first release.

- More than 60 components for data-intensive applications: a data table with client
  and server mode, searchable selects, pickers for dates, periods and times, a rule
  builder and filter bar, dialogs, drawers, toasts, a command palette, charts,
  trees, timelines and the pieces of an application shell.
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

### Fixes from the first three applications (A8, the sure fixes)

Three applications were built from the documentation alone (`apps/`); these are the
cheap, certain fixes from that evaluation. Nothing was released before them, so they
change the first API and not a published one.

- `Remote` is `NotAsked | Loading | Loaded a | Failed Problem` (it was `Success` and
  `Failure`), and `Remote.isLoaded` and `Remote.isFailed` follow. `Success` was also a
  `Theme.Tone`, so an application that used both had to qualify one of them; `Tone`
  keeps `Success` and `Remote` has its own words. (`Autocomplete` matches on
  `Remote.Failed` and `Remote.Loaded` because its internal content type has a `Failed`
  of its own.)
- Documentation examples that did not compile are fixed: the `Klar.Table` module
  doc and its comments gave plain strings where a `Table.ColumnId` is needed (F-001,
  S-001, O-006), and the `Klar.AppShell` doc used `SideNav.item` without `Keys` and
  `SideNav.State` without its key type (F-002, O-007). `npm run check:docs` now also
  fails on these patterns (a string literal as the id of a `Table` column
  constructor, `SideNav.item` or `group` with a record as the first argument,
  `Remote.Success`, `Remote.Failure`) in the exposed modules, the README, USING.md
  and CONTRIBUTING.md. Compiling every example is still a later task.
- USING.md starts with "Start here": a complete `Browser.application` with an
  `AppShell`, a `SideNav` typed by a `Page`, a `Remote` and a `Table`, and the
  `index.html`. It compiles. It says which `main` is mounted how (`Browser.sandbox`
  and `element` with `{ node: ... }`, `Browser.document` and `application` with
  plain `init()`, and the latter for an `AppShell`) and lists `elm/url` as a direct
  dependency of an application (F-003, S-006, O-008). The README says the same in a
  paragraph.
- New: `Date.toPosix : Time.Zone -> Date -> Time.Posix`, the start of the day in
  that zone (F-014).
- New: `Format.iso8601 : Time.Posix -> String`, UTC to the second, as
  `2026-10-22T14:05:00Z` (S-020).
- New: `Stat.change { current, previous }`, which works out the percentage for you
  and shows no change, never `NaN`, when the previous value is 0 (S-018). It reuses
  the delta of the tile, so `lowerIsBetter`, `deltaTone` and `deltaLabel` still apply.
- `Layout.grid [ Layout.minColumn n ]` uses `auto-fit`: two children in a wide grid
  share the whole row instead of leaving empty tracks (S-011). The default grid
  changes the same way.
- New: `Layout.fillRest`, for a `stack`: it is as tall as the room left in its
  parent (inside an `AppShell`, the content area) and hands that height on to
  its children, so a `Table.fillHeight` table fills the rest of the page under its
  heading (F-017). The one new attribute, because without it the application had to
  guess a `Table.maxHeight`.
- `Form.section` draws its title as an `h2`, not an `h3`: under the `h1` of a page
  the outline passes the `heading-order` check of axe (O-015). It takes no level
  argument, to keep the function as it is; `Card` keeps `headingLevel` (default 3).
- The links of the form error summary are at least 24 by 24 CSS pixels (WCAG 2.2
  target size, O-016).
- A `Timeline` with `maxHeight` and no `onLoadMore` takes the keyboard focus
  (`tabindex="0"`) and is a region named by `ariaLabel` ("Events" without one), so it
  can be scrolled without a mouse (S-012).
- `InlineEdit` leaves out "Try again" after a failed save when `Remote.isRetryable`
  says no (a conflict, a validation problem), as `Form.status` and `Select` do (O-014).
- The `Select` popup is as wide as its longest option up to 36rem (at least the field
  and 260 pixels), so descriptions are no longer cut (O-013).
- In `Form.actions` the status takes the free space and wraps inside itself, so a
  long message never pushes the buttons onto a second line (O-012).
- `Klar.Text` documents which functions are blocks and which are inline (O-020).

**Status of the sure fixes of A8.** Fixed: F-001, F-002, F-003, F-014, F-017, S-001,
S-006, S-011, S-012 (for `Timeline`), S-018, S-020, O-006, O-007, O-008, O-012,
O-013, O-014, O-015, O-016, O-020. Skipped, with the reason: the same scroll-area check
for `Tree.maxHeight` and `ListItem.maxHeight` (S-012 suggested it): the tree has
focusable nodes inside it, a list may or may not, and which rule fits needs a
decision. Compiling every doc example (A1) and the larger items of A8 (the form
model, the overlay layer) are later work. A decision for the owner to check: the
`Form.section` default of `h2` (inside a `Card`, whose title is an `h3`, an `h2` is
legal for axe, but a purist would want `h4`).
