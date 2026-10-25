module Klar.CommentThread.Structure exposing (Link(..), Row, arrange)

{-| A bounded, iterative traversal of a flat reply graph. Every supplied comment
is retained, including duplicate ids, missing parents and cycles. Only the first
occurrence of an id may be a parent; invalid duplicates become separate roots.
-}

import Dict exposing (Dict)
import Set exposing (Set)


type Link
    = Root
    | Reply
    | Missing
    | Cycle
    | Duplicate


type alias Row a =
    { key : String, parent : Maybe String, value : a, depth : Int, link : Link, suffix : Maybe Int }


arrange : List { key : String, parent : Maybe String, value : a } -> List (Row a)
arrange items =
    let
        collect index item ( known, uniqueAcc, duplicateAcc ) =
            if Dict.member item.key known then
                ( known, uniqueAcc, { key = item.key, parent = item.parent, value = item.value, depth = 0, link = Duplicate, suffix = Just index } :: duplicateAcc )

            else
                ( Dict.insert item.key item known, item :: uniqueAcc, duplicateAcc )

        ( byKey, reversed, duplicates ) =
            List.indexedMap Tuple.pair items
                |> List.foldl (\( index, item ) acc -> collect index item acc) ( Dict.empty, [], [] )

        unique =
            List.reverse reversed

        children =
            List.foldl
                (\item acc ->
                    case item.parent of
                        Just parent ->
                            if parent /= item.key && Dict.member parent byKey then
                                Dict.update parent (Maybe.withDefault [] >> (::) item.key >> Just) acc

                            else
                                acc

                        Nothing ->
                            acc
                )
                Dict.empty
                (List.reverse unique)

        roots =
            List.filterMap
                (\item ->
                    case item.parent of
                        Nothing ->
                            Just ( item.key, 0, Root )

                        Just parent ->
                            if parent == item.key then
                                Just ( item.key, 0, Cycle )

                            else if not (Dict.member parent byKey) then
                                Just ( item.key, 0, Missing )

                            else
                                Nothing
                )
                unique

        ( visited, rows ) =
            walk byKey children roots Set.empty []

        ( _, finished ) =
            List.foldl
                (\item ( seen, built ) ->
                    if Set.member item.key seen then
                        ( seen, built )

                    else
                        walk byKey children [ ( item.key, 0, Cycle ) ] seen built
                )
                ( visited, rows )
                unique
    in
    List.reverse finished ++ List.reverse duplicates


walk : Dict String { key : String, parent : Maybe String, value : a } -> Dict String (List String) -> List ( String, Int, Link ) -> Set String -> List (Row a) -> ( Set String, List (Row a) )
walk byKey children pending visited built =
    case pending of
        [] ->
            ( visited, built )

        ( key, depth, link ) :: rest ->
            if Set.member key visited then
                walk byKey children rest visited built

            else
                case Dict.get key byKey of
                    Nothing ->
                        walk byKey children rest visited built

                    Just item ->
                        walk byKey
                            children
                            ((Dict.get key children |> Maybe.withDefault [] |> List.map (\child -> ( child, depth + 1, Reply ))) ++ rest)
                            (Set.insert key visited)
                            ({ key = item.key, parent = item.parent, value = item.value, depth = depth, link = link, suffix = Nothing } :: built)
