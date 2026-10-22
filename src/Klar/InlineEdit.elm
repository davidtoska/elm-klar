module Klar.InlineEdit exposing
    ( view, Attribute
    , State, Msg, init, update
    , value, isEditing, isSaving, isFailed, pending
    , saved, failed, setValue
    , label, placeholder, emptyText
    , validate, maxLength
    , disabled
    , locale
    )

{-| Click-to-edit text. In reading mode it looks like text (with a pencil on
hover); a click turns it into an input.

    import Klar.InlineEdit as InlineEdit
    import Klar.Locale as Locale
    import Klar.Validate as Validate

    type alias Model =
        { customerName : InlineEdit.State }

    init : Model
    init =
        { customerName = InlineEdit.init "customer-name" "Ada Lovelace" }

    -- update
    CustomerNameMsg inner ->
        let
            ( customerName, cmd ) =
                InlineEdit.update inner model.customerName

            startsSaving =
                InlineEdit.isSaving customerName
                    && not (InlineEdit.isSaving model.customerName)
        in
        ( { model | customerName = customerName }
        , Cmd.batch
            [ Cmd.map CustomerNameMsg cmd
            , case ( startsSaving, InlineEdit.pending customerName ) of
                ( True, Just text ) ->
                    saveCustomerName text

                _ ->
                    Cmd.none
            ]
        )

    CustomerNameSaved (Ok _) ->
        ( { model | customerName = InlineEdit.saved model.customerName }, Cmd.none )

    CustomerNameSaved (Err problem) ->
        -- problem : Klar.Remote.Problem
        ( { model | customerName = InlineEdit.failed problem model.customerName }, Cmd.none )

    -- view
    InlineEdit.view CustomerNameMsg
        [ InlineEdit.label "Customer name"
        , InlineEdit.validate (Validate.run Locale.en Validate.required)
        ]
        model.customerName

The first `String` given to `init` is the DOM id of the input that is shown while
editing, so there is no `id` attribute; the second is the text to show.

**Keyboard.** Enter saves, Escape cancels, leaving the field saves, and the text
is a button: Tab reaches it and Space or Enter starts editing.

**Saving.** When the user confirms a changed text, `isSaving` turns `True`: that
is the application's cue to send the new text (`pending`) to the backend. The
text keeps showing the new value with a spinner. When the backend answers, call
`saved` (the value is now `pending`) or `failed` with a
[Klar.Remote](Klar-Remote) `Problem`: the text is then shown with the problem,
a "Try again" button (which makes `isSaving` `True` again; left out when
`Remote.isRetryable` says the problem would fail the same way, such as a conflict
or a validation problem) and a "Cancel" button
(which goes back to the old value). Confirming the text unchanged saves nothing.

**Validation.** `validate` is checked when the user confirms; a message keeps
the input open and is shown under it.

**No field wrapper.** Unlike most inputs, this one is not built on the field
wrapper ([Klar.Field](Klar-Field)), so it has no visible label, hint, required
marker or `error` attribute. `label` is only the accessible name, and the
message of `validate` is shown under the input.

The built-in texts (the buttons, "Click to add", "Saving ...") follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# Reading the state

@docs value, isEditing, isSaving, isFailed, pending


# Saving

@docs saved, failed, setValue


# Label and texts

@docs label, placeholder, emptyText


# Rules

@docs validate, maxLength


# Behavior

@docs disabled


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem)



-- STATE


{-| The state of an inline edit: the saved text, the text being edited, and
where the user is in the cycle of reading, editing, saving and failing. Make one
with `init`, keep it in your model and give it to `view` and `update`.
-}
type State
    = State Fields


type alias Fields =
    { id : String
    , value : String
    , draft : String
    , mode : Mode
    , error : Maybe String
    , pending : Maybe String
    , problem : Maybe Problem
    }


type Mode
    = Reading
    | Editing
    | Saving
    | Failed


{-| Starts in reading mode with the given text. The first `String` is the DOM id
of the input shown while editing; it must be unique on the page. The second is
the text to show.

    InlineEdit.init "customer-name" "Ada Lovelace"

-}
init : String -> String -> State
init id initial =
    State
        { id = id
        , value = initial
        , draft = initial
        , mode = Reading
        , error = Nothing
        , pending = Nothing
        , problem = Nothing
        }


{-| The saved text: the one the field started with, or the last one confirmed
with `saved` or put there with `setValue`. While the user is editing, or a save
is on its way, it is still the old text; see `pending`.
-}
value : State -> String
value (State state) =
    state.value


{-| Shows this text as the saved text and goes back to reading mode, dropping
any edit, save in progress or failure. Use it when the text comes from
somewhere else, for example after the data was loaded again.
-}
setValue : String -> State -> State
setValue text (State state) =
    State
        { state
            | value = text
            , draft = text
            , mode = Reading
            , error = Nothing
            , pending = Nothing
            , problem = Nothing
        }


{-| `True` while the input is open for editing.
-}
isEditing : State -> Bool
isEditing (State state) =
    state.mode == Editing


{-| `True` from the moment a changed text is confirmed until `saved` or
`failed` is called, and again after the user chooses "Try again". Start the
save when this turns `True`: compare it before and after `update`.
-}
isSaving : State -> Bool
isSaving (State state) =
    state.mode == Saving


{-| `True` after `failed` until the user chooses "Try again" or "Cancel". The
text is shown with the problem and the two buttons.
-}
isFailed : State -> Bool
isFailed (State state) =
    state.mode == Failed


{-| The text waiting to be saved: the confirmed text while `isSaving`, and after
a failure until the user cancels. Otherwise `Nothing`.
-}
pending : State -> Maybe String
pending (State state) =
    state.pending


{-| The save went well: the pending text is now the value, and the field is back
in reading mode. Call it when the backend answers.
-}
saved : State -> State
saved (State state) =
    case state.pending of
        Just text ->
            setValue text (State state)

        Nothing ->
            State { state | mode = Reading }


{-| The save failed. The text is shown with "Could not save." and the `title` of
the problem, a "Try again" button (which makes `isSaving` `True` again, but only
when `Remote.isRetryable` allows it: not for a conflict or a validation problem,
which would fail the same way) and a
"Cancel" button that goes back to the old value. The `Problem` is from
[Klar.Remote](Klar-Remote); make one from your own error with `Remote.problem`.

    InlineEdit.failed (Remote.problem Remote.network) model.customerName

-}
failed : Problem -> State -> State
failed problem (State state) =
    State { state | mode = Failed, problem = Just problem }



-- UPDATE


type alias Rules =
    { validate : String -> Maybe String
    }


{-| The messages an inline edit sends: starting to edit, typing, confirming,
cancelling and the two buttons after a failure. `view` wraps them with the
function you give it; hand them to `update` when they come back.
-}
type Msg
    = StartEdit
    | Typed String
    | Confirm Rules
    | Cancel
    | Retry
    | Discard
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` moves the keyboard
focus (into the input when editing starts, back to the text when it ends), so
pass it on with `Cmd.map`. Compare `isSaving` before and after to find out when
to start a save.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        StartEdit ->
            if state.mode == Reading then
                ( State { state | mode = Editing, draft = state.value, error = Nothing }
                , Internal.focus state.id Noop
                )

            else
                ( State state, Cmd.none )

        Typed text ->
            ( State { state | draft = text, error = Nothing }, Cmd.none )

        Confirm rules ->
            if state.mode == Editing then
                let
                    candidate =
                        String.trim state.draft
                in
                case rules.validate candidate of
                    Just problem ->
                        ( State { state | error = Just problem }, Cmd.none )

                    Nothing ->
                        if candidate == state.value then
                            ( State { state | mode = Reading, draft = state.value, error = Nothing }
                            , Internal.focus (displayId state.id) Noop
                            )

                        else
                            ( State
                                { state
                                    | mode = Saving
                                    , draft = candidate
                                    , pending = Just candidate
                                    , error = Nothing
                                }
                            , Internal.focus (displayId state.id) Noop
                            )

            else
                ( State state, Cmd.none )

        Cancel ->
            if state.mode == Editing then
                ( State { state | mode = Reading, draft = state.value, error = Nothing }
                , Internal.focus (displayId state.id) Noop
                )

            else
                ( State state, Cmd.none )

        Retry ->
            if state.mode == Failed then
                -- the retry button goes away: keep focus on the text
                ( State { state | mode = Saving, problem = Nothing }
                , Internal.focus (displayId state.id) Noop
                )

            else
                ( State state, Cmd.none )

        Discard ->
            if state.mode == Failed then
                ( State { state | mode = Reading, draft = state.value, pending = Nothing, problem = Nothing }
                , Internal.focus (displayId state.id) Noop
                )

            else
                ( State state, Cmd.none )

        Noop ->
            ( State state, Cmd.none )


displayId : String -> String
displayId id =
    id ++ "-display"



-- ATTRIBUTES


{-| A setting of an inline edit. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { label : Maybe String
    , placeholder : String
    , emptyText : Maybe String
    , maxLength : Maybe Int
    , validate : String -> Maybe String
    , disabled : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing
        , placeholder = ""
        , emptyText = Nothing
        , maxLength = Nothing
        , validate = \_ -> Nothing
        , disabled = False
        , locale = Locale.default
        }
        attributes


{-| What the text is about, such as `"Customer name"`. It is not shown: it is the
accessible name of the input, and part of the name of the text button ("Edit
customer name: Ada Lovelace"). Give every inline edit one.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | label = Just text })


{-| Text shown inside the input while editing, when the input is empty. Default:
none.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\config -> { config | placeholder = text })


{-| Shown in gray in reading mode when the text is empty. Default "Click to add"
(see `locale`).

    InlineEdit.emptyText "No reference"

-}
emptyText : String -> Attribute msg
emptyText text =
    Attribute (\config -> { config | emptyText = Just text })


{-| Limits the text to this many characters (the HTML `maxlength` of the input).
There is no counter. Default: no limit.
-}
maxLength : Int -> Attribute msg
maxLength n =
    Attribute (\config -> { config | maxLength = Just n })


{-| Checked when the user confirms, with the text trimmed. Return `Just message`
to keep the input open and show the message under it (it goes away when the user
types again), or `Nothing` to go on and save. Default: every text is accepted.

    InlineEdit.validate
        (Validate.run Locale.en
            (Validate.all [ Validate.required, Validate.maxLength 60 ])
        )

-}
validate : (String -> Maybe String) -> Attribute msg
validate check =
    Attribute (\config -> { config | validate = check })


{-| While `True` the text is plain text: no pencil, no button, no editing.
Default `False`.

If the field becomes disabled while the input is open, the input stays on the
screen with the text typed so far, but it is inert. It is read-only, it is no
longer handled (leaving it, Enter, Escape and the two buttons do nothing), so
nothing is saved and nothing is cancelled. Editing goes on where it stopped when
the field is enabled again. The "Try again" and "Cancel" buttons after a failed
save are inactive as well while it is disabled.

-}
disabled : Bool -> Attribute msg
disabled flag =
    Attribute (\config -> { config | disabled = flag })


{-| The language of the built-in text: "Click to add", the accessible name "Edit
...", the "Save" and "Cancel" buttons, "Saving ...", "Could not save." and "Try
again". Default `Locale.default`, which is English. Texts you pass in yourself
are shown as they are.
-}
locale : Locale -> Attribute msg
locale lang =
    Attribute (\config -> { config | locale = lang })



-- VIEW


{-| The text, which turns into an input when the user clicks it. The first
argument wraps the field's own messages in one of yours, and the state comes
last.

    InlineEdit.view CustomerNameMsg
        [ InlineEdit.label "Customer name"
        , InlineEdit.emptyText "No name yet"
        ]
        model.customerName

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        rules =
            { validate = config.validate }
    in
    Html.div
        [ Internal.cls
            [ "klar-inline-edit"
            , case state.mode of
                Reading ->
                    ""

                Editing ->
                    "klar-inline-edit--editing"

                Saving ->
                    "klar-inline-edit--saving"

                Failed ->
                    "klar-inline-edit--failed"
            ]
        ]
        (case state.mode of
            Reading ->
                [ viewDisplay toMsg config state state.value ]

            Editing ->
                viewEditor toMsg config rules state

            Saving ->
                [ viewDisplay toMsg config state (Maybe.withDefault state.value state.pending)
                , Html.span
                    [ Internal.cls [ "klar-inline-edit__saving" ]
                    , Attr.attribute "role" "status"
                    ]
                    [ Html.span [ Internal.cls [ "klar-spinner", "klar-spinner--sm" ], Attr.attribute "aria-hidden" "true" ] []
                    , Html.text (Locale.pick config.locale { nb = "Lagrer ...", en = "Saving ..." })
                    ]
                ]

            Failed ->
                viewFailure toMsg config state
        )


{-| The text as a button that starts editing. While saving and after a
failed save it stays (inactive) in the same place, so keyboard focus is not
lost when the input closes: Enter in the input moves focus here, and it stays
here through `saved` and `failed`.
-}
viewDisplay : (Msg -> msg) -> Config -> Fields -> String -> Html msg
viewDisplay toMsg config state text =
    let
        active =
            state.mode == Reading

        accessibleName =
            Locale.pick config.locale { nb = "Rediger", en = "Edit" }
                ++ (case config.label of
                        Just name ->
                            " " ++ String.toLower name

                        Nothing ->
                            ""
                   )
                ++ ": "
                ++ (if text == "" then
                        emptyLabel config

                    else
                        text
                   )
    in
    if config.disabled then
        viewStatic config text

    else
        Html.button
            [ Internal.cls
                [ "klar-inline-edit__display"
                , if active then
                    ""

                  else
                    "klar-inline-edit__display--busy"
                ]
            , Attr.type_ "button"
            , Attr.id (displayId state.id)
            , Attr.attribute "aria-label" accessibleName
            , if active then
                Events.onClick (toMsg StartEdit)

              else
                Attr.attribute "aria-disabled" "true"
            ]
            [ staticText config text
            , Internal.viewIf active
                (Html.span [ Internal.cls [ "klar-inline-edit__pencil" ], Attr.attribute "aria-hidden" "true" ]
                    [ Icon.view Icon.edit ]
                )
            ]


viewStatic : Config -> String -> Html msg
viewStatic config text =
    Html.span [ Internal.cls [ "klar-inline-edit__static" ] ] [ staticText config text ]


staticText : Config -> String -> Html msg
staticText config text =
    if text == "" then
        Html.span [ Internal.cls [ "klar-inline-edit__text", "klar-inline-edit__text--empty" ] ]
            [ Html.text (emptyLabel config) ]

    else
        Html.span [ Internal.cls [ "klar-inline-edit__text" ] ] [ Html.text text ]


emptyLabel : Config -> String
emptyLabel config =
    config.emptyText
        |> Maybe.withDefault (Locale.pick config.locale { nb = "Klikk for å legge til", en = "Click to add" })


viewEditor : (Msg -> msg) -> Config -> Rules -> Fields -> List (Html msg)
viewEditor toMsg config rules state =
    let
        errorId =
            state.id ++ "-error"

        saveLabel =
            Locale.pick config.locale { nb = "Lagre", en = "Save" }

        cancelLabel =
            Locale.pick config.locale { nb = "Avbryt", en = "Cancel" }

        -- An editor that is already open when the field becomes disabled is
        -- inert: the input is read-only, not disabled (a disabled input that has
        -- the focus drops it to the page), and nothing is handled any more, so
        -- leaving it, Enter, Escape and the buttons save and cancel nothing. The
        -- text typed so far stays, and editing goes on when it is enabled again.
        active =
            not config.disabled
    in
    [ Html.div
        [ Internal.cls
            [ "klar-input"
            , "klar-input--sm"
            , "klar-inline-edit__box"
            , if state.error /= Nothing then
                "klar-input--invalid"

              else
                ""
            , if config.disabled then
                "klar-input--disabled"

              else
                ""
            ]
        ]
        [ Html.input
            [ Internal.cls [ "klar-input__control" ]
            , Attr.type_ "text"
            , Attr.id state.id
            , Attr.value state.draft
            , Attr.placeholder config.placeholder
            , Internal.attrMaybe Attr.maxlength config.maxLength
            , Internal.attrMaybe (Attr.attribute "aria-label") config.label
            , Internal.attrIf (state.error /= Nothing) (Attr.attribute "aria-invalid" "true")
            , Internal.attrIf (state.error /= Nothing) (Attr.attribute "aria-describedby" errorId)
            , Internal.attrIf config.disabled (Attr.attribute "aria-disabled" "true")
            , Attr.readonly config.disabled
            , Attr.attribute "autocomplete" "off"
            , Internal.attrIf active (Events.onInput (\text -> toMsg (Typed text)))
            , Internal.attrIf active (Events.onBlur (toMsg (Confirm rules)))
            , Internal.attrIf active (Events.preventDefaultOn "keydown" (keyDecoder toMsg rules))
            ]
            []
        , Html.button
            [ Internal.cls [ "klar-inline-edit__action", "klar-inline-edit__action--save" ]
            , Attr.type_ "button"
            , Attr.tabindex -1
            , Attr.attribute "aria-label" saveLabel
            , Attr.title saveLabel
            , Attr.disabled config.disabled
            , Internal.onMouseDownPrevent (toMsg Noop)
            , Internal.attrIf active (Events.onClick (toMsg (Confirm rules)))
            ]
            [ Icon.view Icon.check ]
        , Html.button
            [ Internal.cls [ "klar-inline-edit__action" ]
            , Attr.type_ "button"
            , Attr.tabindex -1
            , Attr.attribute "aria-label" cancelLabel
            , Attr.title cancelLabel
            , Attr.disabled config.disabled
            , Internal.onMouseDownPrevent (toMsg Noop)
            , Internal.attrIf active (Events.onClick (toMsg Cancel))
            ]
            [ Icon.view Icon.close ]
        ]
    , case state.error of
        Just message ->
            Html.p
                [ Internal.cls [ "klar-field__error", "klar-inline-edit__error" ]
                , Attr.id errorId
                , Attr.attribute "role" "alert"
                ]
                [ Html.text message ]

        Nothing ->
            Html.text ""
    ]


viewFailure : (Msg -> msg) -> Config -> Fields -> List (Html msg)
viewFailure toMsg config state =
    let
        -- A conflict or a validation problem fails the same way again.
        retryable =
            state.problem |> Maybe.map Remote.isRetryable |> Maybe.withDefault True
    in
    [ viewDisplay toMsg config state (Maybe.withDefault state.value state.pending)
    , Html.div
        [ Internal.cls [ "klar-inline-edit__failure" ]
        , Attr.attribute "role" "alert"
        ]
        [ Html.span [ Internal.cls [ "klar-inline-edit__failure-icon" ] ] [ Icon.view Icon.errorCircle ]
        , Html.span [ Internal.cls [ "klar-inline-edit__failure-text" ] ]
            [ Html.text
                (Locale.pick config.locale { nb = "Kunne ikke lagre. ", en = "Could not save. " }
                    ++ (state.problem |> Maybe.map (Remote.title config.locale) |> Maybe.withDefault "")
                )
            ]
        , if retryable then
            Button.view [ Button.small, Button.disabled config.disabled, Button.onClick (toMsg Retry) ]
                (Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" })

          else
            Html.text ""
        , Button.view [ Button.small, Button.ghost, Button.disabled config.disabled, Button.onClick (toMsg Discard) ]
            (Locale.pick config.locale { nb = "Avbryt", en = "Cancel" })
        ]
    ]


keyDecoder : (Msg -> msg) -> Rules -> Decode.Decoder ( msg, Bool )
keyDecoder toMsg rules =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt then
                    Decode.fail "modifier"

                else
                    case event.key of
                        "Enter" ->
                            Decode.succeed ( toMsg (Confirm rules), True )

                        "Escape" ->
                            Decode.succeed ( toMsg Cancel, True )

                        _ ->
                            Decode.fail "unhandled key"
            )
