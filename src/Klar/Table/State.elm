module Klar.Table.State exposing (..)

{-| Table initialization, query accessors and explicit state setters.
-}

import Dict exposing (Dict)
import Klar.Ids as Ids exposing (Ids)
import Klar.Table.Filter exposing (toDraft)
import Klar.Table.Identity exposing (idsOf, keysOf, toggled)
import Klar.Table.Selection exposing (dropAllMatchingOf, selection)
import Klar.Table.Types exposing (ColumnId(..), Direction(..), Filter(..), Model, Picked(..), Popup(..), Query, State(..))
import Klar.Theme as Theme exposing (Density(..))
import Set exposing (Set)


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
