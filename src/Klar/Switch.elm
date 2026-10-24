module Klar.Switch exposing
    ( view, Attribute
    , checked, onCheck, loading
    , label, hint, error, errorMaybe, ariaLabel
    , size, controlAtEnd, disabled, readOnly, id, locale
    )

{-| An on/off switch for a setting that takes effect at once ("Email
notifications"). Use a [Klar.Checkbox](Klar-Checkbox) instead when the choice is
part of a form that is saved with a button.

Use when: an on/off setting that takes effect at once, such as email notifications.
Do not use when: the choice is part of a form that is saved with a button (`Klar.Checkbox`).

    import Klar.Switch as Switch

    Switch.view
        [ Switch.label "Email notifications"
        , Switch.hint "You get an email when an order ships."
        , Switch.checked model.notify
        , Switch.onCheck NotifyChecked
        , Switch.loading model.saving
        , Switch.errorMaybe model.notifyError
        ]

The application owns the value: `checked` says whether the switch is on, and
`onCheck` gets the new value when the user clicks the switch or its label, or
presses Space on it. A setting that is saved at once stores the new value, marks
the model as saving until the answer arrives, and sends the request; when the
save fails it puts the old value back and says why:

    NotifyChecked value ->
        if value == model.notify then
            -- pressed again while the last change is being saved
            ( model, Cmd.none )

        else
            ( { model | notify = value, saving = True, notifyError = Nothing }, saveNotify value )

    NotifySaved (Ok ()) ->
        ( { model | saving = False }, Cmd.none )

    NotifySaved (Err _) ->
        ( { model | notify = not model.notify, saving = False, notifyError = Just "Could not save. Try again." }
        , Cmd.none
        )

It is a checkbox with `role="switch"`, so screen readers say "on" and "off".
While `loading` is `True` (the application is saving the new value) the knob
shows a spinner, screen readers hear "Saving ...", and neither a click nor Space
changes the switch: it keeps showing the value the application gives it, and it
keeps the keyboard focus.

The hint and the error message are drawn under the label, or beside the switch
when there is no label (a switch without a label needs `ariaLabel`). Both are
joined to the switch with `aria-describedby`, and the error is read out when it
appears. A switch draws these parts itself and does not use
[Klar.Field](Klar-Field); it has the same `hint`, `error` and `errorMaybe` as the
fields, and `ariaLabel` instead of `labelHidden`.


# View

@docs view, Attribute


# Value

@docs checked, onCheck, loading


# Label and messages

@docs label, hint, error, errorMaybe, ariaLabel


# Look and behavior

@docs size, controlAtEnd, disabled, readOnly, id, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
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
    , hint : Maybe String
    , error : Maybe String
    , checked : Bool
    , disabled : Bool
    , readOnly : Bool
    , loading : Bool
    , onCheck : Maybe (Bool -> msg)
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
        , hint = Nothing
        , error = Nothing
        , checked = False
        , disabled = False
        , readOnly = False
        , loading = False
        , onCheck = Nothing
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
hint : String -> Attribute msg
hint text =
    Attribute (\config -> { config | hint = Just text })


{-| Marks the switch invalid (a red outline and `aria-invalid`) and shows the
message in red under the label (beside the switch when there is no label). The
message is joined to the switch with `aria-describedby`, and screen readers read
it when it appears. An empty text counts as no error, so there is never a red
outline without a message.
-}
error : String -> Attribute msg
error text =
    Attribute (\config -> { config | error = Just text })


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error, such as the reason the last save failed.

    Switch.errorMaybe model.notifyError

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    Attribute (\config -> { config | error = maybe })


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


{-| Shows the setting without letting the user change it, for a user who may not
change it. Unlike `disabled` it is not dimmed, and Tab still reaches it, so a
screen reader can read it ("Email notifications, switch, on, read only"); a click
or Space changes nothing and nothing is sent to `onCheck`. The switch is then an
element with `role="switch"`, `aria-checked` and `aria-readonly` instead of a
native checkbox, with the same `id`. `disabled` wins over it. The default is
`False`.
-}
readOnly : Bool -> Attribute msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| While `True` the application is saving the change: the knob shows a
spinner, the switch announces `aria-busy`, a screen-reader-only "Saving ..." is
read out, and the switch is `aria-disabled`: a click or Space changes nothing.
The switch keeps the keyboard focus, so a keyboard user can go on from it. A
click or Space while saving sends the value the switch already has to `onCheck`,
so compare it with your model before you save again (see the module example).
Pass a field of your model. The default is `False`.
-}
loading : Bool -> Attribute msg
loading value =
    Attribute (\config -> { config | loading = value })


{-| The message sent when the user toggles the switch. It gets the new value,
`True` for on. Store it, or wait for the server to confirm it, and give it back
with `checked`.

    Switch.onCheck NotifyChecked

-}
onCheck : (Bool -> msg) -> Attribute msg
onCheck toMsg =
    Attribute (\config -> { config | onCheck = Just toMsg })


{-| The DOM id of the switch, for moving focus to it with `Klar.focus`. No id is
set by default. The label, the hint and the error message get the ids
`<id>-label`, `<id>-description` and `<id>-error`. Without an id they are made
from the label (or the `ariaLabel`), so give switches that share a text and show
a hint or an error (the rows of a table) an id each.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The accessible name when there is no visible label, such as "Active" in the
row of a table. It becomes the `aria-label` of the switch.
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


{-| A switch with its label, hint and error message, or bare. See the module
documentation for the attributes that matter most: `checked`, `onCheck` and
`loading`.
-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        -- The ids of the parts: from the id of the switch, else from the label.
        partId =
            case config.id of
                Just given ->
                    given

                Nothing ->
                    "klar-switch-"
                        ++ Internal.sanitizeId
                            (String.toLower (Maybe.withDefault (Maybe.withDefault "switch" config.ariaLabel) config.label))

        labelId =
            partId ++ "-label"

        descriptionId =
            partId ++ "-description"

        errorId =
            partId ++ "-error"

        -- A blank text is no text: there is nothing to show or to refer to.
        shownHint =
            Maybe.andThen Internal.nonEmpty config.hint

        shownError =
            Maybe.andThen Internal.nonEmpty config.error

        -- aria-describedby only names elements that are drawn below.
        described =
            List.filterMap identity
                [ Maybe.map (\_ -> descriptionId) shownHint
                , Maybe.map (\_ -> errorId) shownError
                ]

        hasText =
            config.label /= Nothing || shownHint /= Nothing || shownError /= Nothing

        isReadOnly =
            config.readOnly && not config.disabled

        isLoading =
            config.loading && not config.disabled && not isReadOnly

        -- The name is the label alone (not the hint, the error or the "Saving
        -- ..." that sit inside the label element too).
        ariaAttributes =
            [ Internal.attrMaybe Attr.id config.id
            , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
            , Internal.attrIf (config.label /= Nothing) (Attr.attribute "aria-labelledby" labelId)
            , if List.isEmpty described then
                Internal.noAttr

              else
                Attr.attribute "aria-describedby" (String.join " " described)
            , Internal.attrIf (shownError /= Nothing) (Attr.attribute "aria-invalid" "true")
            ]

        thumb =
            [ Html.span [ Internal.cls [ "klar-switch__thumb" ] ] [] ]
    in
    Html.label
        [ Internal.cls
            [ "klar-switch"
            , "klar-switch--" ++ Internal.sizeSuffix config.size
            , if config.checked then
                "klar-switch--on"

              else
                ""
            , if isLoading then
                "klar-switch--loading"

              else
                ""
            , if config.disabled then
                "klar-switch--disabled"

              else
                ""
            , if isReadOnly then
                "klar-switch--readonly"

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
        [ if isReadOnly then
            Html.span
                ([ Internal.cls [ "klar-switch__track" ]
                 , Attr.attribute "role" "switch"
                 , Attr.attribute "aria-checked"
                    (if config.checked then
                        "true"

                     else
                        "false"
                    )
                 , Attr.attribute "aria-readonly" "true"
                 , Attr.tabindex 0
                 ]
                    ++ ariaAttributes
                )
                thumb

          else
            Html.input
                ([ Internal.cls [ "klar-switch__input" ]
                 , Attr.type_ "checkbox"
                 , Attr.attribute "role" "switch"
                 , Attr.checked config.checked
                 , Attr.disabled config.disabled
                 , Internal.attrIf isLoading (Attr.attribute "aria-disabled" "true")
                 , Internal.attrIf isLoading (Attr.attribute "aria-busy" "true")

                 -- While the change is being saved the input keeps the focus but
                 -- cannot flip, also for Space on the keyboard: a hidden checkbox
                 -- that could still flip would disagree with the switch the user
                 -- sees. The click is cancelled and reported as the value the
                 -- switch already has.
                 , case ( isLoading, config.onCheck ) of
                    ( True, Just toMsg ) ->
                        Events.preventDefaultOn "click" (Decode.succeed ( toMsg config.checked, True ))

                    ( False, Just toMsg ) ->
                        Events.onCheck toMsg

                    ( _, Nothing ) ->
                        Internal.noAttr
                 ]
                    ++ ariaAttributes
                )
                []
        , if isReadOnly then
            Html.text ""

          else
            Html.span [ Internal.cls [ "klar-switch__track" ], Attr.attribute "aria-hidden" "true" ] thumb
        , if hasText then
            Html.span [ Internal.cls [ "klar-switch__text" ] ]
                [ Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-switch__label" ], Attr.id labelId ] [ Html.text text ])
                    config.label
                , Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-switch__description" ], Attr.id descriptionId ] [ Html.text text ])
                    shownHint
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

        -- Always there, so that screen readers notice when its text changes (a
        -- live region that is added together with its text is often not read).
        , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
            [ Html.text
                (if isLoading then
                    Locale.pick config.locale { nb = "Lagrer ...", en = "Saving ..." }

                 else
                    ""
                )
            ]
        ]
