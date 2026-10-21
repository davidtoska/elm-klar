# Using Klar in an application

This is the guide for someone who builds an application with Klar, as the
[README](README.md) shows it, but in more detail: how to get the package into a
project (also before it is published), how to keep it untouched, and how the
parts fit together in an application that talks to a backend.

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
            "elm/time": "1.0.0"
        },
        "indirect": { "elm/virtual-dom": "1.0.5" }
    }
}
```

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
    { orders : Remote (List Order), table : Table.State }

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
When you refresh data that is already there, keep the old `Success` and add
`Table.refreshing True`: the rows stay, dimmed.

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
