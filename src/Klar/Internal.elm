module Klar.Internal exposing
    ( KeyEvent
    , attrIf
    , attrMaybe
    , classes
    , cls
    , densityAttr
    , densitySuffix
    , ensureVisible
    , focus
    , focusChain
    , focusFirst
    , hasLatinLetters
    , heading
    , kbd
    , kbdCombo
    , keyEvent
    , markDot
    , noAttr
    , nonEmpty
    , normalize
    , onClickPrevent
    , onClickStop
    , onKeys
    , onKeysPassive
    , onLayerKeys
    , onMouseDownPrevent
    , pageStartId
    , percentEncode
    , px
    , sanitizeId
    , sizeSuffix
    , stopClick
    , styleVars
    , toneSuffix
    , unhandled
    , viewIf
    , viewMaybe
    )

{-| Small helpers shared by the components in `Klar.*`.

Application code should not need this module. Components use it for class
building, keyboard handling and focus management.

-}

import Browser.Dom as Dom
import Dict exposing (Dict)
import Html exposing (Attribute, Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Color as Color exposing (Color)
import Klar.Theme as Theme exposing (Density(..), Size(..), Tone(..))
import Task



-- ATTRIBUTES


{-| `class` from a list of names; empty names are dropped.

    cls [ "klar-button", "klar-button--primary" ]

-}
cls : List String -> Attribute msg
cls names =
    Attr.class (String.join " " (List.filter (\name -> name /= "") names))


{-| Like `classList`, but order and duplicates are the caller's problem.
-}
classes : List ( String, Bool ) -> Attribute msg
classes =
    Attr.classList


{-| An attribute that does nothing. Useful in `if` branches.
-}
noAttr : Attribute msg
noAttr =
    Attr.classList []


attrIf : Bool -> Attribute msg -> Attribute msg
attrIf condition attribute =
    if condition then
        attribute

    else
        noAttr


attrMaybe : (a -> Attribute msg) -> Maybe a -> Attribute msg
attrMaybe toAttr maybe =
    case maybe of
        Just value ->
            toAttr value

        Nothing ->
            noAttr


{-| The mark that the density of the settings leaves on an element, which the
stylesheet follows: nothing for `Normal`.
-}
densityAttr : Density -> Attribute msg
densityAttr value =
    case value of
        Compact ->
            Attr.attribute "data-klar-density" "compact"

        Normal ->
            noAttr

        Comfortable ->
            Attr.attribute "data-klar-density" "comfortable"


{-| Sets CSS custom properties / inline declarations in one `style` attribute.
Elm's `Html.Attributes.style` cannot set custom properties, this can.

    styleVars [ ( "--klar-col-w", "120px" ) ]

-}
styleVars : List ( String, String ) -> Attribute msg
styleVars declarations =
    Attr.attribute "style"
        (declarations
            |> List.map (\( name, value ) -> name ++ ":" ++ value)
            |> String.join ";"
        )


px : Int -> String
px n =
    String.fromInt n ++ "px"


{-| Does the text contain letters from U+00C0 to U+017F (å, æ, ø, é, ü, š, ł ...)?
Text without them needs no accent folding.
-}
hasLatinLetters : String -> Bool
hasLatinLetters text =
    String.any
        (\char ->
            let
                code =
                    Char.toCode char
            in
            code >= 0xC0 && code <= 0x017F
        )
        text


{-| Lowercases a text and replaces the letters with diacritics by plain letters, so
"é" and "e", "ü" and "u", "š" and "s" or "ł" and "l" compare equal. It covers the
Latin-1 and the Latin Extended-A letters; Norwegian "æ" becomes "a" and "ø" "o", as
a Norwegian types them on a foreign keyboard. The result has as many characters as
the input, so a match position in the normalized text is the same position in the
original.
-}
normalize : String -> String
normalize text =
    -- a capital I with a dot would be lowered to two characters (i and a combining dot)
    foldAccents (String.toLower (String.replace "İ" "I" text))


foldAccents : String -> String
foldAccents text =
    if String.any (\char -> Char.toCode char >= 0xDF && Char.toCode char <= 0x017F) text then
        String.map
            (\char ->
                case Dict.get (Char.toCode char) accentTable of
                    Just plain ->
                        plain

                    Nothing ->
                        char
            )
            text

    else
        text


accentTable : Dict Int Char
accentTable =
    [ ( 'a', "àáâãäåāăąæ" )
    , ( 'c', "çćĉċč" )
    , ( 'd', "ďđð" )
    , ( 'e', "èéêëēĕėęě" )
    , ( 'g', "ĝğġģ" )
    , ( 'h', "ĥħ" )
    , ( 'i', "ìíîïĩīĭįı" )
    , ( 'j', "ĵ" )
    , ( 'k', "ķĸ" )
    , ( 'l', "ĺļľŀł" )
    , ( 'n', "ñńņňŉŋ" )
    , ( 'o', "òóôõöøōŏőœ" )
    , ( 'r', "ŕŗř" )
    , ( 's', "śŝşšßſ" )
    , ( 't', "ţťŧþ" )
    , ( 'u', "ùúûüũūŭůűų" )
    , ( 'w', "ŵ" )
    , ( 'y', "ýÿŷ" )
    , ( 'z', "źżž" )
    ]
        |> List.concatMap (\( plain, accented ) -> List.map (\char -> ( Char.toCode char, plain )) (String.toList accented))
        |> Dict.fromList


{-| `Url.percentEncode`, written in Elm, for text that may hold half of an emoji.
`encodeURIComponent`, which `Url.percentEncode` calls, throws on such a lone
surrogate, and an exception in `view` ends the whole program. Here it is written
as the replacement character U+FFFD, like a browser does when it decodes bad text.
-}
percentEncode : String -> String
percentEncode text =
    String.foldr (\char rest -> encodeCodePoint (Char.toCode char) ++ rest) "" text


encodeCodePoint : Int -> String
encodeCodePoint code =
    if isUnreserved code then
        String.fromChar (Char.fromCode code)

    else if isNaN (toFloat code) || code < 0 || code > 0x0010FFFF || (code >= 0xD800 && code <= 0xDFFF) then
        -- half of an emoji: a lone high surrogate has no code at all (NaN), a lone low
        -- surrogate has a code in the surrogate range
        "%EF%BF%BD"

    else if code < 0x80 then
        percentByte code

    else if code < 0x0800 then
        percentByte (0xC0 + code // 64) ++ percentByte (0x80 + modBy 64 code)

    else if code < 0x00010000 then
        percentByte (0xE0 + code // 4096) ++ percentByte (0x80 + modBy 64 (code // 64)) ++ percentByte (0x80 + modBy 64 code)

    else
        percentByte (0xF0 + code // 262144) ++ percentByte (0x80 + modBy 64 (code // 4096)) ++ percentByte (0x80 + modBy 64 (code // 64)) ++ percentByte (0x80 + modBy 64 code)


{-| The characters `encodeURIComponent` leaves as they are.
-}
isUnreserved : Int -> Bool
isUnreserved code =
    (code >= 0x30 && code <= 0x39)
        || (code >= 0x41 && code <= 0x5A)
        || (code >= 0x61 && code <= 0x7A)
        || List.member code [ 0x2D, 0x5F, 0x2E, 0x21, 0x7E, 0x2A, 0x27, 0x28, 0x29 ]


percentByte : Int -> String
percentByte byte =
    "%" ++ hexDigit (byte // 16) ++ hexDigit (modBy 16 byte)


hexDigit : Int -> String
hexDigit n =
    String.slice n (n + 1) "0123456789ABCDEF"



-- VIEW HELPERS


viewIf : Bool -> Html msg -> Html msg
viewIf condition html =
    if condition then
        html

    else
        Html.text ""


{-| The small dot that marks an option or a tag: a color from the data when there
is one, else the color of a tone, else nothing. It is for the eye only (`aria-hidden`):
the label carries the meaning.
-}
markDot : Maybe Tone -> Maybe Color -> Html msg
markDot tone color =
    case ( color, tone ) of
        ( Just value, _ ) ->
            Html.span
                [ cls [ "klar-mark" ]
                , Attr.attribute "style" ("--klar-mark:" ++ Color.toHex value)
                , Attr.attribute "aria-hidden" "true"
                ]
                []

        ( Nothing, Just value ) ->
            Html.span
                [ cls [ "klar-mark", "klar-mark--" ++ toneSuffix value ]
                , Attr.attribute "aria-hidden" "true"
                ]
                []

        ( Nothing, Nothing ) ->
            Html.text ""


viewMaybe : (a -> Html msg) -> Maybe a -> Html msg
viewMaybe toHtml maybe =
    case maybe of
        Just value ->
            toHtml value

        Nothing ->
            Html.text ""


nonEmpty : String -> Maybe String
nonEmpty text =
    if String.isEmpty (String.trim text) then
        Nothing

    else
        Just text


{-| The heading element for a level from 1 to 6. Components clamp the level they
are given, so anything else counts as 3.
-}
heading : Int -> List (Attribute msg) -> List (Html msg) -> Html msg
heading level =
    case level of
        1 ->
            Html.h1

        2 ->
            Html.h2

        4 ->
            Html.h4

        5 ->
            Html.h5

        6 ->
            Html.h6

        _ ->
            Html.h3


{-| A text as a valid HTML id, without losing anything: ASCII letters, digits and `-`
stay as they are, a space becomes `__`, and every other character becomes `_`, its
code point in lowercase hex, and `_`. (It is not always a CSS identifier as it
stands: `1st` and `-1` need escaping in a selector.)

    sanitizeId "billing-address" -- "billing-address"

    sanitizeId "Customer name" -- "Customer__name"

    sanitizeId "Ørsta" -- "_d8_rsta"

    sanitizeId "order_id" -- "order_5f_id"

Two different texts never give the same id (the encoding can be read back: after a
`_` comes either a second `_` or hex digits and a `_`), so keys that differ only in a
space, a punctuation mark or a letter outside ASCII still name two elements, and an
`aria-controls` made from one key names that key's element. (Half of an emoji, which
has no code point, becomes `_fffd_`, as the replacement character does.) This holds
for one text: an id joined from several parts with `-` (`id ++ "-tab-" ++ key`) can
still meet another such id, because `-` stays as it is; join the parts of an id with
`__` where two keys could otherwise meet.

-}
sanitizeId : String -> String
sanitizeId raw =
    if String.all (\char -> isIdChar (Char.toCode char)) raw then
        raw

    else
        String.foldr (\char rest -> idPart (Char.toCode char) ++ rest) "" raw


{-| ASCII letters, digits and `-`: the characters an id keeps as they are.
-}
isIdChar : Int -> Bool
isIdChar code =
    (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A) || code == 0x2D


idPart : Int -> String
idPart code =
    if isIdChar code then
        String.fromChar (Char.fromCode code)

    else if code == 0x20 then
        "__"

    else if isNaN (toFloat code) || code < 0 || code > 0x0010FFFF then
        -- a lone high surrogate has no code at all (NaN)
        "_fffd_"

    else
        "_" ++ lowerHex code ++ "_"


lowerHex : Int -> String
lowerHex n =
    if n < 16 then
        String.slice n (n + 1) "0123456789abcdef"

    else
        lowerHex (n // 16) ++ String.slice (modBy 16 n) (modBy 16 n + 1) "0123456789abcdef"



-- EVENTS


onClickStop : msg -> Attribute msg
onClickStop msg =
    Events.stopPropagationOn "click" (Decode.succeed ( msg, True ))


{-| A click handler that swallows the click so it does not bubble to a
click-away layer.
-}
stopClick : msg -> Attribute msg
stopClick =
    onClickStop


onClickPrevent : msg -> Attribute msg
onClickPrevent msg =
    Events.preventDefaultOn "click" (Decode.succeed ( msg, True ))


{-| Keeps focus where it is when the mouse goes down (e.g. on an option in a
list while the search input has focus).
-}
onMouseDownPrevent : msg -> Attribute msg
onMouseDownPrevent msg =
    Events.preventDefaultOn "mousedown" (Decode.succeed ( msg, True ))


{-| A key press: `key` as in `KeyboardEvent.key` (`"Enter"`, `"a"`, `"ArrowDown"`)
and the modifiers that were held.
-}
type alias KeyEvent =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , shift : Bool
    , alt : Bool
    }


{-| Reads a `keydown` (or `keyup`) event. It fails, so the handler sends nothing and
the browser default happens, for a key that belongs to the composition of an input
method (Japanese, Chinese, Korean and others): while the user composes, Enter
confirms the text and Escape cancels it, and neither may save, close or pick.
`onKeys`, `onKeysPassive`, `onLayerKeys` and every component decoder built on this
one have the guard; a decoder that reads `key` itself does not, so build key
decoders on this one.
-}
keyEvent : Decoder KeyEvent
keyEvent =
    composing
        |> Decode.andThen
            (\isComposing ->
                if isComposing then
                    Decode.fail "a key of an input method composition"

                else
                    Decode.map5 KeyEvent
                        (Decode.field "key" Decode.string)
                        (Decode.field "ctrlKey" Decode.bool)
                        (Decode.field "metaKey" Decode.bool)
                        (Decode.field "shiftKey" Decode.bool)
                        (Decode.field "altKey" Decode.bool)
            )


{-| Is the key part of an input method composition? Browsers say so with
`isComposing`; Safari sends the Enter that ends a composition with `isComposing`
false and the key code 229, which every browser uses for the keys an input method
takes. An event that has neither field (a test, an old browser) is not composing.
-}
composing : Decoder Bool
composing =
    Decode.map2 (||)
        (Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "keyCode" Decode.int |> Decode.map (\code -> code == 229), Decode.succeed False ])


{-| Only for an event that no element inside has handled yet: the decoder fails when
`defaultPrevented` is true. This is how keys are layered. A control that handles a
key itself (a search box that clears its text on Escape, an inline edit that cancels,
a popup that closes) prevents its default, with `onKeys` or `preventDefaultOn`; the
keydown then bubbles on, and an overlay, a container or a page-level shortcut that
listens further out reads it through `unhandled` and leaves it alone.

    -- a dialog closes on an Escape that nothing inside it took
    Events.preventDefaultOn "keydown"
        (Internal.unhandled Internal.keyEvent
            |> Decode.andThen
                (\event ->
                    if event.key == "Escape" then
                        Decode.succeed ( Close, True )

                    else
                        Decode.fail "another key"
                )
        )

The layer of a popup takes its Escape with `onLayerKeys`, which prevents it. A key
bound with `onKeysPassive` keeps its default, so it still reaches the containers as
not handled. An event without the field (a test) counts as not handled.

-}
unhandled : Decoder a -> Decoder a
unhandled decoder =
    Decode.oneOf [ Decode.field "defaultPrevented" Decode.bool, Decode.succeed False ]
        |> Decode.andThen
            (\handled ->
                if handled then
                    Decode.fail "handled by an element inside"

                else
                    decoder
            )


{-| "Ctrl+Shift+K" style description of a key press. Shift is only added for
non-printable keys (Tab, arrows ...), since `"A"` already implies shift.
-}
keyName : KeyEvent -> String
keyName event =
    let
        printable =
            String.length event.key == 1
    in
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
        , if event.shift && not printable then
            "Shift+"

          else
            ""
        , event.key
        ]


keysDecoder : Bool -> List ( String, msg ) -> Decoder ( msg, Bool )
keysDecoder prevent bindings =
    keyEvent
        |> Decode.andThen
            (\event ->
                case binding event bindings of
                    Just msg ->
                        Decode.succeed ( msg, prevent )

                    Nothing ->
                        Decode.fail "unhandled key"
            )


{-| The message bound to a key press: by its name (`"Ctrl+Enter"`), or, with Ctrl or
Meta held (not both), by its name with `Mod+` for that modifier, so `"Mod+a"` is
Ctrl+A on Windows and Linux and Cmd+A on a Mac. A letter is matched as
`KeyboardEvent.key` gives it, without a `Shift+`: `"Mod+a"` without Shift, `"Mod+A"`
with Shift.
-}
binding : KeyEvent -> List ( String, msg ) -> Maybe msg
binding event bindings =
    case lookup (keyName event) bindings of
        Just msg ->
            Just msg

        Nothing ->
            if event.ctrl /= event.meta then
                lookup ("Mod+" ++ keyName { event | ctrl = False, meta = False }) bindings

            else
                Nothing


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


{-| Keyboard bindings on `keydown`. The browser default is prevented for the
keys that match, which also tells the containers further out that the key is
taken (`unhandled`). Key names follow `KeyboardEvent.key`, with modifiers in the
order Ctrl, Meta, Alt, Shift: `"ArrowDown"`, `"Enter"`, `"Escape"`, `" "`,
`"Shift+Tab"`, `"Ctrl+Enter"`. `Mod+` is Ctrl or Meta (Cmd on a Mac): `"Mod+s"`. A
letter or another printable key is named as `KeyboardEvent.key` gives it, with no
`Shift+`: `"Mod+a"` is Ctrl+A, `"Mod+A"` is Ctrl+Shift+A. A key of an input method
composition matches nothing (`keyEvent`).
-}
onKeys : List ( String, msg ) -> Attribute msg
onKeys bindings =
    Events.preventDefaultOn "keydown" (keysDecoder True bindings)


{-| Same as `onKeys` but the default action still happens (use for Tab). A key of
an input method composition matches nothing here either.
-}
onKeysPassive : List ( String, msg ) -> Attribute msg
onKeysPassive bindings =
    Events.preventDefaultOn "keydown" (keysDecoder False bindings)


{-| The keys of the click-away layer of a popup (`klar-layer`), in one place.
Escape sends the first message and takes the key (its default is prevented), so a
dialog or a drawer around the popup, which reads keys through `unhandled`, leaves
that Escape alone and stays open. The other bindings (Tab and Shift+Tab, and for a
menu Enter and Space) keep their default, so Tab still moves the focus on and Enter
still presses the focused item. A key that an element inside the popup has handled
already (a search box that clears its text on Escape) is left to it: the next
Escape closes the popup.

    Internal.onLayerKeys (toMsg Close)
        [ ( "Tab", toMsg CloseQuiet ), ( "Shift+Tab", toMsg CloseQuiet ) ]

-}
onLayerKeys : msg -> List ( String, msg ) -> Attribute msg
onLayerKeys escape bindings =
    Events.preventDefaultOn "keydown"
        (unhandled keyEvent
            |> Decode.andThen
                (\event ->
                    if keyName event == "Escape" then
                        Decode.succeed ( escape, True )

                    else
                        case binding event bindings of
                            Just msg ->
                                Decode.succeed ( msg, False )

                            Nothing ->
                                Decode.fail "not a key of the layer"
                )
        )



-- FOCUS & SCROLL


{-| Focus an element by id. The given message is sent when it is done
(whether it worked or not).
-}
focus : String -> msg -> Cmd msg
focus id done =
    Task.attempt (\_ -> done) (Dom.focus id)


{-| A way back for the focus: focus the first element of the list that exists, and
send the message when it is done. The list always ends with `pageStartId` (added
when it is not the last id already), which an `AppShell` and an `Overlay.host` draw
and which can take focus, so closing something whose opener and fallbacks are all
gone leaves focus at the start of the page and not on `body`. Empty ids are skipped.

Every id must name an element that can take focus: a control that is not disabled,
or an element with a `tabindex` (-1 is enough). Elm cannot see where focus went: an
element that exists but cannot take focus (a `tr`, a `div` without `tabindex`, a
disabled button) ends the search all the same, and focus stays on `body`.

-}
focusFirst : List String -> msg -> Cmd msg
focusFirst ids done =
    case focusChain ids of
        [] ->
            Cmd.none

        first :: rest ->
            List.foldl
                (\id task -> Task.onError (\_ -> Dom.focus id) task)
                (Dom.focus first)
                rest
                |> Task.attempt (\_ -> done)


{-| The ids `focusFirst` tries, in order: the given ones that are not empty, then
`pageStartId` once at the end.
-}
focusChain : List String -> List String
focusChain ids =
    List.filter (\id -> id /= "" && id /= pageStartId) ids ++ [ pageStartId ]


{-| The DOM id of the start of the page content: the content area of an
`AppShell`, the page of an `Overlay.host`. It can take focus (`tabindex` -1). It is
where focus goes when a dialog closes and neither its opener nor any element that
had focus before it opened exists, so the next `Tab` starts in the content and not
at the top of the window.
-}
pageStartId : String
pageStartId =
    "klar-page-start"


{-| Scroll a fixed-row-height list so that row `index` is fully visible.
-}
ensureVisible : { listId : String, index : Int, rowHeight : Float } -> msg -> Cmd msg
ensureVisible { listId, index, rowHeight } done =
    Dom.getViewportOf listId
        |> Task.andThen
            (\viewport ->
                let
                    top =
                        toFloat index * rowHeight

                    bottom =
                        top + rowHeight

                    current =
                        viewport.viewport.y

                    next =
                        if top < current then
                            top

                        else if bottom > current + viewport.viewport.height then
                            bottom - viewport.viewport.height

                        else
                            current
                in
                if next == current then
                    Task.succeed ()

                else
                    Dom.setViewportOf listId 0 next
            )
        |> Task.attempt (\_ -> done)



-- CLASS NAME MODIFIERS


{-| The modifier of a tone in the class names of the stylesheet.

    toneSuffix Warning -- "warning"

-}
toneSuffix : Tone -> String
toneSuffix tone =
    case tone of
        Neutral ->
            "neutral"

        Primary ->
            "primary"

        Info ->
            "info"

        Success ->
            "success"

        Warning ->
            "warning"

        Danger ->
            "danger"


{-| The modifier of a size in the class names of the stylesheet: `"sm"`, `"md"`
or `"lg"`.
-}
sizeSuffix : Size -> String
sizeSuffix size =
    case size of
        Small ->
            "sm"

        Medium ->
            "md"

        Large ->
            "lg"


{-| The modifier of a density in the class names of the stylesheet:
`"compact"`, `"normal"` or `"comfortable"`.
-}
densitySuffix : Density -> String
densitySuffix density =
    case density of
        Compact ->
            "compact"

        Normal ->
            "normal"

        Comfortable ->
            "comfortable"



-- KEY CAPS


{-| A single key cap (a `kbd` element), such as "Esc", for the hints the components draw.
-}
kbd : String -> Html msg
kbd key =
    Html.kbd [ cls [ "klar-kbd" ] ] [ Html.text key ]


{-| Several key caps in a row, for a keyboard shortcut.
-}
kbdCombo : List String -> Html msg
kbdCombo keys =
    Html.span [ cls [ "klar-kbd-combo" ] ] (List.map kbd keys)
