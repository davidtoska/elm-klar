# Using Klar in an application

This is the guide for someone who builds an application with Klar, as the
[README](README.md) shows it, but in more detail: how to get the package into a
project (also before it is published), how to keep it untouched, and how the
parts fit together in an application that talks to a backend.

## Start here

A complete application with the frame of Klar: a `Browser.application` with an
`AppShell`, a side menu typed by your own `Page`, and a `Remote` that a table draws.
It compiles as it stands. Copy it, then replace `fetchOrders` with a real request
(see section 3).

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

**`src/Main.elm`.**

```elm
module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Icon as Icon
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SideNav as SideNav
import Klar.Table as Table
import Process
import Task
import Url exposing (Url)


type Page
    = Orders
    | Customers


type alias Order =
    { id : String, customer : String, total : Float }


type alias Model =
    { key : Nav.Key
    , page : Page
    , sideNav : SideNav.State Page
    , table : Table.State String
    , orders : Remote (List Order)
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | SideNavMsg SideNav.Msg
    | TableMsg Table.Msg
    | GotOrders (Result Remote.Problem (List Order))
    | Reload
    | NoOp


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        page =
            pageFromUrl url
    in
    ( { key = key
      , page = page
      , sideNav = SideNav.init "main-nav" |> SideNav.reveal page navigation
      , table = Table.init "orders"
      , orders = Loading
      }
    , fetchOrders
    )


{-| Stands for a request: replace it with `Http.get` and `Result.mapError`.
-}
fetchOrders : Cmd Msg
fetchOrders =
    Process.sleep 600
        |> Task.map (\_ -> Ok [ Order "1042" "Aurora Logistics Ltd" 1250.5, Order "1043" "Fjord Foods" 310 ])
        |> Task.perform GotOrders


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                page =
                    pageFromUrl url
            in
            ( { model | page = page, sideNav = SideNav.reveal page navigation model.sideNav }
            , AppShell.resetScroll shellId NoOp
            )

        SideNavMsg m ->
            let
                ( sideNav, cmd ) =
                    SideNav.update m model.sideNav
            in
            ( { model | sideNav = sideNav }, Cmd.map SideNavMsg cmd )

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        Reload ->
            ( { model | orders = Loading }, fetchOrders )

        NoOp ->
            ( model, Cmd.none )

        GotOrders result ->
            ( { model | orders = Remote.fromResult result }, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "Acme Operations"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id shellId
            , AppShell.brand
                (AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Nothing })
            , AppShell.sidebar
                (SideNav.view SideNavMsg
                    [ SideNav.entries navigation, SideNav.current model.page ]
                    model.sideNav
                )
            ]
            [ viewPage model ]
        ]
    }


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Orders ->
            Html.div []
                [ PageHeader.view [ PageHeader.title "Orders" ]
                , Table.view TableMsg
                    [ Table.columns
                        [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                        , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
                        , Table.float (Table.columnId "total") "Total" 2 .total [ Table.footerSum ]
                        ]
                    , Table.rows model.orders
                    , Table.rowId Table.stringIds .id
                    , Table.onRetry Reload
                    ]
                    model.table
                ]

        Customers ->
            PageHeader.view [ PageHeader.title "Customers" ]



-- NAVIGATION


shellId : String
shellId =
    "app-shell"


pageToString : Page -> String
pageToString page =
    case page of
        Orders ->
            "orders"

        Customers ->
            "customers"


pageKeys : SideNav.Keys Page
pageKeys =
    SideNav.keys pageToString


navigation : List (SideNav.Entry Page msg)
navigation =
    [ SideNav.item pageKeys { key = Orders, label = "Orders", href = "#/orders" }
        |> SideNav.withIcon Icon.clipboardCheck
    , SideNav.item pageKeys { key = Customers, label = "Customers", href = "#/customers" }
        |> SideNav.withIcon Icon.users
    ]


pageFromUrl : Url -> Page
pageFromUrl url =
    case url.fragment of
        Just "/customers" ->
            Customers

        _ ->
            Orders
```

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
            "elm/html": "1.0.1",
            "elm/json": "1.1.4",
            "elm/time": "1.0.0",
            "elm/url": "1.0.0"
        },
        "indirect": { "elm/virtual-dom": "1.0.5" }
    }
}
```

`elm/url` is only needed by an application that uses `Browser.application` (every
application with an `AppShell` does, see "Start here"); Klar itself does not
import it. Add the packages your own code imports (`elm/http` for requests, say) the
same way.

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
   it, in the `CLAUDE.md` of the application (or its README):

   > Klar (`vendor/klar`) is frozen. Never edit, copy or wrap a Klar component, and
   > never import a module that Klar does not expose. If a component is missing a
   > setting or a function, write what you need in `LIBRARY-REQUESTS.md` instead and
   > build the page without it.

   For Claude Code the folder can also be made read-only with a permission rule in
   `.claude/settings.json` (check the syntax of the rules in the Claude Code
   documentation):

   ```json
   { "permissions": { "deny": ["Edit(vendor/klar/**)", "Write(vendor/klar/**)"] } }
   ```

   A rule stops the accident, not the determined; the check in layer 2 is what
   catches the rest.

## 3. An application, in the order you write it

**One stylesheet.** `Klar.stylesheet` once in the view of the root (see the README).

**Data from a backend, with `elm/http` in the application.** Klar never sends a
request and never imports `elm/http`. It draws the state of one, as a
[`Remote`](src/Klar/Remote.elm). Turn the result of a request into a `Remote` and
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
When you refresh data that is already there, keep the old `Loaded` and add
`Table.refreshing True`: the rows stay, dimmed.

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
[`Klar.LeaveGuard`](src/Klar/LeaveGuard.elm): `initAt` (with the `Key` and the `Url`),
`setDirty` (with the comparison, `draft /= saved`), `request` (for links and your own
navigation), `onUrlChange` (call it from your `onUrlChange`: it answers the buttons and
says which page to show), `update` and `view`. You do not write: a field for the
address you are going back from, a target type that remembers where the request came
from, a call to `Nav.forward`, or the code that remembers where focus was. Do not undo
a Back with `Nav.forward 1` yourself: it reports the address it leaves, once at once,
and a handler that asks again loops forever (measured; the guard never does it). Give
the links that can ask an `id` so that focus returns to them after "Stay". Run
`node scripts/test-leave-guard.mjs` (needs Chrome) to see the buttons answered in a
real browser.

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

**Row ids, once.** A table keeps the selection and the open rows by id. Say once how
your id type is written as a key and read back, and the table speaks your type:

```elm
orderRows : Table.RowIds OrderId
orderRows =
    Table.rowIds { toKey = OrderId.toString, fromKey = OrderId.fromString }

Table.rowId orderRows .id
Table.selectedIds orderRows model.table -- List OrderId, for "assign 40 orders"
Table.setSelected orderRows [ id ] False model.table
```

The table is typed by the id (`Table.State OrderId`), so a table of orders cannot be
asked about customer ids. Text and whole-number ids have `Table.stringIds` and
`Table.intIds`.

`Klar.Tree` works the same way (`Tree.nodeIds`, `Tree.State RegionId`, nodes built
with `Tree.leaf regions id label`), and `Klar.SideNav` is typed by its keys
(`SideNav.keys`, `SideNav.item pages { key = Orders, ... }`), so a misspelled key is
a compile error. `Klar.JsonViewer` keeps text: its ids are paths into the JSON
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
