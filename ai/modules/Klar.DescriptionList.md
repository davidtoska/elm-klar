# Klar.DescriptionList

Label and value pairs for detail views, rendered as a semantic `dl`.

Import: `import Klar.DescriptionList as DescriptionList` | Group: Structure

Types: `Item`, `Attribute`

## Signatures

```elm
-- View
view : List Attribute -> List (Item msg) -> Html msg

-- Items
type Item msg  -- opaque: no constructors are exposed
text : String -> String -> Item msg
maybe : String -> Maybe String -> Item msg
html : String -> Html msg -> Item msg
values : String -> List (Html msg) -> Item msg
fullWidth : Item msg -> Item msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
columns : Int -> Attribute
labelBeside : Attribute
labelWidth : Int -> Attribute
bordered : Attribute
compact : Attribute
locale : Locale.Locale -> Attribute
```

## Documentation

Label and value pairs for detail views, rendered as a semantic `dl`.

Use when: the application shows the facts about one thing, such as an order, a customer or a shipment.
Do not use when: there are many things of the same kind to compare or sort, use `Klar.Table`.

    import Klar.Badge as Badge
    import Klar.DescriptionList as DescriptionList
    import Klar.Theme exposing (Tone(..))

    DescriptionList.view [ DescriptionList.columns 2 ]
        [ DescriptionList.text "Customer number" "100482"
        , DescriptionList.maybe "Phone" model.phone
        , DescriptionList.html "Status" (Badge.view [ Badge.tone Success ] "Active")
        , DescriptionList.values "Sales channels"
            [ Badge.view [] "Web shop", Badge.view [] "Wholesale" ]
        , DescriptionList.text "Delivery note" model.note
            |> DescriptionList.fullWidth
        ]

Use it for the facts about one thing, such as an order, a customer or a
shipment. For many things of the same kind use [Klar.Table](Klar.Table.md).

A value that is missing (an empty or blank string, `Nothing` or an empty list) is
shown as a muted dash, with a hidden "Not provided" for screen readers, so a row
never silently disappears and a label never sits beside nothing. The hidden text
follows `locale` (English by default).

The label sits above the value by default. `labelBeside` puts it in a column to
the left, which reads like a table and works well with `bordered`. The number of
`columns` is a maximum: the grid drops to fewer columns when there is no room
(a column is never narrower than 200px). Rows keep the order they are given in.
The list has no state and sends no messages.

## View

### `view`

```elm
view : List Attribute -> List (Item msg) -> Html msg
```

The list. Rows keep the order they are given in. Each row is a `div` with a
`dt` for the label and a `dd` for the value inside a `dl`.

## Items

### `Item`

```elm
type Item msg  -- opaque: no constructors are exposed
```

One label with its value. Make an item with `text`, `maybe`, `html` or
`values` and give a list of them to `view`. The `msg` is the message type of the
Html you pass to `html` and `values`.

### `text`

```elm
text : String -> String -> Item msg
```

A plain text value: the label first, then the value. An empty or blank
string (nothing but spaces) counts as no value and is shown as a dash.

    DescriptionList.text "Customer number" "100482"

### `maybe`

```elm
maybe : String -> Maybe String -> Item msg
```

A text value that may be missing. `Nothing` and `Just ""` (or any blank
string) are shown as a dash, like in `text`.

    DescriptionList.maybe "Phone" model.phone

### `html`

```elm
html : String -> Html msg -> Item msg
```

Any content as the value: a badge, a link, a formatted number. It always
counts as a value, even if the Html you pass shows nothing.

    DescriptionList.html "Status" (Badge.view [ Badge.tone Success ] "Active")

### `values`

```elm
values : String -> List (Html msg) -> Item msg
```

Several values for one label, side by side and wrapping onto more lines when
needed (tags, sales channels, phone numbers). An empty list counts as no value
and is shown as a dash.

### `fullWidth`

```elm
fullWidth : Item msg -> Item msg
```

Lets the item use the whole row, whatever the number of `columns`. For long
text such as notes.

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the list. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. The list sends no messages, so
the type has no `msg` parameter.

### `columns`

```elm
columns : Int -> Attribute
```

The largest number of columns, from 1 to 3 (other numbers are moved into that
range). Default 1. It is a maximum: the grid uses fewer columns when there is no
room for them, because a column is never narrower than 200px.

### `labelBeside`

```elm
labelBeside : Attribute
```

Puts the label in a column to the left of the value instead of above it. The
column is 160px wide; change it with `labelWidth`.

### `labelWidth`

```elm
labelWidth : Int -> Attribute
```

The width in pixels of the label column when the label is beside the value.
Default 160. Without `labelBeside` it has no effect.

### `bordered`

```elm
bordered : Attribute
```

A thin line under every row.

### `compact`

```elm
compact : Attribute
```

Tighter vertical spacing between the rows, for dense detail views. It follows a
compact density of the application (`Klar.Settings`) without it.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the hidden text that stands for a missing value: "Not
provided" in English, which is the default (`Locale.en`). The visible dash is the
same in every language.
