# Klar.MultiSelect

Choose several values from a searchable list.

Import: `import Klar.MultiSelect as MultiSelect` | Group: Choosing

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- State
type State id  -- opaque: no constructors are exposed
type Msg id  -- opaque: no constructors are exposed
init : String -> State id
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg

-- Values and popup
values : State id -> List id
setValues : List id -> State id -> State id
setOptions : List (Select.Option id) -> State id -> State id
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
searchPlaceholder : String -> Attribute id msg
clearable : Attribute id msg
creatable : (String -> id) -> Attribute id msg
valueText : (id -> String) -> Attribute id msg
disabled : Bool -> Attribute id msg
readOnly : Bool -> Attribute id msg
size : Theme.Size -> Attribute id msg
visibleRows : Int -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg

-- Limits and chips
maxSelected : Int -> Attribute id msg
maxVisibleChips : Int -> Attribute id msg
```

## Documentation

Choose several values from a searchable list. The chosen values are shown as
chips in the field; the list has a checkbox per option and stays open while the
user picks. Use [Klar.Select](Klar.Select.md) when exactly one value is wanted.

Use when: several values are chosen from a searchable list, shown as chips in the field.
Do not use when: exactly one value is wanted (`Klar.Select`) or a handful of options fit on screen (`Klar.CheckboxGroup`).
Quick path: `init`, `update`, `view`, `values`

    import Klar.MultiSelect as MultiSelect
    import Klar.Select as Select

    -- model: one State per field, of your own id type; the String is a DOM id,
    -- unique on the page
    type alias Model =
        { categories : MultiSelect.State CategoryId }

    init =
        { categories = MultiSelect.init "categories" }

    -- update
    CategoriesMsg inner ->
        let
            ( categories, cmd ) =
                MultiSelect.update inner model.categories
        in
        ( { model | categories = categories }, Cmd.map CategoriesMsg cmd )

    -- view
    MultiSelect.view CategoriesMsg
        [ MultiSelect.label "Product categories"
        , MultiSelect.options (List.map (\c -> Select.option c.id c.name) categories)
        , MultiSelect.maxVisibleChips 3
        ]
        model.categories

    -- reading the values, in the order they were chosen
    MultiSelect.values model.categories --> List CategoryId

It shares the option model, the search, the keyboard handling and the remote
states with [Klar.Select](Klar.Select.md): options are `Select.Option` values, made
with `Select.option` and its `with*` helpers. As there, the state holds the values,
so react to a change by comparing `MultiSelect.values` before and after in your
`update`.

The field shows the first five chips and "+N" for the rest (`maxVisibleChips`
changes that). A chosen value whose label is not known, because the options are
still loading or failed to load, is a muted "Loading ..." or "Could not be
loaded" chip, never the raw value (usually an id); `values` returns the values
all the time.

Under the list are the buttons "Select all" (or "Select all filtered" while a
search is active) and "Clear all", and a status line such as "12 of 40 matches ·
3 selected". `maxSelected` limits how many values can be chosen.

Keyboard: on the closed field Enter, Space, ArrowDown, ArrowUp or a printable
character open the list, and Backspace removes the last chip; the × of every chip
is a button. In the open list ArrowUp and ArrowDown, and PageUp and PageDown move
the highlight; Home and End go to the first and the last option while the search
box is empty (with text in it they move the caret), and Ctrl+Home and Ctrl+End
always do. Enter checks or unchecks the highlighted option, Backspace in an empty
search box removes the last chip, Escape closes the list, and Tab moves on to
"Try again" of old options (when it is shown), "Select all" and "Clear all", and
then out of the list. Backspace removes a chip only on a fresh key press, so
holding it down to delete search text never eats the chips. Keys that belong to
an input method composition (Japanese, Chinese, Korean ...) are left to it.

Accessibility: the field is a button with `role="combobox"` whose hidden text
lists the chosen values for screen readers ("3 selected: Books, Games, Toys"),
and the open list is a `listbox` with `aria-multiselectable`. The status line is
announced politely. The built-in texts follow `locale` and are English by
default (see [Klar.Locale](Klar.Locale.md)).

## State

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

Everything one multi select keeps track of: the chosen values in the order
they were chosen, the search text, and whether the list is open. Make it with
`init`, keep it in your model and pass it to `view` and `update`.

### `Msg`

```elm
type Msg id  -- opaque: no constructors are exposed
```

The messages a multi select sends. Wrap it in a constructor of your own
message type (`CategoriesMsg MultiSelect.Msg`), give that constructor to `view`,
and pass the messages you get back to `update`.

### `init`

```elm
init : String -> State id
```

A closed multi select with nothing chosen. The `String` is the DOM id of the
field and must be unique on the page: the label points to it, and the ids of the
open list are derived from it (`categories-search`, `categories-listbox`,
`categories-popup`).

    MultiSelect.init "categories"

### `update`

```elm
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
```

Handles a message of the multi select and returns the new state with a
command (moving focus, scrolling the list). Map the command into your own
message type with `Cmd.map`.

    CategoriesMsg inner ->
        let
            ( categories, cmd ) =
                MultiSelect.update inner model.categories
        in
        ( { model | categories = categories }, Cmd.map CategoriesMsg cmd )

### `view`

```elm
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
```

The multi select. It takes the constructor that wraps the component's `Msg`
in your own message type, a list of attributes, and the state.

    MultiSelect.view CategoriesMsg
        [ MultiSelect.label "Product categories"
        , MultiSelect.options categoryOptions
        , MultiSelect.maxSelected 5
        ]
        model.categories

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

## Values and popup

### `values`

```elm
values : State id -> List id
```

The chosen values, in the order they were chosen: the `value` of every
chosen option. The list is empty when nothing is chosen. Values set with
`setValues` are returned at once, also while the options are still loading.

### `setValues`

```elm
setValues : List id -> State id -> State id
```

Replaces the chosen values from your code, for example to show a saved
record. Duplicates are dropped (in a list of up to 2000 values; a longer list is
taken as it is, so give unique values). The labels are looked up in the options
when the field is shown; use `setOptions` when the options may not contain them
(server search). A value that the loaded options do not contain is a chip with the
text `valueText` makes of it, or "Unknown value" without `valueText`. The
`maxSelected` limit is not applied to values set this way.

    MultiSelect.setValues [ "books", "games" ] model.categories

### `setOptions`

```elm
setOptions : List (Select.Option id) -> State id -> State id
```

Replaces the chosen values with these options and stores them, so the chips
show their labels even when the current options do not contain them. Use it for
saved values with a server search, where the options are only the latest hits.

    MultiSelect.setOptions [ Select.option "c-42" "Contoso Ltd" ] model.customers

### `clear`

```elm
clear : State id -> State id
```

Removes all chosen values, so `values` is empty again.

### `query`

```elm
query : State id -> String
```

The text in the search box while the list is open, and `""` when it is
closed. With `serverSearch`, fetch when it changes: it then follows the box after a
pause of 300 ms in the typing, so it does not change on every key.

### `isOpen`

```elm
isOpen : State id -> Bool
```

Whether the list is open.

### `open`

```elm
open : State id -> ( State id, Cmd (Msg id) )
```

Opens the list with an empty search and moves focus into its search box,
for example from a button of your own. Map the command like the one from
`update`.

    OpenCategories ->
        let
            ( categories, cmd ) =
                MultiSelect.open model.categories
        in
        ( { model | categories = categories }, Cmd.map CategoriesMsg cmd )

### `close`

```elm
close : State id -> ( State id, Cmd (Msg id) )
```

Closes the list, forgets the search text, and gives focus back to the field
if the list was open. Map the command like the one from `update`.

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of a multi select. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `options`

```elm
options : List (Select.Option id) -> Attribute id msg
```

Local options. The component filters and ranks them itself as the user
types. The default is no options. Use `options` or `remote`, not both: the later
one wins.

    MultiSelect.options [ Select.option "books" "Books", Select.option "toys" "Toys" ]

### `remote`

```elm
remote : Remote.Remote (List (Select.Option id)) -> Attribute id msg
```

Options from the backend, as a `Remote` (see [Klar.Remote](Klar.Remote.md)).
The list shows loading rows while the data is `Loading` or `NotAsked`, a compact
error with a retry button on `Failed` (see `onRetry`), the empty state on
`Loaded []`, and the options on `Loaded`. Options that are `Kept` stay in the
list: dimmed and busy while they are refreshed, and with "Old data from 14:05"
and a retry (`onRetry`) at the top of the list when the last refresh failed.

    MultiSelect.remote model.categories

### `serverSearch`

```elm
serverSearch : Attribute id msg
```

The server does the searching. The component shows the options exactly as
they come and does not filter them; the application fetches when
`MultiSelect.query` changes, which waits for a pause of 300 ms in the typing, so
**write no debounce of your own** (drop an answer whose query is no longer the current
one). While the options are `NotAsked` (nothing fetched
yet, or a text too short to search for) the list says "Type to search". Chosen
values keep their labels as chips even when a later search no longer returns
them.

    -- in update
    CategoriesMsg inner ->
        let
            ( categories, cmd ) =
                MultiSelect.update inner model.categories
        in
        if MultiSelect.query categories /= MultiSelect.query model.categories then
            ( { model | categories = categories, found = Remote.refresh model.found }
            , Cmd.batch [ Cmd.map CategoriesMsg cmd, searchCategories (MultiSelect.query categories) ]
            )

        else
            ( { model | categories = categories }, Cmd.map CategoriesMsg cmd )

    -- in view
    MultiSelect.view CategoriesMsg [ MultiSelect.serverSearch, MultiSelect.remote model.found ] model.categories

`Remote.refresh` keeps the hits of the last search on screen, dimmed and busy,
until the new ones arrive, so the list does not flash empty on every pause in the
typing.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses the "Try again" button of the error
shown when `remote` options failed. The button appears only for problems that are
worth retrying (network trouble, timeouts, server errors); while it is shown,
Enter in the search box sends the message as well. For other problems (no
access, not found ...) nothing is retried, and Enter does nothing.

    MultiSelect.onRetry ReloadCategories

## Field

The label, hint and error around the field work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute id msg
```

The label above the field. It names the multi select for screen readers.

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

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute id msg
```

Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

    MultiSelect.errorMaybe model.categoriesError

### `required`

```elm
required : Attribute id msg
```

Marks the field as required: an asterisk after the label and
`aria-required` for screen readers. It does not validate anything; show a
problem with `error`, for example when `values` is empty.

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

The text shown while nothing is chosen. Default "Select ..." (in the
language of `locale`).

### `searchPlaceholder`

```elm
searchPlaceholder : String -> Attribute id msg
```

The placeholder of the search box in the open list. Default "Search ..."
(in the language of `locale`).

### `clearable`

```elm
clearable : Attribute id msg
```

Shows a small × in the field that removes all chosen values. Nothing is
shown while no value is chosen.

### `creatable`

```elm
creatable : (String -> id) -> Attribute id msg
```

Offers a first row `Create “Acme Ltd”` (for a search text "Acme Ltd") when
the search text matches no option exactly, ignoring case and diacritics.
Choosing it adds a new value and keeps the list open: the typed text is the
label, and the value is what the function you give makes of the text (the text
itself for a select of `String`s, or a value of your own type). Add it to your
options if it should stay in the list.

    MultiSelect.creatable identity

### `valueText`

```elm
valueText : (id -> String) -> Attribute id msg
```

How to write a value that is in none of the options, for example a saved
value with a server search whose hits do not contain it. Without it the chip says
"Unknown value". The label of an option you know about is always its own; use
`setOptions` to give the select those options.

    MultiSelect.valueText CustomerId.toString

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

While `True` the field is dimmed, cannot be focused or opened, and its chips
have no remove buttons. The values are kept. Pass a field of your model, for
example while a form is saving. The default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute id msg
```

While `True` the field shows its chips but does not let the user change
them: the list does not open, and there is no chevron, clear button or remove
button. Unlike `disabled`, a read-only field can be focused. The default is
`False`.

### `size`

```elm
size : Theme.Size -> Attribute id msg
```

The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar.Theme.md). The default is `Medium`. The chips are small in a
`Small` field and medium otherwise.

### `visibleRows`

```elm
visibleRows : Int -> Attribute id msg
```

How many rows the open list shows before it scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the placeholders, the search box, the
chip and button labels, the counts under the list, the empty and error states
and the labels for screen readers. The default is `Locale.default`, which is
English. See [Klar.Locale](Klar.Locale.md).

    MultiSelect.locale Locale.nb

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    MultiSelect.settings model.settings

## Limits and chips

### `maxSelected`

```elm
maxSelected : Int -> Attribute id msg
```

The most values the user can choose, at least 1. By default there is no
limit. When the limit is reached the options that are not chosen are dimmed and
cannot be chosen, "Select all" adds only as many values as are left, and the
status line reads "3 of max 3 selected". The limit is not applied to
`setValues` and `setOptions`.

    MultiSelect.maxSelected 3

### `maxVisibleChips`

```elm
maxVisibleChips : Int -> Attribute id msg
```

Shows at most this many chips and a "+N" chip for the rest. The default is
5, so that the field does not grow with the selection: "Select all" on a long
list would otherwise fill the page. The chips wrap onto as many lines as they
need, so a higher number makes a taller field; 200 is the most. The "+N" chip
names the hidden values in its tooltip, and the list shows every chosen value
ticked.
