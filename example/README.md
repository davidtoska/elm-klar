# Klar showcase

A complete single page application built only with the Klar package: an operations
console with a dashboard, orders, products and a component gallery. It is both the
documentation by example and the test bench of the library.

```bash
npm install     # in the repository root, once
npm start       # builds example/main.js and serves it on http://localhost:8000
```

or by hand: `cd example && elm make src/Main.elm --output=main.js`, then open
`index.html` in a browser (it works from a file or from any static server; the
routes use the URL fragment, `#/orders`). `elm-version` in `elm.json` is the exact
compiler this application was built with.

## What is in it

| Page | What it shows |
| --- | --- |
| **Overview** (`#/`) | Key figures, charts, the orders that need attention and the activity feed, all from one request with loading and failed states |
| **Orders** (`#/orders`) | A server-mode table: search, sort, status filter and paging are requests. Edit in a drawer with the full form, validation from the server, "discard changes?", status changes from the row menu. `#/orders/ORD-10001` opens an order directly |
| **Products** (`#/products`) | A client-mode table of 1 500 products next to a tree of categories |
| **Components** (`#/components`) | A gallery with live examples of every component and state, with code |

Press `Ctrl K` for the command palette and `?` for the keyboard shortcuts. The
**developer tools** (`g d`) make the pretend network misbehave (offline, server
error, timeout, flaky, slow) and switch between a small and a large data set.

## How it is built

```
src/Main.elm            the shell: routing, language, sidebar, toasts, palette, shortcuts
src/Route.elm           hash routes
src/Api.elm             request/response layer: a delay, and failures when the network is switched off
src/Api/                the contract with the backend: types, and the translation of errors
src/Backend/            the dummy server: synchronous functions over an in-memory database
src/Page/               the pages; Page.Effect is how a page asks Main for a toast or a redirect
src/Page/Gallery/       one page per group of components
src/Showcase/           documentation helpers and sample data for the gallery
showcase.css            styles of the gallery's documentation pages only
```

The application imports only modules that the package exposes
(`npm run check:example-imports` checks it), and it has no ports and no JavaScript of
its own: `index.html` only starts Elm. The stylesheet of the library comes with the
package: the view renders `Klar.stylesheet`.
