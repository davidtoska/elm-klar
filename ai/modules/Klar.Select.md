# Klar.Select

A single select with a search box, for lists from a handful to many thousands of options.

Import: `import Klar.Select as Select` | Group: Choosing

Types: `Msg`, `State`, `Attribute`, `Option`

## Signatures

```elm
-- State
type State id  -- opaque: no constructors are exposed
type Msg id  -- opaque: no constructors are exposed
init : String -> State id
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg

-- Value and popup
value : State id -> Maybe id
setValue : id -> State id -> State id
setOption : Option id -> State id -> State id
clear : State id -> State id
query : State id -> String
isOpen : State id -> Bool
open : State id -> ( State id, Cmd (Msg id) )
close : State id -> ( State id, Cmd (Msg id) )

-- Options
type alias Option id = Select.Option.Option id
option : id -> String -> Option id
withDescription : String -> Option id -> Option id
withGroup : String -> Option id -> Option id
withIcon : Icon.Icon -> Option id -> Option id
withTone : Theme.Tone -> Option id -> Option id
withColor : Color.Color -> Option id -> Option id
withKeywords : List String -> Option id -> Option id
disabledOption : Option id -> Option id
mapOption : (a -> b) -> Option a -> Option b
filter : String -> List (Option id) -> List (Option id)

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
options : List (Option id) -> Attribute id msg
remote : Remote.Remote (List (Option id)) -> Attribute id msg
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
```

## Documentation

A single select with a search box, for lists from a handful to many
thousands of options. Use it when only listed values are valid; for free text
with suggestions use [Klar.Autocomplete](Klar.Autocomplete.md), and to choose
several values [Klar.MultiSelect](Klar.MultiSelect.md).

Use when: exactly one value is chosen from a list of a handful to many thousands of options, and only listed values are valid.
Do not use when: the user may type anything (`Klar.Autocomplete`) or several values are chosen (`Klar.MultiSelect`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.Select as Select

    -- model: one State per select, of your own id type; the String is a DOM id,
    -- unique on the page
    type alias Model =
        { country : Select.State CountryCode }

    init =
        { country = Select.init "country" }

    -- update
    CountryMsg inner ->
        let
            ( country, cmd ) =
                Select.update inner model.country
        in
        ( { model | country = country }, Cmd.map CountryMsg cmd )

    -- view
    Select.view CountryMsg
        [ Select.label "Country"
        , Select.options (List.map (\c -> Select.option c.code c.name) countries)
        , Select.clearable
        ]
        model.country

    -- reading the value
    Select.value model.country --> Maybe CountryCode

The state holds the chosen value, the search text and whether the list is open,
and there are no out-messages: react to a change by comparing the state before
and after in your `update`, for example `Select.value new /= Select.value old`.
The value is the `value` of the chosen option, of whatever type you gave it (a
`CustomerId`, a code, an `Int`): there is nothing to convert, and the chosen
value comes back as the same id. Values are compared with `==`, so keep them
plain data.

Typing filters the list the way [Klar.Search](Klar.Search.md) scores text: best
match first, ignoring case and diacritics, several words that must all match,
also in descriptions and keywords. The matches are highlighted. The options are
indexed once and the result is kept between keystrokes, and only the visible rows
are rendered (see [Klar.VirtualList](Klar.VirtualList.md)), so a list with several
thousand options stays responsive.

Keyboard: on the closed field Enter, Space, ArrowDown and ArrowUp open the list,
a printable character opens it and starts the search, and Backspace or Delete
clears a `clearable` field. In the open list ArrowUp and ArrowDown, Home and End,
and PageUp and PageDown move the highlight, Enter chooses (and never submits a
surrounding form), Escape closes the list and returns to the field, and Tab
closes it and moves on.

Accessibility: the field is a button with `role="combobox"` and `aria-expanded`.
The open list is a `listbox` whose options carry `aria-selected`,
`aria-posinset` and `aria-setsize`, and the search box points at the highlighted
option with `aria-activedescendant`. The counts under the list ("12 of 40
matches") are announced politely.

Backend data: `remote` takes a `Remote (List Option)` (see
[Klar.Remote](Klar.Remote.md)) and shows loading rows, a failure with a retry button
(`onRetry`) and the empty state. With `serverSearch` the select does not filter;
the application watches `Select.query` and fetches. The built-in texts ("Select
...", "No matches", "Loading ...") follow `locale` and are English by default
(see [Klar.Locale](Klar.Locale.md)).

## State

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

Everything one select keeps track of: the chosen value, the search text,
whether the list is open and which row is highlighted. Make it with `init`, keep
it in your model and pass it to `view` and `update`.

### `Msg`

```elm
type Msg id  -- opaque: no constructors are exposed
```

The messages a select sends. Wrap it in a constructor of your own message
type (`CountryMsg Select.Msg`), give that constructor to `view`, and pass the
messages you get back to `update`.

### `init`

```elm
init : String -> State id
```

A closed select without a value. The `String` is the DOM id of the field and
must be unique on the page: the label points to it, and the ids of the open list
are derived from it (`country-search`, `country-listbox`, `country-popup`).

    Select.init "country"

### `update`

```elm
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
```

Handles a message of the select and returns the new state with a command
(moving focus, scrolling the list). Map the command into your own message type
with `Cmd.map`.

    CountryMsg inner ->
        let
            ( country, cmd ) =
                Select.update inner model.country
        in
        ( { model | country = country }, Cmd.map CountryMsg cmd )

### `view`

```elm
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
```

The select. It takes the constructor that wraps the component's `Msg` in
your own message type, a list of attributes, and the state.

    Select.view CountryMsg
        [ Select.label "Country"
        , Select.options countryOptions
        , Select.required
        ]
        model.country

Always give the select a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

## Value and popup

### `value`

```elm
value : State id -> Maybe id
```

The chosen value: the `value` of the chosen option, or `Nothing` when
nothing is chosen. A value set with `setValue` is returned at once, also while
the options are still loading.

### `setValue`

```elm
setValue : id -> State id -> State id
```

Chooses a value from your code, for example to show a saved record. The
label is looked up in the options when the select is shown; use `setOption` when
the option may not be among them (server search).

While the options are still loading (`Loading` or `NotAsked`) and the label is
not known, the field shows a muted "Loading ..." instead of the value, and "Could
not be loaded" when they failed: a value is usually an id, and an id is not
something to read out in a form. Once the options have loaded without it, or
with `serverSearch`, the field shows the value itself. `value` returns the value
all the time.

    Select.setValue "de" model.country

### `setOption`

```elm
setOption : Option id -> State id -> State id
```

Chooses an option and stores it, so the field shows its label even when the
current options do not contain it. Use it for a saved value with a server
search, where the options are only the latest hits.

    Select.setOption (Select.option "c-42" "Contoso Ltd") model.customer

### `clear`

```elm
clear : State id -> State id
```

Removes the chosen value, so `value` is `Nothing` again.

### `query`

```elm
query : State id -> String
```

The text in the search box while the list is open, and `""` when it is
closed. With `serverSearch`, fetch when it changes.

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

    OpenCountry ->
        let
            ( country, cmd ) =
                Select.open model.country
        in
        ( { model | country = country }, Cmd.map CountryMsg cmd )

### `close`

```elm
close : State id -> ( State id, Cmd (Msg id) )
```

Closes the list, forgets the search text, and gives focus back to the field
if the list was open. Map the command like the one from `update`.

## Options

Options are plain records, shared with `MultiSelect` and `Autocomplete`. These
are the helpers of [Klar.Select.Option](Klar.Select.Option.md) that a select needs,
so one import is enough.

### `Option`

```elm
type alias Option id = Select.Option.Option id
```

One choice in the list. It is a record with `value` (what the application
stores), `label` (what the user sees and searches), `description`, `group`,
`disabled`, `icon` and `keywords`, as described in
[Klar.Select.Option](Klar.Select.Option.md). Make options with `option` and the
`with*` functions, or write the record yourself.

### `option`

```elm
option : id -> String -> Option id
```

An option with a value (what the application stores) and a label (what the
user sees and searches). The chosen option's value is what `value` returns.

    Select.option "de" "Germany"

### `withDescription`

```elm
withDescription : String -> Option id -> Option id
```

A short secondary text, shown dimmed after the label in the list. It is
searched too, but a match in the description ranks below the same match in the
label.

    Select.option "de" "Germany" |> Select.withDescription "DE"

### `withGroup`

```elm
withGroup : String -> Option id -> Option id
```

Lists the option under a heading with this name. Options with the same group
are shown together, groups in the order they first appear, and options without a
group come first. Headings are not options: the keyboard skips them.

### `withIcon`

```elm
withIcon : Icon.Icon -> Option id -> Option id
```

An icon drawn before the label in the list. When the option is chosen, the
closed field shows it next to the label.

### `withTone`

```elm
withTone : Theme.Tone -> Option id -> Option id
```

A dot in a status color before the label, in the list and in the closed field:
`Success` green, `Warning` amber, `Danger` red. It follows the theme. The label must
say the same, because a color alone is not read by everyone.

    Select.option "late" "Delayed" |> Select.withTone Danger

### `withColor`

```elm
withColor : Color.Color -> Option id -> Option id
```

A dot in a color from your data before the label, in the list and in the closed
field. For options that come from a database, build each option from its row and
give it the color of the row (see [Klar.Color](Klar.Color.md)):

    Select.option row.id row.name
        |> Select.withColor color

### `withKeywords`

```elm
withKeywords : List String -> Option id -> Option id
```

Extra words that also match the option: synonyms, codes, old names. They are
searched but never shown.

    Select.option "us" "United States" |> Select.withKeywords [ "USA", "America" ]

### `disabledOption`

```elm
disabledOption : Option id -> Option id
```

Shows the option dimmed in the list and keeps it from being chosen: it cannot
be clicked or highlighted, and the arrow keys skip it. It is still searched.

### `mapOption`

```elm
mapOption : (a -> b) -> Option a -> Option b
```

Gives the option another kind of value and keeps the label, description,
group, icon, keywords and disabled flag. Handy to turn options over your own id
type into options over a text key, or the other way round.

    Select.option (CustomerId 7) "Contoso Ltd"
        |> Select.mapOption (\(CustomerId n) -> String.fromInt n)

### `filter`

```elm
filter : String -> List (Option id) -> List (Option id)
```

The options matching a query, best first, exactly as the select filters
them. Handy for a simulated backend or for showing a count elsewhere.

    Select.filter "ger" countries |> List.map .label

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of a select. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `options`

```elm
options : List (Option id) -> Attribute id msg
```

Local options. The select filters and ranks them itself as the user types.
The default is no options. Use `options` or `remote`, not both: the later one
wins.

    Select.options [ Select.option "de" "Germany", Select.option "fr" "France" ]

### `remote`

```elm
remote : Remote.Remote (List (Option id)) -> Attribute id msg
```

Options from the backend, as a `Remote` (see [Klar.Remote](Klar.Remote.md)).
The list shows loading rows while the data is `Loading` or `NotAsked`, a compact
error with a retry button on `Failed` (see `onRetry`), the empty state on
`Loaded []`, and the options on `Loaded`. Options that are `Kept` stay in the
list: dimmed and busy while they are refreshed, and with "Old data from 14:05"
and a retry (`onRetry`) at the top of the list when the last refresh failed.

    Select.remote model.countries

### `serverSearch`

```elm
serverSearch : Attribute id msg
```

The server does the searching. The select shows the options exactly as they
come and does not filter them; the application fetches when `Select.query`
changes. While the options are `NotAsked` (nothing fetched yet, or a text too
short to search for) the list says "Type to search".

    -- in update
    CountryMsg inner ->
        let
            ( country, cmd ) =
                Select.update inner model.country
        in
        if Select.query country /= Select.query model.country then
            ( { model | country = country, countries = Remote.Loading }
            , Cmd.batch [ Cmd.map CountryMsg cmd, fetchCountries (Select.query country) ]
            )

        else
            ( { model | country = country }, Cmd.map CountryMsg cmd )

    -- in view
    Select.view CountryMsg [ Select.serverSearch, Select.remote model.countries ] model.country

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses the "Try again" button of the error
shown when `remote` options failed. The button appears only for problems that are
worth retrying (network trouble, timeouts, server errors); while it is shown,
Enter in the search box sends the message as well. For other problems (no
access, not found ...) nothing is retried, and Enter does nothing.

    Select.onRetry ReloadCountries

## Field

The label, hint and error around the select work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute id msg
```

The label above the field. It names the select for screen readers.

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

    Select.errorMaybe model.countryError

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

Shows a small × in the field that removes the chosen value. Backspace and
Delete do the same on the focused field. Nothing is shown while no value is
chosen.

### `creatable`

```elm
creatable : (String -> id) -> Attribute id msg
```

Offers a first row `Create “Acme Ltd”` (for a search text "Acme Ltd") when
the search text matches no option exactly, ignoring case and diacritics.
Choosing it makes the typed text the label, and the value is what the function
you give makes of the text: the text itself for a select of `String`s, or a
value of your own type (a draft id, a new entity). Add it to your options if it
should stay in the list.

    Select.creatable identity -- the typed text is the value

### `valueText`

```elm
valueText : (id -> String) -> Attribute id msg
```

How to write a value that is in none of the options, for example a saved
value with a server search whose hits do not contain it. Without it the field
says "Unknown value". The text of an option you know about is always its label;
use `setOption` to give the select that option.

    Select.valueText CustomerId.toString

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

While `True` the select is dimmed, cannot be focused or opened, and has no
clear button. The value is kept. Pass a field of your model, for example while a
form is saving. The default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute id msg
```

While `True` the select shows its value but does not let the user change it:
the list does not open, and there is no chevron or clear button. Unlike
`disabled`, a read-only field can be focused. The default is `False`.

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

How many rows the open list shows before it scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the placeholders, the search box, the
counts under the list, the empty and error states and the labels for screen
readers. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar.Locale.md).

    Select.locale Locale.nb

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Select.settings model.settings
