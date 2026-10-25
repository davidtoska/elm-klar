module Klar.Select exposing
    ( State, init, Msg, update, view
    , value, setValue, setOption, clear, query, isOpen, open, close
    , Option, option, withDescription, withMeta, withGroup, withIcon, withTone, withColor, withKeywords, disabledOption, mapOption, filter
    , Attribute, options, remote, serverSearch, onRetry
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, searchPlaceholder, clearable, creatable, valueText, disabled, readOnly, size, visibleRows, locale, settings
    )

{-| A single select with a search box, for lists from a handful to many
thousands of options. Use it when only listed values are valid; for free text
with suggestions use [Klar.Autocomplete](Klar-Autocomplete), and to choose
several values [Klar.MultiSelect](Klar-MultiSelect).

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

Typing filters the list the way [Klar.Search](Klar-Search) scores text: best
match first, ignoring case and diacritics, several words that must all match,
also in descriptions and keywords. The matches are highlighted. The options are
indexed once and the result is kept between keystrokes, and only the visible rows
are rendered (see [Klar.VirtualList](Klar-VirtualList)), so a list with several
thousand options stays responsive.

Keyboard: on the closed field Enter, Space, ArrowDown and ArrowUp open the list,
a printable character opens it and starts the search, and Backspace or Delete
clears a `clearable` field. In the open list ArrowUp and ArrowDown, and PageUp and
PageDown move the highlight; Home and End go to the first and the last option
while the search box is empty (with text in it they move the caret), and Ctrl+Home
and Ctrl+End always do. Enter chooses (and never submits a surrounding form),
Escape closes the list and returns to the field, and Tab closes it and moves on
(to "Try again" first, when old or failed options offer it). Keys that belong to
an input method composition (Japanese, Chinese, Korean ...) are left to it: the
Enter that confirms the composed text does not choose an option.

Accessibility: the field is a button with `role="combobox"` and `aria-expanded`.
The open list is a `listbox` whose options carry `aria-selected`,
`aria-posinset` and `aria-setsize` (and the name of their group), and the search
box points at the highlighted option with `aria-activedescendant` while that
option is drawn. The counts under the list ("12 of 40 matches") are announced
politely.

Backend data: `remote` takes a `Remote (List Option)` (see
[Klar.Remote](Klar-Remote)) and shows loading rows, a failure with a retry button
(`onRetry`) and the empty state. With `serverSearch` the select does not filter;
the application watches `Select.query` and fetches. The built-in texts ("Select
...", "No matches", "Loading ...") follow `locale` and are English by default
(see [Klar.Locale](Klar-Locale)).


# State

@docs State, init, Msg, update, view


# Value and popup

@docs value, setValue, setOption, clear, query, isOpen, open, close


# Options

Options are plain records, shared with `MultiSelect`, `Autocomplete` and
`Transfer`: this is the one place to make them, so one import is enough.

@docs Option, option, withDescription, withMeta, withGroup, withIcon, withTone, withColor, withKeywords, disabledOption, mapOption, filter


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, options, remote, serverSearch, onRetry


# Field

The label, hint and error around the select work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs placeholder, searchPlaceholder, clearable, creatable, valueText, disabled, readOnly, size, visibleRows, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Color exposing (Color)
import Klar.Field as Field
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select.Match as Match
import Klar.Select.Option as Option
import Klar.Select.Popup as Popup
import Klar.Settings as Settings exposing (Settings)
import Klar.Theme as Theme exposing (Size(..), Tone)
import Klar.VirtualList as VirtualList
import Process
import Task



-- OPTIONS


{-| One choice in the list, the option type of the whole select family
(`MultiSelect`, `Autocomplete`, `Transfer` and `Rule.choiceFieldOf` take the same
values). Make options with `option` and the `with*` functions, also in a data module
or a simulated backend that has no select of its own. Read the fields as you like
(`.label`, `.value`), but do not write the record by hand: it may gain fields.

  - `value` is what the application stores: its own id type (a `CustomerId`, a code, an `Int`).
    Values are compared with `==`, so use data, not functions, and keep them unique within one
    list (two options with the same value both show as chosen)
  - `label` is what the user sees and searches
  - `description` is a short secondary text, shown dimmed after the label and searched too
  - `group` lists the option under a heading, together with the options of the same group
  - `disabled` shows the option dimmed and keeps it from being chosen
  - `icon` is drawn before the label
  - `tone` and `color` mark the option with a small dot before the label, a status color that
    follows the theme or a color from your data (never both; the last one set wins)
  - `keywords` are extra words that also match but are never shown (synonyms, codes, old names)
  - `meta` is a short value at the end of the row, in tabular figures (a stock count, a code)

-}
type alias Option id =
    { value : id
    , label : String
    , description : Maybe String
    , group : Maybe String
    , disabled : Bool
    , icon : Maybe Icon
    , tone : Maybe Tone
    , color : Maybe Color
    , keywords : List String
    , meta : Maybe String
    }


{-| An option with a value (what the application stores) and a label (what the
user sees and searches). The chosen option's value is what `value` returns.

    Select.option "de" "Germany"

-}
option : id -> String -> Option id
option =
    Option.option


{-| A short secondary text, shown dimmed after the label in the list. It is
searched too, but a match in the description ranks below the same match in the
label.

    Select.option "de" "Germany" |> Select.withDescription "DE"

-}
withDescription : String -> Option id -> Option id
withDescription =
    Option.withDescription


{-| A short value at the end of the row, in tabular figures, for the numbers of
a data-dense list: a stock count, a code, a price. It is searched like the
description.

    Select.option sku.id sku.name |> Select.withMeta (String.fromInt sku.stock ++ " in stock")

-}
withMeta : String -> Option id -> Option id
withMeta =
    Option.withMeta


{-| Lists the option under a heading with this name. Options with the same group
are shown together, groups in the order they first appear, and options without a
group come first. Headings are not options: the keyboard skips them.
-}
withGroup : String -> Option id -> Option id
withGroup =
    Option.withGroup


{-| An icon drawn before the label in the list. When the option is chosen, the
closed field shows it next to the label.
-}
withIcon : Icon -> Option id -> Option id
withIcon =
    Option.withIcon


{-| A dot in a status color before the label, in the list and in the closed field:
`Success` green, `Warning` amber, `Danger` red. It follows the theme. The label must
say the same, because a color alone is not read by everyone.

    Select.option "late" "Delayed" |> Select.withTone Danger

-}
withTone : Tone -> Option id -> Option id
withTone =
    Option.withTone


{-| A dot in a color from your data before the label, in the list and in the closed
field. For options that come from a database, build each option from its row and
give it the color of the row (see [Klar.Color](Klar-Color)):

    Select.option row.id row.name
        |> Select.withColor color

-}
withColor : Color -> Option id -> Option id
withColor =
    Option.withColor


{-| Extra words that also match the option: synonyms, codes, old names. They are
searched but never shown.

    Select.option "us" "United States" |> Select.withKeywords [ "USA", "America" ]

-}
withKeywords : List String -> Option id -> Option id
withKeywords =
    Option.withKeywords


{-| Shows the option dimmed in the list and keeps it from being chosen: it cannot
be clicked or highlighted, and the arrow keys skip it. It is still searched.
-}
disabledOption : Option id -> Option id
disabledOption =
    Option.disabledOption


{-| Gives the option another kind of value and keeps the label, description,
group, icon, keywords and disabled flag. Handy to turn options over your own id
type into options over a text key, or the other way round.

    Select.option (CustomerId 7) "Contoso Ltd"
        |> Select.mapOption (\(CustomerId n) -> String.fromInt n)

-}
mapOption : (a -> b) -> Option a -> Option b
mapOption =
    Option.mapOption


{-| The options matching a query, best first, exactly as the select filters
them. Handy for a simulated backend or for showing a count elsewhere.

    Select.filter "ger" countries |> List.map .label

-}
filter : String -> List (Option id) -> List (Option id)
filter =
    Match.filter



-- STATE


{-| Everything one select keeps track of: the chosen value, the search text,
whether the list is open and which row is highlighted. Make it with `init`, keep
it in your model and pass it to `view` and `update`.
-}
type State id
    = State
        { id : String
        , open : Bool
        , query : String
        , searched : String
        , wait : Int
        , highlighted : Maybe Int
        , value : Maybe id
        , picked : Maybe (Option id)
        , list : VirtualList.State
        , cache : Maybe (Popup.Cache id)
        , fromCode : Bool
        }


{-| A closed select without a value. The `String` is the DOM id of the field and
must be unique on the page: the label points to it, and the ids of the open list
are derived from it (`country-search`, `country-listbox`, `country-popup`).

    Select.init "country"

-}
init : String -> State id
init id =
    State
        { id = id
        , open = False
        , query = ""
        , searched = ""
        , wait = 0
        , highlighted = Nothing
        , value = Nothing
        , picked = Nothing
        , list = VirtualList.init (listboxId id)
        , cache = Nothing
        , fromCode = False
        }


{-| The chosen value: the `value` of the chosen option, or `Nothing` when
nothing is chosen. A value set with `setValue` is returned at once, also while
the options are still loading.
-}
value : State id -> Maybe id
value (State state) =
    state.value


{-| Sets the value from your code, for example to show a saved record:
`Just` chooses it, `Nothing` empties the field (as `clear` does), so a `Maybe`
from your model goes in as it is. The label is looked up in the options when the
select is shown; use `setOption` when the option may not be among them (server
search).

While the options are still loading (`Loading` or `NotAsked`) and the label is
not known, the field shows a muted "Loading ..." instead of the value, and "Could
not be loaded" when they failed: a value is usually an id, and an id is not
something to read out in a form. Once the options have loaded without it, or
with `serverSearch`, the field shows the text `valueText` makes of the value, or
"Unknown value" without `valueText`. `value` returns the value all the time.

    Select.setValue (Just "de") model.country

    Select.setValue order.warehouse model.warehouse

-}
setValue : Maybe id -> State id -> State id
setValue newValue (State state) =
    case newValue of
        Just given ->
            State
                { state
                    | value = Just given
                    , picked =
                        case state.picked of
                            Just opt ->
                                if opt.value == given then
                                    Just opt

                                else
                                    Nothing

                            Nothing ->
                                Nothing
                }

        Nothing ->
            clear (State state)


{-| Chooses an option and stores it, so the field shows its label even when the
current options do not contain it. Use it for a saved value with a server
search, where the options are only the latest hits.

    Select.setOption (Select.option "c-42" "Contoso Ltd") model.customer

-}
setOption : Option id -> State id -> State id
setOption opt (State state) =
    State { state | value = Just opt.value, picked = Just opt }


{-| Removes the chosen value, so `value` is `Nothing` again.
-}
clear : State id -> State id
clear (State state) =
    State { state | value = Nothing, picked = Nothing }


{-| The text in the search box while the list is open, and `""` when it is
closed. With `serverSearch`, fetch when it changes: it then follows the box after a
pause of 300 ms in the typing, so it does not change on every key.
-}
query : State id -> String
query (State state) =
    state.searched


{-| Whether the list is open.
-}
isOpen : State id -> Bool
isOpen (State state) =
    state.open


{-| Opens the list with an empty search and moves focus into its search box,
for example from a button of your own. When focus arrives, the list is the same as
after a click on the field: the chosen option is highlighted and in the middle of
the list. Map the command like the one from `update`.

    OpenCountry ->
        let
            ( country, cmd ) =
                Select.open model.country
        in
        ( { model | country = country }, Cmd.map CountryMsg cmd )

-}
open : State id -> ( State id, Cmd (Msg id) )
open (State state) =
    ( State { state | open = True, query = "", searched = "", highlighted = Nothing, list = VirtualList.reset state.list, fromCode = True }
    , Internal.focus (searchId state.id) NoOp
    )


{-| Closes the list, forgets the search text, and gives focus back to the field
if the list was open. Map the command like the one from `update`.
-}
close : State id -> ( State id, Cmd (Msg id) )
close (State state) =
    ( State { state | open = False, query = "", searched = "", highlighted = Nothing }
    , if state.open then
        Internal.focus state.id NoOp

      else
        Cmd.none
    )


listboxId : String -> String
listboxId id =
    id ++ "-listbox"


searchId : String -> String
searchId id =
    id ++ "-search"


popupId : String -> String
popupId id =
    id ++ "-popup"



-- UPDATE


{-| The messages a select sends. Wrap it in a constructor of your own message
type (`CountryMsg Select.Msg`), give that constructor to `view`, and pass the
messages you get back to `update`.
-}
type Msg id
    = Open (Popup.Env id) Int String
    | Close
    | Dismiss
    | QueryChanged (Popup.Env id) String
    | Backspace (Popup.Env id)
    | Key (Popup.Env id) Int Popup.Move
    | Hover Int
    | Navigate VirtualList.Geometry Int
    | Pick (Option id)
    | Create (Option id)
    | Clear
    | FocusSearch
    | SearchFocused (Popup.Env id) Int
    | ListMsg VirtualList.Msg
    | Settle Int
    | NoOp


{-| Handles a message of the select and returns the new state with a command
(moving focus, scrolling the list). Map the command into your own message type
with `Cmd.map`.

    CountryMsg inner ->
        let
            ( country, cmd ) =
                Select.update inner model.country
        in
        ( { model | country = country }, Cmd.map CountryMsg cmd )

-}
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
update msg ((State state) as current) =
    case msg of
        Open env rowsVisible text ->
            if state.open then
                -- letters typed on the field before focus reached the search box
                if text == "" then
                    ( current, Cmd.none )

                else
                    update (QueryChanged env (state.query ++ text)) current

            else
                openWith env rowsVisible text current

        Backspace env ->
            -- Backspace on the field before focus reached the search box
            if state.open then
                update (QueryChanged env (String.dropRight 1 state.query)) current

            else
                ( current, Cmd.none )

        Key env rowsVisible move ->
            -- a navigation key before focus reached the search box: worked out
            -- here, from the rows as they are now
            if state.open then
                let
                    rows =
                        Popup.cachedRows state.cache env state.query
                in
                case Popup.act rowsVisible rows state.highlighted move of
                    Just (Popup.Highlight index) ->
                        update (Navigate (Popup.geometry rowsVisible rows) index) current

                    Just (Popup.Choose (Popup.Item _ opt)) ->
                        if opt.disabled then
                            ( current, Cmd.none )

                        else
                            choose opt current

                    Just (Popup.Choose (Popup.Create _ _)) ->
                        -- The text was typed in the same moment, before focus
                        -- reached the search box. A message holds no function, so
                        -- the value cannot be made here: the create row is
                        -- highlighted, and Enter in the search box creates it.
                        case Popup.resolve state.highlighted rows of
                            Just index ->
                                update (Navigate (Popup.geometry rowsVisible rows) index) current

                            Nothing ->
                                ( current, Cmd.none )

                    _ ->
                        ( current, Cmd.none )

            else
                ( current, Cmd.none )

        Close ->
            close current

        Dismiss ->
            ( State { state | open = False, query = "", searched = "", highlighted = Nothing }, Cmd.none )

        QueryChanged env text ->
            let
                ( list, scroll ) =
                    VirtualList.scrollTo 0 state.list
            in
            State
                { state
                    | query = text
                    , highlighted = Nothing
                    , list = list
                    , cache = Just (Popup.refresh state.cache env text)
                }
                |> settle env
                |> Tuple.mapSecond (\wait -> Cmd.batch [ Cmd.map ListMsg scroll, wait ])

        Hover index ->
            ( State { state | highlighted = Just index }, Cmd.none )

        Navigate geometry index ->
            let
                ( list, scroll ) =
                    VirtualList.ensureVisible geometry index state.list
            in
            ( State { state | highlighted = Just index, list = list }, Cmd.map ListMsg scroll )

        Pick opt ->
            choose opt current

        Create opt ->
            choose opt current

        Clear ->
            ( State { state | value = Nothing, picked = Nothing }, Internal.focus state.id NoOp )

        SearchFocused env rowsVisible ->
            -- A list opened from code (`open`) has not seen the options. Now
            -- that focus reached its search box, it does what a click on the
            -- field does: the rows are kept, and the chosen option is
            -- highlighted and in the middle of the list.
            if state.open && state.fromCode && state.query == "" && state.highlighted == Nothing then
                openWith env rowsVisible "" (State { state | open = False, fromCode = False })

            else
                ( State { state | fromCode = False }, Cmd.none )

        FocusSearch ->
            ( current, Internal.focus (searchId state.id) NoOp )

        ListMsg inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner state.list
            in
            ( State { state | list = list }, Cmd.map ListMsg cmd )

        Settle ticket ->
            if ticket == state.wait then
                ( State { state | searched = state.query }, Cmd.none )

            else
                ( current, Cmd.none )

        NoOp ->
            ( current, Cmd.none )


{-| How long the search text of a `serverSearch` select must stay still before `query`
reports it, in milliseconds.
-}
searchWait : Float
searchWait =
    300


{-| A list that filters itself reports the search text at once; for `serverSearch`,
where the application asks the server each time `query` changes, the text waits for a
pause in the typing (`searchWait`), and an empty text is reported at once.
-}
settle : Popup.Env id -> State id -> ( State id, Cmd (Msg id) )
settle env (State state) =
    if env.filterLocally || state.query == "" then
        ( State { state | searched = state.query }, Cmd.none )

    else
        ( State { state | wait = state.wait + 1 }
        , Process.sleep searchWait |> Task.perform (\_ -> Settle (state.wait + 1))
        )


{-| The message for choosing the "Create" row: the typed text as the label, and
the value the `creatable` function makes of it.
-}
createMsg : Config id msg -> String -> Msg id
createMsg config text =
    case config.creatable of
        Just make ->
            Create (Option.option (make text) text)

        Nothing ->
            NoOp


openWith : Popup.Env id -> Int -> String -> State id -> ( State id, Cmd (Msg id) )
openWith env rowsVisible text (State state) =
    let
        cache =
            Popup.refresh state.cache env text

        selectedIndex =
            if text == "" then
                state.value |> Maybe.andThen (\v -> Popup.indexOfValue v cache.rows)

            else
                Nothing

        ( list, scroll ) =
            case selectedIndex of
                Just index ->
                    VirtualList.center (Popup.geometry rowsVisible cache.rows) index (VirtualList.reset state.list)

                Nothing ->
                    ( VirtualList.reset state.list, Cmd.none )
    in
    State
        { state
            | open = True
            , query = text
            , highlighted = selectedIndex
            , list = list
            , cache = Just cache
        }
        |> settle env
        |> Tuple.mapSecond (\wait -> Cmd.batch [ Internal.focus (searchId state.id) NoOp, Cmd.map ListMsg scroll, wait ])


choose : Option id -> State id -> ( State id, Cmd (Msg id) )
choose opt (State state) =
    ( State
        { state
            | value = Just opt.value
            , picked = Just opt
            , open = False
            , query = ""
            , searched = ""
            , highlighted = Nothing
        }
    , Internal.focus state.id NoOp
    )



-- ATTRIBUTES


{-| A setting of a select. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { field : Field.Config
    , options : Remote (List (Option id))
    , freshness : Freshness
    , serverSearch : Bool
    , placeholder : Maybe String
    , searchPlaceholder : Maybe String
    , clearable : Bool
    , creatable : Maybe (String -> id)
    , valueText : Maybe (id -> String)
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , visibleRows : Int
    , locale : Locale
    , settings : Settings
    , onRetry : Maybe msg
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , options = Loaded []
        , freshness = Freshness.Fresh
        , serverSearch = False
        , placeholder = Nothing
        , searchPlaceholder = Nothing
        , clearable = False
        , creatable = Nothing
        , valueText = Nothing
        , disabled = False
        , readOnly = False
        , size = Medium
        , visibleRows = 8
        , locale = Locale.default
        , settings = Settings.default
        , onRetry = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute id msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| Local options. The select filters and ranks them itself as the user types.
The default is no options. Use `options` or `remote`, not both: the later one
wins.

    Select.options [ Select.option "de" "Germany", Select.option "fr" "France" ]

-}
options : List (Option id) -> Attribute id msg
options list =
    Attribute (\config -> { config | options = Loaded list, freshness = Freshness.Fresh })


{-| Options from the backend, as a `Remote` (see [Klar.Remote](Klar-Remote)).
The list shows loading rows while the data is `Loading` or `NotAsked`, a compact
error with a retry button on `Failed` (see `onRetry`), the empty state on
`Loaded []`, and the options on `Loaded`. Options that are `Kept` stay in the
list: dimmed and busy while they are refreshed, and with "Old data from 14:05"
and a retry (`onRetry`) at the top of the list when the last refresh failed.

    Select.remote model.countries

-}
remote : Remote (List (Option id)) -> Attribute id msg
remote data =
    let
        ( current, freshness ) =
            Freshness.settle data
    in
    Attribute (\config -> { config | options = current, freshness = freshness })


{-| The server does the searching. The select shows the options exactly as they
come and does not filter them; the application fetches when `Select.query`
changes. `query` waits for a pause of 300 ms in the typing (an empty text comes at
once), so **write no debounce of your own**. Answers can still come back out of order:
send the query with the request and drop an answer whose query is no longer
`Select.query model.country`. While the options are `NotAsked` (nothing fetched yet, or
a text too short to search for) the list says "Type to search".

    -- in update
    CountryMsg inner ->
        let
            ( country, cmd ) =
                Select.update inner model.country
        in
        if Select.query country /= Select.query model.country then
            ( { model | country = country, countries = Remote.refresh model.countries }
            , Cmd.batch [ Cmd.map CountryMsg cmd, fetchCountries (Select.query country) ]
            )

        else
            ( { model | country = country }, Cmd.map CountryMsg cmd )

    -- in view
    Select.view CountryMsg [ Select.serverSearch, Select.remote model.countries ] model.country

`Remote.refresh` keeps the hits of the last search on screen, dimmed and busy,
until the new ones arrive (the first search shows loading rows), so the list does
not flash empty on every pause in the typing.

-}
serverSearch : Attribute id msg
serverSearch =
    Attribute (\config -> { config | serverSearch = True })


{-| The message to send when the user presses the "Try again" button of the error
shown when `remote` options failed. The button appears only for problems that are
worth retrying (network trouble, timeouts, server errors); while it is shown,
Enter in the search box sends the message as well. For other problems (no
access, not found ...) nothing is retried, and Enter does nothing.

    Select.onRetry ReloadCountries

-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The label above the field. It names the select for screen readers.
-}
label : String -> Attribute id msg
label text =
    updateField (Field.setLabel text)


{-| Keeps the label for screen readers but does not draw it. Use it when the
surroundings already name the field, as in a toolbar or a table cell. It needs a
`label`.
-}
labelHidden : Attribute id msg
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text under the field. Screen readers read it with the field
(`aria-describedby`).
-}
hint : String -> Attribute id msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.
-}
error : String -> Attribute id msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

    Select.errorMaybe model.countryError

-}
errorMaybe : Maybe String -> Attribute id msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` for screen readers. It does not validate anything; show a
problem with `error`.
-}
required : Attribute id msg
required =
    updateField (Field.setRequired True)


{-| A text after the label of a field that is not `required`, such as
"(optional)". Required fields show no such text.
-}
optionalText : String -> Attribute id msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The text shown while nothing is chosen. Default "Select ..." (in the
language of `locale`).
-}
placeholder : String -> Attribute id msg
placeholder text =
    Attribute (\config -> { config | placeholder = Just text })


{-| The placeholder of the search box in the open list. Default "Search ..."
(in the language of `locale`).
-}
searchPlaceholder : String -> Attribute id msg
searchPlaceholder text =
    Attribute (\config -> { config | searchPlaceholder = Just text })


{-| Shows a small × in the field that removes the chosen value. Backspace and
Delete do the same on the focused field. Nothing is shown while no value is
chosen.
-}
clearable : Attribute id msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| Offers a first row `Create “Acme Ltd”` (for a search text "Acme Ltd") when
the search text matches no option exactly, ignoring case and diacritics.
Choosing it makes the typed text the label, and the value is what the function
you give makes of the text: the text itself for a select of `String`s, or a
value of your own type (a draft id, a new entity). Add it to your options if it
should stay in the list.

    Select.creatable identity -- the typed text is the value

-}
creatable : (String -> id) -> Attribute id msg
creatable make =
    Attribute (\config -> { config | creatable = Just make })


{-| How to write a value that is in none of the options, for example a saved
value with a server search whose hits do not contain it. Without it the field
says "Unknown value". The text of an option you know about is always its label;
use `setOption` to give the select that option.

    Select.valueText CustomerId.toString

-}
valueText : (id -> String) -> Attribute id msg
valueText toText =
    Attribute (\config -> { config | valueText = Just toText })


{-| While `True` the select is dimmed, cannot be focused or opened, and has no
clear button. The value is kept. Pass a field of your model, for example while a
form is saving. The default is `False`.
-}
disabled : Bool -> Attribute id msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the select shows its value but does not let the user change it:
the list does not open, and there is no chevron or clear button. Unlike
`disabled`, a read-only field can be focused. The default is `False`.
-}
readOnly : Bool -> Attribute id msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar-Theme). The default is `Medium`.
-}
size : Size -> Attribute id msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| How many rows the open list shows before it scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.
-}
visibleRows : Int -> Attribute id msg
visibleRows n =
    Attribute (\config -> { config | visibleRows = clamp 3 20 n })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Select.settings model.settings

-}
settings : Settings -> Attribute id msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text: the placeholders, the search box, the
counts under the list, the empty and error states and the labels for screen
readers. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar-Locale).

    Select.locale Locale.nb

-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| The select. It takes the constructor that wraps the component's `Msg` in
your own message type, a list of attributes, and the state.

    Select.view CountryMsg
        [ Select.label "Country"
        , Select.options countryOptions
        , Select.required
        ]
        model.country

Always give the select a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

-}
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
view toMsg attributes ((State state) as current) =
    let
        config =
            configure attributes

        field =
            Field.setId state.id config.field

        t =
            Popup.texts config.locale

        env =
            { options = Remote.withDefault [] config.options
            , filterLocally = not config.serverSearch
            , creatable = config.creatable /= Nothing
            }

        interactive =
            not config.disabled && not config.readOnly
    in
    -- Always wrapped: an error that appears while the list is open must not
    -- rebuild the field and take the focus out of the search box.
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-anchor"
                , "klar-anchor--block"
                , "klar-select"
                , if state.open && interactive then
                    "klar-select--open"

                  else
                    ""
                ]
            ]
            [ viewControl toMsg config field t env current
            , if state.open && interactive then
                viewPopup toMsg config t env current

              else
                Html.text ""
            ]
        )


{-| What the closed field shows for the value.
-}
type Shown id
    = Chosen (Option id)
    | NotLoadedYet
    | LoadFailed
    | UnknownValue
    | NothingChosen


{-| The option the value stands for: from the options, or stored from when it
was picked. When neither knows it, the label is not known, and the field
says so ("Loading ..." while the options load, "Could not be loaded" when they
failed) instead of showing the raw value, which is usually an id. A list that
did load, or a server search (whose options are only the latest hits), shows
the text `valueText` makes of the value, or "Unknown value".
-}
shownValue : Config id msg -> State id -> List (Option id) -> Shown id
shownValue config (State state) list =
    case state.value of
        Nothing ->
            NothingChosen

        Just v ->
            case Popup.findByValue v list of
                Just opt ->
                    Chosen opt

                Nothing ->
                    case state.picked of
                        Just opt ->
                            if opt.value == v then
                                Chosen opt

                            else
                                unknownLabel config v

                        Nothing ->
                            unknownLabel config v


unknownLabel : Config id msg -> id -> Shown id
unknownLabel config v =
    if config.serverSearch then
        unlisted config v

    else
        case config.options of
            Loaded _ ->
                unlisted config v

            Kept _ ->
                unlisted config v

            Failed _ ->
                LoadFailed

            Loading ->
                NotLoadedYet

            NotAsked ->
                NotLoadedYet


{-| A value that is in none of the options, once they are known: shown with the
text `valueText` makes of it, or as "Unknown value".
-}
unlisted : Config id msg -> id -> Shown id
unlisted config v =
    case config.valueText of
        Just toText ->
            Chosen (Option.option v (toText v))

        Nothing ->
            UnknownValue


viewControl : (Msg id -> msg) -> Config id msg -> Field.Config -> Popup.Texts -> Popup.Env id -> State id -> Html msg
viewControl toMsg config field t env ((State state) as current) =
    let
        interactive =
            not config.disabled && not config.readOnly

        selected =
            shownValue config current env.options

        openMsg =
            toMsg (Open env config.visibleRows "")

        showClear =
            config.clearable && interactive && state.value /= Nothing

        typed =
            Just (\char -> toMsg (Open env config.visibleRows char))

        triggerKeys =
            if interactive && not state.open then
                Popup.onTriggerKeys
                    ([ ( "Enter", openMsg ), ( " ", openMsg ), ( "ArrowDown", openMsg ), ( "ArrowUp", openMsg ) ]
                        ++ (if showClear then
                                [ ( "Backspace", toMsg Clear ), ( "Delete", toMsg Clear ) ]

                            else
                                []
                           )
                    )
                    typed

            else if interactive then
                -- Keys typed after the list opened but before focus reached its
                -- search box (Elm moves focus a frame later) still belong to the
                -- search: text, Backspace, arrows, Enter, Escape and Tab.
                Popup.onWindowKeys
                    { typed = \char -> toMsg (Open env config.visibleRows char)
                    , backspace = toMsg (Backspace env)
                    , move = \move -> toMsg (Key env config.visibleRows move)
                    , close = toMsg Close
                    , leave = toMsg Dismiss
                    }

            else
                Internal.noAttr
    in
    Html.div
        [ Internal.cls
            [ "klar-input"
            , "klar-input--" ++ Internal.sizeSuffix config.size
            , "klar-select__control"
            , if field.error /= Nothing then
                "klar-input--invalid"

              else
                ""
            , if config.disabled then
                "klar-input--disabled"

              else
                ""
            , if config.readOnly then
                "klar-input--readonly"

              else
                ""
            ]
        , if interactive then
            Events.onClick openMsg

          else
            Internal.noAttr
        ]
        [ Html.button
            (Field.controlAttributes field
                ++ [ Internal.cls [ "klar-select__trigger" ]
                   , Attr.type_ "button"
                   , Attr.attribute "role" "combobox"
                   , Attr.attribute "aria-haspopup" "listbox"
                   , Attr.attribute "aria-expanded"
                        (if state.open && interactive then
                            "true"

                         else
                            "false"
                        )
                   , Internal.attrIf (state.open && interactive) (Attr.attribute "aria-controls" (popupId state.id))
                   , Attr.disabled config.disabled
                   , Internal.attrIf config.readOnly (Attr.attribute "aria-readonly" "true")
                   , case selected of
                        Chosen opt ->
                            Attr.title opt.label

                        _ ->
                            Internal.noAttr
                   , triggerKeys
                   ]
            )
            (case selected of
                Chosen opt ->
                    [ Internal.markDot opt.tone opt.color
                    , Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-select__value-icon" ] ] [ Icon.view icon ]) opt.icon
                    , Html.span [ Internal.cls [ "klar-select__value" ] ] [ Html.text opt.label ]
                    ]

                NotLoadedYet ->
                    [ Html.span [ Internal.cls [ "klar-select__value", "klar-select__value--unknown" ] ] [ Html.text t.loading ] ]

                LoadFailed ->
                    [ Html.span [ Internal.cls [ "klar-select__value", "klar-select__value--unknown" ] ] [ Html.text t.unavailable ] ]

                UnknownValue ->
                    [ Html.span [ Internal.cls [ "klar-select__value", "klar-select__value--unknown" ] ] [ Html.text t.unknownValue ] ]

                NothingChosen ->
                    [ Html.span [ Internal.cls [ "klar-select__placeholder" ] ]
                        [ Html.text (Maybe.withDefault t.placeholder config.placeholder) ]
                    ]
            )
        , if showClear then
            Popup.viewClearButton t.clearSelection (toMsg Clear)

          else
            Html.text ""
        , if config.readOnly then
            Html.text ""

          else
            Popup.viewChevron
        ]


viewPopup : (Msg id -> msg) -> Config id msg -> Popup.Texts -> Popup.Env id -> State id -> Html msg
viewPopup toMsg config t env (State state) =
    let
        rows =
            Popup.cachedRows state.cache env state.query

        geometry =
            Popup.geometry config.visibleRows rows

        highlighted =
            Popup.resolve state.highlighted rows

        isLoaded =
            case config.options of
                Loaded _ ->
                    True

                Kept _ ->
                    True

                _ ->
                    False

        -- What Enter and Tab do on a failure depends on whether a "Try again"
        -- button is on screen: the problem must be worth retrying and the
        -- application must have said what retrying means.
        retry =
            case config.options of
                Failed problem ->
                    Popup.retryFor problem config.onRetry

                _ ->
                    Nothing

        navigate index =
            toMsg (Navigate geometry index)

        pickRow index =
            case Popup.rowAt index rows of
                Just (Popup.Item _ opt) ->
                    if opt.disabled then
                        toMsg NoOp

                    else
                        toMsg (Pick opt)

                Just (Popup.Create _ text) ->
                    toMsg (createMsg config text)

                _ ->
                    toMsg NoOp

        navigation =
            case ( isLoaded, highlighted ) of
                ( True, Just h ) ->
                    [ ( "ArrowDown", navigate (Popup.next rows h) )
                    , ( "ArrowUp", navigate (Popup.prev rows h) )
                    , ( "PageDown", navigate (Popup.pageDown (Popup.pageSize config.visibleRows) rows h) )
                    , ( "PageUp", navigate (Popup.pageUp (Popup.pageSize config.visibleRows) rows h) )
                    , ( "Ctrl+Home", navigate (Maybe.withDefault h (Popup.first rows)) )
                    , ( "Ctrl+End", navigate (Maybe.withDefault h (Popup.last rows)) )
                    , ( "Enter", pickRow h )
                    ]

                _ ->
                    -- Enter never submits a surrounding form; it retries only
                    -- when "Try again" is on screen
                    [ ( "Enter", Maybe.withDefault (toMsg NoOp) retry ) ]

        -- Home and End go to the first and last row while the search box is
        -- empty; with text in it they move the caret.
        ends =
            case ( isLoaded, highlighted ) of
                ( True, Just h ) ->
                    [ ( "Home", navigate (Maybe.withDefault h (Popup.first rows)) )
                    , ( "End", navigate (Maybe.withDefault h (Popup.last rows)) )
                    ]

                _ ->
                    []

        -- The "Old data" notice above the list has a "Try again" button that
        -- Tab reaches.
        staleRetry =
            if isLoaded && rows.optionRows > 0 then
                Popup.noticeRetry config.freshness config.onRetry

            else
                Nothing

        keys =
            Popup.onSearchKeys
                { handled = navigation ++ [ ( "Escape", toMsg Close ) ]
                , whenEmpty = ends
                , passive =
                    if Popup.isJust retry || Popup.isJust staleRetry then
                        -- Tab goes on to the "try again" button
                        [ ( "Shift+Tab", toMsg Dismiss ) ]

                    else
                        [ ( "Tab", toMsg Dismiss ), ( "Shift+Tab", toMsg Dismiss ) ]
                }

        rowConfig =
            { idBase = state.id
            , query = state.query
            , highlighted = highlighted
            , setSize = rows.optionRows
            , indicator = Popup.CheckMark
            , isSelected = \opt -> state.value == Just opt.value
            , isBlocked = always False
            , selectedFollowsHighlight = False
            , onPick = Pick >> toMsg
            , onCreate = createMsg config >> toMsg
            , onHover = Hover >> toMsg
            , noop = toMsg NoOp
            , texts = t
            }

        listAttributes =
            [ VirtualList.rowHeight Popup.rowHeight
            , VirtualList.height (Popup.listHeight config.visibleRows)
            , VirtualList.htmlAttrs
                [ Internal.cls [ "klar-select__list" ]
                , Attr.attribute "role" "listbox"
                , Internal.attrMaybe (Attr.attribute "aria-label") config.field.label

                -- dragging the scrollbar must not take focus from the search box
                , Internal.onMouseDownPrevent (toMsg NoOp)
                ]
            ]

        list =
            if rows.grouped then
                VirtualList.viewGrouped (ListMsg >> toMsg)
                    listAttributes
                    { items = rows.rows, viewRow = Popup.viewRow rowConfig, viewHeader = Popup.viewPinned }
                    state.list

            else
                VirtualList.view (ListMsg >> toMsg)
                    listAttributes
                    { items = rows.rows, viewRow = Popup.viewRow rowConfig }
                    state.list

        loadedBody =
            if rows.optionRows == 0 then
                if String.isEmpty (String.trim state.query) then
                    Popup.viewEmpty Icon.inbox t.noOptions Nothing

                else
                    Popup.viewEmpty Icon.search t.noMatches (Just (t.noMatchesFor (String.trim state.query)))

            else
                Html.div
                    [ Internal.cls [ Freshness.className config.freshness ], Freshness.busyAttr config.freshness ]
                    [ Popup.viewNotice
                        { locale = config.locale
                        , settings = config.settings
                        , onRetry = config.onRetry
                        , refocus = toMsg FocusSearch
                        , leave = Just (toMsg Dismiss)
                        }
                        config.freshness
                    , list
                    , Popup.viewFooter (Popup.statusText t env.filterLocally state.query rows) []
                    ]

        body =
            case config.options of
                Loaded _ ->
                    loadedBody

                Kept _ ->
                    loadedBody

                Failed problem ->
                    Popup.viewFailure
                        { locale = config.locale
                        , onRetry = retry
                        , focusable = True
                        , refocus = toMsg FocusSearch
                        , leave = toMsg Dismiss
                        , noop = toMsg NoOp
                        }
                        problem

                Loading ->
                    viewLoading t

                NotAsked ->
                    -- with serverSearch, NotAsked means no request was made
                    -- (also when the text is too short to search for)
                    if config.serverSearch then
                        Popup.viewEmpty Icon.search t.typeToSearch Nothing

                    else
                        viewLoading t
    in
    Popup.viewLayer (toMsg Close)
        (Html.div
            [ Internal.cls [ "klar-popup", "klar-select__popup" ]
            , Attr.id (popupId state.id)
            , Internal.onClickStop (toMsg NoOp)
            , Popup.holdSearchFocus (toMsg NoOp)
            ]
            [ Popup.viewSearch
                { id = searchId state.id
                , listboxId =
                    if isLoaded && rows.optionRows > 0 then
                        Just (listboxId state.id)

                    else
                        Nothing
                , query = state.query
                , placeholder = Maybe.withDefault t.searchPlaceholder config.searchPlaceholder
                , label = t.searchLabel
                , activeDescendant =
                    if isLoaded then
                        Popup.activeDescendant state.id geometry state.list highlighted

                    else
                        Nothing
                , onInput = QueryChanged env >> toMsg
                , onFocus = toMsg (SearchFocused env config.visibleRows)
                , keys = keys
                , loading = Remote.isLoading config.options
                , loadingLabel = t.loading
                , clearLabel = t.clearQuery
                , noop = toMsg NoOp
                }
            , body
            ]
        )


viewLoading : Popup.Texts -> Html msg
viewLoading t =
    Html.div [ Attr.attribute "aria-busy" "true" ]
        [ Popup.viewSkeleton 5
        , Popup.viewFooter t.loading []
        ]
