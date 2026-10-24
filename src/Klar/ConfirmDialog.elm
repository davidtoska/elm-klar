module Klar.ConfirmDialog exposing
    ( view
    , State, Msg, init, update, isOpen, isBusy, problem
    , open, setBusy, setFailed, clearFailure, close
    , Attribute, title, message, body, consequences
    , tone, neutral, warning, danger, icon
    , confirmLabel, cancelLabel, confirmDisabled, typeToConfirm, ignoreCase
    , onConfirm, onCancel
    , locale
    )

{-| The "are you sure?" dialog, with the whole life of the request it guards.

Use when: the user must confirm an action that is hard to undo or that affects others, such as deleting an order or canceling a shipment.
Do not use when: the dialog is a form with several fields to fill in (use `Klar.Modal`); one or two controls in `body`, such as a reason or a target to choose, are fine.
Quick path: `init`, `open`, `update`, `view`, `setBusy`, `close`

The life of a request:

    idle  -->  busy  -->  closed          (success)
                 \--->  failed  -->  busy ...   (retry)

The dialog is a small [Klar.Modal](Klar-Modal), so focus, `Escape`, the
backdrop, scroll locking and the page behind it behave as described there. The
application keeps the thing being confirmed (a row, an id) in its own model, and
decides when to close:

    import Klar.ConfirmDialog as ConfirmDialog

    -- model:   dialog : ConfirmDialog.State   (ConfirmDialog.init "delete-dialog")
    --          pending : Maybe Order

    -- update
    AskDelete order ->
        let
            ( dialog, cmd ) =
                ConfirmDialog.open "delete-button" model.dialog
        in
        ( { model | dialog = dialog, pending = Just order }, Cmd.map DialogMsg cmd )

    ConfirmDelete ->                                  -- onConfirm
        ( { model | dialog = ConfirmDialog.setBusy model.dialog }, deleteRequest model.pending )

    Deleted (Ok _) ->
        closeDialog model

    Deleted (Err problem) ->
        ( { model | dialog = ConfirmDialog.setFailed problem model.dialog }, Cmd.none )

    CancelDelete ->                                   -- onCancel
        closeDialog model

    DialogMsg m ->
        let
            ( dialog, cmd ) =
                ConfirmDialog.update m model.dialog
        in
        ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )

    -- a helper for the two branches that close the dialog
    closeDialog : Model -> ( Model, Cmd Msg )
    closeDialog model =
        let
            ( dialog, cmd ) =
                ConfirmDialog.close model.dialog
        in
        ( { model | dialog = dialog, pending = Nothing }, Cmd.map DialogMsg cmd )

    -- view
    ConfirmDialog.view DialogMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.title "Delete order?"
        , ConfirmDialog.message "Order 1042 will be removed from all lists."
        , ConfirmDialog.consequences [ "3 open shipments are canceled" ]
        , ConfirmDialog.confirmLabel "Delete order"
        , ConfirmDialog.typeToConfirm "DELETE"
        , ConfirmDialog.onConfirm ConfirmDelete
        , ConfirmDialog.onCancel CancelDelete
        ]
        model.dialog

While the request runs the confirm button shows a spinner and nothing can close
the dialog (`Escape`, the backdrop and the close button are ignored). A failed
request shows the problem inside the dialog, with a "Try again" button when the
problem is worth retrying (see [`Remote.isRetryable`](Klar-Remote#isRetryable));
the dialog stays open and can be dismissed.

`onCancel` is sent for the cancel button, the close button, `Escape` and the
backdrop. Without it the dialog closes itself; either way it forgets the typed
text and the failure when it closes. While the request runs none of them sends
it. (An event from the frame before the dialog re-rendered as busy can still
slip through; if your `onCancel` handler closes the dialog, check
`ConfirmDialog.isBusy` first.)

Focus starts on the typed-confirmation field if there is one, otherwise on
"Cancel", so that a stray `Enter` never confirms a destructive action. The
built-in texts (the buttons, "Try again" and the label of the
typed-confirmation field) follow `locale`.


# View

@docs view


# State

@docs State, Msg, init, update, isOpen, isBusy, problem


# Opening, confirming and closing

@docs open, setBusy, setFailed, clearFailure, close


# Content

@docs Attribute, title, message, body, consequences


# Tone

@docs tone, neutral, warning, danger, icon


# Buttons and typed confirmation

@docs confirmLabel, cancelLabel, confirmDisabled, typeToConfirm, ignoreCase


# Messages

@docs onConfirm, onCancel


# Texts

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Modal as Modal
import Klar.Overlay exposing (Overlay)
import Klar.Remote as Remote exposing (Problem)
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Tone(..))



-- STATE


{-| The state of one confirmation dialog: whether it is open, the phase of the
request it guards (idle, busy or failed) and the text typed so far. Create it
with `init`, keep it in your model, and change it with `open`, `setBusy`,
`setFailed`, `close` and `update`.
-}
type State
    = State
        { id : String
        , modal : Modal.State
        , phase : Phase
        , typed : String
        }


type Phase
    = Idle
    | Busy
    | Failed Problem


{-| A closed dialog. The id must be unique on the page: it is the DOM id of the
dialog, and the ids of the parts inside it start with it.
-}
init : String -> State
init id =
    State { id = id, modal = Modal.init id, phase = Idle, typed = "" }


{-| Is the dialog open? The page behind it is made inert by the
[`Overlay`](Klar-Overlay#Overlay) the dialog returns, so you rarely need this.
-}
isOpen : State -> Bool
isOpen (State state) =
    Modal.isOpen state.modal


{-| `True` while the request runs: from `setBusy` until `setFailed`, `close` or
`open`. Check it in your `onCancel` handler before you close the dialog.
-}
isBusy : State -> Bool
isBusy (State state) =
    state.phase == Busy


{-| The [`Problem`](Klar-Remote#Problem) that was given to `setFailed`, while the
dialog is open and shows it; `Nothing` otherwise, and always once the dialog is
closed.
-}
problem : State -> Maybe Problem
problem (State state) =
    case ( state.phase, Modal.isOpen state.modal ) of
        ( Failed found, True ) ->
            Just found

        _ ->
            Nothing


{-| The messages of the dialog (typing, the built-in cancel, focus movements).
Wrap it in a constructor of your own message type, such as
`DialogMsg ConfirmDialog.Msg`, and hand it to `update`.
-}
type Msg
    = ModalMsg Modal.Msg
    | Typed String
    | Cancel
    | FocusConfirm
    | Noop


{-| Handles the typed confirmation, the focus movements and the built-in cancel.
When the dialog closes itself (the close button, `Escape` or the backdrop, with
no `onCancel`), it forgets the typed text and the failure just as `close` does.
Map its command into your own message with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        ModalMsg inner ->
            let
                ( modal, cmd ) =
                    Modal.update inner state.modal

                -- However the dialog closes, it starts over the next time, as
                -- `close` makes it: no typed text, no stale failure.
                closed =
                    Modal.isOpen state.modal && not (Modal.isOpen modal)
            in
            ( State
                (if closed then
                    { state | modal = modal, phase = Idle, typed = "" }

                 else
                    { state | modal = modal }
                )
            , Cmd.map ModalMsg cmd
            )

        Typed text ->
            ( State { state | typed = text }, Cmd.none )

        Cancel ->
            close current

        FocusConfirm ->
            ( current, Internal.focus (confirmId state.id) Noop )

        Noop ->
            ( current, Cmd.none )


{-| Opens the dialog in its idle state, clearing any earlier failure and typed
text. `opener` is the DOM id of the element that gets focus back when the dialog
closes, usually the button that asked the question (with `""`, the element that
had focus when the dialog opened, if it has an id). Focus starts on the
typed-confirmation field if there is one, otherwise on the cancel button.
-}
open : String -> State -> ( State, Cmd Msg )
open opener (State state) =
    let
        ( modal, cmd ) =
            Modal.openWith { opener = opener, focus = [ inputId state.id, cancelId state.id ] } state.modal
    in
    ( State { state | modal = modal, phase = Idle, typed = "" }, Cmd.map ModalMsg cmd )


{-| Call this when the user confirmed and the request starts. The confirm button
shows a spinner, the typed-confirmation field becomes read-only, and nothing can
close the dialog until you call `close` or `setFailed`.
-}
setBusy : State -> State
setBusy (State state) =
    State { state | phase = Busy }


{-| Call this when the request failed. The dialog shows the problem (its title,
detail and code) and, if the problem is retryable and you gave an `onConfirm`, a
"Try again" button that sends your message again. The dialog can be dismissed
again.

It is for the answer of the server, not for checking the user's input: a missing
choice or a field that is not valid is a reason to keep the confirm button
disabled (see `confirmDisabled`), shown beside the field it concerns. If a problem
that was shown has been dealt with while the dialog stays open, take it away with
`clearFailure`.

-}
setFailed : Problem -> State -> State
setFailed found (State state) =
    State { state | phase = Failed found }


{-| Takes the failure away without closing the dialog, for a problem that does not
apply any more (the user chose another option, say). Nothing happens unless the
dialog shows a failure; a request that is running (`setBusy`) is not touched.
-}
clearFailure : State -> State
clearFailure (State state) =
    case state.phase of
        Failed _ ->
            State { state | phase = Idle }

        _ ->
            State state


{-| Closes the dialog, forgets any typed text and failure, and gives focus back
to its opener. Call it when the request succeeded, and from your `onCancel`
handler.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    let
        ( modal, cmd ) =
            Modal.close state.modal
    in
    ( State { state | modal = modal, phase = Idle, typed = "" }, Cmd.map ModalMsg cmd )


inputId : String -> String
inputId id =
    id ++ "-phrase"


cancelId : String -> String
cancelId id =
    id ++ "-cancel"


confirmId : String -> String
confirmId id =
    id ++ "-confirm"


messageId : String -> String
messageId id =
    id ++ "-message"



-- ATTRIBUTES


{-| A setting of the dialog. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { title : String
    , message : Maybe String
    , body : List (Html msg)
    , consequences : List String
    , tone : Tone
    , icon : Maybe Icon
    , confirmLabel : Maybe String
    , cancelLabel : Maybe String
    , phrase : Maybe String
    , ignoreCase : Bool
    , confirmDisabled : Bool
    , onConfirm : Maybe msg
    , onCancel : Maybe msg
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = ""
        , message = Nothing
        , body = []
        , consequences = []
        , tone = Neutral
        , icon = Nothing
        , confirmLabel = Nothing
        , cancelLabel = Nothing
        , phrase = Nothing
        , ignoreCase = False
        , confirmDisabled = False
        , onConfirm = Nothing
        , onCancel = Nothing
        , locale = Locale.default
        }
        attributes


{-| The question: "Delete order?". It is also the accessible name of the dialog.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = value })


{-| A short explanation in plain text, below the question: "Order 1042 will be
removed from all lists." Screen readers read it out after the title.
-}
message : String -> Attribute msg
message value =
    Attribute (\config -> { config | message = Just value })


{-| Rich content below the message: a name in bold, a link, a small table.
-}
body : List (Html msg) -> Attribute msg
body value =
    Attribute (\config -> { config | body = value })


{-| What will happen, one short line each, shown as a bulleted list below the
message: "3 open shipments are canceled".
-}
consequences : List String -> Attribute msg
consequences value =
    Attribute (\config -> { config | consequences = value })


{-| The tone of the question: `Neutral` (the default), `Warning` or `Danger`. It
sets the icon beside the text and its color, and `Danger` also makes the confirm
button red. `neutral`, `warning` and `danger` are shorthands.
-}
tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = value })


{-| A question with no risk: a blue help icon and a blue confirm button. This is
the default.
-}
neutral : Attribute msg
neutral =
    tone Neutral


{-| An action that is hard to undo or that affects others: a warning icon. The
confirm button stays blue.
-}
warning : Attribute msg
warning =
    tone Warning


{-| A destructive action: a red error icon and a red confirm button.
-}
danger : Attribute msg
danger =
    tone Danger


{-| Replaces the icon of the tone with another one, for example
`ConfirmDialog.icon Icon.trash`.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| Text of the confirm button. The default is "Confirm" (it follows `locale`).
Name the action instead: "Delete order".
-}
confirmLabel : String -> Attribute msg
confirmLabel value =
    Attribute (\config -> { config | confirmLabel = Just value })


{-| Text of the cancel button. The default is "Cancel" (it follows `locale`).
-}
cancelLabel : String -> Attribute msg
cancelLabel value =
    Attribute (\config -> { config | cancelLabel = Just value })


{-| Disables the confirm button (and `Enter` in the typed-confirmation field) while
`True`: pass a field of your model that is `False` until the user has made the
choice the question needs. The dialog stays calm about it: no message is shown,
so say what is missing beside the control (a `Select.errorMaybe`, say). If the
confirm button has focus when it becomes disabled, focus moves to the dialog.
-}
confirmDisabled : Bool -> Attribute msg
confirmDisabled value =
    Attribute (\config -> { config | confirmDisabled = value })


{-| The user must type this text before the confirm button is enabled, for
actions that cannot be undone: a word that makes them stop and read, such as
`"DELETE"` or the name of the thing they delete. The field is labeled "Type
DELETE to confirm" (it follows `locale`), and `Enter` in it confirms once the
text matches. Matching is exact, apart from spaces at either end of what the
user typed, unless you add `ignoreCase`.
-}
typeToConfirm : String -> Attribute msg
typeToConfirm phrase =
    Attribute (\config -> { config | phrase = Just phrase })


{-| For `typeToConfirm`: "delete" matches "DELETE".
-}
ignoreCase : Attribute msg
ignoreCase =
    Attribute (\config -> { config | ignoreCase = True })


{-| The message sent when the user confirms: with the confirm button, with
`Enter` in the typed-confirmation field, or with the "Try again" button after a
failure. Nothing is sent until the typed text matches. Your `update` then calls
`setBusy` and starts the request.
-}
onConfirm : msg -> Attribute msg
onConfirm msg =
    Attribute (\config -> { config | onConfirm = Just msg })


{-| The message sent when the user cancels in any way: with the cancel button,
the close button, `Escape` or the backdrop. Your `update` then calls `close`;
without `onCancel` the dialog closes itself. It is not sent while the request
runs.
-}
onCancel : msg -> Attribute msg
onCancel msg =
    Attribute (\config -> { config | onCancel = Just msg })


{-| The language of the built-in text: the buttons ("Confirm" and "Cancel"), the
"Try again" button, the label of the typed-confirmation field and the label of
the close button. The default is [`Locale.default`](Klar-Locale#default), which
is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The dialog. `toMsg` wraps the messages of the dialog. Renders nothing while
closed, so it can stay in your view all the time. It returns an
[`Overlay`](Klar-Overlay#Overlay) for [`Overlay.host`](Klar-Overlay#host) or
`AppShell.overlays`.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Overlay msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        isBusy_ =
            state.phase == Busy

        phraseOk =
            case config.phrase of
                Nothing ->
                    True

                Just phrase ->
                    normalize config.ignoreCase (String.trim state.typed) == normalize config.ignoreCase phrase

        confirmEnabled =
            phraseOk && not config.confirmDisabled

        canConfirm =
            confirmEnabled && not isBusy_

        texts =
            { confirm = Locale.pick config.locale { nb = "Bekreft", en = "Confirm" }
            , cancel = Locale.pick config.locale { nb = "Avbryt", en = "Cancel" }
            , retry = Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" }
            }

        cancelMsg =
            case config.onCancel of
                Just msg ->
                    msg

                Nothing ->
                    toMsg Cancel

        confirmButton =
            Button.view
                ([ Button.id (confirmId state.id)
                 , if config.tone == Danger then
                    Button.danger

                   else
                    Button.primary
                 , Button.loading isBusy_
                 , Button.disabled (not confirmEnabled)
                 ]
                    ++ (case ( canConfirm, config.onConfirm ) of
                            ( True, Just msg ) ->
                                [ Button.onClick msg ]

                            _ ->
                                []
                       )
                )
                (Maybe.withDefault texts.confirm config.confirmLabel)

        cancelButton =
            Button.view
                [ Button.id (cancelId state.id)
                , Button.disabled isBusy_
                , Button.onClick cancelMsg
                ]
                (Maybe.withDefault texts.cancel config.cancelLabel)
    in
    Modal.view (\inner -> toMsg (ModalMsg inner))
        ([ Modal.title config.title
         , Modal.small
         , Modal.busy isBusy_
         , Modal.locale config.locale
         , Modal.ariaDescribedBy (messageId state.id)
         , Modal.lastFocus
            (if confirmEnabled then
                confirmId state.id

             else
                cancelId state.id
            )
         , Modal.footer [ cancelButton, confirmButton ]
         ]
            ++ (case config.onCancel of
                    Just msg ->
                        [ Modal.onRequestClose msg ]

                    Nothing ->
                        []
               )
        )
        state.modal
        [ Html.div [ Internal.cls [ "klar-confirm" ] ]
            [ Html.span
                [ Internal.cls [ "klar-confirm__icon", "klar-confirm__icon--" ++ Internal.toneSuffix config.tone ] ]
                [ Icon.sized Icon.Large (Maybe.withDefault (defaultIcon config.tone) config.icon) ]
            , Html.div [ Internal.cls [ "klar-confirm__content" ] ]
                [ Html.div [ Internal.cls [ "klar-confirm__text" ], Attr.id (messageId state.id) ]
                    (List.filterMap identity
                        [ Maybe.map (\text -> Html.p [ Internal.cls [ "klar-confirm__message" ] ] [ Html.text text ]) config.message
                        , if List.isEmpty config.body then
                            Nothing

                          else
                            Just (Html.div [ Internal.cls [ "klar-confirm__rich" ] ] config.body)
                        , if List.isEmpty config.consequences then
                            Nothing

                          else
                            Just
                                (Html.ul [ Internal.cls [ "klar-confirm__list" ] ]
                                    (List.map (\text -> Html.li [] [ Html.text text ]) config.consequences)
                                )
                        ]
                    )
                , case config.phrase of
                    Just phrase ->
                        TextInput.view
                            [ TextInput.id (inputId state.id)
                            , TextInput.label (Locale.pick config.locale { nb = "Skriv " ++ phrase ++ " for å bekrefte", en = "Type " ++ phrase ++ " to confirm" })
                            , TextInput.placeholder phrase
                            , TextInput.value state.typed
                            , TextInput.onInput (\text -> toMsg (Typed text))

                            -- Read-only, not disabled: a field that is disabled while
                            -- it has focus (Enter sent the request) would drop focus
                            -- out of the dialog, where Escape no longer reaches it.
                            , TextInput.readOnly isBusy_
                            , TextInput.autocomplete "off"
                            , case ( canConfirm, config.onConfirm ) of
                                ( True, Just msg ) ->
                                    TextInput.onEnter msg

                                _ ->
                                    TextInput.onEnter (toMsg Noop)
                            ]

                    Nothing ->
                        Html.text ""
                , case state.phase of
                    Failed found ->
                        viewFailure toMsg state.id texts.retry config found

                    _ ->
                        Html.text ""
                ]
            ]
        ]


viewFailure : (Msg -> msg) -> String -> String -> Config msg -> Problem -> Html msg
viewFailure toMsg id retryLabel config found =
    Alert.viewWith
        [ Alert.tone Danger
        , Alert.title (Remote.title config.locale found)
        , Alert.compact
        , Alert.locale config.locale
        , Alert.actions
            (case ( config.onConfirm, Remote.isRetryable found ) of
                ( Just msg, True ) ->
                    -- The failure goes away while the request runs, and the button
                    -- with it: the click (it bubbles up here) hands focus to the
                    -- confirm button, so that Escape keeps working in the dialog.
                    [ Html.span [ Internal.cls [ "klar-confirm__retry" ], Events.onClick (toMsg FocusConfirm) ]
                        [ Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick msg ] retryLabel ]
                    ]

                _ ->
                    []
            )
        ]
        (List.filterMap identity
            [ Maybe.map Text.text (Remote.detail config.locale found)
            , Maybe.map (\code -> Text.mono ("  " ++ code)) (Remote.code found)
            ]
        )


normalize : Bool -> String -> String
normalize caseInsensitive text =
    if caseInsensitive then
        String.toLower text

    else
        text


defaultIcon : Tone -> Icon
defaultIcon value =
    case value of
        Danger ->
            Icon.errorCircle

        Warning ->
            Icon.warning

        _ ->
            Icon.help
