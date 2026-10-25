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


columnId : String -> ColumnId
columnId =
    ColumnId


columnName : ColumnId -> String
columnName (ColumnId text_) =
    text_


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


query : State id -> Query
query (State model) =
    { search = model.search
    , sort = List.map (\( id, direction ) -> ( ColumnId id, direction )) model.sort
    , filters = List.map (\( id, f ) -> ( ColumnId id, f )) (Dict.toList model.filters)
    , page = model.page
    , pageSize = model.pageSize
    }


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


sort : State id -> List ( ColumnId, Direction )
sort (State model) =
    List.map (\( id, direction ) -> ( ColumnId id, direction )) model.sort


setSort : List ( ColumnId, Direction ) -> State id -> State id
setSort value (State model) =
    State { model | sort = List.map (\( ColumnId id, direction ) -> ( id, direction )) value, page = 1 }


page : State id -> Int
page (State model) =
    model.page


{-| Goes to this page. The first page is 1; smaller numbers count as 1.
-}
setPage : Int -> State id -> State id
setPage value (State model) =
    State { model | page = max 1 value }


pageSize : State id -> Int
pageSize (State model) =
    model.pageSize


setPageSize : Int -> State id -> State id
setPageSize value (State model) =
    State { model | pageSize = max 1 value, page = 1 }


search : State id -> String
search (State model) =
    model.search


setSearch : String -> State id -> State id
setSearch value (State model) =
    State (settled model { model | searchInput = value, search = String.trim value, page = 1 })


filters : State id -> List ( ColumnId, Filter )
filters (State model) =
    List.map (\( id, f ) -> ( ColumnId id, f )) (Dict.toList model.filters)


setFilter : ColumnId -> Maybe Filter -> State id -> State id
setFilter (ColumnId colId) maybeFilter (State model) =
    case maybeFilter of
        Just f ->
            State (settled model { model | filters = Dict.insert colId f model.filters, inputs = Dict.insert colId (toDraft f) model.inputs, page = 1 })

        Nothing ->
            State (settled model { model | filters = Dict.remove colId model.filters, inputs = Dict.remove colId model.inputs, page = 1 })


clearFilters : State id -> State id
clearFilters (State model) =
    State (settled model { model | filters = Dict.empty, inputs = Dict.empty, search = "", searchInput = "", page = 1 })


density : State id -> Density
density (State model) =
    model.density


setDensity : Density -> State id -> State id
setDensity value (State model) =
    State { model | density = value }


expandedIds : Ids id -> State id -> List id
expandedIds ids (State model) =
    idsOf ids model.expanded


{-| Is the row with this id expanded?
-}
isExpanded : Ids id -> id -> State id -> Bool
isExpanded ids id (State model) =
    Set.member (Ids.toKey ids id) model.expanded


expand : Ids id -> id -> State id -> State id
expand ids id (State model) =
    State { model | expanded = Set.insert (Ids.toKey ids id) model.expanded }


{-| Collapses the row with this id.
-}
collapse : Ids id -> id -> State id -> State id
collapse ids id (State model) =
    State { model | expanded = Set.remove (Ids.toKey ids id) model.expanded }


toggle : Ids id -> id -> State id -> State id
toggle ids id (State model) =
    State { model | expanded = toggled (Ids.toKey ids id) model.expanded }


setExpandedIds : Ids id -> List id -> State id -> State id
setExpandedIds ids values (State model) =
    State { model | expanded = Set.fromList (keysOf ids values) }


{-| Collapses every row.
-}
collapseAll : State id -> State id
collapseAll (State model) =
    State { model | expanded = Set.empty }


isColumnVisible : ColumnId -> State id -> Maybe Bool
isColumnVisible (ColumnId colId) (State model) =
    Dict.get colId model.visibility


setColumnVisible : ColumnId -> Bool -> State id -> State id
setColumnVisible (ColumnId colId) value (State model) =
    State { model | visibility = Dict.insert colId value model.visibility }
