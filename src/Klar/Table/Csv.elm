module Klar.Table.Csv exposing
    ( encode
    , field
    )

{-| CSV text for spreadsheet export. The table saves it with
`File.Download.string`, which has no size limit, after a UTF-8 byte order mark
so that Excel reads accented letters (æ, ø, å, é, ü ...) correctly.

    Csv.encode ';' [ [ "Name", "City" ], [ "Ada \"A\" Lovelace", "London" ] ]
    --> "Name;City\r\n\"Ada \"\"A\"\" Lovelace\";London"

Rules (RFC 4180):

  - a field is quoted when it contains the separator, a double quote, a line
    break, or starts or ends with a space; quotes inside are doubled
  - lines end with CRLF
  - a field a spreadsheet would run as a formula (it starts with `=`, `+`,
    `-`, `@`, tab or carriage return and is not a plain number) gets a
    leading apostrophe, so exported data can never execute ("CSV injection")

Use `;` as separator for Excel in a locale where the comma is the decimal
separator (Norwegian, German ...) and `,` for English.

-}


{-| Rows of fields to CSV text.
-}
encode : Char -> List (List String) -> String
encode separator rows =
    let
        glue =
            String.fromChar separator
    in
    rows
        |> List.map (\cells -> cells |> List.map (field separator) |> String.join glue)
        |> String.join "\u{000D}\n"


{-| One field, quoted and guarded when needed.

    field ';' "Oslo" --> "Oslo"

    field ';' "Oslo; Bergen" --> "\"Oslo; Bergen\""

    field ';' "=SUM(A1)" --> "'=SUM(A1)"

    field ';' "-12,5" --> "-12,5"

-}
field : Char -> String -> String
field separator raw =
    let
        value =
            guardFormula raw

        needsQuotes =
            String.contains (String.fromChar separator) value
                || String.contains "\"" value
                || String.contains "\n" value
                || String.contains "\u{000D}" value
                || String.startsWith " " value
                || String.endsWith " " value
    in
    if needsQuotes then
        "\"" ++ String.replace "\"" "\"\"" value ++ "\""

    else
        value


guardFormula : String -> String
guardFormula value =
    case String.uncons value of
        Just ( first, rest ) ->
            if String.isEmpty rest then
                value

            else if List.member first [ '=', '+', '-', '@', '\t', '\u{000D}' ] && not (isPlainNumber value) then
                "'" ++ value

            else
                value

        Nothing ->
            value


{-| "-12,5", "+3" and "-0.25" are numbers; "-x", "=1+1" and "+47 22 33 44 55"
(a phone number, which a spreadsheet would run as a formula) are not.
-}
isPlainNumber : String -> Bool
isPlainNumber value =
    value
        |> String.replace "," "."
        |> String.toFloat
        |> Maybe.map (\n -> not (isInfinite n) && not (isNaN n))
        |> Maybe.withDefault False
