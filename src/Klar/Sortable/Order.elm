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
