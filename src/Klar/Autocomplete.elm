module Klar.Autocomplete exposing
    ( State, init, Msg, update, view
    , text, setText, picked, setOption, clear, query, isOpen, open, close
    , Attribute, options, remote, serverSearch, onRetry, onEnter
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, minChars, clearable, disabled, readOnly, size, visibleRows, prefixIcon, locale, settings
    )

{-| A text field with suggestions. Unlike [Klar.Select](Klar-Select) the user may
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
follow `locale` and are English by default (see [Klar.Locale](Klar-Locale)).


# State

@docs State, init, Msg, update, view


# Value and popup

@docs text, setText, picked, setOption, clear, query, isOpen, open, close


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, options, remote, serverSearch, onRetry, onEnter


# Field

The label, hint and error around the field work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs placeholder, minChars, clearable, disabled, readOnly, size, visibleRows, prefixIcon, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Field as Field
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select exposing (Option)
import Klar.Select.Match as Match
import Klar.Select.Popup as Popup
import Klar.Settings as Settings exposing (Settings)
import Klar.Spinner as Spinner
import Klar.Theme as Theme exposing (Size(..))
import Klar.VirtualList as VirtualList
import Process
import Task



-- STATE


{-| Everything one autocomplete keeps track of: the text in the field, the value
of the suggestion it came from (if any), and whether the list is open. `id` is
the type of the suggestions' values (a `CustomerId`, or `String`). Make it with
`init`, keep it in your model and pass it to `view` and `update`.
-}
type State id
    = State
        { id : String
        , text : String
        , searched : String
        , wait : Int
        , picked : Maybe id
        , open : Bool
        , highlighted : Maybe Int
        , list : VirtualList.State
        , cache : Maybe (Popup.Cache id)
        }


{-| An empty field. The `String` is the DOM id of the input and must be unique
on the page: the label points to it, and the ids of the list are derived from it
(`city-listbox`, `city-popup`).

    Autocomplete.init "city"

-}
init : String -> State id
init id =
    State
        { id = id
        , text = ""
        , searched = ""
        , wait = 0
        , picked = Nothing
        , open = False
        , highlighted = Nothing
        , list = VirtualList.init (listboxId id)
        , cache = Nothing
        }


{-| What is in the field: what the user typed, or the label of the suggestion
they picked. With `serverSearch`, fetch when `query` changes.
-}
text : State id -> String
text (State state) =
    state.text


{-| The text to fetch `serverSearch` suggestions for: it follows `text` after a pause of
300 ms in the typing (at once when a suggestion is picked, the field is cleared or
`setText` or `setOption` is called), so **write no debounce of your own**. Fetch
when it changes, and drop an answer whose text is no longer the current `query`.

    if Autocomplete.query city /= Autocomplete.query model.city then
        fetchCities (Autocomplete.query city)

-}
query : State id -> String
query (State state) =
    state.searched


{-| Replaces the text, for example to show a saved free text. It clears `picked`
and closes the list; use `setOption` when the text is a suggestion, and `clear` to
empty the field (`setText ""` is the same thing).

    Autocomplete.setText "Rotterdam" model.city

-}
setText : String -> State id -> State id
setText newText (State state) =
    State { state | text = newText, searched = newText, picked = Nothing, open = False, highlighted = Nothing }


{-| The value of the suggestion the text came from, or `Nothing` when the text is
free. It is set when a suggestion is picked, or when the list closes (Enter, Tab,
Escape or a click elsewhere) on a text that is exactly the label of a suggestion
(ignoring case and diacritics), and it is cleared as soon as the text is edited or
replaced with `setText`.
-}
picked : State id -> Maybe id
picked (State state) =
    state.picked


{-| Puts a suggestion in the field as if the user had picked it: its label is the
text, and its value is what `picked` returns. Use it to show a saved record whose
value you keep, for example the customer of an order being edited.

    Autocomplete.setOption (Select.option order.customerId order.customerName) model.customer

-}
setOption : Option id -> State id -> State id
setOption opt (State state) =
    State { state | text = opt.label, searched = opt.label, picked = Just opt.value, open = False, highlighted = Nothing }


{-| Empties the field: no text, nothing `picked`, and the list closed. This is
the way to empty the field from code; `setText ""` is the same thing.
-}
clear : State id -> State id
clear (State state) =
    State { state | text = "", searched = "", picked = Nothing, open = False, highlighted = Nothing }


{-| Whether the suggestion list is open. It can be `True` while nothing is
visible, because there are no suggestions to show.
-}
isOpen : State id -> Bool
isOpen (State state) =
    state.open


{-| Opens the suggestion list for the text in the field and moves focus into the
field, for example from a button of your own. Map the command like the one from
`update`.

    ShowCities ->
        let
            ( city, cmd ) =
                Autocomplete.open model.city
        in
        ( { model | city = city }, Cmd.map CityMsg cmd )

-}
open : State id -> ( State id, Cmd (Msg id) )
open (State state) =
    ( State { state | open = True, highlighted = Nothing, list = VirtualList.reset state.list }
    , Internal.focus state.id NoOp
    )


{-| Closes the suggestion list and keeps the text. Map the command like the one
from `update`.
-}
close : State id -> ( State id, Cmd (Msg id) )
close (State state) =
    ( State { state | open = False, highlighted = Nothing }, Cmd.none )


listboxId : String -> String
listboxId id =
    id ++ "-listbox"


popupId : String -> String
popupId id =
    id ++ "-popup"



-- UPDATE


{-| The messages an autocomplete sends. Wrap it in a constructor of your own
message type (`CityMsg (Autocomplete.Msg String)`), give that constructor to
`view`, and pass the messages you get back to `update`.
-}
type Msg id
    = Input (Popup.Env id) Int String
    | Blurred (Popup.Env id)
    | Show (Popup.Env id)
    | Navigate VirtualList.Geometry (Maybe Int)
    | Hover Int
    | Pick (Option id)
    | Commit (Popup.Env id)
    | Close (Popup.Env id)
    | Clear
    | ListMsg VirtualList.Msg
    | Settle Int
    | NoOp


{-| Handles a message of the autocomplete and returns the new state with a
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

-}
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
update msg ((State state) as current) =
    case msg of
        Input env minimum newText ->
            let
                ( list, scroll ) =
                    VirtualList.scrollTo 0 state.list
            in
            ( State
                { state
                    | text = newText
                    , picked = Nothing
                    , open = String.length (String.trim newText) >= minimum
                    , highlighted = Nothing
                    , list = list
                    , cache = Just (Popup.refresh state.cache env newText)
                    , wait = state.wait + 1
                }
            , Cmd.batch
                [ if state.open then
                    Cmd.map ListMsg scroll

                  else
                    Cmd.none
                , Process.sleep 300 |> Task.perform (\_ -> Settle (state.wait + 1))
                ]
            )

        Blurred env ->
            ( settle env current, Cmd.none )

        Show env ->
            let
                cache =
                    Popup.refresh state.cache env state.text
            in
            ( State
                { state
                    | open = True
                    , highlighted = Popup.first cache.rows
                    , list = VirtualList.reset state.list
                    , cache = Just cache
                }
            , Cmd.none
            )

        Navigate geometry target ->
            case target of
                Just index ->
                    let
                        ( list, scroll ) =
                            VirtualList.ensureVisible geometry index state.list
                    in
                    ( State { state | highlighted = Just index, list = list }, Cmd.map ListMsg scroll )

                Nothing ->
                    ( State { state | highlighted = Nothing }, Cmd.none )

        Hover index ->
            ( State { state | highlighted = Just index }, Cmd.none )

        Pick opt ->
            ( setOption opt current, Cmd.none )

        Commit env ->
            ( settle env current, Cmd.none )

        Close env ->
            ( settle env current, Cmd.none )

        Clear ->
            ( clear current, Internal.focus state.id NoOp )

        Settle ticket ->
            if ticket == state.wait then
                ( State { state | searched = state.text }, Cmd.none )

            else
                ( current, Cmd.none )

        ListMsg inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner state.list
            in
            ( State { state | list = list }, Cmd.map ListMsg cmd )

        NoOp ->
            ( current, Cmd.none )


{-| The list closes, by whatever key or click: a typed text that is exactly the
label of a suggestion is that suggestion. A text that came from a pick keeps its
value (two suggestions may have the same label).
-}
settle : Popup.Env id -> State id -> State id
settle env (State state) =
    State
        { state
            | open = False
            , highlighted = Nothing
            , picked =
                case state.picked of
                    Just value ->
                        Just value

                    Nothing ->
                        exactMatch env state.text
        }


exactMatch : Popup.Env id -> String -> Maybe id
exactMatch env typed =
    if String.isEmpty (String.trim typed) then
        Nothing

    else
        env.options
            |> List.filter (\opt -> not opt.disabled && Match.isExactMatch typed opt)
            |> List.head
            |> Maybe.map .value



-- ATTRIBUTES


{-| A setting of an autocomplete. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. `id` is the type of the
suggestions' values.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type Source id
    = Local (List (Option id))
    | FromApp (Remote (List (Option id)))


type alias Config id msg =
    { field : Field.Config
    , source : Source id
    , serverSearch : Bool
    , freshness : Freshness
    , placeholder : String
    , minChars : Int
    , clearable : Bool
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , visibleRows : Int
    , prefixIcon : Maybe Icon
    , locale : Locale
    , settings : Settings
    , onRetry : Maybe msg
    , onEnter : Maybe msg
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , source = Local []
        , serverSearch = False
        , freshness = Freshness.Fresh
        , placeholder = ""
        , minChars = 1
        , clearable = False
        , disabled = False
        , readOnly = False
        , size = Medium
        , visibleRows = 8
        , prefixIcon = Nothing
        , locale = Locale.default
        , settings = Settings.default
        , onRetry = Nothing
        , onEnter = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute id msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| Suggestions that the component filters itself as the user types: best match
first, ignoring case and diacritics, with several words that must all match, in
labels, descriptions and keywords (the scoring of [Klar.Search](Klar-Search)).
The list is hidden while nothing matches. The default is no suggestions. Use
`options` or `remote`, not both: the later one wins. For a list that comes from
the backend, give its `Remote` to `remote` rather than flattening it with
`Remote.withDefault`, so the field shows its loading and failed states.

    Autocomplete.options (List.map (\name -> Select.option name name) cities)

-}
options : List (Option id) -> Attribute id msg
options list =
    Attribute (\config -> { config | source = Local list, freshness = Freshness.Fresh })


{-| Suggestions from the backend, as a `Remote` (see [Klar.Remote](Klar-Remote)).
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

-}
remote : Remote (List (Option id)) -> Attribute id msg
remote data =
    let
        ( current, freshness ) =
            Freshness.settle data
    in
    Attribute (\config -> { config | source = FromApp current, freshness = freshness })


{-| The server does the searching: the field shows the `remote` suggestions exactly
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

-}
serverSearch : Attribute id msg
serverSearch =
    Attribute (\config -> { config | serverSearch = True })


{-| The message to send when the user presses the "Try again" button of the error
shown when `remote` suggestions failed. The button appears only for problems that
are worth retrying (network trouble, timeouts, server errors), and it is for the
mouse: the focus stays in the field, where Enter sends the message as well and Tab
moves on. For other problems (no access, not found ...) nothing is retried, and
Enter keeps the typed text as usual.

    Autocomplete.onRetry ReloadCities

-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The message to send when the user presses Enter and no suggestion is
highlighted, so the typed text is kept (to run a search for it, for example). It
arrives after the component has updated `picked`, so you can read
`Autocomplete.text` and `Autocomplete.picked` in your handler. Picking a
suggestion is a state change instead: compare `Autocomplete.picked` before and
after to react to it. A `disabled` or `readOnly` field sends nothing.

    Autocomplete.onEnter SearchSubmitted

-}
onEnter : msg -> Attribute id msg
onEnter msg =
    Attribute (\config -> { config | onEnter = Just msg })


{-| The label above the field. It names the input for screen readers.
-}
label : String -> Attribute id msg
label value_ =
    updateField (Field.setLabel value_)


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
hint value_ =
    updateField (Field.setHint value_)


{-| Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.
It is safe to set it while the user types: the input keeps its place in the
page, and so its keyboard focus, whether or not there is a label or a hint.
-}
error : String -> Attribute id msg
error value_ =
    updateField (Field.setError (Just value_))


{-| Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

    Autocomplete.errorMaybe model.cityError

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
optionalText value_ =
    updateField (Field.setOptionalText value_)


{-| The text shown in the empty field. There is none by default: the field takes
free text, so there is nothing general to say.
-}
placeholder : String -> Attribute id msg
placeholder value_ =
    Attribute (\config -> { config | placeholder = value_ })


{-| How many characters the user has to type before suggestions appear. The
default is 1, and spaces at the ends do not count. ArrowDown opens the list
whatever the length.
-}
minChars : Int -> Attribute id msg
minChars n =
    Attribute (\config -> { config | minChars = max 0 n })


{-| Shows a small × that empties the field, closes the list and returns focus to
the field. It is shown only while the field has text.
-}
clearable : Attribute id msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| While `True` the field is dimmed and cannot be focused or edited. The text
is kept. Pass a field of your model, for example while a form is saving. The
default is `False`.
-}
disabled : Bool -> Attribute id msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the field shows its text but does not let the user change it,
and no suggestions are shown. Unlike `disabled`, a read-only field can be focused
and its text selected. The default is `False`.
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


{-| How many suggestions show before the list scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.
-}
visibleRows : Int -> Attribute id msg
visibleRows n =
    Attribute (\config -> { config | visibleRows = clamp 3 20 n })


{-| An icon at the start of the field, such as a magnifying glass. There is none
by default.

    Autocomplete.prefixIcon Icon.search

-}
prefixIcon : Icon -> Attribute id msg
prefixIcon icon =
    Attribute (\config -> { config | prefixIcon = Just icon })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Autocomplete.settings model.settings

-}
settings : Settings -> Attribute id msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text: "No suggestions", "Loading ...", the
suggestion count for screen readers, the "Clear search" label and the error
state. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar-Locale).

    Autocomplete.locale Locale.nb

-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


type Content id
    = Hidden
    | Rows (Popup.Rows id)
    | Busy
    | Failed Remote.Problem
    | NoSuggestions


{-| The autocomplete. It takes the constructor that wraps the component's `Msg`
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

-}
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        field =
            Field.setId state.id config.field

        t =
            Popup.texts config.locale

        interactive =
            not config.disabled && not config.readOnly

        env =
            case config.source of
                Local list ->
                    { options = list, filterLocally = True, creatable = False }

                FromApp data ->
                    { options = Remote.withDefault [] data, filterLocally = not config.serverSearch, creatable = False }

        rows () =
            Popup.cachedRows state.cache env state.text

        -- A list the field filters itself is hidden while nothing matches, as
        -- with `options`; the hits of a server search say "No suggestions".
        loadedContent () =
            let
                built =
                    rows ()
            in
            if built.optionRows > 0 then
                Rows built

            else if config.serverSearch then
                NoSuggestions

            else
                Hidden

        content =
            if not (state.open && interactive) then
                Hidden

            else
                case config.source of
                    Local _ ->
                        let
                            built =
                                rows ()
                        in
                        if built.optionRows == 0 then
                            Hidden

                        else
                            Rows built

                    FromApp data ->
                        case data of
                            NotAsked ->
                                Hidden

                            Loading ->
                                Busy

                            Remote.Failed problem ->
                                Failed problem

                            Remote.Loaded _ ->
                                loadedContent ()

                            Remote.Kept _ ->
                                -- settled when it was given: never here
                                loadedContent ()

        -- What Enter does on a failure depends on whether a "Try again" button
        -- is on screen: the problem must be worth retrying and the application
        -- must have said what retrying means.
        retry =
            case content of
                Failed problem ->
                    Popup.retryFor problem config.onRetry

                _ ->
                    Nothing

        visible =
            case content of
                Hidden ->
                    False

                _ ->
                    True

        hasListbox =
            case content of
                Rows _ ->
                    True

                _ ->
                    False

        highlighted =
            case content of
                Rows built ->
                    state.highlighted |> Maybe.andThen (\index -> Popup.resolve (Just index) built)

                _ ->
                    Nothing

        activeDescendant =
            case content of
                Rows built ->
                    Popup.activeDescendant state.id (Popup.geometry config.visibleRows built) state.list highlighted

                _ ->
                    Nothing

        -- Tab always closes the list and moves on: nothing in the popup takes
        -- focus (its "Try again" is for the mouse; Enter retries).
        leave =
            ( "Tab", toMsg (Close env) )

        keys =
            if not interactive then
                Internal.noAttr

            else
                case content of
                    Rows built ->
                        let
                            geometry =
                                Popup.geometry config.visibleRows built

                            navigate target =
                                toMsg (Navigate geometry target)

                            moves =
                                case highlighted of
                                    Just h ->
                                        [ ( "ArrowDown", navigate (Just (Popup.next built h)) )
                                        , ( "ArrowUp"
                                          , if Popup.first built == Just h then
                                                navigate Nothing

                                            else
                                                navigate (Just (Popup.prev built h))
                                          )
                                        , ( "PageDown", navigate (Just (Popup.pageDown (Popup.pageSize config.visibleRows) built h)) )
                                        , ( "PageUp", navigate (Just (Popup.pageUp (Popup.pageSize config.visibleRows) built h)) )
                                        , ( "Enter"
                                          , case Popup.rowAt h built of
                                                Just (Popup.Item _ opt) ->
                                                    toMsg (Pick opt)

                                                _ ->
                                                    toMsg NoOp
                                          )
                                        ]

                                    Nothing ->
                                        [ ( "ArrowDown", navigate (Popup.first built) )
                                        , ( "ArrowUp", navigate (Popup.last built) )
                                        ]
                        in
                        Popup.onKeydown
                            { handled = moves ++ [ ( "Escape", toMsg (Close env) ) ]
                            , passive = [ leave, ( "Enter", toMsg (Commit env) ) ]
                            }

                    Hidden ->
                        Popup.onKeydown
                            { handled =
                                if hasSomething config then
                                    [ ( "ArrowDown", toMsg (Show env) ) ]

                                else
                                    []
                            , passive = [ ( "Enter", toMsg (Commit env) ) ]
                            }

                    Failed _ ->
                        case retry of
                            Just retryMsg ->
                                Popup.onKeydown
                                    { handled = [ ( "Escape", toMsg (Close env) ), ( "Enter", retryMsg ) ]
                                    , passive = [ leave ]
                                    }

                            Nothing ->
                                Popup.onKeydown
                                    { handled = [ ( "Escape", toMsg (Close env) ) ]
                                    , passive = [ leave, ( "Enter", toMsg (Commit env) ) ]
                                    }

                    _ ->
                        Popup.onKeydown
                            { handled = [ ( "Escape", toMsg (Close env) ) ]
                            , passive = [ leave, ( "Enter", toMsg (Commit env) ) ]
                            }

        isBusy =
            case config.source of
                FromApp Loading ->
                    state.open

                _ ->
                    False

        liveText =
            case content of
                Rows built ->
                    t.suggestions built.matchCount

                Busy ->
                    t.loading

                NoSuggestions ->
                    t.noSuggestions

                _ ->
                    ""
    in
    -- The field is always wrapped: the application may set an error while the
    -- user types, and an input that moves into the wrapper then loses focus.
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-anchor"
                , "klar-anchor--block"
                , "klar-autocomplete"
                , if visible then
                    "klar-autocomplete--open"

                  else
                    ""
                ]
            , if interactive then
                -- the same IME-safe decoder as the input's own keys
                Internal.attrMaybe (\msg -> Popup.onKeydown { handled = [], passive = [ ( "Enter", msg ) ] }) config.onEnter

              else
                Internal.noAttr
            ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Internal.sizeSuffix config.size
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
                ]
                [ Internal.viewMaybe
                    (\icon -> Html.span [ Internal.cls [ "klar-input__adornment", "klar-input__prefix" ] ] [ Icon.view icon ])
                    config.prefixIcon
                , Html.input
                    (Field.controlAttributes field
                        ++ [ Internal.cls [ "klar-input__control" ]
                           , Attr.type_ "text"
                           , Attr.value state.text
                           , Attr.placeholder config.placeholder
                           , Attr.disabled config.disabled
                           , Attr.readonly config.readOnly
                           , Attr.attribute "role" "combobox"
                           , Attr.attribute "aria-autocomplete" "list"
                           , Attr.attribute "aria-expanded"
                                (if visible then
                                    "true"

                                 else
                                    "false"
                                )
                           , if hasListbox then
                                Attr.attribute "aria-controls" (listboxId state.id)

                             else
                                Internal.attrIf visible (Attr.attribute "aria-controls" (popupId state.id))
                           , Internal.attrMaybe (Attr.attribute "aria-activedescendant") activeDescendant
                           , Internal.attrIf isBusy (Attr.attribute "aria-busy" "true")
                           , Attr.attribute "autocomplete" "off"
                           , Attr.spellcheck False
                           , Events.onInput (Input env config.minChars >> toMsg)
                           , Events.onBlur (toMsg (Blurred env))
                           , keys
                           ]
                    )
                    []
                , if isBusy then
                    Html.span [ Internal.cls [ "klar-input__adornment" ] ] [ Spinner.view [ Spinner.size Small, Spinner.label t.loading ] ]

                  else
                    Html.text ""
                , if config.clearable && interactive && state.text /= "" then
                    Html.button
                        [ Internal.cls [ "klar-input__clear" ]
                        , Attr.type_ "button"
                        , Attr.tabindex -1
                        , Attr.attribute "aria-label" t.clearQuery
                        , Attr.title t.clearQuery
                        , Internal.onMouseDownPrevent (toMsg NoOp)
                        , Events.onClick (toMsg Clear)
                        ]
                        [ Icon.view Icon.close ]

                  else
                    Html.text ""
                ]
            , Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status", Attr.attribute "aria-live" "polite" ]
                [ Html.text liveText ]
            , viewPopup toMsg config t { id = state.id, list = state.list, text = state.text } highlighted retry content
            ]
        )


hasSomething : Config id msg -> Bool
hasSomething config =
    case config.source of
        Local list ->
            not (List.isEmpty list)

        FromApp data ->
            data /= NotAsked


viewPopup :
    (Msg id -> msg)
    -> Config id msg
    -> Popup.Texts
    -> { id : String, list : VirtualList.State, text : String }
    -> Maybe Int
    -> Maybe msg
    -> Content id
    -> Html msg
viewPopup toMsg config t state highlighted retry content =
    let
        popup children =
            Html.div
                [ Internal.cls [ "klar-popup", "klar-select__popup", "klar-select__popup--suggest", Freshness.className config.freshness ]
                , Attr.id (popupId state.id)
                , Freshness.busyAttr config.freshness
                , Internal.onMouseDownPrevent (toMsg NoOp)
                ]
                children
    in
    case content of
        Hidden ->
            Html.text ""

        Busy ->
            popup [ Html.div [ Attr.attribute "aria-busy" "true" ] [ Popup.viewSkeleton 4 ] ]

        Failed problem ->
            popup
                [ Popup.viewFailure
                    { locale = config.locale
                    , onRetry = retry
                    , focusable = False
                    , refocus = toMsg NoOp
                    , leave = toMsg NoOp
                    , noop = toMsg NoOp
                    }
                    problem
                ]

        NoSuggestions ->
            popup [ Popup.viewMessage t.noSuggestions ]

        Rows rows ->
            let
                rowConfig =
                    { idBase = state.id
                    , query = state.text
                    , highlighted = highlighted
                    , setSize = rows.optionRows
                    , indicator = Popup.NoIndicator
                    , isSelected = \_ -> False
                    , isBlocked = always False
                    , selectedFollowsHighlight = True
                    , onPick = Pick >> toMsg
                    , onCreate = \_ -> toMsg NoOp
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
                        ]
                    ]
            in
            popup
                [ Freshness.notice
                    { locale = config.locale, settings = config.settings, onRetry = Nothing, inline = False }
                    config.freshness
                , if rows.grouped then
                    VirtualList.viewGrouped (ListMsg >> toMsg)
                        listAttributes
                        { items = rows.rows, viewRow = Popup.viewRow rowConfig, viewHeader = Popup.viewPinned }
                        state.list

                  else
                    VirtualList.view (ListMsg >> toMsg)
                        listAttributes
                        { items = rows.rows, viewRow = Popup.viewRow rowConfig }
                        state.list
                ]
