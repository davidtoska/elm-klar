# Klar.Autocomplete

A text field with suggestions.

Import: `import Klar.Autocomplete as Autocomplete` | Group: Choosing

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- State
type State id  -- opaque: no constructors are exposed
type Msg id  -- opaque: no constructors are exposed
init : String -> State id
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg

-- Value and popup
text : State id -> String
setText : String -> State id -> State id
picked : State id -> Maybe id
setOption : Select.Option id -> State id -> State id
clear : State id -> State id
query : State id -> String
isOpen : State id -> Bool
open : State id -> ( State id, Cmd (Msg id) )
close : State id -> ( State id, Cmd (Msg id) )

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
options : List (Select.Option id) -> Attribute id msg
remote : Remote.Remote (List (Select.Option id)) -> Attribute id msg
serverSearch : Attribute id msg
onRetry : msg -> Attribute id msg
onEnter : msg -> Attribute id msg

-- Field
label : String -> Attribute id msg
labelHidden : Attribute id msg
hint : String -> Attribute id msg
error : String -> Attribute id msg
errorMaybe : Maybe String -> Attribute id msg
required : Attribute id msg
optionalText : String -> Attribute id msg

-- Behavior and looks
placeholder : String -> Attribute id msg
minChars : Int -> Attribute id msg
clearable : Attribute id msg
disabled : Bool -> Attribute id msg
readOnly : Bool -> Attribute id msg
size : Theme.Size -> Attribute id msg
visibleRows : Int -> Attribute id msg
prefixIcon : Icon.Icon -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A text field with suggestions. Unlike [Klar.Select](Klar.Select.md) the user may
type anything: the suggestions only help. Use it for free text that often
repeats earlier values (a city, a company name, a product title), and `Select`
when only listed values are valid.

Use when: free text that often repeats earlier values, such as a city or a company name, where the suggestions only help.
Do not use when: only listed values are valid (`Klar.Select`).
Quick path: `init`, `update`, `view`, `text`, `picked`

    import Klar.Autocomplete as Autocomplete
    import Klar.Select as Select

    -- model: one State per field, of the type of the suggestions' values; the
    -- String is a DOM id, unique on the page
    type alias Model =
        { customer : Autocomplete.State CustomerId }

    init =
        { customer = Autocomplete.init "customer" }

    -- update
    CustomerMsg inner ->
        let
            ( customer, cmd ) =
                Autocomplete.update inner model.customer
        in
        ( { model | customer = customer }, Cmd.map CustomerMsg cmd )

    -- view
    Autocomplete.view CustomerMsg
        [ Autocomplete.label "Customer"
        , Autocomplete.options (List.map (\c -> Select.option c.id c.name) customers)
        ]
        model.customer

    Autocomplete.text model.customer --> what is in the field
    Autocomplete.picked model.customer --> Just the CustomerId when the text is a suggestion

Suggestions are options (`Select.Option`, made with `Select.option` and its
`with*` helpers): the label is what the field shows when one is picked, and the
value, of your own type, is what `picked` returns. Give them as a list
(`options`) or as a `Remote` loaded from the backend (`remote`): either way the
field filters and ranks them as the user types, as `Select` does. When the server
does the searching, add `serverSearch`: fetch when `Autocomplete.query` changes
(it waits for a pause in the typing) and the field shows the hits as they come,
or "No suggestions". A `remote` list shows loading rows and a failure with a retry
button. To show a saved record, `setOption` puts its text and its value back.

Keyboard: typing shows the suggestions with none highlighted, so Enter keeps the
typed text. ArrowDown and ArrowUp move through the suggestions (ArrowUp on the
first one returns to the typed text), PageDown and PageUp move a page, Enter
picks the highlighted suggestion, Escape closes the list, and Tab closes it and
moves on (also when the suggestions failed: Enter retries). Home and End move the
caret, as in every text field, and the keys of an input method composition
(Japanese, Chinese, Korean ...) are left to it. The field keeps focus while a
suggestion is clicked, and the list closes when the field loses focus.

`picked` is the same however the user leaves the field: a text that is exactly
the label of a suggestion (ignoring case and diacritics) is that suggestion,
whether the user pressed Enter, Tab or Escape or clicked elsewhere.

Accessibility: the input is a `combobox` with `aria-expanded`, `aria-controls`
and `aria-activedescendant` over a `listbox` of `option`s. A hidden live region
announces "3 suggestions", "Loading ..." and "No suggestions". The built-in texts
follow `locale` and are English by default (see [Klar.Locale](Klar.Locale.md)).

## State

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

Everything one autocomplete keeps track of: the text in the field, the value
of the suggestion it came from (if any), and whether the list is open. `id` is
the type of the suggestions' values (a `CustomerId`, or `String`). Make it with
`init`, keep it in your model and pass it to `view` and `update`.

### `Msg`

```elm
type Msg id  -- opaque: no constructors are exposed
```

The messages an autocomplete sends. Wrap it in a constructor of your own
message type (`CityMsg (Autocomplete.Msg String)`), give that constructor to
`view`, and pass the messages you get back to `update`.

### `init`

```elm
init : String -> State id
```

An empty field. The `String` is the DOM id of the input and must be unique
on the page: the label points to it, and the ids of the list are derived from it
(`city-listbox`, `city-popup`).

    Autocomplete.init "city"

### `update`

```elm
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
```

Handles a message of the autocomplete and returns the new state with a
command (moving focus, scrolling the list). Map the command into your own
message type with `Cmd.map`.

    CityMsg inner ->
        let
            ( city, cmd ) =
                Autocomplete.update inner model.city
        in
        ( { model | city = city }, Cmd.map CityMsg cmd )

With `serverSearch`, compare `Autocomplete.query` before and after to see when to
fetch.

### `view`

```elm
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
```

The autocomplete. It takes the constructor that wraps the component's `Msg`
in your own message type, a list of attributes, and the state.

    Autocomplete.view CityMsg
        [ Autocomplete.label "City"
        , Autocomplete.options cityOptions
        , Autocomplete.minChars 2
        , Autocomplete.clearable
        ]
        model.city

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

## Value and popup

### `text`

```elm
text : State id -> String
```

What is in the field: what the user typed, or the label of the suggestion
they picked. With `serverSearch`, fetch when `query` changes.

### `setText`

```elm
setText : String -> State id -> State id
```

Replaces the text, for example to show a saved free text. It clears `picked`
and closes the list; use `setOption` when the text is a suggestion, and `clear` to
empty the field (`setText ""` is the same thing).

    Autocomplete.setText "Rotterdam" model.city

### `picked`

```elm
picked : State id -> Maybe id
```

The value of the suggestion the text came from, or `Nothing` when the text is
free. It is set when a suggestion is picked, or when the list closes (Enter, Tab,
Escape or a click elsewhere) on a text that is exactly the label of a suggestion
(ignoring case and diacritics), and it is cleared as soon as the text is edited or
replaced with `setText`.

### `setOption`

```elm
setOption : Select.Option id -> State id -> State id
```

Puts a suggestion in the field as if the user had picked it: its label is the
text, and its value is what `picked` returns. Use it to show a saved record whose
value you keep, for example the customer of an order being edited.

    Autocomplete.setOption (Select.option order.customerId order.customerName) model.customer

### `clear`

```elm
clear : State id -> State id
```

Empties the field: no text, nothing `picked`, and the list closed. This is
the way to empty the field from code; `setText ""` is the same thing.

### `query`

```elm
query : State id -> String
```

The text to fetch `serverSearch` suggestions for: it follows `text` after a pause of
300 ms in the typing (at once when a suggestion is picked, the field is cleared or
`setText` or `setOption` is called), so **write no debounce of your own**. Fetch
when it changes, and drop an answer whose text is no longer the current `query`.

    if Autocomplete.query city /= Autocomplete.query model.city then
        fetchCities (Autocomplete.query city)

### `isOpen`

```elm
isOpen : State id -> Bool
```

Whether the suggestion list is open. It can be `True` while nothing is
visible, because there are no suggestions to show.

### `open`

```elm
open : State id -> ( State id, Cmd (Msg id) )
```

Opens the suggestion list for the text in the field and moves focus into the
field, for example from a button of your own. Map the command like the one from
`update`.

    ShowCities ->
        let
            ( city, cmd ) =
                Autocomplete.open model.city
        in
        ( { model | city = city }, Cmd.map CityMsg cmd )

### `close`

```elm
close : State id -> ( State id, Cmd (Msg id) )
```

Closes the suggestion list and keeps the text. Map the command like the one
from `update`.

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of an autocomplete. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. `id` is the type of the
suggestions' values.

### `options`

```elm
options : List (Select.Option id) -> Attribute id msg
```

Suggestions that the component filters itself as the user types: best match
first, ignoring case and diacritics, with several words that must all match, in
labels, descriptions and keywords (the scoring of [Klar.Search](Klar.Search.md)).
The list is hidden while nothing matches. The default is no suggestions. Use
`options` or `remote`, not both: the later one wins. For a list that comes from
the backend, give its `Remote` to `remote` rather than flattening it with
`Remote.withDefault`, so the field shows its loading and failed states.

    Autocomplete.options (List.map (\name -> Select.option name name) cities)

### `remote`

```elm
remote : Remote.Remote (List (Select.Option id)) -> Attribute id msg
```

Suggestions from the backend, as a `Remote` (see [Klar.Remote](Klar.Remote.md)).
Like `Select.remote`, the field filters and ranks them as the user types, the
same as `options`, so a list loaded once needs nothing else; add `serverSearch`
when the server does the searching. The list is hidden while the data is
`NotAsked`, shows loading rows (and a spinner in the field) while `Loading`, and
an error on `Failed` (see `onRetry`). Suggestions that are `Kept` stay in the
list: dimmed and busy while they are refreshed, and with "Old data from 14:05" at
the top of the list when the last refresh failed (the list is not a place for a
button: the focus stays in the field, so use the notice of the page for the
retry).

    Autocomplete.remote model.cities

### `serverSearch`

```elm
serverSearch : Attribute id msg
```

The server does the searching: the field shows the `remote` suggestions exactly
as they come and does not filter them (the typed text is still highlighted in
them), and says "No suggestions" on `Loaded []`. Fetch when `Autocomplete.query`
changes: it waits for a pause of 300 ms in the typing, so **write no debounce of
your own**, and drop an answer whose query is no longer the current one.

    -- in update
    CustomerMsg inner ->
        let
            ( customer, cmd ) =
                Autocomplete.update inner model.customer
        in
        if Autocomplete.query customer /= Autocomplete.query model.customer then
            ( { model | customer = customer, found = Remote.refresh model.found }
            , Cmd.batch [ Cmd.map CustomerMsg cmd, fetchCustomers (Autocomplete.query customer) ]
            )

        else
            ( { model | customer = customer }, Cmd.map CustomerMsg cmd )

    -- in view
    Autocomplete.view CustomerMsg [ Autocomplete.serverSearch, Autocomplete.remote model.found ] model.customer

`Remote.refresh` keeps the hits of the last search on screen, dimmed and busy,
until the new ones arrive. Without `remote` it changes nothing.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses the "Try again" button of the error
shown when `remote` suggestions failed. The button appears only for problems that
are worth retrying (network trouble, timeouts, server errors), and it is for the
mouse: the focus stays in the field, where Enter sends the message as well and Tab
moves on. For other problems (no access, not found ...) nothing is retried, and
Enter keeps the typed text as usual.

    Autocomplete.onRetry ReloadCities

### `onEnter`

```elm
onEnter : msg -> Attribute id msg
```

The message to send when the user presses Enter and no suggestion is
highlighted, so the typed text is kept (to run a search for it, for example). It
arrives after the component has updated `picked`, so you can read
`Autocomplete.text` and `Autocomplete.picked` in your handler. Picking a
suggestion is a state change instead: compare `Autocomplete.picked` before and
after to react to it. A `disabled` or `readOnly` field sends nothing.

    Autocomplete.onEnter SearchSubmitted

## Field

The label, hint and error around the field work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute id msg
```

The label above the field. It names the input for screen readers.

### `labelHidden`

```elm
labelHidden : Attribute id msg
```

Keeps the label for screen readers but does not draw it. Use it when the
surroundings already name the field, as in a toolbar or a table cell. It needs a
`label`.

### `hint`

```elm
hint : String -> Attribute id msg
```

A short help text under the field. Screen readers read it with the field
(`aria-describedby`).

### `error`

```elm
error : String -> Attribute id msg
```

Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.
It is safe to set it while the user types: the input keeps its place in the
page, and so its keyboard focus, whether or not there is a label or a hint.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute id msg
```

Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

    Autocomplete.errorMaybe model.cityError

### `required`

```elm
required : Attribute id msg
```

Marks the field as required: an asterisk after the label and
`aria-required` for screen readers. It does not validate anything; show a
problem with `error`.

### `optionalText`

```elm
optionalText : String -> Attribute id msg
```

A text after the label of a field that is not `required`, such as
"(optional)". Required fields show no such text.

## Behavior and looks

### `placeholder`

```elm
placeholder : String -> Attribute id msg
```

The text shown in the empty field. There is none by default: the field takes
free text, so there is nothing general to say.

### `minChars`

```elm
minChars : Int -> Attribute id msg
```

How many characters the user has to type before suggestions appear. The
default is 1, and spaces at the ends do not count. ArrowDown opens the list
whatever the length.

### `clearable`

```elm
clearable : Attribute id msg
```

Shows a small × that empties the field, closes the list and returns focus to
the field. It is shown only while the field has text.

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

While `True` the field is dimmed and cannot be focused or edited. The text
is kept. Pass a field of your model, for example while a form is saving. The
default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute id msg
```

While `True` the field shows its text but does not let the user change it,
and no suggestions are shown. Unlike `disabled`, a read-only field can be focused
and its text selected. The default is `False`.

### `size`

```elm
size : Theme.Size -> Attribute id msg
```

The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar.Theme.md). The default is `Medium`.

### `visibleRows`

```elm
visibleRows : Int -> Attribute id msg
```

How many suggestions show before the list scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.

### `prefixIcon`

```elm
prefixIcon : Icon.Icon -> Attribute id msg
```

An icon at the start of the field, such as a magnifying glass. There is none
by default.

    Autocomplete.prefixIcon Icon.search

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: "No suggestions", "Loading ...", the
suggestion count for screen readers, the "Clear search" label and the error
state. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar.Locale.md).

    Autocomplete.locale Locale.nb

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Autocomplete.settings model.settings
