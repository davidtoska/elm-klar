module Klar.Diff.Myers exposing (Run(..), diff)

{-| The shortest edit script between two sequences, by the O(ND) algorithm of
Eugene Myers ("An O(ND) Difference Algorithm and Its Variations", 1986).

The sequences are arrays of integers: the caller gives every distinct line, word
or character an id, so that two elements are equal exactly when their ids are.
The answer is a list of runs that, read from left to right, turn the first
sequence into the second.

The cost of the search grows with the square of the number of differences, so it is
capped: `diff` takes a budget of work (one unit for each diagonal it looks at
and each pair of elements it compares) and gives up with `Nothing` when the
budget is spent, instead of freezing the browser. A common beginning and a common
end are cut off first, which makes the usual case (a few changes in a long text)
cheap whatever the length of the text is.

The layers of the search are kept as persistent arrays and the way back is read
from them, so the memory is the square of the number of differences as well, never
more than the budget.

-}

import Array exposing (Array)


{-| A stretch of the edit script: that many elements are the same in both
sequences, only in the first (removed), or only in the second (inserted). The
runs never have the length 0, two runs of the same kind never follow each other,
and in a stretch of changes the removed elements come before the inserted ones.
-}
type Run
    = Same Int
    | Remove Int
    | Insert Int


{-| The edit script from the first sequence to the second, or `Nothing` when
finding it takes more than the given amount of work.
-}
diff : Int -> Array Int -> Array Int -> Maybe (List Run)
diff maxWork a b =
    let
        n =
            Array.length a

        m =
            Array.length b

        prefix =
            commonPrefix a b 0 (min n m)

        suffix =
            commonSuffix a b n m (min (n - prefix) (m - prefix)) 0

        middleA =
            Array.slice prefix (n - suffix) a

        middleB =
            Array.slice prefix (m - suffix) b

        middle =
            case ( Array.length middleA, Array.length middleB ) of
                ( 0, 0 ) ->
                    Just []

                ( 0, lengthB ) ->
                    Just [ Insert lengthB ]

                ( lengthA, 0 ) ->
                    Just [ Remove lengthA ]

                _ ->
                    search maxWork middleA middleB
    in
    middle
        |> Maybe.map (\runs -> normalize (Same prefix :: runs ++ [ Same suffix ]))


commonPrefix : Array Int -> Array Int -> Int -> Int -> Int
commonPrefix a b i limit =
    if i < limit && Array.get i a == Array.get i b then
        commonPrefix a b (i + 1) limit

    else
        i


commonSuffix : Array Int -> Array Int -> Int -> Int -> Int -> Int -> Int
commonSuffix a b n m limit count =
    if count < limit && Array.get (n - 1 - count) a == Array.get (m - 1 - count) b then
        commonSuffix a b n m limit (count + 1)

    else
        count



-- THE SEARCH


type alias Env =
    { a : Array Int
    , b : Array Int
    , n : Int
    , m : Int
    , maxWork : Int
    }


{-| Both sequences are not empty and their first elements differ.

Layer `d` holds, for every diagonal `k = x - y` that has the parity of `d`
(from `-d` to `d`), the furthest `x` that can be reached with `d` edits: the
entry `i` is the diagonal `2 * i - d`. A layer is built from the one before it
alone. An entry of -1 is a diagonal that leaves the grid.

-}
search : Int -> Array Int -> Array Int -> Maybe (List Run)
search maxWork a b =
    let
        env =
            { a = a, b = b, n = Array.length a, m = Array.length b, maxWork = maxWork }
    in
    forward env 0 Array.empty [] 0
        |> Maybe.map (\( d, layers ) -> backtrack env layers d (env.n - env.m) [])


forward : Env -> Int -> Array Int -> List (Array Int) -> Int -> Maybe ( Int, List (Array Int) )
forward env d previous layers work =
    if work > env.maxWork then
        Nothing

    else
        let
            ( layer, spent ) =
                buildLayer env d previous 0 [] 0

            all =
                layer :: layers
        in
        if reached env d layer then
            Just ( d, all )

        else
            forward env (d + 1) layer all (work + spent)


reached : Env -> Int -> Array Int -> Bool
reached env d layer =
    let
        target =
            env.n - env.m
    in
    if abs target <= d && modBy 2 (target + d) == 0 then
        Array.get ((target + d) // 2) layer == Just env.n

    else
        False


buildLayer : Env -> Int -> Array Int -> Int -> List Int -> Int -> ( Array Int, Int )
buildLayer env d previous i built spent =
    if i > d then
        ( Array.fromList (List.reverse built), spent )

    else
        let
            k =
                2 * i - d

            ( start, _ ) =
                origin env d previous i

            end =
                if start < 0 then
                    -1

                else
                    snake env start (start - k)
        in
        buildLayer env d previous (i + 1) (end :: built) (spent + 1 + max 0 (end - start))


{-| Where the furthest path to diagonal `2 * i - d` comes from: the `x` after
the one edit that leads there (before following matching elements), and whether it
was an insertion (moving down from the diagonal above) rather than a removal.
Layer 0 starts at the corner.
-}
origin : Env -> Int -> Array Int -> Int -> ( Int, Bool )
origin env d previous i =
    if d == 0 then
        ( 0, True )

    else
        let
            k =
                2 * i - d

            down =
                if i <= d - 1 then
                    case Array.get i previous of
                        Just x ->
                            if x >= 0 && x - k <= env.m then
                                x

                            else
                                -1

                        Nothing ->
                            -1

                else
                    -1

            right =
                if i >= 1 then
                    case Array.get (i - 1) previous of
                        Just x ->
                            if x >= 0 && x + 1 <= env.n then
                                x + 1

                            else
                                -1

                        Nothing ->
                            -1

                else
                    -1
        in
        if right > down then
            ( right, False )

        else
            ( down, True )


{-| Follows the matching elements from (x, y) and gives the `x` where they end.
-}
snake : Env -> Int -> Int -> Int
snake env x y =
    if x < env.n && y < env.m then
        case ( Array.get x env.a, Array.get y env.b ) of
            ( Just p, Just q ) ->
                if p == q then
                    snake env (x + 1) (y + 1)

                else
                    x

            _ ->
                x

    else
        x


backtrack : Env -> List (Array Int) -> Int -> Int -> List Run -> List Run
backtrack env layers d k following =
    case layers of
        [] ->
            following

        layer :: older ->
            let
                i =
                    (k + d) // 2

                x =
                    Array.get i layer |> Maybe.withDefault 0
            in
            if d == 0 then
                same x following

            else
                case older of
                    previous :: _ ->
                        let
                            ( start, fromDown ) =
                                origin env d previous i
                        in
                        if fromDown then
                            backtrack env older (d - 1) (k + 1) (Insert 1 :: same (x - start) following)

                        else
                            backtrack env older (d - 1) (k - 1) (Remove 1 :: same (x - start) following)

                    [] ->
                        following


same : Int -> List Run -> List Run
same count runs =
    if count > 0 then
        Same count :: runs

    else
        runs



-- TIDYING


type alias Tidy =
    { done : List Run
    , same : Int
    , removed : Int
    , inserted : Int
    }


{-| Joins runs of the same kind and puts the removals of a stretch of changes
before its insertions.
-}
normalize : List Run -> List Run
normalize runs =
    let
        step run state =
            case run of
                Same count ->
                    if count == 0 then
                        state

                    else
                        let
                            flushed =
                                flush state
                        in
                        { flushed | same = flushed.same + count }

                Remove count ->
                    let
                        flushed =
                            flushSame state
                    in
                    { flushed | removed = flushed.removed + count }

                Insert count ->
                    let
                        flushed =
                            flushSame state
                    in
                    { flushed | inserted = flushed.inserted + count }

        final =
            List.foldl step { done = [], same = 0, removed = 0, inserted = 0 } runs
    in
    List.reverse (flush (flushSame final)).done


flushSame : Tidy -> Tidy
flushSame state =
    if state.same > 0 then
        { state | done = Same state.same :: state.done, same = 0 }

    else
        state


flush : Tidy -> Tidy
flush state =
    let
        afterRemoved =
            if state.removed > 0 then
                Remove state.removed :: state.done

            else
                state.done

        afterInserted =
            if state.inserted > 0 then
                Insert state.inserted :: afterRemoved

            else
                afterRemoved
    in
    { state | done = afterInserted, removed = 0, inserted = 0 }
