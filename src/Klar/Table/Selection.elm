module Klar.Table.Selection exposing (..)

{-| Pure row-selection operations, disabled-row decisions and matching-row counts.
-}

import Klar.Ids as Ids exposing (Ids)
import Klar.Table.Identity exposing (idsOf, isJust, keysOf)
import Klar.Table.Types exposing (Config, Ctx, Picked(..), Selection(..), State(..))
import Set exposing (Set)


dropAllMatchingOf : Picked -> Picked
dropAllMatchingOf picked =
    case picked of
        AllPicked _ ->
            Picked Set.empty

        other ->
            other


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


selectionTotal : Ctx row msg -> Int
selectionTotal ctx =
    case ctx.model.selection of
        Picked keys ->
            Set.size keys

        AllPicked except ->
            max 0 (ctx.data.total - Set.size except)


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
