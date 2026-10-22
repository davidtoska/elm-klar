# Klar.SearchInput

A search field that waits until the user stops typing.

Import: `import Klar.SearchInput as SearchInput` | Group: Inputs

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Reading the search
text : State -> String
committed : State -> String
isPending : State -> Bool

-- Changing the search from the application
setText : String -> State -> State
clear : State -> State
focus : State -> Cmd Msg

-- Timing
debounce : Int -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
ariaLabel : String -> Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
optionalText : String -> Attribute msg

-- Appearance and behavior
placeholder : String -> Attribute msg
shortcutHint : String -> Attribute msg
loading : Bool -> Attribute msg
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
name : String -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

A search field that waits until the user stops typing.

    import Klar.Remote as Remote exposing (Remote)
    import Klar.SearchInput as SearchInput

    type alias Model =
        { search : SearchInput.State
        , orders : Remote (List Order)
        }

    init : Model
    init =
        { search = SearchInput.init "order-search"
        , orders = Remote.NotAsked
        }

    -- update
    SearchMsg inner ->
        let
            ( search, cmd ) =
                SearchInput.update inner model.search

            searchChanged =
                SearchInput.committed search /= SearchInput.committed model.search
        in
        ( { model | search = search }
        , Cmd.batch
            [ Cmd.map SearchMsg cmd
            , if searchChanged then
                findOrders (SearchInput.committed search)

              else
                Cmd.none
            ]
        )

    -- view
    SearchInput.view SearchMsg
        [ SearchInput.placeholder "Search orders ..."
        , SearchInput.shortcutHint "/"
        , SearchInput.loading (Remote.isLoading model.orders)
        ]
        model.search

**Debounce without ports.** The state holds two texts: `text`, what is in the
field right now, and `committed`, the text the application should search for.
Every keystroke starts a short timer (`debounce`, 300 ms) and remembers a
counter; when the timer fires only the last keystroke is still current, and
only then is `committed` set to `text`. Enter commits at once, and the clear
button (or Escape) empties and commits at once. The application starts a
search when `committed` differs from before `update`. The timer is a `Cmd`
returned by `update`, so pass it on with `Cmd.map`: if it is dropped, typed text
is never committed.

**Keyboard and accessibility.** Enter commits the text and never submits a
surrounding form. Escape clears a field that has text; in an empty field the key
is left alone, so it can still close a dialog. A search field usually has no
visible `label`, so give it an `ariaLabel` (the default is "Search"). While the
search runs, `loading` shows a spinner that is announced as "Searching ...".

`shortcutHint` only draws the key in the field: bind the key itself with
[Klar.Shortcut](Klar.Shortcut.md) and use `focus` to move the cursor into the
field.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe` and `optionalText` are the
common field attributes. They come with the field wrapper
([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they mean the
same in all of them: the wrapper draws the label, the hint and the error message
around the input and connects them for screen readers (`for`,
`aria-describedby`, `aria-invalid`). A search field has no `required`, and its
DOM id comes from `init`, so there is no `id` attribute. The field is always
inside the wrapper, also when it has no `label`, `hint` or `error` to draw (the
usual case), so it stays where it is and keeps the keyboard focus when the
application shows an error while the user is typing. A wrapper with nothing to
draw takes the place and the width of the field alone.

The built-in texts (the default accessible name, the clear button and the
spinner) follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a search field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A search field with a magnifying glass and a clear button. The first
argument wraps the field's own messages in one of yours, and the state comes
last.

    SearchInput.view SearchMsg
        [ SearchInput.ariaLabel "Search products"
        , SearchInput.debounce 400
        ]
        model.search

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a search field: the text in the field and the text to search
for. Make one with `init`, keep it in your model and give it to `view` and
`update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages a search field sends: typing, the pause timer, Enter and the
clear button. `view` wraps them with the function you give it; hand them to
`update` when they come back.

### `init`

```elm
init : String -> State
```

An empty search field. The `String` is the DOM id of the input; it must be
unique on the page, because `focus` and the label point at it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. The `Cmd` holds the pause
timer and the focus after the clear button, so pass it on with `Cmd.map`: if it
is dropped, typed text is never committed (Enter still commits).

## Reading the search

### `text`

```elm
text : State -> String
```

What is in the field right now, including text that is not committed yet.

### `committed`

```elm
committed : State -> String
```

The text to search for: `text` after the user paused (or pressed Enter).
Compare it before and after `update` to know when to start a search.

### `isPending`

```elm
isPending : State -> Bool
```

`True` while the text in the field differs from the committed text: the user
has typed something and the pause is not over yet.

## Changing the search from the application

### `setText`

```elm
setText : String -> State -> State
```

Puts a text in the field and commits it at once, for example a search
restored from the address. A pause timer that is still running is ignored.

### `clear`

```elm
clear : State -> State
```

Empties the field and commits the empty text.

### `focus`

```elm
focus : State -> Cmd Msg
```

A command that moves the keyboard focus into the field, for example when the
user presses the key you show with `shortcutHint`. Map it into your own message
type.

    Cmd.map SearchMsg (SearchInput.focus model.search)

## Timing

### `debounce`

```elm
debounce : Int -> Attribute msg
```

Milliseconds to wait after the last keystroke before the text is committed.
Default 300; 0 (or less) commits on every keystroke.

    SearchInput.debounce 500

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label shown above the field. It is connected to the input, so clicking
it focuses the input and screen readers read it as the name of the input. A
search field usually has no visible label: then give it an `ariaLabel` (the
default is "Search").

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the input when the field has no `label`. It is not
shown. Default "Search" (see `locale`). It is ignored when there is a `label`.

    SearchInput.ariaLabel "Search products"

### `hint`

```elm
hint : String -> Attribute msg
```

Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` shown after the `label`. By default nothing is
shown. A search field has no `required` attribute, so the text is shown whenever
there is a label.

## Appearance and behavior

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty field, for example `"Search orders ..."`. It is
not a substitute for an accessible name (see `ariaLabel`), and it disappears as
soon as the user types. Default: none.

### `shortcutHint`

```elm
shortcutHint : String -> Attribute msg
```

Draws a key cap such as `/` or `Ctrl K` at the end of the field while it is
empty, not `loading` and not `disabled`. It is only a picture, hidden from
screen readers: bind the key itself with [Klar.Shortcut](Klar.Shortcut.md) and move
the cursor into the field with `focus`.

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` a small spinner is shown inside the field, announced as
"Searching ...", so that the user sees the search is running. Pass whether your
search request is on its way. Default `False`.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px), from [Klar.Theme](Klar.Theme.md). Default `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the field is dimmed and cannot be focused or changed, and the
clear button is hidden. Default `False`.

### `name`

```elm
name : String -> Attribute msg
```

The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the default accessible name ("Search"),
the clear button ("Clear search") and the spinner label ("Searching ...").
Default `Locale.default`, which is English. Texts you pass in yourself are shown
as they are.
