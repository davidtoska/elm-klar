module Klar.MultiSelect exposing
    ( State, init, Msg, update, view
    , values, setValues, setOptions, clear, query, isOpen, open, close
    , Attribute, options, remote, serverSearch, onRetry
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, searchPlaceholder, clearable, creatable, valueText, disabled, readOnly, size, visibleRows, locale, settings
    , maxSelected, maxVisibleChips
    )

{-| Choose several values from a searchable list. The chosen values are shown as
chips in the field; the list has a checkbox per option and stays open while the
user picks. Use [Klar.Select](Klar-Select) when exactly one value is wanted.

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
states with [Klar.Select](Klar-Select): options are `Select.Option` values, made
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
announced politely, and so is a value removed from the closed field with the ×
of its chip, Backspace or the clear button ("Books removed"). The built-in texts
follow `locale` and are English by default (see [Klar.Locale](Klar-Locale)).


# State

@docs State, init, Msg, update, view


# Values and popup

@docs values, setValues, setOptions, clear, query, isOpen, open, close


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, options, remote, serverSearch, onRetry


# Field

The label, hint and error around the field work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs placeholder, searchPlaceholder, clearable, creatable, valueText, disabled, readOnly, size, visibleRows, locale, settings


# Limits and chips

@docs maxSelected, maxVisibleChips

-}

import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select as Select exposing (Option)
import Klar.Select.Popup as Popup
import Klar.Settings as Settings exposing (Settings)
import Klar.Tag as Tag
import Klar.Theme as Theme exposing (Size(..))
import Klar.VirtualList as VirtualList
import Process
import Task



-- STATE


{-| Everything one multi select keeps track of: the chosen values in the order
they were chosen, the search text, and whether the list is open. Make it with
`init`, keep it in your model and pass it to `view` and `update`.
-}
type State id
    = State
        { id : String
        , open : Bool
        , query : String
        , searched : String
        , wait : Int
        , highlighted : Maybe Int
        , selected : List (Selected id)
        , list : VirtualList.State
        , cache : Maybe (Popup.Cache id)
        , said : Maybe Said
        , fromCode : Bool
        }


{-| What the field last told a screen reader about a change made from the closed
field (in the open list, the status line under the list says it).
-}
type Said
    = RemovedValue (Maybe String)
    | RemovedAll


{-| A chosen value, with its option when the component has seen it (so the
chip keeps its label even when a server search no longer returns it).
-}
type alias Selected id =
    { value : id
    , option : Maybe (Option id)
    }


{-| A closed multi select with nothing chosen. The `String` is the DOM id of the
field and must be unique on the page: the label points to it, and the ids of the
open list are derived from it (`categories-search`, `categories-listbox`,
`categories-popup`).

    MultiSelect.init "categories"

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
        , selected = []
        , list = VirtualList.init (listboxId id)
        , cache = Nothing
        , said = Nothing
        , fromCode = False
        }


{-| The chosen values, in the order they were chosen: the `value` of every
chosen option. The list is empty when nothing is chosen. Values set with
`setValues` are returned at once, also while the options are still loading.
-}
values : State id -> List id
values (State state) =
    List.map .value state.selected


{-| Replaces the chosen values from your code, for example to show a saved
record. Duplicates are dropped (in a list of up to 2000 values; a longer list is
taken as it is, so give unique values). The labels are looked up in the options
when the field is shown; use `setOptions` when the options may not contain them
(server search). A value that the loaded options do not contain is a chip with the
text `valueText` makes of it, or "Unknown value" without `valueText`. The
`maxSelected` limit is not applied to values set this way.

    MultiSelect.setValues [ "books", "games" ] model.categories

-}
setValues : List id -> State id -> State id
setValues newValues (State state) =
    let
        known v =
            state.selected |> List.filter (\sel -> sel.value == v) |> List.head

        unique =
            dedupe newValues
    in
    State
        { state
            | selected = List.map (\v -> known v |> Maybe.withDefault { value = v, option = Nothing }) unique
        }


{-| Replaces the chosen values with these options and stores them, so the chips
show their labels even when the current options do not contain them. Use it for
saved values with a server search, where the options are only the latest hits.

    MultiSelect.setOptions [ Select.option "c-42" "Contoso Ltd" ] model.customers

-}
setOptions : List (Option id) -> State id -> State id
setOptions opts (State state) =
    let
        unique =
            dedupeBy .value opts
    in
    State
        { state
            | selected = List.map (\opt -> { value = opt.value, option = Just opt }) unique
        }


{-| Removes all chosen values, so `values` is empty again.
-}
clear : State id -> State id
clear (State state) =
    State { state | selected = [] }


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
for example from a button of your own. Map the command like the one from
`update`.

    OpenCategories ->
        let
            ( categories, cmd ) =
                MultiSelect.open model.categories
        in
        ( { model | categories = categories }, Cmd.map CategoriesMsg cmd )

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


dedupe : List id -> List id
dedupe list =
    dedupeBy identity list


{-| Drops the later items with the same key. Values are compared with `==`, so
this takes time in proportion to the square of the length: a list longer than
`dedupeLimit` is taken to hold unique values already, as the options of one list
must.
-}
dedupeBy : (a -> id) -> List a -> List a
dedupeBy key list =
    if List.length list > dedupeLimit then
        list

    else
        List.foldl
            (\item ( seen, kept ) ->
                if List.member (key item) seen then
                    ( seen, kept )

                else
                    ( key item :: seen, item :: kept )
            )
            ( [], [] )
            list
            |> Tuple.second
            |> List.reverse


dedupeLimit : Int
dedupeLimit =
    2000


{-| Whether a value is among the chosen ones.
-}
isChosen : id -> List (Selected id) -> Bool
isChosen v selected =
    List.any (\sel -> sel.value == v) selected


{-| Whether "Select all" has anything to add: a matching option that can be
chosen and is not chosen yet. Values are compared with `==`, so the exact answer
compares every match with every chosen value, and this runs on every render
(every hover and scroll). So it compares only when it must and when that is
cheap: while fewer values are chosen than there are matches to choose, some match
is not chosen; and when the comparison would be large the button stays available
(the click works the rest out once, in `update`).
-}
anyLeftToChoose : List (Option id) -> List (Selected id) -> Bool
anyLeftToChoose matched selected =
    let
        selectable =
            List.filter (\opt -> not opt.disabled) matched

        selectableCount =
            List.length selectable

        chosenCount =
            List.length selected
    in
    if selectableCount == 0 then
        False

    else if chosenCount < selectableCount || selectableCount * chosenCount > comparisonBudget then
        True

    else
        List.any (\opt -> not (isChosen opt.value selected)) selectable


{-| The most `==` comparisons a render may spend on the state of "Select all".
-}
comparisonBudget : Int
comparisonBudget =
    200000



-- UPDATE


{-| The messages a multi select sends. Wrap it in a constructor of your own
message type (`CategoriesMsg MultiSelect.Msg`), give that constructor to `view`,
and pass the messages you get back to `update`.
-}
type Msg id
    = Open (Popup.Env id) String
    | Close
    | Dismiss
    | QueryChanged (Popup.Env id) String
    | Backspace (Popup.Env id)
    | Key (Popup.Env id) Int (Maybe Int) Popup.Move
    | Hover Int
    | Navigate VirtualList.Geometry Int
    | Toggle (Option id)
    | CreateValue (Option id)
    | Remove (Option id)
    | RemoveLast
    | SelectAllMatched (Popup.Env id) (Maybe Int)
    | ClearAll
    | FocusSearch
    | SearchFocused (Popup.Env id)
    | ListMsg VirtualList.Msg
    | Settle Int
    | NoOp


{-| Handles a message of the multi select and returns the new state with a
command (moving focus, scrolling the list). Map the command into your own
message type with `Cmd.map`.

    CategoriesMsg inner ->
        let
            ( categories, cmd ) =
                MultiSelect.update inner model.categories
        in
        ( { model | categories = categories }, Cmd.map CategoriesMsg cmd )

-}
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
update msg ((State state) as current) =
    case msg of
        Open env text ->
            if state.open then
                -- letters typed on the field before focus reached the search box
                if text == "" then
                    ( current, Cmd.none )

                else
                    update (QueryChanged env (state.query ++ text)) current

            else
                State
                    { state
                        | open = True
                        , query = text
                        , highlighted = Nothing
                        , list = VirtualList.reset state.list
                        , cache = Just (Popup.refresh state.cache env text)
                        , said = Nothing
                    }
                    |> settle env
                    |> Tuple.mapSecond (\wait -> Cmd.batch [ Internal.focus (searchId state.id) NoOp, wait ])

        Backspace env ->
            -- Backspace on the field before focus reached the search box: it
            -- edits the search, or removes the last chip when the search is empty
            if not state.open then
                ( current, Cmd.none )

            else if state.query == "" then
                update RemoveLast current

            else
                update (QueryChanged env (String.dropRight 1 state.query)) current

        Key env rowsVisible limit move ->
            -- a navigation key before focus reached the search box: worked out
            -- here, from the rows as they are now
            if state.open then
                let
                    rows =
                        Popup.cachedRows state.cache env state.query

                    atMax =
                        case limit of
                            Just n ->
                                List.length state.selected >= n

                            Nothing ->
                                False
                in
                case Popup.act rowsVisible rows state.highlighted move of
                    Just (Popup.Highlight index) ->
                        update (Navigate (Popup.geometry rowsVisible rows) index) current

                    Just (Popup.Choose (Popup.Item _ opt)) ->
                        if opt.disabled || (atMax && not (isChosen opt.value state.selected)) then
                            ( current, Cmd.none )

                        else
                            update (Toggle opt) current

                    Just (Popup.Choose (Popup.Create _ _)) ->
                        -- The text was typed in the same moment, before focus
                        -- reached the search box. A message holds no function, so
                        -- the value cannot be made here: the create row is
                        -- highlighted, and Enter in the search box creates it.
                        case Popup.resolve state.highlighted rows of
                            Just index ->
                                if atMax then
                                    ( current, Cmd.none )

                                else
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

        Toggle opt ->
            if isChosen opt.value state.selected then
                ( remove opt.value current, Cmd.none )

            else
                ( add [ opt ] current, Cmd.none )

        CreateValue opt ->
            ( add [ opt ] current, Cmd.none )

        Remove opt ->
            ( remove opt.value current |> say (RemovedValue (Just opt.label))
            , if state.open then
                Cmd.none

              else
                Internal.focus state.id NoOp
            )

        RemoveLast ->
            case List.reverse state.selected of
                lastOne :: _ ->
                    ( remove lastOne.value current |> say (RemovedValue (Maybe.map .label lastOne.option)), Cmd.none )

                [] ->
                    ( current, Cmd.none )

        SelectAllMatched env limit ->
            -- worked out here, once per click, not on every render: it compares
            -- every matching option with every chosen value
            let
                rows =
                    Popup.cachedRows state.cache env state.query

                fresh =
                    rows.matched
                        |> List.filter (\opt -> not opt.disabled && not (isChosen opt.value state.selected))
                        |> (case limit of
                                Just n ->
                                    List.take (max 0 (n - List.length state.selected))

                                Nothing ->
                                    identity
                           )
            in
            ( append fresh current, Internal.focus (searchId state.id) NoOp )

        ClearAll ->
            ( clear current |> say RemovedAll
            , if state.open then
                Internal.focus (searchId state.id) NoOp

              else
                Internal.focus state.id NoOp
            )

        SearchFocused env ->
            -- A list opened from code (`open`) has not seen the options: keep
            -- its rows now, as a click on the field does.
            if state.open && state.fromCode then
                ( State { state | fromCode = False, cache = Just (Popup.refresh state.cache env state.query) }, Cmd.none )

            else
                ( current, Cmd.none )

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


{-| A list that filters itself reports the search text at once; for `serverSearch` the
text waits for a pause of 300 ms in the typing, and an empty text is reported at once
(as in `Klar.Select`).
-}
settle : Popup.Env id -> State id -> ( State id, Cmd (Msg id) )
settle env (State state) =
    if env.filterLocally || state.query == "" then
        ( State { state | searched = state.query }, Cmd.none )

    else
        ( State { state | wait = state.wait + 1 }
        , Process.sleep 300 |> Task.perform (\_ -> Settle (state.wait + 1))
        )


add : List (Option id) -> State id -> State id
add opts ((State state) as current) =
    append (List.filter (\opt -> not (isChosen opt.value state.selected)) opts) current


{-| Adds options that are not chosen yet, in their order.
-}
append : List (Option id) -> State id -> State id
append fresh (State state) =
    State
        { state
            | selected = state.selected ++ List.map (\opt -> { value = opt.value, option = Just opt }) (dedupeBy .value fresh)
        }


{-| Tells a screen reader about a change made from the closed field. The open list
has its own status line, which says it already.
-}
say : Said -> State id -> State id
say said (State state) =
    if state.open then
        State { state | said = Nothing }

    else
        State { state | said = Just said }


remove : id -> State id -> State id
remove v (State state) =
    State
        { state
            | selected = List.filter (\sel -> sel.value /= v) state.selected
        }



-- ATTRIBUTES


{-| A setting of a multi select. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
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
    , maxSelected : Maybe Int
    , maxVisibleChips : Maybe Int
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
        , maxSelected = Nothing
        , maxVisibleChips = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute id msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| Local options. The component filters and ranks them itself as the user
types. The default is no options. Use `options` or `remote`, not both: the later
one wins.

    MultiSelect.options [ Select.option "books" "Books", Select.option "toys" "Toys" ]

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

    MultiSelect.remote model.categories

-}
remote : Remote (List (Option id)) -> Attribute id msg
remote data =
    let
        ( current, freshness ) =
            Freshness.settle data
    in
    Attribute (\config -> { config | options = current, freshness = freshness })


{-| The server does the searching. The component shows the options exactly as
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

-}
serverSearch : Attribute id msg
serverSearch =
    Attribute (\config -> { config | serverSearch = True })


{-| The message to send when the user presses the "Try again" button of the error
shown when `remote` options failed. The button appears only for problems that are
worth retrying (network trouble, timeouts, server errors); while it is shown,
Enter in the search box sends the message as well. For other problems (no
access, not found ...) nothing is retried, and Enter does nothing.

    MultiSelect.onRetry ReloadCategories

-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The label above the field. It names the multi select for screen readers.
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

    MultiSelect.errorMaybe model.categoriesError

-}
errorMaybe : Maybe String -> Attribute id msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` for screen readers. It does not validate anything; show a
problem with `error`, for example when `values` is empty.
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


{-| Shows a small × in the field that removes all chosen values. Nothing is
shown while no value is chosen.
-}
clearable : Attribute id msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| Offers a first row `Create “Acme Ltd”` (for a search text "Acme Ltd") when
the search text matches no option exactly, ignoring case and diacritics.
Choosing it adds a new value and keeps the list open: the typed text is the
label, and the value is what the function you give makes of the text (the text
itself for a select of `String`s, or a value of your own type). Add it to your
options if it should stay in the list.

    MultiSelect.creatable identity

-}
creatable : (String -> id) -> Attribute id msg
creatable make =
    Attribute (\config -> { config | creatable = Just make })


{-| While `True` the field is dimmed, cannot be focused or opened, and its chips
have no remove buttons. The values are kept. Pass a field of your model, for
example while a form is saving. The default is `False`.
-}
disabled : Bool -> Attribute id msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| How to write a value that is in none of the options, for example a saved
value with a server search whose hits do not contain it. Without it the chip says
"Unknown value". The label of an option you know about is always its own; use
`setOptions` to give the select those options.

    MultiSelect.valueText CustomerId.toString

-}
valueText : (id -> String) -> Attribute id msg
valueText toText =
    Attribute (\config -> { config | valueText = Just toText })


{-| While `True` the field shows its chips but does not let the user change
them: the list does not open, and there is no chevron, clear button or remove
button. Unlike `disabled`, a read-only field can be focused. The default is
`False`.
-}
readOnly : Bool -> Attribute id msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar-Theme). The default is `Medium`. The chips are small in a
`Small` field and medium otherwise.
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

    MultiSelect.settings model.settings

-}
settings : Settings -> Attribute id msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text: the placeholders, the search box, the
chip and button labels, the counts under the list, the empty and error states
and the labels for screen readers. The default is `Locale.default`, which is
English. See [Klar.Locale](Klar-Locale).

    MultiSelect.locale Locale.nb

-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })


{-| The most values the user can choose, at least 1. By default there is no
limit. When the limit is reached the options that are not chosen are dimmed and
cannot be chosen, "Select all" adds only as many values as are left, and the
status line reads "3 of max 3 selected". The limit is not applied to
`setValues` and `setOptions`.

    MultiSelect.maxSelected 3

-}
maxSelected : Int -> Attribute id msg
maxSelected n =
    Attribute (\config -> { config | maxSelected = Just (max 1 n) })


{-| Shows at most this many chips and a "+N" chip for the rest. The default is
5, so that the field does not grow with the selection: "Select all" on a long
list would otherwise fill the page. The chips wrap onto as many lines as they
need, so a higher number makes a taller field; 200 is the most. The "+N" chip
names the hidden values in its tooltip, and the list shows every chosen value
ticked.
-}
maxVisibleChips : Int -> Attribute id msg
maxVisibleChips n =
    Attribute (\config -> { config | maxVisibleChips = Just (max 0 n) })



-- VIEW


{-| The multi select. It takes the constructor that wraps the component's `Msg`
in your own message type, a list of attributes, and the state.

    MultiSelect.view CategoriesMsg
        [ MultiSelect.label "Product categories"
        , MultiSelect.options categoryOptions
        , MultiSelect.maxSelected 5
        ]
        model.categories

Always give the field a `label`; `labelHidden` keeps it off the screen but
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
                , "klar-select--multi"
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


{-| A chosen value as the field shows it: with its label, or (when the options
that would tell the label have not arrived, or failed) as a muted placeholder
chip. A raw value is usually an id and is never shown in its place.
-}
type Chip id
    = Labelled (Option id)
    | Unresolved Bool
    | Unlisted


{-| The chosen values with labels, looked up in the current options for values
the component has not seen as options. `Unresolved True` is a value whose
options are still loading, `Unresolved False` one whose options failed. A list
that did load, and a server search (its options are only the latest hits), show
the text `valueText` makes of the value, or "Unknown value" (`Unlisted`).
-}
resolve : Config id msg -> List (Option id) -> List (Selected id) -> List (Chip id)
resolve config available selection =
    if List.all (\sel -> sel.option /= Nothing) selection then
        List.filterMap (\sel -> Maybe.map Labelled sel.option) selection

    else
        let
            unlisted value =
                case config.valueText of
                    Just toText ->
                        Labelled (Select.option value (toText value))

                    Nothing ->
                        Unlisted

            unknown value =
                if config.serverSearch then
                    unlisted value

                else
                    case config.options of
                        Loaded _ ->
                            unlisted value

                        Kept _ ->
                            unlisted value

                        Failed _ ->
                            Unresolved False

                        _ ->
                            Unresolved True
        in
        List.map
            (\sel ->
                case sel.option of
                    Just opt ->
                        Labelled opt

                    Nothing ->
                        case Popup.findByValue sel.value available of
                            Just opt ->
                                Labelled opt

                            Nothing ->
                                unknown sel.value
            )
            selection


chipText : Popup.Texts -> Chip id -> String
chipText t chip =
    case chip of
        Labelled opt ->
            opt.label

        Unresolved True ->
            t.loading

        Unresolved False ->
            t.unavailable

        Unlisted ->
            t.unknownValue


{-| The labels for the summary a screen reader hears; values without a label
are said once ("Loading ...") instead of once each.
-}
spokenNames : Popup.Texts -> List (Chip id) -> List String
spokenNames t chips =
    let
        labels =
            List.filterMap
                (\chip ->
                    case chip of
                        Labelled opt ->
                            Just opt.label

                        Unresolved _ ->
                            Nothing

                        Unlisted ->
                            Nothing
                )
                chips

        unresolved =
            List.filter
                (\chip ->
                    case chip of
                        Labelled _ ->
                            False

                        Unresolved _ ->
                            True

                        Unlisted ->
                            True
                )
                chips
    in
    case unresolved of
        first :: _ ->
            labels ++ [ chipText t first ]

        [] ->
            labels


{-| How many chips the field shows when the application does not say.
-}
defaultVisibleChips : Int
defaultVisibleChips =
    5


{-| How many of the hidden values the "+N" chip names in its tooltip.
-}
hiddenPreview : Int
hiddenPreview =
    20


{-| A click that started on a chip's remove button must not open the list.
-}
fromRemoveButton : Decode.Decoder Bool
fromRemoveButton =
    let
        hasClass path =
            Decode.oneOf
                [ Decode.at (path ++ [ "className" ]) Decode.string |> Decode.map (String.contains "klar-tag__remove")
                , Decode.succeed False
                ]
    in
    Decode.map2 (||) (hasClass [ "target" ]) (hasClass [ "target", "parentElement" ])


{-| The message for choosing the "Create" row: the typed text as the label, and
the value the `creatable` function makes of it.
-}
createMsg : Config id msg -> String -> Msg id
createMsg config text =
    case config.creatable of
        Just make ->
            CreateValue (Select.option (make text) text)

        Nothing ->
            NoOp


viewControl : (Msg id -> msg) -> Config id msg -> Field.Config -> Popup.Texts -> Popup.Env id -> State id -> Html msg
viewControl toMsg config field t env (State state) =
    let
        interactive =
            not config.disabled && not config.readOnly

        count =
            List.length state.selected

        -- The field shows this many chips and "+N" for the rest, so it does
        -- not grow with the selection ("Select all" on a long list would give
        -- a field half a screen high). Every value stays reachable: the "+N"
        -- chip names the hidden ones in its tooltip, a screen reader hears the
        -- first ten in the summary, and the list shows them all ticked.
        chipLimit =
            min 200 (Maybe.withDefault defaultVisibleChips config.maxVisibleChips)

        resolved =
            resolve config env.options (List.take (max (chipLimit + hiddenPreview) 10) state.selected)

        visibleChips =
            List.take chipLimit resolved

        hiddenChips =
            List.take hiddenPreview (List.drop chipLimit resolved)

        hiddenCount =
            count - List.length visibleChips

        openMsg =
            toMsg (Open env "")

        tagSize =
            if config.size == Small then
                Small

            else
                Medium

        summary =
            if count == 0 then
                Maybe.withDefault t.placeholder config.placeholder

            else
                t.selected count
                    ++ ": "
                    ++ String.join ", " (spokenNames t (List.take 10 resolved))
                    ++ (if count > 10 then
                            ", …"

                        else
                            ""
                       )

        typed =
            Just (\char -> toMsg (Open env char))

        triggerKeys =
            if interactive && not state.open then
                Popup.onTriggerKeys
                    ([ ( "Enter", openMsg ), ( " ", openMsg ), ( "ArrowDown", openMsg ), ( "ArrowUp", openMsg ) ]
                        ++ (if count > 0 then
                                [ ( "Backspace", toMsg RemoveLast ) ]

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
                    { typed = \char -> toMsg (Open env char)
                    , backspace = toMsg (Backspace env)
                    , move = \move -> toMsg (Key env config.visibleRows config.maxSelected move)
                    , close = toMsg Close
                    , leave = toMsg Dismiss
                    }

            else
                Internal.noAttr

        chipMark opt =
            case ( opt.color, opt.tone ) of
                ( Just value, _ ) ->
                    [ Tag.color value ]

                ( Nothing, Just value ) ->
                    [ Tag.tone value ]

                ( Nothing, Nothing ) ->
                    []

        chip item =
            case item of
                Labelled opt ->
                    Html.span [ Internal.cls [ "klar-select__chip" ] ]
                        [ Tag.view
                            ([ Tag.size tagSize, Tag.locale config.locale ]
                                ++ chipMark opt
                                ++ (if interactive then
                                        [ Tag.onRemove (toMsg (Remove opt)) ]

                                    else
                                        []
                                   )
                            )
                            opt.label
                        ]

                Unresolved _ ->
                    -- no label to name a remove button after: the chip is only a
                    -- place holder until the options arrive
                    Html.span [ Internal.cls [ "klar-select__chip", "klar-select__chip--unknown" ] ]
                        [ Tag.view [ Tag.size tagSize, Tag.outline, Tag.locale config.locale ] (chipText t item) ]

                Unlisted ->
                    Html.span [ Internal.cls [ "klar-select__chip", "klar-select__chip--unknown" ] ]
                        [ Tag.view [ Tag.size tagSize, Tag.outline, Tag.locale config.locale ] (chipText t item) ]

        more =
            if hiddenCount > 0 then
                Html.span
                    [ Internal.cls [ "klar-select__chip", "klar-select__more" ]
                    , Attr.title
                        (t.moreLabel hiddenCount
                            ++ ": "
                            ++ String.join ", " (List.map (chipText t) hiddenChips)
                            ++ (if hiddenCount > List.length hiddenChips then
                                    ", …"

                                else
                                    ""
                               )
                        )
                    ]
                    [ Tag.view [ Tag.size tagSize, Tag.outline ] (t.more hiddenCount) ]

            else
                Html.text ""
    in
    Html.div
        [ Internal.cls
            [ "klar-input"
            , "klar-input--" ++ Internal.sizeSuffix config.size
            , "klar-select__control"
            , "klar-select__control--multi"
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
            Events.on "click"
                (fromRemoveButton
                    |> Decode.andThen
                        (\isRemove ->
                            if isRemove then
                                Decode.fail "chip removed"

                            else
                                Decode.succeed openMsg
                        )
                )

          else
            Internal.noAttr
        ]
        [ Html.button
            (Field.controlAttributes field
                ++ [ Internal.cls [ "klar-select__trigger", "klar-select__trigger--overlay" ]
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
                   , triggerKeys
                   ]
            )
            [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text summary ] ]
        , Html.div [ Internal.cls [ "klar-select__chips" ] ]
            (if count == 0 then
                [ Html.span [ Internal.cls [ "klar-select__placeholder" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.text (Maybe.withDefault t.placeholder config.placeholder) ]
                ]

             else
                List.map chip visibleChips ++ [ more ]
            )
        , if config.clearable && interactive && count > 0 then
            Popup.viewClearButton t.clearAll (toMsg ClearAll)

          else
            Html.text ""
        , if config.readOnly then
            Html.text ""

          else
            Popup.viewChevron

        -- always on the page, so that a change is announced when it happens
        , Html.span
            [ Internal.cls [ "klar-sr-only" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            ]
            [ Html.text
                (case state.said of
                    Just (RemovedValue (Just name)) ->
                        t.removed name

                    Just (RemovedValue Nothing) ->
                        t.removedValue

                    Just RemovedAll ->
                        t.removedAll

                    Nothing ->
                        ""
                )
            ]
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

        count =
            List.length state.selected

        remaining =
            Maybe.map (\limit -> max 0 (limit - count)) config.maxSelected

        atMax =
            remaining == Just 0

        isLoaded =
            case config.options of
                Loaded _ ->
                    True

                Kept _ ->
                    True

                _ ->
                    False

        hasRows =
            isLoaded && rows.optionRows > 0

        canSelectAll =
            hasRows && not atMax && anyLeftToChoose rows.matched state.selected

        canClear =
            count > 0

        navigate index =
            toMsg (Navigate geometry index)

        toggleRow index =
            case Popup.rowAt index rows of
                Just (Popup.Item _ opt) ->
                    if opt.disabled || (atMax && not (isChosen opt.value state.selected)) then
                        toMsg NoOp

                    else
                        toMsg (Toggle opt)

                Just (Popup.Create _ text) ->
                    if atMax then
                        toMsg NoOp

                    else
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
                    , ( "Enter", toggleRow h )
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
            if hasRows then
                Popup.noticeRetry config.freshness config.onRetry

            else
                Nothing

        -- What Enter and Tab do on a failure depends on whether a "Try again"
        -- button is on screen: the problem must be worth retrying and the
        -- application must have said what retrying means.
        retry =
            case config.options of
                Failed problem ->
                    Popup.retryFor problem config.onRetry

                _ ->
                    Nothing

        retryFocusable =
            Popup.isJust retry

        actionsFocusable =
            hasRows && (canSelectAll || canClear)

        keys =
            Popup.onSearchKeys
                { handled = navigation ++ [ ( "Escape", toMsg Close ) ]
                , whenEmpty = ends
                , passive =
                    ( "Shift+Tab", toMsg Dismiss )
                        :: (if retryFocusable || actionsFocusable || Popup.isJust staleRetry then
                                []

                            else
                                [ ( "Tab", toMsg Dismiss ) ]
                           )
                        ++ (if String.isEmpty state.query && count > 0 then
                                [ ( "Backspace", toMsg RemoveLast ) ]

                            else
                                []
                           )
                }

        leaveOnTab isLast =
            if isLast then
                [ Popup.onKeydown { handled = [], passive = [ ( "Tab", toMsg Dismiss ) ] } ]

            else
                []

        actions =
            [ Button.view
                [ Button.small
                , Button.ghost
                , Button.disabled (not canSelectAll)
                , Button.onClick (toMsg (SelectAllMatched env config.maxSelected))
                , Button.htmlAttrs (Internal.onMouseDownPrevent (toMsg NoOp) :: leaveOnTab (canSelectAll && not canClear))
                ]
                (if String.isEmpty (String.trim state.query) then
                    t.selectAll

                 else
                    t.selectAllFiltered
                )
            , Button.view
                [ Button.small
                , Button.ghost
                , Button.disabled (not canClear)
                , Button.onClick (toMsg ClearAll)
                , Button.htmlAttrs (Internal.onMouseDownPrevent (toMsg NoOp) :: leaveOnTab canClear)
                ]
                t.clearAll
            ]

        status =
            Popup.statusText t env.filterLocally state.query rows
                ++ " · "
                ++ (case config.maxSelected of
                        Just limit ->
                            t.selectedOfMax count limit

                        Nothing ->
                            t.selected count
                   )

        rowConfig =
            { idBase = state.id
            , query = state.query
            , highlighted = highlighted
            , setSize = rows.optionRows
            , indicator = Popup.CheckBox
            , isSelected = \opt -> isChosen opt.value state.selected
            , isBlocked = \_ -> atMax
            , selectedFollowsHighlight = False
            , onPick = Toggle >> toMsg
            , onCreate =
                \text ->
                    if atMax then
                        toMsg NoOp

                    else
                        toMsg (createMsg config text)
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
                , Attr.attribute "aria-multiselectable" "true"
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
                        , leave =
                            if actionsFocusable then
                                -- Tab goes on to "Select all" and "Clear all"
                                Nothing

                            else
                                Just (toMsg Dismiss)
                        }
                        config.freshness
                    , list
                    , Popup.viewFooter status actions
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
                    if hasRows then
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
                , onFocus = toMsg (SearchFocused env)
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
