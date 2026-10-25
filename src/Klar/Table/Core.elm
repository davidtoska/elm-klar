module Klar.Table.Core exposing (..)

{-| The table implementation behind its documented, representation-stable public boundary.
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
import Klar.Table.Csv as Csv
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Sort as Sorting
import Klar.Table.Texts as Texts exposing (Texts)
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
columnId =
    ColumnId


{-| The text a column id was made from, for a backend that sorts or filters by a
name, or for a URL.

    Table.query state |> .sort |> List.map (Tuple.first >> Table.columnName)

-}
columnName : ColumnId -> String
columnName (ColumnId text_) =
    text_


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



-- STATE


{-| What the table remembers: sort, page, page size, search, filters, selection,
expanded rows, hidden columns and density, and which popup and row are open or
focused. Make one with `init`, keep it in your model, change it with `update`
(or the setters in this module) and pass it to `view`.
-}
type State id
    = State Model


type alias Model =
    { id : String
    , sort : List ( String, Direction )
    , page : Int
    , pageSize : Int
    , searchInput : String
    , search : String
    , inputs : Dict String Draft
    , filters : Dict String Filter
    , debounce : Int
    , selection : Picked
    , expanded : Set String
    , visibility : Dict String Bool
    , density : Density
    , popup : Popup
    , optionQuery : String
    , rowMenu : Maybe ( String, Menu.State )
    , activeRow : Int
    , scroll : Float

    -- the row the user last selected or deselected by itself: where a Shift range starts
    , anchor : Maybe String
    }


{-| What the filter inputs show; becomes a `Filter` when it is not empty.
-}
type Draft
    = TextDraft String
    | ChoiceDraft (Set String)
    | RangeDraft String String


type Picked
    = Picked (Set String)
    | AllPicked (Set String)


type Popup
    = NoPopup
    | FilterPopup String
    | ColumnsPopup
    | ExportPopup
    | BulkExportPopup
    | FiltersPopup


{-| A table with nothing sorted, filtered or selected, on page 1 with 25 rows
per page and normal density. The `String` is a DOM id and must be unique on
the page. It is the id of the table's element and the prefix of the ids inside
it (`"orders"` gives `"orders-search"` for the search box, for example).
-}
init : String -> State id
init tableId =
    State
        { id = tableId
        , sort = []
        , page = 1
        , pageSize = 25
        , searchInput = ""
        , search = ""
        , inputs = Dict.empty
        , filters = Dict.empty
        , debounce = 0
        , selection = Picked Set.empty
        , expanded = Set.empty
        , visibility = Dict.empty
        , density = Normal
        , popup = NoPopup
        , optionQuery = ""
        , rowMenu = Nothing
        , activeRow = 0
        , scroll = 0
        , anchor = Nothing
        }



-- ACCESSORS AND SETTERS


{-| The current request as plain data: search text, sort, filters, page and page
size. In server mode, fetch whenever it changed; in client mode you only need it
to save the table's view (see `setQuery`). The search text and the filters are
the ones in effect, so text still waiting for the debounce is not in it.
-}
query : State id -> Query
query (State model) =
    { search = model.search
    , sort = List.map (\( id, direction ) -> ( ColumnId id, direction )) model.sort
    , filters = List.map (\( id, f ) -> ( ColumnId id, f )) (Dict.toList model.filters)
    , page = model.page
    , pageSize = model.pageSize
    }


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
encodeQuery q =
    Encode.object
        [ ( "v", Encode.int 1 )
        , ( "search", Encode.string q.search )
        , ( "sort"
          , Encode.list
                (\( ColumnId id, direction ) ->
                    Encode.object
                        [ ( "column", Encode.string id )
                        , ( "descending", Encode.bool (direction == Descending) )
                        ]
                )
                q.sort
          )
        , ( "filters"
          , Encode.list
                (\( ColumnId id, filter ) ->
                    Encode.object
                        (( "column", Encode.string id )
                            :: (case filter of
                                    Contains words ->
                                        [ ( "contains", Encode.string words ) ]

                                    OneOf choices ->
                                        [ ( "oneOf", Encode.list Encode.string choices ) ]

                                    Between from to ->
                                        [ ( "between", Encode.list (Maybe.map Encode.float >> Maybe.withDefault Encode.null) [ from, to ] ) ]
                               )
                        )
                )
                q.filters
          )
        , ( "page", Encode.int q.page )
        , ( "pageSize", Encode.int q.pageSize )
        ]


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
    Decode.oneOf [ Decode.field "v" Decode.int, Decode.succeed 1 ]
        |> Decode.andThen
            (\version ->
                if version > 1 then
                    Decode.fail ("This query was written by a newer version (v" ++ String.fromInt version ++ ")")

                else
                    Decode.map5 Query
                        (optionalField "search" Decode.string "")
                        (optionalField "sort" (Decode.list sortDecoder |> Decode.map (List.filterMap identity)) [])
                        (optionalField "filters" (Decode.list filterDecoder |> Decode.map (List.filterMap identity)) [])
                        (optionalField "page" Decode.int 1 |> Decode.map (max 1))
                        (optionalField "pageSize" Decode.int 25 |> Decode.map (max 1))
            )


optionalField : String -> Decoder a -> a -> Decoder a
optionalField name decoder fallback =
    Decode.oneOf [ Decode.field name decoder, Decode.succeed fallback ]


sortDecoder : Decoder (Maybe ( ColumnId, Direction ))
sortDecoder =
    Decode.oneOf
        [ Decode.map2
            (\id descending ->
                Just
                    ( ColumnId id
                    , if descending then
                        Descending

                      else
                        Ascending
                    )
            )
            (Decode.field "column" Decode.string)
            (optionalField "descending" Decode.bool False)
        , Decode.succeed Nothing
        ]


filterDecoder : Decoder (Maybe ( ColumnId, Filter ))
filterDecoder =
    Decode.oneOf
        [ Decode.field "column" Decode.string
            |> Decode.andThen
                (\id ->
                    Decode.oneOf
                        [ Decode.field "contains" Decode.string |> Decode.map Contains
                        , Decode.field "oneOf" (Decode.list Decode.string) |> Decode.map OneOf
                        , Decode.field "between" (Decode.list (Decode.nullable Decode.float))
                            |> Decode.andThen
                                (\bounds ->
                                    case bounds of
                                        [ from, to ] ->
                                            Decode.succeed (Between from to)

                                        _ ->
                                            Decode.fail "a range has two bounds"
                                )
                        ]
                        |> Decode.map (\filter -> Just ( ColumnId id, filter ))
                )
        , Decode.succeed Nothing
        ]


{-| Sets the search, sort, filters, page and page size from a query, for example
one restored from the URL or a saved view. The search box and the filter
popovers show the new values; a page or page size below 1 becomes 1. Selected
rows stay selected, but an "all matching" selection (see `Selection`) is dropped
when the search or the filters change.
-}
setQuery : Query -> State id -> State id
setQuery q (State model) =
    State
        (settled model
            { model
                | search = String.trim q.search
                , searchInput = q.search
                , sort = List.map (\( ColumnId id, direction ) -> ( id, direction )) q.sort
                , filters = Dict.fromList (List.map (\( ColumnId id, f ) -> ( id, f )) q.filters)
                , inputs = q.filters |> List.map (\( ColumnId id, f ) -> ( id, toDraft f )) |> Dict.fromList
                , page = max 1 q.page
                , pageSize = max 1 q.pageSize
            }
        )


{-| A search or a filter that changed makes "all matching" mean other rows than
the ones the user chose, so that selection is dropped, as it is when the user
types a new search or filter (`commit`). The rows picked one by one stay.
-}
settled : Model -> Model -> Model
settled before after =
    if before.search /= after.search || Dict.toList before.filters /= Dict.toList after.filters then
        { after | selection = dropAllMatchingOf after.selection }

    else
        after


dropAllMatchingOf : Picked -> Picked
dropAllMatchingOf picked =
    case picked of
        AllPicked _ ->
            Picked Set.empty

        other ->
            other


{-| The columns the table is sorted by, primary first, as column ids with a
direction. Empty when nothing is sorted.
-}
sort : State id -> List ( ColumnId, Direction )
sort (State model) =
    List.map (\( id, direction ) -> ( ColumnId id, direction )) model.sort


{-| Sorts by these columns (ids and directions), primary first, and goes back to
page 1. In client mode, ids that match no column, or a column that is
`unsortable`, are ignored.
-}
setSort : List ( ColumnId, Direction ) -> State id -> State id
setSort value (State model) =
    State { model | sort = List.map (\( ColumnId id, direction ) -> ( id, direction )) value, page = 1 }


{-| The page the user asked for, counted from 1. A page past the last one is
drawn as the last page (the footer says so, and in client mode the rows are those
of the last page), but this keeps returning the number that was asked for.
-}
page : State id -> Int
page (State model) =
    model.page


{-| Goes to this page. The first page is 1; smaller numbers count as 1.
-}
setPage : Int -> State id -> State id
setPage value (State model) =
    State { model | page = max 1 value }


{-| How many rows are on a page: 25 until the user picks another size in the
footer (see `pageSizes`) or you call `setPageSize`.
-}
pageSize : State id -> Int
pageSize (State model) =
    model.pageSize


{-| Sets how many rows are on a page (at least 1) and goes back to page 1. A size
that is not in `pageSizes` is still used and shown in the footer.
-}
setPageSize : Int -> State id -> State id
setPageSize value (State model) =
    State { model | pageSize = max 1 value, page = 1 }


{-| The search text in effect: what the user typed, trimmed, once any
`searchDebounce` has passed. Empty when there is no search.
-}
search : State id -> String
search (State model) =
    model.search


{-| Sets the search text. It shows in the search box, takes effect at once
(without the debounce) and goes back to page 1. A changed search drops an "all
matching" selection (see `Selection`).
-}
setSearch : String -> State id -> State id
setSearch value (State model) =
    State (settled model { model | searchInput = value, search = String.trim value, page = 1 })


{-| The column filters in effect, as column ids with their filter, ordered by
column id. Typed text still waiting for the debounce is not included.
-}
filters : State id -> List ( ColumnId, Filter )
filters (State model) =
    List.map (\( id, f ) -> ( ColumnId id, f )) (Dict.toList model.filters)


{-| Sets (`Just`) or removes (`Nothing`) the filter of the column with this id,
and goes back to page 1. The column's filter popover shows the new value.
-}
setFilter : ColumnId -> Maybe Filter -> State id -> State id
setFilter (ColumnId colId) maybeFilter (State model) =
    case maybeFilter of
        Just f ->
            State (settled model { model | filters = Dict.insert colId f model.filters, inputs = Dict.insert colId (toDraft f) model.inputs, page = 1 })

        Nothing ->
            State (settled model { model | filters = Dict.remove colId model.filters, inputs = Dict.remove colId model.inputs, page = 1 })


{-| Removes the search and every column filter, and goes back to page 1. Filters
that live outside the table (see `rowFilter`) are yours to clear.
-}
clearFilters : State id -> State id
clearFilters (State model) =
    State (settled model { model | filters = Dict.empty, inputs = Dict.empty, search = "", searchInput = "", page = 1 })


{-| The row density: `Compact`, `Normal` (the default) or `Comfortable`, from
[Klar.Theme](Klar-Theme). The user changes it with the buttons of `densityToggle`.
A table whose density was not set (or is `Normal`) follows the density of the
application (`Klar.Settings`); a `Compact` or `Comfortable` table keeps its own.
-}
density : State id -> Density
density (State model) =
    model.density


{-| Sets the row density, for example from a saved preference. It works whether
or not `densityToggle` is shown.
-}
setDensity : Density -> State id -> State id
setDensity value (State model) =
    State { model | density = value }


{-| What is selected, as a `Selection`. In client mode `selectedIds` is enough; in
server mode check this one for `AllMatching`.
-}
selection : Ids id -> State id -> Selection id
selection ids (State model) =
    case model.selection of
        Picked keys ->
            Selected (idsOf ids keys)

        AllPicked except ->
            AllMatching { except = idsOf ids except }


{-| The ids (see `rowId`) of the selected rows. After "Select all N matching" in
server mode this is empty: check `selection` for `AllMatching`.
-}
selectedIds : Ids id -> State id -> List id
selectedIds ids (State model) =
    case model.selection of
        Picked keys ->
            idsOf ids keys

        AllPicked _ ->
            []


{-| How many rows are selected. Pass the number of rows that match the current
query (the `total` you give to `server`). It is only used after "Select all N
matching", where the count is that number minus the exceptions, so in client
mode any number will do.
-}
selectedCount : Int -> State id -> Int
selectedCount matching (State model) =
    case model.selection of
        Picked keys ->
            Set.size keys

        AllPicked except ->
            max 0 (matching - Set.size except)


{-| Is the row with this id selected? After "Select all N matching" every id
counts as selected except the exceptions.
-}
isSelected : Ids id -> id -> State id -> Bool
isSelected ids id (State model) =
    isPicked model.selection (Ids.toKey ids id)


{-| Selects the rows with these ids, as their checkboxes do, and keeps the rest of
the selection. After "Select all N matching" it takes them out of the exceptions.

    Table.select orderIds failedIds model.table

-}
select : Ids id -> List id -> State id -> State id
select ids values (State model) =
    State { model | selection = pick (keysOf ids values) True model.selection }


{-| Deselects the rows with these ids and keeps the rest of the selection, for
example the rows a bulk action has done its work on. After "Select all N
matching" it adds them to the exceptions.
-}
deselect : Ids id -> List id -> State id -> State id
deselect ids values (State model) =
    State { model | selection = pick (keysOf ids values) False model.selection }


{-| Makes the selection exactly these rows, as a whole: to restore a selection, or
to keep only the rows that are still there. It also ends an "all matching"
selection. To deselect everything use `clearSelection`.
-}
setSelectedIds : Ids id -> List id -> State id -> State id
setSelectedIds ids values (State model) =
    State { model | selection = Picked (Set.fromList (keysOf ids values)) }


{-| Deselects everything, including an "all matching" selection. Call it when a
bulk action has done its work.
-}
clearSelection : State id -> State id
clearSelection (State model) =
    State { model | selection = Picked Set.empty }


{-| Drops an "all matching" selection (see `Selection`) and keeps the rows that were
picked one by one. The table does it by itself when its own search or filters change; call
it when something else changes what "all matching" means, such as a filter bar next to
the table.
-}
dropAllMatching : State id -> State id
dropAllMatching (State model) =
    State { model | selection = dropAllMatchingOf model.selection }


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
focus (State model) =
    Internal.focus (scrollDomId model.id) NoOp


{-| The ids (see `rowId`) of the rows that are expanded. Rows only expand when you
give the table an `expandedRow`.
-}
expandedIds : Ids id -> State id -> List id
expandedIds ids (State model) =
    idsOf ids model.expanded


{-| Is the row with this id expanded?
-}
isExpanded : Ids id -> id -> State id -> Bool
isExpanded ids id (State model) =
    Set.member (Ids.toKey ids id) model.expanded


{-| Expands the row with this id, for example to open the first row when the table
appears.

    Table.expand orderIds firstOrder.id model.table

-}
expand : Ids id -> id -> State id -> State id
expand ids id (State model) =
    State { model | expanded = Set.insert (Ids.toKey ids id) model.expanded }


{-| Collapses the row with this id.
-}
collapse : Ids id -> id -> State id -> State id
collapse ids id (State model) =
    State { model | expanded = Set.remove (Ids.toKey ids id) model.expanded }


{-| Toggles the details of a row (`expandedRow`), not its selection: expands the
row with this id when it is collapsed, and collapses it when it is expanded, as its
arrow button does. To toggle a selection use `select` and `deselect`.
-}
toggle : Ids id -> id -> State id -> State id
toggle ids id (State model) =
    State { model | expanded = toggled (Ids.toKey ids id) model.expanded }


{-| Makes these rows, and no others, the expanded ones: to restore the rows that
were open, or to expand every row (`setExpandedIds orderIds (List.map .id orders)`).
To collapse every row use `collapseAll`.
-}
setExpandedIds : Ids id -> List id -> State id -> State id
setExpandedIds ids values (State model) =
    State { model | expanded = Set.fromList (keysOf ids values) }


{-| Collapses every row.
-}
collapseAll : State id -> State id
collapseAll (State model) =
    State { model | expanded = Set.empty }


{-| Whether the user chose to show (`Just True`) or hide (`Just False`) the
column with this id. `Nothing` means no choice yet: the column follows its
default, shown unless it is `hiddenByDefault`. With `setColumnVisible` this lets
you remember the user's column choices.
-}
isColumnVisible : ColumnId -> State id -> Maybe Bool
isColumnVisible (ColumnId colId) (State model) =
    Dict.get colId model.visibility


{-| Records that the column with this id is shown (`True`) or hidden (`False`),
as if the user had ticked it in the column chooser. Columns that are
`alwaysVisible` ignore it, and the table always keeps at least one column on
screen.
-}
setColumnVisible : ColumnId -> Bool -> State id -> State id
setColumnVisible (ColumnId colId) value (State model) =
    State { model | visibility = Dict.insert colId value model.visibility }



-- UPDATE


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
    | PopupOpened Popup (List String)
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
update msg (State model) =
    let
        ( next, cmd ) =
            step msg model
    in
    -- sorting and searching start at the top of a table that scrolls
    if model.scroll > 0 && next.scroll == 0 then
        ( State next, Cmd.batch [ cmd, scrollTo model.id 0 ] )

    else
        ( State next, cmd )


{-| Scrolls the scroll area to this offset, and then focuses the row. In that order:
focus in a row that is out of view makes the browser scroll, and the window of
drawn rows then moves a second time while the row has the focus. The row is drawn
already (the offset is in the model), and when it gets the focus it is in view.
-}
scrollThenFocus : String -> Float -> String -> Cmd Msg
scrollThenFocus tableId top rowDomIdValue =
    Dom.getViewportOf (scrollDomId tableId)
        |> Task.andThen (\viewport -> Dom.setViewportOf (scrollDomId tableId) viewport.viewport.x top)
        |> Task.andThen (\_ -> Dom.focus rowDomIdValue |> Task.onError (\_ -> Dom.focus (scrollDomId tableId)))
        |> Task.attempt (\_ -> NoOp)


{-| Scrolls the table's scroll area to this offset from the top, keeping its
horizontal position.
-}
scrollTo : String -> Float -> Cmd Msg
scrollTo tableId top =
    Dom.getViewportOf (scrollDomId tableId)
        |> Task.andThen (\viewport -> Dom.setViewportOf (scrollDomId tableId) viewport.viewport.x top)
        |> Task.attempt (\_ -> NoOp)


step : Msg -> Model -> ( Model, Cmd Msg )
step msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        SortClicked colId multi ->
            ( { model | sort = nextSort multi colId model.sort, page = 1, activeRow = 0, scroll = 0 }, Cmd.none )

        PageChanged n ->
            ( { model | page = max 1 n, activeRow = 0, scroll = 0, rowMenu = Nothing }, Cmd.none )

        PageSizeChanged size ->
            let
                newSize =
                    max 1 size

                firstIndex =
                    (max 1 model.page - 1) * model.pageSize
            in
            ( { model | pageSize = newSize, page = firstIndex // newSize + 1, activeRow = 0, scroll = 0 }, Cmd.none )

        SearchChanged value delay ->
            schedule delay { model | searchInput = value }

        FilterTextChanged colId value delay ->
            schedule delay { model | inputs = Dict.insert colId (TextDraft value) model.inputs }

        FilterRangeChanged colId isFrom value delay ->
            let
                ( from, to ) =
                    case Dict.get colId model.inputs of
                        Just (RangeDraft a b) ->
                            ( a, b )

                        _ ->
                            ( "", "" )

                next =
                    if isFrom then
                        RangeDraft value to

                    else
                        RangeDraft from value
            in
            schedule delay { model | inputs = Dict.insert colId next model.inputs }

        FilterChoiceToggled colId value checked ->
            let
                current =
                    choicesOf colId model.inputs

                next =
                    if checked then
                        Set.insert value current

                    else
                        Set.remove value current
            in
            ( commit { model | inputs = Dict.insert colId (ChoiceDraft next) model.inputs }, Cmd.none )

        FilterChoicesSet colId values ->
            -- "Select all" and "Clear" disable themselves: focus moves into the list
            ( commit { model | inputs = Dict.insert colId (ChoiceDraft (Set.fromList values)) model.inputs }
            , focusFirst [ filterInputId model.id colId "search", filterInputId model.id colId "option-0" ]
            )

        OptionQueryChanged value ->
            ( { model | optionQuery = value }, Cmd.none )

        FilterCleared colId ->
            afterClear (Just colId) model (commit { model | inputs = Dict.remove colId model.inputs })

        FiltersCleared ->
            afterClear Nothing model (commit { model | inputs = Dict.empty })

        AllCleared ->
            afterClear Nothing model (commit { model | inputs = Dict.empty, searchInput = "" })

        Debounced n ->
            if n == model.debounce then
                ( commit model, Cmd.none )

            else
                ( model, Cmd.none )

        PopupOpened popup focusIds ->
            ( { model | popup = popup, optionQuery = "" }
            , focusFirst (focusIds ++ [ popupDomId model.id popup ])
            )

        PopupClosed ->
            ( { model | popup = NoPopup }
            , if model.popup == NoPopup then
                Cmd.none

              else
                Internal.focus (triggerDomId model.id model.popup) NoOp
            )

        PopupLeft ->
            ( { model | popup = NoPopup }, Cmd.none )

        RowMenu key menuId fallback menuMsg ->
            let
                current =
                    case model.rowMenu of
                        Just ( openKey, menu ) ->
                            if openKey == key then
                                menu

                            else
                                Menu.init menuId

                        Nothing ->
                            Menu.init menuId

                ( next, cmd ) =
                    Menu.update menuMsg current

                closed =
                    Menu.isOpen current && not (Menu.isOpen next)
            in
            ( { model
                | rowMenu =
                    if Menu.isOpen next then
                        Just ( key, next )

                    else
                        Nothing
              }
            , Cmd.batch
                [ Cmd.map (RowMenu key menuId fallback) cmd

                -- The menu gives focus back to its button. When the action
                -- removed the row (a delete, a status that no longer matches
                -- the filter) the button is gone: the row that took its place,
                -- or the table, gets focus instead of the page.
                , if closed then
                    focusFirst fallback

                  else
                    Cmd.none
                ]
            )

        RowMenuOpened key menuId fallback ->
            -- Shift+F10 or the menu key on a row: the same as its "more" button
            let
                ( opened, cmd ) =
                    Menu.open (Menu.init menuId)
            in
            ( { model | rowMenu = Just ( key, opened ) }
            , Cmd.map (RowMenu key menuId fallback) cmd
            )

        RowSelected key checked ->
            ( { model | selection = pick [ key ] checked model.selection, anchor = Just key }, Cmd.none )

        RangeSelected keys checked target ->
            -- Shift: the rows from the anchor to this one get the state of this one
            ( { model | selection = pick keys checked model.selection, anchor = Just target }, Cmd.none )

        RowsSelected keys checked ->
            ( { model | selection = pick keys checked model.selection }, Cmd.none )

        MatchingSelected keys ->
            -- "Select all N matching" is replaced by a note: focus goes to the bar
            ( { model | selection = pick keys True model.selection }, Internal.focus (bulkDomId model.id) NoOp )

        AllMatchingPicked ->
            ( { model | selection = AllPicked Set.empty }, Internal.focus (bulkDomId model.id) NoOp )

        SelectionCleared focusId ->
            ( { model | selection = Picked Set.empty }, Internal.focus focusId NoOp )

        ExpandToggled key ->
            ( { model | expanded = toggled key model.expanded }, Cmd.none )

        DensityChanged value ->
            ( { model | density = value }, Cmd.none )

        ColumnToggled colId visible ->
            ( { model | visibility = Dict.insert colId visible model.visibility }, Cmd.none )

        ColumnsReset ->
            ( { model | visibility = Dict.empty }, Cmd.none )

        RowFocused index ->
            if index == model.activeRow then
                ( model, Cmd.none )

            else
                ( { model | activeRow = index }, Cmd.none )

        FocusRow index domId ->
            ( { model | activeRow = index }, Internal.focus domId NoOp )

        FocusVirtualRow index domId geometry ->
            -- the row may not be drawn yet: scroll first, so that it is when focus arrives
            let
                top =
                    Window.scrollToRow geometry model.scroll index
            in
            ( { model | activeRow = index, scroll = top }
            , scrollThenFocus model.id top domId
            )

        Scrolled top ->
            ( { model | scroll = max 0 top }, Cmd.none )

        RetryClicked ->
            -- "Try again" is replaced by skeleton rows while the answer is on
            -- its way: focus waits on the table instead of falling to the page
            ( model, Internal.focus (scrollDomId model.id) NoOp )

        FirstPageClicked ->
            -- the same for "Go to the first page" in the empty page: rows replace it
            ( { model | page = 1, activeRow = 0, scroll = 0, rowMenu = Nothing }, Internal.focus (scrollDomId model.id) NoOp )

        ExportClicked filename csv ->
            -- a byte order mark first, so that Excel reads æ, ø and å as UTF-8
            ( { model | popup = NoPopup }
            , Cmd.batch
                [ Download.string filename "text/csv;charset=utf-8" ("\u{FEFF}" ++ csv)
                , if model.popup == NoPopup then
                    Cmd.none

                  else
                    Internal.focus (triggerDomId model.id model.popup) NoOp
                ]
            )


{-| Where focus goes after a filter was removed. The control that removed it
is often gone or disabled now (a chip, "Reset", the reset button next to
"N filters active", the empty state), and without a new target focus would
fall back to the page, where Escape no longer closes anything. A summary
popover with no filters left is closed, so it does not open by itself with
the next filter.
-}
afterClear : Maybe String -> Model -> Model -> ( Model, Cmd Msg )
afterClear removed before after =
    let
        -- Every target takes focus when it is there: the search box, "N filters
        -- active", the filter button in the header of a column whose filter was
        -- removed, and last the scroll area, which can take focus whenever the
        -- table has a filter button. A row is not on the list: it cannot take
        -- focus unless the rows are interactive, and focus would fall to the page.
        clearedColumns =
            Maybe.withDefault [] (Maybe.map List.singleton removed)
                ++ List.map Tuple.first (activeDrafts before)

        outside =
            [ after.id ++ "-search", triggerDomId after.id FiltersPopup ]
                ++ List.map (\colId -> triggerDomId after.id (FilterPopup colId)) clearedColumns
                ++ [ scrollDomId after.id ]

        lastChip =
            activeDrafts before |> List.reverse |> List.head |> Maybe.map Tuple.first
    in
    case after.popup of
        FilterPopup colId ->
            ( after
            , focusFirst
                ([ "text", "from", "search", "option-0" ]
                    |> List.map (filterInputId after.id colId)
                    |> (\inputs -> inputs ++ [ popupDomId after.id after.popup ])
                )
            )

        FiltersPopup ->
            if List.isEmpty (activeDrafts after) then
                ( { after | popup = NoPopup }, focusFirst (triggerDomId after.id FiltersPopup :: outside) )

            else if removed == Nothing || removed == lastChip then
                -- the chips after a removed one move up and keep the focus; the last has nothing after it
                ( after, focusFirst [ popupDomId after.id FiltersPopup ] )

            else
                ( after, Cmd.none )

        _ ->
            ( after, focusFirst outside )


{-| Focus the first of these elements that exists.
-}
focusFirst : List String -> Cmd Msg
focusFirst ids =
    ids
        |> List.foldr (\domId fallback -> Dom.focus domId |> Task.onError (\_ -> fallback)) (Task.succeed ())
        |> Task.attempt (\_ -> NoOp)


{-| Plain click: sort by this column only, cycling ascending, descending,
unsorted. Shift-click (multi-sort): add the column, or cycle it in place.
-}
nextSort : Bool -> String -> List ( String, Direction ) -> List ( String, Direction )
nextSort multi colId current =
    let
        existing =
            lookup colId current

        cycled =
            case existing of
                Nothing ->
                    Just Ascending

                Just Ascending ->
                    Just Descending

                Just Descending ->
                    Nothing
    in
    if multi then
        case ( existing, cycled ) of
            ( Nothing, Just direction ) ->
                current ++ [ ( colId, direction ) ]

            ( Just _, Just direction ) ->
                List.map
                    (\( other, d ) ->
                        if other == colId then
                            ( other, direction )

                        else
                            ( other, d )
                    )
                    current

            ( _, Nothing ) ->
                List.filter (\( other, _ ) -> other /= colId) current

    else if List.length current == 1 && existing /= Nothing then
        case cycled of
            Just direction ->
                [ ( colId, direction ) ]

            Nothing ->
                []

    else
        [ ( colId, Ascending ) ]


{-| Typing is committed at once (`delay` 0) or after a pause; a newer key
press makes older timers stale.
-}
schedule : Int -> Model -> ( Model, Cmd Msg )
schedule delay model =
    if delay <= 0 then
        ( commit model, Cmd.none )

    else
        let
            n =
                model.debounce + 1
        in
        ( { model | debounce = n }
        , Process.sleep (toFloat delay) |> Task.perform (\_ -> Debounced n)
        )


{-| Turns the inputs into the search and filters in effect. A changed search
or filter goes back to page 1, and "all matching" no longer means the same
rows, so that selection is dropped.
-}
commit : Model -> Model
commit model =
    let
        newFilters =
            model.inputs
                |> Dict.toList
                |> List.filterMap (\( colId, draft ) -> Maybe.map (Tuple.pair colId) (toFilter draft))
                |> Dict.fromList

        newSearch =
            String.trim model.searchInput

        changed =
            Dict.toList newFilters /= Dict.toList model.filters || newSearch /= model.search
    in
    if changed then
        { model
            | filters = newFilters
            , search = newSearch
            , page = 1
            , activeRow = 0
            , scroll = 0
            , selection = dropAllMatchingOf model.selection
        }

    else
        model


pick : List String -> Bool -> Picked -> Picked
pick keys checked picked =
    case picked of
        Picked set ->
            Picked
                (if checked then
                    List.foldl Set.insert set keys

                 else
                    List.foldl Set.remove set keys
                )

        AllPicked except ->
            AllPicked
                (if checked then
                    List.foldl Set.remove except keys

                 else
                    List.foldl Set.insert except keys
                )


isPicked : Picked -> String -> Bool
isPicked picked key =
    case picked of
        Picked set ->
            Set.member key set

        AllPicked except ->
            not (Set.member key except)


toFilter : Draft -> Maybe Filter
toFilter draft =
    case draft of
        TextDraft value ->
            if String.isEmpty (String.trim value) then
                Nothing

            else
                Just (Contains (String.trim value))

        ChoiceDraft values ->
            if Set.isEmpty values then
                Nothing

            else
                Just (OneOf (Set.toList values))

        RangeDraft from to ->
            case ( parseNumber from, parseNumber to ) of
                ( Nothing, Nothing ) ->
                    Nothing

                ( Just low, Just high ) ->
                    -- "80 to 20" means 20 to 80 (as in Rule.matches), not "nothing"
                    Just (Between (Just (min low high)) (Just (max low high)))

                ( low, high ) ->
                    Just (Between low high)


toDraft : Filter -> Draft
toDraft f =
    case f of
        Contains value ->
            TextDraft value

        OneOf values ->
            ChoiceDraft (Set.fromList values)

        Between low high ->
            RangeDraft
                (Maybe.map String.fromFloat low |> Maybe.withDefault "")
                (Maybe.map String.fromFloat high |> Maybe.withDefault "")


choicesOf : String -> Dict String Draft -> Set String
choicesOf colId inputs =
    case Dict.get colId inputs of
        Just (ChoiceDraft values) ->
            values

        _ ->
            Set.empty


{-| "12,5", "12.5", "1 234", "−3" (Unicode minus) are numbers.
-}
parseNumber : String -> Maybe Float
parseNumber raw =
    let
        cleaned =
            raw
                |> String.trim
                |> String.replace "−" "-"
                |> String.filter (\c -> c /= ' ' && c /= '\u{00A0}')
                |> String.replace "," "."
    in
    if String.isEmpty cleaned then
        Nothing

    else
        String.toFloat cleaned
            |> Maybe.andThen
                (\n ->
                    if isNaN n || isInfinite n then
                        Nothing

                    else
                        Just n
                )


{-| A yes / no column offers "Yes" / "No" in English and "Ja" / "Nei" in
Norwegian. A filter keeps the value it was set with, which would stop matching
when the language changes, so choices of such a column are kept in one form that
belongs to no language (`"true"` and `"false"`) and shown in the language of the
moment. Other columns are left as they are.
-}
canonicalChoice : ColumnConfig row msg -> String -> String
canonicalChoice col value =
    if col.boolean then
        if value == (Texts.texts Locale.en).yes || value == (Texts.texts Locale.nb).yes then
            "true"

        else if value == (Texts.texts Locale.en).no || value == (Texts.texts Locale.nb).no then
            "false"

        else
            value

    else
        value


{-| The choice as the column says it in this language.
-}
localChoice : Locale -> ColumnConfig row msg -> String -> String
localChoice loc col value =
    if col.boolean then
        if value == "true" then
            (Texts.texts loc).yes

        else if value == "false" then
            (Texts.texts loc).no

        else
            value

    else
        value


{-| The value a select filter keeps for a row: its `filterValue`, or the text of
the column (`"true"` or `"false"` for a yes / no column).
-}
choiceOf : Locale -> ColumnConfig row msg -> row -> String
choiceOf loc col row =
    case col.filterValue of
        Just toValue ->
            toValue row

        Nothing ->
            canonicalChoice col (col.value loc row)


{-| How a select filter shows the values it keeps: the label of `filterOptions`,
"Yes" and "No" for a yes / no column, and for a column with a `filterValue` the
text of a row with that value. A value that nothing names is shown as it is.
-}
choiceLabels : Locale -> ColumnConfig row msg -> List row -> String -> String
choiceLabels loc col someRows =
    let
        given =
            Maybe.withDefault [] col.filterOptions
                |> List.map (\option -> ( option.value, option.label ))
                |> Dict.fromList

        found =
            case col.filterValue of
                Just toValue ->
                    List.foldl
                        (\row dict ->
                            let
                                value =
                                    toValue row
                            in
                            if Dict.member value dict then
                                dict

                            else
                                Dict.insert value (col.value loc row) dict
                        )
                        Dict.empty
                        someRows

                Nothing ->
                    Dict.empty
    in
    \value ->
        case Dict.get value given of
            Just label_ ->
                label_

            Nothing ->
                case Dict.get value found of
                    Just label_ ->
                        label_

                    Nothing ->
                        localChoice loc col value


{-| Does a row pass a column filter?
-}
filterTest : Locale -> ColumnConfig row msg -> Filter -> (row -> Bool)
filterTest loc col f =
    case f of
        Contains needle ->
            let
                wanted =
                    Search.normalize (String.trim needle)
            in
            \row -> String.contains wanted (fold (col.value loc row))

        OneOf values ->
            let
                allowed =
                    Set.fromList (List.map (canonicalChoice col) values)
            in
            \row -> Set.member (choiceOf loc col row) allowed

        Between low high ->
            case col.number of
                Just toNumber ->
                    \row ->
                        case toNumber row of
                            Just n ->
                                withinRange low high n

                            Nothing ->
                                False

                Nothing ->
                    always True


withinRange : Maybe Float -> Maybe Float -> Float -> Bool
withinRange low high n =
    let
        -- a range restored with its ends the wrong way round is the same range, as
        -- when the two numbers are typed into the filter
        ( from, to ) =
            case ( low, high ) of
                ( Just a, Just b ) ->
                    if a > b then
                        ( high, low )

                    else
                        ( low, high )

                _ ->
                    ( low, high )
    in
    (case from of
        Just bound ->
            n >= bound

        Nothing ->
            True
    )
        && (case to of
                Just bound ->
                    n <= bound

                Nothing ->
                    True
           )


searchWords : String -> List String
searchWords value =
    value
        |> Search.normalize
        |> String.words
        |> List.filter (\word -> word /= "")


{-| Every word of the search must be found in one of the searched columns
(case and accents ignored).
-}
searchTest : Locale -> List (ColumnConfig row msg) -> String -> Maybe (row -> Bool)
searchTest loc searched value =
    case searchWords value of
        [] ->
            Nothing

        words ->
            Just (\row -> List.all (\word -> String.contains word (searchText loc searched row)) words)


{-| The text of a row that the search looks in: the values of the searched
columns, one on each line, in lower case and without accents.
-}
searchText : Locale -> List (ColumnConfig row msg) -> row -> String
searchText loc searched row =
    searched
        |> List.map (\col -> col.value loc row)
        |> String.join "\n"
        |> String.replace "\u{00A0}" " "
        |> fold


{-| The same as `Search.normalize` (lower case, accents folded), but the slow
character-by-character fold only runs when the text has accented letters (the
letters from U+00C0 to U+00FF).
-}
fold : String -> String
fold value =
    let
        lower =
            String.toLower value
    in
    if Internal.hasLatinLetters lower then
        Search.normalize lower

    else
        lower



-- COLUMNS


{-| One column of the table. Make it with `text`, `int`, `float`, `date`,
`maybeDate`, `badge`, `status`, `bool`, `custom` or `actions`, and give a list of
them to `columns`.
-}
type Column row msg
    = Column (ColumnConfig row msg)


{-| A setting of one column. Make them with the functions below and pass a list
as the last argument of `text`, `int` and the other column helpers; later
attributes win over earlier ones.
-}
type ColumnAttribute row msg
    = ColumnAttribute (ColumnConfig row msg -> ColumnConfig row msg)


type alias ColumnConfig row msg =
    { id : String
    , title : String
    , value : Locale -> row -> String
    , cell : Maybe (Locale -> row -> Html msg)
    , sortBy : SortBy row
    , number : Maybe (row -> Maybe Float)
    , decimals : Int
    , export : Maybe (Locale -> row -> String)
    , align : Align
    , width : Maybe Int
    , minWidth : Int
    , pinned : Bool
    , hiddenByDefault : Bool
    , hideable : Bool
    , wrap : Bool
    , tooltip : Bool
    , searchable : Bool
    , exported : Bool
    , filter : Maybe FilterKind
    , filterOptions : Maybe (List { value : String, label : String })
    , filterValue : Maybe (row -> String)
    , footer : Maybe (Footer row)
    , hint : Maybe String
    , controls : Bool
    , numeric : Bool
    , boolean : Bool

    -- a money column: its footers add the amounts exactly, per currency
    , money : Maybe (row -> Money)
    }


type SortBy row
    = SortByValue
    | SortByText (row -> String)
    | SortByNumber (row -> Maybe Float)
    | SortByComparator (row -> row -> Order)
    | NotSortable


type Align
    = AlignLeft
    | AlignRight
    | AlignCenter


type FilterKind
    = TextFilter
    | SelectFilter
    | RangeFilter


type Footer row
    = FooterSum
    | FooterAverage
    | FooterCustom (List row -> String)


baseColumn : String -> String -> (Locale -> row -> String) -> ColumnConfig row msg
baseColumn colId title value =
    { id = colId
    , title = title
    , value = value
    , cell = Nothing
    , sortBy = SortByValue
    , number = Nothing
    , decimals = 0
    , export = Nothing
    , align = AlignLeft
    , width = Nothing
    , minWidth = 120
    , pinned = False
    , hiddenByDefault = False
    , hideable = True
    , wrap = False
    , tooltip = True
    , searchable = True
    , exported = True
    , filter = Nothing
    , filterOptions = Nothing
    , filterValue = Nothing
    , footer = Nothing
    , hint = Nothing
    , controls = False
    , numeric = False
    , boolean = False
    , money = Nothing
    }


build : ColumnConfig row msg -> List (ColumnAttribute row msg) -> Column row msg
build base attributes =
    Column (List.foldl (\(ColumnAttribute change) config -> change config) base attributes)


{-| A text column: `Table.text (Table.columnId "customer") "Customer" .customer []` takes the
column id (unique in the table), the title for the header and a function that
reads the text from a row.

The text is searched, sorted alphabetically (in the order of the table's
`locale`), exported to CSV and highlighted where it matches the search. A long
text is cut with an ellipsis and a tooltip, a blank one is shown as a dash and
sorts last, and the column is at least 120 pixels wide (see `minWidth`).

-}
text : ColumnId -> String -> (row -> String) -> List (ColumnAttribute row msg) -> Column row msg
text (ColumnId colId) title toText attributes =
    build (baseColumn colId title (\_ row -> toText row)) attributes


{-| A whole number: `Table.int (Table.columnId "items") "Items" .items []`. It is right-aligned
with tabular digits and thousands separators (`1,234` in English), sorted
numerically, exported as a plain number and 104 pixels wide (see `width`). It
supports `filterRange`, `footerSum` and `footerAverage`, and the search box
skips it unless you add `includeInSearch`.
-}
int : ColumnId -> String -> (row -> Int) -> List (ColumnAttribute row msg) -> Column row msg
int (ColumnId colId) title toInt attributes =
    let
        base =
            baseColumn colId title (\loc row -> Format.int loc (toInt row))

        toNumber row =
            Just (toFloat (toInt row))
    in
    build
        { base
            | sortBy = SortByNumber toNumber
            , number = Just toNumber
            , export = Just (\_ row -> String.fromInt (toInt row))
            , align = AlignRight
            , width = Just 104
            , searchable = False
            , numeric = True
            , tooltip = False
        }
        attributes


{-| A decimal number with a fixed count of decimals:
`Table.float (Table.columnId "weight") "Weight (kg)" 1 .weight []`. The `Int` is the number of
decimals shown (also in filter hints and footers). It is like `int` otherwise,
but 112 pixels wide, and the CSV export keeps the decimals with the locale's
decimal separator and no thousands separator, so a spreadsheet reads a number.
-}
float : ColumnId -> String -> Int -> (row -> Float) -> List (ColumnAttribute row msg) -> Column row msg
float (ColumnId colId) title decimals toNumber attributes =
    let
        base =
            baseColumn colId title (\loc row -> Format.decimal loc decimals (toNumber row))
    in
    build
        { base
            | sortBy = SortByNumber (toNumber >> Just)
            , number = Just (toNumber >> Just)
            , decimals = decimals
            , export = Just (\loc row -> plainDecimal loc decimals (toNumber row))
            , align = AlignRight
            , width = Just 112
            , searchable = False
            , numeric = True
            , tooltip = False
        }
        attributes


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
money (ColumnId colId) title toMoney attributes =
    let
        base =
            baseColumn colId title (\loc row -> Money.toString loc (toMoney row))

        amount row =
            Just (majorAmount (toMoney row))
    in
    build
        { base
            | sortBy = SortByNumber amount
            , number = Just amount
            , decimals = 2
            , money = Just toMoney
            , export = Just (\loc row -> String.replace "." (Locale.decimalSeparator loc) (Money.toDecimalString (toMoney row)))
            , align = AlignRight
            , width = Just 136
            , searchable = False
            , numeric = True
            , tooltip = False
        }
        attributes


{-| The decimals the numbers of the range filter of this column are shown with:
those of the currency of a money column (none for yen, three for dinars), read
from its first row, else the column's own.
-}
rangeDecimals : Ctx row msg -> ColumnConfig row msg -> Int
rangeDecimals ctx col =
    let
        firstRow =
            case ctx.config.rows of
                Remote.Loaded (FromList list) ->
                    List.head list

                Remote.Loaded (FromRows (Rows prep)) ->
                    Array.get 0 prep.array

                _ ->
                    Nothing
    in
    case ( col.money, firstRow ) of
        ( Just toMoney, Just row ) ->
            Money.decimals (Money.currencyOf (toMoney row))

        _ ->
            col.decimals


{-| An amount in whole units of its currency (12.5 for 12,50 kroner), for sorting
and the range filter.
-}
majorAmount : Money -> Float
majorAmount amount =
    toFloat (Money.toMinor amount) / toFloat (10 ^ Money.decimals (Money.currencyOf amount))


{-| The amounts of one currency in a money column added up exactly, with how many
there are. A total beyond the range of `Money` is `Nothing`.
-}
type alias MoneyTotal =
    { total : Maybe Money
    , count : Int
    }


{-| The amounts of a money column added up exactly, one total for each currency in
the order of the currency codes (so that sorting or filtering the rows never moves
them), with the number of amounts in each.
-}
moneyTotals : (row -> Money) -> List row -> List MoneyTotal
moneyTotals toMoney someRows =
    let
        add row groups =
            let
                amount =
                    toMoney row

                code =
                    Money.currencyCode (Money.currencyOf amount)
            in
            case Dict.get code groups of
                Just group ->
                    Dict.insert code
                        { total = group.total |> Maybe.andThen (\running -> Result.toMaybe (Money.add running amount))
                        , count = group.count + 1
                        }
                        groups

                Nothing ->
                    Dict.insert code { total = Just amount, count = 1 } groups
    in
    List.foldl add Dict.empty someRows
        |> Dict.values


{-| A calendar date ([Klar.Date](Klar-Date)), sorted by date and shown as
`2026-10-20` in English or `20.10.2026` in Norwegian. For a date that may be
missing use `maybeDate`.

    Table.date (Table.columnId "shipped") "Shipped" .shippedOn []

-}
date : ColumnId -> String -> (row -> Date) -> List (ColumnAttribute row msg) -> Column row msg
date (ColumnId colId) title toDate attributes =
    maybeDate (ColumnId colId) title (toDate >> Just) attributes


{-| Like `date`, for a date that may be missing: `Nothing` is shown as a dash
and sorts last, whichever way the column is sorted.
-}
maybeDate : ColumnId -> String -> (row -> Maybe Date) -> List (ColumnAttribute row msg) -> Column row msg
maybeDate (ColumnId colId) title toDate attributes =
    let
        base =
            baseColumn colId title (\loc row -> toDate row |> Maybe.map (Format.date loc) |> Maybe.withDefault "")
    in
    build
        { base
            | sortBy = SortByNumber (\row -> toDate row |> Maybe.map (Date.toEpochDay >> toFloat))
            , width = Just 112
            , numeric = True
            , tooltip = False
        }
        attributes


{-| A tone ([Klar.Theme](Klar-Theme)) and a label, shown as a
[Klar.Badge](Klar-Badge). The label is the text used for search, sorting, export
and `filterSelect`; the column is 124 pixels wide.

    Table.badge (Table.columnId "status")
        "Status"
        (\order -> ( statusTone order.status, statusLabel order.status ))
        [ Table.filterSelect ]

-}
badge : ColumnId -> String -> (row -> ( Tone, String )) -> List (ColumnAttribute row msg) -> Column row msg
badge (ColumnId colId) title toBadge attributes =
    let
        base =
            baseColumn colId title (\_ row -> Tuple.second (toBadge row))
    in
    build
        { base
            | cell =
                Just
                    (\_ row ->
                        let
                            ( tone, labelText ) =
                                toBadge row
                        in
                        Badge.view [ Badge.tone tone ] labelText
                    )
            , width = Just 124
            , tooltip = False
        }
        attributes


{-| Like `badge`, but drawn as a colored dot and text (`Badge.status` in
[Klar.Badge](Klar-Badge)), which is quieter in dense tables.
-}
status : ColumnId -> String -> (row -> ( Tone, String )) -> List (ColumnAttribute row msg) -> Column row msg
status (ColumnId colId) title toStatus attributes =
    let
        base =
            baseColumn colId title (\_ row -> Tuple.second (toStatus row))
    in
    build
        { base
            | cell =
                Just
                    (\_ row ->
                        let
                            ( tone, labelText ) =
                                toStatus row
                        in
                        Badge.status tone labelText
                    )
            , width = Just 124
            , tooltip = False
        }
        attributes


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
bool (ColumnId colId) title toBool attributes =
    let
        yesNo loc row =
            if toBool row then
                (Texts.texts loc).yes

            else
                (Texts.texts loc).no

        base =
            baseColumn colId title yesNo
    in
    build
        { base
            | cell =
                Just
                    (\loc row ->
                        if toBool row then
                            Html.span [ Internal.cls [ "klar-table__bool", "klar-table__bool--yes" ] ]
                                [ Icon.sized Icon.Small Icon.check
                                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (Texts.texts loc).yes ]
                                ]

                        else
                            Html.span [ Internal.cls [ "klar-table__bool", "klar-table__bool--no" ] ]
                                [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ]
                                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (Texts.texts loc).no ]
                                ]
                    )
            , align = AlignCenter
            , width = Just 88
            , tooltip = False
            , boolean = True
        }
        attributes


{-| A column with your own HTML and no text: `render` draws the cell. Without
text the column is not searched, sorted or exported; turn sorting back on with
`sortText`, `sortNumber`, `sortMaybeNumber`, `sortDate` or `sortWith`, and export
with `exportAs`. For a custom look with a text behind it, use `text` with `cell`
instead.

    Table.custom (Table.columnId "progress") "Progress" viewProgress [ Table.sortNumber .progress ]

-}
custom : ColumnId -> String -> (row -> Html msg) -> List (ColumnAttribute row msg) -> Column row msg
custom (ColumnId colId) title render attributes =
    let
        base =
            baseColumn colId title (\_ _ -> "")
    in
    build
        { base
            | cell = Just (\_ row -> render row)
            , sortBy = NotSortable
            , searchable = False
            , exported = False
            , tooltip = False
        }
        attributes


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
actions (ColumnId colId) title render attributes =
    let
        base =
            baseColumn colId title (\_ _ -> "")
    in
    build
        { base
            | cell = Just (\_ row -> Html.div [ Internal.cls [ "klar-table__controls" ] ] (render row))
            , sortBy = NotSortable
            , searchable = False
            , exported = False
            , tooltip = False
            , controls = True
            , align = AlignRight
            , width = Just 96
        }
        attributes



-- COLUMN ATTRIBUTES


{-| A fixed width in pixels (at least 24). Columns without a width share the
space that is left. A fixed column is never narrower than its header needs, so
the title is not cut.
-}
width : Int -> ColumnAttribute row msg
width px =
    ColumnAttribute (\config -> { config | width = Just (max 24 px) })


{-| The column shares the remaining space but never gets narrower than this many
pixels (at least 24); the table scrolls sideways instead. The default is 120.
It also replaces a fixed width, such as the one `int`, `date` and `badge`
columns start with.
-}
minWidth : Int -> ColumnAttribute row msg
minWidth px =
    ColumnAttribute (\config -> { config | width = Nothing, minWidth = max 24 px })


{-| Aligns the header and the cells of the column to the right, as numbers
should be. Columns start left-aligned, except `int`, `float` and `actions`,
which are right-aligned.
-}
alignRight : ColumnAttribute row msg
alignRight =
    ColumnAttribute (\config -> { config | align = AlignRight })


{-| Centers the header and the cells of the column. A `bool` column starts
centered.
-}
alignCenter : ColumnAttribute row msg
alignCenter =
    ColumnAttribute (\config -> { config | align = AlignCenter })


{-| Keeps the column in view while the table scrolls sideways. Only the first
visible column can be pinned (on any other column this does nothing); the
selection and expand columns, if there are any, stay with it.
-}
pinned : ColumnAttribute row msg
pinned =
    ColumnAttribute (\config -> { config | pinned = True })


{-| The column starts hidden. The user can show it in the column chooser (see
`columnChooser`), and you can with `setColumnVisible`.
-}
hiddenByDefault : ColumnAttribute row msg
hiddenByDefault =
    ColumnAttribute (\config -> { config | hiddenByDefault = True })


{-| The user cannot hide the column: its checkbox in the column chooser is
disabled. It also cancels `hiddenByDefault`.
-}
alwaysVisible : ColumnAttribute row msg
alwaysVisible =
    ColumnAttribute (\config -> { config | hideable = False, hiddenByDefault = False })


{-| Long values wrap onto more lines instead of being cut, so the row grows. There
is no tooltip then, as the whole value is visible.
-}
wrap : ColumnAttribute row msg
wrap =
    ColumnAttribute (\config -> { config | wrap = True, tooltip = False })


{-| Turns off the tooltip (the `title` attribute) that shows the full value of a
cell whose text is cut off.
-}
noTooltip : ColumnAttribute row msg
noTooltip =
    ColumnAttribute (\config -> { config | tooltip = False })


{-| Draws the cell yourself. The text accessor of the column is still used for
search, sorting, export and filters, but a match is no longer highlighted in the
cell, and there is no tooltip.

    Table.text (Table.columnId "customer") "Customer" .customer [ Table.cell viewCustomerLink ]

-}
cell : (row -> Html msg) -> ColumnAttribute row msg
cell render =
    ColumnAttribute (\config -> { config | cell = Just (\_ row -> render row), tooltip = False })


{-| A short explanation of the column, shown as a tooltip on the header. It
replaces the default tooltip ("Click to sort").
-}
hint : String -> ColumnAttribute row msg
hint value =
    ColumnAttribute (\config -> { config | hint = Just value })


{-| Sorts alphabetically (in the order of the table's `locale`) by another text
than the one shown.
-}
sortText : (row -> String) -> ColumnAttribute row msg
sortText toText =
    ColumnAttribute (\config -> { config | sortBy = SortByText toText })


{-| Sorts by a number instead of the text. The number also makes `filterRange`,
`footerSum` and `footerAverage` work on a column that shows text.
-}
sortNumber : (row -> Float) -> ColumnAttribute row msg
sortNumber toNumber =
    sortMaybeNumber (toNumber >> Just)


{-| Like `sortNumber`, for a number that may be missing: rows with `Nothing` go
last, whichever way the column is sorted.
-}
sortMaybeNumber : (row -> Maybe Float) -> ColumnAttribute row msg
sortMaybeNumber toNumber =
    ColumnAttribute (\config -> { config | sortBy = SortByNumber toNumber, number = Just toNumber })


{-| Sorts by a date instead of the text, for example when the column shows a
date in your own format.

    Table.text (Table.columnId "due") "Due" .dueText [ Table.sortDate .dueDate ]

-}
sortDate : (row -> Date) -> ColumnAttribute row msg
sortDate toDate =
    ColumnAttribute (\config -> { config | sortBy = SortByNumber (\row -> Just (toFloat (Date.toEpochDay (toDate row)))) })


{-| Sorts with your own comparison, written for the ascending order; the table
reverses it for `Descending`. Rows that compare equal keep their order.

    Table.text (Table.columnId "size") "Size" .sizeLabel [ Table.sortWith (\a b -> compare a.sizeRank b.sizeRank) ]

-}
sortWith : (row -> row -> Order) -> ColumnAttribute row msg
sortWith comparator =
    ColumnAttribute (\config -> { config | sortBy = SortByComparator comparator })


{-| Turns sorting off for the column: its header is a plain title instead of a
button.
-}
unsortable : ColumnAttribute row msg
unsortable =
    ColumnAttribute (\config -> { config | sortBy = NotSortable })


{-| The search box skips this column.
-}
notSearchable : ColumnAttribute row msg
notSearchable =
    ColumnAttribute (\config -> { config | searchable = False })


{-| The search box looks in this column. Text, date, badge, status and yes / no
columns are searched by default; number columns are not (searching "42" rarely
means an item count). Only visible columns are searched.
-}
includeInSearch : ColumnAttribute row msg
includeInSearch =
    ColumnAttribute (\config -> { config | searchable = True })


{-| The value written to the CSV export, when it should differ from the text
shown. It also puts a column in the export that would be left out otherwise,
such as a `custom` column.
-}
exportAs : (row -> String) -> ColumnAttribute row msg
exportAs toText =
    ColumnAttribute (\config -> { config | export = Just (\_ row -> toText row), exported = True })


{-| Leaves the column out of the CSV export (see `exportCsv`).
-}
notExported : ColumnAttribute row msg
notExported =
    ColumnAttribute (\config -> { config | exported = False })


{-| Adds a "contains" text filter to the column: a filter button in the header
opens a popover with an input. Case and accents are ignored.
-}
filterText : ColumnAttribute row msg
filterText =
    ColumnAttribute (\config -> { config | filter = Just TextFilter })


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
    ColumnAttribute (\config -> { config | filter = Just SelectFilter })


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
filterOptions options =
    ColumnAttribute (\config -> { config | filter = Just SelectFilter, filterOptions = Just options })


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
filterValue toValue =
    ColumnAttribute (\config -> { config | filterValue = Just toValue })


{-| Adds a from / to number filter to the column; either bound can be left
empty. It needs a number column (`int`, `float`) or `sortNumber`; on a column
without numbers there is no filter button.
-}
filterRange : ColumnAttribute row msg
filterRange =
    ColumnAttribute (\config -> { config | filter = Just RangeFilter })


{-| A footer value computed from the rows: all rows that match the search and
filters in client mode, the current page in server mode. The footer row shows
when any visible column has a footer value and there are rows.

    Table.int (Table.columnId "items") "Items" .items [ Table.footer (\orders -> String.fromInt (List.length orders) ++ " orders") ]

-}
footer : (List row -> String) -> ColumnAttribute row msg
footer summarize =
    ColumnAttribute (\config -> { config | footer = Just (FooterCustom summarize) })


{-| The sum of a number column in the footer, as in "Sum 12,345". It adds up the
same rows as `footer`.
-}
footerSum : ColumnAttribute row msg
footerSum =
    ColumnAttribute (\config -> { config | footer = Just FooterSum })


{-| The average of a number column in the footer, as in "Avg 51.2". It is written
with the decimals of the column (one at least, so an average of whole numbers is
not rounded to a whole number): cents stay cents in a money column. It averages
the same rows as `footer`; a dash is shown when there is nothing to average.
-}
footerAverage : ColumnAttribute row msg
footerAverage =
    ColumnAttribute (\config -> { config | footer = Just FooterAverage })



-- TABLE ATTRIBUTES


{-| A setting of the table as a whole (`columns`, `remote`, `searchable` ...). Make
them with the functions below and pass a list to `view`; later attributes win
over earlier ones.
-}
type Attribute id row msg
    = Attribute (Config row msg -> Config row msg)


type alias Config row msg =
    { columns : List (Column row msg)
    , rows : Remote (Source row)
    , rowId : Maybe (row -> String)
    , rowLabel : Maybe (row -> String)
    , server : Maybe Int
    , label : Maybe String
    , locale : Locale
    , settings : Settings
    , searchable : Bool
    , searchPlaceholder : Maybe String
    , searchDebounce : Maybe Int
    , rowFilter : Maybe (row -> Bool)
    , externalFilters : Int
    , onResetFilters : Maybe msg
    , selectable : Bool
    , bulkActions : List (Html msg)
    , rowActions : Maybe (row -> List (Menu.Item msg))
    , onRowClick : Maybe (row -> msg)
    , expandedRow : Maybe (row -> Html msg)
    , rowTone : Maybe (row -> Maybe Tone)
    , rowDisabled : Maybe (row -> Bool)
    , currentRow : Maybe (row -> Bool)
    , toolbarActions : List (Html msg)
    , onRefresh : Maybe msg
    , refreshing : Bool
    , freshness : Freshness
    , onRetry : Maybe msg
    , export : Maybe String
    , csvSeparator : Maybe Char
    , columnChooser : Bool
    , densityToggle : Bool
    , pageSizes : List Int
    , rangeText : Maybe (Int -> Int -> Int -> String)
    , paged : Bool
    , virtual : Bool
    , multiSort : Bool
    , zebra : Bool
    , maxHeight : Maybe Int
    , fillHeight : Bool
    , emptyState : List (EmptyState.Attribute msg)
    }


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
        , moneyTotals : Dict String (List MoneyTotal)
        }


type Source row
    = FromList (List row)
    | FromRows (Rows row)


{-| Prepares the rows for a table with these columns in this locale (the `Locale`
you give to `locale`). Take the same columns you give to `columns`. Every sortable
column is sorted once here, so this takes about as long as sorting by each column
would, a few hundred milliseconds for 50 000 rows. A table given the result reads
a sort by one column from it and does not sort again; a sort by several columns
(`multiSort`) and a `sortWith` column are still sorted on every message.
-}
prepareRows : Locale -> List (Column row msg) -> Array row -> Rows row
prepareRows loc givenColumns array =
    let
        allColumns =
            List.map (\(Column col) -> col) givenColumns

        searched =
            (case init "" of
                State model ->
                    visibleColumns model allColumns
            )
                |> List.filter .searchable
    in
    Rows
        { array = array
        , locale = loc
        , columnIds = List.map .id allColumns
        , searchIds = List.map .id searched
        , index =
            Index.build array
                { search =
                    if List.isEmpty searched then
                        Nothing

                    else
                        Just (searchText loc searched)
                , sorts = List.filterMap (\col -> sortKeyOf loc col |> Maybe.map (Tuple.pair col.id)) allColumns
                , totals =
                    List.filterMap
                        (\col ->
                            -- a money column adds its amounts exactly in the footer instead
                            case ( col.footer, col.number, col.money ) of
                                ( Just FooterSum, Just toNumber, Nothing ) ->
                                    Just ( col.id, toNumber )

                                ( Just FooterAverage, Just toNumber, Nothing ) ->
                                    Just ( col.id, toNumber )

                                _ ->
                                    Nothing
                        )
                        allColumns
                }
        , moneyTotals =
            List.filterMap
                (\col ->
                    case ( col.footer, col.money ) of
                        ( Just FooterSum, Just toMoney ) ->
                            Just ( col.id, moneyTotals toMoney (Array.toList array) )

                        ( Just FooterAverage, Just toMoney ) ->
                            Just ( col.id, moneyTotals toMoney (Array.toList array) )

                        _ ->
                            Nothing
                )
                allColumns
                |> Dict.fromList
        }


{-| The rows of prepared rows, to give to other parts of the page that want an
`Array` too, such as [Klar.VirtualList](Klar-VirtualList). It costs nothing.
-}
rowsArray : Rows row -> Array row
rowsArray (Rows prep) =
    prep.array


sourceList : Source row -> List row
sourceList source =
    case source of
        FromList list ->
            list

        FromRows (Rows prep) ->
            Array.toList prep.array


sourceArray : Source row -> Array row
sourceArray source =
    case source of
        FromList list ->
            Array.fromList list

        FromRows (Rows prep) ->
            prep.array


{-| The prepared rows, if they were made for this locale and these columns.
-}
usablePrepared : Locale -> List (ColumnConfig row msg) -> Source row -> Maybe (Rows row)
usablePrepared loc allColumns source =
    case source of
        FromRows ((Rows prep) as prepared) ->
            if prep.locale == loc && prep.columnIds == List.map .id allColumns then
                Just prepared

            else
                Nothing

        FromList _ ->
            Nothing


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



-- PROCESSING


type alias Data row =
    { status : DataStatus
    , pageRows : List row
    , pageAll : List row
    , first : Int
    , rowCount : Int
    , matchingRows : () -> List row

    -- How many matching rows pass a test that gets the place of the row among the
    -- matching rows and the row itself: a count that never builds the list of rows.
    , countMatching : (Int -> row -> Bool) -> Int
    , totals : String -> Maybe Index.Totals

    -- the exact totals of a money column, kept by prepared rows while no row is left out
    , moneyTotals : String -> Maybe (List MoneyTotal)
    , total : Int
    , available : Int
    , page : Int
    , pageCount : Int
    , offset : Int
    }


type DataStatus
    = Waiting
    | Failed Problem
    | Ready


{-| What to show: in client mode the rows after outside filter, column
filters, search and sort, and the slice for the current page.
-}
process : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Data row
process config model allColumns visible =
    let
        nothing =
            { status = Waiting
            , pageRows = []
            , pageAll = []
            , first = 0
            , rowCount = 0
            , matchingRows = \_ -> []
            , countMatching = \_ -> 0
            , totals = \_ -> Nothing
            , moneyTotals = \_ -> Nothing
            , total = Maybe.withDefault 0 config.server
            , available = Maybe.withDefault 0 config.server
            , page = max 1 model.page
            , pageCount = 1
            , offset = 0
            }
    in
    case config.rows of
        Remote.Loaded source ->
            case config.server of
                Just total ->
                    let
                        ( current, count, offset ) =
                            pageWindow config model total

                        allRows =
                            sourceList source

                        rowTotal =
                            List.length allRows

                        shown =
                            if config.virtual then
                                Window.window virtualWindow (virtualGeometry config model rowTotal) model.scroll

                            else
                                { first = 0, end = rowTotal, before = 0, after = 0 }
                    in
                    { status = Ready
                    , pageRows =
                        if config.virtual then
                            allRows |> List.drop shown.first |> List.take (shown.end - shown.first)

                        else
                            allRows
                    , pageAll = allRows
                    , first = shown.first
                    , rowCount = rowTotal
                    , matchingRows = \_ -> allRows
                    , countMatching = \test -> List.length (List.filter (\( index, row ) -> test index row) (List.indexedMap Tuple.pair allRows))
                    , totals = \_ -> Nothing
                    , moneyTotals = \_ -> Nothing
                    , total = total
                    , available = total
                    , page = current
                    , pageCount = count
                    , offset = offset
                    }

                Nothing ->
                    processClient config model allColumns visible source

        Remote.Failed problem ->
            { nothing | status = Failed problem }

        _ ->
            nothing


{-| Client mode: finds the matching rows as positions in the array of rows (see
`Klar.Table.Index`), and takes the rows of the current page from them. With
prepared rows the search texts and the sorted orders are there already.
-}
processClient : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Source row -> Data row
processClient config model allColumns visible source =
    let
        loc =
            config.locale

        array =
            sourceArray source

        rowAt position =
            Array.get position array

        onPosition test position =
            case rowAt position of
                Just row ->
                    test row

                Nothing ->
                    False

        prepared =
            usablePrepared loc allColumns source

        searched =
            List.filter .searchable visible

        words =
            searchWords model.search

        indexedSearch =
            case prepared of
                Just (Rows prep) ->
                    prep.searchIds == List.map .id searched

                Nothing ->
                    False

        searchFallback =
            if indexedSearch then
                []

            else
                searchTest loc searched model.search |> Maybe.map (onPosition >> List.singleton) |> Maybe.withDefault []

        columnTests =
            model.filters
                |> Dict.toList
                |> List.filterMap (\( colId, f ) -> findColumn colId allColumns |> Maybe.map (\col -> onPosition (filterTest loc col f)))

        tests =
            List.concat
                [ searchFallback
                , config.rowFilter |> Maybe.map (onPosition >> List.singleton) |> Maybe.withDefault []
                , columnTests
                ]

        matches =
            Index.matching
                (Maybe.map (\(Rows prep) -> prep.index) prepared)
                { count = Array.length array
                , words =
                    if indexedSearch then
                        words

                    else
                        []
                , tests = tests
                , levels = sortLevels loc prepared rowAt model.sort allColumns
                }

        total =
            Index.matchCount matches

        ( current, count, offset ) =
            pageWindow config model total

        rowsOf positions =
            List.filterMap rowAt positions

        shown =
            Window.window virtualWindow (virtualGeometry config model total) model.scroll

        pageRows =
            if config.virtual then
                rowsOf (Index.pageIndices shown.first (shown.end - shown.first) matches)

            else if config.paged then
                rowsOf (Index.pageIndices offset (max 1 model.pageSize) matches)

            else
                rowsOf (Index.allIndices matches)
    in
    { status = Ready
    , pageRows = pageRows
    , pageAll =
        if config.virtual then
            []

        else
            pageRows
    , first =
        if config.virtual then
            shown.first

        else
            0
    , rowCount =
        if config.virtual then
            total

        else
            List.length pageRows
    , matchingRows = \_ -> rowsOf (Index.allIndices matches)
    , countMatching =
        \test ->
            Index.countMatching
                (\place position ->
                    case rowAt position of
                        Just row ->
                            test place row

                        Nothing ->
                            False
                )
                matches
    , totals =
        case prepared of
            Just (Rows prep) ->
                -- read from the numbers kept per position: no row is turned into a number again
                \id -> Index.totalsOver id matches prep.index

            Nothing ->
                \_ -> Nothing
    , moneyTotals =
        case prepared of
            Just (Rows prep) ->
                if total == Array.length array then
                    -- every row matched: the totals worked out once by prepareRows
                    \id -> Dict.get id prep.moneyTotals

                else
                    \_ -> Nothing

            Nothing ->
                \_ -> Nothing
    , total = total
    , available = Array.length array
    , page = current
    , pageCount = count
    , offset = offset
    }


{-| The levels of the sort, for `Index.matching`. A single level on a column that
the prepared rows have the order of is read from the index; the others are
worked out from the rows.
-}
sortLevels :
    Locale
    -> Maybe (Rows row)
    -> (Int -> Maybe row)
    -> List ( String, Direction )
    -> List (ColumnConfig row msg)
    -> List Index.Level
sortLevels loc prepared rowAt levels allColumns =
    let
        chosen =
            levels
                |> List.filterMap
                    (\( colId, direction ) ->
                        findColumn colId allColumns
                            |> Maybe.andThen
                                (\col ->
                                    if isSortable col then
                                        Just ( col, direction == Descending )

                                    else
                                        Nothing
                                )
                    )

        computed ( col, descending ) =
            case col.sortBy of
                SortByComparator comparator ->
                    Index.Compared descending
                        (\a b ->
                            case ( rowAt a, rowAt b ) of
                                ( Just rowA, Just rowB ) ->
                                    comparator rowA rowB

                                _ ->
                                    EQ
                        )

                _ ->
                    Index.Keyed descending
                        (\position ->
                            case ( rowAt position, sortKeyOf loc col ) of
                                ( Just row, Just toKey ) ->
                                    toKey row

                                _ ->
                                    Sorting.Missing
                        )
    in
    case ( chosen, prepared ) of
        ( [ ( col, descending ) ], Just (Rows prep) ) ->
            if Index.hasRanks col.id prep.index then
                [ Index.Ranked col.id descending ]

            else
                [ computed ( col, descending ) ]

        _ ->
            List.map computed chosen


{-| The rows of a table that scrolls are one height, the one of its density
(`--klar-row-compact`, `--klar-row` and `--klar-row-comfortable`).
-}
rowPx : Density -> Int
rowPx spacing =
    case spacing of
        Compact ->
            28

        Normal ->
            36

        Comfortable ->
            46


{-| The sticky header (`--_head-h`).
-}
headPx : Density -> Int
headPx spacing =
    case spacing of
        Compact ->
            28

        _ ->
            36


{-| How many rows are drawn beyond the ones in view, above and below, and in how
many rows at a time the drawn rows change (each chunk is a `tbody` of its own,
so that scrolling a few rows moves none of them and the keyboard focus stays).
-}
virtualWindow : { overscan : Int, chunk : Int }
virtualWindow =
    { overscan = 4, chunk = 16 }


{-| The height of a table that scrolls without `maxHeight`.
-}
defaultVirtualHeight : Int
defaultVirtualHeight =
    480


{-| What the window arithmetic needs for this table: the room the rows are seen in
is the scroll area less the header.
-}
virtualGeometry : Config row msg -> Model -> Int -> Window.Geometry
virtualGeometry config model count =
    let
        -- the totals row stays in view at the bottom and covers a row's room (a sum that
        -- does not fit on one line takes a second line, so it is a little taller)
        footPx =
            if List.any (\(Column col) -> hasFooter col) config.columns then
                rowPx model.density + 4

            else
                0

        area =
            case config.maxHeight of
                Just px ->
                    px

                Nothing ->
                    if config.fillHeight then
                        1000

                    else
                        defaultVirtualHeight
    in
    { rowHeight = rowPx model.density
    , viewport = max (rowPx model.density) (area - headPx model.density - footPx)
    , count = count
    }


pageWindow : Config row msg -> Model -> Int -> ( Int, Int, Int )
pageWindow config model total =
    if config.paged then
        let
            size =
                max 1 model.pageSize

            count =
                Pagination.pageCount size total

            current =
                clamp 1 count model.page
        in
        ( current, count, (current - 1) * size )

    else
        ( 1, 1, 0 )


{-| Applies the outside filter, the column filters (except `excluded`, used
for the counts in a filter popover) and the search.
-}
keepMatching : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Maybe String -> List row -> List row
keepMatching config model allColumns visible excluded allRows =
    let
        loc =
            config.locale

        columnTests =
            model.filters
                |> Dict.toList
                |> List.filter (\( colId, _ ) -> Just colId /= excluded)
                |> List.filterMap (\( colId, f ) -> findColumn colId allColumns |> Maybe.map (\col -> filterTest loc col f))

        tests =
            List.concat
                [ config.rowFilter |> Maybe.map List.singleton |> Maybe.withDefault []
                , columnTests
                , searchTest loc (List.filter .searchable visible) model.search |> Maybe.map List.singleton |> Maybe.withDefault []
                ]
    in
    case tests of
        [] ->
            allRows

        _ ->
            List.filter (\row -> List.all (\test -> test row) tests) allRows


sortRows : Config row msg -> Model -> List (ColumnConfig row msg) -> List row -> List row
sortRows config model allColumns allRows =
    case List.filterMap (\( colId, direction ) -> findColumn colId allColumns |> Maybe.andThen (sortLevel config.locale direction)) model.sort of
        [] ->
            allRows

        levels ->
            Sorting.sort levels allRows


sortLevel : Locale -> Direction -> ColumnConfig row msg -> Maybe (Sorting.Level row)
sortLevel loc direction col =
    let
        descending =
            direction == Descending
    in
    case col.sortBy of
        SortByComparator comparator ->
            Just (Sorting.ByComparator descending comparator)

        _ ->
            sortKeyOf loc col |> Maybe.map (Sorting.ByKey descending)


{-| The sort key of a row in this column, for the columns that sort by a key.
-}
sortKeyOf : Locale -> ColumnConfig row msg -> Maybe (row -> Sorting.Key)
sortKeyOf loc col =
    case col.sortBy of
        SortByValue ->
            Just (\row -> Sorting.textKey loc (col.value loc row))

        SortByText toText ->
            Just (\row -> Sorting.textKey loc (toText row))

        SortByNumber toNumber ->
            Just (\row -> Sorting.numberKey (toNumber row))

        SortByComparator _ ->
            Nothing

        NotSortable ->
            Nothing


isSortable : ColumnConfig row msg -> Bool
isSortable col =
    case col.sortBy of
        NotSortable ->
            False

        _ ->
            True


hasFooter : ColumnConfig row msg -> Bool
hasFooter col =
    case col.footer of
        Just _ ->
            True

        Nothing ->
            False


findColumn : String -> List (ColumnConfig row msg) -> Maybe (ColumnConfig row msg)
findColumn colId allColumns =
    case allColumns of
        [] ->
            Nothing

        col :: rest ->
            if col.id == colId then
                Just col

            else
                findColumn colId rest


visibleColumns : Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg)
visibleColumns model allColumns =
    case List.filter (isShown model) allColumns of
        [] ->
            List.take 1 allColumns

        shown ->
            shown


isShown : Model -> ColumnConfig row msg -> Bool
isShown model col =
    if col.hideable then
        Dict.get col.id model.visibility |> Maybe.withDefault (not col.hiddenByDefault)

    else
        True


activeDrafts : Model -> List ( String, Draft )
activeDrafts model =
    model.inputs
        |> Dict.toList
        |> List.filter (\( _, draft ) -> toFilter draft /= Nothing)


exportValue : Locale -> ColumnConfig row msg -> row -> String
exportValue loc col row =
    case col.export of
        Just toText ->
            toText loc row

        Nothing ->
            col.value loc row


{-| A number with the locale's decimal separator and no thousands separator,
which spreadsheets read as a number.
-}
plainDecimal : Locale -> Int -> Float -> String
plainDecimal loc decimals n =
    Format.decimal loc decimals n
        |> String.replace (Locale.thousandSeparator loc) ""
        |> String.replace "−" "-"



-- VIEW


type alias Ctx row msg =
    { toMsg : Msg -> msg
    , config : Config row msg
    , model : Model
    , t : Texts
    , loc : Locale
    , allColumns : List (ColumnConfig row msg)
    , visible : List (ColumnConfig row msg)
    , data : Data row
    , keyOf : Int -> row -> String
    , labelOf : row -> String
    , delay : Int
    , hasSelect : Bool
    , hasExpand : Bool
    , hasMenu : Bool
    , pinnedFirst : Bool
    , colCount : Int
    , interactiveRows : Bool
    , activeRow : Int
    , rowCount : Int
    , pageKeys : List String
    , geometry : Window.Geometry
    }


selectWidth : Int
selectWidth =
    40


expandWidth : Int
expandWidth =
    36


menuWidth : Int
menuWidth =
    48


{-| Draws the table: toolbar, header, rows, totals row and pagination. `toMsg`
wraps the table's own messages, usually the constructor you handle in `update`.
The attributes describe the table (columns, rows, options) and are given on every
call; the `State` only holds what the user changed.

    Table.view TableMsg [ Table.columns columns, Table.remote model.orders ] model.table

-}
view : (Msg -> msg) -> List (Attribute id row msg) -> State id -> Html msg
view toMsg attributes (State model) =
    let
        config =
            configure attributes

        allColumns =
            List.map (\(Column col) -> col) config.columns

        visible =
            visibleColumns model allColumns

        data =
            process config model allColumns visible

        loc =
            config.locale

        keyOf index row =
            case config.rowId of
                Just toId ->
                    toId row

                Nothing ->
                    String.fromInt index

        labelOf row =
            case config.rowLabel of
                Just toLabel ->
                    toLabel row

                Nothing ->
                    case visible of
                        first :: _ ->
                            first.value loc row

                        [] ->
                            ""

        -- Selection and open rows are kept by row id. Without `rowId` they would
        -- be kept by position and follow the place, not the row, after a sort or
        -- a filter (and a bulk action would act on other rows), so the table
        -- draws no checkboxes and no details at all: the mistake shows at once.
        hasSelect =
            config.selectable && isJust config.rowId

        hasExpand =
            isJust config.expandedRow && isJust config.rowId

        hasMenu =
            isJust config.rowActions

        rowCount =
            data.rowCount

        isDisabled row =
            case config.rowDisabled of
                Just test ->
                    test row

                Nothing ->
                    False

        pageKeys =
            data.pageAll
                |> List.indexedMap (\i row -> ( keyOf (data.offset + i) row, isDisabled row ))
                |> List.filter (\( _, disabled ) -> not disabled)
                |> List.map Tuple.first

        ctx =
            { toMsg = toMsg
            , config = config
            , model = model
            , t = Texts.texts loc
            , loc = loc
            , allColumns = allColumns
            , visible = visible
            , data = data
            , keyOf = keyOf
            , labelOf = labelOf
            , delay =
                case config.searchDebounce of
                    Just ms ->
                        ms

                    Nothing ->
                        if config.server /= Nothing then
                            350

                        else
                            0
            , hasSelect = hasSelect
            , hasExpand = hasExpand
            , hasMenu = hasMenu
            , pinnedFirst =
                case visible of
                    first :: _ ->
                        first.pinned

                    [] ->
                        False
            , colCount =
                List.length visible
                    + (if hasSelect then
                        1

                       else
                        0
                      )
                    + (if hasExpand then
                        1

                       else
                        0
                      )
                    + (if hasMenu then
                        1

                       else
                        0
                      )
            , interactiveRows = isJust config.onRowClick || hasSelect || hasExpand || hasMenu
            , activeRow =
                if model.activeRow < rowCount then
                    model.activeRow

                else
                    0
            , rowCount = rowCount
            , pageKeys = pageKeys
            , geometry = virtualGeometry config model rowCount
            }
    in
    Html.div
        [ Internal.cls
            [ "klar-table"
            , "klar-table--" ++ Internal.densitySuffix model.density
            , if config.zebra then
                "klar-table--zebra"

              else
                ""
            , if config.refreshing && data.status == Ready then
                "klar-table--refreshing"

              else
                ""
            , if config.fillHeight then
                "klar-table--fill"

              else
                ""
            , if ctx.pinnedFirst then
                "klar-table--pinned"

              else
                ""
            , if config.virtual then
                "klar-table--virtual"

              else
                ""
            ]
        , Attr.id model.id
        , Internal.attrIf config.virtual (Internal.styleVars [ ( "--_row-h", Internal.px ctx.geometry.rowHeight ) ])
        ]
        [ viewToolbar ctx
        , case config.freshness of
            Freshness.Stale _ ->
                -- the retry button goes away when the data is fresh: focus waits on the table
                Html.div [ Events.on "click" (retryClicked ctx) ]
                    [ Freshness.notice
                        { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                        config.freshness
                    ]

            _ ->
                Html.text ""
        , viewFrame ctx
        , viewFooter ctx
        , Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status", Attr.attribute "aria-live" "polite" ]
            [ Html.text (liveSummary ctx) ]

        -- "3 selected" when the selection changes; always there, so that the first
        -- selection is announced too, and empty when nothing is selected
        , Internal.viewIf hasSelect
            (Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "aria-live" "polite", Attr.id (model.id ++ "-selection-status") ]
                [ Html.text
                    (if selectionTotal ctx > 0 then
                        ctx.t.selected (selectionTotal ctx)

                     else
                        ""
                    )
                ]
            )
        ]


liveSummary : Ctx row msg -> String
liveSummary ctx =
    case ctx.data.status of
        Waiting ->
            ctx.t.loading

        Failed _ ->
            ""

        Ready ->
            if ctx.config.refreshing then
                ctx.t.refreshing

            else
                let
                    ( first, last ) =
                        if ctx.config.paged then
                            Pagination.range { page = ctx.data.page, pageSize = ctx.model.pageSize, total = ctx.data.total }

                        else
                            ( min 1 ctx.data.total, ctx.data.total )

                    counted =
                        if ctx.data.total == 0 then
                            ctx.t.noRows

                        else
                            ctx.t.summary first last ctx.data.total

                    sorted =
                        case ctx.model.sort of
                            ( colId, direction ) :: _ ->
                                case findColumn colId ctx.allColumns of
                                    Just col ->
                                        " " ++ ctx.t.sortedBy col.title (direction == Descending)

                                    Nothing ->
                                        ""

                            [] ->
                                ""
                in
                counted ++ sorted



-- TOOLBAR


{-| Is there anything for the toolbar to hold? Column filters live in the
header, so a table with only those has no toolbar until a filter is active
(then "2 filters active" and its reset are shown here). A selectable table keeps
its band so the rows do not jump down when the first one is selected.
-}
hasToolbar : Ctx row msg -> Bool
hasToolbar ctx =
    hasTools ctx || ctx.hasSelect || activeFilterCount ctx > 0


{-| Search, refresh, density, columns, export or the application's own buttons.
-}
hasTools : Ctx row msg -> Bool
hasTools ctx =
    let
        config =
            ctx.config
    in
    config.searchable
        || config.columnChooser
        || config.densityToggle
        || config.export
        /= Nothing
        || isJust config.onRefresh
        || not (List.isEmpty config.toolbarActions)


{-| Filters in effect: the table's own and the application's.
-}
activeFilterCount : Ctx row msg -> Int
activeFilterCount ctx =
    List.length (activeDrafts ctx.model)


selectionTotal : Ctx row msg -> Int
selectionTotal ctx =
    case ctx.model.selection of
        Picked keys ->
            Set.size keys

        AllPicked except ->
            max 0 (ctx.data.total - Set.size except)


viewToolbar : Ctx row msg -> Html msg
viewToolbar ctx =
    if not (hasToolbar ctx) then
        Html.text ""

    else
        let
            config =
                ctx.config

            bulk =
                ctx.hasSelect && selectionTotal ctx > 0

            activeCount =
                activeFilterCount ctx
        in
        Html.div [ Internal.cls [ "klar-table__toolbar" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-table__tools"
                    , if bulk then
                        "klar-table__tools--covered"

                      else
                        ""
                    ]
                ]
                [ if config.searchable then
                    viewSearch ctx

                  else
                    Html.text ""
                , if activeCount > 0 then
                    viewFilterSummary ctx activeCount

                  else
                    Html.text ""
                , -- the band is only there for the bulk bar: say what it is for
                  if ctx.hasSelect && not (hasTools ctx) && activeCount == 0 then
                    Html.span [ Internal.cls [ "klar-table__tools-note" ] ] [ Html.text ctx.t.noneSelected ]

                  else
                    Html.text ""
                , Html.div [ Internal.cls [ "klar-table__tools-end" ] ]
                    [ Internal.viewMaybe
                        (\msg ->
                            Button.iconOnly
                                [ Button.ghost
                                , Button.loading (config.refreshing || ctx.data.status == Waiting)
                                , Button.onClick msg
                                ]
                                Icon.refresh
                                ctx.t.refresh
                        )
                        config.onRefresh
                    , Internal.viewIf config.densityToggle (viewDensity ctx)
                    , Internal.viewIf config.columnChooser (viewColumnsMenu ctx)
                    , Internal.viewMaybe (viewExportMenu ctx ExportPopup) config.export
                    , Internal.viewIf (not (List.isEmpty config.toolbarActions))
                        (Html.div [ Internal.cls [ "klar-table__app-actions" ] ] config.toolbarActions)
                    ]
                ]
            , if bulk then
                viewBulkBar ctx

              else
                Html.text ""
            ]


viewSearch : Ctx row msg -> Html msg
viewSearch ctx =
    Html.div
        [ Internal.cls [ "klar-table__search" ]

        -- Escape clears the text and is used up: its default is prevented, so a
        -- dialog or drawer that reads defaultPrevented (keys are layered) leaves
        -- it alone; in an empty box it is left to the dialog.
        , Internal.attrIf (ctx.model.searchInput /= "")
            (Internal.onKeys [ ( "Escape", ctx.toMsg (SearchChanged "" 0) ) ])
        ]
        [ TextInput.view
            [ TextInput.id (ctx.model.id ++ "-search")
            , TextInput.label ctx.t.searchLabel
            , TextInput.labelHidden
            , TextInput.search
            , TextInput.clearable
            , TextInput.locale ctx.loc
            , TextInput.placeholder
                (case ctx.config.searchPlaceholder of
                    Just value ->
                        value

                    Nothing ->
                        if ctx.config.server == Nothing then
                            ctx.t.searchPlaceholder ctx.data.available

                        else
                            ctx.t.searchPlaceholder 0
                )
            , TextInput.value ctx.model.searchInput
            , TextInput.onInput (\value -> ctx.toMsg (SearchChanged value ctx.delay))
            ]
        ]


{-| "2 filters active" (opens the list of active filters) and "Reset filters".
-}
viewFilterSummary : Ctx row msg -> Int -> Html msg
viewFilterSummary ctx activeCount =
    let
        isOpen =
            ctx.model.popup == FiltersPopup

        drafts =
            activeDrafts ctx.model
    in
    Html.div [ Internal.cls [ "klar-table__filter-summary" ] ]
        [ Html.div [ Internal.cls [ "klar-anchor" ] ]
            [ Button.view
                [ Button.small
                , Button.icon Icon.filter
                , Button.id (triggerDomId ctx.model.id FiltersPopup)
                , Button.expanded isOpen
                , Button.htmlAttrs [ Attr.attribute "aria-haspopup" "dialog" ]
                , Button.onClick (ctx.toMsg (PopupOpened FiltersPopup []))
                ]
                (ctx.t.filtersActive activeCount)
            , if isOpen then
                viewPopup ctx
                    FiltersPopup
                    { title = ctx.t.activeFilters, alignEnd = False }
                    [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                        [ Html.ul [ Internal.cls [ "klar-table__chips" ] ]
                            (drafts
                                |> List.filterMap
                                    (\( colId, draft ) ->
                                        findColumn colId ctx.allColumns
                                            |> Maybe.map
                                                (\col ->
                                                    Html.li []
                                                        [ Tag.view
                                                            [ Tag.tone Theme.Primary
                                                            , Tag.locale ctx.loc
                                                            , Tag.onRemove (ctx.toMsg (FilterCleared colId))
                                                            ]
                                                            (describeDraft ctx col draft)
                                                        ]
                                                )
                                    )
                            )
                        ]
                    , Html.div [ Internal.cls [ "klar-table__popover-foot" ] ]
                        [ resetFiltersButton ctx [ Button.small, Button.ghost ] ctx.t.resetFilters FiltersCleared
                        , Button.view [ Button.small, Button.onClick (ctx.toMsg PopupClosed) ] ctx.t.done
                        ]
                    ]

              else
                Html.text ""
            ]
        , withAppReset ctx
            (Button.iconOnly
                [ Button.small
                , Button.ghost
                , Button.onClick (ctx.toMsg FiltersCleared)
                ]
                Icon.close
                ctx.t.resetFilters
            )
        ]


{-| A button that clears what its label says ("Reset filters": the column
filters; "Clear search and filters": the search too) and, in the same click,
sends the application's `onResetFilters`.
-}
resetFiltersButton : Ctx row msg -> List (Button.Attribute msg) -> String -> Msg -> Html msg
resetFiltersButton ctx buttonAttributes labelText resetMsg =
    withAppReset ctx (Button.view (buttonAttributes ++ [ Button.onClick (ctx.toMsg resetMsg) ]) labelText)


{-| The click on the button inside bubbles to this wrapper, which sends the
application's `onResetFilters` too.
-}
withAppReset : Ctx row msg -> Html msg -> Html msg
withAppReset ctx button =
    Html.span
        [ Internal.cls [ "klar-table__reset" ]
        , Internal.attrMaybe Events.onClick ctx.config.onResetFilters
        ]
        [ button ]


describeDraft : Ctx row msg -> ColumnConfig row msg -> Draft -> String
describeDraft ctx col draft =
    case draft of
        TextDraft value ->
            ctx.t.describeContains col.title (String.trim value)

        ChoiceDraft values ->
            let
                labelOf =
                    case col.filterValue of
                        Just _ ->
                            choiceLabels ctx.loc col (loadedRows ctx)

                        Nothing ->
                            choiceLabels ctx.loc col []

                list =
                    values |> Set.toList |> List.map (canonicalChoice col >> labelOf)

                shown =
                    List.take 3 list

                more =
                    List.length list - List.length shown
            in
            col.title
                ++ ": "
                ++ String.join ", " shown
                ++ (if more > 0 then
                        " +" ++ String.fromInt more

                    else
                        ""
                   )

        RangeDraft from to ->
            let
                show =
                    formatNumber ctx.loc (rangeDecimals ctx col)
            in
            col.title
                ++ ": "
                ++ (case ( parseNumber from, parseNumber to ) of
                        ( Just low, Just high ) ->
                            show (min low high) ++ "–" ++ show (max low high)

                        ( Just low, Nothing ) ->
                            "≥ " ++ show low

                        ( Nothing, Just high ) ->
                            "≤ " ++ show high

                        ( Nothing, Nothing ) ->
                            ""
                   )


formatNumber : Locale -> Int -> Float -> String
formatNumber loc decimals n =
    if decimals <= 0 && toFloat (round n) == n then
        Format.int loc (round n)

    else
        Format.decimal loc (max 1 decimals) n


densityCompact : Icon.Icon
densityCompact =
    Icon.fromSvg "table-density-compact" "<line x1='4' y1='4.5' x2='20' y2='4.5'/><line x1='4' y1='9.5' x2='20' y2='9.5'/><line x1='4' y1='14.5' x2='20' y2='14.5'/><line x1='4' y1='19.5' x2='20' y2='19.5'/>"


densityNormal : Icon.Icon
densityNormal =
    Icon.fromSvg "table-density-normal" "<line x1='4' y1='5' x2='20' y2='5'/><line x1='4' y1='12' x2='20' y2='12'/><line x1='4' y1='19' x2='20' y2='19'/>"


densityComfortable : Icon.Icon
densityComfortable =
    Icon.fromSvg "table-density-comfortable" "<rect x='4' y='4' width='16' height='6' rx='1'/><rect x='4' y='14' width='16' height='6' rx='1'/>"


viewDensity : Ctx row msg -> Html msg
viewDensity ctx =
    let
        choice value icon name =
            Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.pressed (ctx.model.density == value)
                , Button.title (ctx.t.density ++ ": " ++ name)
                , Button.onClick (ctx.toMsg (DensityChanged value))
                ]
                icon
                name
    in
    Html.div
        [ Internal.cls [ "klar-table__density" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" ctx.t.density
        ]
        [ choice Compact densityCompact ctx.t.compact
        , choice Normal densityNormal ctx.t.normal
        , choice Comfortable densityComfortable ctx.t.comfortable
        ]


viewColumnsMenu : Ctx row msg -> Html msg
viewColumnsMenu ctx =
    let
        isOpen =
            ctx.model.popup == ColumnsPopup

        shownCount =
            List.length ctx.visible

        checkboxId index =
            ctx.model.id ++ "-column-" ++ String.fromInt index

        isShownColumn col =
            List.any (\v -> v.id == col.id) ctx.visible

        isLocked col =
            not col.hideable || (isShownColumn col && shownCount <= 1)

        -- focus goes to the first checkbox that can be changed
        firstUnlocked =
            ctx.allColumns
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, col ) -> not (isLocked col))
                |> List.map (Tuple.first >> checkboxId)
                |> List.take 1
    in
    Html.div [ Internal.cls [ "klar-anchor" ] ]
        [ Button.view
            [ Button.ghost
            , Button.icon Icon.columns
            , Button.id (triggerDomId ctx.model.id ColumnsPopup)
            , Button.expanded isOpen
            , Button.htmlAttrs [ Attr.attribute "aria-haspopup" "dialog" ]
            , Button.onClick (ctx.toMsg (PopupOpened ColumnsPopup firstUnlocked))
            ]
            ctx.t.columns
        , if isOpen then
            viewPopup ctx
                ColumnsPopup
                { title = ctx.t.columnsTitle, alignEnd = True }
                [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                    -- The list scrolls: with many columns the popup (fixed
                    -- below the toolbar) would run past the bottom of the
                    -- window, taking "Done" with it.
                    [ Html.div [ Internal.cls [ "klar-table__options", "klar-table__options--scroll" ] ]
                        (List.indexedMap
                            (\index col ->
                                let
                                    shown =
                                        isShownColumn col

                                    locked =
                                        isLocked col
                                in
                                Html.div [ Internal.cls [ "klar-table__option" ] ]
                                    [ Checkbox.view
                                        [ Checkbox.id (checkboxId index)
                                        , Checkbox.label col.title
                                        , Checkbox.checked shown
                                        , Checkbox.disabled locked
                                        , Checkbox.onCheck (\value -> ctx.toMsg (ColumnToggled col.id value))
                                        ]
                                    ]
                            )
                            ctx.allColumns
                        )
                    ]
                , Html.div [ Internal.cls [ "klar-table__popover-foot" ] ]
                    [ Button.view [ Button.small, Button.ghost, Button.onClick (ctx.toMsg ColumnsReset) ] ctx.t.reset
                    , Button.view [ Button.small, Button.onClick (ctx.toMsg PopupClosed) ] ctx.t.done
                    ]
                ]

          else
            Html.text ""
        ]


{-| The export menu, in the toolbar (`ExportPopup`) or in the bulk action bar
(`BulkExportPopup`, the selected rows first).
-}
viewExportMenu : Ctx row msg -> Popup -> String -> Html msg
viewExportMenu ctx popup filename =
    let
        isOpen =
            ctx.model.popup == popup

        inBulkBar =
            popup == BulkExportPopup
    in
    Html.div [ Internal.cls [ "klar-anchor" ] ]
        [ Button.view
            [ if inBulkBar then
                Button.small

              else
                Button.ghost
            , Button.icon Icon.download
            , Button.id (triggerDomId ctx.model.id popup)
            , Button.expanded isOpen
            , Button.disabled (ctx.data.status /= Ready)
            , Button.htmlAttrs [ Attr.attribute "aria-haspopup" "dialog" ]
            , Button.onClick (ctx.toMsg (PopupOpened popup [ popupDomId ctx.model.id popup ++ "-option-0" ]))
            ]
            ctx.t.export
        , if isOpen then
            viewPopup ctx popup { title = ctx.t.exportTitle, alignEnd = True } (exportOptions ctx popup filename)

          else
            Html.text ""
        ]


{-| The download buttons. The CSV text of a choice is written only when its
button is clicked (in the click decoder), never on a render, and the file is
saved from `update` with `File.Download.string`, which has no size limit (a
`data:` link stops at the length of a URL, a few megabytes).
-}
exportOptions : Ctx row msg -> Popup -> String -> List (Html msg)
exportOptions ctx popup filename =
    let
        separator =
            csvSeparatorOf ctx

        exported =
            List.filter .exported ctx.visible

        -- the whole page in server mode, also when `virtual` draws only part of it
        pageRows =
            ctx.data.pageAll

        selectedRows =
            case ( ctx.config.rows, ctx.config.server ) of
                ( Remote.Loaded source, Nothing ) ->
                    sourceList source
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( index, row ) -> isPicked ctx.model.selection (ctx.keyOf index row))
                        |> List.map Tuple.second
                        |> sortRows ctx.config ctx.model ctx.allColumns

                _ ->
                    pageRows
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( index, row ) -> isPicked ctx.model.selection (ctx.keyOf (ctx.data.offset + index) row))
                        |> List.map Tuple.second

        option index title suffix choice =
            Html.button
                [ Internal.cls [ "klar-table__export-option" ]
                , Attr.type_ "button"
                , Attr.id (popupDomId ctx.model.id popup ++ "-option-" ++ String.fromInt index)
                , Events.on "click"
                    (Decode.succeed ()
                        |> Decode.map
                            (\_ -> ctx.toMsg (ExportClicked (withSuffix suffix filename) (csvText separator exported ctx.loc (choice.rows ()))))
                    )
                ]
                [ Icon.view Icon.download
                , Html.span [ Internal.cls [ "klar-table__export-label" ] ] [ Html.text title ]
                , Html.span [ Internal.cls [ "klar-table__export-count", "klar-tabular" ] ] [ Html.text (ctx.t.rowCount choice.count) ]
                ]

        allChoice =
            if ctx.config.server == Nothing then
                Just ( ctx.t.exportAll, "", { count = ctx.data.total, rows = ctx.data.matchingRows } )

            else
                Nothing

        -- In server mode only the current page is here. A file of "the selected
        -- rows" that lacks the ones on other pages would be wrong without a sign,
        -- so it is offered only when every selected row is on this page.
        offPage =
            if ctx.config.server == Nothing then
                0

            else
                max 0 (selectionTotal ctx - List.length selectedRows)

        selectedChoice =
            if ctx.hasSelect && not (List.isEmpty selectedRows) && offPage == 0 then
                Just ( ctx.t.exportSelected, ctx.t.fileSelected, { count = List.length selectedRows, rows = \_ -> selectedRows } )

            else
                Nothing

        pageChoice =
            { count = List.length pageRows, rows = \_ -> pageRows }

        pageOption =
            if ctx.config.paged && ctx.data.pageCount > 1 then
                Just ( ctx.t.exportPage, ctx.t.filePage ctx.data.page, pageChoice )

            else
                Nothing

        choices =
            (if popup == BulkExportPopup then
                [ selectedChoice, allChoice, pageOption ]

             else
                [ allChoice, selectedChoice, pageOption ]
            )
                |> List.filterMap identity
                |> (\list ->
                        if List.isEmpty list then
                            [ ( ctx.t.exportPage, "", pageChoice ) ]

                        else
                            list
                   )
    in
    [ Html.div [ Internal.cls [ "klar-table__popover-body", "klar-table__popover-body--flush" ] ]
        (List.indexedMap (\index ( title, suffix, choice ) -> option index title suffix choice) choices)
    , Internal.viewIf (ctx.hasSelect && offPage > 0)
        (Html.p [ Internal.cls [ "klar-table__popover-note" ] ]
            [ Html.text (ctx.t.selectionOffPage offPage (selectionTotal ctx)) ]
        )
    , Html.p [ Internal.cls [ "klar-table__popover-note", "klar-table__popover-note--foot" ] ]
        [ Html.text (ctx.t.exportNote (List.length exported) separator) ]
    ]


{-| The field separator of the export: `csvSeparator`, or a comma in English and a
semicolon in Norwegian.
-}
csvSeparatorOf : Ctx row msg -> Char
csvSeparatorOf ctx =
    Maybe.withDefault (Locale.pick ctx.loc { nb = ';', en = ',' }) ctx.config.csvSeparator


{-| The CSV text of some rows: a line of titles, then a line per row with the
exported values of these columns.
-}
csvText : Char -> List (ColumnConfig row msg) -> Locale -> List row -> String
csvText separator exported loc someRows =
    Csv.encode separator
        (List.map .title exported
            :: List.map (\row -> List.map (\col -> exportValue loc col row) exported) someRows
        )


{-| "orders.csv" + "-selected" = "orders-selected.csv" (the suffix is "-valgte" in
Norwegian)
-}
withSuffix : String -> String -> String
withSuffix suffix filename =
    if String.isEmpty suffix then
        filename

    else
        case List.reverse (String.split "." filename) of
            extension :: ((_ :: _) as restReversed) ->
                String.join "." (List.reverse restReversed) ++ suffix ++ "." ++ extension

            _ ->
                filename ++ suffix


viewBulkBar : Ctx row msg -> Html msg
viewBulkBar ctx =
    let
        t =
            ctx.t

        count =
            selectionTotal ctx

        allPageSelected =
            not (List.isEmpty ctx.pageKeys) && List.all (isPicked ctx.model.selection) ctx.pageKeys

        clientMode =
            ctx.config.server == Nothing

        -- client mode: what "select all N matching" selects (matching rows that are not disabled)
        selectableTotal =
            if clientMode then
                selectableCount ctx

            else
                ctx.data.total

        allMatchingSelected =
            case ctx.model.selection of
                AllPicked except ->
                    Set.isEmpty except

                Picked keys ->
                    clientMode
                        && selectableTotal
                        > 0
                        && Set.size keys
                        >= selectableTotal
                        && (everyRowCanBeSelected ctx || List.all (\key -> Set.member key keys) (selectableKeys ctx))

        note value =
            Html.span [ Internal.cls [ "klar-table__bulk-note" ] ] [ Html.text value ]

        -- Selected rows the user cannot see. Client mode knows they are left out
        -- by the search or a filter. A server only gives the current page, so
        -- there it is "not on this page": other pages, or rows a new search
        -- or filter took away. Either way the count in the bar is not a
        -- surprise when a bulk action then acts on all of them.
        hiddenCount =
            case ( ctx.model.selection, ctx.config.server, ctx.config.rowId ) of
                ( Picked keys, Nothing, Just toId ) ->
                    if Set.isEmpty keys || ctx.data.total == ctx.data.available then
                        -- no row is left out, so none of the selected rows is out of sight
                        0

                    else
                        Set.size keys - ctx.data.countMatching (\_ row -> Set.member (toId row) keys)

                ( Picked keys, Just _, _ ) ->
                    Set.size keys - List.length (List.filter (\key -> Set.member key keys) ctx.pageKeys)

                _ ->
                    0

        hiddenNote =
            note
                (if clientMode then
                    t.hiddenSelected hiddenCount

                 else
                    t.selectedElsewhere hiddenCount
                )

        prompt =
            if allMatchingSelected && selectableTotal > List.length ctx.pageKeys then
                note (t.allMatching selectableTotal)
                    :: (if hiddenCount > 0 then
                            [ hiddenNote ]

                        else
                            []
                       )

            else if allPageSelected && selectableTotal > List.length ctx.pageKeys then
                [ note (t.allOnPage (List.length ctx.pageKeys))
                , Button.view
                    [ Button.link
                    , if clientMode then
                        -- the keys of every matching row are found when the button is
                        -- clicked, not on every render while it is shown
                        Button.htmlAttrs
                            [ Events.on "click"
                                (Decode.succeed ()
                                    |> Decode.map (\_ -> ctx.toMsg (MatchingSelected (selectableKeys ctx)))
                                )
                            ]

                      else
                        Button.onClick (ctx.toMsg AllMatchingPicked)
                    ]
                    (t.selectAllMatching selectableTotal)
                ]

            else if hiddenCount > 0 then
                [ hiddenNote ]

            else
                []
    in
    Html.div
        [ Internal.cls [ "klar-table__bulk" ]
        , Attr.id (bulkDomId ctx.model.id)
        , Attr.tabindex -1
        , Attr.attribute "role" "region"
        , Attr.attribute "aria-label" (t.selected count)
        ]
        [ Html.span [ Internal.cls [ "klar-table__bulk-count", "klar-tabular" ] ] [ Html.text (t.selected count) ]
        , Html.div [ Internal.cls [ "klar-table__bulk-prompt" ] ] prompt
        , Html.div [ Internal.cls [ "klar-table__bulk-actions" ] ]
            ((case ctx.config.export of
                Just filename ->
                    [ viewExportMenu ctx BulkExportPopup filename ]

                Nothing ->
                    []
             )
                ++ ctx.config.bulkActions
                ++ [ Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.onClick (ctx.toMsg (SelectionCleared (ctx.model.id ++ "-select-page")))
                        ]
                        t.cancel
                   ]
            )
        ]


{-| A client-mode table that scrolls: there are no pages, so the checkbox in
the header and the bulk bar speak of all the matching rows.
-}
isLongClientTable : Ctx row msg -> Bool
isLongClientTable ctx =
    ctx.config.virtual && ctx.config.server == Nothing


{-| The keys of the matching rows that can be selected. It goes through every
matching row: ask for it when the user acts, or when a selection is there to be
counted, and not on every view.
-}
selectableKeys : Ctx row msg -> List String
selectableKeys ctx =
    ctx.data.matchingRows ()
        |> List.indexedMap (\index row -> ( ctx.keyOf index row, rowIsDisabled ctx.config row ))
        |> List.filter (\( _, disabled ) -> not disabled)
        |> List.map Tuple.first


{-| Does every row of the table match, and can every one be selected? Then as many
selected keys as rows mean that all rows are selected, and the bulk bar need not
go through the rows to see it.
-}
everyRowCanBeSelected : Ctx row msg -> Bool
everyRowCanBeSelected ctx =
    ctx.data.total == ctx.data.available && not (isJust ctx.config.rowDisabled)


{-| How many matching rows can be selected. Without `rowDisabled` that is all of them.
-}
selectableCount : Ctx row msg -> Int
selectableCount ctx =
    if isJust ctx.config.rowDisabled then
        List.length (selectableKeys ctx)

    else
        ctx.data.total


{-| For the checkbox in the header of a table that scrolls: are all the matching
rows selected, and if not, are some?
-}
matchingSelectionState : Ctx row msg -> ( Bool, Bool )
matchingSelectionState ctx =
    let
        selected =
            case ctx.model.selection of
                Picked keys ->
                    if Set.isEmpty keys then
                        0

                    else if ctx.data.total == ctx.data.available then
                        Set.size keys

                    else
                        ctx.data.countMatching (\index row -> Set.member (ctx.keyOf index row) keys)

                AllPicked except ->
                    max 0 (ctx.data.total - Set.size except)

        all =
            selected > 0 && selected >= selectableCount ctx
    in
    ( all, selected > 0 && not all )


rowIsDisabled : Config row msg -> row -> Bool
rowIsDisabled config row =
    case config.rowDisabled of
        Just test ->
            test row

        Nothing ->
            False



-- POPUPS


{-| The popup recipe: a click-away layer, Escape closes and gives focus back
to the trigger, focus leaving the popup (Tab) closes it.
-}
viewPopup : Ctx row msg -> Popup -> { title : String, alignEnd : Bool } -> List (Html msg) -> Html msg
viewPopup ctx popup options content =
    let
        popupId =
            popupDomId ctx.model.id popup
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]

        -- Clicks inside the popup are ignored here instead of being stopped in
        -- the popup: a handler that stops propagation makes Elm render in the
        -- middle of the click, which resets checkboxes before their change
        -- event fires.
        , Events.on "click" (outsideClick popupId (ctx.toMsg PopupClosed))

        -- Escape closes the popup and is used up, so that a dialog around the table stays open
        , Internal.onKeys [ ( "Escape", ctx.toMsg PopupClosed ) ]
        ]
        [ Html.div
            [ Internal.cls
                [ "klar-popup"
                , "klar-table__popover"
                , if options.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
            , Attr.id popupId
            , Attr.tabindex -1
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-label" options.title
            , Events.on "focusout" (focusLeft popupId (ctx.toMsg PopupLeft))
            ]
            (Html.div [ Internal.cls [ "klar-table__popover-title" ] ] [ Html.text options.title ] :: content)
        ]


popupSuffix : Popup -> String
popupSuffix popup =
    case popup of
        NoPopup ->
            "none"

        FilterPopup colId ->
            "filter-" ++ Internal.sanitizeId colId

        ColumnsPopup ->
            "columns"

        ExportPopup ->
            "export"

        BulkExportPopup ->
            "bulk-export"

        FiltersPopup ->
            "filters"


popupDomId : String -> Popup -> String
popupDomId tableId popup =
    tableId ++ "-popup-" ++ popupSuffix popup


triggerDomId : String -> Popup -> String
triggerDomId tableId popup =
    tableId ++ "-trigger-" ++ popupSuffix popup


rowDomId : String -> Int -> String
rowDomId tableId index =
    tableId ++ "-row-" ++ String.fromInt index


detailDomId : String -> Int -> String
detailDomId tableId index =
    tableId ++ "-detail-" ++ String.fromInt index


bulkDomId : String -> String
bulkDomId tableId =
    tableId ++ "-bulk"


{-| The scroll area: where focus waits when the control that had it (the retry
button) is replaced.
-}
scrollDomId : String -> String
scrollDomId tableId =
    tableId ++ "-scroll"


filterInputId : String -> String -> String -> String
filterInputId tableId colId part =
    tableId ++ "-filter-" ++ Internal.sanitizeId colId ++ "-" ++ part


{-| Fires when focus moves to an element outside the popup (Tab, Shift+Tab).
Focus moving inside, or to nothing (the window lost focus), is ignored.
-}
focusLeft : String -> msg -> Decoder msg
focusLeft popupId msg =
    Decode.field "relatedTarget" (Decode.nullable (isInside popupId 0))
        |> Decode.andThen
            (\inside ->
                case inside of
                    Just False ->
                        Decode.succeed msg

                    _ ->
                        Decode.fail "focus stayed inside"
            )


{-| A click on the click-away layer itself, not one that started inside the
popup.
-}
outsideClick : String -> msg -> Decoder msg
outsideClick popupId msg =
    Decode.field "target" (isInside popupId 0)
        |> Decode.andThen
            (\inside ->
                if inside then
                    Decode.fail "click inside the popup"

                else
                    Decode.succeed msg
            )


isInside : String -> Int -> Decoder Bool
isInside targetId depth =
    Decode.oneOf [ Decode.field "id" Decode.string, Decode.succeed "" ]
        |> Decode.andThen
            (\elementId ->
                if elementId == targetId then
                    Decode.succeed True

                else if depth > 40 then
                    Decode.succeed False

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.null False)
                        , Decode.field "parentElement" (Decode.lazy (\_ -> isInside targetId (depth + 1)))
                        , Decode.succeed False
                        ]
            )



-- FRAME, HEADER AND BODY


viewFrame : Ctx row msg -> Html msg
viewFrame ctx =
    let
        config =
            ctx.config

        busy =
            ctx.data.status == Waiting || (config.refreshing && ctx.data.status == Ready)
    in
    Html.div [ Internal.cls [ "klar-table__frame" ] ]
        [ Html.div
            ([ Internal.cls [ "klar-table__scroll" ]
             , Attr.id (scrollDomId ctx.model.id)

             -- Not a tab stop: only a place for focus to wait (see RetryClicked).
             -- A table with nothing to focus in it is left alone: Chrome makes
             -- such a scroll area focusable, so it can be scrolled with the keys.
             -- One that scrolls is a tab stop while the row that Tab should reach
             -- is not drawn, and hands the focus to that row. With onResetFilters
             -- it can always take focus: it is where focus goes after "Reset
             -- filters" when the table has no search box or filter button.
             , Internal.attrIf (hasFocusableContent ctx || isJust config.onResetFilters)
                (Attr.tabindex
                    (if activeRowHidden ctx then
                        0

                     else
                        -1
                    )
                )
             , Internal.attrIf (config.virtual && activeRowHidden ctx) (Events.on "focus" (activeRowRequested ctx))
             , Internal.attrIf config.virtual (Events.on "scroll" (Decode.map (Scrolled >> ctx.toMsg) (Decode.at [ "target", "scrollTop" ] Decode.float)))
             , case scrollVars ctx of
                [] ->
                    Internal.noAttr

                vars ->
                    Internal.styleVars vars
             ]
                ++ (case config.label of
                        Just name ->
                            [ Attr.attribute "role" "region", Attr.attribute "aria-label" name ]

                        Nothing ->
                            []
                   )
            )
            [ let
                tableAttributes =
                    [ Internal.cls [ "klar-table__table" ]
                    , Internal.styleVars [ ( "min-width", Internal.px (tableMinWidth ctx) ) ]

                    -- Rows that expand make a tree grid (see isTreegrid): screen
                    -- readers then leave the arrow keys to the rows. Every other
                    -- table, also one whose rows take focus, stays a table.
                    , Internal.attrIf (isTreegrid ctx) (Attr.attribute "role" "treegrid")
                    , Internal.attrIf (isTreegrid ctx && ctx.hasSelect) (Attr.attribute "aria-multiselectable" "true")
                    , Internal.attrMaybe (Attr.attribute "aria-label") config.label
                    , Attr.attribute "aria-rowcount"
                        (if ctx.data.status == Ready then
                            String.fromInt (ctx.data.total + 1)

                         else
                            "-1"
                        )
                    , Attr.attribute "aria-colcount" (String.fromInt ctx.colCount)
                    , Internal.attrIf busy (Attr.attribute "aria-busy" "true")
                    ]

                parts =
                    List.concat
                        [ [ ( "colgroup", viewColgroup ctx ), ( "head", viewHead ctx ) ]
                        , viewBodies ctx
                        , [ ( "foot", viewFoot ctx ) ]
                        ]
              in
              if config.virtual then
                -- the chunks of rows come and go at the ends, and keys keep the others where they are
                Html.Keyed.node "table" tableAttributes parts

              else
                Html.table tableAttributes (List.map Tuple.second parts)
            ]
        , Html.div [ Internal.cls [ "klar-table__edge", "klar-table__edge--start" ], Attr.attribute "aria-hidden" "true" ] []
        , Html.div [ Internal.cls [ "klar-table__edge", "klar-table__edge--end" ], Attr.attribute "aria-hidden" "true" ] []
        , Internal.viewIf (config.refreshing && ctx.data.status == Ready)
            (Html.div [ Internal.cls [ "klar-table__progress" ], Attr.attribute "aria-hidden" "true" ] [])
        ]


{-| In a table that scrolls: is the row that has the tab stop out of the drawn rows?
-}
activeRowHidden : Ctx row msg -> Bool
activeRowHidden ctx =
    ctx.config.virtual
        && ctx.interactiveRows
        && ctx.data.status
        == Ready
        && ctx.data.rowCount
        > 0
        && (ctx.activeRow < ctx.data.first || ctx.activeRow >= ctx.data.first + List.length ctx.data.pageRows)


{-| The scroll area itself got the focus (Tab reached it): focus goes on to the row
that has the tab stop, which is scrolled into view first.
-}
activeRowRequested : Ctx row msg -> Decoder msg
activeRowRequested ctx =
    Decode.at [ "target", "id" ] Decode.string
        |> Decode.andThen
            (\targetId ->
                if targetId == scrollDomId ctx.model.id then
                    Decode.succeed (ctx.toMsg (FocusVirtualRow ctx.activeRow (rowDomId ctx.model.id ctx.activeRow) ctx.geometry))

                else
                    Decode.fail "not the scroll area"
            )


{-| Fixed columns keep their width; the others share the rest and each gets
at least the largest of their minimum widths before the table scrolls.
-}
tableMinWidth : Ctx row msg -> Int
tableMinWidth ctx =
    let
        fixed =
            ctx.visible |> List.filterMap fixedWidth |> List.sum

        flexibleCount =
            ctx.visible |> List.filter (\col -> col.width == Nothing) |> List.length

        system =
            (if ctx.hasSelect then
                selectWidth

             else
                0
            )
                + (if ctx.hasExpand then
                    expandWidth

                   else
                    0
                  )
                + (if ctx.hasMenu then
                    menuWidth

                   else
                    0
                  )
    in
    fixed + system + flexibleCount * flexibleShare ctx


{-| Is there a control in the table itself (a sort button, a filter, a row
that can be focused, controls in a cell) for the keyboard to reach?
-}
hasFocusableContent : Ctx row msg -> Bool
hasFocusableContent ctx =
    ctx.interactiveRows
        || List.any (\col -> isSortable col || usableFilter col /= Nothing || col.controls) ctx.visible


{-| What each column without a fixed width gets when the table is as narrow as
it can be (and therefore scrolls sideways): the largest of their minimum
widths.
-}
flexibleShare : Ctx row msg -> Int
flexibleShare ctx =
    ctx.visible
        |> List.filter (\col -> col.width == Nothing)
        |> List.map flexibleMinWidth
        |> List.maximum
        |> Maybe.withDefault 0


{-| What the sticky columns cover of the scroll area at the table's narrowest:
the pinned first column with the select and expand columns before it, and the
row menu at the other edge. Given to the scroll area as scroll padding, so
that the browser moves a control that got focus (Tab, Shift+Tab) clear of
them instead of leaving it underneath.
-}
scrollVars : Ctx row msg -> List ( String, String )
scrollVars ctx =
    let
        coveredLeft =
            case ctx.visible of
                first :: _ ->
                    if ctx.pinnedFirst then
                        pinLeft ctx
                            + (case fixedWidth first of
                                Just px ->
                                    px

                                Nothing ->
                                    flexibleShare ctx
                              )

                    else
                        0

                [] ->
                    0
    in
    List.concat
        [ case ctx.config.maxHeight of
            Just px ->
                [ ( "max-height", Internal.px px ) ]

            Nothing ->
                if ctx.config.virtual && not ctx.config.fillHeight then
                    [ ( "max-height", Internal.px defaultVirtualHeight ) ]

                else
                    []
        , if coveredLeft > 0 then
            [ ( "--_pin-w", Internal.px coveredLeft ) ]

          else
            []
        , if ctx.hasMenu then
            [ ( "--_menu-w", Internal.px menuWidth ) ]

          else
            []
        ]


viewColgroup : Ctx row msg -> Html msg
viewColgroup ctx =
    let
        fixedCol px =
            Html.col [ Internal.styleVars [ ( "width", Internal.px px ) ] ] []
    in
    Html.colgroup []
        (List.concat
            [ if ctx.hasSelect then
                [ fixedCol selectWidth ]

              else
                []
            , if ctx.hasExpand then
                [ fixedCol expandWidth ]

              else
                []
            , List.map
                (\col ->
                    case fixedWidth col of
                        Just px ->
                            fixedCol px

                        Nothing ->
                            Html.col [] []
                )
                ctx.visible
            , if ctx.hasMenu then
                [ fixedCol menuWidth ]

              else
                []
            ]
        )


{-| The width of a fixed column, never narrower than its header needs.
-}
fixedWidth : ColumnConfig row msg -> Maybe Int
fixedWidth col =
    Maybe.map (max (headerWidth col)) col.width


flexibleMinWidth : ColumnConfig row msg -> Int
flexibleMinWidth col =
    max col.minWidth (headerWidth col)


{-| A generous estimate of what the header needs so its title is not cut:
the title (about 7 px per character at the header's 12 px semibold), the
sort icon, the filter button and the cell padding.
-}
headerWidth : ColumnConfig row msg -> Int
headerWidth col =
    24
        + (if col.controls then
            0

           else
            ceiling (toFloat (String.length col.title) * 7.2)
          )
        + (if isSortable col then
            22

           else
            0
          )
        + (case usableFilter col of
            Just _ ->
                26

            Nothing ->
                0
          )


{-| The column's filter, if it can work: a range filter needs numbers.
-}
usableFilter : ColumnConfig row msg -> Maybe FilterKind
usableFilter col =
    case ( col.filter, col.number ) of
        ( Just RangeFilter, Nothing ) ->
            Nothing

        ( kind, _ ) ->
            kind


{-| Left offset of the pinned column: the select and expand columns before it.
-}
pinLeft : Ctx row msg -> Int
pinLeft ctx =
    (if ctx.hasSelect then
        selectWidth

     else
        0
    )
        + (if ctx.hasExpand then
            expandWidth

           else
            0
          )


systemPinStyle : Ctx row msg -> Int -> Html.Attribute msg
systemPinStyle ctx left =
    if ctx.pinnedFirst then
        Internal.styleVars [ ( "--_pin-left", Internal.px left ) ]

    else
        Internal.noAttr


viewHead : Ctx row msg -> Html msg
viewHead ctx =
    let
        t =
            ctx.t

        pinClass =
            if ctx.pinnedFirst then
                "klar-table__cell--pinned"

            else
                ""

        pageSelected =
            List.filter (isPicked ctx.model.selection) ctx.pageKeys

        ( allOn, someOn ) =
            if isLongClientTable ctx then
                matchingSelectionState ctx

            else
                let
                    all =
                        not (List.isEmpty ctx.pageKeys) && List.length pageSelected == List.length ctx.pageKeys
                in
                ( all, not all && not (List.isEmpty pageSelected) )
    in
    Html.thead [ Internal.cls [ "klar-table__head" ] ]
        [ Html.tr [ Attr.attribute "aria-rowindex" "1", gridPart ctx "row" ]
            (List.concat
                [ if ctx.hasSelect then
                    [ Html.th
                        [ Internal.cls [ "klar-table__th", "klar-table__th--select", pinClass ]
                        , Attr.scope "col"
                        , gridPart ctx "columnheader"
                        , systemPinStyle ctx 0
                        ]
                        [ Checkbox.view
                            [ Checkbox.id (ctx.model.id ++ "-select-page")
                            , Checkbox.ariaLabel t.selectPage
                            , Checkbox.checked allOn
                            , Checkbox.indeterminate someOn
                            , Checkbox.disabled
                                ((if isLongClientTable ctx then
                                    ctx.data.total == 0

                                  else
                                    List.isEmpty ctx.pageKeys
                                 )
                                    || ctx.data.status
                                    /= Ready
                                )
                            , Checkbox.onCheck
                                (\value ->
                                    if isLongClientTable ctx then
                                        ctx.toMsg (RowsSelected (selectableKeys ctx) value)

                                    else
                                        ctx.toMsg (RowsSelected ctx.pageKeys value)
                                )
                            ]
                        ]
                    ]

                  else
                    []
                , if ctx.hasExpand then
                    [ Html.th
                        [ Internal.cls [ "klar-table__th", "klar-table__th--expand", pinClass ]
                        , Attr.scope "col"
                        , gridPart ctx "columnheader"
                        , systemPinStyle ctx
                            (if ctx.hasSelect then
                                selectWidth

                             else
                                0
                            )
                        ]
                        [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.details ] ]
                    ]

                  else
                    []
                , List.indexedMap (viewHeaderCell ctx) ctx.visible
                , if ctx.hasMenu then
                    [ Html.th [ Internal.cls [ "klar-table__th", "klar-table__th--menu" ], Attr.scope "col", gridPart ctx "columnheader" ]
                        [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.actions ] ]
                    ]

                  else
                    []
                ]
            )
        ]


alignClass : String -> Align -> String
alignClass block align =
    case align of
        AlignLeft ->
            ""

        AlignRight ->
            block ++ "--right"

        AlignCenter ->
            block ++ "--center"


viewHeaderCell : Ctx row msg -> Int -> ColumnConfig row msg -> Html msg
viewHeaderCell ctx index col =
    let
        model =
            ctx.model

        direction =
            lookup col.id model.sort

        sortPosition =
            model.sort
                |> List.indexedMap (\i ( colId, _ ) -> ( colId, i + 1 ))
                |> lookup col.id

        isPrimary =
            sortPosition == Just 1

        sortable =
            isSortable col

        pinnedHere =
            index == 0 && ctx.pinnedFirst

        filterOpen =
            model.popup == FilterPopup col.id

        sortIcon =
            Html.span
                [ Internal.cls
                    [ "klar-table__sort-icon"
                    , if direction /= Nothing then
                        "klar-table__sort-icon--active"

                      else
                        ""
                    ]
                , Attr.attribute "aria-hidden" "true"
                ]
                [ Icon.sized Icon.Small
                    (case direction of
                        Just Ascending ->
                            Icon.arrowUp

                        Just Descending ->
                            Icon.arrowDown

                        Nothing ->
                            Icon.chevronsUpDown
                    )
                , case ( sortPosition, List.length model.sort > 1 ) of
                    ( Just position, True ) ->
                        Html.span [ Internal.cls [ "klar-table__sort-order" ] ] [ Html.text (String.fromInt position) ]

                    _ ->
                        Html.text ""
                ]

        titleSpan =
            Html.span
                [ Internal.cls
                    [ "klar-table__title"
                    , if col.controls then
                        "klar-sr-only"

                      else
                        ""
                    ]
                ]
                [ Html.text col.title ]

        heading =
            if sortable then
                Html.button
                    [ Internal.cls [ "klar-table__sort" ]
                    , Attr.type_ "button"
                    , Attr.title
                        (case col.hint of
                            Just value ->
                                value

                            Nothing ->
                                if ctx.config.multiSort then
                                    ctx.t.multiSortHint

                                else
                                    ctx.t.sortHint
                        )
                    , Events.on "click"
                        (Decode.field "shiftKey" Decode.bool
                            |> Decode.map (\shift -> ctx.toMsg (SortClicked col.id (shift && ctx.config.multiSort)))
                        )
                    ]
                    (if col.align == AlignRight then
                        [ sortIcon, titleSpan ]

                     else
                        [ titleSpan, sortIcon ]
                    )

            else
                Html.span
                    [ Internal.cls [ "klar-table__label" ]
                    , Internal.attrMaybe Attr.title col.hint
                    ]
                    [ titleSpan ]

        filterControl =
            case usableFilter col of
                Just _ ->
                    viewFilterButton ctx col filterOpen

                Nothing ->
                    Html.text ""
    in
    Html.th
        [ Internal.cls
            [ "klar-table__th"
            , alignClass "klar-table__th" col.align
            , if pinnedHere then
                "klar-table__cell--pinned klar-table__cell--pin-edge"

              else
                ""
            , if filterOpen then
                "klar-table__th--open"

              else
                ""
            ]
        , Attr.scope "col"
        , gridPart ctx "columnheader"
        , if pinnedHere then
            Internal.styleVars [ ( "--_pin-left", Internal.px (pinLeft ctx) ) ]

          else
            Internal.noAttr
        , case ( direction, isPrimary ) of
            ( Just Ascending, True ) ->
                Attr.attribute "aria-sort" "ascending"

            ( Just Descending, True ) ->
                Attr.attribute "aria-sort" "descending"

            _ ->
                Internal.attrIf sortable (Attr.attribute "aria-sort" "none")
        ]
        [ Html.div [ Internal.cls [ "klar-table__heading", alignClass "klar-table__heading" col.align ] ]
            (if col.align == AlignRight then
                [ filterControl, heading ]

             else
                [ heading, filterControl ]
            )
        ]


viewFilterButton : Ctx row msg -> ColumnConfig row msg -> Bool -> Html msg
viewFilterButton ctx col isOpen =
    let
        active =
            case Dict.get col.id ctx.model.inputs of
                Just draft ->
                    toFilter draft /= Nothing

                Nothing ->
                    False

        popup =
            FilterPopup col.id

        name =
            if active then
                ctx.t.filterColumnActive col.title

            else
                ctx.t.filterColumn col.title
    in
    Html.div [ Internal.cls [ "klar-anchor", "klar-table__filter" ] ]
        [ Html.button
            [ Internal.cls
                [ "klar-table__filter-button"
                , if active then
                    "klar-table__filter-button--active"

                  else
                    ""
                ]
            , Attr.type_ "button"
            , Attr.id (triggerDomId ctx.model.id popup)
            , Attr.title name
            , Attr.attribute "aria-label" name
            , Attr.attribute "aria-haspopup" "dialog"

            -- No aria-pressed next to aria-expanded: a button that opens a popup is not also
            -- a toggle. A filter that is on is part of the name.
            , Attr.attribute "aria-expanded"
                (if isOpen then
                    "true"

                 else
                    "false"
                )
            , Events.onClick (ctx.toMsg (PopupOpened popup (filterFocusTargets ctx col)))
            ]
            [ Icon.sized Icon.Small Icon.filter ]
        , if isOpen then
            viewPopup ctx
                popup
                { title = ctx.t.filterTitle col.title
                , alignEnd = col.align == AlignRight
                }
                (viewFilterContent ctx col)

          else
            Html.text ""
        ]


{-| Where focus goes when a filter popover opens: the first of these that
exists.
-}
filterFocusTargets : Ctx row msg -> ColumnConfig row msg -> List String
filterFocusTargets ctx col =
    case usableFilter col of
        Just TextFilter ->
            [ filterInputId ctx.model.id col.id "text" ]

        Just RangeFilter ->
            [ filterInputId ctx.model.id col.id "from" ]

        Just SelectFilter ->
            [ filterInputId ctx.model.id col.id "search", filterInputId ctx.model.id col.id "option-0" ]

        Nothing ->
            []


viewFilterContent : Ctx row msg -> ColumnConfig row msg -> List (Html msg)
viewFilterContent ctx col =
    let
        t =
            ctx.t

        draft =
            Dict.get col.id ctx.model.inputs

        -- anything typed or picked can be cleared, also text that is not a valid filter yet ("abc" in a number field)
        active =
            case draft of
                Just (TextDraft value) ->
                    value /= ""

                Just (RangeDraft from to) ->
                    from /= "" || to /= ""

                Just (ChoiceDraft values) ->
                    not (Set.isEmpty values)

                Nothing ->
                    False

        foot =
            Html.div [ Internal.cls [ "klar-table__popover-foot" ] ]
                [ Button.view
                    [ Button.small
                    , Button.ghost
                    , Button.disabled (not active)
                    , Button.onClick (ctx.toMsg (FilterCleared col.id))
                    ]
                    t.clear
                , Button.view [ Button.small, Button.onClick (ctx.toMsg PopupClosed) ] t.done
                ]
    in
    case usableFilter col of
        Just TextFilter ->
            [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                [ TextInput.view
                    [ TextInput.id (filterInputId ctx.model.id col.id "text")
                    , TextInput.label t.contains
                    , TextInput.clearable
                    , TextInput.locale ctx.loc
                    , TextInput.value
                        (case draft of
                            Just (TextDraft value) ->
                                value

                            _ ->
                                ""
                        )
                    , TextInput.onInput (\value -> ctx.toMsg (FilterTextChanged col.id value ctx.delay))
                    , TextInput.onEnter (ctx.toMsg PopupClosed)
                    ]
                ]
            , foot
            ]

        Just RangeFilter ->
            let
                ( from, to ) =
                    case draft of
                        Just (RangeDraft a b) ->
                            ( a, b )

                        _ ->
                            ( "", "" )

                bounds =
                    case ( ctx.config.server, col.number ) of
                        ( Nothing, Just toNumber ) ->
                            let
                                numbers =
                                    case ctx.config.rows of
                                        Remote.Loaded source ->
                                            List.filterMap toNumber (sourceList source)

                                        _ ->
                                            []
                            in
                            Maybe.map2 Tuple.pair (List.minimum numbers) (List.maximum numbers)

                        _ ->
                            Nothing

                invalid raw =
                    not (String.isEmpty (String.trim raw)) && parseNumber raw == Nothing

                rangeInput part value isFrom =
                    TextInput.view
                        [ TextInput.id (filterInputId ctx.model.id col.id part)
                        , TextInput.label
                            (if isFrom then
                                t.from

                             else
                                t.to
                            )
                        , TextInput.inputMode "decimal"
                        , TextInput.locale ctx.loc
                        , TextInput.value value
                        , TextInput.onInput (\raw -> ctx.toMsg (FilterRangeChanged col.id isFrom raw ctx.delay))
                        , TextInput.onEnter (ctx.toMsg PopupClosed)
                        , TextInput.errorMaybe
                            (if invalid value then
                                Just t.notANumber

                             else
                                Nothing
                            )
                        ]
            in
            [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                [ Html.div [ Internal.cls [ "klar-table__range" ] ]
                    [ rangeInput "from" from True
                    , rangeInput "to" to False
                    ]
                , Internal.viewMaybe
                    (\( low, high ) ->
                        Html.p [ Internal.cls [ "klar-table__popover-note" ] ]
                            [ Html.text (t.rangeHint (formatNumber ctx.loc (rangeDecimals ctx col) low) (formatNumber ctx.loc (rangeDecimals ctx col) high)) ]
                    )
                    bounds
                ]
            , foot
            ]

        Just SelectFilter ->
            viewChoiceFilter ctx col ++ [ foot ]

        Nothing ->
            []


{-| The rows of the table as they came (all rows in client mode, the page in
server mode), or none while they load.
-}
loadedRows : Ctx row msg -> List row
loadedRows ctx =
    case ctx.config.rows of
        Remote.Loaded rowSource ->
            sourceList rowSource

        _ ->
            []


{-| The values a select filter offers (what it keeps, see `choiceOf`): the
column's `filterOptions`, or the distinct values in the rows, in the order of
their labels, plus anything already chosen.
-}
filterValues : Ctx row msg -> ColumnConfig row msg -> (String -> String) -> List String
filterValues ctx col labelOf =
    let
        chosen =
            choicesOf col.id ctx.model.inputs |> Set.map (canonicalChoice col)

        base =
            case col.filterOptions of
                Just options ->
                    List.map .value options

                Nothing ->
                    loadedRows ctx
                        |> List.filter (\row -> not (String.isEmpty (String.trim (col.value ctx.loc row))))
                        |> List.map (choiceOf ctx.loc col)
                        |> Set.fromList
                        |> Set.toList
                        |> List.sortBy (labelOf >> Sorting.collationKey ctx.loc)
    in
    base ++ List.filter (\value -> not (List.member value base)) (Set.toList chosen)


viewChoiceFilter : Ctx row msg -> ColumnConfig row msg -> List (Html msg)
viewChoiceFilter ctx col =
    let
        t =
            ctx.t

        labelOf =
            choiceLabels ctx.loc col (loadedRows ctx)

        values =
            filterValues ctx col labelOf

        chosen =
            choicesOf col.id ctx.model.inputs
                |> Set.map (canonicalChoice col)

        isChosen value =
            Set.member value chosen

        showSearch =
            List.length values > 8

        shown =
            if showSearch && String.trim ctx.model.optionQuery /= "" then
                List.filter (labelOf >> Search.matches ctx.model.optionQuery) values

            else
                values

        -- how many rows each value would add, given the other filters and the search
        counts =
            case ( ctx.config.server, ctx.config.rows ) of
                ( Nothing, Remote.Loaded source ) ->
                    sourceList source
                        |> keepMatching ctx.config ctx.model ctx.allColumns ctx.visible (Just col.id)
                        |> List.foldl
                            (\row dict ->
                                Dict.update (choiceOf ctx.loc col row) (\c -> Just (Maybe.withDefault 0 c + 1)) dict
                            )
                            Dict.empty
                        |> Just

                _ ->
                    Nothing
    in
    [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
        [ Internal.viewIf showSearch
            (TextInput.view
                [ TextInput.id (filterInputId ctx.model.id col.id "search")
                , TextInput.label t.searchValues
                , TextInput.labelHidden
                , TextInput.search
                , TextInput.clearable
                , TextInput.size Theme.Small
                , TextInput.placeholder t.searchValues
                , TextInput.locale ctx.loc
                , TextInput.value ctx.model.optionQuery
                , TextInput.onInput (\value -> ctx.toMsg (OptionQueryChanged value))
                ]
            )
        , Html.div [ Internal.cls [ "klar-table__option-actions" ] ]
            [ Button.view
                [ Button.link
                , Button.disabled (List.all isChosen shown)
                , Button.onClick (ctx.toMsg (FilterChoicesSet col.id (Set.toList chosen ++ shown)))
                ]
                t.selectAll
            , Button.view
                [ Button.link
                , Button.disabled (Set.isEmpty chosen)
                , Button.onClick (ctx.toMsg (FilterChoicesSet col.id []))
                ]
                t.selectNone
            ]
        , if List.isEmpty shown then
            Html.p [ Internal.cls [ "klar-table__popover-note" ] ] [ Html.text t.noValues ]

          else
            Html.div [ Internal.cls [ "klar-table__options", "klar-table__options--scroll" ] ]
                (List.indexedMap
                    (\index value ->
                        Html.div [ Internal.cls [ "klar-table__option" ] ]
                            [ Checkbox.view
                                [ Checkbox.id (filterInputId ctx.model.id col.id ("option-" ++ String.fromInt index))
                                , Checkbox.label (labelOf value)
                                , Checkbox.checked (isChosen value)
                                , Checkbox.onCheck (\checked -> ctx.toMsg (FilterChoiceToggled col.id value checked))
                                ]
                            , Internal.viewMaybe
                                (\dict ->
                                    Html.span [ Internal.cls [ "klar-table__option-count", "klar-tabular" ] ]
                                        [ Html.text (Format.int ctx.loc (Dict.get value dict |> Maybe.withDefault 0)) ]
                                )
                                counts
                            ]
                    )
                    shown
                )
        ]
    ]


viewBody : Ctx row msg -> Html msg
viewBody ctx =
    Html.Keyed.node "tbody"
        [ Internal.cls [ "klar-table__body" ] ]
        (case ctx.data.status of
            Waiting ->
                skeletonRows ctx

            Failed problem ->
                [ ( "state-error"
                  , stateRow ctx
                        -- the click on "Try again" bubbles to the wrapper, which
                        -- keeps focus in the table when the button goes away
                        (Html.div [ Events.on "click" (retryClicked ctx) ]
                            [ ErrorState.view
                                (List.filterMap identity
                                    [ Just ErrorState.compact
                                    , Just (ErrorState.locale ctx.loc)
                                    , Maybe.map ErrorState.onRetry ctx.config.onRetry
                                    ]
                                )
                                problem
                            ]
                        )
                  )
                ]

            Ready ->
                if List.isEmpty ctx.data.pageRows then
                    [ ( "state-empty", stateRow ctx (viewEmpty ctx) ) ]

                else
                    ctx.data.pageRows
                        |> List.indexedMap (\i row -> viewRowAndDetail ctx (ctx.data.first + i) row)
                        |> List.concat
        )


{-| The bodies of the table: one, or for a table that scrolls the empty room
above the rows in view, the rows in chunks of a `tbody` each, and the empty room
below them.
-}
viewBodies : Ctx row msg -> List ( String, Html msg )
viewBodies ctx =
    if ctx.config.virtual && ctx.data.status == Ready && not (List.isEmpty ctx.data.pageRows) then
        let
            after =
                ctx.data.rowCount - ctx.data.first - List.length ctx.data.pageRows

            chunk =
                virtualWindow.chunk

            chunks =
                ctx.data.pageRows
                    |> List.indexedMap (\i row -> ( ctx.data.first + i, row ))
                    |> List.foldr
                        (\( index, row ) groups ->
                            case groups of
                                ( number, members ) :: rest ->
                                    if number == index // chunk then
                                        ( number, ( index, row ) :: members ) :: rest

                                    else
                                        ( index // chunk, [ ( index, row ) ] ) :: groups

                                [] ->
                                    [ ( index // chunk, [ ( index, row ) ] ) ]
                        )
                        []
        in
        List.concat
            [ spacerBody ctx "top" ctx.data.first
            , List.map
                (\( number, members ) ->
                    ( "chunk-" ++ String.fromInt number
                    , Html.Keyed.node "tbody"
                        [ Internal.cls [ "klar-table__body" ] ]
                        (List.concatMap (\( index, row ) -> viewRowAndDetail ctx index row) members)
                    )
                )
                chunks
            , spacerBody ctx "bottom" after
            ]

    else
        [ ( "body", viewBody ctx ) ]


{-| The room of the rows of a table that scrolls that are not drawn.
-}
spacerBody : Ctx row msg -> String -> Int -> List ( String, Html msg )
spacerBody ctx place count =
    if count <= 0 then
        []

    else
        [ ( "spacer-" ++ place
          , Html.tbody [ Internal.cls [ "klar-table__spacer-body" ], Attr.attribute "aria-hidden" "true" ]
                [ Html.tr [ Internal.styleVars [ ( "height", Internal.px (count * ctx.geometry.rowHeight) ) ] ]
                    [ Html.td [ Attr.colspan ctx.colCount ] [] ]
                ]
          )
        ]


{-| A click on the retry button (the error state has no other control).
-}
retryClicked : Ctx row msg -> Decoder msg
retryClicked ctx =
    Decode.field "target" (startsOnControl 0)
        |> Decode.andThen
            (\onControl ->
                if onControl then
                    Decode.succeed (ctx.toMsg RetryClicked)

                else
                    Decode.fail "not the retry button"
            )


stateRow : Ctx row msg -> Html msg -> Html msg
stateRow ctx content =
    Html.tr [ Internal.cls [ "klar-table__state-row" ], gridPart ctx "row" ]
        [ Html.td [ Internal.cls [ "klar-table__state-cell" ], Attr.colspan ctx.colCount, gridPart ctx "gridcell" ]
            [ Html.div [ Internal.cls [ "klar-table__state" ] ] [ content ] ]
        ]


{-| Are rows left out by the search or a filter? In client mode: there are rows
before filtering. In server mode: a search or filter is in effect.
-}
isFiltered : Ctx row msg -> Bool
isFiltered ctx =
    not (String.isEmpty ctx.model.search)
        || not (Dict.isEmpty ctx.model.filters)
        || (ctx.config.externalFilters > 0)
        || (ctx.config.server == Nothing && ctx.data.available > 0)


viewEmpty : Ctx row msg -> Html msg
viewEmpty ctx =
    let
        t =
            ctx.t

        filtered =
            isFiltered ctx
    in
    if ctx.data.total > 0 then
        EmptyState.view
            [ EmptyState.compact
            , EmptyState.icon Icon.fileText
            , EmptyState.title t.emptyPage
            , EmptyState.description t.emptyPageDescription
            , EmptyState.actions [ Button.view [ Button.onClick (ctx.toMsg FirstPageClicked) ] t.firstPage ]
            ]

    else if filtered then
        EmptyState.view
            [ EmptyState.compact
            , EmptyState.icon Icon.search
            , EmptyState.title t.noMatches
            , EmptyState.description t.noMatchesDescription
            , EmptyState.actions [ resetFiltersButton ctx [] t.clearSearchAndFilters AllCleared ]
            ]

    else
        EmptyState.view
            ([ EmptyState.compact
             , EmptyState.icon Icon.inbox
             , EmptyState.title t.noData
             , EmptyState.description t.noDataDescription
             ]
                ++ ctx.config.emptyState
            )


skeletonRows : Ctx row msg -> List ( String, Html msg )
skeletonRows ctx =
    let
        count =
            if ctx.config.paged then
                clamp 1 100 ctx.model.pageSize

            else
                8
    in
    List.range 0 (count - 1)
        |> List.map (\i -> ( "skeleton-" ++ String.fromInt i, skeletonRow ctx i ))


skeletonRow : Ctx row msg -> Int -> Html msg
skeletonRow ctx i =
    let
        widthFor j col =
            let
                spread =
                    modBy 41 ((i * 37 + j * 61 + 17) * 13)
            in
            if col.numeric then
                30 + modBy 25 spread

            else
                45 + spread
    in
    Html.tr [ Internal.cls [ "klar-table__row", "klar-table__row--skeleton" ], Attr.attribute "aria-hidden" "true" ]
        (List.concat
            [ systemCells ctx (\_ -> [])
            , List.indexedMap
                (\j col ->
                    Html.td [ Internal.cls (dataCellClasses ctx j col), pinStyle ctx j ]
                        [ if col.controls then
                            Html.text ""

                          else
                            Skeleton.line (widthFor j col)
                        ]
                )
                ctx.visible
            , if ctx.hasMenu then
                [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--menu" ] ] [] ]

              else
                []
            ]
        )


{-| The select and expand cells, empty, for skeleton and footer rows.
-}
systemCells : Ctx row msg -> (String -> List (Html msg)) -> List (Html msg)
systemCells ctx content =
    let
        pinClass =
            if ctx.pinnedFirst then
                "klar-table__cell--pinned"

            else
                ""
    in
    List.concat
        [ if ctx.hasSelect then
            [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--select", pinClass ], systemPinStyle ctx 0, gridPart ctx "gridcell" ] (content "select") ]

          else
            []
        , if ctx.hasExpand then
            [ Html.td
                [ Internal.cls [ "klar-table__td", "klar-table__td--expand", pinClass ]
                , gridPart ctx "gridcell"
                , systemPinStyle ctx
                    (if ctx.hasSelect then
                        selectWidth

                     else
                        0
                    )
                ]
                (content "expand")
            ]

          else
            []
        ]


dataCellClasses : Ctx row msg -> Int -> ColumnConfig row msg -> List String
dataCellClasses ctx index col =
    [ "klar-table__td"
    , alignClass "klar-table__td" col.align
    , if col.numeric then
        "klar-tabular"

      else
        ""
    , if col.wrap then
        "klar-table__td--wrap"

      else
        ""
    , if col.controls then
        "klar-table__td--controls"

      else
        ""
    , if index == 0 && ctx.pinnedFirst then
        "klar-table__cell--pinned klar-table__cell--pin-edge"

      else
        ""
    ]


{-| The role of a row or cell in the tree grid of a table whose rows expand
(`row`, `columnheader`, `rowheader`, `gridcell`). Every other table is a plain
table, where the elements have their roles already.
-}
gridPart : Ctx row msg -> String -> Html.Attribute msg
gridPart ctx role =
    if isTreegrid ctx then
        Attr.attribute "role" role

    else
        Internal.noAttr


{-| A table whose rows take focus and expand is a `treegrid`, the ARIA pattern
where focus is on rows and ArrowRight and ArrowLeft expand and collapse them, as
here. Rows that only take focus (clickable, selectable, with a menu) keep the
semantics of a plain table: a `grid` would promise arrow keys between cells, and
a screen reader in a grid gives up reading the table cell by cell in browse mode.
-}
isTreegrid : Ctx row msg -> Bool
isTreegrid ctx =
    ctx.interactiveRows && ctx.hasExpand


pinStyle : Ctx row msg -> Int -> Html.Attribute msg
pinStyle ctx index =
    if index == 0 && ctx.pinnedFirst then
        Internal.styleVars [ ( "--_pin-left", Internal.px (pinLeft ctx) ) ]

    else
        Internal.noAttr


viewRowAndDetail : Ctx row msg -> Int -> row -> List ( String, Html msg )
viewRowAndDetail ctx index row =
    let
        key =
            ctx.keyOf (ctx.data.offset + index) row

        expanded =
            ctx.hasExpand && Set.member key ctx.model.expanded

        rowHtml =
            viewRow ctx index row key expanded
    in
    case ( expanded, ctx.config.expandedRow ) of
        ( True, Just render ) ->
            [ ( "row-" ++ key, rowHtml )
            , ( "detail-" ++ key
              , Html.tr
                    [ Internal.cls [ "klar-table__detail-row" ]
                    , Attr.id (detailDomId ctx.model.id index)
                    , gridPart ctx "row"

                    -- in the tree grid the details are the child of their row
                    , Internal.attrIf (isTreegrid ctx) (Attr.attribute "aria-level" "2")
                    ]
                    [ Html.td
                        [ Internal.cls [ "klar-table__detail" ]
                        , gridPart ctx "gridcell"
                        , Attr.colspan ctx.colCount
                        , Internal.styleVars [ ( "--_indent", Internal.px (pinLeft ctx) ) ]
                        ]
                        [ Html.div [ Internal.cls [ "klar-table__detail-inner" ] ] [ render row ] ]
                    ]
              )
            ]

        _ ->
            [ ( "row-" ++ key, rowHtml ) ]


viewRow : Ctx row msg -> Int -> row -> String -> Bool -> Html msg
viewRow ctx index row key expanded =
    let
        config =
            ctx.config

        model =
            ctx.model

        t =
            ctx.t

        disabled =
            rowIsDisabled config row

        selected =
            ctx.hasSelect && isPicked model.selection key

        current =
            case config.currentRow of
                Just isCurrent ->
                    isCurrent row

                Nothing ->
                    False

        tone =
            config.rowTone |> Maybe.andThen (\toTone -> toTone row)

        domId =
            rowDomId model.id index

        name =
            ctx.labelOf row

        clickMsg =
            if disabled then
                Nothing

            else
                case config.onRowClick of
                    Just toMsg ->
                        Just (toMsg row)

                    Nothing ->
                        if ctx.hasExpand then
                            Just (ctx.toMsg (ExpandToggled key))

                        else
                            Nothing

        menuItems =
            case config.rowActions of
                Just toItems ->
                    toItems row

                Nothing ->
                    []

        menuId =
            model.id ++ "-menu-" ++ String.fromInt index

        -- where focus goes if the menu's own button is gone when it closes
        -- (the action removed the row)
        fallback =
            (menuId ++ "-trigger")
                :: (if ctx.interactiveRows then
                        [ domId ]

                    else
                        []
                   )
                ++ [ scrollDomId model.id ]

        -- One tab stop for the rows: the row that has (or last had) the focus
        -- keeps the tab stops of its own controls, the checkbox and the menu
        -- button. The other rows are reached with the arrow keys, instead of
        -- making a keyboard user tab through 25 or 50 checkboxes and menus.
        tabStop =
            if ctx.interactiveRows && index /= ctx.activeRow then
                Just -1

            else
                Nothing

        info =
            { index = index
            , key = key
            , domId = domId
            , disabled = disabled
            , selected = selected
            , expanded = expanded
            , click = clickMsg
            , menu =
                -- a disabled row has a menu button that cannot be used, and no
                -- key opens its menu either
                if disabled || List.isEmpty menuItems then
                    Nothing

                else
                    Just (ctx.toMsg (RowMenuOpened key menuId fallback))
            , menuTrigger = menuId ++ "-trigger"
            }

        pinClass =
            if ctx.pinnedFirst then
                "klar-table__cell--pinned"

            else
                ""

        selectCell =
            if ctx.hasSelect then
                [ Html.td
                    [ Internal.cls [ "klar-table__td", "klar-table__td--select", "klar-table__td--control", pinClass ]
                    , systemPinStyle ctx 0
                    , gridPart ctx "gridcell"
                    , if disabled then
                        Internal.noAttr

                      else
                        rangeClick ctx key selected
                    ]
                    [ Checkbox.view
                        (List.filterMap identity
                            [ Just (Checkbox.ariaLabel (t.selectRow name))
                            , Just (Checkbox.checked selected)
                            , Just (Checkbox.disabled disabled)
                            , if disabled then
                                Nothing

                              else
                                Just (Checkbox.onCheck (\value -> ctx.toMsg (RowSelected key value)))
                            , Maybe.map Checkbox.tabIndex tabStop
                            ]
                        )
                    ]
                ]

            else
                []

        expandCell =
            if ctx.hasExpand then
                [ Html.td
                    [ Internal.cls [ "klar-table__td", "klar-table__td--expand", "klar-table__td--control", pinClass ]
                    , gridPart ctx "gridcell"
                    , systemPinStyle ctx
                        (if ctx.hasSelect then
                            selectWidth

                         else
                            0
                        )
                    ]
                    [ Html.button
                        [ Internal.cls
                            [ "klar-table__expand"
                            , if expanded then
                                "klar-table__expand--open"

                              else
                                ""
                            ]
                        , Attr.type_ "button"
                        , Attr.tabindex -1
                        , Attr.disabled disabled

                        -- as on the row: a disabled row cannot open its details, so
                        -- its button does not say they are closed (only that they are open)
                        , Internal.attrIf (expanded || not disabled)
                            (Attr.attribute "aria-expanded"
                                (if expanded then
                                    "true"

                                 else
                                    "false"
                                )
                            )
                        , Internal.attrIf expanded (Attr.attribute "aria-controls" (detailDomId model.id index))
                        , Attr.attribute "aria-label"
                            (if expanded then
                                t.hideDetails name

                             else
                                t.showDetails name
                            )
                        , Attr.title
                            (if expanded then
                                t.hideDetails name

                             else
                                t.showDetails name
                            )
                        , Internal.attrIf (not disabled) (Events.onClick (ctx.toMsg (ExpandToggled key)))
                        ]
                        [ Icon.sized Icon.Small Icon.chevronRight ]
                    ]
                ]

            else
                []

        menuCell =
            case config.rowActions of
                Just _ ->
                    let
                        -- the menu of a disabled row stays closed, also when it
                        -- was open when the row became disabled
                        menuState =
                            case model.rowMenu of
                                Just ( openKey, state ) ->
                                    if openKey == key && not disabled then
                                        state

                                    else
                                        Menu.init menuId

                                Nothing ->
                                    Menu.init menuId

                        tabIndexAttrs =
                            case tabStop of
                                Just n ->
                                    [ Attr.tabindex n ]

                                Nothing ->
                                    []
                    in
                    [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--menu", "klar-table__td--control" ], gridPart ctx "gridcell" ]
                        [ if List.isEmpty menuItems then
                            Html.text ""

                          else if disabled then
                            -- The trigger of a menu tells only when it is clicked whether it
                            -- is unavailable. A disabled row gets the same button without the
                            -- menu: disabled, it sends nothing and has nothing to open.
                            Html.div [ Internal.cls [ "klar-anchor", "klar-menu" ] ]
                                [ Button.iconOnly
                                    (Button.ghost
                                        :: Button.small
                                        :: Button.disabled True
                                        :: Button.id (Menu.triggerId menuState)
                                        :: Button.htmlAttrs (Attr.attribute "aria-haspopup" "menu" :: tabIndexAttrs)
                                        :: []
                                    )
                                    Icon.moreVertical
                                    (t.rowActions name)
                                ]

                          else
                            Menu.view (\menuMsg -> ctx.toMsg (RowMenu key menuId fallback menuMsg))
                                [ Menu.kebab (t.rowActions name)
                                , Menu.alignEnd
                                , Menu.trigger [ Button.small, Button.htmlAttrs tabIndexAttrs ]
                                , Menu.items menuItems
                                ]
                                menuState
                        ]
                    ]

                Nothing ->
                    []

        rowAttributes =
            List.concat
                [ [ Internal.cls
                        [ "klar-table__row"
                        , if ctx.config.zebra && modBy 2 index == 1 then
                            "klar-table__row--alt"

                          else
                            ""
                        , if selected then
                            "klar-table__row--selected"

                          else
                            ""
                        , if disabled then
                            "klar-table__row--disabled"

                          else
                            ""
                        , if isJust clickMsg then
                            "klar-table__row--clickable"

                          else
                            ""
                        , if expanded then
                            "klar-table__row--expanded"

                          else
                            ""
                        , if current then
                            "klar-table__row--current"

                          else
                            ""
                        , case tone of
                            Just value ->
                                "klar-table__row--tone klar-table__row--" ++ Internal.toneSuffix value

                            Nothing ->
                                ""
                        ]
                  , Attr.id domId
                  , Attr.attribute "aria-rowindex" (String.fromInt (ctx.data.offset + index + 2))
                  , Internal.attrIf ctx.hasSelect
                        (Attr.attribute "aria-selected"
                            (if selected then
                                "true"

                             else
                                "false"
                            )
                        )
                  , Internal.attrIf disabled (Attr.attribute "aria-disabled" "true")
                  , Internal.attrIf current (Attr.attribute "aria-current" "true")
                  , gridPart ctx "row"

                  -- a tree grid tells on the row whether its details are open; a
                  -- disabled row cannot open them, so it says nothing (unless they are open)
                  , Internal.attrIf (isTreegrid ctx) (Attr.attribute "aria-level" "1")
                  , Internal.attrIf (isTreegrid ctx && (expanded || not disabled))
                        (Attr.attribute "aria-expanded"
                            (if expanded then
                                "true"

                             else
                                "false"
                            )
                        )
                  ]
                , if ctx.interactiveRows then
                    [ Attr.tabindex
                        (if index == ctx.activeRow then
                            0

                         else
                            -1
                        )
                    , -- focusin, not focus: it also tells when a control in the row got the focus
                      Events.on "focusin" (Decode.succeed (ctx.toMsg (RowFocused index)))
                    , Events.preventDefaultOn "keydown" (rowKeys ctx info)
                    , Events.preventDefaultOn "contextmenu" (rowContextMenu info)
                    ]

                  else
                    []
                , case clickMsg of
                    Just msg ->
                        [ Events.on "click" (ignoreControls msg) ]

                    Nothing ->
                        []
                ]
    in
    Html.tr rowAttributes
        (List.concat
            [ selectCell
            , expandCell
            , List.indexedMap (viewCell ctx row) ctx.visible
            , menuCell
            ]
        )


viewCell : Ctx row msg -> row -> Int -> ColumnConfig row msg -> Html msg
viewCell ctx row index col =
    let
        value =
            col.value ctx.loc row

        blank =
            String.isEmpty (String.trim value)

        content =
            case col.cell of
                Just render ->
                    [ render ctx.loc row ]

                Nothing ->
                    if blank then
                        [ Html.span [ Internal.cls [ "klar-table__empty" ] ] [ Html.text "–" ] ]

                    else if col.searchable && not (String.isEmpty ctx.model.search) then
                        Search.highlight ctx.model.search value

                    else
                        [ Html.text value ]
    in
    Html.td
        [ Internal.cls (dataCellClasses ctx index col)
        , pinStyle ctx index
        , gridPart ctx
            (if index == 0 then
                "rowheader"

             else
                "gridcell"
            )
        , Internal.attrIf (col.tooltip && not blank && not (isJust col.cell)) (Attr.title value)
        ]
        [ Html.div [ Internal.cls [ "klar-table__cell" ] ] content ]


{-| The keys a Shift range runs over, in the order of the table: the rows of the
page that can be selected, or every matching one in a client table that scrolls.
Only asked for when the user makes a range.
-}
rangeKeys : Ctx row msg -> List String
rangeKeys ctx =
    if isLongClientTable ctx then
        selectableKeys ctx

    else
        ctx.pageKeys


{-| The message of a Shift range that ends on this row, which gets the state the
row is about to get (`checked`), as in a mail client; `Nothing` without an anchor
on this page.
-}
rangeMsg : Ctx row msg -> String -> Bool -> Maybe msg
rangeMsg ctx key checked =
    ctx.model.anchor
        |> Maybe.andThen (\anchorKey -> keysBetween anchorKey key (rangeKeys ctx))
        |> Maybe.map (\keys -> ctx.toMsg (RangeSelected keys checked key))


{-| Shift+click on the checkbox of a row (or its cell): the rows from the anchor
to this one take the state this one is about to get. The checkbox itself sends the
same state for its own row right after.
-}
rangeClick : Ctx row msg -> String -> Bool -> Html.Attribute msg
rangeClick ctx key selected =
    if ctx.model.anchor == Nothing || ctx.model.anchor == Just key then
        Internal.noAttr

    else
        Events.on "click"
            (Decode.field "shiftKey" Decode.bool
                |> Decode.andThen
                    (\shift ->
                        if shift then
                            case rangeMsg ctx key (not selected) of
                                Just msg ->
                                    Decode.succeed msg

                                Nothing ->
                                    Decode.fail "the anchor is not among these rows"

                        else
                            Decode.fail "not a range"
                    )
            )


type alias RowInfo msg =
    { index : Int
    , key : String
    , domId : String
    , disabled : Bool
    , selected : Bool
    , expanded : Bool
    , click : Maybe msg
    , menu : Maybe msg
    , menuTrigger : String
    }


{-| Keys on a focused row, and the keys that move between rows on its checkbox
and its menu button.
-}
rowKeys : Ctx row msg -> RowInfo msg -> Decoder ( msg, Bool )
rowKeys ctx info =
    Decode.map5 (\key targetId command alt shift -> { key = key, targetId = targetId, command = command, alt = alt, shift = shift })
        (Decode.field "key" Decode.string)
        (Decode.oneOf [ Decode.at [ "target", "id" ] Decode.string, Decode.succeed "" ])
        (Decode.map2 (||)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
        )
        (Decode.field "altKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        |> Decode.andThen
            (\event ->
                if event.targetId /= info.domId then
                    -- On the row's checkbox or menu button the keys that move to other
                    -- rows still work, unless the control used the key itself (the
                    -- menu button opens its menu with ArrowDown).
                    if List.member event.key [ "ArrowDown", "ArrowUp", "Home", "End", "PageDown", "PageUp" ] && not event.command && not event.alt then
                        Decode.map2 Tuple.pair
                            (Decode.oneOf [ Decode.at [ "target", "type" ] Decode.string, Decode.succeed "" ])
                            (Decode.oneOf [ Decode.field "defaultPrevented" Decode.bool, Decode.succeed False ])
                            |> Decode.andThen
                                (\( targetType, prevented ) ->
                                    if not prevented && (targetType == "checkbox" || event.targetId == info.menuTrigger) then
                                        case rowKeyMsg ctx info event.key event.shift of
                                            Just msg ->
                                                Decode.succeed ( msg, True )

                                            Nothing ->
                                                Decode.fail "unhandled key"

                                    else
                                        Decode.fail "not on a control of the row"
                                )

                    else
                        Decode.fail "not on the row"

                else if event.command && not event.alt && String.toLower event.key == "a" && ctx.hasSelect then
                    -- Ctrl+A (Cmd+A): every row of the page, or every matching row of a table that scrolls
                    Decode.succeed ( ctx.toMsg (RowsSelected (rangeKeys ctx) True), True )

                else if event.command || event.alt then
                    Decode.fail "a key with Ctrl, Cmd or Alt"

                else
                    case rowKeyMsg ctx info event.key event.shift of
                        Just msg ->
                            Decode.succeed ( msg, True )

                        Nothing ->
                            Decode.fail "unhandled key"
            )


{-| The menu key and Shift+F10 can also arrive as a `contextmenu` event, which
the browser answers with its own menu unless the page does something with it.
That event has `button` 0 when it comes from the keyboard (or a long press) and
2 from a right click, which keeps the browser's menu.
-}
rowContextMenu : RowInfo msg -> Decoder ( msg, Bool )
rowContextMenu info =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                case ( button, info.menu ) of
                    ( 0, Just msg ) ->
                        Decode.succeed ( msg, True )

                    _ ->
                        Decode.fail "a right click, or a row without a menu"
            )


rowKeyMsg : Ctx row msg -> RowInfo msg -> String -> Bool -> Maybe msg
rowKeyMsg ctx info key shift =
    let
        focusRow target =
            if target >= 0 && target < ctx.rowCount && target /= info.index then
                if ctx.config.virtual then
                    Just (ctx.toMsg (FocusVirtualRow target (rowDomId ctx.model.id target) ctx.geometry))

                else
                    Just (ctx.toMsg (FocusRow target (rowDomId ctx.model.id target)))

            else
                Just (ctx.toMsg NoOp)

        -- ten rows at a time, or a screenful when the table scrolls; otherwise the
        -- page scrolls away from the focused row
        jump =
            if ctx.config.virtual then
                Window.rowsPerScreen ctx.geometry

            else
                10
    in
    case key of
        "ArrowDown" ->
            focusRow (info.index + 1)

        "ArrowUp" ->
            focusRow (info.index - 1)

        "Home" ->
            focusRow 0

        "End" ->
            focusRow (ctx.rowCount - 1)

        "PageDown" ->
            focusRow (min (ctx.rowCount - 1) (info.index + jump))

        "PageUp" ->
            focusRow (max 0 (info.index - jump))

        "Enter" ->
            case info.click of
                Just msg ->
                    Just msg

                Nothing ->
                    -- a row that does nothing else when clicked opens its menu
                    if isJust ctx.config.onRowClick || ctx.hasExpand then
                        Nothing

                    else
                        info.menu

        -- the context menu key and Shift+F10: the row's "more" menu
        "ContextMenu" ->
            info.menu

        "F10" ->
            if shift then
                info.menu

            else
                Nothing

        " " ->
            if ctx.hasSelect && not info.disabled then
                -- Shift+Space: the rows from the anchor to this one
                case
                    if shift then
                        rangeMsg ctx info.key (not info.selected)

                    else
                        Nothing
                of
                    Just msg ->
                        Just msg

                    Nothing ->
                        Just (ctx.toMsg (RowSelected info.key (not info.selected)))

            else
                Nothing

        "ArrowRight" ->
            if ctx.hasExpand && not info.expanded && not info.disabled then
                Just (ctx.toMsg (ExpandToggled info.key))

            else
                Nothing

        "ArrowLeft" ->
            if ctx.hasExpand && info.expanded && not info.disabled then
                Just (ctx.toMsg (ExpandToggled info.key))

            else
                Nothing

        _ ->
            Nothing


{-| A row click, unless it started on a control inside the row (a button, a
link, a checkbox, a menu, an inline action).
-}
ignoreControls : msg -> Decoder msg
ignoreControls msg =
    Decode.field "target" (startsOnControl 0)
        |> Decode.andThen
            (\onControl ->
                if onControl then
                    Decode.fail "click on a control"

                else
                    Decode.succeed msg
            )


startsOnControl : Int -> Decoder Bool
startsOnControl depth =
    Decode.map2 Tuple.pair
        (Decode.oneOf [ Decode.field "tagName" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "className" Decode.string, Decode.succeed "" ])
        |> Decode.andThen
            (\( tag, className ) ->
                if tag == "" || tag == "TR" || tag == "TABLE" || depth > 20 then
                    Decode.succeed False

                else if
                    List.member tag [ "A", "BUTTON", "INPUT", "SELECT", "TEXTAREA", "LABEL", "SUMMARY" ]
                        || String.contains "klar-anchor" className
                        || String.contains "klar-layer" className
                        || String.contains "klar-table__td--control" className
                then
                    Decode.succeed True

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.lazy (\_ -> startsOnControl (depth + 1)))
                        , Decode.succeed False
                        ]
            )


viewFoot : Ctx row msg -> Html msg
viewFoot ctx =
    if ctx.data.status /= Ready || not (List.any hasFooter ctx.visible) || ctx.data.total == 0 then
        Html.text ""

    else
        let
            matched =
                ctx.data.matchingRows
        in
        Html.tfoot [ Internal.cls [ "klar-table__foot" ] ]
            [ Html.tr [ gridPart ctx "row" ]
                (List.concat
                    [ systemCells ctx (\_ -> [])
                    , List.indexedMap
                        (\index col ->
                            Html.td [ Internal.cls (dataCellClasses ctx index col), pinStyle ctx index, gridPart ctx "gridcell" ]
                                [ Html.div [ Internal.cls [ "klar-table__cell" ] ] (footerContent ctx matched index col) ]
                        )
                        ctx.visible
                    , if ctx.hasMenu then
                        [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--menu" ], gridPart ctx "gridcell" ] [] ]

                      else
                        []
                    ]
                )
            ]


footerContent : Ctx row msg -> (() -> List row) -> Int -> ColumnConfig row msg -> List (Html msg)
footerContent ctx matched index col =
    let
        t =
            ctx.t

        numbers () =
            case col.number of
                Just toNumber ->
                    List.filterMap toNumber (matched ())

                Nothing ->
                    []

        -- the sum and the count, kept by prepared rows while no row is left out
        totals () =
            case ctx.data.totals col.id of
                Just kept ->
                    kept

                Nothing ->
                    let
                        values =
                            numbers ()
                    in
                    { sum = List.sum values, count = List.length values }

        aggregate name value =
            [ Html.span [ Internal.cls [ "klar-table__aggregate-label" ] ] [ Html.text name ]
            , Html.span [ Internal.cls [ "klar-table__aggregate" ] ] [ Html.text value ]
            ]

        -- a money column: exact totals, one for each currency (kept by prepared
        -- rows while no row is left out, so that a scroll adds up nothing again)
        moneyAggregate name toValue toMoney =
            case
                ctx.data.moneyTotals col.id
                    |> Maybe.withDefault (moneyTotals toMoney (matched ()))
            of
                [] ->
                    aggregate name "–"

                groups ->
                    aggregate name
                        (groups
                            |> List.map (\group -> Maybe.withDefault "–" (Maybe.map (Money.toString ctx.loc) (Maybe.andThen (toValue group.count) group.total)))
                            |> String.join " · "
                        )
    in
    case ( col.footer, col.money ) of
        ( Just FooterSum, Just toMoney ) ->
            moneyAggregate t.sum (\_ total -> Just total) toMoney

        ( Just FooterAverage, Just toMoney ) ->
            moneyAggregate t.average (\count total -> Result.toMaybe (Money.fraction 1 count total)) toMoney

        ( Just FooterSum, Nothing ) ->
            aggregate t.sum (formatNumber ctx.loc col.decimals (totals ()).sum)

        ( Just FooterAverage, Nothing ) ->
            let
                kept =
                    totals ()
            in
            if kept.count == 0 then
                aggregate t.average "–"

            else
                aggregate t.average (Format.decimal ctx.loc (max 1 col.decimals) (kept.sum / toFloat kept.count))

        ( Just (FooterCustom summarize), _ ) ->
            [ Html.text (summarize (matched ())) ]

        ( Nothing, _ ) ->
            if index == 0 then
                [ Html.span [ Internal.cls [ "klar-table__aggregate-label" ] ] [ Html.text t.total ] ]

            else
                []



-- FOOTER


{-| The pagination, in every state of a server-mode table once a total is known.
A page that is loading or failed must not take the pagination away: the user
is often on one of its controls (the page they just asked for, the page size),
and a control that disappears drops keyboard focus to the page. The range
("1–25 of 3,000") is not shown then, because it describes rows that are not
on screen; the other pages can still be tried.
-}
viewFooter : Ctx row msg -> Html msg
viewFooter ctx =
    if not ctx.config.paged then
        if ctx.config.virtual then
            viewRange ctx

        else
            Html.text ""

    else
        let
            totalKnown =
                ctx.config.server /= Nothing && ctx.data.total > 0
        in
        case ctx.data.status of
            Failed _ ->
                if totalKnown then
                    viewPagination ctx (Just [])

                else
                    Html.text ""

            Waiting ->
                let
                    loading =
                        -- announced by the table's own live region, so hidden here
                        Html.span [ Internal.cls [ "klar-table__footer-loading" ], Attr.attribute "aria-hidden" "true" ]
                            [ Spinner.view [ Spinner.size Theme.Small ]
                            , Html.text ctx.t.loading
                            ]
                in
                if totalKnown then
                    viewPagination ctx (Just [ loading ])

                else
                    Html.div [ Internal.cls [ "klar-table__footer" ] ] [ loading ]

            Ready ->
                if ctx.data.total == 0 && not (isFiltered ctx) then
                    -- nothing at all: no pagination to show
                    Html.text ""

                else
                    viewPagination ctx Nothing


{-| The rows in view of a long table, "Showing 1-24 of 50,000 rows". It is
for the eye only: the live region of the table does not repeat it while the
user scrolls, and every row says its place (`aria-rowindex`).
-}
viewRange : Ctx row msg -> Html msg
viewRange ctx =
    if ctx.data.status /= Ready || ctx.data.total == 0 then
        Html.text ""

    else
        let
            top =
                Window.clampScroll ctx.geometry ctx.model.scroll

            -- the rows that are in view in full
            first =
                clamp 1 ctx.data.total (ceiling (top / toFloat ctx.geometry.rowHeight) + 1)

            last =
                clamp first ctx.data.total (floor ((top + toFloat ctx.geometry.viewport) / toFloat ctx.geometry.rowHeight))
        in
        Html.div [ Internal.cls [ "klar-table__footer" ], Attr.attribute "aria-hidden" "true" ]
            [ Html.span [ Internal.cls [ "klar-table__footer-range", "klar-tabular" ] ]
                [ Html.text (Maybe.withDefault ctx.t.summary ctx.config.rangeText first last ctx.data.total) ]
            ]


{-| `summary` replaces the range text (a loading message, or nothing).
-}
viewPagination : Ctx row msg -> Maybe (List (Html msg)) -> Html msg
viewPagination ctx summary =
    Html.div [ Internal.cls [ "klar-table__footer" ] ]
        [ Pagination.view
            (List.filterMap identity
                [ Just (Pagination.id (ctx.model.id ++ "-pagination"))
                , Just (Pagination.onPage (\n -> ctx.toMsg (PageChanged n)))
                , Just (Pagination.onPageSize (\n -> ctx.toMsg (PageSizeChanged n)))
                , Just (Pagination.pageSizes ctx.config.pageSizes)
                , Just Pagination.jumpToPage
                , Just (Pagination.locale ctx.loc)
                , Maybe.map Pagination.rangeText ctx.config.rangeText
                , -- the landmark is named after the table, so that two tables on a page are told apart
                  Maybe.map (\name -> Pagination.ariaLabel (ctx.t.pagination name)) (Internal.nonEmpty (Maybe.withDefault "" ctx.config.label))
                , Maybe.map Pagination.summary summary
                ]
            )
            { page = ctx.data.page, pageSize = ctx.model.pageSize, total = ctx.data.total }
        ]
