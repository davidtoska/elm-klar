module Klar.Form.Layout exposing
    ( view, section, grid, fullRow, actions, stickyActions
    , errorSummary, focusSummary
    , Status(..), status, focusStatus
    , unsavedChanges, unsavedFlag
    , Attribute
    , id, ariaLabel, onSubmit, stacked
    , locale
    , labels, onFocusField
    , onRetry, onDismiss
    , onSave, onDiscard, saving, sticky
    )

{-| The layout of a form and the parts around it: sections, a grid for the
fields, the row of buttons, the list of problems after a failed submit, the
state of the submit and a reminder of unsaved changes.

Use when: you need the frame of a form (sections, grid, button row, status of the save, unsaved mark) or wire a form by hand.
Do not use when: you want values, rules, steps and problems kept for you (use `Klar.Form`).

This is the frame that [Klar.Form](Klar-Form) is drawn in, and it works alone for
a form that you wire by hand (the example below). For most forms start with
[Klar.Form](Klar-Form), which keeps the values, the rules, the steps and the
problems in one state, and use this module for the sections, the button row and
the status of the save.

A form is values in the model, rules that find what is wrong with them, and a
view. This module draws the frame of the view, the controls (`TextInput`,
`Radio` ...) draw the fields, and [Klar.Validate](Klar-Validate) holds the
rules. Here they work together in a small order form.

**Model and rules.** The model keeps the values, whether the problems are shown
yet, and where the submit is. The rules are a function of the model, so the
messages are always up to date: once a submit has found problems, they follow
the values and disappear as the fields are fixed. The first part of each triple
is the DOM id of the control, so the control gets the same `id`.

    import Html exposing (Html)
    import Klar
    import Klar.Button as Button
    import Klar.Form.Layout as FormLayout
    import Klar.Layout as Layout
    import Klar.Locale as Locale
    import Klar.Radio as Radio
    import Klar.Remote as Remote
    import Klar.TextInput as TextInput
    import Klar.Validate as Validate

    type alias Model =
        { customer : String
        , email : String
        , priority : String
        , showErrors : Bool
        , status : FormLayout.Status
        }

    type Msg
        = CustomerChanged String
        | EmailChanged String
        | PriorityChanged String
        | Submit
        | Retry
        | Saved (Result Remote.Problem ())
        | FocusField String
        | NoOp

    problems : Model -> List Validate.Problem
    problems model =
        Validate.collect Locale.default
            [ ( "order-customer", [ Validate.required ], model.customer )
            , ( "order-email", [ Validate.required, Validate.email ], model.email )
            ]

**View.** The whole form is one `FormLayout.view`. Several attributes are shared by
the functions of this module: each function reads the ones it needs and ignores
the rest, so one list serves the form, its error summary and its status line.
`labels` lets the summary say "Email: Invalid email address" instead of the
message alone.

    formAttributes : List (FormLayout.Attribute Msg)
    formAttributes =
        [ FormLayout.id "order-form"
        , FormLayout.onSubmit Submit
        , FormLayout.labels [ ( "order-customer", "Customer" ), ( "order-email", "Email" ) ]
        , FormLayout.onFocusField FocusField
        , FormLayout.onRetry Retry
        ]

    view : Model -> Html Msg
    view model =
        let
            errors =
                if model.showErrors then
                    problems model

                else
                    []
        in
        FormLayout.view formAttributes
            [ FormLayout.errorSummary formAttributes errors
            , FormLayout.section "Customer"
                "Who the invoice is for."
                [ FormLayout.grid 2
                    [ TextInput.view
                        [ TextInput.id "order-customer"
                        , TextInput.label "Customer"
                        , TextInput.required
                        , TextInput.value model.customer
                        , TextInput.onInput CustomerChanged
                        , TextInput.errorMaybe (Validate.errorFor "order-customer" errors)
                        ]
                    , TextInput.view
                        [ TextInput.id "order-email"
                        , TextInput.label "Email"
                        , TextInput.email
                        , TextInput.required
                        , TextInput.value model.email
                        , TextInput.onInput EmailChanged
                        , TextInput.errorMaybe (Validate.errorFor "order-email" errors)
                        ]
                    ]
                ]
            , FormLayout.section "Delivery"
                "How fast the order should arrive."
                [ Radio.view
                    [ Radio.id "order-priority"
                    , Radio.label "Priority"
                    , Radio.options
                        [ Radio.option "standard" "Standard, 3 to 5 days"
                        , Radio.option "express" "Express, next day"
                        ]
                    , Radio.selected (Just model.priority)
                    , Radio.onChange PriorityChanged
                    ]
                ]
            , FormLayout.actions
                [ FormLayout.status formAttributes model.status
                , Layout.spacer
                , Button.view
                    [ Button.primary
                    , Button.submit
                    , Button.loading (model.status == FormLayout.Submitting)
                    ]
                    "Place order"
                ]
            ]

The form has `novalidate`: the browser shows none of its own validation
bubbles, and the application shows its messages next to the fields and in the
summary. Pressing Enter in a field submits the form, even when the submit button
is outside it (in the footer of a dialog, for example): the form holds an
invisible submit button for that. A section puts its title and description
beside its fields when the window is wide, and above them otherwise. Give every
form on a page its own `FormLayout.id`: the DOM ids of its summary and its status line
are made from it, and two forms without one would share them.

**Update.** `Submit` decides what happens. The browser would reload the page on
a submit, so a form needs its `onSubmit`. Enter in a field sends it too, also
while a request is running, so ignore it then. When there are problems, show
them and move the focus to the summary, where a screen reader reads them; each
problem is a button that sends `FocusField` with the id of its control, which
`Klar.focus` turns into the focus. When there are none, start the request
(`sendOrder` is your own function, this package has no HTTP) and answer the
status with `Succeeded` or `Failed` when it comes back.

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            Submit ->
                if model.status == FormLayout.Submitting then
                    ( model, Cmd.none )

                else if List.isEmpty (problems model) then
                    ( { model | showErrors = False, status = FormLayout.Submitting }
                    , sendOrder model
                    )

                else
                    ( { model | showErrors = True }
                    , FormLayout.focusSummary "order-form" NoOp
                    )

            FocusField fieldId ->
                ( model, Klar.focus fieldId NoOp )

            Retry ->
                ( { model | status = FormLayout.Submitting }
                , Cmd.batch [ sendOrder model, FormLayout.focusStatus "order-form" NoOp ]
                )

            Saved (Ok ()) ->
                ( { model | status = FormLayout.Succeeded "The order was saved." }, Cmd.none )

            Saved (Err problem) ->
                ( { model | status = FormLayout.Failed problem }, Cmd.none )

            CustomerChanged value ->
                ( { model | customer = value }, Cmd.none )

            EmailChanged value ->
                ( { model | email = value }, Cmd.none )

            PriorityChanged value ->
                ( { model | priority = value }, Cmd.none )

            NoOp ->
                ( model, Cmd.none )

`status` shows `Submitting` as a spinner with "Saving ...", `Succeeded` as a
line with a green check mark and `Failed` as a red message with the title and detail of the
`Remote.Problem` and, when `onRetry` is given and the problem is worth trying
again, a "Try again" button. That button is replaced by "Saving ..." the moment
it is pressed, which is why `Retry` moves the focus to the status line with
`focusStatus` instead of leaving it on a button that is gone.

A form that edits existing data can also show `unsavedChanges`, a banner for as
long as the data differs from what was loaded or saved, or `unsavedFlag`, a
small mark for the footer of a dialog or drawer. The texts the functions draw
are English; `FormLayout.locale Locale.nb` makes them Norwegian.


# Layout

@docs view, section, grid, fullRow, actions, stickyActions


# Problems after a submit

@docs errorSummary, focusSummary


# The state of the submit

@docs Status, status, focusStatus


# Unsaved changes

@docs unsavedChanges, unsavedFlag


# Attributes

@docs Attribute

The form itself (`view`). The `id` is also read by `errorSummary` and `status`:

@docs id, ariaLabel, onSubmit, stacked

The language of the texts that `errorSummary`, `status`, `unsavedChanges` and
`unsavedFlag` draw:

@docs locale

The error summary (`errorSummary`):

@docs labels, onFocusField

The status line (`status`):

@docs onRetry, onDismiss

The unsaved-changes banner (`unsavedChanges`):

@docs onSave, onDiscard, saving, sticky

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem)
import Klar.Theme exposing (Tone(..))



-- ATTRIBUTES


{-| A setting for the functions of this module. Make them with the functions
below and pass a list to `view`, `errorSummary`, `status`, `unsavedChanges` or
`unsavedFlag`. Each function reads the attributes it knows and ignores the rest,
so one list can serve them all; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { id : Maybe String
    , ariaLabel : Maybe String
    , onSubmit : Maybe msg
    , stacked : Bool
    , locale : Locale
    , labels : List ( String, String )
    , onFocusField : Maybe (String -> msg)
    , onRetry : Maybe msg
    , onDismiss : Maybe msg
    , onSave : Maybe msg
    , onDiscard : Maybe msg
    , saving : Bool
    , sticky : Bool
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { id = Nothing
        , ariaLabel = Nothing
        , onSubmit = Nothing
        , stacked = False
        , locale = Locale.default
        , labels = []
        , onFocusField = Nothing
        , onRetry = Nothing
        , onDismiss = Nothing
        , onSave = Nothing
        , onDiscard = Nothing
        , saving = False
        , sticky = False
        }
        attributes


{-| The DOM id of the form. `view` puts it on the `form` element. The error
summary and the status line make their own ids from it (`<id>-summary` and
`<id>-status`), which is how `focusSummary` and `focusStatus` find them, so give
the same id to all of them. Give every form on a page its own id: without one
the summary and the status line use `form-summary` and `form-status`, and two
forms without an id would share those ids.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The accessible name of the form (`view`). A form with a name is a landmark
that screen reader users can jump to.
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The message sent when the form is submitted, by a submit button
(`Button.submit`) or by Enter in a field (`view`). The browser's own submit,
which would reload the page, is prevented only when this is given: always give
a form an `onSubmit`. Enter submits also while a request is running, so ignore
the message in `update` while the status is `Submitting`.
-}
onSubmit : msg -> Attribute msg
onSubmit msg =
    Attribute (\config -> { config | onSubmit = Just msg })


{-| Puts the title and description of every section above its fields instead
of beside them (`view`). Sections already stack on a narrow window; use this for
a form in a narrow place such as a dialog or a drawer, where the width of the
window says nothing about the room the form has.
-}
stacked : Attribute msg
stacked =
    Attribute (\config -> { config | stacked = True })


{-| The language of the texts that `errorSummary`, `status`, `unsavedChanges`
and `unsavedFlag` draw ("The form has 2 errors", "Saving ...", "Try again",
"Unsaved changes" ...). The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Pairs of a field's DOM id and its label, so that a problem reads "Email:
Invalid email address" in the error summary instead of the message alone
(`errorSummary`). A problem whose field has no pair shows only its message.
-}
labels : List ( String, String ) -> Attribute msg
labels value =
    Attribute (\config -> { config | labels = value })


{-| What a click on a problem in the error summary sends: the DOM id of its
field. Handle it with `Klar.focus` (`errorSummary`). Without this each problem
is a plain link to `#<field id>`, which an application built with
`Browser.application` receives as a URL request; always give it.
-}
onFocusField : (String -> msg) -> Attribute msg
onFocusField toMsg =
    Attribute (\config -> { config | onFocusField = Just toMsg })


{-| Shows a "Try again" button in the failure message when the submit failed in
a way that is worth trying again: the network, a timeout, a server error or an
unknown error, see `Remote.isRetryable` (`status`). The button sends this
message.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Shows a close button on the success and failure messages and sends this
message when it is pressed (`status`). The button goes away with the message, so
in the update that handles it move focus to a control that makes sense (the
submit button, with `Klar.focus`); otherwise keyboard focus falls back to the page.
-}
onDismiss : msg -> Attribute msg
onDismiss msg =
    Attribute (\config -> { config | onDismiss = Just msg })


{-| Gives the unsaved-changes banner a "Save" button that sends this message
(`unsavedChanges`). Without it the banner has no such button.
-}
onSave : msg -> Attribute msg
onSave msg =
    Attribute (\config -> { config | onSave = Just msg })


{-| Gives the unsaved-changes banner a "Discard" button that sends this message
(`unsavedChanges`). Without it the banner has no such button.
-}
onDiscard : msg -> Attribute msg
onDiscard msg =
    Attribute (\config -> { config | onDiscard = Just msg })


{-| While `True` the "Save" button of the banner shows a spinner and ignores
clicks, and the "Discard" button is disabled (`unsavedChanges`). Pass a field of
your model that is `True` while the request is running. The default is `False`.
-}
saving : Bool -> Attribute msg
saving value =
    Attribute (\config -> { config | saving = value })


{-| The banner sticks to the top of the scrolling area while the page scrolls
(`unsavedChanges`).
-}
sticky : Attribute msg
sticky =
    Attribute (\config -> { config | sticky = True })



-- FORM


{-| The `form` element around the sections, the error summary and the button row.
It has `novalidate`, so the browser shows none of its own validation bubbles.
Reads `id`, `ariaLabel`, `onSubmit` and `stacked`.

    FormLayout.view [ FormLayout.id "order-form", FormLayout.onSubmit Submit ]
        [ FormLayout.section "Customer" "Who the invoice is for." [ customerFields ]
        , FormLayout.actions [ Layout.spacer, saveButton ]
        ]

With an `onSubmit`, the form also holds an invisible submit button, so that Enter
in a field submits it even when the real buttons are outside the form, as in the
footer of a dialog.

-}
view : List (Attribute msg) -> List (Html msg) -> Html msg
view attributes children =
    let
        config =
            configure attributes
    in
    Html.form
        [ Internal.cls
            [ "klar-form"
            , if config.stacked then
                "klar-form--stacked"

              else
                ""
            ]
        , Attr.novalidate True
        , Attr.attribute "aria-busy"
            (if config.saving then
                "true"

             else
                "false"
            )
        , Internal.attrMaybe Attr.id config.id
        , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
        , case config.onSubmit of
            Just msg ->
                Events.onSubmit msg

            Nothing ->
                Internal.noAttr
        ]
        (case config.onSubmit of
            -- Pressing Enter in a field only submits a form with several
            -- fields when the form has a submit button. The real buttons are
            -- often outside the form (a dialog footer), so there is an
            -- invisible one that keeps Enter working.
            Just _ ->
                children
                    ++ [ Html.button
                            [ Attr.type_ "submit"
                            , Internal.cls [ "klar-sr-only" ]
                            , Attr.tabindex -1
                            , Attr.attribute "aria-hidden" "true"
                            ]
                            []
                       ]

            Nothing ->
                children
        )


{-| A part of the form: a title and a short explanation on the left and the
fields on the right (above each other when the window is narrow, or always with
`stacked`). Sections are separated by a thin gray line.

    FormLayout.section "Delivery" "Where and when the order should arrive." [ addressFields ]

The second argument may be an empty string. The title names the section for
screen readers (`role="group"` with an `aria-label`) and is an `h2`, the level under
the `h1` of a page. A section has no DOM id, so
two sections may share a title, also in different forms on one page.

A `Card` inside a section takes the level below: give it `Card.headingLevel 3`,
or the page outline skips a level. A card with no section above it (on a
review page, say) keeps the default, 2.

-}
section : String -> String -> List (Html msg) -> Html msg
section title description children =
    -- The title names the group with aria-label instead of aria-labelledby, so
    -- the section needs no DOM id: two sections may share a title, also in
    -- different forms of one page, and nothing can collide.
    Html.section
        [ Internal.cls [ "klar-form-section" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" title
        ]
        [ Html.div [ Internal.cls [ "klar-form-section__head" ] ]
            [ Html.h2 [ Internal.cls [ "klar-form-section__title" ] ] [ Html.text title ]
            , if description == "" then
                Html.text ""

              else
                Html.p [ Internal.cls [ "klar-form-section__description" ] ] [ Html.text description ]
            ]
        , Html.div [ Internal.cls [ "klar-form-section__body" ] ] children
        ]


{-| Fields side by side in this many columns (a number below 1 counts as 1). It
becomes a single column on a narrow window.

    FormLayout.grid 2 [ nameField, emailField, FormLayout.fullRow addressField ]

-}
grid : Int -> List (Html msg) -> Html msg
grid columns children =
    Html.div
        [ Internal.cls [ "klar-form-grid" ]
        , Internal.styleVars [ ( "--klar-cols", String.fromInt (max 1 columns) ) ]
        ]
        children


{-| A field that takes the whole row of a `grid`, such as an address or a free
text note.
-}
fullRow : Html msg -> Html msg
fullRow child =
    Html.div [ Internal.cls [ "klar-form-grid__full" ] ] [ child ]


{-| The row of buttons at the end of the form, right-aligned and set off from
the fields by a thin line. Put `Layout.spacer` between buttons to push the first
ones to the left, for example a "Delete" button; the `status` line also belongs
here.

    FormLayout.actions
        [ Button.view [ Button.danger, Button.onClick Delete ] "Delete"
        , Layout.spacer
        , Button.view [ Button.onClick Cancel ] "Cancel"
        , Button.view [ Button.primary, Button.submit ] "Save"
        ]

-}
actions : List (Html msg) -> Html msg
actions children =
    Html.div [ Internal.cls [ "klar-form-actions" ] ] children


{-| Like `actions`, but the row stays at the bottom of the scrolling area while
the form is longer than the window.
-}
stickyActions : List (Html msg) -> Html msg
stickyActions children =
    Html.div [ Internal.cls [ "klar-form-actions", "klar-form-actions--sticky" ] ] children



-- FOCUS


{-| Moves focus to the error summary of the form with this id (the one given to
`FormLayout.id`), so that a screen reader reads it. Call it in the update that finds
problems on a submit, after the problems are in the model. The message is sent
when it is done.
-}
focusSummary : String -> msg -> Cmd msg
focusSummary formId done =
    Internal.focus (summaryId formId) done


summaryId : String -> String
summaryId formId =
    formId ++ "-summary"



-- ERROR SUMMARY


{-| A red message at the top of the form that says how many problems there are
("The form has 2 errors", then "Fix the problems below before you continue.")
and lists them, one line each. Nothing is drawn for an empty list. A problem is
a `field`, the DOM id of its control, and a `message`; the `Validate.Problem`
records from [Klar.Validate](Klar-Validate) fit. Each line is a button that
sends `onFocusField` with the id of its field (a plain link to `#<field id>`
when there is no `onFocusField`), and the box itself can take focus
(`focusSummary`). It is announced by screen readers when it appears
(`role="alert"`). Reads `id`, `labels`, `onFocusField` and `locale`.
-}
errorSummary : List (Attribute msg) -> List { field : String, message : String } -> Html msg
errorSummary attributes problems =
    let
        config =
            configure attributes

        count =
            List.length problems

        formId =
            Maybe.withDefault "form" config.id

        title =
            Locale.pick config.locale
                { nb = "Skjemaet har " ++ String.fromInt count ++ " feil"
                , en = "The form has " ++ String.fromInt count ++ " " ++ Format.plural config.locale count { one = "error", other = "errors" }
                }

        intro =
            Locale.pick config.locale
                { nb = "Rett opp feilene under før du fortsetter."
                , en = "Fix the problems below before you continue."
                }
    in
    if List.isEmpty problems then
        Html.text ""

    else
        Html.div
            [ Internal.cls [ "klar-form-summary" ]
            , Attr.id (summaryId formId)
            , Attr.tabindex -1
            ]
            [ Alert.viewWith
                [ Alert.tone Danger, Alert.title title, Alert.locale config.locale ]
                [ Html.p [ Internal.cls [ "klar-form-summary__intro" ] ] [ Html.text intro ]
                , Html.ul [ Internal.cls [ "klar-form-summary__list" ] ]
                    (List.map (summaryItem config) problems)
                ]
            ]


summaryItem : Config msg -> { field : String, message : String } -> Html msg
summaryItem config problem =
    let
        text =
            case List.filter (\( fieldId, _ ) -> fieldId == problem.field) config.labels |> List.head of
                Just ( _, fieldLabel ) ->
                    fieldLabel ++ ": " ++ problem.message

                Nothing ->
                    problem.message
    in
    Html.li []
        [ case ( problem.field, config.onFocusField ) of
            ( "", _ ) ->
                Html.text text

            -- A button, not a link: in an application with hash routing a
            -- click on `href="#field"` would be taken for a route change.
            ( _, Just toMsg ) ->
                Html.button
                    [ Internal.cls [ "klar-form-summary__link" ]
                    , Attr.type_ "button"
                    , Events.onClick (toMsg problem.field)
                    ]
                    [ Html.text text ]

            ( _, Nothing ) ->
                Html.a
                    [ Internal.cls [ "klar-form-summary__link" ]
                    , Attr.href ("#" ++ problem.field)
                    ]
                    [ Html.text text ]
        ]



-- STATUS


{-| Where the submit of a form is, for `status` to show. Keep one in the model
and start with `Idle`.

  - `Idle`: nothing to show, because nothing has been sent yet or the
    application cleared the message.
  - `Submitting`: the request is on its way.
  - `Succeeded message`: it worked; the message is shown with a green check
    mark and read out by a screen reader.
  - `Failed problem`: it did not; the `Problem` from
    [Klar.Remote](Klar-Remote) is shown in red.

-}
type Status
    = Idle
    | Submitting
    | Succeeded String
    | Failed Problem


{-| The state of the submit as one line or message: nothing while `Idle`, a
spinner with "Saving ..." while `Submitting`, a line with a check mark and the
text of `Succeeded` (and a close button with `onDismiss`), and a red message
with the title, detail and code of the problem in `Failed` and, when `onRetry`
is given and trying again could help, a "Try again" button. Put it in the button
row (`actions`). Reads `id`, `onRetry`, `onDismiss` and `locale`.

**Focus.** The message sits in a region that can take focus (`tabindex="-1"`,
with the DOM id `<form id>-status`), and the region is always in the page, in
every state, also `Idle`: when a save that had the focus on the region ends in
`Idle`, the focus stays on it and does not fall to the page. "Saving ..." and
the text of `Succeeded` are written into a polite live line (`role="status"`)
that is always there, so a screen reader announces them; the message of `Failed`
is an alert (`role="alert"`), announced at once. The "Try again" button is replaced by "Saving ..."
the moment it is pressed, so keyboard focus would fall back to the page: move it
to the region with `focusStatus` in the same update, and a screen reader follows
the retry from "Saving ..." to the result.

    Retry ->
        ( { model | status = FormLayout.Submitting }
        , Cmd.batch [ sendOrder model, FormLayout.focusStatus "order-form" NoOp ]
        )

-}
status : List (Attribute msg) -> Status -> Html msg
status attributes current =
    let
        config =
            configure attributes

        dismiss =
            case config.onDismiss of
                Just msg ->
                    [ Alert.onDismiss msg ]

                Nothing ->
                    []

        -- the same region and the same live line in every state: focus on the region survives
        -- the end of a save, and what the line says ("Saving ...", the message of a success) is
        -- announced because the live line was already there
        region modifier line content =
            Html.div
                [ Internal.cls [ "klar-form-statusregion" ]
                , Attr.id (statusId (Maybe.withDefault "form" config.id))
                , Attr.tabindex -1
                ]
                [ Html.span
                    [ Internal.cls [ "klar-form-status", modifier ]
                    , Attr.attribute "role" "status"
                    ]
                    line
                , content
                ]
    in
    case current of
        Idle ->
            region "" [] (Html.text "")

        Submitting ->
            region ""
                [ Html.span [ Internal.cls [ "klar-spinner", "klar-spinner--sm" ], Attr.attribute "aria-hidden" "true" ] []
                , Html.text (Locale.pick config.locale { nb = "Lagrer ...", en = "Saving ..." })
                ]
                (Html.text "")

        Succeeded message ->
            -- written into the live line, not drawn as an alert: an element with a live role that is
            -- inserted with its text is often not announced, and two would be announced twice
            region "klar-form-status--success"
                [ Html.span [ Internal.cls [ "klar-form-status__icon" ] ] [ Icon.view Icon.check ]
                , Html.text message
                ]
                (case config.onDismiss of
                    Just msg ->
                        Button.iconOnly [ Button.ghost, Button.small, Button.onClick msg ]
                            Icon.close
                            (Locale.pick config.locale { nb = "Lukk", en = "Close" })

                    Nothing ->
                        Html.text ""
                )

        Failed problem ->
            -- an alert (`role="alert"`), which is announced when it is inserted
            region ""
                []
                (Alert.viewWith
                    ([ Alert.tone Danger
                     , Alert.compact
                     , Alert.title (Remote.title config.locale problem)
                     , Alert.locale config.locale
                     , Alert.actions
                        (case ( config.onRetry, Remote.isRetryable problem ) of
                            ( Just msg, True ) ->
                                [ Button.view [ Button.small, Button.onClick msg ]
                                    (Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" })
                                ]

                            _ ->
                                []
                        )
                     ]
                        ++ dismiss
                    )
                    [ Html.text (Maybe.withDefault "" (Remote.detail config.locale problem))
                    , case Remote.code problem of
                        Just code ->
                            Html.span [ Internal.cls [ "klar-form-status__code" ] ] [ Html.text (" (" ++ code ++ ")") ]

                        Nothing ->
                            Html.text ""
                    ]
                )


{-| Moves keyboard focus to the status region of the form with this id (the one
given to `FormLayout.id`, see `status`). Call it in the update that handles the "Try
again" button, so focus is not left on a button that has just been replaced. The
message is sent when it is done. Nothing happens when the form has no status
message at that moment.
-}
focusStatus : String -> msg -> Cmd msg
focusStatus formId done =
    Internal.focus (statusId formId) done


statusId : String -> String
statusId formId =
    formId ++ "-status"



-- UNSAVED CHANGES


{-| A warning banner ("You have unsaved changes. The changes are lost if you
leave the page without saving.") for as long as the form has changes that are
not saved. The `Bool` says whether there are some: compare the data in the form
with what was loaded or saved. Nothing is drawn for `False`. The buttons "Save"
and "Discard" are there when `onSave` and `onDiscard` are given. The banner is
announced politely (`role="status"`), as it appears while the user is typing.
Reads `onSave`, `onDiscard`, `saving`, `sticky` and `locale`.

    FormLayout.unsavedChanges
        [ FormLayout.onSave SaveOrder, FormLayout.onDiscard DiscardChanges, FormLayout.saving model.saving ]
        (model.draft /= model.saved)

The banner appears above the fields when the first change is made, and pushes
them down. In a long form or flow prefer [`unsavedFlag`](#unsavedFlag), which takes
no room of its own. Keeping people from leaving the page with unsaved changes is
[`LeaveGuard`](Klar-LeaveGuard): tell it the same fact with `LeaveGuard.setDirty`
and it asks on links, in your code and on the browser's Back and Forward buttons.
Closing the tab cannot be intercepted without JavaScript.

-}
unsavedChanges : List (Attribute msg) -> Bool -> Html msg
unsavedChanges attributes dirty =
    let
        config =
            configure attributes

        buttons =
            List.filterMap identity
                [ config.onSave
                    |> Maybe.map
                        (\msg ->
                            Button.view
                                [ Button.small
                                , Button.primary
                                , Button.loading config.saving
                                , Button.onClick msg
                                ]
                                (Locale.pick config.locale { nb = "Lagre", en = "Save" })
                        )
                , config.onDiscard
                    |> Maybe.map
                        (\msg ->
                            Button.view
                                [ Button.small
                                , Button.disabled config.saving
                                , Button.onClick msg
                                ]
                                (Locale.pick config.locale { nb = "Forkast", en = "Discard" })
                        )
                ]
    in
    if dirty then
        Html.div
            [ Internal.cls
                [ "klar-form-unsaved"
                , if config.sticky then
                    "klar-form-unsaved--sticky"

                  else
                    ""
                ]
            ]
            [ Alert.viewWith
                [ Alert.tone Warning
                , Alert.compact
                , Alert.polite
                , Alert.locale config.locale
                , Alert.title (Locale.pick config.locale { nb = "Du har ulagrede endringer", en = "You have unsaved changes" })
                , Alert.actions buttons
                ]
                [ Html.text
                    (Locale.pick config.locale
                        { nb = "Endringene går tapt hvis du forlater siden uten å lagre."
                        , en = "The changes are lost if you leave the page without saving."
                        }
                    )
                ]
            ]

    else
        Html.text ""


{-| A small mark, "Unsaved changes", for the footer of a drawer or dialog
(`Drawer.footerStart`, `Modal.footerStart`) or the button row of a form. The
`Bool` says whether there are unsaved changes, as for `unsavedChanges`. The mark
takes no room of its own while the form is clean and does not push the fields
around when the first key is typed, which the banner of `unsavedChanges` does:
this is the one for a long form or flow. The empty live region is always there, so a
screen reader announces the text when it appears. Reads `locale`. The question
"Leave without saving?" when the user goes away is
[`LeaveGuard`](Klar-LeaveGuard), fed with the same `Bool`.

    FormLayout.unsavedFlag [] (model.draft /= model.saved)

-}
unsavedFlag : List (Attribute msg) -> Bool -> Html msg
unsavedFlag attributes dirty =
    let
        config =
            configure attributes
    in
    Html.span
        [ Internal.cls [ "klar-form-flag" ]
        , Attr.attribute "role" "status"
        ]
        (if dirty then
            [ Html.span [ Internal.cls [ "klar-form-flag__dot" ], Attr.attribute "aria-hidden" "true" ] []
            , Html.text (Locale.pick config.locale { nb = "Ulagrede endringer", en = "Unsaved changes" })
            ]

         else
            []
        )
