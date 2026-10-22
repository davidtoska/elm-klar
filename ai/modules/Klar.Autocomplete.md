# Klar.Autocomplete

A text field with suggestions.

Import: `import Klar.Autocomplete as Autocomplete` | Group: Choosing

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- Value
text : State -> String
setText : String -> State -> State
picked : State -> Maybe String
isOpen : State -> Bool

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
options : List (Select.Option.Option String) -> Attribute msg
suggestions : Remote.Remote (List (Select.Option.Option String)) -> Attribute msg
onRetry : msg -> Attribute msg
onEnter : msg -> Attribute msg

-- Field
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Behavior and looks
placeholder : String -> Attribute msg
minChars : Int -> Attribute msg
clearable : Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
size : Theme.Size -> Attribute msg
visibleRows : Int -> Attribute msg
prefixIcon : Icon.Icon -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A text field with suggestions. Unlike [Klar.Select](Klar.Select.md) the user may
type anything: the suggestions only help. Use it for free text that often
repeats earlier values (a city, a company name, a product title), and `Select`
when only listed values are valid.

    import Klar.Autocomplete as Autocomplete
    import Klar.Select as Select

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { city : Autocomplete.State }

    init =
        { city = Autocomplete.init "city" }

    -- update
    CityMsg inner ->
        let
            ( city, cmd ) =
                Autocomplete.update inner model.city
        in
        ( { model | city = city }, Cmd.map CityMsg cmd )

    -- view
    Autocomplete.view CityMsg
        [ Autocomplete.label "City"
        , Autocomplete.options (List.map (\name -> Select.option name name) cities)
        ]
        model.city

    Autocomplete.text model.city --> what is in the field
    Autocomplete.picked model.city --> Just value when the text came from a suggestion

Suggestions are options (`Select.Option`, made with `Select.option` and its
`with*` helpers, see [Klar.Select.Option](Klar.Select.Option.md)): the label is what
the field shows when one is picked, and the value is what `picked` returns. They
are filtered locally (`options`) or come from the application (`suggestions`, a
`Remote`): then fetch when `Autocomplete.text` changes. The list shows loading
rows, a failure with a retry button, or "No suggestions".

Keyboard: typing shows the suggestions with none highlighted, so Enter keeps the
typed text. ArrowDown and ArrowUp move through the suggestions (ArrowUp on the
first one returns to the typed text), PageDown and PageUp move a page, Enter
picks the highlighted suggestion, Escape closes the list, and Tab closes it and
moves on. The field keeps focus while a suggestion is clicked, and the list
closes when the field loses focus.

Accessibility: the input is a `combobox` with `aria-expanded`, `aria-controls`
and `aria-activedescendant` over a `listbox` of `option`s. A hidden live region
announces "3 suggestions", "Loading ..." and "No suggestions". The built-in texts
follow `locale` and are English by default (see [Klar.Locale](Klar.Locale.md)).

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Everything one autocomplete keeps track of: the text in the field, the value
of the suggestion it came from (if any), and whether the list is open. Make it
with `init`, keep it in your model and pass it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages an autocomplete sends. Wrap it in a constructor of your own
message type (`CityMsg Autocomplete.Msg`), give that constructor to `view`, and
pass the messages you get back to `update`.

### `init`

```elm
init : String -> State
```

An empty field. The `String` is the DOM id of the input and must be unique
on the page: the label points to it, and the id of the list is derived from it
(`city-listbox`).

    Autocomplete.init "city"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
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

With `suggestions`, compare `Autocomplete.text` before and after to see when to
fetch.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
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

## Value

### `text`

```elm
text : State -> String
```

What is in the field: what the user typed, or the label of the suggestion
they picked. With `suggestions` from a backend, fetch when it changes.

### `setText`

```elm
setText : String -> State -> State
```

Replaces the text, for example to show a saved value. It clears `picked` and
closes the list.

    Autocomplete.setText "Rotterdam" model.city

### `picked`

```elm
picked : State -> Maybe String
```

The value of the suggestion the text came from, or `Nothing` when the text is
free. It is set when a suggestion is picked, or when Enter is pressed on a text
that is exactly the label of a suggestion (ignoring case and diacritics), and it
is cleared as soon as the text is edited or replaced with `setText`.

### `isOpen`

```elm
isOpen : State -> Bool
```

Whether the suggestion list is open. It can be `True` while nothing is
visible, because there are no suggestions to show.

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of an autocomplete. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `options`

```elm
options : List (Select.Option.Option String) -> Attribute msg
```

Suggestions that the component filters itself as the user types: best match
first, ignoring case and diacritics, with several words that must all match, in
labels, descriptions and keywords (the scoring of [Klar.Search](Klar.Search.md), see
[Klar.Select.Option](Klar.Select.Option.md)). The list is hidden while nothing
matches. The default is no suggestions. Use `options` or `suggestions`, not both:
the later one wins.

    Autocomplete.options (List.map (\name -> Select.option name name) cities)

### `suggestions`

```elm
suggestions : Remote.Remote (List (Select.Option.Option String)) -> Attribute msg
```

Suggestions from the application, usually the backend, as a `Remote` (see
[Klar.Remote](Klar.Remote.md)). They are shown exactly as they come and the
component does not filter them; the typed text is highlighted in them. Fetch
when `Autocomplete.text` changes. The list is hidden while the data is
`NotAsked`, shows loading rows (and a spinner in the field) while `Loading`, an
error on `Failed` (see `onRetry`), and "No suggestions" on `Loaded []`.

    Autocomplete.suggestions model.citySuggestions

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message to send when the user presses the "Try again" button of the error
shown when `suggestions` failed. The button appears only for problems that are
worth retrying (network trouble, timeouts, server errors); while it is shown,
Enter in the field sends the message as well. For other problems (no access, not
found ...) nothing is retried, and Enter keeps the typed text as usual.

    Autocomplete.onRetry ReloadCities

### `onEnter`

```elm
onEnter : msg -> Attribute msg
```

The message to send when the user presses Enter and no suggestion is
highlighted, so the typed text is kept (to run a search for it, for example). It
arrives after the component has updated `picked`, so you can read
`Autocomplete.text` and `Autocomplete.picked` in your handler. Picking a
suggestion is a state change instead: compare `Autocomplete.picked` before and
after to react to it.

    Autocomplete.onEnter SearchSubmitted

## Field

The label, hint and error around the field work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute msg
```

The label above the field. It names the input for screen readers.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Keeps the label for screen readers but does not draw it. Use it when the
surroundings already name the field, as in a toolbar or a table cell. It needs a
`label`.

### `hint`

```elm
hint : String -> Attribute msg
```

A short help text under the field. Screen readers read it with the field
(`aria-describedby`).

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.
It is safe to set it while the user types: the input keeps its place in the
page, and so its keyboard focus, whether or not there is a label or a hint.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

    Autocomplete.errorMaybe model.cityError

### `required`

```elm
required : Attribute msg
```

Marks the field as required: an asterisk after the label and
`aria-required` for screen readers. It does not validate anything; show a
problem with `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

A text after the label of a field that is not `required`, such as
"(optional)". Required fields show no such text.

## Behavior and looks

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

The text shown in the empty field. There is none by default.

### `minChars`

```elm
minChars : Int -> Attribute msg
```

How many characters the user has to type before suggestions appear. The
default is 1, and spaces at the ends do not count. ArrowDown opens the list
whatever the length.

### `clearable`

```elm
clearable : Attribute msg
```

Shows a small × that empties the field, closes the list and returns focus to
the field. It is shown only while the field has text.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the field is dimmed and cannot be focused or edited. The text
is kept. Pass a field of your model, for example while a form is saving. The
default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

While `True` the field shows its text but does not let the user change it,
and no suggestions are shown. Unlike `disabled`, a read-only field can be focused
and its text selected. The default is `False`.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar.Theme.md). The default is `Medium`.

### `visibleRows`

```elm
visibleRows : Int -> Attribute msg
```

How many suggestions show before the list scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.

### `prefixIcon`

```elm
prefixIcon : Icon.Icon -> Attribute msg
```

An icon at the start of the field, such as a magnifying glass. There is none
by default.

    Autocomplete.prefixIcon Icon.search

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: "No suggestions", "Loading ...", the
suggestion count for screen readers, the "Clear search" label and the error
state. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar.Locale.md).

    Autocomplete.locale Locale.nb
