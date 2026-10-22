module Klar.MaskedInput.Phone exposing
    ( callingCodeLength
    , groups
    )

{-| What the phone number mask knows about telephone numbers. It is not a phone
number library: it knows how long a country calling code is (so that `+47 912 34 567`
can be written with the country code apart from the rest), how Norwegian, Danish and
North American numbers are grouped, and that the rest are written in groups of three.
It does not know which numbers exist.
-}


{-| The length of the country calling code at the start of a phone number written
with its digits (without the `+`): 1, 2 or 3. The calling codes are prefix free, so
the first digits tell: 1 and 7 are one digit; 20 and 27, 30 to 34, 36, 39, 40, 41, 43
to 49, 51 to 58, 60 to 66, 81, 82, 84, 86, 90 to 95 and 98 are two; the rest, such as
35x, 42x, 50x and 59x, are three.

A number that starts with 0 has no country calling code; 1 is the answer then, and
the mask refuses the 0 before it gets here.

-}
callingCodeLength : String -> Int
callingCodeLength digits =
    case String.left 1 digits of
        "1" ->
            1

        "7" ->
            1

        "2" ->
            if List.member (String.left 2 digits) [ "20", "27" ] then
                2

            else
                3

        "3" ->
            if List.member (String.left 2 digits) [ "35", "37", "38" ] then
                3

            else
                2

        "4" ->
            if String.left 2 digits == "42" then
                3

            else
                2

        "5" ->
            if List.member (String.left 2 digits) [ "50", "59" ] then
                3

            else
                2

        "6" ->
            if List.member (String.left 2 digits) [ "67", "68", "69" ] then
                3

            else
                2

        "8" ->
            if List.member (String.left 2 digits) [ "81", "82", "84", "86" ] then
                2

            else
                3

        "9" ->
            if List.member (String.left 2 digits) [ "90", "91", "92", "93", "94", "95", "98" ] then
                2

            else
                3

        _ ->
            1


{-| The sizes of the groups of the digits after the country calling code, from the
start: a Norwegian number begins with 4 or 9 for a mobile (`912 34 567`) and is
written `22 12 34 56` otherwise; Danish numbers are written in pairs; North American
ones as `202 555 0123`. The last size repeats for all the digits there are left, so
the rest of the world is written in groups of three.

The size of a group never depends on the digits that come after it, so the way a
number is written does not change while it is typed.

-}
groups : String -> String -> List Int
groups callingCode national =
    case callingCode of
        "47" ->
            if String.startsWith "4" national || String.startsWith "9" national then
                [ 3, 2, 3 ]

            else
                [ 2, 2, 2, 2 ]

        "45" ->
            [ 2, 2, 2, 2 ]

        "1" ->
            [ 3, 3, 4 ]

        _ ->
            [ 3 ]
