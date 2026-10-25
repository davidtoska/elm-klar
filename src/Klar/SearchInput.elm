module Klar.SearchInput exposing
    ( view, Attribute
    , State, Msg, init, update
    , value, committed, isPending
    , setValue, clear
    , debounce
    , label, labelHidden, ariaLabel, hint, error, errorMaybe, optionalText
    , placeholder, shortcut, remote, size, disabled, name
    , locale
    )

{-| A search field that waits until the user stops typing.

Use when: a list is searched as the user types (a request to a server, say) and you want one message when the typing pauses.
Do not use when: you need an ordinary text field (use `Klar.TextInput`), a list that is filtered in the browser at every keystroke (use `TextInput.search`) or suggestions to pick from (use `Klar.Autocomplete`).
Quick path: `init`, `update`, `view`, `committed`

    import Klar.Remote as Remote exposing (Remote)
    import Klar.SearchInput as SearchInput
    import Klar.Shortcut as Shortcut

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

    OrdersFound query result ->
        -- an answer to an older search can come after the newest one: drop it
        if query == SearchInput.committed model.search then
            ( { model | orders = Remote.fromResult result }, Cmd.none )

        else
            ( model, Cmd.none )

    -- view
    SearchInput.view SearchMsg
        [ SearchInput.placeholder "Search orders ..."
        , SearchInput.shortcut (Shortcut.char '/')
        , SearchInput.remote model.orders
        ]
        model.search

**Debounce without ports.** The state holds two texts: `value`, what is in the
field right now, and `committed`, the text the application should search for.
Every keystroke starts a short timer (`debounce`, 300 ms) and remembers a
counter; when the timer fires only the last keystroke is still current, and
only then is `committed` set to `value`, without the spaces at its ends (so a
space typed at the end starts no new search). Enter commits at once, and the
clear button (or Escape) empties and commits at once. The application starts a
search when `committed` differs from before `update`. The timer is a `Cmd`
returned by `update`, so pass it on with `Cmd.map`: if it is dropped, typed text
is never committed. While an input method (Chinese, Japanese, Korean) composes
a word, nothing is committed; the timer starts when the word is confirmed.

**Keyboard and accessibility.** Enter commits the text and never submits a
surrounding form. Escape clears a field that has text and is then kept from
closing a dialog around the field (its default is prevented); in an empty field
the key is left alone, so it can close the dialog. A search field usually has
no visible `label`, so give it an `ariaLabel` (the default is "Search"). While
the `remote` is loading or refreshing, a spinner shows in the field and screen
readers hear "Searching ...".

`shortcut` only draws the key in the field: bind the key itself with
[Klar.Shortcut](Klar-Shortcut), with the same `Shortcut.Keys`, and move the
cursor into the field with `Klar.focus` and the id given to `init`.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe` and `optionalText` are the
common field attributes. They come with the field wrapper
([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they mean the
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


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# Reading the search

@docs value, committed, isPending


# Changing the search from the application

@docs setValue, clear


# Timing

@docs debounce


# Label, hint and error

@docs label, labelHidden, ariaLabel, hint, error, errorMaybe, optionalText


# Appearance and behavior

@docs placeholder, shortcut, remote, size, disabled, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.TextField as TextField
import Klar.Kbd as Kbd
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Shortcut as Shortcut
import Klar.Spinner as Spinner
import Klar.Theme as Theme exposing (Size(..))
import Process
import Task



-- STATE


{-| The state of a search field: the text in the field and the text to search
for. Make one with `init`, keep it in your model and give it to `view` and
`update`.
-}
type State
    = State
        { id : String
        , text : String
        , committed : String
        , version : Int
        }


{-| An empty search field. The `String` is the DOM id of the input; it must be
unique on the page, because the label points at it, and it is the id to give
`Klar.focus`.
-}
init : String -> State
init id =
    State { id = id, text = "", committed = "", version = 0 }


{-| What is in the field right now, including text that is not committed yet.
-}
value : State -> String
value (State state) =
    state.text


{-| The text to search for: `value` after the user paused (or pressed Enter),
without the spaces at its ends. Compare it before and after `update` to know
when to start a search.
-}
committed : State -> String
committed (State state) =
    state.committed


{-| `True` while the text in the field differs from the committed text: the user
has typed something and the pause is not over yet.
-}
isPending : State -> Bool
isPending (State state) =
    String.trim state.text /= state.committed


{-| Puts a text in the field and commits it at once, for example a search
restored from the address. A pause timer that is still running is ignored.
-}
setValue : String -> State -> State
setValue given (State state) =
    State { state | text = given, committed = String.trim given, version = state.version + 1 }


{-| Empties the field and commits the empty text.
-}
clear : State -> State
clear =
    setValue ""



-- UPDATE


{-| The messages a search field sends: typing, the pause timer, Enter and the
clear button. `view` wraps them with the function you give it; hand them to
`update` when they come back.
-}
type Msg
    = Typed Int String
    | Composing String
    | Pause Int
    | CommitNow
    | Cleared
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` holds the pause
timer and the focus after the clear button, so pass it on with `Cmd.map`: if it
is dropped, typed text is never committed (Enter still commits).
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Typed delay given ->
            let
                version =
                    state.version + 1
            in
            if delay <= 0 then
                ( State { state | text = given, committed = String.trim given, version = version }, Cmd.none )

            else
                ( State { state | text = given, version = version }
                , Process.sleep (toFloat delay)
                    |> Task.perform (\_ -> Pause version)
                )

        Composing given ->
            -- not final yet: no timer, and the one of the last keystroke is stale
            ( State { state | text = given, version = state.version + 1 }, Cmd.none )

        Pause version ->
            -- Only the timer of the last keystroke commits.
            if version == state.version then
                ( State { state | committed = String.trim state.text }, Cmd.none )

            else
                ( State state, Cmd.none )

        CommitNow ->
            ( State { state | committed = String.trim state.text, version = state.version + 1 }, Cmd.none )

        Cleared ->
            ( State { state | text = "", committed = "", version = state.version + 1 }
            , Internal.focus state.id Noop
            )

        Noop ->
            ( State state, Cmd.none )



-- ATTRIBUTES


{-| A setting of a search field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , ariaLabel : Maybe String
    , placeholder : Maybe String
    , debounce : Int
    , shortcut : Maybe Shortcut.Keys
    , busy : Bool
    , disabled : Bool
    , size : Size
    , name : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , ariaLabel = Nothing
        , placeholder = Nothing
        , debounce = 300
        , shortcut = Nothing
        , busy = False
        , disabled = False
        , size = Medium
        , name = Nothing
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label shown above the field. It is connected to the input, so clicking
it focuses the input and screen readers read it as the name of the input. A
search field usually has no visible label: then give it an `ariaLabel` (the
default is "Search").
-}
label : String -> Attribute msg
label given =
    updateField (Field.setLabel given)


{-| Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| The accessible name of the input when the field has no `label`. It is not
shown. Default "Search" (see `locale`). It is ignored when there is a `label`.

    SearchInput.ariaLabel "Search products"

-}
ariaLabel : String -> Attribute msg
ariaLabel given =
    Attribute (\config -> { config | ariaLabel = Just given })


{-| Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).
-}
hint : String -> Attribute msg
hint given =
    updateField (Field.setHint given)


{-| Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`.
-}
error : String -> Attribute msg
error given =
    updateField (Field.setError (Just given))


{-| Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Text such as `"(optional)"` shown after the `label`. By default nothing is
shown. A search field has no `required` attribute, so the text is shown whenever
there is a label.
-}
optionalText : String -> Attribute msg
optionalText given =
    updateField (Field.setOptionalText given)


{-| Text shown inside the empty field, for example `"Search orders ..."`. It is
not a substitute for an accessible name (see `ariaLabel`), and it disappears as
soon as the user types. Default: none.
-}
placeholder : String -> Attribute msg
placeholder given =
    Attribute (\config -> { config | placeholder = Just given })


{-| Milliseconds to wait after the last keystroke before the text is committed.
Default 300; 0 (or less) commits on every keystroke.

    SearchInput.debounce 500

-}
debounce : Int -> Attribute msg
debounce milliseconds =
    Attribute (\config -> { config | debounce = milliseconds })


{-| Draws the key caps of a shortcut, such as `/` or `Ctrl K`, at the end of the
field while it is empty, not busy and not `disabled`. Give it the same
`Shortcut.Keys` that [Klar.Shortcut](Klar-Shortcut) listens to, so that the hint
and the binding cannot disagree. It is only a picture, hidden from screen
readers: bind the key with `Klar.Shortcut` and move the cursor into the field
with `Klar.focus`.

    SearchInput.shortcut (Shortcut.char '/')

-}
shortcut : Shortcut.Keys -> Attribute msg
shortcut keys =
    Attribute (\config -> { config | shortcut = Just keys })


{-| The results of the search, as your model has them: while they are loading,
and while results that are shown are being refreshed, a small spinner shows in
the field and screen readers hear "Searching ...". Default: no spinner.

    SearchInput.remote model.orders

-}
remote : Remote a -> Attribute msg
remote results =
    Attribute (\config -> { config | busy = Remote.isLoading results || Remote.isRefreshing results })


{-| While `True` the field is dimmed and cannot be focused or changed, and the
clear button is hidden. Default `False`.
-}
disabled : Bool -> Attribute msg
disabled given =
    Attribute (\config -> { config | disabled = given })


{-| The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px) at the default density (see `Klar.Theme` for the others), from
[Klar.Theme](Klar-Theme). Default `Medium`.
-}
size : Size -> Attribute msg
size given =
    Attribute (\config -> { config | size = given })


{-| The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.
-}
name : String -> Attribute msg
name given =
    Attribute (\config -> { config | name = Just given })


{-| The language of the built-in text: the default accessible name ("Search"),
the clear button ("Clear search") and what screen readers hear while the search
runs ("Searching ..."). Default `Locale.default`, which is English. Texts you
pass in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale given =
    Attribute (\config -> { config | locale = given })



-- VIEW


{-| A search field with a magnifying glass and a clear button. The first
argument wraps the field's own messages in one of yours, and the state comes
last.

    SearchInput.view SearchMsg
        [ SearchInput.ariaLabel "Search products"
        , SearchInput.debounce 400
        ]
        model.search

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        field =
            Field.setId state.id config.field

        hasText =
            state.text /= ""

        showClear =
            hasText && not config.disabled

        showKeys =
            case config.shortcut of
                Just _ ->
                    not hasText && not config.busy && not config.disabled

                Nothing ->
                    False

        name_ =
            case ( field.label, config.ariaLabel ) of
                ( Nothing, Just given ) ->
                    Just given

                ( Nothing, Nothing ) ->
                    Just (Locale.pick config.locale { nb = "Søk", en = "Search" })

                _ ->
                    Nothing
    in
    -- stable: the application may show an error while the user types, and the
    -- input must not move into the wrapper then (it would lose the focus)
    Field.view field
        (Html.div
            [ Internal.cls
                [ "klar-input"
                , "klar-input--" ++ Internal.sizeSuffix config.size
                , "klar-search"
                , if field.error /= Nothing then
                    "klar-input--invalid"

                  else
                    ""
                , if config.disabled then
                    "klar-input--disabled"

                  else
                    ""
                ]
            ]
            [ Html.span [ Internal.cls [ "klar-input__adornment", "klar-input__prefix" ] ] [ Icon.view Icon.search ]
            , Html.input
                (Field.controlAttributes field
                    ++ [ Internal.cls [ "klar-input__control", "klar-search__control" ]
                       , Attr.type_ "search"
                       , Attr.value state.text
                       , Internal.attrMaybe Attr.placeholder config.placeholder
                       , Attr.disabled config.disabled
                       , Attr.attribute "autocomplete" "off"
                       , Attr.attribute "autocapitalize" "off"
                       , Attr.attribute "spellcheck" "false"
                       , Attr.attribute "enterkeyhint" "search"
                       , Internal.attrMaybe (Attr.attribute "aria-label") name_
                       , Internal.attrMaybe Attr.name config.name
                       , Events.on "input" (inputDecoder toMsg config.debounce)
                       , Events.on "compositionend" (Decode.map (\given -> toMsg (Typed config.debounce given)) targetValue)
                       , Events.preventDefaultOn "keydown" (keyDecoder toMsg hasText)
                       ]
                )
                []
            , if config.busy then
                Html.span [ Internal.cls [ "klar-search__spinner" ] ]
                    [ Spinner.view [ Spinner.size Small, Spinner.label "" ] ]

              else
                Html.text ""
            , if showClear then
                Html.button
                    [ Internal.cls [ "klar-input__clear" ]
                    , Attr.type_ "button"
                    , Attr.tabindex -1
                    , Attr.attribute "aria-label" (Locale.pick config.locale { nb = "Tøm søket", en = "Clear search" })
                    , Attr.title (Locale.pick config.locale { nb = "Tøm søket", en = "Clear search" })
                    , Internal.onMouseDownPrevent (toMsg Noop)
                    , Events.onClick (toMsg Cleared)
                    ]
                    [ Icon.view Icon.close ]

              else
                Html.text ""
            , case ( showKeys, config.shortcut ) of
                ( True, Just keys ) ->
                    Html.span [ Internal.cls [ "klar-search__keys" ], Attr.attribute "aria-hidden" "true" ]
                        [ Kbd.view [ Kbd.small, Kbd.locale config.locale ] keys ]

                _ ->
                    Html.text ""

            -- always there, so that "Searching ..." is read out the first time too
            , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                [ Html.text
                    (if config.busy then
                        Locale.pick config.locale { nb = "Søker ...", en = "Searching ..." }

                     else
                        ""
                    )
                ]
            ]
        )


targetValue : Decoder String
targetValue =
    Decode.at [ "target", "value" ] Decode.string


inputDecoder : (Msg -> msg) -> Int -> Decoder msg
inputDecoder toMsg delay =
    Decode.map2
        (\isComposing given ->
            if isComposing then
                toMsg (Composing given)

            else
                toMsg (Typed delay given)
        )
        TextField.composing
        targetValue


keyDecoder : (Msg -> msg) -> Bool -> Decoder ( msg, Bool )
keyDecoder toMsg hasText =
    Decode.map2 Tuple.pair TextField.composing Internal.keyEvent
        |> Decode.andThen
            (\( isComposing, event ) ->
                if isComposing then
                    -- Enter confirms the composed word, Escape cancels it
                    Decode.fail "composing"

                else if event.ctrl || event.meta || event.alt then
                    Decode.fail "modifier"

                else
                    case event.key of
                        "Enter" ->
                            Decode.succeed ( toMsg CommitNow, True )

                        "Escape" ->
                            if hasText then
                                -- prevented, so that a dialog around the field
                                -- knows the key was used and stays open
                                Decode.succeed ( toMsg Cleared, True )

                            else
                                Decode.fail "nothing to clear"

                        _ ->
                            Decode.fail "unhandled key"
            )
