module Klar.InlineEdit exposing
    ( view, Attribute
    , State, Msg, init, update
    , value, isEditing, isSaving, isFailed, pending
    , saved, failed, setValue, edit
    , ariaLabel, placeholder, emptyText
    , validate, maxLength
    , multiline, disabled
    , locale
    )

{-| Click-to-edit text. In reading mode it looks like text (with a pencil on
hover); a click turns it into an input.

Use when: a single text that is edited in place and saved at once, such as a customer name on a detail page.
Do not use when: the text is one field of a form that is saved with a button; use `Klar.TextInput`.
Quick path: `init`, `update`, `view`, `pending`, `saved`, `failed`

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
        [ InlineEdit.ariaLabel "Customer name"
        , InlineEdit.validate (Validate.run Locale.en Validate.required)
        ]
        model.customerName

The first `String` given to `init` is the DOM id of the input that is shown while
editing, so there is no `id` attribute; the second is the text to show.

**Keyboard.** Enter saves, Escape cancels, leaving the field saves, and the text
is a button: Tab reaches it and Space or Enter starts editing. After Enter or
Escape the focus is back on the text; after leaving the field with Tab or a click
it stays where the user put it. A `multiline` text
is edited in a text area, where Enter starts a new line and Ctrl+Enter (Cmd+Enter on
a Mac) saves. The Enter or
Escape that ends an IME composition (Japanese, Chinese, Korean input) only picks
the characters. Escape is handled here and its default is prevented, so a
surrounding dialog that respects `defaultPrevented` stays open. Switching to
another window (Alt+Tab) does not count as leaving the field: the editor stays
open with the text, and nothing is saved.

**Saving.** When the user confirms a changed text, `isSaving` turns `True`: that
is the application's cue to send the new text (`pending`) to the backend. The
text keeps showing the new value with a spinner, and screen readers hear "Saving
..." and then "Saved". When the backend answers, call `saved` (the value is now
`pending`) or `failed` with a [Klar.Remote](Klar-Remote) `Problem`: the text is
then shown with the problem, a "Try again" button (which makes `isSaving` `True`
again; left out when `Remote.isRetryable` says the problem would fail the same
way, such as a conflict or a validation problem) and a "Cancel" button (which
goes back to the old value). A click on the text opens the editor again with the
refused text and the problem under it, so the user can correct it. Leaving it
unchanged brings the failure back and sends nothing; Enter on it sends it again
only when "Try again" would. Confirming the saved text unchanged saves nothing. An answer that comes when no save is on its
way (a late one, after a `setValue` or a "Cancel") changes nothing.

**Validation.** `validate` is checked when the user confirms; a message keeps
the input open and is shown under it.

**The application's own changes.** `setValue` replaces the saved text. While the
user is editing, or a save is on its way, it never touches what they typed or
the save: the editor stays open with their text, and "Cancel" goes back to the
new value. This is the rule of every Klar input: what the user types wins.

**No field wrapper.** Unlike most inputs, this one is not built on the field
wrapper ([Klar.Field](Klar-Field)), so it has no visible label, hint, required
marker or `error` attribute. `ariaLabel` is the name screen readers hear, and the
message of `validate` is shown under the input.

The built-in texts (the buttons, "Click to add", "Saving ...") follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# Reading the state

@docs value, isEditing, isSaving, isFailed, pending


# Saving and changing it from the application

@docs saved, failed, setValue, edit


# Name and texts

@docs ariaLabel, placeholder, emptyText


# Rules

@docs validate, maxLength


# Behavior

@docs multiline, disabled


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
import Klar.Internal.Composition as Composition
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

    -- opened from a failure: the refused text, until the user types
    , refused : Maybe String

    -- the last save went well: "Saved" for screen readers, until editing starts again
    , justSaved : Bool
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
        , refused = Nothing
        , justSaved = False
        }


{-| The saved text: the one the field started with, or the last one confirmed
with `saved` or put there with `setValue`. While the user is editing, or a save
is on its way, it is still the old text; see `pending`.
-}
value : State -> String
value (State state) =
    state.value


{-| Replaces the saved text, for example after the record was loaded again. In
reading mode the new text is shown at once. While the user is editing, the text
they typed stays in the editor and only the saved text changes: "Cancel" and
Escape go back to the new one. (When they have not changed anything yet, the
editor shows the new text too, so an Enter does not save the old one over it.)
While a save is on its way or has failed, the save goes on: `saved` still makes
`pending` the value, and "Cancel" goes back to the new text.
-}
setValue : String -> State -> State
setValue text (State state) =
    case state.mode of
        Reading ->
            State { state | value = text, draft = text, error = Nothing }

        Editing ->
            if state.draft == state.value then
                State { state | value = text, draft = text }

            else
                State { state | value = text }

        Saving ->
            State { state | value = text }

        Failed ->
            State { state | value = text }


{-| Opens the editor from the application, as a click on the text does: for a
keyboard shortcut such as F2 on the row, or an "Edit" item in a menu. The `Cmd`
moves the focus into the input, so pass it on with `Cmd.map`. It does nothing
while the editor is open or a save is on its way. Do not call it for a field
that is `disabled`: its editor would open inert.

    EditNameClicked ->
        let
            ( customerName, cmd ) =
                InlineEdit.edit model.customerName
        in
        ( { model | customerName = customerName }, Cmd.map CustomerNameMsg cmd )

-}
edit : State -> ( State, Cmd Msg )
edit state =
    update StartEdit state


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


{-| `True` after `failed` until the user chooses "Try again" or "Cancel", or
clicks the text to correct it. The text is shown with the problem and the
buttons.
-}
isFailed : State -> Bool
isFailed (State state) =
    state.mode == Failed


{-| The text waiting to be saved: the confirmed text while `isSaving`, and after
a failure until the user cancels or opens the editor again. Otherwise `Nothing`.
-}
pending : State -> Maybe String
pending (State state) =
    state.pending


{-| The save went well: the pending text is now the value, and the field is back
in reading mode. Call it when the backend answers. It does nothing when no save
is on its way, so a late answer cannot close an editor the user opened since.
-}
saved : State -> State
saved (State state) =
    if state.mode == Saving then
        let
            text =
                Maybe.withDefault state.value state.pending
        in
        State
            { state
                | value = text
                , draft = text
                , mode = Reading
                , error = Nothing
                , pending = Nothing
                , problem = Nothing
                , justSaved = True
            }

    else
        State state


{-| The save failed. The text is shown with "Could not save." and the `title` of
the problem, followed by its `detail` when you gave one with `Remote.withDetail`
(the server's message for this field), a "Try again" button (which makes
`isSaving` `True` again, but only when `Remote.isRetryable` allows it: not for a
conflict or a validation problem, which would fail the same way) and a "Cancel"
button that goes back to the old value. A click on the text opens the editor
with the refused text and the message under it. The `Problem` is from
[Klar.Remote](Klar-Remote); make one from your own error with `Remote.problem`.
It does nothing when no save is on its way, like `saved`.

    InlineEdit.failed (Remote.problem Remote.network) model.customerName

A refusal that names the field:

    InlineEdit.failed
        (Remote.problem Remote.validation |> Remote.withDetail "This domain is blocked.")
        model.website
    -- "Could not save. The form has errors: This domain is blocked."

-}
failed : Problem -> State -> State
failed problem (State state) =
    if state.mode == Saving then
        State { state | mode = Failed, problem = Just problem }

    else
        State state



-- UPDATE


{-| What the user confirmed: the text as it is in the input, and the message of
`validate` for it, worked out in the view where the rule is known. No function
travels in a message.
-}
type alias Confirmation =
    { text : String
    , problem : Maybe String
    }


{-| The messages an inline edit sends: starting to edit, typing, confirming,
cancelling and the two buttons after a failure. `view` wraps them with the
function you give it; hand them to `update` when they come back.
-}
type Msg
    = StartEdit
    | Typed String
    | Confirm Confirmation
    | Leave Confirmation
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
            case state.mode of
                Reading ->
                    ( State { state | mode = Editing, draft = state.value, error = Nothing, justSaved = False }
                    , Internal.focus state.id Noop
                    )

                Failed ->
                    -- correct the refused text: it comes back with the problem under it
                    ( State
                        { state
                            | mode = Editing
                            , draft = Maybe.withDefault state.value state.pending
                            , pending = Nothing
                            , refused = state.pending
                            , error = Nothing
                            , justSaved = False
                        }
                    , Internal.focus state.id Noop
                    )

                _ ->
                    ( State state, Cmd.none )

        Typed text ->
            if state.mode == Editing then
                ( State { state | draft = text, error = Nothing, problem = Nothing, refused = Nothing }, Cmd.none )

            else
                ( State state, Cmd.none )

        Confirm confirmed ->
            confirm True confirmed state

        Leave confirmed ->
            confirm False confirmed state

        Cancel ->
            if state.mode == Editing then
                ( State
                    { state
                        | mode = Reading
                        , draft = state.value
                        , error = Nothing
                        , pending = Nothing
                        , problem = Nothing
                        , refused = Nothing
                    }
                , Internal.focus (displayId state.id) Noop
                )

            else
                ( State state, Cmd.none )

        Retry ->
            case ( state.mode, state.pending ) of
                ( Failed, Just _ ) ->
                    -- the retry button goes away: keep focus on the text
                    ( State { state | mode = Saving, problem = Nothing }
                    , Internal.focus (displayId state.id) Noop
                    )

                ( Failed, Nothing ) ->
                    -- nothing to send again
                    ( State { state | mode = Reading, draft = state.value, problem = Nothing }
                    , Internal.focus (displayId state.id) Noop
                    )

                _ ->
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


{-| Confirms the text of the editor. Enter and the save button (`refocus`) give the
focus back to the text, as the editor goes away under it; leaving the field (Tab, a
click elsewhere) does not, so the focus stays where the user put it. A refused text
that was opened only to read the problem, and not changed, is not sent again: the
failure comes back as it was. An Enter on it sends it again only when the problem
can go away by itself (`Remote.isRetryable`), as "Try again" does.
-}
confirm : Bool -> Confirmation -> Fields -> ( State, Cmd Msg )
confirm refocus confirmed state =
    let
        candidate =
            String.trim confirmed.text

        focusBack =
            if refocus then
                Internal.focus (displayId state.id) Noop

            else
                Cmd.none

        unchangedFailure =
            case ( state.problem, state.refused ) of
                ( Just problem, Just text ) ->
                    if text == candidate then
                        Just problem

                    else
                        Nothing

                _ ->
                    Nothing

        sending =
            State
                { state
                    | mode = Saving
                    , draft = candidate
                    , pending = Just candidate
                    , error = Nothing
                    , problem = Nothing
                    , refused = Nothing
                }
    in
    if state.mode /= Editing then
        ( State state, Cmd.none )

    else
        case ( confirmed.problem, unchangedFailure ) of
            ( Just problem, _ ) ->
                ( State { state | draft = confirmed.text, error = Just problem }, Cmd.none )

            ( Nothing, Just problem ) ->
                if refocus && Remote.isRetryable problem then
                    ( sending, focusBack )

                else
                    ( State { state | mode = Failed, pending = state.refused, refused = Nothing, error = Nothing }
                    , focusBack
                    )

            ( Nothing, Nothing ) ->
                if candidate == state.value then
                    ( State
                        { state
                            | mode = Reading
                            , draft = state.value
                            , error = Nothing
                            , pending = Nothing
                            , problem = Nothing
                            , refused = Nothing
                        }
                    , focusBack
                    )

                else
                    ( sending, focusBack )


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
    { ariaLabel : Maybe String
    , placeholder : String
    , emptyText : Maybe String
    , maxLength : Maybe Int
    , validate : String -> Maybe String
    , multiline : Bool
    , disabled : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { ariaLabel = Nothing
        , placeholder = ""
        , emptyText = Nothing
        , maxLength = Nothing
        , validate = \_ -> Nothing
        , multiline = False
        , disabled = False
        , locale = Locale.default
        }
        attributes


{-| What the text is about, such as `"Customer name"`, for screen readers only:
it is the accessible name of the input, and part of the name of the text button
("Edit Customer name: Ada Lovelace", in the case it was given). Give every inline
edit one; the visible label, when there is one, is yours (a `DescriptionList`
term, a heading).
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


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


{-| The text has several lines, such as a note or a description. The editor is a
text area: Enter starts a new line, Ctrl+Enter (Cmd+Enter on a Mac) saves, Escape
cancels and leaving the field saves, as in a single line. In reading mode the line
breaks are kept. Default: a single line.

    InlineEdit.view NoteMsg
        [ InlineEdit.ariaLabel "Delivery note", InlineEdit.multiline ]
        model.deliveryNote

-}
multiline : Attribute msg
multiline =
    Attribute (\config -> { config | multiline = True })


{-| While `True` the text cannot be edited: no pencil, and a click does nothing.
It stays the same button, marked `aria-disabled` and out of the Tab order, so a
field that becomes disabled while it has the focus keeps it. Default `False`.

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
...", the "Save" and "Cancel" buttons, "Saving ...", "Saved", "Could not save."
and "Try again". Default `Locale.default`, which is English. Texts you pass in
yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale lang =
    Attribute (\config -> { config | locale = lang })



-- VIEW


{-| The text, which turns into an input when the user clicks it. The first
argument wraps the field's own messages in one of yours, and the state comes
last.

    InlineEdit.view CustomerNameMsg
        [ InlineEdit.ariaLabel "Customer name"
        , InlineEdit.emptyText "No name yet"
        ]
        model.customerName

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes
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
        -- The live region is the first child in every mode, so it is never made
        -- again and what it says is announced.
        (viewAnnouncement config state
            :: (case state.mode of
                    Reading ->
                        [ viewDisplay toMsg config state state.value ]

                    Editing ->
                        viewEditor toMsg config state

                    Saving ->
                        [ viewDisplay toMsg config state (Maybe.withDefault state.value state.pending)
                        , Html.span
                            [ Internal.cls [ "klar-inline-edit__saving" ]
                            , Attr.attribute "aria-hidden" "true"
                            ]
                            [ Html.span [ Internal.cls [ "klar-spinner", "klar-spinner--sm" ] ] []
                            , Html.text (savingText config.locale)
                            ]
                        ]

                    Failed ->
                        viewFailure toMsg config state
               )
        )


{-| "Saving ..." while a save is on its way and "Saved" after it, for screen
readers. A failure is announced by its own alert.
-}
viewAnnouncement : Config -> Fields -> Html msg
viewAnnouncement config state =
    Html.span
        [ Internal.cls [ "klar-sr-only" ]
        , Attr.attribute "role" "status"
        ]
        [ Html.text
            (case state.mode of
                Saving ->
                    savingText config.locale

                Reading ->
                    if state.justSaved then
                        Locale.pick config.locale { nb = "Lagret", en = "Saved" }

                    else
                        ""

                _ ->
                    ""
            )
        ]


savingText : Locale -> String
savingText lang =
    Locale.pick lang { nb = "Lagrer ...", en = "Saving ..." }


{-| The text as a button that starts editing. While saving it stays (inactive)
in the same place, so keyboard focus is not lost when the input closes: Enter in
the input moves focus here, and it stays here through `saved` and `failed`.
After a failed save a click opens the editor again. While disabled it is the
same button, inactive and out of the Tab order, so it keeps the focus it has.
-}
viewDisplay : (Msg -> msg) -> Config -> Fields -> String -> Html msg
viewDisplay toMsg config state text =
    let
        active =
            not config.disabled && (state.mode == Reading || state.mode == Failed)

        accessibleName =
            Locale.pick config.locale { nb = "Rediger", en = "Edit" }
                ++ (case config.ariaLabel of
                        Just name ->
                            " " ++ name

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
    Html.button
        [ Internal.cls
            [ "klar-inline-edit__display"
            , if config.disabled then
                "klar-inline-edit__display--disabled"

              else if active then
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
        , Internal.attrIf config.disabled (Attr.tabindex -1)
        ]
        [ staticText config text
        , Internal.viewIf active
            (Html.span [ Internal.cls [ "klar-inline-edit__pencil" ], Attr.attribute "aria-hidden" "true" ]
                [ Icon.view Icon.edit ]
            )
        ]


staticText : Config -> String -> Html msg
staticText config text =
    if text == "" then
        Html.span [ Internal.cls [ "klar-inline-edit__text", "klar-inline-edit__text--empty" ] ]
            [ Html.text (emptyLabel config) ]

    else
        Html.span
            [ Internal.cls
                [ "klar-inline-edit__text"
                , if config.multiline then
                    "klar-inline-edit__text--multiline"

                  else
                    ""
                ]
            ]
            [ Html.text text ]


emptyLabel : Config -> String
emptyLabel config =
    config.emptyText
        |> Maybe.withDefault (Locale.pick config.locale { nb = "Klikk for å legge til", en = "Click to add" })


{-| What the user confirms, with the message of `validate` for it.
-}
confirmation : Config -> String -> Confirmation
confirmation config text =
    { text = text, problem = config.validate (String.trim text) }


viewEditor : (Msg -> msg) -> Config -> Fields -> List (Html msg)
viewEditor toMsg config state =
    let
        errorId =
            state.id ++ "-error"

        saveLabel =
            Locale.pick config.locale { nb = "Lagre", en = "Save" }

        cancelLabel =
            Locale.pick config.locale { nb = "Avbryt", en = "Cancel" }

        -- the message of `validate`, or else the problem of the save that failed
        -- (the editor was opened again to correct the refused text)
        message =
            case state.error of
                Just text ->
                    Just text

                Nothing ->
                    Maybe.map (\problem -> couldNotSave config.locale ++ failureText config.locale problem) state.problem

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
            , if message /= Nothing then
                "klar-input--invalid"

              else
                ""
            , if config.disabled then
                "klar-input--disabled"

              else
                ""
            , if config.multiline then
                "klar-inline-edit__box--multiline"

              else
                ""
            ]
        ]
        [ (if config.multiline then
            Html.textarea

           else
            Html.input
          )
            [ Internal.cls
                [ "klar-input__control"
                , if config.multiline then
                    "klar-inline-edit__textarea"

                  else
                    ""
                ]
            , if config.multiline then
                Attr.rows 3

              else
                Attr.type_ "text"
            , Attr.id state.id
            , Attr.value state.draft
            , Attr.placeholder config.placeholder
            , Internal.attrMaybe Attr.maxlength config.maxLength
            , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
            , Internal.attrIf (message /= Nothing) (Attr.attribute "aria-invalid" "true")
            , Internal.attrIf (message /= Nothing) (Attr.attribute "aria-describedby" errorId)
            , Internal.attrIf config.disabled (Attr.attribute "aria-disabled" "true")
            , Attr.readonly config.disabled
            , Attr.attribute "autocomplete" "off"
            , Internal.attrIf active (Events.onInput (\text -> toMsg (Typed text)))
            , Internal.attrIf active (Events.on "blur" (blurDecoder toMsg config state))
            , Internal.attrIf active (Events.preventDefaultOn "keydown" (keyDecoder toMsg config state))
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
            , Internal.attrIf active (Events.onClick (toMsg (Confirm (confirmation config state.draft))))
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
    , case message of
        Just text ->
            Html.p
                [ Internal.cls [ "klar-field__error", "klar-inline-edit__error" ]
                , Attr.id errorId
                , Attr.attribute "role" "alert"
                ]
                [ Html.text text ]

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
                (couldNotSave config.locale
                    ++ (state.problem |> Maybe.map (failureText config.locale) |> Maybe.withDefault "")
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


couldNotSave : Locale -> String
couldNotSave lang =
    Locale.pick lang { nb = "Kunne ikke lagre. ", en = "Could not save. " }


{-| The title of the problem, and its detail after a colon when the application
gave one of its own (`Remote.withDetail`), such as the server's message for this
field. The ready-made detail of a kind is left out: it would only repeat the title.
-}
failureText : Locale -> Problem -> String
failureText lang problem =
    let
        own =
            Remote.detail lang problem

        standard =
            Remote.detail lang (Remote.problem (Remote.kind problem))
    in
    case own of
        Just text ->
            if own /= standard && String.trim text /= "" then
                Remote.title lang problem ++ ": " ++ text

            else
                Remote.title lang problem

        Nothing ->
            Remote.title lang problem


{-| Enter confirms and Escape cancels; both are handled here, so their default is
prevented (no form is submitted, and a dialog around the field that respects
`defaultPrevented` stays open). In a `multiline` text a plain Enter is a new line,
and Ctrl+Enter or Cmd+Enter confirms. The text comes from the input itself, so an
Enter pressed before the next frame confirms what is in it. The key that ends an IME
composition is left to the input method.
-}
keyDecoder : (Msg -> msg) -> Config -> Fields -> Decode.Decoder ( msg, Bool )
keyDecoder toMsg config state =
    Composition.unlessComposing
        (Decode.map2 Tuple.pair Internal.keyEvent (textDecoder state)
            |> Decode.andThen
                (\( event, text ) ->
                    let
                        command =
                            event.ctrl || event.meta
                    in
                    case event.key of
                        "Enter" ->
                            if event.alt || command /= config.multiline then
                                -- a new line in a text area, or a key of the browser
                                Decode.fail "not for the field"

                            else
                                Decode.succeed ( toMsg (Confirm (confirmation config text)), True )

                        "Escape" ->
                            if event.alt || command then
                                Decode.fail "modifier"

                            else
                                Decode.succeed ( toMsg Cancel, True )

                        _ ->
                            Decode.fail "unhandled key"
                )
        )


{-| Leaving the field confirms it, and the focus stays where the user put it (the
next control after a Tab, the input they clicked). When the whole window loses the
focus (the user switches to another one), the input is still the focused element of
its page, and nothing happens: the user comes back to the open editor.
-}
blurDecoder : (Msg -> msg) -> Config -> Fields -> Decode.Decoder msg
blurDecoder toMsg config state =
    Decode.map2 Tuple.pair
        (textDecoder state)
        (Decode.oneOf
            [ Decode.at [ "target", "ownerDocument", "activeElement", "id" ] Decode.string
            , Decode.succeed ""
            ]
        )
        |> Decode.andThen
            (\( text, focused ) ->
                if focused == state.id then
                    Decode.fail "the window was left"

                else
                    Decode.succeed (toMsg (Leave (confirmation config text)))
            )


{-| The text in the input, read from the input itself; the text of the last
render when the event has none.
-}
textDecoder : Fields -> Decode.Decoder String
textDecoder state =
    Decode.oneOf [ Decode.at [ "target", "value" ] Decode.string, Decode.succeed state.draft ]
