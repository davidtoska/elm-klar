module Klar.Table exposing
    ( view
    , State, init, Msg, update, focus
    , ColumnId, columnId, columnName
    , Query, Direction(..), Filter(..), query, setQuery, encodeQuery, queryDecoder, sort, setSort, page, setPage, pageSize, setPageSize, search, setSearch, filters, setFilter, clearFilters
    , Selection(..), selection, selectedIds, selectedCount, isSelected, select, deselect, setSelectedIds, clearSelection, dropAllMatching
    , expandedIds, isExpanded, expand, collapse, toggle, setExpandedIds, collapseAll, isColumnVisible, setColumnVisible, density, setDensity
    , Attribute, columns, remote, rowId, rowLabel, server, ariaLabel, locale, settings
    , searchable, searchPlaceholder, searchDebounce, rowFilter, activeExternalFilters, onResetFilters, multiSort
    , selectable, bulkActions, rowActions, onRowClick, currentRow, expandedRow, rowTone, rowDisabled
    , onRefresh, onRetry, emptyState
    , toolbarActions, exportCsv, csvSeparator, columnChooser, densityToggle
    , pageSizes, rangeText, unpaged, virtual, zebra, maxHeight, fillHeight
    , Rows, prepareRows, rowsArray, remotePrepared
    , Column, text, int, float, money, date, maybeDate, badge, status, bool, custom, actions
    , ColumnAttribute, width, minWidth, alignRight, alignCenter, pinned, hiddenByDefault, alwaysVisible, wrap, noTooltip, cell, hint
    , sortText, sortNumber, sortMaybeNumber, sortDate, sortWith, unsortable
    , notSearchable, includeInSearch, exportAs, notExported
    , filterText, filterSelect, filterOptions, filterValue, filterRange
    , footer, footerSum, footerAverage
    )

{-| A data table for records: search, column filters, sorting, selection with
bulk actions, row actions, expandable rows, CSV export and pagination.

Use when: people have to find, compare and act on many rows of the same kind: orders, customers, shipments.
Do not use when: you show a short list of things to open (as `Klar.ListItem`) or a long, plain list of equal rows (as `Klar.VirtualList`).
Quick path: `init`, `update`, `view`, `columns`, `remote`, `rowId`, `ariaLabel`; in server mode also `server`, `query`, `searchable`, `onRowClick`, `selectable`, `bulkActions` (read `selection`), `exportCsv`, `onRetry`

**Quick path: a client table.** All rows are in the browser; the table searches,
filters, sorts and pages them. In this order:

  - `init "orders"` in your `init` (the string is the DOM id), a `Table.State String` in the model;
  - `update` for a `TableMsg Table.Msg`, mapped back with `Cmd.map TableMsg` (the `Cmd`
    moves focus and saves the CSV export);
  - `Table.view TableMsg [ ... ] model.table` with the attributes `columns` (made with
    `Table.text`, `int`, `float`, `money`, `date`, each with a `Table.columnId` named once),
    `remote` (a `Remote (List row)`, which draws the skeleton, the failure and the empty
    state), `rowId` (a [Klar.Ids](Klar-Ids): `Ids.string`, `Ids.int`, or `Ids.make` for your
    own id type) and `ariaLabel` (the name screen readers hear);
  - when you need them: `searchable`, `selectable`, `bulkActions`, `rowActions`, `onRetry`.

The view of the whole table is one function:

    import Html exposing (Html)
    import Klar.Ids as Ids
    import Klar.Money exposing (Money)
    import Klar.Remote exposing (Remote)
    import Klar.Table as Table

    type alias Order =
        { id : String, customer : String, total : Money }

    ordersTable : (Table.Msg -> msg) -> msg -> Remote (List Order) -> Table.State String -> Html msg
    ordersTable toMsg retry orders state =
        Table.view toMsg
            [ Table.columns
                [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
                , Table.money (Table.columnId "total") "Total" .total [ Table.filterRange, Table.footerSum ]
                ]
            , Table.remote orders
            , Table.rowId Ids.string .id
            , Table.ariaLabel "Orders"
            , Table.searchable
            , Table.onRetry retry
            ]
            state

**Quick path: a server table.** The rows live on the server; you give the table one page
of them and the number of matches, and it only records what the user asked for. A server list
with a filter bar or saved views is [Klar.ServerList](Klar-ServerList), which does every step
below for you (`example/src/Examples/Inbox.elm`). A server table on its own needs, in order:

  - `Table.server { total = model.total }` and `Table.remote model.page` (a `Remote` of the
    current page only);
  - `Table.query` before and after `update`: when it differs, ask the server. The search
    box and the filter fields already wait 350 ms (`searchDebounce`); a sort click and a page change
    arrive at once, so **write no debounce of your own**. Give each request a ticket and drop an
    answer that is not for the latest one;
  - `searchable` for the search box, `onRowClick` for the row that opens a drawer or a page
    (`Drawer.open ""`, and `currentRow` to mark it), `selectable` and `bulkActions` for
    "assign these 12", `exportCsv` for the download;
  - in the bulk action's branch of your `update`, read `Table.selection`, not `selectedIds`:
    after "Select all N matching" it is `AllMatching { except }`, every row of the query but
    the exceptions, and `selectedIds` is `[]`. Send the query and the exceptions to the server;
  - `onRetry` for a failure with no rows to keep, and `Table.setPage 1` whenever the filter that
    you keep outside the table (a `FilterBar` rule) changed.

The view with all of it, the comparison that decides whether to ask, and the bulk action:

    import Html exposing (Html)
    import Klar.Button as Button
    import Klar.Ids as Ids
    import Klar.Remote exposing (Remote)
    import Klar.Table as Table

    type alias Order =
        { id : String, customer : String }

    inbox : (Table.Msg -> msg) -> { retry : msg, open : Order -> msg, assign : msg } -> Int -> Remote (List Order) -> Table.State String -> Html msg
    inbox toMsg on total page state =
        Table.view toMsg
            [ Table.columns
                [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
                ]
            , Table.server { total = total }
            , Table.remote page
            , Table.rowId Ids.string .id
            , Table.ariaLabel "Orders"
            , Table.searchable
            , Table.onRowClick on.open
            , Table.selectable
            , Table.bulkActions [ Button.view [ Button.small, Button.onClick on.assign ] "Assign" ]
            , Table.exportCsv "orders.csv"
            , Table.onRetry on.retry
            ]
            state

    -- the third part is True when the user asked for something new: ask the server
    asked : Table.Msg -> Table.State String -> ( Table.State String, Cmd Table.Msg, Bool )
    asked msg before =
        let
            ( after, cmd ) =
                Table.update msg before
        in
        ( after, cmd, Table.query after /= Table.query before )

    -- what "Assign" acts on: some ids, or every row of the query but some
    assignTarget : Table.State String -> { query : Table.Query, ids : List String, allBut : Maybe (List String) }
    assignTarget state =
        case Table.selection Ids.string state of
            Table.Selected ids ->
                { query = Table.query state, ids = ids, allBut = Nothing }

            Table.AllMatching { except } ->
                { query = Table.query state, ids = [], allBut = Just except }

**Quick path: many rows.** Tens of thousands of rows in client mode: prepare them once,
when they arrive, with `prepareRows`, keep the `Rows` in the model and give them to
`remotePrepared` instead of `remote`; add `virtual` when people read the table by scrolling.

The columns are given twice, once to `prepareRows` and once to the view:

    import Array
    import Html exposing (Html)
    import Klar.Ids as Ids
    import Klar.Locale as Locale
    import Klar.Remote exposing (Remote)
    import Klar.Table as Table

    type alias Order =
        { id : String, customer : String }

    columns : List (Table.Column Order msg)
    columns =
        [ Table.text (Table.columnId "id") "Order" .id []
        , Table.text (Table.columnId "customer") "Customer" .customer []
        ]

    prepare : List Order -> Table.Rows Order
    prepare orders =
        Table.prepareRows Locale.default columns (Array.fromList orders)

    bigTable : (Table.Msg -> msg) -> Remote (Table.Rows Order) -> Table.State String -> Html msg
    bigTable toMsg rows state =
        Table.view toMsg
            [ Table.columns columns
            , Table.remotePrepared rows
            , Table.rowId Ids.string .id
            , Table.ariaLabel "Orders"
            , Table.searchable
            , Table.virtual
            ]
            state

With 50 000 prepared rows of 7 columns and two footer sums, measured in the optimized build in
headless Chrome, from the event to two animation frames later (about 33 ms of each number is
those frames): a sort click or a page change about 40 ms, a keystroke 30 to 55 ms. When the
search keeps 37 000 of the rows, a page change or a sort click is 60 to 75 ms and a keystroke
about 55 ms, because every message goes through the matching rows once (the sums of the footers
read numbers kept per row, not the rows); with a selection in a result that large add up to 25 ms.
Everything stays under 100 ms on a desktop; a phone is several times slower. The rest of this
page is the reference.

See also [Klar.ListItem](Klar-ListItem) and
[Klar.VirtualList](Klar-VirtualList). The page controls in the footer are
[Klar.Pagination](Klar-Pagination).

A table works in one of two modes. In **client mode** you give it all the rows
and it searches, filters, sorts and paginates them itself. Only the current page
is turned into HTML. Thousands of rows are fine, and tens of thousands are too once
the rows are prepared (see "Many rows" below).

    import Klar.Button as Button
    import Klar.Menu as Menu
    import Klar.Remote exposing (Remote)
    import Klar.Table as Table

    -- model
    { orders : Remote (List Order)
    , table : Table.State OrderId -- Table.init "orders"
    }

    orderIds : Ids OrderId -- import Klar.Ids as Ids exposing (Ids)
    orderIds =
        Ids.make { toKey = OrderId.toString, fromKey = OrderId.fromString }

    customer : Table.ColumnId
    customer =
        Table.columnId "customer"

    -- update
    TableMsg m ->
        let
            ( table, cmd ) =
                Table.update m model.table
        in
        ( { model | table = table }, Cmd.map TableMsg cmd )

    -- view
    Table.view TableMsg
        [ Table.columns
            [ Table.text customer "Customer" .customer [ Table.pinned, Table.filterText ]
            , Table.text (Table.columnId "city") "City" .city [ Table.width 140, Table.filterSelect ]
            , Table.int (Table.columnId "items") "Items" .items [ Table.filterRange, Table.footerSum ]
            ]
        , Table.remote model.orders
        , Table.rowId orderIds .id
        , Table.searchable
        , Table.selectable
        , Table.bulkActions [ Button.view [ Button.small, Button.onClick DeleteSelected ] "Delete" ]
        , Table.rowActions (\order -> [ Menu.item "Open" (OpenOrder order.id) ])
        ]
        model.table

In **server mode** you give it the current page of rows and the number of rows
that match, and the table only records what the user asks for. Compare
`Table.query` before and after `update`, and fetch when it changed:

    TableMsg m ->
        let
            ( table, cmd ) =
                Table.update m model.table

            fetch =
                if Table.query table /= Table.query model.table then
                    Api.searchOrders (Table.query table)

                else
                    Cmd.none
        in
        ( { model | table = table }, Cmd.batch [ Cmd.map TableMsg cmd, fetch ] )

    Table.view TableMsg
        [ Table.columns columns
        , Table.server { total = model.total }
        , Table.remote model.page -- Remote (List Order): the current page only
        , Table.onRetry Retry
        ]
        model.table

Text typed into the search box and the filter fields reaches `query` after a
short pause in server mode (`searchDebounce`, 350 ms by default) and at once in
client mode.

**State.** The `State` holds what the user can change: sort, page, page size,
search, filters, selection, expanded rows, hidden columns and density. Read it
with the accessors (`query`, `selectedIds` ...) and compare before and after
`update` to react to a change; there are no out-messages. Columns, rows and
options are not part of the state, `view` gets them on every call. What is not a
state change (a row click, a row action, a bulk action, refresh, retry) is a
message of your own.

**Remote data.** `remote` takes a `Remote` ([Klar.Remote](Klar-Remote)). The table
draws the loading skeleton, the failure with a retry button and the empty state
itself; you give it the current value and the message for the retry button
(`onRetry`).

**Columns** are data: an id (unique in the table), a title and a function that
reads the cell's value from a row. The value is shown in the default cell and
used for search, sorting, CSV export and the filters. Helpers set sensible
defaults for common kinds: `text`, `int`, `float`, `date`, `maybeDate`, `badge`,
`status`, `bool`, `custom` and `actions`. Column attributes such as `width`,
`pinned` or `filterText` refine them.

**Locale.** The built-in text (the search placeholder, the filter popovers, the
labels read by screen readers, the Yes and No of `bool` columns) comes from the
table's `locale`: English by default, Norwegian with `Locale.nb`
([Klar.Locale](Klar-Locale)). The locale also decides number and date formats,
the alphabetical order of text columns and the default CSV separator. Titles and
everything else you pass in are your own text.

**Layout.** The header and the totals row stay in view while the rows scroll
(`maxHeight`, `fillHeight`), the first column can be `pinned` while the rest
scrolls sideways, and columns keep their widths while the user pages (the layout
is fixed: `width` sets a column's width and the other columns share the rest).
Rows are single-line: long values are cut with an ellipsis and a tooltip, unless
the column is set to `wrap`.

**Keyboard.** Header buttons sort with Enter or Space (with Shift for a
multi-column sort, see `multiSort`). The rows are one tab stop, not fifty: when
rows are clickable, selectable, expandable or have a menu, Tab reaches the row
that last had focus, and from it that row's checkbox and menu button. ArrowUp,
ArrowDown, PageUp, PageDown, Home and End move to other rows (which then get the
tab stops of their own controls), also from the row's checkbox and menu button (where
ArrowDown opens the menu), Enter opens the row (or its menu, when the row
does nothing else), Space selects it (Shift+Space, or Shift and a click on a
checkbox, the rows from the one picked last; Ctrl+A or Cmd+A every row of the
page), ArrowRight and ArrowLeft expand and collapse it, and Shift+F10 or the menu key opens its menu; a `rowDisabled` row
only takes part in the movement. Controls you put in an `actions` column stay tab
stops in every row. Filter popovers and menus close with Escape, and Escape in
the search box clears it. Both use the key up (its default is prevented), so a
dialog or drawer that closes only on an Escape that nothing inside took stays open;
an Escape in the empty box is left to it. When an action removes the control that had focus (a
bulk action that deletes the selected rows takes the bulk bar with it), give the
table focus again with `focus`.

**Accessibility.** Sortable headers carry `aria-sort`, the table has
`aria-rowcount`, `aria-colcount` and, while it loads, `aria-busy`, and a polite
live region announces loading, refreshing, the range shown and the sort order.
A table stays a plain `table`, also when its rows take focus, so that a screen
reader can read it cell by cell; a selectable row says `aria-selected`, and its
checkbox whether it is checked. With `expandedRow` the table is a `treegrid` (focus
on rows, ArrowRight and ArrowLeft expand and collapse, as in the ARIA pattern):
screen readers leave the arrow keys to the rows, the first cell of a row is its row
header, a selectable tree grid is `aria-multiselectable`, a row that can open its
details says `aria-expanded`, and the details are a row one level down.
Name the table with `ariaLabel`; the page controls in its footer are named after it
too ("Pages of Orders"), so that two tables on a page can be told apart.
`rowLabel` names a row for screen readers ("Select Ada Lovelace" on its checkbox).
In Windows high contrast the focused, selected, current and toned rows are drawn
with system colors.

**Many rows.** Client mode searches, filters and sorts inside `view`: sort keys
are made once per row, a missing sort or filter costs nothing, and only the
current page is turned into HTML. That is quick for a few thousand rows and slow
for tens of thousands, because every value is turned into text again each time. So
for many rows, make the work once, when the rows arrive, and keep the result in your
model instead of the `List`:

    Loaded orders ->
        { model | orders = Loaded (Table.prepareRows locale columns (Array.fromList orders)) }

    Table.remotePrepared model.orders

The table then has, for every row, the text that the search looks in and, for every
sortable column, the rows in order, and for the columns with a footer sum their numbers.
With 50 000 rows (numbers in the head of this page) a sort click, a page change and a
keystroke stay under 100 ms including two frames, also when the search keeps most of the
rows; a page change does not sort again, but it does go through the matching rows once. Search and sorting need no other rows than
these; `rowsArray` gives the `Array` to the other parts of the page that want the
rows, such as [Klar.VirtualList](Klar-VirtualList), so that the page keeps one
collection. If the rows change (an order is edited), prepare them again.

**Paging or scrolling.** Use pages (the default) when people search, filter and
sort to find a few rows, and when a row can hold anything: details that expand, text
that wraps, a menu. Use `virtual` when people read a long table by scrolling, jump to
its end or go through it with the keyboard: only the rows in view are drawn, every
row is the height of the density, and the header and the totals stay in view. Do not
use `unpaged` for many rows: it turns every row into HTML.

**Narrow places.** A table in a narrow card scrolls sideways, and a shadow at the
edge shows that columns are cut off. Put the columns that matter first (the first can
be `pinned`), give the others a `minWidth`, and leave out what people rarely need
with `hiddenByDefault`; with `columnChooser` they can add it.

**How many columns fit.** The table never squeezes a column below its `minWidth`: 120
pixels for text, 104 to 124 for numbers, dates and badges. Next to a 232 pixel
sidebar a 1280 pixel window leaves about 1000 pixels, so eight or nine columns fit and
the eleventh is behind the sideways scroll, with its footer sum. Plan for 1000 pixels:
give the columns that carry the sums a short `width`, lower the `minWidth` of the
others, and put what people rarely need behind `hiddenByDefault`. The shadow at the
edge is the only hint the table gives; it does not count columns for you.


# View

@docs view


# State

@docs State, init, Msg, update, focus

The `id` of `State id` is the type of your row ids (`State OrderId`). Declare how
it is written as a key once, as a [Klar.Ids](Klar-Ids) (`Ids.make`, or `Ids.string` and
`Ids.int`), and the selection and the expanded rows come back in your own type, with no
converting to text and back. The same `Ids` serves every other component that holds that type.

A table that never needs its row ids (no `selectable`, no `expandedRow`) can use
any type for `id`, for example `Table.State ()`.


# Sort, page, search and filters

Read these after `update` to see what the user asked for, or set them to restore
a saved view.

@docs ColumnId, columnId, columnName

@docs Query, Direction, Filter, query, setQuery, encodeQuery, queryDecoder, sort, setSort, page, setPage, pageSize, setPageSize, search, setSearch, filters, setFilter, clearFilters


# Selection

@docs Selection, selection, selectedIds, selectedCount, isSelected, select, deselect, setSelectedIds, clearSelection, dropAllMatching


# Expanded rows, columns and density

@docs expandedIds, isExpanded, expand, collapse, toggle, setExpandedIds, collapseAll, isColumnVisible, setColumnVisible, density, setDensity


# Basic attributes

@docs Attribute, columns, remote, rowId, rowLabel, server, ariaLabel, locale, settings


# Search, filters and sorting

@docs searchable, searchPlaceholder, searchDebounce, rowFilter, activeExternalFilters, onResetFilters, multiSort


# Selection and rows

@docs selectable, bulkActions, rowActions, onRowClick, currentRow, expandedRow, rowTone, rowDisabled


# Loading and empty states

@docs onRefresh, onRetry, emptyState


# Toolbar and export

@docs toolbarActions, exportCsv, csvSeparator, columnChooser, densityToggle


# Pagination and layout

@docs pageSizes, rangeText, unpaged, virtual, zebra, maxHeight, fillHeight


# Many rows

Prepared rows are made once for a list of rows that arrives or changes (see "Many
rows" at the top).

@docs Rows, prepareRows, rowsArray, remotePrepared


# Columns

@docs Column, text, int, float, money, date, maybeDate, badge, status, bool, custom, actions


# Column layout and content

@docs ColumnAttribute, width, minWidth, alignRight, alignCenter, pinned, hiddenByDefault, alwaysVisible, wrap, noTooltip, cell, hint


# Column sorting

@docs sortText, sortNumber, sortMaybeNumber, sortDate, sortWith, unsortable


# Column search and export

@docs notSearchable, includeInSearch, exportAs, notExported


# Column filters

@docs filterText, filterSelect, filterOptions, filterValue, filterRange


# Column footers

@docs footer, footerSum, footerAverage

-}

import Array exposing (Array)
import Browser.Dom as Dom
import Dict exposing (Dict)
import File.Download as Download
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Date as Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Internal.Window as Window
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Money as Money exposing (Money)
import Klar.Pagination as Pagination
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Search as Search
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Table.Core as Core
import Klar.Table.Csv as Csv
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Sort as Sorting
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Table.Types as Types
import Klar.Tag as Tag
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Density(..), Tone)
import Process
import Set exposing (Set)
import Task


{-| The direction of a sort: `Ascending` (A to Z, smallest or earliest first)
or `Descending`. Used in `Query` and `setSort`.
-}
type Direction
    = Ascending
    | Descending


{-| A column filter, as the user set it in the header or as you restore it with
`setFilter`.

  - `Contains text` - the column text contains `text` as one piece, ignoring case
    and accents (the search box, in contrast, looks for each word separately)
  - `OneOf values` - the value the column keeps for the row is exactly one of
    `values`, case included: its `filterValue` (a stable code) when it has one,
    otherwise its text (`"true"` or `"false"` for a `bool` column)
  - `Between from to` - the column number is within the bounds (inclusive); a
    `Nothing` bound is open. A row without a number does not match, and on a
    column that has no numbers at all every row matches.

-}
type Filter
    = Contains String
    | OneOf (List String)
    | Between (Maybe Float) (Maybe Float)


{-| The id of a column, which sort, filters, column choices and a `Query` refer to.
Make it once with `columnId`, keep it as a value of your own, and give it to the
column and to the functions that talk about the column, so that a misspelled id
cannot happen:

    customer : Table.ColumnId
    customer =
        Table.columnId "customer"

    Table.text customer "Customer" .customer []

    Table.setSort [ ( customer, Table.Ascending ) ] state

-}
type ColumnId
    = ColumnId String


{-| Names a column. The text has to be unique in the table and has to stay the
same: a saved sort, a saved filter and a hidden column refer to it. It is also
what you send to a backend for the column (see `columnName`).
-}
columnId : String -> ColumnId
columnId arg1 =
    fromCoreColumnId (Core.columnId arg1)


{-| The text a column id was made from, for a backend that sorts or filters by a
name, or for a URL.

    Table.query state |> .sort |> List.map (Tuple.first >> Table.columnName)

-}
columnName : ColumnId -> String
columnName arg1 =
    Core.columnName (unwrapColumnId arg1)


{-| Everything a backend needs to produce the rows the user asked for: the
search text, the sort levels (primary first), the column filters (ordered by
column id), the page (the first is 1) and the page size. It is plain data, so
you can compare two queries with `==` and fetch only when it changed, or keep
one in the URL or in a saved view (see `setQuery`).
-}
type alias Query =
    { search : String
    , sort : List ( ColumnId, Direction )
    , filters : List ( ColumnId, Filter )
    , page : Int
    , pageSize : Int
    }


{-| What is selected: `Selected ids`, a list of row ids, or
`AllMatching { except }`. The second only happens in server mode, after the user
chose "Select all N matching": every row that matches the current `query` is
selected, except the ids in `except` (the table cannot list rows it never
received). A new search or filter drops it, because it would then mean other
rows.
-}
type Selection id
    = Selected (List id)
    | AllMatching { except : List id }


{-| What the table remembers: sort, page, page size, search, filters, selection,
expanded rows, hidden columns and density, and which popup and row are open or
focused. Make one with `init`, keep it in your model, change it with `update`
(or the setters in this module) and pass it to `view`.
-}
type State id
    = State Types.Model


{-| A table with nothing sorted, filtered or selected, on page 1 with 25 rows
per page and normal density. The `String` is a DOM id and must be unique on
the page. It is the id of the table's element and the prefix of the ids inside
it (`"orders"` gives `"orders-search"` for the search box, for example).
-}
init : String -> State id
init arg1 =
    fromCoreState (Core.init arg1)


{-| The current request as plain data: search text, sort, filters, page and page
size. In server mode, fetch whenever it changed; in client mode you only need it
to save the table's view (see `setQuery`). The search text and the filters are
the ones in effect, so text still waiting for the debounce is not in it.
-}
query : State id -> Query
query arg1 =
    fromCoreQuery (Core.query (unwrapState arg1))


{-| A query as JSON, to keep it where the application keeps its things (a saved
view, the address, a setting): `Encode.encode 0 (Table.encodeQuery q)`. The library
stores nothing itself. The object has a version, `"v": 1`, and the columns are
written by their name (`columnName`):

    {"v":1,"search":"acme","sort":[{"column":"total","descending":true}],
     "filters":[{"column":"status","oneOf":["open","late"]}],"page":1,"pageSize":25}

A filter is written as `contains` (text), `oneOf` (a list of texts) or `between`
(`[from, to]`, a missing bound is `null`).

-}
encodeQuery : Query -> Encode.Value
encodeQuery arg1 =
    Core.encodeQuery (toCoreQuery arg1)


{-| Reads what `encodeQuery` wrote. It is made for text that has been kept for a long
time or written by another version: a field that is missing takes the value of an
empty query (no search, no sort, no filters, page 1, 25 rows), a field it does not
know is ignored, a filter it does not know is left out (a restored view is better with
one filter less than not at all), and a version newer than 1 is refused, because
reading it as version 1 could be wrong. A page or page size below 1 becomes 1.

    Decode.decodeString Table.queryDecoder text

-}
queryDecoder : Decoder Query
queryDecoder =
    Decode.map fromCoreQuery Core.queryDecoder


{-| Sets the search, sort, filters, page and page size from a query, for example
one restored from the URL or a saved view. The search box and the filter
popovers show the new values; a page or page size below 1 becomes 1. Selected
rows stay selected, but an "all matching" selection (see `Selection`) is dropped
when the search or the filters change.
-}
setQuery : Query -> State id -> State id
setQuery arg1 arg2 =
    fromCoreState (Core.setQuery (toCoreQuery arg1) (unwrapState arg2))


{-| The columns the table is sorted by, primary first, as column ids with a
direction. Empty when nothing is sorted.
-}
sort : State id -> List ( ColumnId, Direction )
sort arg1 =
    List.map (\( id, direction ) -> ( fromCoreColumnId id, fromCoreDirection direction )) (Core.sort (unwrapState arg1))


{-| Sorts by these columns (ids and directions), primary first, and goes back to
page 1. In client mode, ids that match no column, or a column that is
`unsortable`, are ignored.
-}
setSort : List ( ColumnId, Direction ) -> State id -> State id
setSort arg1 arg2 =
    fromCoreState (Core.setSort (List.map (\( id, direction ) -> ( unwrapColumnId id, toCoreDirection direction )) arg1) (unwrapState arg2))


{-| The page the user asked for, counted from 1. A page past the last one is
drawn as the last page (the footer says so, and in client mode the rows are those
of the last page), but this keeps returning the number that was asked for.
-}
page : State id -> Int
page arg1 =
    Core.page (unwrapState arg1)


{-| Goes to this page. The first page is 1; smaller numbers count as 1.
-}
setPage : Int -> State id -> State id
setPage arg1 arg2 =
    fromCoreState (Core.setPage arg1 (unwrapState arg2))


{-| How many rows are on a page: 25 until the user picks another size in the
footer (see `pageSizes`) or you call `setPageSize`.
-}
pageSize : State id -> Int
pageSize arg1 =
    Core.pageSize (unwrapState arg1)


{-| Sets how many rows are on a page (at least 1) and goes back to page 1. A size
that is not in `pageSizes` is still used and shown in the footer.
-}
setPageSize : Int -> State id -> State id
setPageSize arg1 arg2 =
    fromCoreState (Core.setPageSize arg1 (unwrapState arg2))


{-| The search text in effect: what the user typed, trimmed, once any
`searchDebounce` has passed. Empty when there is no search.
-}
search : State id -> String
search arg1 =
    Core.search (unwrapState arg1)


{-| Sets the search text. It shows in the search box, takes effect at once
(without the debounce) and goes back to page 1. A changed search drops an "all
matching" selection (see `Selection`).
-}
setSearch : String -> State id -> State id
setSearch arg1 arg2 =
    fromCoreState (Core.setSearch arg1 (unwrapState arg2))


{-| The column filters in effect, as column ids with their filter, ordered by
column id. Typed text still waiting for the debounce is not included.
-}
filters : State id -> List ( ColumnId, Filter )
filters arg1 =
    List.map (\( id, filter ) -> ( fromCoreColumnId id, fromCoreFilter filter )) (Core.filters (unwrapState arg1))


{-| Sets (`Just`) or removes (`Nothing`) the filter of the column with this id,
and goes back to page 1. The column's filter popover shows the new value.
-}
setFilter : ColumnId -> Maybe Filter -> State id -> State id
setFilter arg1 arg2 arg3 =
    fromCoreState (Core.setFilter (unwrapColumnId arg1) (Maybe.map toCoreFilter arg2) (unwrapState arg3))


{-| Removes the search and every column filter, and goes back to page 1. Filters
that live outside the table (see `rowFilter`) are yours to clear.
-}
clearFilters : State id -> State id
clearFilters arg1 =
    fromCoreState (Core.clearFilters (unwrapState arg1))


{-| The row density: `Compact`, `Normal` (the default) or `Comfortable`, from
[Klar.Theme](Klar-Theme). The user changes it with the buttons of `densityToggle`.
A table whose density was not set (or is `Normal`) follows the density of the
application (`Klar.Settings`); a `Compact` or `Comfortable` table keeps its own.
-}
density : State id -> Density
density arg1 =
    Core.density (unwrapState arg1)


{-| Sets the row density, for example from a saved preference. It works whether
or not `densityToggle` is shown.
-}
setDensity : Density -> State id -> State id
setDensity arg1 arg2 =
    fromCoreState (Core.setDensity arg1 (unwrapState arg2))


{-| What is selected, as a `Selection`. In client mode `selectedIds` is enough; in
server mode check this one for `AllMatching`.
-}
selection : Ids id -> State id -> Selection id
selection arg1 arg2 =
    fromCoreSelection (Core.selection arg1 (unwrapState arg2))


{-| The ids (see `rowId`) of the selected rows. After "Select all N matching" in
server mode this is empty: check `selection` for `AllMatching`.
-}
selectedIds : Ids id -> State id -> List id
selectedIds arg1 arg2 =
    Core.selectedIds arg1 (unwrapState arg2)


{-| How many rows are selected. Pass the number of rows that match the current
query (the `total` you give to `server`). It is only used after "Select all N
matching", where the count is that number minus the exceptions, so in client
mode any number will do.
-}
selectedCount : Int -> State id -> Int
selectedCount arg1 arg2 =
    Core.selectedCount arg1 (unwrapState arg2)


{-| Is the row with this id selected? After "Select all N matching" every id
counts as selected except the exceptions.
-}
isSelected : Ids id -> id -> State id -> Bool
isSelected arg1 arg2 arg3 =
    Core.isSelected arg1 arg2 (unwrapState arg3)


{-| Selects the rows with these ids, as their checkboxes do, and keeps the rest of
the selection. After "Select all N matching" it takes them out of the exceptions.

    Table.select orderIds failedIds model.table

-}
select : Ids id -> List id -> State id -> State id
select arg1 arg2 arg3 =
    fromCoreState (Core.select arg1 arg2 (unwrapState arg3))


{-| Deselects the rows with these ids and keeps the rest of the selection, for
example the rows a bulk action has done its work on. After "Select all N
matching" it adds them to the exceptions.
-}
deselect : Ids id -> List id -> State id -> State id
deselect arg1 arg2 arg3 =
    fromCoreState (Core.deselect arg1 arg2 (unwrapState arg3))


{-| Makes the selection exactly these rows, as a whole: to restore a selection, or
to keep only the rows that are still there. It also ends an "all matching"
selection. To deselect everything use `clearSelection`.
-}
setSelectedIds : Ids id -> List id -> State id -> State id
setSelectedIds arg1 arg2 arg3 =
    fromCoreState (Core.setSelectedIds arg1 arg2 (unwrapState arg3))


{-| Deselects everything, including an "all matching" selection. Call it when a
bulk action has done its work.
-}
clearSelection : State id -> State id
clearSelection arg1 =
    fromCoreState (Core.clearSelection (unwrapState arg1))


{-| Drops an "all matching" selection (see `Selection`) and keeps the rows that were
picked one by one. The table does it by itself when its own search or filters change; call
it when something else changes what "all matching" means, such as a filter bar next to
the table.
-}
dropAllMatching : State id -> State id
dropAllMatching arg1 =
    fromCoreState (Core.dropAllMatching (unwrapState arg1))


{-| Moves keyboard focus to the table (its scroll area; Tab goes on to the
header from there). Use it when whatever had focus is gone: a bulk action that
removed the selected rows takes the bulk bar and its buttons with it, and focus
would fall back to the page.

    DeleteSelected ->
        ( { model
            | orders = withoutOrders (Table.selectedIds orderIds model.table) model.orders
            , table = Table.clearSelection model.table
          }
        , Cmd.map TableMsg (Table.focus model.table)
        )

-}
focus : State id -> Cmd Msg
focus arg1 =
    Cmd.map fromCoreMsg (Core.focus (unwrapState arg1))


{-| The ids (see `rowId`) of the rows that are expanded. Rows only expand when you
give the table an `expandedRow`.
-}
expandedIds : Ids id -> State id -> List id
expandedIds arg1 arg2 =
    Core.expandedIds arg1 (unwrapState arg2)


{-| Is the row with this id expanded?
-}
isExpanded : Ids id -> id -> State id -> Bool
isExpanded arg1 arg2 arg3 =
    Core.isExpanded arg1 arg2 (unwrapState arg3)


{-| Expands the row with this id, for example to open the first row when the table
appears.

    Table.expand orderIds firstOrder.id model.table

-}
expand : Ids id -> id -> State id -> State id
expand arg1 arg2 arg3 =
    fromCoreState (Core.expand arg1 arg2 (unwrapState arg3))


{-| Collapses the row with this id.
-}
collapse : Ids id -> id -> State id -> State id
collapse arg1 arg2 arg3 =
    fromCoreState (Core.collapse arg1 arg2 (unwrapState arg3))


{-| Toggles the details of a row (`expandedRow`), not its selection: expands the
row with this id when it is collapsed, and collapses it when it is expanded, as its
arrow button does. To toggle a selection use `select` and `deselect`.
-}
toggle : Ids id -> id -> State id -> State id
toggle arg1 arg2 arg3 =
    fromCoreState (Core.toggle arg1 arg2 (unwrapState arg3))


{-| Makes these rows, and no others, the expanded ones: to restore the rows that
were open, or to expand every row (`setExpandedIds orderIds (List.map .id orders)`).
To collapse every row use `collapseAll`.
-}
setExpandedIds : Ids id -> List id -> State id -> State id
setExpandedIds arg1 arg2 arg3 =
    fromCoreState (Core.setExpandedIds arg1 arg2 (unwrapState arg3))


{-| Collapses every row.
-}
collapseAll : State id -> State id
collapseAll arg1 =
    fromCoreState (Core.collapseAll (unwrapState arg1))


{-| Whether the user chose to show (`Just True`) or hide (`Just False`) the
column with this id. `Nothing` means no choice yet: the column follows its
default, shown unless it is `hiddenByDefault`. With `setColumnVisible` this lets
you remember the user's column choices.
-}
isColumnVisible : ColumnId -> State id -> Maybe Bool
isColumnVisible arg1 arg2 =
    Core.isColumnVisible (unwrapColumnId arg1) (unwrapState arg2)


{-| Records that the column with this id is shown (`True`) or hidden (`False`),
as if the user had ticked it in the column chooser. Columns that are
`alwaysVisible` ignore it, and the table always keeps at least one column on
screen.
-}
setColumnVisible : ColumnId -> Bool -> State id -> State id
setColumnVisible arg1 arg2 arg3 =
    fromCoreState (Core.setColumnVisible (unwrapColumnId arg1) arg2 (unwrapState arg3))


{-| A message from the table's own controls: sorting, paging, typing in a filter,
opening a popup and so on. You never make one. Give `view` a constructor of your
own that wraps it (`TableMsg`), and hand the `m` in `TableMsg m` to `update`.
-}
type Msg
    = NoOp
    | SortClicked String Bool
    | PageChanged Int
    | PageSizeChanged Int
    | SearchChanged String Int
    | FilterTextChanged String String Int
    | FilterRangeChanged String Bool String Int
    | FilterChoiceToggled String String Bool
    | FilterChoicesSet String (List String)
    | OptionQueryChanged String
    | FilterCleared String
    | FiltersCleared
    | AllCleared
    | Debounced Int
    | PopupOpened Types.Popup (List String)
    | PopupClosed
    | PopupLeft
    | RowMenu String String (List String) Menu.Msg
    | RowMenuOpened String String (List String)
    | RowSelected String Bool
    | RowsSelected (List String) Bool
    | RangeSelected (List String) Bool String
    | MatchingSelected (List String)
    | AllMatchingPicked
    | SelectionCleared String
    | ExpandToggled String
    | DensityChanged Density
    | ColumnToggled String Bool
    | ColumnsReset
    | RowFocused Int
    | FocusRow Int String
    | FocusVirtualRow Int String Window.Geometry
    | Scrolled Float
    | RetryClicked
    | FirstPageClicked
    | ExportClicked String String


{-| Applies a message from the table to its state. The `Cmd` moves keyboard
focus (into a popup, back to its button), runs the timer behind the search
debounce and saves the file of the CSV export, so map it back with your own
constructor: `Cmd.map TableMsg cmd`.
-}
update : Msg -> State id -> ( State id, Cmd Msg )
update arg1 arg2 =
    Tuple.mapBoth fromCoreState (Cmd.map fromCoreMsg) (Core.update (unwrapMsg arg1) (unwrapState arg2))


{-| One column of the table. Make it with `text`, `int`, `float`, `date`,
`maybeDate`, `badge`, `status`, `bool`, `custom` or `actions`, and give a list of
them to `columns`.
-}
type Column row msg
    = Column (Types.ColumnConfig row msg)


{-| A setting of one column. Make them with the functions below and pass a list
as the last argument of `text`, `int` and the other column helpers; later
attributes win over earlier ones.
-}
type ColumnAttribute row msg
    = ColumnAttribute (Types.ColumnConfig row msg -> Types.ColumnConfig row msg)


{-| A text column: `Table.text (Table.columnId "customer") "Customer" .customer []` takes the
column id (unique in the table), the title for the header and a function that
reads the text from a row.

The text is searched, sorted alphabetically (in the order of the table's
`locale`), exported to CSV and highlighted where it matches the search. A long
text is cut with an ellipsis and a tooltip, a blank one is shown as a dash and
sorts last, and the column is at least 120 pixels wide (see `minWidth`).

-}
text : ColumnId -> String -> (row -> String) -> List (ColumnAttribute row msg) -> Column row msg
text arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.text (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A whole number: `Table.int (Table.columnId "items") "Items" .items []`. It is right-aligned
with tabular digits and thousands separators (`1,234` in English), sorted
numerically, exported as a plain number and 104 pixels wide (see `width`). It
supports `filterRange`, `footerSum` and `footerAverage`, and the search box
skips it unless you add `includeInSearch`.
-}
int : ColumnId -> String -> (row -> Int) -> List (ColumnAttribute row msg) -> Column row msg
int arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.int (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A decimal number with a fixed count of decimals:
`Table.float (Table.columnId "weight") "Weight (kg)" 1 .weight []`. The `Int` is the number of
decimals shown (also in filter hints and footers). It is like `int` otherwise,
but 112 pixels wide, and the CSV export keeps the decimals with the locale's
decimal separator and no thousands separator, so a spreadsheet reads a number.
-}
float : ColumnId -> String -> Int -> (row -> Float) -> List (ColumnAttribute row msg) -> Column row msg
float arg1 arg2 arg3 arg4 arg5 =
    fromCoreColumn (Core.float (unwrapColumnId arg1) arg2 arg3 arg4 (List.map unwrapColumnAttribute arg5))


{-| An amount of money ([Klar.Money](Klar-Money)), exact to the minor unit:
`Table.money (Table.columnId "total") "Total" .total []`. It is shown with its
currency code in the format of the table's locale (`NOK 1,234.50` in English,
`1 234,50 NOK` in Norwegian), right-aligned with tabular digits and 136 pixels wide.

It sorts by amount, `filterRange` filters by the amount in whole units of the
currency (100 is 100 kroner), and the CSV export writes the plain amount with the
locale's decimal separator (`1234.50`, `1234,50`). Sorting and the range filter
compare the amounts without their currency, so they are meant for a column of one
currency: in a column of several, 100 EUR and 100 NOK sort as equal. `footerSum`
and `footerAverage` add the amounts exactly, as `Money` and not as `Float`, with one
total for each currency in the order of their codes when the column holds several
(`EUR 300.00 · NOK 1,250.00`); prepared rows (`remotePrepared`) work them out once.
The search box skips it unless you add `includeInSearch`. Use it instead of `float`
for every amount of money.

-}
money : ColumnId -> String -> (row -> Money) -> List (ColumnAttribute row msg) -> Column row msg
money arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.money (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A calendar date ([Klar.Date](Klar-Date)), sorted by date and shown as
`2026-10-20` in English or `20.10.2026` in Norwegian. For a date that may be
missing use `maybeDate`.

    Table.date (Table.columnId "shipped") "Shipped" .shippedOn []

-}
date : ColumnId -> String -> (row -> Date) -> List (ColumnAttribute row msg) -> Column row msg
date arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.date (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| Like `date`, for a date that may be missing: `Nothing` is shown as a dash
and sorts last, whichever way the column is sorted.
-}
maybeDate : ColumnId -> String -> (row -> Maybe Date) -> List (ColumnAttribute row msg) -> Column row msg
maybeDate arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.maybeDate (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A tone ([Klar.Theme](Klar-Theme)) and a label, shown as a
[Klar.Badge](Klar-Badge). The label is the text used for search, sorting, export
and `filterSelect`; the column is 124 pixels wide.

    Table.badge (Table.columnId "status")
        "Status"
        (\order -> ( statusTone order.status, statusLabel order.status ))
        [ Table.filterSelect ]

-}
badge : ColumnId -> String -> (row -> ( Tone, String )) -> List (ColumnAttribute row msg) -> Column row msg
badge arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.badge (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| Like `badge`, but drawn as a colored dot and text (`Badge.status` in
[Klar.Badge](Klar-Badge)), which is quieter in dense tables.
-}
status : ColumnId -> String -> (row -> ( Tone, String )) -> List (ColumnAttribute row msg) -> Column row msg
status arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.status (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A yes / no column: a check mark for yes and a dash for no. The words ("Yes"
and "No" in English) are what screen readers hear and what search, sorting,
export and `filterSelect` use.

When the user picks values in the `filterSelect` of this column, the table
stores them as the words `"true"` and `"false"` whatever the locale, so that a
saved filter still matches when the language changes, and so that a backend can
read a server-mode `Query` without knowing the language. A `Filter` you read from
`filters` or `query` therefore holds those words, while `setFilter` also accepts
the words of either language ("Yes", "Ja").

-}
bool : ColumnId -> String -> (row -> Bool) -> List (ColumnAttribute row msg) -> Column row msg
bool arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.bool (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A column with your own HTML and no text: `render` draws the cell. Without
text the column is not searched, sorted or exported; turn sorting back on with
`sortText`, `sortNumber`, `sortMaybeNumber`, `sortDate` or `sortWith`, and export
with `exportAs`. For a custom look with a text behind it, use `text` with `cell`
instead.

    Table.custom (Table.columnId "progress") "Progress" viewProgress [ Table.sortNumber .progress ]

-}
custom : ColumnId -> String -> (row -> Html msg) -> List (ColumnAttribute row msg) -> Column row msg
custom arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.custom (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| Inline controls for each row, such as small icon buttons or links: `render`
returns the elements of one cell. Clicks inside never trigger `onRowClick`, and
the title is only read by screen readers. For a "more" menu use `rowActions`
instead: its button is one tab stop for the whole table, while controls you draw
here are a tab stop in every row (keep them few).

    Table.actions (Table.columnId "open")
        "Open"
        (\order ->
            [ Button.iconOnly
                [ Button.ghost, Button.small, Button.onClick (OpenOrder order.id) ]
                Icon.externalLink
                "Open order"
            ]
        )
        []

-}
actions : ColumnId -> String -> (row -> List (Html msg)) -> List (ColumnAttribute row msg) -> Column row msg
actions arg1 arg2 arg3 arg4 =
    fromCoreColumn (Core.actions (unwrapColumnId arg1) arg2 arg3 (List.map unwrapColumnAttribute arg4))


{-| A fixed width in pixels (at least 24). Columns without a width share the
space that is left. A fixed column is never narrower than its header needs, so
the title is not cut.
-}
width : Int -> ColumnAttribute row msg
width arg1 =
    fromCoreColumnAttribute (Core.width arg1)


{-| The column shares the remaining space but never gets narrower than this many
pixels (at least 24); the table scrolls sideways instead. The default is 120.
It also replaces a fixed width, such as the one `int`, `date` and `badge`
columns start with.
-}
minWidth : Int -> ColumnAttribute row msg
minWidth arg1 =
    fromCoreColumnAttribute (Core.minWidth arg1)


{-| Aligns the header and the cells of the column to the right, as numbers
should be. Columns start left-aligned, except `int`, `float` and `actions`,
which are right-aligned.
-}
alignRight : ColumnAttribute row msg
alignRight =
    fromCoreColumnAttribute Core.alignRight


{-| Centers the header and the cells of the column. A `bool` column starts
centered.
-}
alignCenter : ColumnAttribute row msg
alignCenter =
    fromCoreColumnAttribute Core.alignCenter


{-| Keeps the column in view while the table scrolls sideways. Only the first
visible column can be pinned (on any other column this does nothing); the
selection and expand columns, if there are any, stay with it.
-}
pinned : ColumnAttribute row msg
pinned =
    fromCoreColumnAttribute Core.pinned


{-| The column starts hidden. The user can show it in the column chooser (see
`columnChooser`), and you can with `setColumnVisible`.
-}
hiddenByDefault : ColumnAttribute row msg
hiddenByDefault =
    fromCoreColumnAttribute Core.hiddenByDefault


{-| The user cannot hide the column: its checkbox in the column chooser is
disabled. It also cancels `hiddenByDefault`.
-}
alwaysVisible : ColumnAttribute row msg
alwaysVisible =
    fromCoreColumnAttribute Core.alwaysVisible


{-| Long values wrap onto more lines instead of being cut, so the row grows. There
is no tooltip then, as the whole value is visible.
-}
wrap : ColumnAttribute row msg
wrap =
    fromCoreColumnAttribute Core.wrap


{-| Turns off the tooltip (the `title` attribute) that shows the full value of a
cell whose text is cut off.
-}
noTooltip : ColumnAttribute row msg
noTooltip =
    fromCoreColumnAttribute Core.noTooltip


{-| Draws the cell yourself. The text accessor of the column is still used for
search, sorting, export and filters, but a match is no longer highlighted in the
cell, and there is no tooltip.

    Table.text (Table.columnId "customer") "Customer" .customer [ Table.cell viewCustomerLink ]

-}
cell : (row -> Html msg) -> ColumnAttribute row msg
cell arg1 =
    fromCoreColumnAttribute (Core.cell arg1)


{-| A short explanation of the column, shown as a tooltip on the header. It
replaces the default tooltip ("Click to sort").
-}
hint : String -> ColumnAttribute row msg
hint arg1 =
    fromCoreColumnAttribute (Core.hint arg1)


{-| Sorts alphabetically (in the order of the table's `locale`) by another text
than the one shown.
-}
sortText : (row -> String) -> ColumnAttribute row msg
sortText arg1 =
    fromCoreColumnAttribute (Core.sortText arg1)


{-| Sorts by a number instead of the text. The number also makes `filterRange`,
`footerSum` and `footerAverage` work on a column that shows text.
-}
sortNumber : (row -> Float) -> ColumnAttribute row msg
sortNumber arg1 =
    fromCoreColumnAttribute (Core.sortNumber arg1)


{-| Like `sortNumber`, for a number that may be missing: rows with `Nothing` go
last, whichever way the column is sorted.
-}
sortMaybeNumber : (row -> Maybe Float) -> ColumnAttribute row msg
sortMaybeNumber arg1 =
    fromCoreColumnAttribute (Core.sortMaybeNumber arg1)


{-| Sorts by a date instead of the text, for example when the column shows a
date in your own format.

    Table.text (Table.columnId "due") "Due" .dueText [ Table.sortDate .dueDate ]

-}
sortDate : (row -> Date) -> ColumnAttribute row msg
sortDate arg1 =
    fromCoreColumnAttribute (Core.sortDate arg1)


{-| Sorts with your own comparison, written for the ascending order; the table
reverses it for `Descending`. Rows that compare equal keep their order.

    Table.text (Table.columnId "size") "Size" .sizeLabel [ Table.sortWith (\a b -> compare a.sizeRank b.sizeRank) ]

-}
sortWith : (row -> row -> Order) -> ColumnAttribute row msg
sortWith arg1 =
    fromCoreColumnAttribute (Core.sortWith arg1)


{-| Turns sorting off for the column: its header is a plain title instead of a
button.
-}
unsortable : ColumnAttribute row msg
unsortable =
    fromCoreColumnAttribute Core.unsortable


{-| The search box skips this column.
-}
notSearchable : ColumnAttribute row msg
notSearchable =
    fromCoreColumnAttribute Core.notSearchable


{-| The search box looks in this column. Text, date, badge, status and yes / no
columns are searched by default; number columns are not (searching "42" rarely
means an item count). Only visible columns are searched.
-}
includeInSearch : ColumnAttribute row msg
includeInSearch =
    fromCoreColumnAttribute Core.includeInSearch


{-| The value written to the CSV export, when it should differ from the text
shown. It also puts a column in the export that would be left out otherwise,
such as a `custom` column.
-}
exportAs : (row -> String) -> ColumnAttribute row msg
exportAs arg1 =
    fromCoreColumnAttribute (Core.exportAs arg1)


{-| Leaves the column out of the CSV export (see `exportCsv`).
-}
notExported : ColumnAttribute row msg
notExported =
    fromCoreColumnAttribute Core.notExported


{-| Adds a "contains" text filter to the column: a filter button in the header
opens a popover with an input. Case and accents are ignored.
-}
filterText : ColumnAttribute row msg
filterText =
    fromCoreColumnAttribute Core.filterText


{-| Adds a filter in the header where the user picks values with checkboxes. In
client mode the values are the distinct, non-blank texts of the column in all
rows, in the alphabetical order of the locale, each with the number of rows it
would add given the other filters and the search. In server mode the table only
sees one page, so without `filterOptions` it offers just the values on the
current page, with no counts. A search box appears above the values when there
are more than eight.
-}
filterSelect : ColumnAttribute row msg
filterSelect =
    fromCoreColumnAttribute Core.filterSelect


{-| The values offered by `filterSelect`, in this order, instead of the ones found
in the rows (client mode still counts the rows of each), each with the label the
user sees. The `value` is what the filter keeps and what a `Query` carries: the
column's `filterValue` of the rows it should match, or the column's text when the
column has none. A chosen value that is not in the list stays in it. It also
turns the select filter on, so `filterSelect` is not needed next to it. In server
mode, give the options: the table only sees one page.

    Table.badge (Table.columnId "status")
        "Status"
        statusBadge
        [ Table.filterValue (.status >> statusCode)
        , Table.filterOptions (List.map (\s -> { value = statusCode s, label = statusLabel s }) allStatuses)
        ]

-}
filterOptions : List { value : String, label : String } -> ColumnAttribute row msg
filterOptions arg1 =
    fromCoreColumnAttribute (Core.filterOptions arg1)


{-| The stable value that a select filter keeps for a row, instead of the text the
column shows: a code such as `"shipped"` for a row shown as "Shipped" in English
and "Sendt" in Norwegian. The filter, a saved view and the `Query` you send to a
backend then hold codes, which stay right when the language or a label changes and
tell two values with the same label apart. The filter popover still shows the
labels (the column's text, or the labels of `filterOptions`). Without it a select
filter keeps the column's text, and a yes / no column keeps `"true"` and
`"false"`.

    Table.filterValue (.status >> statusCode)

-}
filterValue : (row -> String) -> ColumnAttribute row msg
filterValue arg1 =
    fromCoreColumnAttribute (Core.filterValue arg1)


{-| Adds a from / to number filter to the column; either bound can be left
empty. It needs a number column (`int`, `float`) or `sortNumber`; on a column
without numbers there is no filter button.
-}
filterRange : ColumnAttribute row msg
filterRange =
    fromCoreColumnAttribute Core.filterRange


{-| A footer value computed from the rows: all rows that match the search and
filters in client mode, the current page in server mode. The footer row shows
when any visible column has a footer value and there are rows.

    Table.int (Table.columnId "items") "Items" .items [ Table.footer (\orders -> String.fromInt (List.length orders) ++ " orders") ]

-}
footer : (List row -> String) -> ColumnAttribute row msg
footer arg1 =
    fromCoreColumnAttribute (Core.footer arg1)


{-| The sum of a number column in the footer, as in "Sum 12,345". It adds up the
same rows as `footer`.
-}
footerSum : ColumnAttribute row msg
footerSum =
    fromCoreColumnAttribute Core.footerSum


{-| The average of a number column in the footer, as in "Avg 51.2". It is written
with the decimals of the column (one at least, so an average of whole numbers is
not rounded to a whole number): cents stay cents in a money column. It averages
the same rows as `footer`; a dash is shown when there is nothing to average.
-}
footerAverage : ColumnAttribute row msg
footerAverage =
    fromCoreColumnAttribute Core.footerAverage


{-| A setting of the table as a whole (`columns`, `remote`, `searchable` ...). Make
them with the functions below and pass a list to `view`; later attributes win
over earlier ones.
-}
type Attribute id row msg
    = Attribute (Types.Config row msg -> Types.Config row msg)


{-| The columns of the table, left to right. Make them with `text`, `int`,
`float`, `date`, `maybeDate`, `badge`, `status`, `bool`, `custom` and `actions`.
Column ids must be unique and stay the same: sort, filters, hidden columns and
the `Query` refer to them.
-}
columns : List (Column row msg) -> Attribute id row msg
columns arg1 =
    fromCoreAttribute (Core.columns (List.map unwrapColumn arg1))


{-| The rows, as [Klar.Remote](Klar-Remote) data. `Loading` (and `NotAsked`)
shows skeleton rows under the header, `Failed` shows the error with a retry
button (see `onRetry`), and `Loaded []` shows the empty state (see
`emptyState`). In server mode these are the rows of the current page only.
Without `remote` the table shows the loading skeleton.

Rows that are `Kept` stay on the screen. While they are refreshed (the next page
in server mode, a refresh button: `Remote.refresh`) they are dimmed, with a
progress line under the header, and screen readers hear "Refreshing ...". When the
last refresh failed they carry the marker "Old data from 14:05" with a retry
button (`onRetry`).

    Table.remote model.orders

-}
remote : Remote (List row) -> Attribute id row msg
remote arg1 =
    fromCoreAttribute (Core.remote arg1)


{-| The rows of a client-mode table that has thousands of them, as `Rows` made
once with `prepareRows` (see "Many rows" at the top), instead of `remote`. It
does what `remote` does, and the search and a sort by one column no longer format
every value again on each message.

    Table.remotePrepared model.orders -- Remote (Table.Rows Order)

-}
remotePrepared : Remote (Rows row) -> Attribute id row msg
remotePrepared arg1 =
    fromCoreAttribute (Core.remotePrepared (Remote.map unwrapRows arg1))


{-| Rows that the table has worked on in advance: for each row the text the search
looks in, and for each sortable column the rows in order. Make them once, when the
rows arrive or change, and keep them in your model instead of the `Array`; give
them to the table with `remotePrepared`.

    Loaded orders ->
        { model | orders = Loaded (Table.prepareRows locale columns (Array.fromList orders)) }

They are made for one locale and one list of columns. A table that is given other
columns or another locale shows the right rows all the same, but works them out
again on every message, as `remote` does.

-}
type Rows row
    = Rows
        { array : Array row
        , locale : Locale
        , columnIds : List String
        , searchIds : List String
        , index : Index

        -- the exact totals of the money columns with a footer, over every row
        , moneyTotals : Dict String (List Types.MoneyTotal)
        }


{-| Prepares the rows for a table with these columns in this locale (the `Locale`
you give to `locale`). Take the same columns you give to `columns`. Every sortable
column is sorted once here, so this takes about as long as sorting by each column
would, a few hundred milliseconds for 50 000 rows. A table given the result reads
a sort by one column from it and does not sort again; a sort by several columns
(`multiSort`) and a `sortWith` column are still sorted on every message.
-}
prepareRows : Locale -> List (Column row msg) -> Array row -> Rows row
prepareRows arg1 arg2 arg3 =
    fromCoreRows (Core.prepareRows arg1 (List.map unwrapColumn arg2) arg3)


{-| The rows of prepared rows, to give to other parts of the page that want an
`Array` too, such as [Klar.VirtualList](Klar-VirtualList). It costs nothing.
-}
rowsArray : Rows row -> Array row
rowsArray arg1 =
    Core.rowsArray (unwrapRows arg1)


{-| A stable, unique id for each row, such as a database id. Selection, expanded
rows and keyed rendering depend on it; without it rows are identified by their
position in the current (filtered and sorted) result, so a selection or an open
row does not follow its row when the order changes, and `selectable` needs it.

The first argument says how your id type is written as a key and read back
(a [Klar.Ids](Klar-Ids)); the `State` of the table then speaks your id type:

    Table.rowId orderIds .id

-}
rowId : Ids id -> (row -> id) -> Attribute id row msg
rowId arg1 arg2 =
    fromCoreAttribute (Core.rowId arg1 arg2)


{-| How screen readers name a row, for example in the label of its checkbox
("Select Ada Lovelace"), its expand button and its actions menu. The default is
the text of the first visible column.
-}
rowLabel : (row -> String) -> Attribute id row msg
rowLabel arg1 =
    fromCoreAttribute (Core.rowLabel arg1)


{-| Switches to server mode: `remote` is the current page and `total` the number
of rows that match the query. The table does not search, filter, sort or slice
the rows itself; it shows the pagination for `total` and records what the user
asks for, which you read with `query`. Without this attribute the table is in
client mode.
-}
server : { total : Int } -> Attribute id row msg
server arg1 =
    fromCoreAttribute (Core.server arg1)


{-| The name of the table that screen readers hear, such as "Orders" (it is not
shown: a visible title is a heading of your own above the table). It also makes
the scrolling area a labelled region and names the page controls in the footer
("Pages of Orders"), so that two tables on a page can be told apart. Give every
table one.
-}
ariaLabel : String -> Attribute id row msg
ariaLabel arg1 =
    fromCoreAttribute (Core.ariaLabel arg1)


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Table.settings model.settings

-}
settings : Settings -> Attribute id row msg
settings arg1 =
    fromCoreAttribute (Core.settings arg1)


{-| The language of the built-in text, and the conventions that go with it:
number and date formats, the alphabetical order of text columns and the default
CSV separator. The default is `Locale.default`, which is English; see
[Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute id row msg
locale arg1 =
    fromCoreAttribute (Core.locale arg1)


{-| Adds a search box to the toolbar. Every word the user types must be found in
one of the visible, searchable columns (case and accents are ignored), and the
match is highlighted. Escape clears the box and is used up (its default is
prevented, so a dialog that closes only on an Escape nothing inside took stays
open); an Escape in the empty box is left to the dialog. In server mode the table
only records the text (see `query`).
-}
searchable : Attribute id row msg
searchable =
    fromCoreAttribute Core.searchable


{-| The placeholder of the search box. It also turns the search box on. The
default tells how many rows can be searched, as in "Search 120 rows ...", and is
just "Search ..." in server mode.
-}
searchPlaceholder : String -> Attribute id row msg
searchPlaceholder arg1 =
    fromCoreAttribute (Core.searchPlaceholder arg1)


{-| Milliseconds to wait after typing before what was typed in the search box,
the text filters and the number range filters takes effect (checkbox filters
always apply at once). The default is 0 in client mode and 350 in server mode,
so that a server is not asked on every key press.
-}
searchDebounce : Int -> Attribute id row msg
searchDebounce arg1 =
    fromCoreAttribute (Core.searchDebounce arg1)


{-| Client mode: an extra filter from outside the table, such as a
[Klar.FilterBar](Klar-FilterBar) or a [Klar.RuleBuilder](Klar-RuleBuilder). Rows
for which it returns `False` are left out, on top of the table's own search and
filters. Tell the table how many outside filters are active with
`activeExternalFilters`; server mode ignores this one, as your backend filters.
-}
rowFilter : (row -> Bool) -> Attribute id row msg
rowFilter arg1 =
    fromCoreAttribute (Core.rowFilter arg1)


{-| How many filters outside the table are active (the ones behind `rowFilter`,
or the ones you send to your backend). The table uses the number to tell "no
matches" (a filter hides the rows) from "no data". It draws nothing for them: the
"N filters active" button counts the column filters of the table only, because
outside filters have a display of their own (the chips of a
[FilterBar](Klar-FilterBar)), and a second summary of the same filters only repeats
it. Wire `onResetFilters` once, to clear both.
-}
activeExternalFilters : Int -> Attribute id row msg
activeExternalFilters arg1 =
    fromCoreAttribute (Core.activeExternalFilters arg1)


{-| The message to send when the user clicks one of the table's reset buttons: the
cross and "Reset filters" in the filter summary, which clear the column filters
and keep the search text, and "Clear search and filters" in the "No matches"
state, which clears both. When your message arrives the table has cleared its own
filters (and maybe the search), so clear your outside filters too (see
`rowFilter`) and fetch or filter again.
-}
onResetFilters : msg -> Attribute id row msg
onResetFilters arg1 =
    fromCoreAttribute (Core.onResetFilters arg1)


{-| Adds a checkbox column, a "select all on this page" checkbox in the header,
and a bar that covers the toolbar while something is selected (see
`bulkActions`). Needs `rowId`: without it there are no checkboxes at all, because a
selection kept by position would point at other rows after a sort. Space selects the focused row, and rows that are
`rowDisabled` cannot be selected. Shift and a click on a checkbox, or Shift+Space,
give the rows from the one picked last to this one the state this one gets (as in a
mail client), and Ctrl+A (Cmd+A) on a row selects every row of the page (of all
matching rows in a `virtual` client table). When a whole page is selected and more
rows match, the bar offers "Select all N matching". Screen readers hear the number
of selected rows when it changes.
-}
selectable : Attribute id row msg
selectable =
    fromCoreAttribute Core.selectable


{-| Buttons for the bar that covers the toolbar while rows are selected, next to
the count, the export menu and a Cancel button that clears the selection. Your
buttons send plain messages: read `selection` in your update, which is
`AllMatching { except }` after "Select all N matching" in server mode (then
`selectedIds` is `[]`). Use small buttons; it also turns on `selectable`, and like
it needs `rowId`: without it the table draws no checkboxes and no bar.

    Table.bulkActions [ Button.view [ Button.small, Button.onClick DeleteSelected ] "Delete" ]

-}
bulkActions : List (Html msg) -> Attribute id row msg
bulkActions arg1 =
    fromCoreAttribute (Core.bulkActions arg1)


{-| A "more" menu at the end of every row, made of [Klar.Menu](Klar-Menu) items.
Return `[]` for rows without actions. The menu buttons are one tab stop for the
whole table (the arrow keys move between rows), and Shift+F10 or the menu key
on a row opens its menu. On a `rowDisabled` row the button is disabled and no
key opens the menu.

    Table.rowActions
        (\order ->
            [ Menu.item "Open" (OpenOrder order.id)
            , Menu.item "Cancel order" (CancelOrder order.id) |> Menu.danger
            ]
        )

-}
rowActions : (row -> List (Menu.Item msg)) -> Attribute id row msg
rowActions arg1 =
    fromCoreAttribute (Core.rowActions arg1)


{-| The message to send for a row, when the user clicks it (outside its own
controls) or presses Enter on it. The function gets the row. A row that is
`rowDisabled` does not send it.

A row that opens a [Klar.Drawer](Klar-Drawer) or a dialog opens it with
`Drawer.open ""`: the row has the focus (a click and Enter both give it), and the
drawer gives it back to the row when it closes. Mark the row whose details are
open with `currentRow`.

    Table.onRowClick (\order -> OpenOrder order.id)

-}
onRowClick : (row -> msg) -> Attribute id row msg
onRowClick arg1 =
    fromCoreAttribute (Core.onRowClick arg1)


{-| Marks the row whose details are shown elsewhere, such as the order open in a
drawer next to the table: it gets a bar at its start and a darker background, and
screen readers hear it as the current row (`aria-current`). Return `True` for at
most one row; without this attribute no row is marked.

    Table.currentRow (\order -> Just order.id == model.openOrder)

-}
currentRow : (row -> Bool) -> Attribute id row msg
currentRow arg1 =
    fromCoreAttribute (Core.currentRow arg1)


{-| Lets rows expand to show more under them: adds an arrow button at the start
of each row and draws `render row` in a full-width cell below an open row.
ArrowRight and ArrowLeft expand and collapse the focused row, and without
`onRowClick` a click on the row toggles it too; a `rowDisabled` row does none of
this. Which rows are open is part of the state (see `expandedIds` and
`expand`). Needs `rowId`: without it no row expands.
-}
expandedRow : (row -> Html msg) -> Attribute id row msg
expandedRow arg1 =
    fromCoreAttribute (Core.expandedRow arg1)


{-| A colored accent at the start of some rows: return a `Tone` (from
[Klar.Theme](Klar-Theme)) for the rows that need one and `Nothing` for the rest.
-}
rowTone : (row -> Maybe Tone) -> Attribute id row msg
rowTone arg1 =
    fromCoreAttribute (Core.rowTone arg1)


{-| Rows that are shown but cannot be operated. A disabled row is dimmed and
marked `aria-disabled`; its checkbox, expand button and actions button are
disabled, so Tab skips them, and it is left out of "select all". A click, Enter,
Space, ArrowRight, ArrowLeft, Shift+F10 or the menu key on the row does nothing,
but the keys that move between rows (ArrowUp, ArrowDown, PageUp, PageDown, Home,
End) still reach it, so that its text can be read. Selection and expansion that a
row already has stay until you change them with `deselect` or `collapse`,
and controls you draw yourself (`actions`, `cell`, `custom`) are yours to
disable.
-}
rowDisabled : (row -> Bool) -> Attribute id row msg
rowDisabled arg1 =
    fromCoreAttribute (Core.rowDisabled arg1)


{-| Your own buttons at the right end of the toolbar, next to the table's own
tools.
-}
toolbarActions : List (Html msg) -> Attribute id row msg
toolbarActions arg1 =
    fromCoreAttribute (Core.toolbarActions arg1)


{-| Adds a refresh button to the toolbar that sends this message. The button
shows a spinner while the rows are refreshing (`Remote.refresh`) or loading.
-}
onRefresh : msg -> Attribute id row msg
onRefresh arg1 =
    fromCoreAttribute (Core.onRefresh arg1)


{-| The message to send when the user clicks "Try again" in the error state, which
shows when `remote` is a `Failed`. Without it there is no button, and the button
only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar-Remote)). Keyboard focus stays in the table while the new rows
load.
-}
onRetry : msg -> Attribute id row msg
onRetry arg1 =
    fromCoreAttribute (Core.onRetry arg1)


{-| Adds an "Export" menu to the toolbar (and to the bar that shows while rows are
selected) that downloads the visible columns as a CSV file. The `String` is the
file name, used as given (`"orders.csv"`).

The menu offers all matching rows (client mode), the selected rows and the
current page, the last two with a suffix in the file name (`orders-selected.csv`,
`orders-page-2.csv`). In server mode only the current page is known (all of it,
also in a `virtual` table that draws part of it), so the selected rows are
offered only while every selected row is on the page; when some are selected on
other pages the menu says how many and offers the page only. Build that file from
your backend (read `selection`, which can be `AllMatching`). Hidden columns and
`notExported` columns are left out, and so are `custom` and `actions` columns
unless they have `exportAs`. Text that a spreadsheet could run as a formula is
made safe. See `csvSeparator` for the field separator.

The file is written when the user picks a choice, not while the menu is drawn, and
`update` saves it with `File.Download.string` (a UTF-8 file with a byte order mark,
so that Excel reads æ, ø and å). There is no size limit, so 50 000 rows are one
file: map the `Cmd` of `update` back, as always.

-}
exportCsv : String -> Attribute id row msg
exportCsv arg1 =
    fromCoreAttribute (Core.exportCsv arg1)


{-| The field separator of the CSV export. The default is a comma in English and
a semicolon in Norwegian, where spreadsheets use the comma as the decimal
separator.
-}
csvSeparator : Char -> Attribute id row msg
csvSeparator arg1 =
    fromCoreAttribute (Core.csvSeparator arg1)


{-| Adds a "Columns" button to the toolbar that opens a list of checkboxes to
hide and show columns, with Reset and Done buttons. Columns that are
`alwaysVisible`, and the last visible column, cannot be hidden. The choices are
part of the state (see `isColumnVisible` and `setColumnVisible`).
-}
columnChooser : Attribute id row msg
columnChooser =
    fromCoreAttribute Core.columnChooser


{-| Adds three buttons to the toolbar to choose the row height: compact, normal
or comfortable. The choice is part of the state (see `density` and
`setDensity`).
-}
densityToggle : Attribute id row msg
densityToggle =
    fromCoreAttribute Core.densityToggle


{-| The choices of the "Rows per page" selector in the footer. The default is
`[ 10, 25, 50, 100 ]`. The page size itself is part of the state (25 from
`init`; see `pageSize` and `setPageSize`).
-}
pageSizes : List Int -> Attribute id row msg
pageSizes arg1 =
    fromCoreAttribute (Core.pageSizes arg1)


{-| Words the range in the footer yourself ("1–25 of 200" is the default): the first
and last row shown and the number of matching rows in, the text out. Format the
numbers with [Klar.Format](Klar-Format). It is also the range of a `virtual` table
("1 to 24 of 50,000"); the announcement for screen readers keeps its own words.
Works the same in `ServerList.viewTable`.

    Table.rangeText
        (\first last total ->
            Format.int locale first ++ " to " ++ Format.int locale last ++ " of " ++ Format.int locale total
        )

-}
rangeText : (Int -> Int -> Int -> String) -> Attribute id row msg
rangeText arg1 =
    fromCoreAttribute (Core.rangeText arg1)


{-| All rows on one page and no pagination footer. Every matching row is turned
into HTML, so keep it for short tables.
-}
unpaged : Attribute id row msg
unpaged =
    fromCoreAttribute Core.unpaged


{-| Shows the rows in one long list that scrolls, instead of in pages, and draws
only the rows that are in view. Use it for tables with thousands of rows that people
read by scrolling; a table that people page through, or whose rows differ in
height, is better with pages (see "Paging or scrolling" at the top).

All rows are one height, the one of the table's `density`. A row that is `wrap`ped
or `expandedRow`s do not make it taller: the cell is cut with an ellipsis, and the
details are not available. The table is as high as `maxHeight` (480 pixels without
it) and the header and the totals row stay in view. The keyboard works as in a
paged table, and PageUp and PageDown move by a screenful. In server mode the
pagination stays, and `virtual` only draws the rows of the current page that are
in view, so a page can be a few hundred rows.

-}
virtual : Attribute id row msg
virtual =
    fromCoreAttribute Core.virtual


{-| Lets the user sort by several columns: Shift-clicking a header adds that
column as the next sort level (or cycles its direction in place), and the
headers show the order as small numbers. A plain click sorts by that column
only; without `multiSort`, Shift changes nothing.
-}
multiSort : Attribute id row msg
multiSort =
    fromCoreAttribute Core.multiSort


{-| Gives every second row a light gray background.
-}
zebra : Attribute id row msg
zebra =
    fromCoreAttribute Core.zebra


{-| The rows scroll inside this height in pixels, under a header that stays in
view. Without it the table is as tall as its rows.
-}
maxHeight : Int -> Attribute id row msg
maxHeight arg1 =
    fromCoreAttribute (Core.maxHeight arg1)


{-| The table fills the height of its parent, which must have a height of its
own, and the rows scroll inside under the header. For the rest of the page under
a heading, put the table in a `Layout.stack [ Layout.fillRest ]` (inside an
`AppShell` that is the height of the window under the top bar).
-}
fillHeight : Attribute id row msg
fillHeight =
    fromCoreAttribute Core.fillHeight


{-| Changes the empty state shown when there are no rows at all (titled "No data"
by default). The "No matches" state for a search or filter that hides every row
is built in and not affected; its "Clear search and filters" button clears the
search and the column filters, and sends your `onResetFilters` message. The
attributes are those of
[Klar.EmptyState](Klar-EmptyState), applied after the built-in ones, so yours
win.

    Table.emptyState [ EmptyState.title "No orders yet", EmptyState.actions [ addButton ] ]

-}
emptyState : List (EmptyState.Attribute msg) -> Attribute id row msg
emptyState arg1 =
    fromCoreAttribute (Core.emptyState arg1)


{-| Draws the table: toolbar, header, rows, totals row and pagination. `toMsg`
wraps the table's own messages, usually the constructor you handle in `update`.
The attributes describe the table (columns, rows, options) and are given on every
call; the `State` only holds what the user changed.

    Table.view TableMsg [ Table.columns columns, Table.remote model.orders ] model.table

-}
view : (Msg -> msg) -> List (Attribute id row msg) -> State id -> Html msg
view arg1 arg2 arg3 =
    Core.view (fromCoreMsg >> arg1) (List.map unwrapAttribute arg2) (unwrapState arg3)


unwrapState : State id -> Types.State id
unwrapState (State value) =
    Types.State value


fromCoreState : Types.State id -> State id
fromCoreState (Types.State value) =
    State value


unwrapColumnId : ColumnId -> Types.ColumnId
unwrapColumnId (ColumnId value) =
    Types.ColumnId value


fromCoreColumnId : Types.ColumnId -> ColumnId
fromCoreColumnId (Types.ColumnId value) =
    ColumnId value


unwrapAttribute : Attribute id row msg -> Types.Attribute id row msg
unwrapAttribute (Attribute value) =
    Types.Attribute value


fromCoreAttribute : Types.Attribute id row msg -> Attribute id row msg
fromCoreAttribute (Types.Attribute value) =
    Attribute value


unwrapRows : Rows row -> Types.Rows row
unwrapRows (Rows value) =
    Types.Rows value


fromCoreRows : Types.Rows row -> Rows row
fromCoreRows (Types.Rows value) =
    Rows value


unwrapColumn : Column row msg -> Types.Column row msg
unwrapColumn (Column value) =
    Types.Column value


fromCoreColumn : Types.Column row msg -> Column row msg
fromCoreColumn (Types.Column value) =
    Column value


unwrapColumnAttribute : ColumnAttribute row msg -> Types.ColumnAttribute row msg
unwrapColumnAttribute (ColumnAttribute value) =
    Types.ColumnAttribute value


fromCoreColumnAttribute : Types.ColumnAttribute row msg -> ColumnAttribute row msg
fromCoreColumnAttribute (Types.ColumnAttribute value) =
    ColumnAttribute value


toCoreDirection : Direction -> Types.Direction
toCoreDirection direction =
    case direction of
        Ascending ->
            Types.Ascending

        Descending ->
            Types.Descending


fromCoreDirection : Types.Direction -> Direction
fromCoreDirection direction =
    case direction of
        Types.Ascending ->
            Ascending

        Types.Descending ->
            Descending


toCoreFilter : Filter -> Types.Filter
toCoreFilter filter =
    case filter of
        Contains value ->
            Types.Contains value

        OneOf values ->
            Types.OneOf values

        Between low high ->
            Types.Between low high


fromCoreFilter : Types.Filter -> Filter
fromCoreFilter filter =
    case filter of
        Types.Contains value ->
            Contains value

        Types.OneOf values ->
            OneOf values

        Types.Between low high ->
            Between low high


toCoreQuery : Query -> Types.Query
toCoreQuery q =
    { search = q.search
    , sort = List.map (\( id, direction ) -> ( unwrapColumnId id, toCoreDirection direction )) q.sort
    , filters = List.map (\( id, filter ) -> ( unwrapColumnId id, toCoreFilter filter )) q.filters
    , page = q.page
    , pageSize = q.pageSize
    }


fromCoreQuery : Types.Query -> Query
fromCoreQuery q =
    { search = q.search
    , sort = List.map (\( id, direction ) -> ( fromCoreColumnId id, fromCoreDirection direction )) q.sort
    , filters = List.map (\( id, filter ) -> ( fromCoreColumnId id, fromCoreFilter filter )) q.filters
    , page = q.page
    , pageSize = q.pageSize
    }


fromCoreSelection : Types.Selection id -> Selection id
fromCoreSelection selected =
    case selected of
        Types.Selected ids ->
            Selected ids

        Types.AllMatching except ->
            AllMatching except


unwrapMsg : Msg -> Types.Msg
unwrapMsg msg =
    case msg of
        NoOp ->
            Types.NoOp

        SortClicked arg1 arg2 ->
            Types.SortClicked arg1 arg2

        PageChanged arg1 ->
            Types.PageChanged arg1

        PageSizeChanged arg1 ->
            Types.PageSizeChanged arg1

        SearchChanged arg1 arg2 ->
            Types.SearchChanged arg1 arg2

        FilterTextChanged arg1 arg2 arg3 ->
            Types.FilterTextChanged arg1 arg2 arg3

        FilterRangeChanged arg1 arg2 arg3 arg4 ->
            Types.FilterRangeChanged arg1 arg2 arg3 arg4

        FilterChoiceToggled arg1 arg2 arg3 ->
            Types.FilterChoiceToggled arg1 arg2 arg3

        FilterChoicesSet arg1 arg2 ->
            Types.FilterChoicesSet arg1 arg2

        OptionQueryChanged arg1 ->
            Types.OptionQueryChanged arg1

        FilterCleared arg1 ->
            Types.FilterCleared arg1

        FiltersCleared ->
            Types.FiltersCleared

        AllCleared ->
            Types.AllCleared

        Debounced arg1 ->
            Types.Debounced arg1

        PopupOpened arg1 arg2 ->
            Types.PopupOpened arg1 arg2

        PopupClosed ->
            Types.PopupClosed

        PopupLeft ->
            Types.PopupLeft

        RowMenu arg1 arg2 arg3 arg4 ->
            Types.RowMenu arg1 arg2 arg3 arg4

        RowMenuOpened arg1 arg2 arg3 ->
            Types.RowMenuOpened arg1 arg2 arg3

        RowSelected arg1 arg2 ->
            Types.RowSelected arg1 arg2

        RowsSelected arg1 arg2 ->
            Types.RowsSelected arg1 arg2

        RangeSelected arg1 arg2 arg3 ->
            Types.RangeSelected arg1 arg2 arg3

        MatchingSelected arg1 ->
            Types.MatchingSelected arg1

        AllMatchingPicked ->
            Types.AllMatchingPicked

        SelectionCleared arg1 ->
            Types.SelectionCleared arg1

        ExpandToggled arg1 ->
            Types.ExpandToggled arg1

        DensityChanged arg1 ->
            Types.DensityChanged arg1

        ColumnToggled arg1 arg2 ->
            Types.ColumnToggled arg1 arg2

        ColumnsReset ->
            Types.ColumnsReset

        RowFocused arg1 ->
            Types.RowFocused arg1

        FocusRow arg1 arg2 ->
            Types.FocusRow arg1 arg2

        FocusVirtualRow arg1 arg2 arg3 ->
            Types.FocusVirtualRow arg1 arg2 arg3

        Scrolled arg1 ->
            Types.Scrolled arg1

        RetryClicked ->
            Types.RetryClicked

        FirstPageClicked ->
            Types.FirstPageClicked

        ExportClicked arg1 arg2 ->
            Types.ExportClicked arg1 arg2


fromCoreMsg : Types.Msg -> Msg
fromCoreMsg msg =
    case msg of
        Types.NoOp ->
            NoOp

        Types.SortClicked arg1 arg2 ->
            SortClicked arg1 arg2

        Types.PageChanged arg1 ->
            PageChanged arg1

        Types.PageSizeChanged arg1 ->
            PageSizeChanged arg1

        Types.SearchChanged arg1 arg2 ->
            SearchChanged arg1 arg2

        Types.FilterTextChanged arg1 arg2 arg3 ->
            FilterTextChanged arg1 arg2 arg3

        Types.FilterRangeChanged arg1 arg2 arg3 arg4 ->
            FilterRangeChanged arg1 arg2 arg3 arg4

        Types.FilterChoiceToggled arg1 arg2 arg3 ->
            FilterChoiceToggled arg1 arg2 arg3

        Types.FilterChoicesSet arg1 arg2 ->
            FilterChoicesSet arg1 arg2

        Types.OptionQueryChanged arg1 ->
            OptionQueryChanged arg1

        Types.FilterCleared arg1 ->
            FilterCleared arg1

        Types.FiltersCleared ->
            FiltersCleared

        Types.AllCleared ->
            AllCleared

        Types.Debounced arg1 ->
            Debounced arg1

        Types.PopupOpened arg1 arg2 ->
            PopupOpened arg1 arg2

        Types.PopupClosed ->
            PopupClosed

        Types.PopupLeft ->
            PopupLeft

        Types.RowMenu arg1 arg2 arg3 arg4 ->
            RowMenu arg1 arg2 arg3 arg4

        Types.RowMenuOpened arg1 arg2 arg3 ->
            RowMenuOpened arg1 arg2 arg3

        Types.RowSelected arg1 arg2 ->
            RowSelected arg1 arg2

        Types.RowsSelected arg1 arg2 ->
            RowsSelected arg1 arg2

        Types.RangeSelected arg1 arg2 arg3 ->
            RangeSelected arg1 arg2 arg3

        Types.MatchingSelected arg1 ->
            MatchingSelected arg1

        Types.AllMatchingPicked ->
            AllMatchingPicked

        Types.SelectionCleared arg1 ->
            SelectionCleared arg1

        Types.ExpandToggled arg1 ->
            ExpandToggled arg1

        Types.DensityChanged arg1 ->
            DensityChanged arg1

        Types.ColumnToggled arg1 arg2 ->
            ColumnToggled arg1 arg2

        Types.ColumnsReset ->
            ColumnsReset

        Types.RowFocused arg1 ->
            RowFocused arg1

        Types.FocusRow arg1 arg2 ->
            FocusRow arg1 arg2

        Types.FocusVirtualRow arg1 arg2 arg3 ->
            FocusVirtualRow arg1 arg2 arg3

        Types.Scrolled arg1 ->
            Scrolled arg1

        Types.RetryClicked ->
            RetryClicked

        Types.FirstPageClicked ->
            FirstPageClicked

        Types.ExportClicked arg1 arg2 ->
            ExportClicked arg1 arg2
