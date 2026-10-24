# Using Klar in an application

This is the guide for someone who builds an application with Klar, as the
[README](README.md) shows it, but in more detail: how to get the package into a
project (also before it is published), how to keep it untouched, and how the
parts fit together in an application that talks to a backend.

## Start here

*Writing the application with an AI? Point it at [AI.md](AI.md) first; section 4 below has the paragraph for the application's own `CLAUDE.md`.*

A complete application with the frame of Klar is in AI.md and in `template/`. The parts
you set up around it are `elm.json`, `index.html` and the request to your backend.

**`elm.json`.** An application that uses `Browser.application` imports `Url`, so
`elm/url` must be a *direct* dependency next to the ones Klar needs
(`elm install elm/url` does it). See section 1 for the whole list.

**`index.html`.** How the application is mounted depends on its `main`:

| `main` is built with | Mount it with | Use it for |
| --- | --- | --- |
| `Browser.sandbox`, `Browser.element` | `Elm.Main.init({ node: document.getElementById("app") })` | a widget inside a page you own (the README's first program) |
| `Browser.document`, `Browser.application` | `Elm.Main.init()` | a whole page: **use this with `AppShell`**, which fills the viewport and owns the page |

`Elm.Main.init()` without a `node` on a sandbox or an element fails with
`Cannot read properties of undefined (reading 'node')`. `Klar.stylesheet` removes
the margin of the `body`, so the page needs no CSS of its own:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Acme Operations</title>
</head>
<body>
  <script src="main.js"></script>
  <script>Elm.Main.init();</script>
</body>
</html>
```

`elm make src/Main.elm --output=main.js` builds it. The routes are the part of the
URL after `#`, so any static file server works and nothing has to be configured to
send every path to `index.html`.

**`src/Main.elm`.** Copy the program in [AI.md](AI.md) ("The standard application"), or
[template/src/Main.elm](template/src/Main.elm), which adds a confirmation dialog. Both are the
same application: a `Browser.application` with an `AppShell` that owns the address, the
sidebar and the focus, a side menu typed by your own `Page`, and a `Remote` that a table draws.
There is one way to wire the frame (AI.md, "The frame"); do not write a `LinkClicked` or a
`SideNav.init` next to it. Replace `fetchOrders` with a real request (see section 3).

## 1. Getting Klar into a project

**Published.** `elm install davidtoska/elm-klar`. The package is a normal Elm
package; nothing else is needed.

**Before it is published, or when you want an exact copy.** Elm cannot install a
package from GitHub, but it can read the source of one from a folder. Put Klar in
the repository of the application as a git submodule, pinned to a tag or a commit:

```bash
git submodule add https://github.com/davidtoska/elm-klar vendor/klar
git -C vendor/klar checkout 1.0.0        # or the commit you want
```

and add its `src` to the `source-directories` of the application's `elm.json`.
The application also has to list the packages Klar depends on, because Elm reads
the dependencies of the application and not of a folder:

```json
{
    "type": "application",
    "source-directories": ["src", "vendor/klar/src"],
    "dependencies": {
        "direct": {
            "elm/browser": "1.0.2",
            "elm/core": "1.0.5",
            "elm/file": "1.0.5",
            "elm/html": "1.0.1",
            "elm/json": "1.1.4",
            "elm/time": "1.0.0",
            "elm/url": "1.0.0"
        },
        "indirect": { "elm/bytes": "1.0.8", "elm/virtual-dom": "1.0.5" }
    }
}
```

`elm/url` is only needed by an application that uses `Browser.application` (every
application with an `AppShell` does, see "Start here"); Klar itself imports it
only in `AppShell` and `LeaveGuard`, which follow the address. `elm/file` is for
`Klar.FileDrop` (and `Klar.Form`'s file fields), which hand the application the `File`
values. Add the packages your own code imports (`elm/http` for requests, say) the same way.

Replacing the submodule with `elm install davidtoska/elm-klar` later changes
nothing in the application's code.

## 2. Keeping Klar frozen

A folder of source has two weaknesses that a real package does not: the
application can import Klar's internal modules (`Klar.Internal`, `Klar.Table.Sort`
...), and anyone can edit a component in place. Three layers close them.

1. **A submodule pinned to a commit.** A change inside it shows up as "modified
   content" in `git status`, and the application's repository records which
   version it uses.
2. **A check in CI and before each commit.** `scripts/check-app.mjs` in this
   repository fails when the application imports a module that Klar does not
   expose, and when the copy of Klar differs from the version that was accepted
   (a fingerprint in `klar.lock`). Copy the script into the application:

   ```bash
   node scripts/check-app.mjs vendor/klar --write-lock       # once, and commit klar.lock
   node scripts/check-app.mjs vendor/klar src                # in CI and before a commit
   ```

3. **A rule for the people and tools that write the code.** Say it where they read
   it, in the `CLAUDE.md` of the application (or its README): the paragraph is in
   section 4.

   For Claude Code the folder can also be made read-only with a permission rule in
   `.claude/settings.json` (check the syntax of the rules in the Claude Code
   documentation):

   ```json
   { "permissions": { "deny": ["Edit(vendor/klar/**)", "Write(vendor/klar/**)"] } }
   ```

   A rule stops the accident, not the determined; the check in layer 2 is what
   catches the rest.

## 3. An application, in the order you write it

**One stylesheet.** `Klar.stylesheet` once in the view of the root (see the README), or
`Klar.stylesheetFor model.settings` when the application picks a theme (below).

**Density and time zone, stated once.** Keep one `Klar.Settings` in the model, ask the browser
for the zone when the program starts, and give the settings to the shell:

```elm
-- init
( { settings = Settings.default, ... }, Task.perform GotZone Time.here )

-- update
GotZone zone ->
    ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

-- view: everything inside the shell follows the density, with no attribute on any component
AppShell.view [ AppShell.settings model.settings, ... ] [ page ]
```

The density (`Settings.withDensity Compact`) is carried by the page, so every table, card, list,
tree, button and input follows it; a component that is given its own density keeps it. The
zone reaches the components that write a time: give each of them `X.settings model.settings`
(`Table`, `Stat`, `Chart`, `Tree`, `ListItem`, `Select`, `MultiSelect`, `Autocomplete`,
`CommandPalette`, `RemoteView`, `Timeline`, `ApprovalFlow`). Without it a time is written in UTC
**and ends in "UTC"**, so a forgotten zone is seen, not found by a user two hours off. For a
time you write yourself: `Settings.time model.settings posix`. The theme is in the same
settings (`Settings.withTheme Theme.ocean`, `Settings.withMode Theme.System`) and is drawn by
`Klar.stylesheetFor model.settings` in place of `Klar.stylesheet`.

**Data from a backend, with `elm/http` in the application.** Klar never sends a
request and never imports `elm/http`. It draws the state of one, as a
[`Remote`](ai/modules/Klar.Remote.md). Turn the result of a request into a `Remote` and
give it to the component:

```elm
type alias Model =
    { orders : Remote (List Order), table : Table.State OrderId }

type Msg
    = GotOrders (Result Http.Error (List Order))
    | TableMsg Table.Msg

toProblem : Http.Error -> Remote.Problem
toProblem error =
    case error of
        Http.Timeout -> Remote.problem Remote.timeout
        Http.NetworkError -> Remote.problem Remote.network
        Http.BadStatus 404 -> Remote.problem Remote.notFound
        Http.BadStatus 403 -> Remote.problem Remote.forbidden
        _ -> Remote.problem Remote.unknown

-- update
GotOrders result ->
    ( { model | orders = result |> Result.mapError toProblem |> Remote.fromResult }, Cmd.none )

-- view
Table.view TableMsg [ Table.columns columns, Table.rows model.orders, Table.onRetry Reload ] model.table
```

Loading, the failure with a retry button and the empty state are drawn by the
table. The texts of a problem are chosen when it is drawn, in the language of the
component, so a language switch changes a failure that is already on the screen.

**Refreshing, and old data when a refresh fails.** Two lines carry it, and every data
component (`Table`, `Stat`, `Chart`, `Timeline`, `Tree`, `Select`, `MultiSelect`,
`Autocomplete`, `ListItem.remote`, the palette) draws it with no attribute: the data
stays on the screen, dimmed and busy while it is refreshed, and marked "Old data from
14:05" with a retry when the last refresh failed.

```elm
-- the request leaves (the old rows stay)
( { model | orders = Remote.refresh model.orders }, fetchOrders )

-- the answer comes back, good or bad; `at` is the time it came (Time.now, or your clock)
GotOrders result at ->
    ( { model | orders = Remote.refreshWith model.orders (Result.mapError toProblem result) at }, Cmd.none )

-- one notice for the page: "The last refresh failed. Showing the previous data for: orders."
Alert.stale [] Reload (List.concat [ Remote.staleIn "orders" model.orders, Remote.staleIn "figures" model.figures ])
```

The time is shown in the zone of the application's settings (see "Density and time
zone" above: `Table.settings model.settings`; UTC, and marked "UTC", until the zone is
given). Read the data with `Remote.toMaybe`, `withDefault` or `map`: they see
refreshed data too. A `case` of your own on a `Remote` needs a branch for `Kept`.
`Remote.refresh` on nothing is `Loading`; for a new question (another customer, another
period) set `Loading` yourself.

**The body of a card, drawer or dialog.** `RemoteView.view` is the loading skeleton (read
out to screen readers), the failure with a retry, and old or refreshing data, so you write
only what the data looks like:

```elm
Drawer.view DrawerMsg [ Drawer.title "Order 1042" ] model.drawer
    (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)
```

On a page or in a card, "Try again" is replaced by the skeleton and focus would fall to the
page: give the body an `id` and move focus to it in the same `update` branch that asks again
(`Klar.focus "order-body" NoOp`). The same holds for every region that shows a retry:
`Stat.id`, `Chart.id` and `Timeline.id` give the tile, the chart or the timeline the id,
`Klar.focus` moves focus to it, and a `Tree` branch has `Tree.focusNode`. Use a
message of its own for the retry of the region, so that a "Reload" button elsewhere does not
take focus. A page that is only a `RemoteView` draws its title
(`PageHeader`) outside it, so that there is one `h1` while it loads and when it fails.

**Dialogs, drawers, toasts and the palette.** Each has a `State` in your model and a
`view` that returns an `Overlay`. Give the list of them to the page; the layer does
the rest:

```elm
AppShell.overlays
    [ Modal.view EditMsg [ Modal.title "Edit order" ] model.edit [ form ]
    , Drawer.view OrderMsg [ Drawer.title "Order 1042" ] model.order [ details ]
    , ConfirmDialog.view CancelMsg [ ConfirmDialog.title "Cancel order?" ] model.cancel
    , CommandPalette.view PaletteMsg [ CommandPalette.sections sections ] model.palette
    , Toast.view ToastMsg [] model.toasts
    ]
-- without an AppShell: Overlay.host { attributes = [], page = [ ... ], overlays = [ ... ] }
```

You do not write: a flag that makes the page inert (it is inert while any dialog in
the list is open), a call that gives focus back after an action replaced the button
that had it, the id of the opener of a dialog that a route or the palette opens
(`Drawer.open ""`), a copy of a toast inside a dialog (toasts move to the top of the
window and `Tab` reaches them after the footer), or anything for the landmarks. Keep
every overlay in the list all the time, also while it is closed. In a page module of
your own, `List.map (Overlay.map PageMsg) overlays` gives the list to the main module.

**Leaving a page with unsaved work.** `LeaveGuard` asks "Leave without saving?" on a
link, on your own navigation and on the browser's Back and Forward buttons. Six
functions, and the complete application is at the top of
[`Klar.LeaveGuard`](ai/modules/Klar.LeaveGuard.md): `initAt` (with the `Key` and the `Url`),
`setDirty` (with the comparison, `draft /= saved`; in the branches of the messages that edit a form, never in a wrapper after every message, because "Leave" gives the changes up and a flag that says "dirty" again re-arms the guard), `request` (for links and your own
navigation), `onUrlChange` (call it from your `onUrlChange`: it answers the buttons and
says which page to show), `update` and `view`. With an `AppShell` the link click is a message of
your own (`LeaveGuard.request`, then `Nav.pushUrl`), `onUrlChange` stays the shell's
(`AppShell.onUrlChange ShellMsg`) and the `Url` that `AppShell.update` returns goes to
`LeaveGuard.onUrlChange`: the wiring, tried in Chrome, is in the docs of `LeaveGuard`. You do not write: a field for the
address you are going back from, a target type that remembers where the request came
from, a call to `Nav.forward` (never undo a Back yourself: the guard does it), or the code
that remembers where focus was. Give the links that can ask an `id` so that focus returns to
them after "Stay".

**A form: declare it once.** The values, the rules, the steps, the rows of a repeating
group, what the server refused and whether anything changed live in one `Form.State`.
Declare the form as a constant with `Klar.Form.Spec`, keep the state and one message in
your model, and draw each control with one call:

```elm
form : Form.Form () Fields Values
form =
    Spec.define "customer" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.build

-- update
FormMsg inner -> Form.update form inner model.form |> Tuple.mapBoth (\s -> { model | form = s }) (Cmd.map FormMsg)
Save ->
    case Form.toValues Locale.default form model.form of
        Ok values -> ( { model | status = FormLayout.Submitting }, send values )
        Err _ -> Form.reveal form model.form |> Tuple.mapBoth (\s -> { model | form = s }) (Cmd.map FormMsg)
Refused problems -> Form.rejected problems form model.form |> Tuple.mapBoth ...

-- view
let v = Form.bind Locale.default FormMsg form model.form
in FormLayout.view [ FormLayout.onSubmit Save ] [ Form.summary v, Form.textInput v fields.name [], Form.select v fields.country options [] ]
```

A wizard adds `Spec.step` and `Form.advance`, `Form.back`, `Form.stepper` and draws the fields
of the current step inside `Form.stepBody v [ ... ]` (without it Elm reuses the focused input
of one step for the field at the same place in the next, and `advance` shows "Required" on a
field nobody touched); a group such as the
contacts of a supplier is `Spec.rows` with `Form.rowFields`, `Form.addRow` and
`Form.removeRow`. You do not write: a state, a message or a DOM id for any field, a dirty
test (`Form.isDirty`), "validate before Next", the list of everything that is wrong on the
review step, the focus after an add, a remove, a step or a refused save, or a second copy
of the server's problems. `Klar.Form`'s module documentation has a complete example; the
`Klar.Ids` of your id types are written once and shared with the rule builder.

**Ids from your database, in the selects.** The value of an option is your own
type, and the select hands the same value back:

```elm
type CustomerId = CustomerId Int

type alias Model = { customer : Select.State CustomerId }

Select.view CustomerMsg
    [ Select.label "Customer"
    , Select.options (List.map (\c -> Select.option c.id c.name) customers)
    , Select.valueText (\(CustomerId n) -> "Customer #" ++ String.fromInt n)
    ]
    model.customer

Select.value model.customer -- Maybe CustomerId
```

`valueText` says how to write an id that is in none of the options (a saved value
whose option the server has not sent); without it the field says "Unknown value".
For a record that is not in the list yet, `Select.setOption` stores the option
together with the id. Values are compared with `==`, so use plain data.

**Ids, once per type.** A table keeps the selection and the open rows by id, a tree its
open nodes, a picker its choices. Say once how your id type is written as a key and read
back, as a `Klar.Ids`, and every component that holds that type speaks it:

```elm
orderIds : Ids OrderId -- import Klar.Ids as Ids exposing (Ids)
orderIds =
    Ids.make { toKey = OrderId.toString, fromKey = OrderId.fromString }

Table.rowId orderIds .id
Table.selectedIds orderIds model.table -- List OrderId, for "assign 40 orders"
Table.setSelected orderIds [ id ] False model.table
```

The table is typed by the id (`Table.State OrderId`), so a table of orders cannot be
asked about customer ids. Text and whole-number ids have `Ids.string` and
`Ids.int`.

`Klar.Tree` works the same way (`Tree.State RegionId`, nodes built with
`Tree.leaf regionIds id label`), and so do the pickers, `Sortable` and `Klar.SideNav`,
whose keys are your pages: `Ids.list pageToString [ Orders, Settings ]` reads a page back
from the list, and `SideNav.item pageIds { key = Orders, ... }` makes a misspelled key a
compile error. `Klar.JsonViewer` keeps text: its ids are paths into the JSON
document, not ids of your data.

**Columns named once.** A table column, a sort, a filter and a hidden column
refer to the same value, so a misspelled id is a compile error:

```elm
customer : Table.ColumnId
customer = Table.columnId "customer"

Table.text customer "Customer" .customer [ Table.filterText ]
Table.setSort [ ( customer, Table.Ascending ) ] state
```

A server-mode table gives you a `Table.query`; `Table.columnName` turns the ids in
it into the names your API knows.

**A list on a server** (a table with a filter bar and saved views) is `Klar.ServerList`: one
`State` and one `Msg` for the three, and no comparing, page reset or ticket in your code.
`ServerList.update` returns a `Step` with the `request` to send (the table's `Query` and the
filter bar's `Rule`; you make the call and answer with `ServerList.gotPage request result at`),
the saved views to store, and a command. See `recipes/inbox`. For a bulk action or an export of
everything that matches, `ServerList.target` gives the ids that were picked or the query, the
rule and the exceptions.

**Dom ids, once.** Every component with state takes a DOM id in `init`, and the
ids must be unique on the page. Keep them in one module as named values (see the
`Klar` module documentation).

**Rules and filters.** Fields describe what a rule can talk about. Limit what a
field offers with `Rule.withOperators` (an entity needs `Is`, `IsNot`, `IsAnyOf`,
not `Contains`), and use `Rule.bareField` when the rows live on the server and the
fields only drive the filter bar:

```elm
fields =
    [ Rule.textField "customer" "Customer" .customer
    , Rule.choiceField "owner" "Owner" owners (.owner >> ownerValue)
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    ]
```

A saved rule is plain data (`Rule.encode`, `Rule.decoder`). Translate it into your
own query by walking the tree on the server or in the application; `Rule.matches`
runs it against rows that are in the browser.

**Dates.** `Klar.Date` is opaque: there is no 31 February. Make one with
`Date.fromIso` or `Date.fromParts` (a `Maybe`), read it with `Date.year`,
`Date.month` and `Date.day`.

**Keyboard shortcuts** are built from keys, not written as text:
`Shortcut.mod (Shortcut.char 'k')`, `Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]`.

## 4. Telling an AI how to use Klar

An AI that builds the application needs three things: the files to read, the rules, and a
starting point. Klar ships them:

- **Read:** [AI.md](AI.md) (the mental model, the standard application, the ten rules, "I need X,
  use module Y", the known traps), [ai/klar-index.json](ai/klar-index.json) (every module: when to
  use it, when not, its types and main functions) and [ai/modules/](ai/modules/README.md) (every
  signature and the documentation of each module as plain text). They are generated from the doc
  comments by `npm run gen:ai-docs`, so they are never stale. [llms.txt](llms.txt) is the map.
- **Copy:** [template/](template/README.md) is a working application; [recipes/](recipes/README.md)
  are complete programs for the common screens.
- **Rules:** drop this paragraph into the `CLAUDE.md` (or the project instructions) of your
  application, with the path where Klar lives (`vendor/klar` below):

  > This application uses Klar (`vendor/klar`), a UI toolkit for Elm. Use only the modules that
  > Klar exposes (`Klar.*`, listed in `vendor/klar/elm.json`), never `Klar.Internal.*`, and never
  > copy or edit a Klar file. Before you write any screen, read `vendor/klar/AI.md` and search
  > `vendor/klar/ai/klar-index.json`; then read `vendor/klar/ai/modules/<Module>.md` for the
  > modules you use and the nearest program in `vendor/klar/recipes/`. Never write your own popup,
  > dialog, focus, scroll, date, keyboard-shortcut or virtual-list code: a Klar module does it.
  > Write no CSS, no `class`, no `style` attribute and no JavaScript. Keep ids as your own types
  > and backend data as `Remote`. If Klar lacks something, write the best honest version, put
  > `-- KLAR GAP: <what is missing>` above it and list it in `LIBRARY-REQUESTS.md`.
