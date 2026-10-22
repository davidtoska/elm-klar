# Klar.Compare

Records side by side, with the differences marked: two or more products, two versions of an order, "your version" against "theirs".

Import: `import Klar.Compare as Compare` | Group: Text and change

Types: `Field`, `Attribute`

## Signatures

```elm
-- View
view :
    List (Attribute id msg)
    -> { label : String, records : Remote.Remote (List record), id : record -> id, toKey : id -> String, header : record -> Html msg, fields : List (Field record msg) }
    -> Html msg

-- Fields
type Field record msg  -- opaque: no constructors are exposed
text : String -> (record -> String) -> Field record msg
maybe : String -> (record -> Maybe String) -> Field record msg
html : String -> (record -> String) -> (record -> Html msg) -> Field record msg
longText : String -> (record -> String) -> Field record msg
heading : String -> Field record msg

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
baseline : id -> Attribute id msg
onlyDifferences : Bool -> (Bool -> msg) -> Attribute id msg
onRetry : msg -> Attribute id msg
refreshing : Bool -> Attribute id msg
density : Theme.Density -> Attribute id msg
maxHeight : Int -> Attribute id msg
emptyState : List (EmptyState.Attribute msg) -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
```

## Documentation

Records side by side, with the differences marked: two or more products,
two versions of an order, "your version" against "theirs".

Use when: two or more records are read side by side and the application wants to see where they differ.
Do not use when: the change between two versions of one text or record is the point, use `Klar.Diff`.

    import Klar.Compare as Compare
    import Klar.Format as Format

    Compare.view
        [ Compare.baseline model.current
        , Compare.onlyDifferences model.onlyDifferences OnlyDifferencesChanged
        , Compare.onRetry ReloadProducts
        ]
        { label = "Compare products"
        , records = model.products -- Remote (List Product)
        , id = .id
        , toKey = ProductId.toString
        , header = \product -> Html.text product.name
        , fields =
            [ Compare.text "SKU" .sku
            , Compare.heading "Pricing"
            , Compare.html "Price"
                (\product -> String.fromFloat product.price)
                (\product -> Html.text (Format.currency Locale.en "$" 2 product.price))
            , Compare.maybe "Discount" (Maybe.map String.fromInt << .discount)
            , Compare.heading "Description"
            , Compare.longText "Summary" .summary
            ]
        }

Fields are the rows and the records are the columns. The first record is the
baseline (or the one you name with `baseline`); every other record is compared
with it, cell by cell. A cell that differs says so with a sign (`≠`) and with hidden
text ("Differs from baseline") as well as with a color, a cell that is the same says
"Same as baseline" to a screen reader, and a row where every record is equal is
dimmed, or left out when the switch "Show only differences" is on (see
`onlyDifferences`). The headings of groups of fields (`heading`) are left out with
the rows under them.

**What counts as the same.** Every field gives a _text_ for each record, and two
records are the same in a field when the texts are exactly equal: no trimming and no
change of case. A text that is empty or only white space means that the record has no
value there, which is shown as a dash and is different from every real value (and the
same as another missing value). Functions are never compared, so a field that is
shown as a badge or as a formatted amount says what to compare with a text of its
own (`html`).

**States.** The records are a [Klar.Remote](Klar.Remote.md): `Loading` and `NotAsked`
draw a skeleton, `Failure` the error with "Try again" (see `onRetry`), and `Success
[]` an empty state ("Nothing to compare", see `emptyState`). With one record there is
nothing to compare it with, which the toolbar says. Pass `refreshing True` while new
data is on its way and the old table is still shown.

The table is a real `table` with `th scope="col"` for the records and `th
scope="row"` for the fields, inside a box that scrolls sideways and, with
`maxHeight`, up and down, and is a tab stop. The row labels stay at the left and the
headings at the top while it scrolls. The component has no state: the switch
"Show only differences" is yours (a `Bool` in your model).

**Right to left** pages are supported: the table, the sticky labels and the bar that marks
a difference follow the direction of the page (the `dir` attribute of the page).

**Cost.** The word marks in a long text (`longText`) are worked out in `view`, in
all about a third of a second for the whole table; the texts after that are shown without
marks. Keep the table to a handful of records, and long texts to the fields that need
them. The other fields cost one comparison of text for each cell.

**No fields.** A comparison with no fields (or only headings) says "No fields", not
"No differences".

Use [Klar.Table](Klar.Table.md) for many records of the same kind with sorting and
paging, and [Klar.Diff](Klar.Diff.md) for what changed between two versions of one text
or one record. The number of records is meant for a handful (a hundred columns work,
but are hard to read).

## View

### `view`

```elm
view :
    List (Attribute id msg)
    -> { label : String, records : Remote.Remote (List record), id : record -> id, toKey : id -> String, header : record -> Html msg, fields : List (Field record msg) }
    -> Html msg
```

The comparison. `label` names it for screen readers ("Compare products"), and
it names the area that scrolls, which is a region and a tab stop. `records` are the
columns: the `header` of each record is whatever you want in the column heading (a
name, a status badge), `id` gives the id of a record in your own type and `toKey`
writes that id as a text (the id is what `baseline` refers to, and it keeps the
columns apart; two records with the same id are both drawn). `fields` are the rows.

The view sends a message only when a switch or a button you asked for is used
(`onlyDifferences`, `onRetry`).

## Fields

### `Field`

```elm
type Field record msg  -- opaque: no constructors are exposed
```

A row of the comparison: a field of the records, or the heading of a group of
fields. Make them with `text`, `maybe`, `html`, `longText` and `heading`, and give a
list of them to `view`; the rows come in that order. The `record` is your type of
record and the `msg` the message type of the Html you pass to `html`.

### `text`

```elm
text : String -> (record -> String) -> Field record msg
```

A field that is a text. It is shown as it is and two records are the same in it
when the texts are the same. A blank text is no value.

    Compare.text "SKU" .sku

### `maybe`

```elm
maybe : String -> (record -> Maybe String) -> Field record msg
```

A field that a record may not have: `Nothing` is no value, shown as a dash.

    Compare.maybe "Discount" (.discount >> Maybe.map String.fromInt)

### `html`

```elm
html : String -> (record -> String) -> (record -> Html msg) -> Field record msg
```

A field that is shown as Html (a badge, a formatted amount, a link) and compared
as a text. The first function gives the text that makes two records equal, the second
what is shown. Give the exact value as the text and the formatted one as the Html: two
prices that look the same after rounding are still different prices.

    Compare.html "Status"
        (\product -> Status.toString product.status)
        (\product -> Badge.view [] (Status.label product.status))

A blank text is no value, and then the Html is not drawn: a dash is.

### `longText`

```elm
longText : String -> (record -> String) -> Field record msg
```

A text of some length, such as a description or a note. It is wrapped over
several lines, and in the cells that differ from the baseline the words that
differ are marked: words only the baseline has are struck through and words only
this record has are underlined. A text that has nothing in common with the baseline
is shown as it is.

    Compare.longText "Summary" .summary

### `heading`

```elm
heading : String -> Field record msg
```

The heading of a group of fields, a full row such as "Pricing" above the
fields that belong to it. It has no values to compare, and when the switch "Show only
differences" leaves out every field under it the heading is left out too.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of the comparison. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. `id` is the type of your ids of
records and `msg` your message type.

### `baseline`

```elm
baseline : id -> Attribute id msg
```

The record the others are compared with, by its id. The default is the first
record. When no record has this id (it was taken out of the comparison), the first
record is the baseline again, and its column says so.

### `onlyDifferences`

```elm
onlyDifferences : Bool -> (Bool -> msg) -> Attribute id msg
```

Adds the switch "Show only differences" above the table. The `Bool` says
whether it is on (keep it in your model, `False` at the start) and the function gets
the new value when the user flips the switch. While it is on, the rows where every
record is equal, and the headings above only such rows, are left out. Without this
attribute there is no switch and all rows are drawn. With a single record the switch
is dimmed, as there is nothing to compare.

    Compare.onlyDifferences model.onlyDifferences OnlyDifferencesChanged

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses "Try again" in the error state, which
shows when `records` is a `Failure`. Without it there is no button, and the button
only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar.Remote.md)).

### `refreshing`

```elm
refreshing : Bool -> Attribute id msg
```

Pass `True` while new data is on its way and you still hold the old records: the
table stays, dimmed, with a progress line under the headings, and screen readers hear
"Refreshing ...". It only applies to `Success`; the skeleton is shown while the
records are loading. The default is `False`.

### `density`

```elm
density : Theme.Density -> Attribute id msg
```

How tightly the rows are packed, like the density of [Klar.Table](Klar.Table.md):
`Compact`, `Normal` or `Comfortable`. Without it the rows follow the density of
the application (`Klar.Settings`).

### `maxHeight`

```elm
maxHeight : Int -> Attribute id msg
```

Scrolls inside the table when it is taller than this many pixels, with the
headings of the records staying at the top. By default the table grows with its
rows; it scrolls sideways inside its own box in any case.

### `emptyState`

```elm
emptyState : List (EmptyState.Attribute msg) -> Attribute id msg
```

Changes the empty state, which shows when there are no records: it has a title
("Nothing to compare") and a description, and these attributes are applied after
them, so yours win. Use it to say how to add records and to give the button for it.

    Compare.emptyState [ EmptyState.action addProductButton ]

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the heading of the column of the fields, the
words for the baseline and the differences, the switch and the counts. The default is
`Locale.default`, which is English. Your own labels and values are shown as you give
them.
