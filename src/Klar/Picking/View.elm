module Klar.Picking.View exposing
    ( Binding
    , Move(..)
    , atEnd
    , atStart
    , holdSearchFocus
    , isJust
    , onKeydown
    , onSearchKeys
    , onTriggerKeys
    , onWindowKeys
    , plain
    , retryFor
    , viewChevron
    , viewClearButton
    , viewEmpty
    , viewFailure
    , viewFooter
    , viewLayer
    , viewSearch
    , viewSkeleton
    , whenEmpty
    , whenEmptyFresh
    )

{-| The parts of a popup that the picking components share with the select
family, written out here so that they do not depend on the select's internals:
the click-away layer, the search box, the footer, the states of a list that
loads, and the keyboard handlers with the conditions a tree needs (the arrow
keys that move the caret in the search box while there is text to move it in).

They use the CSS classes of the select family, so a tree field looks like a
select.

Not for application code.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner


{-| Whether a `Maybe` has a value, without comparing values.
-}
isJust : Maybe a -> Bool
isJust maybe =
    case maybe of
        Just _ ->
            True

        Nothing ->
            False



-- KEYS


{-| A key of the search box and when it counts. The arrow keys that a tree uses
to open and close nodes are also the keys that move the caret in the text, so
they only count when the caret has nowhere to go.
-}
type Binding msg
    = Binding Condition String msg


type Condition
    = Always
    | WhenEmpty
    | WhenEmptyFresh
    | AtStart
    | AtEnd


plain : String -> msg -> Binding msg
plain =
    Binding Always


{-| Only while the search box is empty (Space chooses a node then, and is a
letter of the search text otherwise).
-}
whenEmpty : String -> msg -> Binding msg
whenEmpty =
    Binding WhenEmpty


{-| Only while the search box is empty and the key was pressed afresh, not held
down (so holding Backspace to clear a text does not go on to remove chips).
-}
whenEmptyFresh : String -> msg -> Binding msg
whenEmptyFresh =
    Binding WhenEmptyFresh


{-| Only when the caret is at the end of the text (or there is none).
-}
atEnd : String -> msg -> Binding msg
atEnd =
    Binding AtEnd


{-| Only when the caret is at the start of the text, with nothing selected.
-}
atStart : String -> msg -> Binding msg
atStart =
    Binding AtStart


type alias Caret =
    { text : String
    , start : Int
    , end : Int
    , repeated : Bool
    , composing : Bool
    }


caret : Decoder Caret
caret =
    Decode.map5 Caret
        (Decode.oneOf [ Decode.at [ "target", "value" ] Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.at [ "target", "selectionStart" ] Decode.int, Decode.succeed 0 ])
        (Decode.oneOf [ Decode.at [ "target", "selectionEnd" ] Decode.int, Decode.succeed 0 ])
        (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])
        composing


{-| Is the key part of an input method composition (Japanese, Chinese, Korean
...)? Then Enter commits the composed text and the arrows pick a candidate: they
are not keys for the list. Browsers say so with `isComposing`, and the key code
229 for the key that ends a composition in some of them.
-}
composing : Decoder Bool
composing =
    Decode.map2 (||)
        (Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "keyCode" Decode.int |> Decode.map (\code -> code == 229), Decode.succeed False ])


holds : Condition -> Caret -> Bool
holds condition c =
    case condition of
        Always ->
            True

        WhenEmpty ->
            c.text == ""

        WhenEmptyFresh ->
            c.text == "" && not c.repeated

        AtStart ->
            c.start == 0 && c.end == 0

        AtEnd ->
            c.start == String.length c.text && c.end == String.length c.text


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


findBinding : String -> Caret -> List (Binding msg) -> Maybe msg
findBinding name c bindings =
    case bindings of
        [] ->
            Nothing

        (Binding condition key msg) :: rest ->
            if key == name && holds condition c then
                Just msg

            else
                findBinding name c rest


{-| The keys of the search box. `handled` keys prevent the browser's own action
and stop the key from reaching a surrounding dialog; `passive` keys only send
the message (Tab).
-}
onSearchKeys : { handled : List (Binding msg), passive : List (Binding msg) } -> Html.Attribute msg
onSearchKeys bindings =
    Events.custom "keydown"
        (Decode.map2 Tuple.pair Internal.keyEvent caret
            |> Decode.andThen
                (\( event, c ) ->
                    let
                        name =
                            keyName event
                    in
                    if c.composing then
                        Decode.fail "a key of an input method composition"

                    else
                        case findBinding name c bindings.handled of
                            Just msg ->
                                Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }

                            Nothing ->
                                case findBinding name c bindings.passive of
                                    Just msg ->
                                        Decode.succeed { message = msg, preventDefault = False, stopPropagation = False }

                                    Nothing ->
                                        Decode.fail "unhandled key"
                )
        )


{-| Plain keys with a message each (no conditions).
-}
onKeydown : { handled : List ( String, msg ), passive : List ( String, msg ) } -> Html.Attribute msg
onKeydown bindings =
    onSearchKeys
        { handled = List.map (\( key, msg ) -> plain key msg) bindings.handled
        , passive = List.map (\( key, msg ) -> plain key msg) bindings.passive
        }


{-| Keys on a closed trigger: the bindings, plus (optionally) any printable
character, which opens the list and starts the search with that character.
-}
onTriggerKeys : List ( String, msg ) -> Maybe (String -> msg) -> Html.Attribute msg
onTriggerKeys bindings typed =
    Events.custom "keydown"
        (Decode.map2 Tuple.pair Internal.keyEvent (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])
            |> Decode.andThen
                (\( event, repeated ) ->
                    let
                        name =
                            if repeated && event.key == "Backspace" then
                                "Repeat+" ++ keyName event

                            else
                                keyName event
                    in
                    case lookup name bindings of
                        Just msg ->
                            Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }

                        Nothing ->
                            case typed of
                                Just toMsg ->
                                    if String.length event.key == 1 && event.key /= " " && not event.ctrl && not event.meta && not event.alt then
                                        Decode.succeed { message = toMsg event.key, preventDefault = True, stopPropagation = True }

                                    else
                                        Decode.fail "unhandled key"

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


{-| A navigation key in the first moment after a list opened, before the search
box has the focus.
-}
type Move
    = MoveDown
    | MoveUp
    | MovePageDown
    | MovePageUp
    | MoveFirst
    | MoveLast
    | MoveChoose


{-| Keys on the trigger of a list that has just opened, before focus has reached
its search box (Elm moves it a frame later). What is typed in that moment still
belongs to the search, so it is not lost: characters and Backspace edit the text,
the arrows, Home, End and Page keys and Enter act on the list, Escape closes it,
and Tab goes on.
-}
onWindowKeys :
    { typed : String -> msg
    , backspace : msg
    , move : Move -> msg
    , close : msg
    , leave : msg
    }
    -> Html.Attribute msg
onWindowKeys bindings =
    Events.custom "keydown"
        (Decode.map3 (\event repeated inComposition -> ( event, repeated, inComposition ))
            Internal.keyEvent
            (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])
            composing
            |> Decode.andThen
                (\( event, repeated, composing_ ) ->
                    let
                        handled msg =
                            Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }
                    in
                    if event.ctrl || event.meta || event.alt then
                        Decode.fail "modifier"

                    else if composing_ then
                        Decode.fail "a key of an input method composition"

                    else
                        case event.key of
                            "Tab" ->
                                Decode.succeed { message = bindings.leave, preventDefault = False, stopPropagation = False }

                            "Escape" ->
                                handled bindings.close

                            "Enter" ->
                                handled (bindings.move MoveChoose)

                            "ArrowDown" ->
                                handled (bindings.move MoveDown)

                            "ArrowUp" ->
                                handled (bindings.move MoveUp)

                            "PageDown" ->
                                handled (bindings.move MovePageDown)

                            "PageUp" ->
                                handled (bindings.move MovePageUp)

                            "Home" ->
                                handled (bindings.move MoveFirst)

                            "End" ->
                                handled (bindings.move MoveLast)

                            "Backspace" ->
                                if repeated then
                                    Decode.fail "repeat"

                                else
                                    handled bindings.backspace

                            _ ->
                                if String.length event.key == 1 then
                                    handled (bindings.typed event.key)

                                else
                                    Decode.fail "unhandled key"
                )
        )



-- PARTS


{-| The transparent click-away layer around a popup. A click outside the popup
lands here (`close`); Escape anywhere inside sends `close` too and does not
reach a surrounding dialog.
-}
viewLayer : msg -> Html msg -> Html msg
viewLayer close popup =
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick close
        , onKeydown { handled = [ ( "Escape", close ) ], passive = [] }
        ]
        [ popup ]


{-| A mouse press anywhere in the popup except on its search box keeps keyboard
focus in the search box.
-}
holdSearchFocus : msg -> Html.Attribute msg
holdSearchFocus msg =
    Events.preventDefaultOn "mousedown"
        (Decode.at [ "target", "tagName" ] Decode.string
            |> Decode.andThen
                (\tag ->
                    if tag == "INPUT" then
                        Decode.fail "the search box takes the press itself"

                    else
                        Decode.succeed ( msg, True )
                )
        )


viewChevron : Html msg
viewChevron =
    Html.span [ Internal.cls [ "klar-select__chevron" ], Attr.attribute "aria-hidden" "true" ] [ Icon.view Icon.chevronDown ]


{-| The small x inside a trigger. Its click does not reach the trigger.
-}
viewClearButton : String -> msg -> Html msg
viewClearButton text msg =
    Html.button
        [ Internal.cls [ "klar-input__clear", "klar-select__clear" ]
        , Attr.type_ "button"
        , Attr.tabindex -1
        , Attr.attribute "aria-label" text
        , Attr.title text
        , Internal.onClickStop msg
        ]
        [ Icon.view Icon.close ]


{-| The search box at the top of a popup. It keeps the keyboard focus while the
user moves through the rows (`aria-activedescendant`).
-}
viewSearch :
    { id : String
    , controls : Maybe String
    , popup : String
    , query : String
    , placeholder : String
    , label : String
    , activeDescendant : Maybe String
    , onInput : String -> msg
    , keys : Html.Attribute msg
    , loading : Bool
    , loadingLabel : String
    , clearLabel : String
    , noop : msg
    }
    -> Html msg
viewSearch config =
    Html.div [ Internal.cls [ "klar-select__search" ] ]
        [ Html.span [ Internal.cls [ "klar-select__search-icon" ] ] [ Icon.view Icon.search ]
        , Html.input
            [ Internal.cls [ "klar-select__search-input" ]
            , Attr.id config.id
            , Attr.type_ "text"
            , Attr.value config.query
            , Attr.placeholder config.placeholder
            , Attr.attribute "role" "combobox"
            , Attr.attribute "aria-expanded" "true"
            , Attr.attribute "aria-haspopup" config.popup
            , Internal.attrMaybe (Attr.attribute "aria-controls") config.controls
            , Attr.attribute "aria-autocomplete" "list"
            , Attr.attribute "aria-label" config.label
            , Internal.attrMaybe (Attr.attribute "aria-activedescendant") config.activeDescendant
            , Attr.attribute "autocomplete" "off"
            , Attr.spellcheck False
            , Events.onInput config.onInput
            , config.keys
            ]
            []
        , -- Always in the page, so that its live region is there before the
          -- text "Loading" is (an idle slot is out of sight and takes no room).
          Html.span
            [ Internal.cls
                [ if config.loading then
                    "klar-select__search-spinner"

                  else
                    "klar-sr-only"
                ]
            ]
            [ Spinner.view [ Spinner.label config.loadingLabel, Spinner.loading config.loading ] ]
        , if config.loading then
            Html.text ""

          else if config.query /= "" then
            Html.button
                [ Internal.cls [ "klar-input__clear" ]
                , Attr.type_ "button"
                , Attr.tabindex -1
                , Attr.attribute "aria-label" config.clearLabel
                , Attr.title config.clearLabel
                , Internal.onMouseDownPrevent config.noop
                , Events.onClick (config.onInput "")
                ]
                [ Icon.view Icon.close ]

          else
            Html.text ""
        ]


{-| The status line under a list: counts on the left (announced politely to
screen readers), optional actions on the right.
-}
viewFooter : String -> List (Html msg) -> Html msg
viewFooter status actions =
    Html.div [ Internal.cls [ "klar-select__footer" ] ]
        [ Html.span
            [ Internal.cls [ "klar-select__status", "klar-tabular", "klar-truncate" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            ]
            [ Html.text status ]
        , if List.isEmpty actions then
            Html.text ""

          else
            Html.div [ Internal.cls [ "klar-select__actions" ] ] actions
        ]


{-| Placeholder rows while the data loads.
-}
viewSkeleton : Int -> Html msg
viewSkeleton count =
    Html.div [ Internal.cls [ "klar-select__skeleton" ], Attr.attribute "aria-hidden" "true" ]
        (List.range 0 (max 1 count - 1)
            |> List.map
                (\i ->
                    Html.div [ Internal.cls [ "klar-select__skeleton-row" ] ]
                        [ Skeleton.line (Maybe.withDefault 60 (List.head (List.drop (modBy 5 i) [ 72, 48, 84, 60, 40 ]))) ]
                )
        )


viewEmpty : Icon -> String -> Maybe String -> Html msg
viewEmpty icon title description =
    Html.div [ Internal.cls [ "klar-select__state" ] ]
        [ EmptyState.view
            (List.filterMap identity
                [ Just EmptyState.compact
                , Just (EmptyState.icon icon)
                , Just (EmptyState.title title)
                , Maybe.map EmptyState.description description
                ]
            )
        ]


{-| The message that retries a failed load, when a "Try again" button is on
screen: the problem must be worth retrying and the application must have said
what retrying means.
-}
retryFor : Remote.Problem -> Maybe msg -> Maybe msg
retryFor problem onRetry =
    if Remote.isRetryable problem then
        onRetry

    else
        Nothing


{-| Data that failed to load: a compact `ErrorState`, with "try again" when there
is something to retry. A mouse click on it does not take focus from the search
box, and any click sends `refocus`, so focus goes back to the search box when
the button is replaced by loading rows. Tab on the button sends `leave`.
-}
viewFailure :
    { locale : Locale
    , onRetry : Maybe msg
    , refocus : msg
    , leave : msg
    , noop : msg
    }
    -> Remote.Problem
    -> Html msg
viewFailure config problem =
    let
        retry =
            retryFor problem config.onRetry
    in
    Html.div
        [ Internal.cls [ "klar-select__state" ]
        , Internal.onMouseDownPrevent config.noop
        , Events.onClick config.refocus
        , Internal.attrIf (isJust retry) (onKeydown { handled = [], passive = [ ( "Tab", config.leave ) ] })
        ]
        [ ErrorState.view
            (List.filterMap identity
                [ Just ErrorState.compact
                , Just (ErrorState.locale config.locale)
                , Maybe.map ErrorState.onRetry retry
                ]
            )
            problem
        ]
