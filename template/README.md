# Application template

A small, complete Klar application with the standard architecture. Copy this folder as the
start of an application.

What is in it:

| Piece | Where |
|---|---|
| `Browser.application` whose `onUrlRequest` and `onUrlChange` go to `AppShell` (hash routes) | `src/Main.elm` |
| `AppShell` keeps the key, the sidebar, the drawer and the focus; `update` returns the address, the one place that learns of a new route | `ShellMsg` in `update` |
| `SideNav` typed by the application's own `Page` (`SideNav.keys`) | `pageKeys`, `navigation` |
| Two pages (`Orders`, `Settings`) chosen by `pageFromUrl` | `viewPage` |
| A `Remote` from a backend stand-in, drawn by `Table` (loading, failure with retry, empty) | `fetchOrders`, `GotOrders` |
| The `Klar.Settings` of the application (density and time zone, `Time.here` at the start), given to `AppShell.settings` and `Table.settings` | `settings`, `GotZone` |
| One list of overlays: a `ConfirmDialog` and the `Toast` stack | `overlays` |
| `elm.json` with `elm/url` as a **direct** dependency | `elm.json` |
| `index.html` that mounts the program with `Elm.Main.init()` | `index.html` |

Modules used: `Klar`, `Klar.AppShell`, `Klar.SideNav`, `Klar.PageHeader`, `Klar.Table`,
`Klar.Remote`, `Klar.Button`, `Klar.ConfirmDialog`, `Klar.Toast`, `Klar.Overlay`, `Klar.Icon`.

## Build and open

```bash
elm make src/Main.elm --output=main.js
```

then serve this folder with any static file server and open `index.html`. The routes are the
part of the URL after `#`.

## When you copy it out of the Klar repository

`elm.json` reads Klar from `../src`. In your own project either put Klar next to your code
(a git submodule, `"source-directories": ["src", "vendor/klar/src"]`, see
[USING.md](../USING.md) section 1) or run `elm install davidtoska/elm-klar` once it is
published, and remove `../src` from the source directories.

## Make it yours

1. Replace `Page`, `Order` and `fetchOrders` with your own types and your request.
2. Add a page: a constructor of `Page`, a case in `pageToString`, `navigation`, `pageFromUrl`
   and `viewPage`.
3. Keep every overlay in `overlays`, also while it is closed.
4. Read [AI.md](../AI.md) before you add a component, and the recipes in [recipes/](../recipes/README.md)
   for the common screens.
