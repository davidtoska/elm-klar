module Klar.Sortable.Order exposing
    ( Indicator
    , Rect
    , bounds
    , clampTarget
    , finalIndex
    , gapAt
    , indexOf
    , indicator
    , move
    , place
    )

{-| The pure part of `Klar.Sortable`: moving one element of a list, the limits that
fixed items set, and finding the gap the pointer is over. Everything here is total:
an index outside the list, an empty list or a pointer far away never crash and
never lose or duplicate an element.

Positions are counted from 0. A **target** is the index the moved element has
when the move is done (the list without it, with it put back at that index). A
**gap** is a place between two elements, counted from 0 (before the first
element) to the length of the list (after the last one).

-}

import Set


{-| A box on the page, in page coordinates (what `Browser.Dom.getElement` gives).
-}
type alias Rect =
    { x : Float
    , y : Float
    , width : Float
    , height : Float
    }


{-| Moves the element at `from` so that it ends up at index `to`. A `to` outside
the list counts as the nearest end; a `from` outside the list changes nothing. The
list keeps its length and all its elements, and moving an element to where it is
changes nothing.

    move 0 2 [ "a", "b", "c", "d" ] --> [ "b", "c", "a", "d" ]

    move 3 -5 [ "a", "b", "c", "d" ] --> [ "d", "a", "b", "c" ]

-}
move : Int -> Int -> List a -> List a
move from to list =
    let
        length =
            List.length list

        target =
            clamp 0 (length - 1) to
    in
    if from < 0 || from >= length || target == from then
        list

    else
        case List.drop from list of
            element :: _ ->
                let
                    without =
                        List.take from list ++ List.drop (from + 1) list
                in
                List.take target without ++ element :: List.drop target without

            [] ->
                list


{-| Puts the element with the key `source` of a list where a drop put it among the
elements that were drawn, which need not be all the elements of the list (a filter
may hide some, others may have come or gone since). `drawn` is the keys of the drawn
elements as they are after the drop and `index` is the place of `source` in them.

The element goes right behind the nearest of the drawn elements above its new place
that is still in the list, and when there is none, right in front of the nearest one
below it. Elements that were not drawn stay where they are in relation to each
other. When no other drawn element is left in the list, `index` is used as an index
of the list itself, kept inside it. The first element with the key is the one that
moves; a key that is not in the list changes nothing.

    place identity "a" 2 [ "c", "e", "a" ] [ "a", "b", "c", "d", "e" ]
        --> [ "b", "c", "d", "e", "a" ]

When the drawn elements are all the elements, this is `move`.

-}
place : (a -> String) -> String -> Int -> List String -> List a -> List a
place toKey source index drawn list =
    let
        keys =
            List.map toKey list
    in
    case indexOf source keys of
        Nothing ->
            list

        Just at ->
            case List.drop at list of
                moved :: after ->
                    let
                        rest =
                            List.take at list ++ after

                        restKeys =
                            List.map toKey rest

                        present =
                            Set.fromList restKeys

                        total =
                            List.length drawn

                        keyAt i =
                            if i < 0 || i >= total then
                                Nothing

                            else
                                List.head (List.drop i drawn)
                                    |> Maybe.andThen
                                        (\key ->
                                            if Set.member key present then
                                                Just key

                                            else
                                                Nothing
                                        )

                        -- the nearest surviving neighbour above, else the nearest below
                        above =
                            surviving (\away -> keyAt (index - away)) 1 total

                        below =
                            surviving (\away -> keyAt (index + away)) 1 total

                        insertAt position =
                            List.take position rest ++ moved :: List.drop position rest
                    in
                    case ( above, below ) of
                        ( Just key, _ ) ->
                            case indexOf key restKeys of
                                Just found ->
                                    insertAt (found + 1)

                                Nothing ->
                                    list

                        ( Nothing, Just key ) ->
                            case indexOf key restKeys of
                                Just found ->
                                    insertAt found

                                Nothing ->
                                    list

                        ( Nothing, Nothing ) ->
                            move at index list

                [] ->
                    list


{-| The first key that a search outward from a place finds, trying each distance from
1 to `limit`.
-}
surviving : (Int -> Maybe String) -> Int -> Int -> Maybe String
surviving keyAt away limit =
    if away > limit then
        Nothing

    else
        case keyAt away of
            Just key ->
                Just key

            Nothing ->
                surviving keyAt (away + 1) limit


{-| The lowest and the highest index the element at `index` can have when the
elements that are `fixed` stay where they are and nothing moves past them: the
run of loose elements around it. A fixed element, and an index outside the list,
can only stay where it is.

    bounds [ False, False, True, False ] 0 --> ( 0, 1 )

    bounds [ False, False, True, False ] 3 --> ( 3, 3 )

-}
bounds : List Bool -> Int -> ( Int, Int )
bounds fixed index =
    let
        length =
            List.length fixed

        indexed =
            List.indexedMap Tuple.pair fixed

        isFixed =
            List.any (\( i, flag ) -> i == index && flag) indexed

        below =
            indexed
                |> List.filter (\( i, flag ) -> flag && i < index)
                |> List.map Tuple.first
                |> List.maximum

        above =
            indexed
                |> List.filter (\( i, flag ) -> flag && i > index)
                |> List.map Tuple.first
                |> List.minimum
    in
    if index < 0 || index >= length || isFixed then
        ( index, index )

    else
        ( Maybe.withDefault -1 below + 1
        , Maybe.withDefault length above - 1
        )


{-| The index nearest to `to` that the element at `from` may have: inside its
`bounds`.
-}
clampTarget : List Bool -> Int -> Int -> Int
clampTarget fixed from to =
    let
        ( low, high ) =
            bounds fixed from
    in
    clamp low high to


{-| The index an element ends up at when it is dropped into a gap. The gaps right
before and right after the element itself both mean "where it was".
-}
finalIndex : Int -> Int -> Int
finalIndex from gap =
    if gap <= from then
        gap

    else
        gap - 1


{-| Where to draw the line that shows a move: next to the element at `index`,
before it or after it. There is no line when the element stays where it is.
-}
type alias Indicator =
    { index : Int
    , after : Bool
    }


{-| The line for moving the element at `from` to the target `to`: moving up puts
it before the element now at `to`, moving down puts it after.
-}
indicator : Int -> Int -> Maybe Indicator
indicator from to =
    if to < from then
        Just { index = to, after = False }

    else if to > from then
        Just { index = to, after = True }

    else
        Nothing


{-| The gap a pointer at (`x`, `y`) points at, given the boxes of the elements in
list order: the element whose box is nearest to the pointer (the first one when
two are equally near), and the gap before it when the pointer is in its first
half (left half in a `horizontal` list, upper half otherwise), after it when in
the second half. No boxes give gap 0.
-}
gapAt : Bool -> List Rect -> Float -> Float -> Int
gapAt horizontal rects x y =
    case nearest x y rects of
        Nothing ->
            0

        Just ( index, rect ) ->
            let
                first =
                    if horizontal then
                        x < rect.x + rect.width / 2

                    else
                        y < rect.y + rect.height / 2
            in
            if first then
                index

            else
                index + 1


nearest : Float -> Float -> List Rect -> Maybe ( Int, Rect )
nearest x y rects =
    rects
        |> List.indexedMap Tuple.pair
        |> List.foldl
            (\( index, rect ) best ->
                let
                    d =
                        distance x y rect
                in
                case best of
                    Just ( _, _, bestDistance ) ->
                        if d < bestDistance then
                            Just ( index, rect, d )

                        else
                            best

                    Nothing ->
                        Just ( index, rect, d )
            )
            Nothing
        |> Maybe.map (\( index, rect, _ ) -> ( index, rect ))


{-| The squared distance from a point to a box: 0 when the point is inside it.
-}
distance : Float -> Float -> Rect -> Float
distance x y rect =
    let
        dx =
            max (rect.x - x) (max 0 (x - (rect.x + rect.width)))

        dy =
            max (rect.y - y) (max 0 (y - (rect.y + rect.height)))
    in
    dx * dx + dy * dy


{-| The index of the first element that is equal to this one.
-}
indexOf : a -> List a -> Maybe Int
indexOf target list =
    list
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, element ) -> element == target)
        |> List.head
        |> Maybe.map Tuple.first
