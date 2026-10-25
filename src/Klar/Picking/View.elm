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
    , overscan
    , plain
    , renderedRange
    , retryFor
    , rowHeight
    , staleRetry
    , viewChevron
    , viewClearButton
    , viewEmpty
    , viewFailure
    , viewFooter
    , viewLayer
    , viewNotice
    , viewSearch
    , viewSkeleton
    , whenEmpty
    , whenEmptyFresh
    )

{-| Tree-picker keyboard handling, retry focus and freshness notices. The select
and tree families share DOM primitives through `Klar.Internal.ChoicePopup`;
tree navigation stays here, including arrow keys that move the caret while the
search box has text to move it in.

They use the CSS classes of the select family, so a tree field looks like a
select.

Not for application code.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.ErrorState as ErrorState
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.ChoicePopup as Popup
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Internal.Window as Window
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Settings exposing (Settings)
import Klar.VirtualList as VirtualList



-- ROWS


{-| The height in pixels of a row in the lists of the picking components. The
stylesheet gives `.klar-select__option` rows inside a virtual list the same
height at every density, so the arithmetic and the drawing agree.
-}
rowHeight : Int
rowHeight =
    32


{-| How many rows the lists draw above and below the ones in view. The lists are
given it (`VirtualList.overscan`), and `renderedRange` uses it, so the two agree.
-}
overscan : Int
overscan =
    6


{-| The rows that a list of `visibleRows` rows of `rowHeight` draws at its scroll
position, from the first up to (not including) the second: the arithmetic of
`VirtualList.view` (`Klar.Internal.Window`), so that `aria-activedescendant` only
ever names a row that is in the page.
-}
renderedRange : { visibleRows : Int, count : Int } -> VirtualList.State -> ( Int, Int )
renderedRange list state =
    let
        drawn =
            Window.window { overscan = overscan, chunk = 1 }
                { rowHeight = rowHeight
                , viewport = min (list.visibleRows * rowHeight) (list.count * rowHeight)
                , count = list.count
                }
                (VirtualList.scrollTop state)
    in
    ( drawn.first, drawn.end )


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
        , rest event
        ]


rest : Internal.KeyEvent -> String
rest event =
    String.concat
        [ if event.alt then
            "Alt+"

          else
            ""
        , if event.shift && String.length event.key /= 1 then
            "Shift+"

          else
            ""
        , event.key
        ]


{-| The names a key answers to: the exact one (`Ctrl+a`, `Meta+a`), and with
exactly one of Ctrl and Meta also `Mod+a`, so that a binding written with `Mod+` is
Ctrl on Windows and Linux and Cmd on a Mac.
-}
keyNames : Internal.KeyEvent -> List String
keyNames event =
    if event.ctrl /= event.meta then
        [ keyName event, "Mod+" ++ rest event ]

    else
        [ keyName event ]


findBinding : List String -> Caret -> List (Binding msg) -> Maybe msg
findBinding names c bindings =
    case bindings of
        [] ->
            Nothing

        (Binding condition key msg) :: others ->
            if List.member key names && holds condition c then
                Just msg

            else
                findBinding names c others


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
                        names =
                            keyNames event
                    in
                    if c.composing then
                        Decode.fail "a key of an input method composition"

                    else
                        case findBinding names c bindings.handled of
                            Just msg ->
                                Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }

                            Nothing ->
                                case findBinding names c bindings.passive of
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
                        names =
                            if repeated && event.key == "Backspace" then
                                List.map (\name -> "Repeat+" ++ name) (keyNames event)

                            else
                                keyNames event
                    in
                    case lookup names bindings of
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


lookup : List String -> List ( String, a ) -> Maybe a
lookup names bindings =
    case bindings of
        [] ->
            Nothing

        ( name, value ) :: others ->
            if List.member name names then
                Just value

            else
                lookup names others


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


viewLayer : msg -> Html msg -> Html msg
viewLayer close popup =
    Popup.viewLayer (onKeydown { handled = [ ( "Escape", close ) ], passive = [] }) close popup


holdSearchFocus : msg -> Html.Attribute msg
holdSearchFocus =
    Popup.holdSearchFocus


viewChevron : Html msg
viewChevron =
    Popup.viewChevron


viewClearButton : String -> msg -> Html msg
viewClearButton =
    Popup.viewClearButton


viewSearch :
    { id : String
    , controls : Maybe String
    , popup : String
    , query : String
    , placeholder : String
    , label : String
    , activeDescendant : Maybe String
    , onInput : String -> msg
    , onFocus : msg
    , keys : Html.Attribute msg
    , loading : Bool
    , loadingLabel : String
    , clearLabel : String
    , noop : msg
    }
    -> Html msg
viewSearch config =
    Popup.search config
        [ Internal.cls [ "klar-select__search-input" ]
        , Events.onFocus config.onFocus
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


viewFooter : String -> List (Html msg) -> Html msg
viewFooter =
    Popup.viewFooter


viewSkeleton : Int -> Html msg
viewSkeleton =
    Popup.viewSkeleton


viewEmpty : Icon -> String -> Maybe String -> Html msg
viewEmpty =
    Popup.viewEmpty


retryFor : Remote.Problem -> Maybe msg -> Maybe msg
retryFor =
    Popup.retryFor


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


{-| The retry of data that is old, when trying again could help: what the Try
again button of the marker for old data sends.
-}
staleRetry : Freshness -> Maybe msg -> Maybe msg
staleRetry freshness onRetry =
    case freshness of
        Freshness.Stale value ->
            retryFor value.problem onRetry

        _ ->
            Nothing


{-| The marker for old data above the rows (`Freshness.notice`), in a wrapper
that is always there and keeps focus safe: a mouse press on it does not take
focus, a click on its retry (also Enter on the button) sends `refocus`, so focus
is back in the search or filter box before the button goes away, and Tab on the
button sends `leave` when it is the last stop of a popup.
-}
viewNotice :
    { locale : Locale
    , settings : Settings
    , onRetry : Maybe msg
    , refocus : msg
    , leave : Maybe msg
    , noop : msg
    }
    -> Freshness
    -> Html msg
viewNotice config freshness =
    let
        retry =
            staleRetry freshness config.onRetry
    in
    Html.div
        [ Internal.cls [ "klar-picking__notice" ]
        , Internal.onMouseDownPrevent config.noop
        , Internal.attrIf (isJust retry) (Events.onClick config.refocus)
        , case ( retry, config.leave ) of
            ( Just _, Just leave ) ->
                onKeydown { handled = [], passive = [ ( "Tab", leave ) ] }

            _ ->
                Internal.attrIf False (Attr.title "")
        ]
        [ Freshness.notice
            { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
            freshness
        ]
