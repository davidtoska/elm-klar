# Klar.Color

A color that comes from data: the color of a status, a category, a team, a customer.

Import: `import Klar.Color as Color` | Group: Foundations

Types: `Color`

## Signatures

```elm
type Color  -- opaque: no constructors are exposed
rgb : Int -> Int -> Int -> Color
hex : String -> Maybe Color
toHex : Color -> String
```

## Documentation

A color that comes from data: the color of a status, a category, a team, a
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

### `Color`

```elm
type Color  -- opaque: no constructors are exposed
```

A color with red, green and blue from 0 to 255. The type is opaque.

### `rgb`

```elm
rgb : Int -> Int -> Int -> Color
```

A color from its red, green and blue, each from 0 to 255. A number outside
the range is brought into it.

    Color.rgb 42 148 97 -- a green

### `hex`

```elm
hex : String -> Maybe Color
```

A color from a color code: `"#2a9461"` or the short `"#2a9"`, with or without
the `#`, in any case. `Nothing` for anything else, so a missing or bad code is
visible in your code and not on the page.

    Color.hex "#D6453A" |> Maybe.map Color.toHex -- Just "#d6453a"

    Color.hex "red" -- Nothing

### `toHex`

```elm
toHex : Color -> String
```

The color as a code in the long form, lowercase: `"#2a9461"`. Use it to
store a color or send it back to a backend.
