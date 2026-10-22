module Klar.PermissionMatrix.Grid exposing
    ( ColumnKey(..)
    , Item
    , Key(..)
    , Layout
    , Row(..)
    , RowKey(..)
    , Size
    , Summary(..)
    , columnToken
    , domId
    , layout
    , move
    , rowToken
    , shouldGrant
    , summarize
    )

{-| The pure parts of `Klar.PermissionMatrix`: which rows are shown (groups, the
filter, collapsed groups, the cap), where the arrow keys lead, and what a header
checkbox means. Nothing here knows `Html`; everything is tested without a browser.
-}

import Dict exposing (Dict)
import Klar.Internal as Internal
import Set exposing (Set)



-- KEYS: WHERE A CELL IS, WRITTEN AS DATA


{-| A row of the grid: the header row, a group row (by group name) or the row of
a permission (by its key).
-}
type RowKey
    = HeaderKey
    | GroupKey String
    | PermissionKey String


{-| A column of the grid: the first column that names the rows, or the column of a
role (by its key).
-}
type ColumnKey
    = LabelKey
    | RoleKey String


{-| The row as text, without a character that `domId` uses to separate parts.
-}
rowToken : RowKey -> String
rowToken key =
    case key of
        HeaderKey ->
            "h"

        GroupKey name ->
            "g" ++ Internal.percentEncode name

        PermissionKey permission ->
            "p" ++ Internal.percentEncode permission


columnToken : ColumnKey -> String
columnToken key =
    case key of
        LabelKey ->
            "l"

        RoleKey role ->
            "r" ++ Internal.percentEncode role


{-| The DOM id of a cell: the id of the matrix, then the row, then the column.
`percentEncode` never writes a slash, so two different cells never share an id.
-}
domId : String -> RowKey -> ColumnKey -> String
domId matrixId row column =
    matrixId ++ "/" ++ rowToken row ++ "/" ++ columnToken column



-- ROWS


{-| One permission, as far as the layout needs to know it: its place in the list
the application gave, its label and its group, if it has one.
-}
type alias Item =
    { index : Int
    , label : String
    , group : Maybe String
    }


{-| A row that is drawn: a group row with the places of the permissions of the
group that match the filter, or the row of one permission (by its place).
-}
type Row
    = GroupRow String (List Int)
    | PermissionRow Int


type alias Layout =
    { rows : List Row
    , matches : List Int
    , total : Int
    , truncated : Bool

    -- how many permission rows the cap cut off (rows of folded groups are not cut, they are folded)
    , cutRows : Int
    }


{-| The rows to draw.

  - Permissions are gathered by group, groups in the order in which they first
    appear, permissions in the order given. Permissions without a group stay together
    where the first of them appeared and have no group row.
  - With a `query`, only permissions whose group and label contain every word are
    kept (case and accents do not matter), and every group that has a match is open
    whether or not it was collapsed.
  - Without one, a collapsed group shows its group row only.
  - At most `maxRows` permission rows are drawn; `truncated` says that rows were cut.

`matches` are the places of all permissions that match the query, shown or not (a
collapsed group, a row beyond the cap): a header checkbox acts on all of them.

-}
layout : { query : String, collapsed : Set String, maxRows : Int } -> List Item -> Layout
layout options items =
    let
        words =
            -- `String.words` of nothing is one empty word
            String.words (Internal.normalize options.query)
                |> List.filter (\word -> word /= "")

        filtering =
            not (List.isEmpty words)

        matching item =
            let
                haystack =
                    Internal.normalize (Maybe.withDefault "" item.group ++ " " ++ item.label)
            in
            List.all (\word -> String.contains word haystack) words

        sections =
            gather items

        rows =
            sections
                |> List.concatMap
                    (\( name, members ) ->
                        let
                            kept =
                                List.filter matching members
                                    |> List.map .index
                        in
                        if List.isEmpty kept then
                            []

                        else
                            case name of
                                Nothing ->
                                    List.map PermissionRow kept

                                Just groupName ->
                                    GroupRow groupName kept
                                        :: (if Set.member groupName options.collapsed && not filtering then
                                                []

                                            else
                                                List.map PermissionRow kept
                                           )
                    )

        ( shown, truncated ) =
            capRows (max 0 options.maxRows) rows
    in
    { rows = shown
    , matches = List.filter matching items |> List.map .index
    , total = List.length items
    , truncated = truncated
    , cutRows = permissionRows rows - permissionRows shown
    }


{-| The permissions of each group, the groups in the order of their first
permission; the permissions without a group are one section (with no name).
-}
gather : List Item -> List ( Maybe String, List Item )
gather items =
    let
        key item =
            Maybe.withDefault "" item.group

        order =
            List.foldl
                (\item seen ->
                    if List.member (key item) seen then
                        seen

                    else
                        key item :: seen
                )
                []
                items
                |> List.reverse

        byKey : Dict String (List Item)
        byKey =
            List.foldr
                (\item dict ->
                    Dict.update (key item)
                        (\existing -> Just (item :: Maybe.withDefault [] existing))
                        dict
                )
                Dict.empty
                items
    in
    List.map
        (\name ->
            ( if name == "" then
                Nothing

              else
                Just name
            , Dict.get name byKey |> Maybe.withDefault []
            )
        )
        order


permissionRows : List Row -> Int
permissionRows rows =
    rows
        |> List.filter
            (\row ->
                case row of
                    PermissionRow _ ->
                        True

                    GroupRow _ _ ->
                        False
            )
        |> List.length


capRows : Int -> List Row -> ( List Row, Bool )
capRows limit rows =
    let
        go count remaining acc =
            case remaining of
                [] ->
                    ( List.reverse acc, False )

                row :: rest ->
                    case row of
                        PermissionRow _ ->
                            if count >= limit then
                                ( List.reverse acc, True )

                            else
                                go (count + 1) rest (row :: acc)

                        GroupRow _ _ ->
                            if count >= limit then
                                ( List.reverse acc, True )

                            else
                                go count rest (row :: acc)
    in
    go 0 rows []



-- MOVING WITH THE KEYBOARD


{-| The keys that move between cells.
-}
type Key
    = Up
    | Down
    | Left
    | Right
    | Home
    | End
    | CtrlHome
    | CtrlEnd
    | PageUp
    | PageDown


{-| The grid as the keys see it: how many rows (the header row included), how many
columns (the column of the labels included) and how many rows a page is.
-}
type alias Size =
    { rows : Int
    , columns : Int
    , page : Int
    }


{-| Where a key leads from a cell, as ( row, column ), counting from 0. Row 0 is
the header row and column 0 the labels; their meeting place has nothing in it
and is never a stop. A key that would leave the grid stays at its edge.
-}
move : Size -> Key -> ( Int, Int ) -> ( Int, Int )
move size key ( row, column ) =
    let
        lastRow =
            max 0 (size.rows - 1)

        lastColumn =
            max 0 (size.columns - 1)

        page =
            max 1 size.page

        clampRow value =
            clamp 0 lastRow value

        clampColumn value =
            clamp 0 lastColumn value

        target =
            case key of
                Up ->
                    ( clampRow (row - 1), column )

                Down ->
                    ( clampRow (row + 1), column )

                Left ->
                    ( row, clampColumn (column - 1) )

                Right ->
                    ( row, clampColumn (column + 1) )

                Home ->
                    ( row, 0 )

                End ->
                    ( row, lastColumn )

                CtrlHome ->
                    ( 0, 0 )

                CtrlEnd ->
                    ( lastRow, lastColumn )

                PageUp ->
                    ( clampRow (row - page), column )

                PageDown ->
                    ( clampRow (row + page), column )
    in
    case target of
        ( 0, 0 ) ->
            -- the empty corner is never a stop
            case key of
                Up ->
                    ( min 1 lastRow, 0 )

                PageUp ->
                    ( min 1 lastRow, 0 )

                _ ->
                    ( 0, min 1 lastColumn )

        _ ->
            target



-- WHAT A HEADER CHECKBOX MEANS


{-| How much of a row or a column is granted.
-}
type Summary
    = NoCells
    | NoneGranted
    | SomeGranted
    | AllGranted


{-| The summary of cells that are granted (`True`) or denied (`False`).
-}
summarize : List Bool -> Summary
summarize cells =
    let
        total =
            List.length cells

        granted =
            List.length (List.filter identity cells)
    in
    if total == 0 then
        NoCells

    else if granted == 0 then
        NoneGranted

    else if granted == total then
        AllGranted

    else
        SomeGranted


{-| What a click on the checkbox of these cells does: `Just True` grants every cell
that is not granted, `Just False` denies them all (the cells were all granted),
`Nothing` when there is no cell to change. A row that is partly granted is
granted, which is what "select all" is expected to do.
-}
shouldGrant : List Bool -> Maybe Bool
shouldGrant cells =
    case summarize cells of
        NoCells ->
            Nothing

        AllGranted ->
            Just False

        _ ->
            Just True
