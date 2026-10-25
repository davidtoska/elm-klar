module Klar.MaskedInput.Checksum exposing
    ( mod10
    , mod11
    , mod97
    )

{-| The check digits that identifiers carry: they catch a mistyped or transposed
character, so a wrong number is found before it is sent anywhere.

They work on text that has been read already: digits only for `mod10` and `mod11`,
digits and capital letters for `mod97`.

-}


{-| The check digit of the Norwegian organisation number and of the Norwegian bank
account number (modulus 11). The last digit is the check digit; the digits before it
are multiplied by the weights, one weight each and in order, and added. The check
digit is 11 minus the remainder of the sum divided by 11, and zero when there is no
remainder. A remainder of one would need a check digit of 10, so no number has it:
such a number is wrong.

    -- the organisation number 974 760 673
    Checksum.mod11 [ 3, 2, 7, 6, 5, 4, 3, 2 ] "974760673" --> True

`False` for a text of another length than the weights plus one, and for text that is
not made of digits.

-}
mod11 : List Int -> String -> Bool
mod11 weights digits =
    if String.length digits /= List.length weights + 1 || not (String.all Char.isDigit digits) then
        False

    else
        let
            numbers =
                digits |> String.toList |> List.map (\c -> Char.toCode c - 48)

            sum =
                List.map2 (*) weights numbers |> List.sum

            check =
                numbers |> List.drop (List.length weights) |> List.head |> Maybe.withDefault -1
        in
        case modBy 11 sum of
            0 ->
                check == 0

            1 ->
                False

            remainder ->
                check == 11 - remainder


{-| The check digit of a GTIN, the number under the barcode of a product (EAN-13,
modulus 10). The last digit is the check digit. The digits before it are multiplied
by 3 and 1 in turn, starting with 3 at the one next to the check digit, and added;
the check digit is what brings the sum up to the next multiple of ten.

    Checksum.mod10 "5901234123457" --> True

`False` for fewer than two digits, and for text that is not made of digits.

-}
mod10 : String -> Bool
mod10 digits =
    if String.length digits < 2 || not (String.all Char.isDigit digits) then
        False

    else
        let
            fromTheRight =
                digits |> String.toList |> List.map (\c -> Char.toCode c - 48) |> List.reverse

            sum =
                fromTheRight
                    |> List.drop 1
                    |> List.indexedMap
                        (\index n ->
                            if modBy 2 index == 0 then
                                3 * n

                            else
                                n
                        )
                    |> List.sum
        in
        List.head fromTheRight == Just (modBy 10 (10 - modBy 10 sum))


{-| The check of an IBAN (ISO 7064, modulus 97-10). The first four characters (the
country and the two check digits) move to the end, every letter becomes the two
digits 10 to 35, and the number that comes out must leave the remainder 1 when divided
by 97. The number is too large for a computer's whole numbers, so the remainder is
taken as the digits come, which gives the same answer.

ISO 13616 allows the check digits 02 to 98 only. Modulo 97 the digits 00, 01 and 99 are
the same as 97, 98 and 02, so the remainder can come out right with them: an IBAN with
one of those is wrong, however the rest looks.

`False` for text with anything but capital letters and digits in it.

-}
mod97 : String -> Bool
mod97 iban =
    if String.length iban < 5 || not (String.all (\c -> Char.isDigit c || (Char.isAlpha c && Char.isUpper c)) iban) then
        False

    else if List.member (String.slice 2 4 iban) [ "00", "01", "99" ] then
        False

    else
        let
            rearranged =
                String.dropLeft 4 iban ++ String.left 4 iban

            step c remainder =
                if Char.isDigit c then
                    modBy 97 (remainder * 10 + (Char.toCode c - 48))

                else
                    modBy 97 (remainder * 100 + (Char.toCode c - 55))
        in
        String.foldl step 0 rearranged == 1
