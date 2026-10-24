module Klar.Transfer.Lists exposing
    ( Chosen
    , Item
    , Order(..)
    , PaneRow
    , Source
    , availableRows
    , buildSource
    , chosenRows
    , emptySource
    , filterWords
    , moveIn
    , normalize
    , removeFrom
    , typeahead
    )

{-| The pure side of `Klar.Transfer`: the source items indexed by key, the rows of
the two lists (the source without what is chosen, and what is chosen, including
ids the source no longer knows), the filter, moving items between the lists in
either order, and type-ahead.

Not for application code.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Ids as Ids exposing (Ids)
import Klar.Picking as Picking
import Klar.Search as Search
import Klar.Select.Option exposing (Option)
import Set exposing (Set)


{-| One item of the source: its key, the option, the normalized label (for
type-ahead) and the normalized text the filter looks in.
-}
type alias Item id =
    { key : String
    , option : Option id
    , labelNorm : String
    , haystack : String
    }


type alias Source id =
    { items : Array (Item id)
    , byKey : Dict String (Item id)
    , position : Dict String Int
    }


{-| Indexes the source. When two options have the same key the first one is kept.
-}
buildSource : Ids id -> List (Option id) -> Source id
buildSource ids options =
    let
        ( reversed, byKey, position ) =
            List.foldl
                (\option ( items, dict, places ) ->
                    let
                        key =
                            Ids.toKey ids option.value
                    in
                    if Dict.member key dict then
                        ( items, dict, places )

                    else
                        let
                            item =
                                { key = key
                                , option = option
                                , labelNorm = Search.normalize option.label
                                , haystack =
                                    Search.normalize
                                        (String.join " " (option.label :: Maybe.withDefault "" option.description :: option.keywords))
                                }
                        in
                        ( item :: items, Dict.insert key item dict, Dict.insert key (Dict.size places) places )
                )
                ( [], Dict.empty, Dict.empty )
                options
    in
    { items = Array.fromList (List.reverse reversed), byKey = byKey, position = position }


emptySource : Source id
emptySource =
    { items = Array.empty, byKey = Dict.empty, position = Dict.empty }


{-| The order of the chosen list, and of `values`: the order of the source, or the
order in which the user moved the items.
-}
type Order
    = SourceOrder
    | MovedOrder


{-| A chosen id: the id as the application gave it, its key, and the label the
component saw when it was moved (for an id that the source no longer has).
-}
type alias Chosen id =
    { key : String
    , id : id
    , label : Maybe String
    }


{-| A row of one of the lists. `known` says that the source has the item; for an id
it does not have, the option is made up from the remembered label.
-}
type alias PaneRow id =
    { key : String
    , option : Option id
    , known : Bool
    , labelNorm : String
    }


{-| The words of a filter text, normalized.
-}
filterWords : String -> List String
filterWords text =
    Search.normalize text |> String.words |> List.filter (\w -> w /= "")


matchesAll : List String -> String -> Bool
matchesAll words haystack =
    List.all (\word -> String.contains word haystack) words


{-| The source without what is chosen, in the order of the source, with the items
that contain every word of the filter.
-}
availableRows : Source id -> Set String -> List String -> Array (PaneRow id)
availableRows source chosenKeys words =
    source.items
        |> Array.toList
        |> List.filter (\item -> not (Set.member item.key chosenKeys) && matchesAll words item.haystack)
        |> List.map (\item -> { key = item.key, option = item.option, known = True, labelNorm = item.labelNorm })
        |> Array.fromList


{-| What is chosen, in the order of the list, with the rows that contain every
word of the filter. An id that the source does not have is a row too: its option
is made up from the remembered label (or an empty one), `known` is `False`.
-}
chosenRows : Source id -> List (Chosen id) -> List String -> Array (PaneRow id)
chosenRows source chosen words =
    chosen
        |> List.filterMap
            (\c ->
                case Dict.get c.key source.byKey of
                    Just item ->
                        if matchesAll words item.haystack then
                            Just { key = c.key, option = item.option, known = True, labelNorm = item.labelNorm }

                        else
                            Nothing

                    Nothing ->
                        let
                            text =
                                Maybe.withDefault "" c.label
                        in
                        if List.isEmpty words || matchesAll words (Search.normalize text) then
                            Just
                                { key = c.key
                                , option = unknownOption c.id text
                                , known = False
                                , labelNorm = Search.normalize text
                                }

                        else
                            Nothing
            )
        |> Array.fromList


unknownOption : id -> String -> Option id
unknownOption id text =
    { value = id
    , label = text
    , description = Nothing
    , group = Nothing
    , disabled = False
    , icon = Nothing
    , tone = Nothing
    , color = Nothing
    , keywords = []
    }


{-| Puts the chosen list in the order: the order of the source, with the ids the
source does not know after the others (in the order they had), or as it is.
-}
normalize : Order -> Source id -> List (Chosen id) -> List (Chosen id)
normalize order source chosen =
    case order of
        MovedOrder ->
            chosen

        SourceOrder ->
            let
                total =
                    Array.length source.items
            in
            chosen
                |> List.indexedMap
                    (\i c ->
                        ( case Dict.get c.key source.position of
                            Just place ->
                                place

                            Nothing ->
                                total + i
                        , c
                        )
                    )
                |> List.sortBy Tuple.first
                |> List.map Tuple.second


{-| Moves items to the chosen list: the ones that are not disabled and not chosen
already, at the end, then in the order.
-}
moveIn : Order -> Source id -> List (Item id) -> List (Chosen id) -> List (Chosen id)
moveIn order source items chosen =
    let
        have =
            Set.fromList (List.map .key chosen)

        ( _, fresh ) =
            List.foldl
                (\item ( seen, kept ) ->
                    if item.option.disabled || Set.member item.key seen then
                        ( seen, kept )

                    else
                        ( Set.insert item.key seen, { key = item.key, id = item.option.value, label = Just item.option.label } :: kept )
                )
                ( have, [] )
                items
    in
    normalize order source (chosen ++ List.reverse fresh)


{-| Takes the items with these keys out of the chosen list, except the ones that
are locked: an item that the source has and has disabled. Returns the new list
and the keys that were taken out.
-}
removeFrom : Source id -> Set String -> List (Chosen id) -> ( List (Chosen id), List String )
removeFrom source keys chosen =
    let
        locked c =
            case Dict.get c.key source.byKey of
                Just item ->
                    item.option.disabled

                Nothing ->
                    False

        ( kept, removed ) =
            List.partition (\c -> not (Set.member c.key keys) || locked c) chosen
    in
    ( kept, List.map .key removed )


{-| Type-ahead: the row to move to when the user has typed `buffer` since the last
pause. One letter looks after the current row, more letters keep it while it still
starts with them; the search goes round the end of the list.
-}
typeahead : String -> Maybe Int -> Array String -> Maybe Int
typeahead buffer current labels =
    let
        typed =
            Search.normalize buffer

        count =
            Array.length labels

        start =
            case current of
                Just i ->
                    if String.length typed <= 1 then
                        i + 1

                    else
                        max 0 i

                Nothing ->
                    0

        starts i =
            case Array.get (modBy (max 1 count) i) labels of
                Just label ->
                    String.startsWith typed label

                Nothing ->
                    False

        search offset =
            if offset >= count then
                Nothing

            else if starts (start + offset) then
                Just (modBy count (start + offset))

            else
                search (offset + 1)
    in
    if typed == "" || count == 0 then
        Nothing

    else
        search 0
