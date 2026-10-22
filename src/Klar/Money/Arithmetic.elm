module Klar.Money.Arithmetic exposing
    ( allocate
    , fromDigits
    , maxMinor
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


{-| `a * n / d`, rounded half away from zero (a half goes up, as a person rounds by
hand). `a` and `n` must not be negative and `d` must be at least 1.

The product is not formed in one go: `a` is split into whole `d`s and a remainder, so
`a * n` may be far above the exact range as long as the answer, and `remainder * n`,
are not. `Nothing` when something does not fit.

-}
mulDivRound : Int -> Int -> Int -> Maybe Int
mulDivRound a n d =
    let
        wholes =
            quotient a d

        remainder =
            a - wholes * d

        fromWholes =
            wholes * n

        fromRemainder =
            remainder * n
    in
    if fromWholes > maxMinor || fromRemainder > maxMinor then
        Nothing

    else
        let
            extra =
                quotient fromRemainder d

            left =
                fromRemainder - extra * d

            -- 2 * left >= d, written so that nothing doubles
            roundUp =
                if left >= d - left then
                    1

                else
                    0

            total =
                fromWholes + extra + roundUp
        in
        if total > maxMinor then
            Nothing

        else
            Just total


{-| Splits `total` (not negative) in proportion to the `weights` (none negative,
their sum above zero), so that the parts add up to exactly `total`.

Every part gets the whole number of minor units that its share comes to; the units
that are left over (fewer than there are parts) go one by one to the parts with the
biggest fractions, and to the earlier part when two fractions are equal. 100.00 in
three equal parts is 33.34, 33.33 and 33.33. A part with the weight 0 gets 0.

`Nothing` when the weights are not usable, or when the numbers are so large that the
working would leave the exact range (the weights add up to some tens of millions).

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
        let
            wholes =
                quotient total sum

            left =
                total - wholes * sum

            -- the share of one weight: floor (total * weight / sum), and what is left of it
            shareOf weight =
                let
                    scaled =
                        left * weight

                    extra =
                        quotient scaled sum
                in
                { amount = wholes * weight + extra
                , fraction = scaled - extra * sum
                , fits = scaled <= maxMinor
                }

            shares =
                List.map shareOf weights
        in
        if List.any (\share -> not share.fits) shares then
            Nothing

        else
            let
                floors =
                    List.sum (List.map .amount shares)

                leftOver =
                    total - floors

                -- the earliest of the biggest fractions
                chosen =
                    shares
                        |> List.indexedMap (\index share -> ( index, share.fraction ))
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
                    (\index share ->
                        if Set.member index chosen then
                            share.amount + 1

                        else
                            share.amount
                    )
                |> Just
