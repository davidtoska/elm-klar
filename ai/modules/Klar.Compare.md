# Klar.Compare

Records side by side, with the differences marked: two or more products, two versions of an order, "your version" against "theirs".

Import: `import Klar.Compare as Compare` | Group: Text and change

Types: `Field`, `Attribute`

## Signatures

```elm
-- View
view :
    List (Attribute id msg)
    -> { ariaLabel : String, ids : Ids.Ids id, id : record -> id, header : record -> Html msg, fields : List (Field record msg) }
    -> List record
    -> Html msg
viewRemote :
    List (Attribute id msg)
    -> { ariaLabel : String, ids : Ids.Ids id, id : record -> id, header : record -> Html msg, fields : List (Field record msg) }
    -> Remote.Remote (List record)
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
onBaseline : (id -> msg) -> Attribute id msg
onlyDifferences : Bool -> Attribute id msg
onOnlyDifferences : (Bool -> msg) -> Attribute id msg
onRetry : msg -> Attribute id msg
id : String -> Attribute id msg
density : Theme.Density -> Attribute id msg
maxHeight : Int -> Attribute id msg
emptyState : List (EmptyState.Attribute msg) -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

Records side by side, with the differences marked: two or more products,
two versions of an order, "your version" against "theirs".

Use when: two or more records are read side by side and the application wants to see where they differ.
Do not use when: the change between two versions of one text or record is the point, use `Klar.Diff`; many records of one kind with sorting and paging, use `Klar.Table`.

    import Klar.Compare as Compare
    import Klar.Format as Format

    -- model: products : Remote (List Product), onlyDifferences : Bool
    -- update
    OnlyDifferencesChanged on ->
        ( { model | onlyDifferences = on }, Cmd.none )

    -- view
    Compare.viewRemote
        [ Compare.onlyDifferences model.onlyDifferences
        , Compare.onOnlyDifferences OnlyDifferencesChanged
        , Compare.onRetry ReloadProducts
        , Compare.settings model.settings
        ]
        { ariaLabel = "Compare products"
        , ids = productIds
        , id = .id
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
        model.products

Fields are the rows and the records are the columns. The first record is the
baseline (or the one you name with `baseline`, which the user can choose in the
headings with `onBaseline`); every other record is compared with it, cell by cell. A cell that differs says so with a sign (`≠`) and with hidden
text ("Differs from baseline") as well as with a color, a cell that is the same says
"Same as baseline" to a screen reader, and a row where every record is equal is
dimmed, or left out while `onlyDifferences` is `True` (the switch "Show only
differences" of `onOnlyDifferences` flips it). The headings of groups of fields
(`heading`) are left out with the rows under them.

**What counts as the same.** Every field gives a _text_ for each record, and two
records are the same in a field when the texts are exactly equal: no trimming and no
change of case. A text that is empty or only white space means that the record has no
value there, which is shown as a dash and is different from every real value (and the
same as another missing value). Functions are never compared, so a field that is
shown as a badge or as a formatted amount says what to compare with a text of its
own (`html`).

**States.** `view` takes the records you hold; `viewRemote` takes them as a
[Klar.Remote](Klar.Remote.md) (shape your data with `Remote.map`). `NotAsked` and
`Loading` draw a skeleton, `Failed` the problem with "Try again" (see `onRetry`), and
`Loaded []` the empty state ("Nothing to compare", see `emptyState`). Data that is
`Kept` stays on the screen: dimmed, busy and announced as "Refreshing ..." while a
refresh is on its way (`Remote.refresh`), and with "Old data from 14:05" and "Try
again" in the toolbar when the last refresh failed (the time is written in the zone of
`settings`). The table is the same element in all of these, so focus inside it stays
where it is. With one record there is nothing to compare it with, which the toolbar
says.

The table is a real `table` with `th scope="col"` for the records and `th
scope="row"` for the fields, inside a box that scrolls sideways and, with
`maxHeight`, up and down; that box is a region named by `ariaLabel` and a tab stop.
The row labels stay at the start and the headings at the top while it scrolls. The
component has no state: whether only the differences are shown is yours (a `Bool` in
your model).

**Right to left** pages are supported: the table, the sticky labels and the bar that marks
a difference follow the direction of the page (the `dir` attribute of the page).

**Cost.** The word marks in a long text (`longText`) are worked out once for each pair
of texts and kept while the texts stay the same (`Html.Lazy`), so a message of the
application that changes nothing in the comparison does not repeat them. All the long
texts of the table share a budget of about a third of a second; a pair that does not
fit in its part is shown without marks. The other fields cost one comparison of text
for each cell. The number of records is meant for a handful (a hundred columns work,
but are hard to read).

**No fields.** A comparison with no fields (or only headings) says "No fields", not
"No differences".

## View

### `view`

```elm
view :
    List (Attribute id msg)
    -> { ariaLabel : String, ids : Ids.Ids id, id : record -> id, header : record -> Html msg, fields : List (Field record msg) }
    -> List record
    -> Html msg
```

The comparison of the records you hold. `ariaLabel` names it for screen readers
("Compare products"): it names the box that scrolls, which is a region and a tab
stop. The records are the columns: the `header` of each record is whatever you want
in the column heading (a name, a status badge), `id` gives the id of a record in your
own type and `ids` how that type is written as a key ([Klar.Ids](Klar.Ids.md)). The id
is what `baseline` refers to, and it keeps the columns apart; two records with the
same id are both drawn. `fields` are the rows. An empty list draws the empty state.

The view sends a message only when a switch or a button you asked for is used
(`onOnlyDifferences`, `onRetry`).

    Compare.view [ Compare.baseline model.current ]
        { ariaLabel = "Compare versions"
        , ids = versionIds
        , id = .id
        , header = \version -> Html.text version.title
        , fields = [ Compare.text "Status" .status, Compare.longText "Notes" .notes ]
        }
        model.versions

### `viewRemote`

```elm
viewRemote :
    List (Attribute id msg)
    -> { ariaLabel : String, ids : Ids.Ids id, id : record -> id, header : record -> Html msg, fields : List (Field record msg) }
    -> Remote.Remote (List record)
    -> Html msg
```

The same comparison for records that come from the backend, in every state of a
[Klar.Remote](Klar.Remote.md): a skeleton while `NotAsked` or `Loading`, the problem
with "Try again" (`onRetry`) when `Failed`, the empty state for `Loaded []`, and the
table for `Loaded`. `Kept` data stays in the same table: dimmed and busy while it is
refreshed, and with the marker "Old data from 14:05" and "Try again" when the last
refresh failed.

    Compare.viewRemote
        [ Compare.onRetry ReloadProducts, Compare.settings model.settings ]
        productColumns
        (Remote.map .items model.products)

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
fields that belong to it. It has no values to compare, and when `onlyDifferences`
leaves out every field under it the heading is left out too.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of the comparison. Make them with the functions below and pass a list
to `view` or `viewRemote`; later attributes win over earlier ones. `id` is the type
of your ids of records and `msg` your message type.

### `baseline`

```elm
baseline : id -> Attribute id msg
```

The record the others are compared with, by its id. The default is the first
record. When no record has this id (it was taken out of the comparison), the first
record is the baseline again, and its column says so.

### `onBaseline`

```elm
onBaseline : (id -> msg) -> Attribute id msg
```

Lets the user choose the baseline: the heading of every record gets a small button
"Set as baseline", and the function gets the id of the record that was chosen. Keep
it in your model and give it back with `baseline`. The heading of the baseline says
"Baseline" in the same place, as a button that cannot be pressed
(`aria-disabled`), so the focus stays where the user pressed. A screen reader hears
each button with the title of its record ("Set as baseline Widget"): the ids that tie
them are made from `id`, or from the `ariaLabel` when there is none, so two
comparisons on one page need different ones. Without this attribute the baseline is
the application's choice alone. With a single record there is no button.

    Compare.onBaseline BaselineChosen

### `onlyDifferences`

```elm
onlyDifferences : Bool -> Attribute id msg
```

While `True`, the rows where every record is equal are left out, and so are the
headings above only such rows. The default is `False`: every row is drawn, and the
rows that are equal are dimmed. Keep the `Bool` in your model; with a single record
there is nothing to compare and every row is drawn.

    Compare.onlyDifferences model.onlyDifferences

### `onOnlyDifferences`

```elm
onOnlyDifferences : (Bool -> msg) -> Attribute id msg
```

Adds the switch "Show only differences" to the toolbar above the table. It is on
while `onlyDifferences` is `True`, and the function gets the new value when the user
flips it. Without this attribute there is no switch. With a single record the switch
is dimmed, as there is nothing to compare.

    Compare.onOnlyDifferences OnlyDifferencesChanged

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message sent by "Try again": in the failure (`Failed`), and in the marker of
old data (`Kept` after a refresh that failed). Without it there is no button, and the
button only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar.Remote.md)). The button goes away once the new data is there; give
the comparison an `id` and move focus to it when you start the request, so focus does
not fall to the page.

### `id`

```elm
id : String -> Attribute id msg
```

The DOM id of the comparison, unique on the page. The comparison is one element
in every state (loading, failed, empty, data), and with an id it can take focus, so
that `Klar.focus` has a place to put it when "Try again" goes away:

    Compare.id "compare-products"

    Retry ->
        ( { model | products = Remote.refresh model.products }
        , Cmd.batch [ fetchProducts, Klar.focus "compare-products" NoOp ]
        )

### `density`

```elm
density : Theme.Density -> Attribute id msg
```

How tightly the rows are packed, like the density of [Klar.Table](Klar.Table.md):
`Compact`, `Normal` or `Comfortable`. Without it, or with `Normal`, the rows follow
the density of the application (`Klar.Settings`).

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

    Compare.emptyState [ EmptyState.actions [ addProductButton ] ]

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the heading of the column of the fields, the
words for the baseline and the differences, the switch, the counts and the marker of
old data. The default is `Locale.default`, which is English. Your own labels and
values are shown as you give them.

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Compare.settings model.settings
