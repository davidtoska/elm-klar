module Klar.Splitter.Layout exposing
    ( Limits
    , Request
    , collapse
    , drag
    , edge
    , equal
    , expand
    , fit
    , normalise
    , range
    , resolve
    , settle
    )

{-| The maths of `Klar.Splitter`: how a row of panes shares the room, and what a
move of one separator does to its two neighbours. Everything here is a pure function
on lists of fractions, and every function is total.

A **size** is a fraction of the room the panes share (the width of the container
without the separators), from 0 to 1. The sizes of a row of panes add up to 1. A
pane's **limits** are the smallest and the largest fraction it may have. Fractions,
not pixels, are what is kept, so the layout follows the window when it is resized.

Whatever the input is (a size that is negative or not a number, sizes that do not
add up to 1, limits that cannot be met together, a container with no room, a
separator that does not exist), the result is a list of the same length whose sizes
are not negative, are numbers and add up to 1.

-}


{-| What a pane asks for, before anybody knows how many pixels the container has:
shares of the room, and pixels.
-}
type alias Request =
    { minShare : Float
    , maxShare : Float
    , minPixels : Float
    , maxPixels : Maybe Float
    }


{-| The smallest and the largest fraction that a pane may have, with `min` never
above `max`.
-}
type alias Limits =
    { min : Float
    , max : Float
    }


{-| Turns what a pane asks for into limits, given the room in pixels (when it is
known). Without the room the pixel limits cannot be turned into fractions, so they
are left out (the stylesheet keeps a pane from being drawn smaller than its
`min-width` all the same). A room of nothing or less is the same as an unknown one.
-}
resolve : Maybe Float -> Request -> Limits
resolve room request =
    let
        usable =
            case room of
                Just pixels ->
                    if pixels > 0 && not (isNaN pixels) && not (isInfinite pixels) then
                        Just pixels

                    else
                        Nothing

                Nothing ->
                    Nothing

        fromPixels pixels =
            Maybe.map (\total -> pixels / total) usable

        low =
            Basics.max (unit request.minShare) (fromPixels request.minPixels |> Maybe.withDefault 0 |> unit)

        high =
            Basics.min (unit request.maxShare)
                (request.maxPixels |> Maybe.andThen fromPixels |> Maybe.withDefault 1 |> unit)
    in
    { min = low, max = Basics.max low high }


{-| A number between 0 and 1; anything else (not a number included) is 0.
-}
unit : Float -> Float
unit x =
    if isNaN x then
        0

    else
        clamp 0 1 x


{-| Sizes that share the room equally.
-}
equal : Int -> List Float
equal count =
    if count <= 0 then
        []

    else
        List.repeat count (1 / toFloat count)


{-| Makes a list of sizes add up to 1: sizes that are negative or not a number count
as 0, and when nothing is left the panes share the room equally. The proportions
are kept.
-}
normalise : List Float -> List Float
normalise sizes =
    let
        clean =
            List.map
                (\size ->
                    if isNaN size || isInfinite size || size < 0 then
                        0

                    else
                        size
                )
                sizes

        total =
            List.sum clean
    in
    if List.isEmpty sizes then
        []

    else if total <= 0 || isInfinite total then
        equal (List.length sizes)

    else
        List.map (\size -> size / total) clean


{-| Sizes for exactly this many panes, from the sizes that were kept for another
number: with more panes than sizes the new panes get an equal share and the others
keep their proportions; with fewer, the sizes of the panes that are gone are
dropped.
-}
fit : Int -> List Float -> List Float
fit count sizes =
    let
        known =
            List.length sizes
    in
    if count <= 0 then
        []

    else if known == count then
        normalise sizes

    else if known == 0 then
        equal count

    else if known > count then
        normalise (List.take count sizes)

    else
        let
            share =
                1 / toFloat count

            kept =
                List.map (\size -> size * toFloat known / toFloat count) (normalise sizes)
        in
        kept ++ List.repeat (count - known) share


{-| Brings sizes inside their limits. Sizes that already fit are left alone; when
not, the sizes outside their limits are put on the nearest limit, and the rest
shift by the same amount (found by bisection) so that the total is 1 again. Limits
that cannot be met together (the smallest sizes add up to more than the room, or the
largest to less) give each pane its smallest, or its largest, size, scaled to fill
the room exactly.
-}
settle : List Limits -> List Float -> List Float
settle limits sizes =
    let
        count =
            List.length sizes

        bounds =
            alignLimits count limits

        base =
            normalise sizes

        within shifted =
            List.map2 (\bound size -> Basics.max bound.min (Basics.min bound.max (size + shifted))) bounds base

        total shifted =
            List.sum (within shifted)

        smallest =
            List.sum (List.map .min bounds)

        largest =
            List.sum (List.map .max bounds)

        search lowest highest rounds =
            if rounds <= 0 then
                (lowest + highest) / 2

            else
                let
                    middle =
                        (lowest + highest) / 2
                in
                if total middle < 1 then
                    search middle highest (rounds - 1)

                else
                    search lowest middle (rounds - 1)

        alreadyFit =
            List.all identity (List.map2 (\bound size -> size >= bound.min - 1.0e-12 && size <= bound.max + 1.0e-12) bounds base)
    in
    if count == 0 then
        []

    else if alreadyFit then
        base

    else if smallest > 1 then
        normalise (List.map .min bounds)

    else if largest < 1 then
        normalise (List.map .max bounds)

    else
        within (search -1 1 64)


{-| One limit for every size: missing limits are no limit at all, surplus ones are
dropped.
-}
alignLimits : Int -> List Limits -> List Limits
alignLimits count limits =
    List.take count (limits ++ List.repeat count { min = 0, max = 1 })


{-| The least and the most that the separator after the pane at `index` can move the
pane: how much it may grow and shrink (a growth of the neighbour counts as a
shrink of this pane), both as a change of the size. `(0, 0)` where there is no such
separator. Always `low <= 0 <= high` when the sizes are inside their limits.
-}
reach : Int -> List Limits -> List Float -> ( Float, Float )
reach index limits sizes =
    case ( paneAt index limits sizes, paneAt (index + 1) limits sizes ) of
        ( Just here, Just next ) ->
            let
                low =
                    Basics.max (here.limits.min - here.size) (next.size - next.limits.max)

                high =
                    Basics.min (here.limits.max - here.size) (next.size - next.limits.min)
            in
            if low > high then
                ( 0, 0 )

            else
                ( low, high )

        _ ->
            ( 0, 0 )


{-| The smallest and the largest size that the pane at `index` can be given by
moving the separator after it, as sizes. Used for `aria-valuemin` and
`aria-valuemax`.
-}
range : Int -> List Limits -> List Float -> ( Float, Float )
range index limits sizes =
    case nth index sizes of
        Just here ->
            let
                ( low, high ) =
                    reach index limits sizes
            in
            ( here + low, here + high )

        Nothing ->
            ( 0, 0 )


{-| Moves the separator after the pane at `index` by `delta` (a fraction of the room;
positive grows the pane before the separator). Only the two panes next to the
separator change, by the same amount in opposite directions, and neither goes
outside its limits: a move that is too big is cut to the most that is possible.
Any other index changes nothing.
-}
drag : Int -> Float -> List Limits -> List Float -> List Float
drag index delta limits sizes =
    case ( nth index sizes, nth (index + 1) sizes ) of
        ( Just here, Just next ) ->
            let
                ( low, high ) =
                    reach index limits sizes

                wanted =
                    if isNaN delta then
                        0

                    else
                        delta

                change =
                    Basics.max low (Basics.min high wanted)

                grown =
                    here + change
            in
            sizes
                |> setAt index grown
                |> setAt (index + 1) (here + next - grown)

        _ ->
            sizes


{-| Moves the separator as far as it goes: to the smallest (`False`) or the largest
(`True`) size of the pane before it.
-}
edge : Int -> Bool -> List Limits -> List Float -> List Float
edge index toLargest limits sizes =
    let
        ( low, high ) =
            reach index limits sizes
    in
    drag index
        (if toLargest then
            high

         else
            low
        )
        limits
        sizes


{-| Folds the pane at `index` away: its room goes to the pane at `into`. Gives the
new sizes and the size the pane had (to give back). Panes that do not exist, or the
same pane twice, change nothing and give 0.
-}
collapse : Int -> Int -> List Float -> ( List Float, Float )
collapse index into sizes =
    case ( nth index sizes, nth into sizes ) of
        ( Just here, Just other ) ->
            if index == into then
                ( sizes, 0 )

            else
                ( sizes |> setAt index 0 |> setAt into (here + other), here )

        _ ->
            ( sizes, 0 )


{-| Gives a folded pane back its room, `wanted` at most and at least its own least
size, but never more than the pane at `from` can spare above its own least size.
Where the pane cannot be given anything, nothing changes.
-}
expand : Int -> Int -> Float -> List Limits -> List Float -> List Float
expand index from wanted limits sizes =
    case ( paneAt index limits sizes, paneAt from limits sizes ) of
        ( Just here, Just other ) ->
            if index == from then
                sizes

            else
                let
                    spare =
                        Basics.max 0 (other.size - other.limits.min)

                    size =
                        Basics.min spare (Basics.max (unit wanted) here.limits.min)
                in
                if size <= 0 then
                    sizes

                else
                    sizes
                        |> setAt index (here.size + size)
                        |> setAt from (other.size - size)

        _ ->
            sizes


{-| A pane: its size and its limits.
-}
type alias Placed =
    { size : Float
    , limits : Limits
    }


paneAt : Int -> List Limits -> List Float -> Maybe Placed
paneAt index limits sizes =
    case ( nth index sizes, nth index limits ) of
        ( Just size, Just bounds ) ->
            Just { size = size, limits = bounds }

        _ ->
            Nothing


nth : Int -> List a -> Maybe a
nth index list =
    if index < 0 then
        Nothing

    else
        List.head (List.drop index list)


setAt : Int -> a -> List a -> List a
setAt index value list =
    List.indexedMap
        (\i element ->
            if i == index then
                value

            else
                element
        )
        list
