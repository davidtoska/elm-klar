module Klar.Money.Arithmetic exposing
    ( allocate
    , fromDigits
    , maxMinor
    , mulDivMod
    , mulDivRound
    , quotient
    )

{-| Whole-number arithmetic that stays exact.

Elm's `Int` is a JavaScript number, so it is exact up to 2^53 - 1 (9 007 199 254 740 991)
and silently wrong beyond that. Elm's `//` makes things worse: it cuts a result to 32
bits. Every function here keeps its working numbers inside the exact range, and says
`Nothing` when the answer would not fit, instead of returning a wrong number.

The check "is the result in range" is reliable for sums and products: the computer
rounds a result that is too large to a number that is still too large.

-}

import Set


{-| The largest number of minor units a `Money` holds: 2^53 - 1. For a currency with
two decimals that is 90 trillion in the main unit.
-}
maxMinor : Int
maxMinor =
    9007199254740991


{-| A number written in digits, exactly: up to 16 of them, nothing else. `String.toInt`
adds the digits one at a time and overshoots 2^53 by the last digit for the numbers
just below it (it reads `9007199254740991` as `9007199254740992`), so the digits are
read in two halves of eight, which are small, and put together once.
-}
fromDigits : String -> Maybe Int
fromDigits digits =
    if digits == "" || String.length digits > 16 || not (String.all Char.isDigit digits) then
        Nothing

    else
        let
            padded =
                String.padLeft 16 '0' digits
        in
        Maybe.map2 (\high low -> high * 100000000 + low)
            (String.toInt (String.left 8 padded))
            (String.toInt (String.right 8 padded))


{-| `a // b` that does not cut at 32 bits. Both numbers must be whole, `a` must not be
negative and `b` must be at least 1.

The remainder is exact (the `%` of a JavaScript number is), so `a - remainder` is an
exact multiple of `b`, and dividing a multiple by its factor gives the exact whole
number.

-}
quotient : Int -> Int -> Int
quotient a b =
    round (toFloat (a - remainderBy b a) / toFloat b)


{-| `a * b` divided by `c`, as the whole number of times `c` goes into it and what is
left: `( floor (a * b / c), a * b mod c )`, exactly. `a` and `b` must not be negative and
`c` must be at least 1. `Nothing` when the whole number is beyond the exact range; the
product `a * b` itself may be far beyond it (up to about 10^32).

The product is never formed. `a` is split into whole `c`s and a remainder (smaller than
`c`), which leaves `remainder * b / c`. When that product is small it is divided at once.
When it is not, it is built one binary digit of `b` at a time, in the way a person
multiplies by doubling and adding: the value so far is kept as a whole number of `c`s and
a remainder, doubling it or adding `remainder` never needs a number beyond `c`, and the
checks are written as `x >= c - y`, so that nothing is added before it is known to fit.

-}
mulDivMod : Int -> Int -> Int -> Maybe ( Int, Int )
mulDivMod a b c =
    let
        wholes =
            quotient a c

        remainder =
            a - wholes * c

        fromWholes =
            wholes * b

        ( extra, left ) =
            if remainder * b <= maxMinor then
                let
                    product =
                        remainder * b

                    times =
                        quotient product c
                in
                ( times, product - times * c )

            else
                List.foldl (doubleAndAdd c remainder) ( 0, 0 ) (binaryDigits b)

        total =
            fromWholes + extra
    in
    if fromWholes > maxMinor || total > maxMinor then
        Nothing

    else
        Just ( total, left )


{-| The binary digits of a whole number, the largest first.
-}
binaryDigits : Int -> List Int
binaryDigits n =
    let
        collect rest digits =
            if rest == 0 then
                digits

            else
                collect (quotient rest 2) (remainderBy 2 rest :: digits)
    in
    collect n []


{-| One step of multiplying `r * b` by doubling and adding: the value so far, written as
`times * c + left`, is doubled, and `r` is added when the binary digit is 1. `left` and
`r` are both below `c`.
-}
doubleAndAdd : Int -> Int -> Int -> ( Int, Int ) -> ( Int, Int )
doubleAndAdd c r digit ( times, left ) =
    let
        ( doubledTimes, doubledLeft ) =
            if left >= c - left then
                ( 2 * times + 1, left - (c - left) )

            else
                ( 2 * times, left + left )
    in
    if digit == 1 then
        if doubledLeft >= c - r then
            ( doubledTimes + 1, doubledLeft - (c - r) )

        else
            ( doubledTimes, doubledLeft + r )

    else
        ( doubledTimes, doubledLeft )


{-| `a * n / d`, rounded half away from zero (a half goes up, as a person rounds by
hand). `a` and `n` must not be negative and `d` must be at least 1. Exact for every
`a`, `n` and `d` in the exact range, whatever the size of the product `a * n`;
`Nothing` only when the answer does not fit.
-}
mulDivRound : Int -> Int -> Int -> Maybe Int
mulDivRound a n d =
    mulDivMod a n d
        |> Maybe.andThen
            (\( times, left ) ->
                -- 2 * left >= d, written so that nothing doubles
                if left >= d - left then
                    if times + 1 > maxMinor then
                        Nothing

                    else
                        Just (times + 1)

                else
                    Just times
            )


{-| Splits `total` (not negative) in proportion to the `weights` (none negative,
their sum above zero), so that the parts add up to exactly `total`.

Every part gets the whole number of minor units that its share comes to; the units
that are left over (fewer than there are parts) go one by one to the parts with the
biggest fractions, and to the earlier part when two fractions are equal. 100.00 in
three equal parts is 33.34, 33.33 and 33.33. A part with the weight 0 gets 0.

The shares are exact for every list of weights whose sum is in the exact range, however
large the weights and the total are. `Nothing` when the weights are not usable (none, a
negative one, all zero), and when their sum is beyond the exact range.

-}
allocate : Int -> List Int -> Maybe (List Int)
allocate total weights =
    let
        sum =
            List.sum weights
    in
    if List.isEmpty weights || List.any (\weight -> weight < 0) weights || sum <= 0 || sum > maxMinor then
        Nothing

    else
        -- the share of a weight is floor (total * weight / sum), and what is left of it
        case allOrNothing (List.map (\weight -> mulDivMod total weight sum) weights) of
            Nothing ->
                Nothing

            Just shares ->
                let
                    leftOver =
                        total - List.sum (List.map Tuple.first shares)

                    -- the earliest of the biggest fractions
                    chosen =
                        shares
                            |> List.indexedMap (\index ( _, fraction ) -> ( index, fraction ))
                            |> List.sortWith
                                (\( indexA, fractionA ) ( indexB, fractionB ) ->
                                    case compare fractionB fractionA of
                                        EQ ->
                                            compare indexA indexB

                                        order ->
                                            order
                                )
                            |> List.take leftOver
                            |> List.map Tuple.first
                            |> Set.fromList
                in
                shares
                    |> List.indexedMap
                        (\index ( amount, _ ) ->
                            if Set.member index chosen then
                                amount + 1

                            else
                                amount
                        )
                    |> Just


allOrNothing : List (Maybe a) -> Maybe (List a)
allOrNothing maybes =
    List.foldr (\maybe rest -> Maybe.map2 (::) maybe rest) (Just []) maybes
