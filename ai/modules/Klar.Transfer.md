# Klar.Transfer

Two lists side by side, "Available" and "Chosen", and a way to move items from one to the other.

Import: `import Klar.Transfer as Transfer` | Group: Choosing

Types: `Msg`, `Order`, `State`, `Attribute`

## Signatures

```elm
-- State
type State id  -- opaque: no constructors are exposed
type Msg id  -- opaque: no constructors are exposed
init : String -> State id
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg

-- Value
values : State id -> List id
setValues : Picking.Ids id -> List id -> State id -> State id
clear : State id -> State id

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
type Order  -- opaque: no constructors are exposed
options : Picking.Ids id -> List (Select.Option.Option id) -> Attribute id msg
remote : Picking.Ids id -> Remote.Remote (List (Select.Option.Option id)) -> Attribute id msg
onRetry : msg -> Attribute id msg
titles : { available : String, chosen : String } -> Attribute id msg
sourceOrder : Order
movedOrder : Order
order : Order -> Attribute id msg

-- Field
label : String -> Attribute id msg
labelHidden : Attribute id msg
hint : String -> Attribute id msg
error : String -> Attribute id msg
errorMaybe : Maybe String -> Attribute id msg
required : Attribute id msg
optionalText : String -> Attribute id msg

-- Behavior and looks
valueText : (id -> String) -> Attribute id msg
disabled : Bool -> Attribute id msg
readOnly : Bool -> Attribute id msg
visibleRows : Int -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
```

## Documentation

Two lists side by side, "Available" and "Chosen", and a way to move items
from one to the other: the way to assign many things to one thing, such as
products to a promotion, users to a group or columns to an export. For picking a
few values from a list use [Klar.MultiSelect](Klar.MultiSelect.md), for values in a
hierarchy [Klar.TreeSelect](Klar.TreeSelect.md).

    import Klar.Picking as Picking
    import Klar.Select as Select
    import Klar.Transfer as Transfer

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { products : Transfer.State ProductId }

    init =
        { products = Transfer.init "promotion-products" }

    -- update
    ProductsMsg inner ->
        let
            ( products, cmd ) =
                Transfer.update inner model.products
        in
        ( { model | products = products }, Cmd.map ProductsMsg cmd )

    -- view
    Transfer.view ProductsMsg
        [ Transfer.label "Products in the promotion"
        , Transfer.options productIds
            (List.map (\p -> Select.option p.id p.name |> Select.withDescription p.sku) products)
        , Transfer.titles { available = "All products", chosen = "In the promotion" }
        ]
        model.products

    -- reading the value
    Transfer.values model.products --> List ProductId

The items are [Klar.Select](Klar.Select.md) options (see
[Klar.Select.Option](Klar.Select.Option.md)): a value of your own id type, a label, an
optional description, and `disabledOption` for an item that cannot be moved.
Ids are compared through their key (see `Picking.ids` in
[Klar.Picking](Klar.Picking.md)), which keeps thousands of items fast. As in every
Klar field, the state holds the value and there are no out-messages: compare
`Transfer.values` before and after `update` to react.

An item is in one of the lists and never in both: "Available" is the source without
what is chosen. The chosen ids are kept in the order of the source by default, so
the same set gives the same value; `order movedOrder` keeps them in the order the
user moved them in instead (for a list of columns, say). Only a move changes the
order of the value: marking, filtering and looking never do. Ids that you set with
`setValues` are put in the order of the items at once when the field has seen the
items (it has once it was looked at), and otherwise kept as you gave them until the
first move, so give them in the order of the items to have the same value from the
start. An id that the source no longer has stays in "Chosen" with the text
"Unknown value" (or what `valueText` writes) and can be taken out; it is never
dropped quietly. An item that is disabled and chosen is locked: it stays in
"Chosen".

Each list has a filter box above it and a header check box that marks everything
that is shown (a dash when only some are marked), with the count ("3 of 120
selected"). Items are marked with a click or Space and moved with the arrow
buttons between the lists (">" moves the marked items, ">>" all that are shown
after the filter), with a double click, or with the keyboard. The filter only
hides: an item that is marked and hidden by the filter stays marked, and is not
moved by ">" while it is hidden (the count says how many marked items are shown).
Both lists show only
the rows that are visible (see [Klar.VirtualList](Klar.VirtualList.md)), so a source
with many thousands of items stays fast. On a narrow space the lists are stacked
and the buttons sit between them (the field fills the width of its container, so
put it in one that has a width). Right-to-left languages are not supported: the
keys for moving between the lists assume left-to-right text.

Keyboard: Tab goes from the filter box to the list, to the buttons and on. In a
filter box Enter or ArrowDown moves on to the list (and never submits a form). In a
list ArrowDown and ArrowUp, Home and End, and PageUp and PageDown move the
highlight, and Shift with the arrows marks a range from where the last mark was
made (going back shrinks it). Space marks or unmarks the
highlighted item and Ctrl+A marks all that are shown. Enter moves the marked items
to the other list (the highlighted item when none is marked), Ctrl+ArrowRight in
"Available" and Ctrl+ArrowLeft in "Chosen" do the same, and with Shift they move
all that are shown. Typing letters jumps to the next item that starts with them
(an item that is disabled is skipped, as it is by the arrow keys).

Accessibility: the field is a `group` with the label; each list is a `listbox` with
`aria-multiselectable`, with the highlighted row named by `aria-activedescendant`,
and its rows are `option`s with `aria-selected` for the mark. The move buttons have
names ("Move selected to “Chosen”"). After a move, and after the filter changed, a
polite live region says what happened ("3 items moved to “Chosen”", "12 shown in
“Available”"). The built-in text follows `locale` and is
English by default (see [Klar.Locale](Klar.Locale.md)).

## State

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

Everything one transfer keeps track of: the chosen ids, the marks and the
filter text of each list, and which row is highlighted. Make it with `init`, keep
it in your model and pass it to `view` and `update`. The `id` is the type of your
ids.

### `Msg`

```elm
type Msg id  -- opaque: no constructors are exposed
```

The messages a transfer sends. Wrap it in a constructor of your own message
type (`ProductsMsg Transfer.Msg`), give that constructor to `view`, and pass the
messages you get back to `update`.

### `init`

```elm
init : String -> State id
```

A transfer with nothing chosen. The `String` is the DOM id of the field and
must be unique on the page: the label points to it, and the ids of the lists, the
filter boxes and the rows are derived from it (`products-available`,
`products-chosen`, `products-available-filter` ...).

    Transfer.init "promotion-products"

### `update`

```elm
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
```

Handles a message of the transfer and returns the new state with a command
(scrolling a list, clearing the type-ahead letters after a pause). Map the command
into your own message type with `Cmd.map`.

    ProductsMsg inner ->
        let
            ( products, cmd ) =
                Transfer.update inner model.products
        in
        ( { model | products = products }, Cmd.map ProductsMsg cmd )

### `view`

```elm
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
```

The transfer. It takes the constructor that wraps the component's `Msg` in your
own message type, a list of attributes, and the state.

    Transfer.view ProductsMsg
        [ Transfer.label "Products in the promotion"
        , Transfer.options productIds productOptions
        ]
        model.products

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

## Value

### `values`

```elm
values : State id -> List id
```

The chosen ids: in the order of the source (or the order of moving, see
`order`), and ids that the source does not have after the others. Ids set with
`setValues` are returned at once, also while the items are still loading.

### `setValues`

```elm
setValues : Picking.Ids id -> List id -> State id -> State id
```

Replaces the chosen ids from your code, for example to show a saved record.
Duplicates are dropped. An id that the items do not have is kept and shown as
"Unknown value".

    Transfer.setValues productIds [ sku1, sku2 ] model.products

### `clear`

```elm
clear : State id -> State id
```

Removes everything from "Chosen": `values` is empty again, without regard to
what is locked.

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of a transfer. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `Order`

```elm
type Order  -- opaque: no constructors are exposed
```

In which order the chosen ids are kept, given to `order`. It is one of
`sourceOrder` and `movedOrder`.

### `options`

```elm
options : Picking.Ids id -> List (Select.Option.Option id) -> Attribute id msg
```

The items to choose from, as options of [Klar.Select](Klar.Select.md), with the
`Ids` that write their values as keys. The default is no items. Use `options` or
`remote`, not both: the later one wins.

    Transfer.options productIds [ Select.option sku1 "Coffee 1 kg", Select.option sku2 "Tea 500 g" ]

An option that is `disabledOption` can be seen but not moved. When two options have
the same key the first one is used.

### `remote`

```elm
remote : Picking.Ids id -> Remote.Remote (List (Select.Option.Option id)) -> Attribute id msg
```

The items from the backend, as a `Remote` (see [Klar.Remote](Klar.Remote.md)).
"Available" shows loading rows while the data is `Loading` or `NotAsked`, a compact
error with a retry button on `Failed` (see `onRetry`), and the items on `Loaded`.
"Chosen" keeps showing what is chosen, with "Loading ..." for the labels it does
not know yet.

    Transfer.remote productIds model.products

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses the "Try again" button of the error
shown when the items (`remote`) failed to load. The button appears only for
problems that are worth retrying (network trouble, timeouts, server errors).

    Transfer.onRetry ReloadProducts

### `titles`

```elm
titles : { available : String, chosen : String } -> Attribute id msg
```

The titles of the two lists. The default is "Available" and "Chosen" (in the
language of `locale`). The titles name the lists for screen readers, label the
buttons and are used in the announcement after a move ("3 items moved to “In the
promotion”"), in quotes wherever a title is part of a sentence.

    Transfer.titles { available = "All products", chosen = "In the promotion" }

### `sourceOrder`

```elm
sourceOrder : Order
```

The chosen ids are kept in the order of the items, whatever the order in which
the user moved them. This is the default: after a move the same set of ids is always
the same value, so comparing the value before and after an update tells whether
anything changed. The value changes order only when the user moves items (or when
ids are set from the code and the field knows the items).

### `movedOrder`

```elm
movedOrder : Order
```

The chosen ids are kept in the order in which the user moved them, the newest
last: that order is the value, and `setValues` keeps the order it is given. Use it
when the order means something, such as the columns of an export.

### `order`

```elm
order : Order -> Attribute id msg
```

Sets the order of the chosen ids, see `Order`. The default is `sourceOrder`.

    Transfer.order Transfer.movedOrder

## Field

The label, hint and error around the field work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute id msg
```

The label above the field. It names the group for screen readers.

### `labelHidden`

```elm
labelHidden : Attribute id msg
```

Keeps the label for screen readers but does not draw it. It needs a `label`.

### `hint`

```elm
hint : String -> Attribute id msg
```

A short help text under the field. Screen readers read it with the group.

### `error`

```elm
error : String -> Attribute id msg
```

Shows an error message under the field. The message is announced to screen
readers when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute id msg
```

Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

### `required`

```elm
required : Attribute id msg
```

Marks the field as required: an asterisk after the label. It does not validate
anything; show a problem with `error`, for example when `values` is empty.

### `optionalText`

```elm
optionalText : String -> Attribute id msg
```

A text after the label of a field that is not `required`, such as
"(optional)".

## Behavior and looks

### `valueText`

```elm
valueText : (id -> String) -> Attribute id msg
```

How to write a chosen id that the items do not have, for example a product that
was removed. Without it the row says "Unknown value" (or the label that the
component saw when the id was moved).

    Transfer.valueText ProductId.toString

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

While `True` the field is dimmed and nothing can be marked or moved. The value
is kept. Pass a field of your model, for example while a form is saving. The
default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute id msg
```

While `True` the field shows its lists but does not let the user change them,
and the lists can still be scrolled and read. Unlike `disabled` it is not dimmed.
The two are independent; with both set the field is disabled. The default is
`False`.

### `visibleRows`

```elm
visibleRows : Int -> Attribute id msg
```

How many rows each list shows before it scrolls. The default is 10; numbers
below 4 or above 30 are brought into that range.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the titles, the filter boxes, the counts,
the button names, the announcement after a move and the labels for screen readers.
The default is `Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

    Transfer.locale Locale.nb
