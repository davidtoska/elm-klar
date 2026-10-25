module Klar.Table.Config exposing (..)

{-| Table attributes and their order-independent final defaults.
-}

import Html exposing (Html)
import Klar.EmptyState as EmptyState
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Theme as Theme exposing (Density(..), Tone)


configure : List (Attribute id row msg) -> Config row msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { columns = []
        , rows = Remote.Loading
        , rowId = Nothing
        , rowLabel = Nothing
        , server = Nothing
        , label = Nothing
        , locale = Locale.default
        , settings = Settings.default
        , searchable = False
        , searchPlaceholder = Nothing
        , searchDebounce = Nothing
        , rowFilter = Nothing
        , externalFilters = 0
        , onResetFilters = Nothing
        , selectable = False
        , bulkActions = []
        , rowActions = Nothing
        , onRowClick = Nothing
        , expandedRow = Nothing
        , rowTone = Nothing
        , rowDisabled = Nothing
        , currentRow = Nothing
        , toolbarActions = []
        , onRefresh = Nothing
        , refreshing = False
        , freshness = Freshness.Fresh
        , onRetry = Nothing
        , export = Nothing
        , csvSeparator = Nothing
        , columnChooser = False
        , densityToggle = False
        , pageSizes = [ 10, 25, 50, 100 ]
        , rangeText = Nothing
        , paged = True
        , virtual = False
        , multiSort = False
        , zebra = False
        , maxHeight = Nothing
        , fillHeight = False
        , emptyState = []
        }
        attributes
        |> finish


{-| What follows from the attributes together, whatever their order: a long
table has no pages in client mode, and rows of one height have no details.
-}
finish : Config row msg -> Config row msg
finish config =
    if config.virtual then
        { config
            | paged = config.paged && config.server /= Nothing
            , expandedRow = Nothing
        }

    else
        config


{-| The columns of the table, left to right. Make them with `text`, `int`,
`float`, `date`, `maybeDate`, `badge`, `status`, `bool`, `custom` and `actions`.
Column ids must be unique and stay the same: sort, filters, hidden columns and
the `Query` refer to them.
-}
columns : List (Column row msg) -> Attribute id row msg
columns value =
    Attribute (\config -> { config | columns = value })


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
remote value =
    Attribute
        (\config ->
            let
                ( current, freshness ) =
                    Freshness.settle value
            in
            { config | rows = Remote.map FromList current, freshness = freshness, refreshing = Freshness.busy freshness }
        )


{-| The rows of a client-mode table that has thousands of them, as `Rows` made
once with `prepareRows` (see "Many rows" at the top), instead of `remote`. It
does what `remote` does, and the search and a sort by one column no longer format
every value again on each message.

    Table.remotePrepared model.orders -- Remote (Table.Rows Order)

-}
remotePrepared : Remote (Rows row) -> Attribute id row msg
remotePrepared value =
    Attribute
        (\config ->
            let
                ( current, freshness ) =
                    Freshness.settle value
            in
            { config | rows = Remote.map FromRows current, freshness = freshness, refreshing = Freshness.busy freshness }
        )


{-| A stable, unique id for each row, such as a database id. Selection, expanded
rows and keyed rendering depend on it; without it rows are identified by their
position in the current (filtered and sorted) result, so a selection or an open
row does not follow its row when the order changes, and `selectable` needs it.

The first argument says how your id type is written as a key and read back
(a [Klar.Ids](Klar-Ids)); the `State` of the table then speaks your id type:

    Table.rowId orderIds .id

-}
rowId : Ids id -> (row -> id) -> Attribute id row msg
rowId ids toId =
    Attribute (\config -> { config | rowId = Just (toId >> Ids.toKey ids) })


{-| How screen readers name a row, for example in the label of its checkbox
("Select Ada Lovelace"), its expand button and its actions menu. The default is
the text of the first visible column.
-}
rowLabel : (row -> String) -> Attribute id row msg
rowLabel toLabel =
    Attribute (\config -> { config | rowLabel = Just toLabel })


{-| Switches to server mode: `remote` is the current page and `total` the number
of rows that match the query. The table does not search, filter, sort or slice
the rows itself; it shows the pagination for `total` and records what the user
asks for, which you read with `query`. Without this attribute the table is in
client mode.
-}
server : { total : Int } -> Attribute id row msg
server options =
    Attribute (\config -> { config | server = Just (max 0 options.total) })


{-| The name of the table that screen readers hear, such as "Orders" (it is not
shown: a visible title is a heading of your own above the table). It also makes
the scrolling area a labelled region and names the page controls in the footer
("Pages of Orders"), so that two tables on a page can be told apart. Give every
table one.
-}
ariaLabel : String -> Attribute id row msg
ariaLabel value =
    Attribute (\config -> { config | label = Just value })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Table.settings model.settings

-}
settings : Settings -> Attribute id row msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text, and the conventions that go with it:
number and date formats, the alphabetical order of text columns and the default
CSV separator. The default is `Locale.default`, which is English; see
[Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute id row msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Adds a search box to the toolbar. Every word the user types must be found in
one of the visible, searchable columns (case and accents are ignored), and the
match is highlighted. Escape clears the box and is used up (its default is
prevented, so a dialog that closes only on an Escape nothing inside took stays
open); an Escape in the empty box is left to the dialog. In server mode the table
only records the text (see `query`).
-}
searchable : Attribute id row msg
searchable =
    Attribute (\config -> { config | searchable = True })


{-| The placeholder of the search box. It also turns the search box on. The
default tells how many rows can be searched, as in "Search 120 rows ...", and is
just "Search ..." in server mode.
-}
searchPlaceholder : String -> Attribute id row msg
searchPlaceholder value =
    Attribute (\config -> { config | searchable = True, searchPlaceholder = Just value })


{-| Milliseconds to wait after typing before what was typed in the search box,
the text filters and the number range filters takes effect (checkbox filters
always apply at once). The default is 0 in client mode and 350 in server mode,
so that a server is not asked on every key press.
-}
searchDebounce : Int -> Attribute id row msg
searchDebounce ms =
    Attribute (\config -> { config | searchDebounce = Just (max 0 ms) })


{-| Client mode: an extra filter from outside the table, such as a
[Klar.FilterBar](Klar-FilterBar) or a [Klar.RuleBuilder](Klar-RuleBuilder). Rows
for which it returns `False` are left out, on top of the table's own search and
filters. Tell the table how many outside filters are active with
`activeExternalFilters`; server mode ignores this one, as your backend filters.
-}
rowFilter : (row -> Bool) -> Attribute id row msg
rowFilter keep =
    Attribute (\config -> { config | rowFilter = Just keep })


{-| How many filters outside the table are active (the ones behind `rowFilter`,
or the ones you send to your backend). The table uses the number to tell "no
matches" (a filter hides the rows) from "no data". It draws nothing for them: the
"N filters active" button counts the column filters of the table only, because
outside filters have a display of their own (the chips of a
[FilterBar](Klar-FilterBar)), and a second summary of the same filters only repeats
it. Wire `onResetFilters` once, to clear both.
-}
activeExternalFilters : Int -> Attribute id row msg
activeExternalFilters n =
    Attribute (\config -> { config | externalFilters = max 0 n })


{-| The message to send when the user clicks one of the table's reset buttons: the
cross and "Reset filters" in the filter summary, which clear the column filters
and keep the search text, and "Clear search and filters" in the "No matches"
state, which clears both. When your message arrives the table has cleared its own
filters (and maybe the search), so clear your outside filters too (see
`rowFilter`) and fetch or filter again.
-}
onResetFilters : msg -> Attribute id row msg
onResetFilters msg =
    Attribute (\config -> { config | onResetFilters = Just msg })


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
    Attribute (\config -> { config | selectable = True })


{-| Buttons for the bar that covers the toolbar while rows are selected, next to
the count, the export menu and a Cancel button that clears the selection. Your
buttons send plain messages: read `selection` in your update, which is
`AllMatching { except }` after "Select all N matching" in server mode (then
`selectedIds` is `[]`). Use small buttons; it also turns on `selectable`, and like
it needs `rowId`: without it the table draws no checkboxes and no bar.

    Table.bulkActions [ Button.view [ Button.small, Button.onClick DeleteSelected ] "Delete" ]

-}
bulkActions : List (Html msg) -> Attribute id row msg
bulkActions value =
    Attribute (\config -> { config | selectable = True, bulkActions = value })


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
rowActions toItems =
    Attribute (\config -> { config | rowActions = Just toItems })


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
onRowClick toMsg =
    Attribute (\config -> { config | onRowClick = Just toMsg })


{-| Marks the row whose details are shown elsewhere, such as the order open in a
drawer next to the table: it gets a bar at its start and a darker background, and
screen readers hear it as the current row (`aria-current`). Return `True` for at
most one row; without this attribute no row is marked.

    Table.currentRow (\order -> Just order.id == model.openOrder)

-}
currentRow : (row -> Bool) -> Attribute id row msg
currentRow isCurrent =
    Attribute (\config -> { config | currentRow = Just isCurrent })


{-| Lets rows expand to show more under them: adds an arrow button at the start
of each row and draws `render row` in a full-width cell below an open row.
ArrowRight and ArrowLeft expand and collapse the focused row, and without
`onRowClick` a click on the row toggles it too; a `rowDisabled` row does none of
this. Which rows are open is part of the state (see `expandedIds` and
`expand`). Needs `rowId`: without it no row expands.
-}
expandedRow : (row -> Html msg) -> Attribute id row msg
expandedRow render =
    Attribute (\config -> { config | expandedRow = Just render })


{-| A colored accent at the start of some rows: return a `Tone` (from
[Klar.Theme](Klar-Theme)) for the rows that need one and `Nothing` for the rest.
-}
rowTone : (row -> Maybe Tone) -> Attribute id row msg
rowTone toTone =
    Attribute (\config -> { config | rowTone = Just toTone })


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
rowDisabled isDisabled =
    Attribute (\config -> { config | rowDisabled = Just isDisabled })


{-| Your own buttons at the right end of the toolbar, next to the table's own
tools.
-}
toolbarActions : List (Html msg) -> Attribute id row msg
toolbarActions value =
    Attribute (\config -> { config | toolbarActions = value })


{-| Adds a refresh button to the toolbar that sends this message. The button
shows a spinner while the rows are refreshing (`Remote.refresh`) or loading.
-}
onRefresh : msg -> Attribute id row msg
onRefresh msg =
    Attribute (\config -> { config | onRefresh = Just msg })


{-| The message to send when the user clicks "Try again" in the error state, which
shows when `remote` is a `Failed`. Without it there is no button, and the button
only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar-Remote)). Keyboard focus stays in the table while the new rows
load.
-}
onRetry : msg -> Attribute id row msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


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
exportCsv filename =
    Attribute (\config -> { config | export = Just filename })


{-| The field separator of the CSV export. The default is a comma in English and
a semicolon in Norwegian, where spreadsheets use the comma as the decimal
separator.
-}
csvSeparator : Char -> Attribute id row msg
csvSeparator value =
    Attribute (\config -> { config | csvSeparator = Just value })


{-| Adds a "Columns" button to the toolbar that opens a list of checkboxes to
hide and show columns, with Reset and Done buttons. Columns that are
`alwaysVisible`, and the last visible column, cannot be hidden. The choices are
part of the state (see `isColumnVisible` and `setColumnVisible`).
-}
columnChooser : Attribute id row msg
columnChooser =
    Attribute (\config -> { config | columnChooser = True })


{-| Adds three buttons to the toolbar to choose the row height: compact, normal
or comfortable. The choice is part of the state (see `density` and
`setDensity`).
-}
densityToggle : Attribute id row msg
densityToggle =
    Attribute (\config -> { config | densityToggle = True })


{-| The choices of the "Rows per page" selector in the footer. The default is
`[ 10, 25, 50, 100 ]`. The page size itself is part of the state (25 from
`init`; see `pageSize` and `setPageSize`).
-}
pageSizes : List Int -> Attribute id row msg
pageSizes value =
    Attribute (\config -> { config | pageSizes = value })


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
rangeText words =
    Attribute (\config -> { config | rangeText = Just words })


{-| All rows on one page and no pagination footer. Every matching row is turned
into HTML, so keep it for short tables.
-}
unpaged : Attribute id row msg
unpaged =
    Attribute (\config -> { config | paged = False })


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
    Attribute (\config -> { config | virtual = True })


{-| Lets the user sort by several columns: Shift-clicking a header adds that
column as the next sort level (or cycles its direction in place), and the
headers show the order as small numbers. A plain click sorts by that column
only; without `multiSort`, Shift changes nothing.
-}
multiSort : Attribute id row msg
multiSort =
    Attribute (\config -> { config | multiSort = True })


{-| Gives every second row a light gray background.
-}
zebra : Attribute id row msg
zebra =
    Attribute (\config -> { config | zebra = True })


{-| The rows scroll inside this height in pixels, under a header that stays in
view. Without it the table is as tall as its rows.
-}
maxHeight : Int -> Attribute id row msg
maxHeight px =
    Attribute (\config -> { config | maxHeight = Just px })


{-| The table fills the height of its parent, which must have a height of its
own, and the rows scroll inside under the header. For the rest of the page under
a heading, put the table in a `Layout.stack [ Layout.fillRest ]` (inside an
`AppShell` that is the height of the window under the top bar).
-}
fillHeight : Attribute id row msg
fillHeight =
    Attribute (\config -> { config | fillHeight = True })


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
emptyState value =
    Attribute (\config -> { config | emptyState = value })
