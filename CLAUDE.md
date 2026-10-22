# Klar

An Elm package (`davidtoska/elm-klar`, modules `Klar.*`): a UI toolkit for precise,
data-dense, data-intensive applications. "Klar" is Norwegian for "clear" and "ready".
It is published on package.elm-lang.org, so its public API is a promise: see
`CONTRIBUTING.md`.

## Tech

- Vanilla Elm (0.19.x, built with 0.19.3). The library depends only on the official
  `elm/*` packages from the Elm team (core, html, browser, json, time, url and file today;
  `file` only for `Klar.FileDrop`, which hands the application the `File` values; `svg`,
  `bytes`, `http`, `parser`, `regex` and `random` are allowed, added to `elm.json`
  only when a component needs them). The library never knows HTTP (`elm/http` stays out,
  see ROADMAP.md) and never reads or sends a `File`. No third-party Elm packages. Use
  `Klar.Internal.percentEncode`, not `Url.percentEncode`.
- No ports, no kernel code, no `Debug`, no JavaScript in the library or the example.
- Vanilla CSS only. Sources in `css/src/*.css`; `npm run build:css` writes
  `css/klar.css` and the Elm module `src/Klar/Internal/Css.elm` that `Klar.stylesheet`
  renders. Never edit the generated files.
- `example/` is the showcase: a SINGLE PAGE APP (hash routing) with a dummy backend
  written in Elm (`Backend.*`, synchronous functions behind the request/response layer
  `Api`). It imports only exposed `Klar.*` modules (`npm run check:example-imports`).
- Icons are Elm values (`Icon.fromSvg`), not CSS rules: `src/Klar/Icon.elm` (everyday set, by hand)
  and `src/Klar/Icon/*.elm` (generated from Lucide by `scripts/generate-icons.mjs`, spec in
  `scripts/icons-spec.mjs`; see `ICONS.md`). Never edit the generated modules.
- English everywhere: documentation, comments, README, example. The components' built-in
  text comes in English and Norwegian Bokmål through `Klar.Locale` (default English).
- Domain-neutral examples: orders, customers, products, warehouses. Nothing about the
  application this library was extracted from.

## Commands

```bash
npm install          # elm-test, elm-format
npm run check        # everything: text files, css, icons, docs, api, format, tests, example
npm test             # elm-test (do not run two at once in one directory)
npm run format       # elm-format, then LF line endings and no byte order mark
npm run check:compat # Elm 0.19.1 and the oldest allowed dependencies (needs the network)
npm start            # builds and serves the showcase on http://localhost:8000
```

## Docs

- https://guide.elm-lang.org/
- https://package.elm-lang.org/help/design-guidelines
- https://github.com/rtfeldman/elm-spa-example
