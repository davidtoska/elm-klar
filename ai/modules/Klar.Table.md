# Klar.Table

A data table for records: search, column filters, sorting, selection with bulk actions, row actions, expandable rows, CSV export and pagination.

Import: `import Klar.Table as Table` | Group: Tables and lists

Types: `Msg`, `Rows`, `State`, `Column`, `Filter`, `RowIds`, `ColumnId`, `Attribute`, `Direction`, `Selection`, `ColumnAttribute`, `Query`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute id row msg) -> State id -> Html msg

-- State
type State id  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State id
update : Msg -> State id -> ( State id, Cmd Msg )
focus : State id -> Cmd Msg
type RowIds id  -- opaque: no constructors are exposed
rowIds : { toKey : id -> String, fromKey : String -> Maybe id } -> RowIds id
stringIds : RowIds String
intIds : RowIds Int

-- Sort, page, search and filters
type ColumnId  -- opaque: no constructors are exposed
columnId : String -> ColumnId
columnName : ColumnId -> String
type alias Query =
    { search : String
    , sort : List ( ColumnId, Direction )
    , filters : List ( ColumnId, Filter )
    , page : Int
    , pageSize : Int
    }
type Direction = Ascending | Descending
type Filter = Contains String | OneOf (List String) | Between (Maybe Float) (Maybe Float)
query : State id -> Query
setQuery : Query -> State id -> State id
sort : State id -> List ( ColumnId, Direction )
setSort : List ( ColumnId, Direction ) -> State id -> State id
page : State id -> Int
setPage : Int -> State id -> State id
pageSize : State id -> Int
setPageSize : Int -> State id -> State id
search : State id -> String
setSearch : String -> State id -> State id
filters : State id -> List ( ColumnId, Filter )
setFilter : ColumnId -> Maybe Filter -> State id -> State id
clearFilters : State id -> State id

-- Selection
type Selection id = Selected (List id) | AllMatching { except : List id }
selection : RowIds id -> State id -> Selection id
selectedIds : RowIds id -> State id -> List id
selectedCount : Int -> State id -> Int
isSelected : RowIds id -> id -> State id -> Bool
setSelected : RowIds id -> List id -> Bool -> State id -> State id
clearSelection : State id -> State id
dropAllMatching : State id -> State id

-- Expanded rows, columns and density
expandedIds : RowIds id -> State id -> List id
isExpanded : RowIds id -> id -> State id -> Bool
setExpanded : RowIds id -> id -> Bool -> State id -> State id
isColumnVisible : ColumnId -> State id -> Maybe Bool
setColumnVisible : ColumnId -> Bool -> State id -> State id
density : State id -> Theme.Density
setDensity : Theme.Density -> State id -> State id

-- Basic attributes
type Attribute id row msg  -- opaque: no constructors are exposed
columns : List (Column row msg) -> Attribute id row msg
rows : Remote.Remote (List row) -> Attribute id row msg
rowId : RowIds id -> (row -> id) -> Attribute id row msg
rowLabel : (row -> String) -> Attribute id row msg
server : { total : Int } -> Attribute id row msg
label : String -> Attribute id row msg
locale : Locale.Locale -> Attribute id row msg

-- Search, filters and sorting
searchable : Attribute id row msg
searchPlaceholder : String -> Attribute id row msg
searchDebounce : Int -> Attribute id row msg
rowFilter : (row -> Bool) -> Attribute id row msg
activeExternalFilters : Int -> Attribute id row msg
onResetFilters : msg -> Attribute id row msg
multiSort : Attribute id row msg

-- Selection and rows
selectable : Attribute id row msg
bulkActions : List (Html msg) -> Attribute id row msg
rowActions : (row -> List (Menu.Item msg)) -> Attribute id row msg
onRowClick : (row -> msg) -> Attribute id row msg
expandedRow : (row -> Html msg) -> Attribute id row msg
rowTone : (row -> Maybe Theme.Tone) -> Attribute id row msg
rowDisabled : (row -> Bool) -> Attribute id row msg

-- Loading and empty states
zone : Time.Zone -> Attribute id row msg
onRefresh : msg -> Attribute id row msg
onRetry : msg -> Attribute id row msg
emptyState : List (EmptyState.Attribute msg) -> Attribute id row msg

-- Toolbar and export
toolbarActions : List (Html msg) -> Attribute id row msg
exportCsv : String -> Attribute id row msg
csvSeparator : Char -> Attribute id row msg
columnChooser : Attribute id row msg
densityToggle : Attribute id row msg

-- Pagination and layout
pageSizes : List Int -> Attribute id row msg
unpaged : Attribute id row msg
virtual : Attribute id row msg
zebra : Attribute id row msg
maxHeight : Int -> Attribute id row msg
fillHeight : Attribute id row msg

-- Many rows
type Rows row  -- opaque: no constructors are exposed
prepareRows : Locale.Locale -> List (Column row msg) -> Array row -> Rows row
rowsArray : Rows row -> Array row
preparedRows : Remote.Remote (Rows row) -> Attribute id row msg

-- Columns
type Column row msg  -- opaque: no constructors are exposed
text : ColumnId -> String -> (row -> String) -> List (ColumnAttribute row msg) -> Column row msg
int : ColumnId -> String -> (row -> Int) -> List (ColumnAttribute row msg) -> Column row msg
float :
    ColumnId
    -> String
    -> Int
    -> (row -> Float)
    -> List (ColumnAttribute row msg)
    -> Column row msg
date : ColumnId -> String -> (row -> Date.Date) -> List (ColumnAttribute row msg) -> Column row msg
maybeDate :
    ColumnId
    -> String
    -> (row -> Maybe Date.Date)
    -> List (ColumnAttribute row msg)
    -> Column row msg
badge :
    ColumnId
    -> String
    -> (row -> ( Theme.Tone, String ))
    -> List (ColumnAttribute row msg)
    -> Column row msg
status :
    ColumnId
    -> String
    -> (row -> ( Theme.Tone, String ))
    -> List (ColumnAttribute row msg)
    -> Column row msg
bool : ColumnId -> String -> (row -> Bool) -> List (ColumnAttribute row msg) -> Column row msg
custom : ColumnId -> String -> (row -> Html msg) -> List (ColumnAttribute row msg) -> Column row msg
actions :
    ColumnId
    -> String
    -> (row -> List (Html msg))
    -> List (ColumnAttribute row msg)
    -> Column row msg

-- Column layout and content
type ColumnAttribute row msg  -- opaque: no constructors are exposed
width : Int -> ColumnAttribute row msg
minWidth : Int -> ColumnAttribute row msg
alignRight : ColumnAttribute row msg
alignCenter : ColumnAttribute row msg
pinned : ColumnAttribute row msg
hiddenByDefault : ColumnAttribute row msg
alwaysVisible : ColumnAttribute row msg
wrap : ColumnAttribute row msg
noTooltip : ColumnAttribute row msg
cell : (row -> Html msg) -> ColumnAttribute row msg
hint : String -> ColumnAttribute row msg

-- Column sorting
sortText : (row -> String) -> ColumnAttribute row msg
sortNumber : (row -> Float) -> ColumnAttribute row msg
sortMaybeNumber : (row -> Maybe Float) -> ColumnAttribute row msg
sortDate : (row -> Date.Date) -> ColumnAttribute row msg
sortWith : (row -> row -> Order) -> ColumnAttribute row msg
unsortable : ColumnAttribute row msg

-- Column search and export
notSearchable : ColumnAttribute row msg
includeInSearch : ColumnAttribute row msg
exportAs : (row -> String) -> ColumnAttribute row msg
notExported : ColumnAttribute row msg

-- Column filters
filterText : ColumnAttribute row msg
filterSelect : ColumnAttribute row msg
filterOptions : List String -> ColumnAttribute row msg
filterRange : ColumnAttribute row msg

-- Column footers
footer : (List row -> String) -> ColumnAttribute row msg
footerSum : ColumnAttribute row msg
footerAverage : ColumnAttribute row msg
```

## Documentation

A data table for records: search, column filters, sorting, selection with
bulk actions, row actions, expandable rows, CSV export and pagination.

Use when: people have to find, compare and act on many rows of the same kind: orders, customers, shipments.
Do not use when: you show a short list of things to open (as `Klar.ListItem`) or a long, plain list of equal rows (as `Klar.VirtualList`).
Quick path: `init`, `update`, `view`, `columns`, `rows`, `rowId`

See also [Klar.ListItem](Klar.ListItem.md) and
[Klar.VirtualList](Klar.VirtualList.md). The page controls in the footer are
[Klar.Pagination](Klar.Pagination.md).

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

    orderRows : Table.RowIds OrderId
    orderRows =
        Table.rowIds { toKey = OrderId.toString, fromKey = OrderId.fromString }

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
        , Table.rows model.orders
        , Table.rowId orderRows .id
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
        , Table.rows model.page -- Remote (List Order): the current page only
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

**Remote data.** `rows` takes a `Remote` ([Klar.Remote](Klar.Remote.md)). The table
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
([Klar.Locale](Klar.Locale.md)). The locale also decides number and date formats,
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
tab stops of their own controls), Enter opens the row (or its menu, when the row
does nothing else), Space selects it, ArrowRight and ArrowLeft expand and
collapse it, and Shift+F10 or the menu key opens its menu; a `rowDisabled` row
only takes part in the movement. Controls you put in an `actions` column stay tab
stops in every row. Filter popovers and menus close with Escape, and Escape in
the search box clears it. When an action removes the control that had focus (a
bulk action that deletes the selected rows takes the bulk bar with it), give the
table focus again with `focus`.

**Accessibility.** Sortable headers carry `aria-sort`, the table has
`aria-rowcount`, `aria-colcount` and, while it loads, `aria-busy`, and a polite
live region announces loading, refreshing, the range shown and the sort order.
Name the table with `label`; the page controls in its footer are named after it
too ("Pages of Orders"), so that two tables on a page can be told apart.
`rowLabel` names a row for screen readers ("Select Ada Lovelace" on its checkbox).

**Many rows.** Client mode searches, filters and sorts inside `view`: sort keys
are made once per row, a missing sort or filter costs nothing, and only the
current page is turned into HTML. That is quick for a few thousand rows and slow
for tens of thousands, because every value is turned into text again each time. So
for many rows, make the work once, when the rows arrive, and keep the result in your
model instead of the `List`:

    Loaded orders ->
        { model | orders = Loaded (Table.prepareRows locale columns (Array.fromList orders)) }

    Table.preparedRows model.orders

The table then has, for every row, the text that the search looks in and, for every
sortable column, the rows in order. A keystroke in the search box, a sort click and
a page change each take a few milliseconds with 50 000 rows, as with 500, and a
page change does not sort again. Search and sorting need no other rows than
these; `rowsArray` gives the `Array` to the other parts of the page that want the
rows, such as [Klar.VirtualList](Klar.VirtualList.md), so that the page keeps one
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

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute id row msg) -> State id -> Html msg
```

Draws the table: toolbar, header, rows, totals row and pagination. `toMsg`
wraps the table's own messages, usually the constructor you handle in `update`.
The attributes describe the table (columns, rows, options) and are given on every
call; the `State` only holds what the user changed.

    Table.view TableMsg [ Table.columns columns, Table.rows model.orders ] model.table

## State

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

What the table remembers: sort, page, page size, search, filters, selection,
expanded rows, hidden columns and density, and which popup and row are open or
focused. Make one with `init`, keep it in your model, change it with `update`
(or the setters in this module) and pass it to `view`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from the table's own controls: sorting, paging, typing in a filter,
opening a popup and so on. You never make one. Give `view` a constructor of your
own that wraps it (`TableMsg`), and hand the `m` in `TableMsg m` to `update`.

### `init`

```elm
init : String -> State id
```

A table with nothing sorted, filtered or selected, on page 1 with 25 rows
per page and normal density. The `String` is a DOM id and must be unique on
the page. It is the id of the table's element and the prefix of the ids inside
it (`"orders"` gives `"orders-search"` for the search box, for example).

### `update`

```elm
update : Msg -> State id -> ( State id, Cmd Msg )
```

Applies a message from the table to its state. The `Cmd` moves keyboard
focus (into a popup, back to its button) and runs the timer behind the search
debounce, so map it back with your own constructor: `Cmd.map TableMsg cmd`.

### `focus`

```elm
focus : State id -> Cmd Msg
```

Moves keyboard focus to the table (its scroll area; Tab goes on to the
header from there). Use it when whatever had focus is gone: a bulk action that
removed the selected rows takes the bulk bar and its buttons with it, and focus
would fall back to the page.

    DeleteSelected ->
        ( { model
            | orders = withoutOrders (Table.selectedIds orderRows model.table) model.orders
            , table = Table.clearSelection model.table
          }
        , Cmd.map TableMsg (Table.focus model.table)
        )

The `id` of `State id` is the type of your row ids (`State OrderId`). Declare how
it is written as a key once with `rowIds`, and the selection and the expanded rows
come back in your own type, with no converting to text and back:

### `RowIds`

```elm
type RowIds id  -- opaque: no constructors are exposed
```

How your row id type (an `OrderId`, a `CustomerId` ...) is written as a key
and read back. Declare one value for each kind of row, once, and pass it to
`rowId`, `selectedIds`, `isSelected`, `setSelected` and the other functions that
speak ids. The `State` of the table is then typed by the id: a table of orders
cannot be asked about customer ids.

    orderRows : Table.RowIds OrderId
    orderRows =
        Table.rowIds { toKey = OrderId.toString, fromKey = OrderId.fromString }

The key is what the table keeps inside its `State`, so `toKey` must give every id
its own key and `fromKey` must give the id back. A key `fromKey` rejects (it can
come from a saved view that holds an old id) is left out of the lists you get.
The lists are ordered by key, as text, not in the order the ids were selected.

### `rowIds`

```elm
rowIds : { toKey : id -> String, fromKey : String -> Maybe id } -> RowIds id
```

Makes the `RowIds` of an id type, see there.

### `stringIds`

```elm
stringIds : RowIds String
```

Row ids that are plain text (a SKU, a code), used as they are.

    Table.rowId Table.stringIds .sku

### `intIds`

```elm
intIds : RowIds Int
```

Row ids that are whole numbers (a database id).

    Table.rowId Table.intIds .id

A table that never needs its row ids (no `selectable`, no `expandedRow`) can use
any type for `id`, for example `Table.State ()`.

## Sort, page, search and filters

Read these after `update` to see what the user asked for, or set them to restore
a saved view.

### `ColumnId`

```elm
type ColumnId  -- opaque: no constructors are exposed
```

The id of a column, which sort, filters, column choices and a `Query` refer to.
Make it once with `columnId`, keep it as a value of your own, and give it to the
column and to the functions that talk about the column, so that a misspelled id
cannot happen:

    customer : Table.ColumnId
    customer =
        Table.columnId "customer"

    Table.text customer "Customer" .customer []

    Table.setSort [ ( customer, Table.Ascending ) ] state

### `columnId`

```elm
columnId : String -> ColumnId
```

Names a column. The text has to be unique in the table and has to stay the
same: a saved sort, a saved filter and a hidden column refer to it. It is also
what you send to a backend for the column (see `columnName`).

### `columnName`

```elm
columnName : ColumnId -> String
```

The text a column id was made from, for a backend that sorts or filters by a
name, or for a URL.

    Table.query state |> .sort |> List.map (Tuple.first >> Table.columnName)

### `Query`

```elm
type alias Query =
    { search : String
    , sort : List ( ColumnId, Direction )
    , filters : List ( ColumnId, Filter )
    , page : Int
    , pageSize : Int
    }
```

Everything a backend needs to produce the rows the user asked for: the
search text, the sort levels (primary first), the column filters (ordered by
column id), the page (the first is 1) and the page size. It is plain data, so
you can compare two queries with `==` and fetch only when it changed, or keep
one in the URL or in a saved view (see `setQuery`).

### `Direction`

```elm
type Direction = Ascending | Descending
```

The direction of a sort: `Ascending` (A to Z, smallest or earliest first)
or `Descending`. Used in `Query` and `setSort`.

### `Filter`

```elm
type Filter = Contains String | OneOf (List String) | Between (Maybe Float) (Maybe Float)
```

A column filter, as the user set it in the header or as you restore it with
`setFilter`.

  - `Contains text` - the column text contains `text` as one piece, ignoring case
    and accents (the search box, in contrast, looks for each word separately)
  - `OneOf values` - the column text is exactly one of `values`, case included
    (see `bool` for yes / no columns)
  - `Between from to` - the column number is within the bounds (inclusive); a
    `Nothing` bound is open. A row without a number does not match, and on a
    column that has no numbers at all every row matches.

### `query`

```elm
query : State id -> Query
```

The current request as plain data: search text, sort, filters, page and page
size. In server mode, fetch whenever it changed; in client mode you only need it
to save the table's view (see `setQuery`). The search text and the filters are
the ones in effect, so text still waiting for the debounce is not in it.

### `setQuery`

```elm
setQuery : Query -> State id -> State id
```

Sets the search, sort, filters, page and page size from a query, for example
one restored from the URL or a saved view. The search box and the filter
popovers show the new values; a page or page size below 1 becomes 1. Selected
rows stay selected, but an "all matching" selection (see `Selection`) is dropped
when the search or the filters change.

### `sort`

```elm
sort : State id -> List ( ColumnId, Direction )
```

The columns the table is sorted by, primary first, as column ids with a
direction. Empty when nothing is sorted.

### `setSort`

```elm
setSort : List ( ColumnId, Direction ) -> State id -> State id
```

Sorts by these columns (ids and directions), primary first, and goes back to
page 1. In client mode, ids that match no column, or a column that is
`unsortable`, are ignored.

### `page`

```elm
page : State id -> Int
```

The page the user asked for, counted from 1. A page past the last one is
drawn as the last page (the footer says so, and in client mode the rows are those
of the last page), but this keeps returning the number that was asked for.

### `setPage`

```elm
setPage : Int -> State id -> State id
```

Goes to this page. The first page is 1; smaller numbers count as 1.

### `pageSize`

```elm
pageSize : State id -> Int
```

How many rows are on a page: 25 until the user picks another size in the
footer (see `pageSizes`) or you call `setPageSize`.

### `setPageSize`

```elm
setPageSize : Int -> State id -> State id
```

Sets how many rows are on a page (at least 1) and goes back to page 1. A size
that is not in `pageSizes` is still used and shown in the footer.

### `search`

```elm
search : State id -> String
```

The search text in effect: what the user typed, trimmed, once any
`searchDebounce` has passed. Empty when there is no search.

### `setSearch`

```elm
setSearch : String -> State id -> State id
```

Sets the search text. It shows in the search box, takes effect at once
(without the debounce) and goes back to page 1. A changed search drops an "all
matching" selection (see `Selection`).

### `filters`

```elm
filters : State id -> List ( ColumnId, Filter )
```

The column filters in effect, as column ids with their filter, ordered by
column id. Typed text still waiting for the debounce is not included.

### `setFilter`

```elm
setFilter : ColumnId -> Maybe Filter -> State id -> State id
```

Sets (`Just`) or removes (`Nothing`) the filter of the column with this id,
and goes back to page 1. The column's filter popover shows the new value.

### `clearFilters`

```elm
clearFilters : State id -> State id
```

Removes the search and every column filter, and goes back to page 1. Filters
that live outside the table (see `rowFilter`) are yours to clear.

## Selection

### `Selection`

```elm
type Selection id = Selected (List id) | AllMatching { except : List id }
```

What is selected: `Selected ids`, a list of row ids, or
`AllMatching { except }`. The second only happens in server mode, after the user
chose "Select all N matching": every row that matches the current `query` is
selected, except the ids in `except` (the table cannot list rows it never
received). A new search or filter drops it, because it would then mean other
rows.

### `selection`

```elm
selection : RowIds id -> State id -> Selection id
```

What is selected, as a `Selection`. In client mode `selectedIds` is enough; in
server mode check this one for `AllMatching`.

### `selectedIds`

```elm
selectedIds : RowIds id -> State id -> List id
```

The ids (see `rowId`) of the selected rows. After "Select all N matching" in
server mode this is empty: check `selection` for `AllMatching`.

### `selectedCount`

```elm
selectedCount : Int -> State id -> Int
```

How many rows are selected. Pass the number of rows that match the current
query (the `total` you give to `server`). It is only used after "Select all N
matching", where the count is that number minus the exceptions, so in client
mode any number will do.

### `isSelected`

```elm
isSelected : RowIds id -> id -> State id -> Bool
```

Is the row with this id selected? After "Select all N matching" every id
counts as selected except the exceptions.

### `setSelected`

```elm
setSelected : RowIds id -> List id -> Bool -> State id -> State id
```

Selects (`True`) or deselects (`False`) the rows with these ids, as the
checkboxes do. After "Select all N matching" selecting removes ids from the
exceptions and deselecting adds them.

### `clearSelection`

```elm
clearSelection : State id -> State id
```

Deselects everything, including an "all matching" selection. Call it when a
bulk action has done its work.

### `dropAllMatching`

```elm
dropAllMatching : State id -> State id
```

Drops an "all matching" selection (see `Selection`) and keeps the rows that were
picked one by one. The table does it by itself when its own search or filters change; call
it when something else changes what "all matching" means, such as a filter bar next to
the table.

## Expanded rows, columns and density

### `expandedIds`

```elm
expandedIds : RowIds id -> State id -> List id
```

The ids (see `rowId`) of the rows that are expanded. Rows only expand when you
give the table an `expandedRow`.

### `isExpanded`

```elm
isExpanded : RowIds id -> id -> State id -> Bool
```

Is the row with this id expanded?

### `setExpanded`

```elm
setExpanded : RowIds id -> id -> Bool -> State id -> State id
```

Expands (`True`) or collapses (`False`) the row with this id, for example to
open the first row when the table appears.

### `isColumnVisible`

```elm
isColumnVisible : ColumnId -> State id -> Maybe Bool
```

Whether the user chose to show (`Just True`) or hide (`Just False`) the
column with this id. `Nothing` means no choice yet: the column follows its
default, shown unless it is `hiddenByDefault`. With `setColumnVisible` this lets
you remember the user's column choices.

### `setColumnVisible`

```elm
setColumnVisible : ColumnId -> Bool -> State id -> State id
```

Records that the column with this id is shown (`True`) or hidden (`False`),
as if the user had ticked it in the column chooser. Columns that are
`alwaysVisible` ignore it, and the table always keeps at least one column on
screen.

### `density`

```elm
density : State id -> Theme.Density
```

The row density: `Compact`, `Normal` (the default) or `Comfortable`, from
[Klar.Theme](Klar.Theme.md). The user changes it with the buttons of `densityToggle`.

### `setDensity`

```elm
setDensity : Theme.Density -> State id -> State id
```

Sets the row density, for example from a saved preference. It works whether
or not `densityToggle` is shown.

## Basic attributes

### `Attribute`

```elm
type Attribute id row msg  -- opaque: no constructors are exposed
```

A setting of the table as a whole (`columns`, `rows`, `searchable` ...). Make
them with the functions below and pass a list to `view`; later attributes win
over earlier ones.

### `columns`

```elm
columns : List (Column row msg) -> Attribute id row msg
```

The columns of the table, left to right. Make them with `text`, `int`,
`float`, `date`, `maybeDate`, `badge`, `status`, `bool`, `custom` and `actions`.
Column ids must be unique and stay the same: sort, filters, hidden columns and
the `Query` refer to them.

### `rows`

```elm
rows : Remote.Remote (List row) -> Attribute id row msg
```

The rows, as [Klar.Remote](Klar.Remote.md) data. `Loading` (and `NotAsked`)
shows skeleton rows under the header, `Failed` shows the error with a retry
button (see `onRetry`), and `Loaded []` shows the empty state (see
`emptyState`). In server mode these are the rows of the current page only.
Without `rows` the table shows the loading skeleton.

Rows that are `Kept` stay on the screen. While they are refreshed (the next page
in server mode, a refresh button: `Remote.refresh`) they are dimmed, with a
progress line under the header, and screen readers hear "Refreshing ...". When the
last refresh failed they carry the marker "Old data from 14:05" with a retry
button (`onRetry`).

### `rowId`

```elm
rowId : RowIds id -> (row -> id) -> Attribute id row msg
```

A stable, unique id for each row, such as a database id. Selection, expanded
rows and keyed rendering depend on it; without it rows are identified by their
position in the current (filtered and sorted) result, so a selection or an open
row does not follow its row when the order changes, and `selectable` needs it.

The first argument says how your id type is written as a key and read back
(see `rowIds`); the `State` of the table then speaks your id type:

    Table.rowId orderRows .id

### `rowLabel`

```elm
rowLabel : (row -> String) -> Attribute id row msg
```

How screen readers name a row, for example in the label of its checkbox
("Select Ada Lovelace"), its expand button and its actions menu. The default is
the text of the first visible column.

### `server`

```elm
server : { total : Int } -> Attribute id row msg
```

Switches to server mode: `rows` is the current page and `total` the number
of rows that match the query. The table does not search, filter, sort or slice
the rows itself; it shows the pagination for `total` and records what the user
asks for, which you read with `query`. Without this attribute the table is in
client mode.

### `label`

```elm
label : String -> Attribute id row msg
```

The accessible name of the table, such as "Orders". It is also what makes the
scrolling area a labelled region for screen readers.

### `locale`

```elm
locale : Locale.Locale -> Attribute id row msg
```

The language of the built-in text, and the conventions that go with it:
number and date formats, the alphabetical order of text columns and the default
CSV separator. The default is `Locale.default`, which is English; see
[Klar.Locale](Klar.Locale.md).

## Search, filters and sorting

### `searchable`

```elm
searchable : Attribute id row msg
```

Adds a search box to the toolbar. Every word the user types must be found in
one of the visible, searchable columns (case and accents are ignored), and the
match is highlighted. Escape clears the box; in server mode the table only
records the text (see `query`).

### `searchPlaceholder`

```elm
searchPlaceholder : String -> Attribute id row msg
```

The placeholder of the search box. It also turns the search box on. The
default tells how many rows can be searched, as in "Search 120 rows ...", and is
just "Search ..." in server mode.

### `searchDebounce`

```elm
searchDebounce : Int -> Attribute id row msg
```

Milliseconds to wait after typing before what was typed in the search box,
the text filters and the number range filters takes effect (checkbox filters
always apply at once). The default is 0 in client mode and 350 in server mode,
so that a server is not asked on every key press.

### `rowFilter`

```elm
rowFilter : (row -> Bool) -> Attribute id row msg
```

Client mode: an extra filter from outside the table, such as a
[Klar.FilterBar](Klar.FilterBar.md) or a [Klar.RuleBuilder](Klar.RuleBuilder.md). Rows
for which it returns `False` are left out, on top of the table's own search and
filters. Tell the table how many outside filters are active with
`activeExternalFilters`; server mode ignores this one, as your backend filters.

### `activeExternalFilters`

```elm
activeExternalFilters : Int -> Attribute id row msg
```

How many filters outside the table are active (the ones behind `rowFilter`,
or the ones you send to your backend). The table uses the number to tell "no
matches" (a filter hides the rows) from "no data". It draws nothing for them: the
"N filters active" button counts the column filters of the table only, because
outside filters have a display of their own (the chips of a
[FilterBar](Klar.FilterBar.md)), and a second summary of the same filters only repeats
it. Wire `onResetFilters` once, to clear both.

### `onResetFilters`

```elm
onResetFilters : msg -> Attribute id row msg
```

The message to send when the user clicks one of the table's reset buttons: the
cross and "Reset filters" in the filter summary, which clear the column filters
and keep the search text, and "Clear search and filters" in the "No matches"
state, which clears both. When your message arrives the table has cleared its own
filters (and maybe the search), so clear your outside filters too (see
`rowFilter`) and fetch or filter again.

### `multiSort`

```elm
multiSort : Attribute id row msg
```

Lets the user sort by several columns: Shift-clicking a header adds that
column as the next sort level (or cycles its direction in place), and the
headers show the order as small numbers. A plain click sorts by that column
only; without `multiSort`, Shift changes nothing.

## Selection and rows

### `selectable`

```elm
selectable : Attribute id row msg
```

Adds a checkbox column, a "select all on this page" checkbox in the header,
and a bar that covers the toolbar while something is selected (see
`bulkActions`). Needs `rowId`; Space selects the focused row, and rows that are
`rowDisabled` cannot be selected. When a whole page is selected and more rows
match, the bar offers "Select all N matching".

### `bulkActions`

```elm
bulkActions : List (Html msg) -> Attribute id row msg
```

Buttons for the bar that covers the toolbar while rows are selected, next to
the count, the export menu and a Cancel button that clears the selection. Your
buttons send plain messages: read `selectedIds` in your update. Use small
buttons; it also turns on `selectable`.

    Table.bulkActions [ Button.view [ Button.small, Button.onClick DeleteSelected ] "Delete" ]

### `rowActions`

```elm
rowActions : (row -> List (Menu.Item msg)) -> Attribute id row msg
```

A "more" menu at the end of every row, made of [Klar.Menu](Klar.Menu.md) items.
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

### `onRowClick`

```elm
onRowClick : (row -> msg) -> Attribute id row msg
```

The message to send for a row, when the user clicks it (outside its own
controls) or presses Enter on it. The function gets the row. A row that is
`rowDisabled` does not send it.

### `expandedRow`

```elm
expandedRow : (row -> Html msg) -> Attribute id row msg
```

Lets rows expand to show more under them: adds an arrow button at the start
of each row and draws `render row` in a full-width cell below an open row.
ArrowRight and ArrowLeft expand and collapse the focused row, and without
`onRowClick` a click on the row toggles it too; a `rowDisabled` row does none of
this. Which rows are open is part of the state (see `expandedIds` and
`setExpanded`).

### `rowTone`

```elm
rowTone : (row -> Maybe Theme.Tone) -> Attribute id row msg
```

A colored accent at the start of some rows: return a `Tone` (from
[Klar.Theme](Klar.Theme.md)) for the rows that need one and `Nothing` for the rest.

### `rowDisabled`

```elm
rowDisabled : (row -> Bool) -> Attribute id row msg
```

Rows that are shown but cannot be operated. A disabled row is dimmed and
marked `aria-disabled`; its checkbox, expand button and actions button are
disabled, so Tab skips them, and it is left out of "select all". A click, Enter,
Space, ArrowRight, ArrowLeft, Shift+F10 or the menu key on the row does nothing,
but the keys that move between rows (ArrowUp, ArrowDown, PageUp, PageDown, Home,
End) still reach it, so that its text can be read. Selection and expansion that a
row already has stay until you change them with `setSelected` or `setExpanded`,
and controls you draw yourself (`actions`, `cell`, `custom`) are yours to
disable.

## Loading and empty states

### `zone`

```elm
zone : Time.Zone -> Attribute id row msg
```

The time zone of the time in "Old data from 14:05". The default is UTC.

### `onRefresh`

```elm
onRefresh : msg -> Attribute id row msg
```

Adds a refresh button to the toolbar that sends this message. The button
shows a spinner while the rows are refreshing (`Remote.refresh`) or loading.

### `onRetry`

```elm
onRetry : msg -> Attribute id row msg
```

The message to send when the user clicks "Try again" in the error state, which
shows when `rows` is a `Failed`. Without it there is no button, and the button
only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar.Remote.md)). Keyboard focus stays in the table while the new rows
load.

### `emptyState`

```elm
emptyState : List (EmptyState.Attribute msg) -> Attribute id row msg
```

Changes the empty state shown when there are no rows at all (titled "No data"
by default). The "No matches" state for a search or filter that hides every row
is built in and not affected; its "Clear search and filters" button clears the
search and the column filters, and sends your `onResetFilters` message. The
attributes are those of
[Klar.EmptyState](Klar.EmptyState.md), applied after the built-in ones, so yours
win.

    Table.emptyState [ EmptyState.title "No orders yet", EmptyState.action addButton ]

## Toolbar and export

### `toolbarActions`

```elm
toolbarActions : List (Html msg) -> Attribute id row msg
```

Your own buttons at the right end of the toolbar, next to the table's own
tools.

### `exportCsv`

```elm
exportCsv : String -> Attribute id row msg
```

Adds an "Export" menu to the toolbar (and to the bar that shows while rows are
selected) that downloads the visible columns as a CSV file. The `String` is the
file name, used as given (`"orders.csv"`).

The menu offers all matching rows (client mode), the selected rows and the
current page, the last two with a suffix in the file name (`orders-selected.csv`,
`orders-page-2.csv`). In server mode only the current page is known, so the
selected rows are offered only while every selected row is on the page; when some
are selected on other pages the menu says how many and offers the page only. Build
that file from your backend (the ids are in `selectedIds`). Hidden
columns and `notExported` columns are left out, and so are `custom` and
`actions` columns unless they have `exportAs`. Text that a spreadsheet could run
as a formula is made safe. See `csvSeparator` for the field separator.

### `csvSeparator`

```elm
csvSeparator : Char -> Attribute id row msg
```

The field separator of the CSV export. The default is a comma in English and
a semicolon in Norwegian, where spreadsheets use the comma as the decimal
separator.

### `columnChooser`

```elm
columnChooser : Attribute id row msg
```

Adds a "Columns" button to the toolbar that opens a list of checkboxes to
hide and show columns, with Reset and Done buttons. Columns that are
`alwaysVisible`, and the last visible column, cannot be hidden. The choices are
part of the state (see `isColumnVisible` and `setColumnVisible`).

### `densityToggle`

```elm
densityToggle : Attribute id row msg
```

Adds three buttons to the toolbar to choose the row height: compact, normal
or comfortable. The choice is part of the state (see `density` and
`setDensity`).

## Pagination and layout

### `pageSizes`

```elm
pageSizes : List Int -> Attribute id row msg
```

The choices of the "Rows per page" selector in the footer. The default is
`[ 10, 25, 50, 100 ]`. The page size itself is part of the state (25 from
`init`; see `pageSize` and `setPageSize`).

### `unpaged`

```elm
unpaged : Attribute id row msg
```

All rows on one page and no pagination footer. Every matching row is turned
into HTML, so keep it for short tables.

### `virtual`

```elm
virtual : Attribute id row msg
```

Shows the rows in one long list that scrolls, instead of in pages, and draws
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

### `zebra`

```elm
zebra : Attribute id row msg
```

Gives every second row a light gray background.

### `maxHeight`

```elm
maxHeight : Int -> Attribute id row msg
```

The rows scroll inside this height in pixels, under a header that stays in
view. Without it the table is as tall as its rows.

### `fillHeight`

```elm
fillHeight : Attribute id row msg
```

The table fills the height of its parent, which must have a height of its
own, and the rows scroll inside under the header. For the rest of the page under
a heading, put the table in a `Layout.stack [ Layout.fillRest ]` (inside an
`AppShell` that is the height of the window under the top bar).

## Many rows

Prepared rows are made once for a list of rows that arrives or changes (see "Many
rows" at the top).

### `Rows`

```elm
type Rows row  -- opaque: no constructors are exposed
```

Rows that the table has worked on in advance: for each row the text the search
looks in, and for each sortable column the rows in order. Make them once, when the
rows arrive or change, and keep them in your model instead of the `Array`; give
them to the table with `preparedRows`.

    Loaded orders ->
        { model | orders = Loaded (Table.prepareRows locale columns orders) }

They are made for one locale and one list of columns. A table that is given other
columns or another locale shows the right rows all the same, but works them out
again on every message, as `rows` does.

### `prepareRows`

```elm
prepareRows : Locale.Locale -> List (Column row msg) -> Array row -> Rows row
```

Prepares the rows for a table with these columns in this locale (the `Locale`
you give to `locale`). Take the same columns you give to `columns`. Every sortable
column is sorted once here, so this takes about as long as sorting by each column
would, a few hundred milliseconds for 50 000 rows, and a table that is given
the result never has to sort again.

### `rowsArray`

```elm
rowsArray : Rows row -> Array row
```

The rows of prepared rows, to give to other parts of the page that want an
`Array` too, such as [Klar.VirtualList](Klar.VirtualList.md). It costs nothing.

### `preparedRows`

```elm
preparedRows : Remote.Remote (Rows row) -> Attribute id row msg
```

The rows of a client-mode table that has thousands of them, as `Rows` made
once with `prepareRows` (see "Performance" at the top). It does what `rows` does,
and the search and the sorting no longer format every value again on each message.

## Columns

### `Column`

```elm
type Column row msg  -- opaque: no constructors are exposed
```

One column of the table. Make it with `text`, `int`, `float`, `date`,
`maybeDate`, `badge`, `status`, `bool`, `custom` or `actions`, and give a list of
them to `columns`.

### `text`

```elm
text : ColumnId -> String -> (row -> String) -> List (ColumnAttribute row msg) -> Column row msg
```

A text column: `Table.text (Table.columnId "customer") "Customer" .customer []` takes the
column id (unique in the table), the title for the header and a function that
reads the text from a row.

The text is searched, sorted alphabetically (in the order of the table's
`locale`), exported to CSV and highlighted where it matches the search. A long
text is cut with an ellipsis and a tooltip, a blank one is shown as a dash and
sorts last, and the column is at least 120 pixels wide (see `minWidth`).

### `int`

```elm
int : ColumnId -> String -> (row -> Int) -> List (ColumnAttribute row msg) -> Column row msg
```

A whole number: `Table.int (Table.columnId "items") "Items" .items []`. It is right-aligned
with tabular digits and thousands separators (`1,234` in English), sorted
numerically, exported as a plain number and 104 pixels wide (see `width`). It
supports `filterRange`, `footerSum` and `footerAverage`, and the search box
skips it unless you add `includeInSearch`.

### `float`

```elm
float :
    ColumnId
    -> String
    -> Int
    -> (row -> Float)
    -> List (ColumnAttribute row msg)
    -> Column row msg
```

A decimal number with a fixed count of decimals:
`Table.float (Table.columnId "weight") "Weight (kg)" 1 .weight []`. The `Int` is the number of
decimals shown (also in filter hints and footers). It is like `int` otherwise,
but 112 pixels wide, and the CSV export keeps the decimals with the locale's
decimal separator and no thousands separator, so a spreadsheet reads a number.

### `date`

```elm
date : ColumnId -> String -> (row -> Date.Date) -> List (ColumnAttribute row msg) -> Column row msg
```

A calendar date ([Klar.Date](Klar.Date.md)), sorted by date and shown as
`2026-10-20` in English or `20.10.2026` in Norwegian. For a date that may be
missing use `maybeDate`.

    Table.date (Table.columnId "shipped") "Shipped" .shippedOn []

### `maybeDate`

```elm
maybeDate :
    ColumnId
    -> String
    -> (row -> Maybe Date.Date)
    -> List (ColumnAttribute row msg)
    -> Column row msg
```

Like `date`, for a date that may be missing: `Nothing` is shown as a dash
and sorts last, whichever way the column is sorted.

### `badge`

```elm
badge :
    ColumnId
    -> String
    -> (row -> ( Theme.Tone, String ))
    -> List (ColumnAttribute row msg)
    -> Column row msg
```

A tone ([Klar.Theme](Klar.Theme.md)) and a label, shown as a
[Klar.Badge](Klar.Badge.md). The label is the text used for search, sorting, export
and `filterSelect`; the column is 124 pixels wide.

    Table.badge (Table.columnId "status")
        "Status"
        (\order -> ( statusTone order.status, statusLabel order.status ))
        [ Table.filterSelect ]

### `status`

```elm
status :
    ColumnId
    -> String
    -> (row -> ( Theme.Tone, String ))
    -> List (ColumnAttribute row msg)
    -> Column row msg
```

Like `badge`, but drawn as a colored dot and text (`Badge.status` in
[Klar.Badge](Klar.Badge.md)), which is quieter in dense tables.

### `bool`

```elm
bool : ColumnId -> String -> (row -> Bool) -> List (ColumnAttribute row msg) -> Column row msg
```

A yes / no column: a check mark for yes and a dash for no. The words ("Yes"
and "No" in English) are what screen readers hear and what search, sorting,
export and `filterSelect` use.

When the user picks values in the `filterSelect` of this column, the table
stores them as the words `"true"` and `"false"` whatever the locale, so that a
saved filter still matches when the language changes, and so that a backend can
read a server-mode `Query` without knowing the language. A `Filter` you read from
`filters` or `query` therefore holds those words, while `setFilter` also accepts
the words of either language ("Yes", "Ja").

### `custom`

```elm
custom : ColumnId -> String -> (row -> Html msg) -> List (ColumnAttribute row msg) -> Column row msg
```

A column with your own HTML and no text: `render` draws the cell. Without
text the column is not searched, sorted or exported; turn sorting back on with
`sortText`, `sortNumber`, `sortMaybeNumber`, `sortDate` or `sortWith`, and export
with `exportAs`. For a custom look with a text behind it, use `text` with `cell`
instead.

    Table.custom (Table.columnId "progress") "Progress" viewProgress [ Table.sortNumber .progress ]

### `actions`

```elm
actions :
    ColumnId
    -> String
    -> (row -> List (Html msg))
    -> List (ColumnAttribute row msg)
    -> Column row msg
```

Inline controls for each row, such as small icon buttons or links: `render`
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

## Column layout and content

### `ColumnAttribute`

```elm
type ColumnAttribute row msg  -- opaque: no constructors are exposed
```

A setting of one column. Make them with the functions below and pass a list
as the last argument of `text`, `int` and the other column helpers; later
attributes win over earlier ones.

### `width`

```elm
width : Int -> ColumnAttribute row msg
```

A fixed width in pixels (at least 24). Columns without a width share the
space that is left. A fixed column is never narrower than its header needs, so
the title is not cut.

### `minWidth`

```elm
minWidth : Int -> ColumnAttribute row msg
```

The column shares the remaining space but never gets narrower than this many
pixels (at least 24); the table scrolls sideways instead. The default is 120.
It also replaces a fixed width, such as the one `int`, `date` and `badge`
columns start with.

### `alignRight`

```elm
alignRight : ColumnAttribute row msg
```

Aligns the header and the cells of the column to the right, as numbers
should be. Columns start left-aligned, except `int`, `float` and `actions`,
which are right-aligned.

### `alignCenter`

```elm
alignCenter : ColumnAttribute row msg
```

Centers the header and the cells of the column. A `bool` column starts
centered.

### `pinned`

```elm
pinned : ColumnAttribute row msg
```

Keeps the column in view while the table scrolls sideways. Only the first
visible column can be pinned (on any other column this does nothing); the
selection and expand columns, if there are any, stay with it.

### `hiddenByDefault`

```elm
hiddenByDefault : ColumnAttribute row msg
```

The column starts hidden. The user can show it in the column chooser (see
`columnChooser`), and you can with `setColumnVisible`.

### `alwaysVisible`

```elm
alwaysVisible : ColumnAttribute row msg
```

The user cannot hide the column: its checkbox in the column chooser is
disabled. It also cancels `hiddenByDefault`.

### `wrap`

```elm
wrap : ColumnAttribute row msg
```

Long values wrap onto more lines instead of being cut, so the row grows. There
is no tooltip then, as the whole value is visible.

### `noTooltip`

```elm
noTooltip : ColumnAttribute row msg
```

Turns off the tooltip (the `title` attribute) that shows the full value of a
cell whose text is cut off.

### `cell`

```elm
cell : (row -> Html msg) -> ColumnAttribute row msg
```

Draws the cell yourself. The text accessor of the column is still used for
search, sorting, export and filters, but a match is no longer highlighted in the
cell, and there is no tooltip.

    Table.text (Table.columnId "customer") "Customer" .customer [ Table.cell viewCustomerLink ]

### `hint`

```elm
hint : String -> ColumnAttribute row msg
```

A short explanation of the column, shown as a tooltip on the header. It
replaces the default tooltip ("Click to sort").

## Column sorting

### `sortText`

```elm
sortText : (row -> String) -> ColumnAttribute row msg
```

Sorts alphabetically (in the order of the table's `locale`) by another text
than the one shown.

### `sortNumber`

```elm
sortNumber : (row -> Float) -> ColumnAttribute row msg
```

Sorts by a number instead of the text. The number also makes `filterRange`,
`footerSum` and `footerAverage` work on a column that shows text.

### `sortMaybeNumber`

```elm
sortMaybeNumber : (row -> Maybe Float) -> ColumnAttribute row msg
```

Like `sortNumber`, for a number that may be missing: rows with `Nothing` go
last, whichever way the column is sorted.

### `sortDate`

```elm
sortDate : (row -> Date.Date) -> ColumnAttribute row msg
```

Sorts by a date instead of the text, for example when the column shows a
date in your own format.

    Table.text (Table.columnId "due") "Due" .dueText [ Table.sortDate .dueDate ]

### `sortWith`

```elm
sortWith : (row -> row -> Order) -> ColumnAttribute row msg
```

Sorts with your own comparison, written for the ascending order; the table
reverses it for `Descending`. Rows that compare equal keep their order.

    Table.text (Table.columnId "size") "Size" .sizeLabel [ Table.sortWith (\a b -> compare a.sizeRank b.sizeRank) ]

### `unsortable`

```elm
unsortable : ColumnAttribute row msg
```

Turns sorting off for the column: its header is a plain title instead of a
button.

## Column search and export

### `notSearchable`

```elm
notSearchable : ColumnAttribute row msg
```

The search box skips this column.

### `includeInSearch`

```elm
includeInSearch : ColumnAttribute row msg
```

The search box looks in this column. Text, date, badge, status and yes / no
columns are searched by default; number columns are not (searching "42" rarely
means an item count). Only visible columns are searched.

### `exportAs`

```elm
exportAs : (row -> String) -> ColumnAttribute row msg
```

The value written to the CSV export, when it should differ from the text
shown. It also puts a column in the export that would be left out otherwise,
such as a `custom` column.

### `notExported`

```elm
notExported : ColumnAttribute row msg
```

Leaves the column out of the CSV export (see `exportCsv`).

## Column filters

### `filterText`

```elm
filterText : ColumnAttribute row msg
```

Adds a "contains" text filter to the column: a filter button in the header
opens a popover with an input. Case and accents are ignored.

### `filterSelect`

```elm
filterSelect : ColumnAttribute row msg
```

Adds a filter in the header where the user picks values with checkboxes. In
client mode the values are the distinct, non-blank texts of the column in all
rows, in the alphabetical order of the locale, each with the number of rows it
would add given the other filters and the search. In server mode the table only
sees one page, so without `filterOptions` it offers just the values on the
current page, with no counts. A search box appears above the values when there
are more than eight.

### `filterOptions`

```elm
filterOptions : List String -> ColumnAttribute row msg
```

The values offered by `filterSelect`, in this order, instead of the ones found
in the rows (client mode still counts the rows of each). They must equal the
column's text for the rows they should match, and a chosen value that is not in
the list stays in it. It also turns the select filter on, so `filterSelect` is
not needed next to it.

    Table.text (Table.columnId "status") "Status" .statusLabel [ Table.filterOptions [ "Open", "Shipped", "Cancelled" ] ]

### `filterRange`

```elm
filterRange : ColumnAttribute row msg
```

Adds a from / to number filter to the column; either bound can be left
empty. It needs a number column (`int`, `float`) or `sortNumber`; on a column
without numbers there is no filter button.

## Column footers

### `footer`

```elm
footer : (List row -> String) -> ColumnAttribute row msg
```

A footer value computed from the rows: all rows that match the search and
filters in client mode, the current page in server mode. The footer row shows
when any visible column has a footer value and there are rows.

    Table.int (Table.columnId "items") "Items" .items [ Table.footer (\orders -> String.fromInt (List.length orders) ++ " orders") ]

### `footerSum`

```elm
footerSum : ColumnAttribute row msg
```

The sum of a number column in the footer, as in "Sum 12,345". It adds up the
same rows as `footer`.

### `footerAverage`

```elm
footerAverage : ColumnAttribute row msg
```

The average of a number column in the footer, as in "Avg 51.2". It is written
with the decimals of the column (one at least, so an average of whole numbers is
not rounded to a whole number): cents stay cents in a money column. It averages
the same rows as `footer`; a dash is shown when there is nothing to average.
