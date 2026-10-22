module Klar.Autocomplete exposing
    ( State, init, Msg, update, view
    , text, setText, picked, isOpen
    , Attribute, options, suggestions, onRetry, onEnter, zone
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, minChars, clearable, disabled, readOnly, size, visibleRows, prefixIcon, locale
    )

{-| A text field with suggestions. Unlike [Klar.Select](Klar-Select) the user may
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
`with*` helpers, see [Klar.Select.Option](Klar-Select-Option)): the label is what
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
follow `locale` and are English by default (see [Klar.Locale](Klar-Locale)).


# State

@docs State, init, Msg, update, view


# Value

@docs text, setText, picked, isOpen


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, options, suggestions, onRetry, onEnter, zone


# Field

The label, hint and error around the field work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs placeholder, minChars, clearable, disabled, readOnly, size, visibleRows, prefixIcon, locale

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
import Klar.Select.Match as Match
import Klar.Select.Option as Option exposing (Option)
import Klar.Select.Popup as Popup
import Klar.Spinner as Spinner
import Klar.Theme as Theme exposing (Size(..))
import Klar.VirtualList as VirtualList
import Time



-- STATE


{-| Everything one autocomplete keeps track of: the text in the field, the value
of the suggestion it came from (if any), and whether the list is open. Make it
with `init`, keep it in your model and pass it to `view` and `update`.
-}
type State
    = State
        { id : String
        , text : String
        , picked : Maybe String
        , open : Bool
        , highlighted : Maybe Int
        , list : VirtualList.State
        , cache : Maybe (Popup.Cache String)
        }


{-| An empty field. The `String` is the DOM id of the input and must be unique
on the page: the label points to it, and the id of the list is derived from it
(`city-listbox`).

    Autocomplete.init "city"

-}
init : String -> State
init id =
    State
        { id = id
        , text = ""
        , picked = Nothing
        , open = False
        , highlighted = Nothing
        , list = VirtualList.init (listboxId id)
        , cache = Nothing
        }


{-| What is in the field: what the user typed, or the label of the suggestion
they picked. With `suggestions` from a backend, fetch when it changes.
-}
text : State -> String
text (State state) =
    state.text


{-| Replaces the text, for example to show a saved value. It clears `picked` and
closes the list.

    Autocomplete.setText "Rotterdam" model.city

-}
setText : String -> State -> State
setText newText (State state) =
    State { state | text = newText, picked = Nothing, open = False, highlighted = Nothing }


{-| The value of the suggestion the text came from, or `Nothing` when the text is
free. It is set when a suggestion is picked, or when Enter is pressed on a text
that is exactly the label of a suggestion (ignoring case and diacritics), and it
is cleared as soon as the text is edited or replaced with `setText`.
-}
picked : State -> Maybe String
picked (State state) =
    state.picked


{-| Whether the suggestion list is open. It can be `True` while nothing is
visible, because there are no suggestions to show.
-}
isOpen : State -> Bool
isOpen (State state) =
    state.open


listboxId : String -> String
listboxId id =
    id ++ "-listbox"



-- UPDATE


{-| The messages an autocomplete sends. Wrap it in a constructor of your own
message type (`CityMsg Autocomplete.Msg`), give that constructor to `view`, and
pass the messages you get back to `update`.
-}
type Msg
    = Input (Popup.Env String) Int String
    | Blurred
    | Show (Popup.Env String)
    | Navigate VirtualList.Geometry (Maybe Int)
    | Hover Int
    | Pick (Option String)
    | Commit (Popup.Env String)
    | Close
    | Clear
    | ListMsg VirtualList.Msg
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

With `suggestions`, compare `Autocomplete.text` before and after to see when to
fetch.

-}
update : Msg -> State -> ( State, Cmd Msg )
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
                }
            , if state.open then
                Cmd.map ListMsg scroll

              else
                Cmd.none
            )

        Blurred ->
            ( State { state | open = False, highlighted = Nothing }, Cmd.none )

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
            ( State { state | text = opt.label, picked = Just opt.value, open = False, highlighted = Nothing }, Cmd.none )

        Commit env ->
            let
                exact =
                    if String.isEmpty (String.trim state.text) then
                        Nothing

                    else
                        env.options
                            |> List.filter (\opt -> not opt.disabled && Match.isExactMatch state.text opt)
                            |> List.head
            in
            ( State
                { state
                    | open = False
                    , highlighted = Nothing
                    , picked = Maybe.map .value exact
                }
            , Cmd.none
            )

        Close ->
            ( State { state | open = False, highlighted = Nothing }, Cmd.none )

        Clear ->
            ( State { state | text = "", picked = Nothing, open = False, highlighted = Nothing }
            , Internal.focus state.id NoOp
            )

        ListMsg inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner state.list
            in
            ( State { state | list = list }, Cmd.map ListMsg cmd )

        NoOp ->
            ( current, Cmd.none )



-- ATTRIBUTES


{-| A setting of an autocomplete. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type Source
    = Local (List (Option String))
    | FromApp (Remote (List (Option String)))


type alias Config msg =
    { field : Field.Config
    , source : Source
    , freshness : Freshness
    , zone : Time.Zone
    , placeholder : String
    , minChars : Int
    , clearable : Bool
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , visibleRows : Int
    , prefixIcon : Maybe Icon
    , locale : Locale
    , onRetry : Maybe msg
    , onEnter : Maybe msg
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , source = Local []
        , freshness = Freshness.Fresh
        , zone = Time.utc
        , placeholder = ""
        , minChars = 1
        , clearable = False
        , disabled = False
        , readOnly = False
        , size = Medium
        , visibleRows = 8
        , prefixIcon = Nothing
        , locale = Locale.default
        , onRetry = Nothing
        , onEnter = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| Suggestions that the component filters itself as the user types: best match
first, ignoring case and diacritics, with several words that must all match, in
labels, descriptions and keywords (the scoring of [Klar.Search](Klar-Search), see
[Klar.Select.Option](Klar-Select-Option)). The list is hidden while nothing
matches. The default is no suggestions. Use `options` or `suggestions`, not both:
the later one wins.

    Autocomplete.options (List.map (\name -> Select.option name name) cities)

-}
options : List (Option String) -> Attribute msg
options list =
    Attribute (\config -> { config | source = Local list, freshness = Freshness.Fresh })


{-| Suggestions from the application, usually the backend, as a `Remote` (see
[Klar.Remote](Klar-Remote)). They are shown exactly as they come and the
component does not filter them; the typed text is highlighted in them. Fetch
when `Autocomplete.text` changes. The list is hidden while the data is
`NotAsked`, shows loading rows (and a spinner in the field) while `Loading`, an
error on `Failed` (see `onRetry`), and "No suggestions" on `Loaded []`.
Suggestions that are `Kept` stay in the list: dimmed and busy while they are
refreshed, and with "Old data from 14:05" at the top of the list when the last
refresh failed (the list is not a place for a button: the focus stays in the
field, so use the notice of the page for the retry).

    Autocomplete.suggestions model.citySuggestions

-}
suggestions : Remote (List (Option String)) -> Attribute msg
suggestions data =
    let
        ( current, freshness ) =
            Freshness.settle data
    in
    Attribute (\config -> { config | source = FromApp current, freshness = freshness })


{-| The time zone of the time in "Old data from 14:05". The default is UTC.
-}
zone : Time.Zone -> Attribute msg
zone value_ =
    Attribute (\config -> { config | zone = value_ })


{-| The message to send when the user presses the "Try again" button of the error
shown when `suggestions` failed. The button appears only for problems that are
worth retrying (network trouble, timeouts, server errors); while it is shown,
Enter in the field sends the message as well. For other problems (no access, not
found ...) nothing is retried, and Enter keeps the typed text as usual.

    Autocomplete.onRetry ReloadCities

-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The message to send when the user presses Enter and no suggestion is
highlighted, so the typed text is kept (to run a search for it, for example). It
arrives after the component has updated `picked`, so you can read
`Autocomplete.text` and `Autocomplete.picked` in your handler. Picking a
suggestion is a state change instead: compare `Autocomplete.picked` before and
after to react to it.

    Autocomplete.onEnter SearchSubmitted

-}
onEnter : msg -> Attribute msg
onEnter msg =
    Attribute (\config -> { config | onEnter = Just msg })


{-| The label above the field. It names the input for screen readers.
-}
label : String -> Attribute msg
label value_ =
    updateField (Field.setLabel value_)


{-| Keeps the label for screen readers but does not draw it. Use it when the
surroundings already name the field, as in a toolbar or a table cell. It needs a
`label`.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text under the field. Screen readers read it with the field
(`aria-describedby`).
-}
hint : String -> Attribute msg
hint value_ =
    updateField (Field.setHint value_)


{-| Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.
It is safe to set it while the user types: the input keeps its place in the
page, and so its keyboard focus, whether or not there is a label or a hint.
-}
error : String -> Attribute msg
error value_ =
    updateField (Field.setError (Just value_))


{-| Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

    Autocomplete.errorMaybe model.cityError

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` for screen readers. It does not validate anything; show a
problem with `error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| A text after the label of a field that is not `required`, such as
"(optional)". Required fields show no such text.
-}
optionalText : String -> Attribute msg
optionalText value_ =
    updateField (Field.setOptionalText value_)


{-| The text shown in the empty field. There is none by default.
-}
placeholder : String -> Attribute msg
placeholder value_ =
    Attribute (\config -> { config | placeholder = value_ })


{-| How many characters the user has to type before suggestions appear. The
default is 1, and spaces at the ends do not count. ArrowDown opens the list
whatever the length.
-}
minChars : Int -> Attribute msg
minChars n =
    Attribute (\config -> { config | minChars = max 0 n })


{-| Shows a small × that empties the field, closes the list and returns focus to
the field. It is shown only while the field has text.
-}
clearable : Attribute msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| While `True` the field is dimmed and cannot be focused or edited. The text
is kept. Pass a field of your model, for example while a form is saving. The
default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the field shows its text but does not let the user change it,
and no suggestions are shown. Unlike `disabled`, a read-only field can be focused
and its text selected. The default is `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar-Theme). The default is `Medium`.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| How many suggestions show before the list scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range. Group headings take a
row each.
-}
visibleRows : Int -> Attribute msg
visibleRows n =
    Attribute (\config -> { config | visibleRows = clamp 3 20 n })


{-| An icon at the start of the field, such as a magnifying glass. There is none
by default.

    Autocomplete.prefixIcon Icon.search

-}
prefixIcon : Icon -> Attribute msg
prefixIcon icon =
    Attribute (\config -> { config | prefixIcon = Just icon })


{-| The language of the built-in text: "No suggestions", "Loading ...", the
suggestion count for screen readers, the "Clear search" label and the error
state. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar-Locale).

    Autocomplete.locale Locale.nb

-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


type Content
    = Hidden
    | Rows (Popup.Rows String)
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
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
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
                    { options = Remote.withDefault [] data, filterLocally = False, creatable = False }

        rows () =
            Popup.cachedRows state.cache env state.text

        loadedContent () =
            let
                built =
                    rows ()
            in
            if built.optionRows == 0 then
                NoSuggestions

            else
                Rows built

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

                            Remote.Loaded [] ->
                                NoSuggestions

                            Remote.Loaded _ ->
                                loadedContent ()

                            Remote.Kept _ ->
                                -- settled when it was given: never here
                                loadedContent ()

        -- What Enter and Tab do on a failure depends on whether a "Try again"
        -- button is on screen: the problem must be worth retrying and the
        -- application must have said what retrying means.
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

        keys =
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
                        { handled = moves ++ [ ( "Escape", toMsg Close ) ]
                        , passive = [ ( "Tab", toMsg Close ), ( "Enter", toMsg (Commit env) ) ]
                        }

                Hidden ->
                    Popup.onKeydown
                        { handled =
                            if interactive && hasSomething config then
                                [ ( "ArrowDown", toMsg (Show env) ) ]

                            else
                                []
                        , passive = [ ( "Enter", toMsg (Commit env) ) ]
                        }

                Failed _ ->
                    case retry of
                        Just retryMsg ->
                            -- the retry button is for the mouse; Enter retries, and Tab
                            -- closes the list first so focus does not land in it
                            Popup.onKeydown
                                { handled = [ ( "Escape", toMsg Close ), ( "Enter", retryMsg ), ( "Tab", toMsg Close ) ]
                                , passive = []
                                }

                        Nothing ->
                            Popup.onKeydown
                                { handled = [ ( "Escape", toMsg Close ) ]
                                , passive = [ ( "Tab", toMsg Close ), ( "Enter", toMsg (Commit env) ) ]
                                }

                _ ->
                    Popup.onKeydown
                        { handled = [ ( "Escape", toMsg Close ) ]
                        , passive = [ ( "Tab", toMsg Close ), ( "Enter", toMsg (Commit env) ) ]
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
            , Internal.attrMaybe (\msg -> Internal.onKeysPassive [ ( "Enter", msg ) ]) config.onEnter
            ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Theme.sizeSuffix config.size
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
                           , Internal.attrIf hasListbox (Attr.attribute "aria-controls" (listboxId state.id))
                           , Internal.attrMaybe (\index -> Attr.attribute "aria-activedescendant" (Popup.optionId state.id index)) highlighted
                           , Internal.attrIf isBusy (Attr.attribute "aria-busy" "true")
                           , Attr.attribute "autocomplete" "off"
                           , Attr.spellcheck False
                           , Events.onInput (Input env config.minChars >> toMsg)
                           , Events.onBlur (toMsg Blurred)
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
            , viewPopup toMsg config t state.id state.list highlighted state.text retry content
            ]
        )


hasSomething : Config msg -> Bool
hasSomething config =
    case config.source of
        Local list ->
            not (List.isEmpty list)

        FromApp data ->
            data /= NotAsked


viewPopup : (Msg -> msg) -> Config msg -> Popup.Texts -> String -> VirtualList.State -> Maybe Int -> String -> Maybe msg -> Content -> Html msg
viewPopup toMsg config t id list highlighted query retry content =
    let
        popup children =
            Html.div
                [ Internal.cls [ "klar-popup", "klar-select__popup", "klar-select__popup--suggest", Freshness.className config.freshness ]
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
                    , refocus = toMsg NoOp
                    , leave = toMsg Close
                    , noop = toMsg NoOp
                    }
                    problem
                ]

        NoSuggestions ->
            popup [ Popup.viewMessage t.noSuggestions ]

        Rows rows ->
            let
                rowConfig =
                    { idBase = id
                    , query = query
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
                    { locale = config.locale, zone = config.zone, onRetry = Nothing, inline = False }
                    config.freshness
                , if rows.grouped then
                    VirtualList.viewGrouped (ListMsg >> toMsg)
                        listAttributes
                        { items = rows.rows, viewRow = Popup.viewRow rowConfig, viewHeader = Popup.viewPinned }
                        list

                  else
                    VirtualList.view (ListMsg >> toMsg)
                        listAttributes
                        { items = rows.rows, viewRow = Popup.viewRow rowConfig }
                        list
                ]
