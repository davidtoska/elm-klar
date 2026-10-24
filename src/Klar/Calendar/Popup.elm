module Klar.Calendar.Popup exposing
    ( dialog
    , holdFocus
    , onBlurOutside
    , onEscape
    , onFocusLeave
    , onKeys
    , onPressOutside
    )

{-| The popup shell shared by the date pickers: a click-away layer around a
`role="dialog"` popup (see "Popups and focus" in `CLAUDE.md`).

Closing:

  - a press on the layer closes and gives focus back to the field,
  - Escape closes (and does not reach an enclosing modal),
  - Tab or Shift+Tab out of the dialog closes without taking focus back.

Not meant for application code.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Internal as Internal


{-| The layer and the popup. `prefix` is the DOM id of the popup; every
focusable element inside must have an id that starts with it, so the popup can
tell when focus leaves.
-}
dialog :
    { prefix : String
    , label : String
    , classes : List String
    , alignEnd : Bool
    , onClose : msg
    , onEscape : msg
    , onLeave : msg
    , noop : msg
    }
    -> List (Html msg)
    -> Html msg
dialog options content =
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , onPressOutside options.onClose
        , onEscape options.onEscape
        , onFocusLeave options.prefix options.onLeave
        ]
        [ Html.div
            [ Internal.cls
                ("klar-popup"
                    :: (if options.alignEnd then
                            "klar-popup--end"

                        else
                            ""
                       )
                    :: options.classes
                )
            , Attr.id options.prefix
            , Attr.tabindex -1
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-label" options.label
            , Internal.onClickStop options.noop
            , stopPress options.noop
            ]
            content
        ]


{-| A mouse button pressed on the click-away layer. It closes on the press, not
on the click, so dragging a scrollbar or a text selection from inside the popup
and letting go outside does not close it.
-}
onPressOutside : msg -> Html.Attribute msg
onPressOutside msg =
    Events.on "mousedown" (Decode.succeed msg)


{-| A press inside the popup of a field that keeps keyboard focus (a
combobox): the field keeps its focus, and the press reaches neither the layer
nor the page.
-}
holdFocus : msg -> Html.Attribute msg
holdFocus msg =
    Events.custom "mousedown"
        (Decode.succeed { message = msg, stopPropagation = True, preventDefault = True })


{-| A press inside the popup stays inside it (and keeps the page's own mouse
handlers, like a row that opens on press, out of it).
-}
stopPress : msg -> Html.Attribute msg
stopPress msg =
    Events.stopPropagationOn "mousedown" (Decode.succeed ( msg, True ))


{-| Keyboard bindings like `Internal.onKeys` (same key names), for keys a
popup handles itself: the default action is prevented and the event does not
bubble, so an enclosing modal, table or page shortcut never sees it.

Elm keeps one `keydown` handler per element: do not combine this with another
`keydown` attribute on the same element.

-}
onKeys : List ( String, msg ) -> Html.Attribute msg
onKeys bindings =
    Events.custom "keydown"
        (Internal.keyEvent
            |> Decode.andThen
                (\event ->
                    case lookup (keyName event) bindings of
                        Just msg ->
                            Decode.succeed { message = msg, stopPropagation = True, preventDefault = True }

                        Nothing ->
                            Decode.fail "unhandled key"
                )
        )


lookup : String -> List ( String, a ) -> Maybe a
lookup key bindings =
    case bindings of
        [] ->
            Nothing

        ( name, value ) :: rest ->
            if name == key then
                Just value

            else
                lookup key rest


{-| "Ctrl+Shift+K" style name of a key press (Shift only for non-printable keys).
-}
keyName : Internal.KeyEvent -> String
keyName event =
    String.concat
        [ if event.ctrl then
            "Ctrl+"

          else
            ""
        , if event.meta then
            "Meta+"

          else
            ""
        , if event.alt then
            "Alt+"

          else
            ""
        , if event.shift && String.length event.key /= 1 then
            "Shift+"

          else
            ""
        , event.key
        ]


{-| The Escape key. It does not bubble, so an enclosing modal stays open.
-}
onEscape : msg -> Html.Attribute msg
onEscape msg =
    Events.stopPropagationOn "keydown"
        (Decode.field "key" Decode.string
            |> Decode.andThen
                (\key ->
                    if key == "Escape" then
                        Decode.succeed ( msg, True )

                    else
                        Decode.fail "not escape"
                )
        )


{-| Fires when focus moves to an element whose id does not start with
`prefix`. Moves to nowhere (clicking empty space, leaving the window) are
ignored.
-}
onFocusLeave : String -> msg -> Html.Attribute msg
onFocusLeave prefix msg =
    Events.on "focusout"
        (Decode.at [ "relatedTarget", "id" ] Decode.string
            |> Decode.andThen
                (\id ->
                    if String.startsWith prefix id then
                        Decode.fail "still inside"

                    else
                        Decode.succeed msg
                )
        )


{-| A `blur` handler for a field that keeps focus while its popup is open
(a combobox). It does not fire when focus moves into the popup, which is what
clicking the scrollbar of a list does.
-}
onBlurOutside : String -> msg -> Html.Attribute msg
onBlurOutside prefix msg =
    Events.on "blur"
        (Decode.field "relatedTarget" (Decode.nullable (Decode.field "id" Decode.string))
            |> Decode.andThen
                (\maybeId ->
                    case maybeId of
                        Just id ->
                            if String.startsWith prefix id then
                                Decode.fail "focus moved into the popup"

                            else
                                Decode.succeed msg

                        Nothing ->
                            Decode.succeed msg
                )
        )
