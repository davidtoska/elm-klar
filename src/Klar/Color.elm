module Klar.Color exposing (Color, rgb, hex, toHex)

{-| A color that comes from data: the color of a status, a category, a team, a
customer. It marks an option in a select, a chip or a tag with a small dot.

Use when: the color is a value of your data (a `Maybe String` code from a backend, a color in a record) and a component should show it.
Do not use when: the color means success, warning or danger; use a `Tone` (`Klar.Theme`), which follows the theme and the dark mode. Do not use it for the look of the application, which is the theme.
Quick path: `hex`, `rgb`

    import Klar.Color as Color
    import Klar.Select as Select


    -- a traffic light, from a record with a color code
    statusOption : Status -> Select.Option StatusId
    statusOption status =
        Select.option status.id status.name
            |> (case Color.hex status.color of
                    Just color ->
                        Select.withColor color

                    Nothing ->
                        identity
               )

A `Color` is not a `String`: `hex` checks the code, so a bad code from a backend
is a `Nothing` you decide about, never a broken style. The color is drawn as it is,
in light and dark mode alike; it is a mark, never the only carrier of the meaning,
so the label of the option must say it too ("Red", "Delayed").

@docs Color, rgb, hex, toHex

-}


{-| A color with red, green and blue from 0 to 255. The type is opaque.
-}
type Color
    = Color Int Int Int


{-| A color from its red, green and blue, each from 0 to 255. A number outside
the range is brought into it.

    Color.rgb 42 148 97 -- a green

-}
rgb : Int -> Int -> Int -> Color
rgb r g b =
    Color (clamp 0 255 r) (clamp 0 255 g) (clamp 0 255 b)


{-| A color from a color code: `"#2a9461"` or the short `"#2a9"`, with or without
the `#`, in any case. `Nothing` for anything else, so a missing or bad code is
visible in your code and not on the page.

    Color.hex "#D6453A" |> Maybe.map Color.toHex -- Just "#d6453a"

    Color.hex "red" -- Nothing

-}
hex : String -> Maybe Color
hex text =
    let
        digits =
            text
                |> String.trim
                |> (\trimmed ->
                        if String.startsWith "#" trimmed then
                            String.dropLeft 1 trimmed

                        else
                            trimmed
                   )
                |> String.toLower
                |> String.toList
                |> List.map digit
    in
    if List.any ((==) Nothing) digits then
        Nothing

    else
        case List.filterMap identity digits of
            [ r, g, b ] ->
                Just (Color (r * 17) (g * 17) (b * 17))

            [ r1, r2, g1, g2, b1, b2 ] ->
                Just (Color (r1 * 16 + r2) (g1 * 16 + g2) (b1 * 16 + b2))

            _ ->
                Nothing


digit : Char -> Maybe Int
digit char =
    case char of
        '0' ->
            Just 0

        '1' ->
            Just 1

        '2' ->
            Just 2

        '3' ->
            Just 3

        '4' ->
            Just 4

        '5' ->
            Just 5

        '6' ->
            Just 6

        '7' ->
            Just 7

        '8' ->
            Just 8

        '9' ->
            Just 9

        'a' ->
            Just 10

        'b' ->
            Just 11

        'c' ->
            Just 12

        'd' ->
            Just 13

        'e' ->
            Just 14

        'f' ->
            Just 15

        _ ->
            Nothing


{-| The color as a code in the long form, lowercase: `"#2a9461"`. Use it to
store a color or send it back to a backend.
-}
toHex : Color -> String
toHex (Color r g b) =
    "#" ++ pair r ++ pair g ++ pair b


pair : Int -> String
pair value =
    String.fromList [ nibble (value // 16), nibble (modBy 16 value) ]


nibble : Int -> Char
nibble value =
    String.toList "0123456789abcdef"
        |> List.drop value
        |> List.head
        |> Maybe.withDefault '0'
