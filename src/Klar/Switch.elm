module Klar.Switch exposing
    ( view, Attribute
    , checked, onToggle, loading
    , label, description, error, ariaLabel
    , size, controlAtEnd, disabled, id, locale
    )

{-| An on/off switch for a setting that takes effect at once ("Email
notifications"). Use a [Klar.Checkbox](Klar-Checkbox) instead when the choice is
part of a form that is saved with a button.

Use when: an on/off setting that takes effect at once, such as email notifications.
Do not use when: the choice is part of a form that is saved with a button (`Klar.Checkbox`).

    import Klar.Switch as Switch

    Switch.view
        [ Switch.label "Email notifications"
        , Switch.description "You get an email when an order ships."
        , Switch.checked model.notify
        , Switch.onToggle NotifyToggled
        , Switch.loading model.saving
        ]

The application owns the value: `checked` says whether the switch is on, and
`onToggle` gets the new value when the user clicks the switch or its label, or
presses Space on it. A setting that is saved at once usually stores the new
value, marks the model as saving until the answer arrives, and sends the
request:

    NotifyToggled value ->
        ( { model | notify = value, saving = True }, saveNotify value )

It is a checkbox with `role="switch"`, so screen readers say "on" and "off".
While `loading` is `True` (the application is saving the new value) the knob
shows a spinner and the input is disabled, so neither a click nor the keyboard
can change it; the switch keeps showing the value the application gives it. The
browser takes the keyboard focus from a control that becomes disabled, so move
it back with `Klar.focus` and the `id` of the switch when the save is
done, if that matters.

The description and the error message are drawn under the label, or beside the
switch when there is no label (a switch without a label needs `ariaLabel`). Both
are joined to the switch with `aria-describedby`, and the error is read out when
it appears. A switch draws these parts itself and does not use
[Klar.Field](Klar-Field), so it has no `errorMaybe`, `required` or `labelHidden`.


# View

@docs view, Attribute


# Value

@docs checked, onToggle, loading


# Label and messages

@docs label, description, error, ariaLabel


# Look and behavior

@docs size, controlAtEnd, disabled, id, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a switch. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { label : Maybe String
    , description : Maybe String
    , error : Maybe String
    , checked : Bool
    , disabled : Bool
    , loading : Bool
    , onToggle : Maybe (Bool -> msg)
    , id : Maybe String
    , ariaLabel : Maybe String
    , size : Size
    , controlAtEnd : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing
        , description = Nothing
        , error = Nothing
        , checked = False
        , disabled = False
        , loading = False
        , onToggle = Nothing
        , id = Nothing
        , ariaLabel = Nothing
        , size = Medium
        , controlAtEnd = False
        , locale = Locale.default
        }
        attributes


{-| The text next to the switch. A click on it toggles the switch, and it is the
accessible name of the switch. Without a label the switch is bare: give it an
`ariaLabel`.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | label = Just text })


{-| A line of gray explanation under the label (beside the switch when there is
no label), joined to the switch with `aria-describedby`. An empty text counts as
none.
-}
description : String -> Attribute msg
description text =
    Attribute (\config -> { config | description = Just text })


{-| Marks the switch invalid (a red outline and `aria-invalid`) and shows the
message in red under the label (beside the switch when there is no label). The
message is joined to the switch with `aria-describedby`, and screen readers read
it when it appears. An empty text counts as no error, so there is never a red
outline without a message. There is no `errorMaybe`: add `error` to the list only
while there is a problem.
-}
error : String -> Attribute msg
error text =
    Attribute (\config -> { config | error = Just text })


{-| Whether the switch is on. The default is `False`. The switch always shows
the value it is given, also while it is `loading`.
-}
checked : Bool -> Attribute msg
checked value =
    Attribute (\config -> { config | checked = value })


{-| Dims the switch and makes it unchangeable and unfocusable (the HTML
`disabled` attribute). The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| While `True` the application is saving the change: the knob shows a
spinner, the switch announces `aria-busy` and a screen-reader-only "Saving ...",
and the input is disabled, so neither a click nor the keyboard changes it and
nothing is sent to `onToggle`. A disabled control cannot keep the keyboard focus;
move it back with `Klar.focus` (see `id`) when the save is done. Pass a
field of your model. The default is `False`.
-}
loading : Bool -> Attribute msg
loading value =
    Attribute (\config -> { config | loading = value })


{-| The message sent when the user toggles the switch. It gets the new value,
`True` for on. Store it, or wait for the server to confirm it, and give it back
with `checked`.

    Switch.onToggle NotifyToggled

-}
onToggle : (Bool -> msg) -> Attribute msg
onToggle toMsg =
    Attribute (\config -> { config | onToggle = Just toMsg })


{-| The DOM id of the `input` element, for moving focus to it with
`Klar.focus`. The label, the description and the error message get the
ids `<id>-label`, `<id>-description` and `<id>-error`. Without an id it is made
from the label, or from the `ariaLabel` when there is no label, so give switches
that share a text an id each.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The accessible name when there is no visible label. It becomes the
`aria-label` of the input.
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The size of the switch and its text: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| Puts the switch at the far end of the row with the label first, like a
list of settings. The row fills the width of its container, so put the switch in
something wider than itself, such as a card or a stack.
-}
controlAtEnd : Attribute msg
controlAtEnd =
    Attribute (\config -> { config | controlAtEnd = True })


{-| The language of the built-in text, which is the "Saving ..." that screen
readers hear while the switch is `loading`. The default is `Locale.default`,
which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| A switch with its label, description and error message, or bare. See the
module documentation for the attributes that matter most: `checked`,
`onToggle` and `loading`.
-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        inputId =
            case config.id of
                Just given ->
                    given

                Nothing ->
                    "klar-switch-"
                        ++ Internal.sanitizeId
                            (String.toLower (Maybe.withDefault (Maybe.withDefault "switch" config.ariaLabel) config.label))

        labelId =
            inputId ++ "-label"

        descriptionId =
            inputId ++ "-description"

        errorId =
            inputId ++ "-error"

        -- A blank text is no text: there is nothing to show or to refer to.
        shownDescription =
            Maybe.andThen Internal.nonEmpty config.description

        shownError =
            Maybe.andThen Internal.nonEmpty config.error

        -- aria-describedby only names elements that are drawn below.
        described =
            List.filterMap identity
                [ Maybe.map (\_ -> descriptionId) shownDescription
                , Maybe.map (\_ -> errorId) shownError
                ]

        hasText =
            config.label /= Nothing || shownDescription /= Nothing || shownError /= Nothing
    in
    Html.label
        [ Internal.cls
            [ "klar-switch"
            , "klar-switch--" ++ Internal.sizeSuffix config.size
            , if config.checked then
                "klar-switch--on"

              else
                ""
            , if config.loading then
                "klar-switch--loading"

              else
                ""
            , if config.disabled then
                "klar-switch--disabled"

              else
                ""
            , if shownError /= Nothing then
                "klar-switch--invalid"

              else
                ""
            , if config.controlAtEnd then
                "klar-switch--control-end"

              else
                ""
            ]
        ]
        [ Html.input
            [ Internal.cls [ "klar-switch__input" ]
            , Attr.type_ "checkbox"
            , Attr.attribute "role" "switch"
            , Attr.id inputId
            , Attr.checked config.checked

            -- While the change is being saved the input is inert, also for
            -- Space on the keyboard: a hidden checkbox that could still flip
            -- would disagree with the switch the user sees.
            , Attr.disabled (config.disabled || config.loading)
            , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
            , Internal.attrIf (config.label /= Nothing) (Attr.attribute "aria-labelledby" labelId)
            , if List.isEmpty described then
                Internal.noAttr

              else
                Attr.attribute "aria-describedby" (String.join " " described)
            , Internal.attrIf config.loading (Attr.attribute "aria-busy" "true")
            , Internal.attrIf (shownError /= Nothing) (Attr.attribute "aria-invalid" "true")
            , if config.loading then
                Internal.noAttr

              else
                Internal.attrMaybe Events.onCheck config.onToggle
            ]
            []
        , Html.span [ Internal.cls [ "klar-switch__track" ], Attr.attribute "aria-hidden" "true" ]
            [ Html.span [ Internal.cls [ "klar-switch__thumb" ] ] [] ]
        , if hasText then
            Html.span [ Internal.cls [ "klar-switch__text" ] ]
                [ Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-switch__label" ], Attr.id labelId ] [ Html.text text ])
                    config.label
                , Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-switch__description" ], Attr.id descriptionId ] [ Html.text text ])
                    shownDescription
                , Internal.viewMaybe
                    (\message ->
                        Html.span
                            [ Internal.cls [ "klar-switch__error" ]
                            , Attr.id errorId
                            , Attr.attribute "role" "alert"
                            ]
                            [ Html.text message ]
                    )
                    shownError
                ]

          else
            Html.text ""
        , Internal.viewIf config.loading
            (Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                [ Html.text (Locale.pick config.locale { nb = "Lagrer ...", en = "Saving ..." }) ]
            )
        ]
