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
- One stylesheet, delivered with the package (`Klar.stylesheet`), built on design
  tokens (CSS custom properties).
- Pure helpers with unit tests: dates (`Klar.Date`), formatting (`Klar.Format`),
  search (`Klar.Search`), validation (`Klar.Validate`), the rule engine (`Klar.Rule`).
- A showcase application (`example/`) with a component gallery and a dummy backend.
- Made for applications with very little code of their own: a select hands back
  your own id type (`Select.State CustomerId`), a date can never be invalid
  (`Klar.Date` is opaque), columns, keyboard shortcuts and problems are values and
  not free text (`Table.columnId`, `Shortcut.mod (Shortcut.char 'k')`,
  `Remote.problem Remote.timeout`), and a rule field offers only the operators you
  choose (`Rule.withOperators`).
- A guide for building an application, also before the package is published
  ([USING.md](USING.md)), and `scripts/check-app.mjs` to keep a copy of Klar frozen.
