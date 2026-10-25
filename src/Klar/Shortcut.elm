module Klar.Shortcut exposing
    ( Shortcut, shortcut, inInputs, keysOf, groupOf, labelOf, firesInInputs, conflicts
    , Keys, char, function, escape, enter, tab, space, backspace, delete, home, end, pageUp, pageDown, up, down, left, right
    , mod, alt, shift, sequence
    , State, init, Msg, update, listen, subscription
    )

{-| Global keyboard shortcuts for the whole application, including sequences of
two keys such as `g` then `m`.

Use when: the application needs global keyboard shortcuts, including sequences of two keys.
Do not use when: a key only matters inside one component (use that component's own key handling).
Quick path: `init`, `listen`, `subscription`, `update`

A shortcut is the keys, a group and a label (which
[Klar.ShortcutHelp](Klar-ShortcutHelp) lists) and the message to send. Keep all
shortcuts in one list and give that list to `listen`, `subscription` and
`update`; `conflicts` finds the shortcuts in it that can never fire.

    import Klar.Shortcut as Shortcut

    shortcuts : List (Shortcut.Shortcut Msg)
    shortcuts =
        [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
            |> Shortcut.inInputs
        , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to orders" GoToOrders
        , Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp
        ]

**Keys** are values of the opaque type `Keys`, built from the keys themselves,
so a misspelled key name cannot happen. `char 'k'` is a letter, a digit or a
symbol (`char '?'`, `char '/'`, `char '+'`), and the named keys are `escape`,
`enter`, `tab`, `space`, `backspace`, `delete`, `home`, `end`, `pageUp`,
`pageDown`, the arrows `up`, `down`, `left` and `right`, and `function 2` for F2.
`mod` is Ctrl (or Cmd on a Mac) and is put around keys: `mod (char 'k')`,
`shift enter`, `alt up`, `mod (shift (char 'n'))`. `shift` counts for letters and
named keys but not for symbols: the key for a question mark is simply
`char '?'`. A **sequence** is several keys one after the other:
`sequence [ char 'g', char 'o' ]` means `g`, then `o`, each within 1.2 seconds of
the one before. A key that is a shortcut by itself cannot also start a sequence.

**Wiring**, once, at the root of the application:

    -- model
    { shortcuts : Shortcut.State } -- Shortcut.init

    -- view: the root element listens, and takes focus so that it keeps it
    Html.div
        [ Shortcut.listen ShortcutMsg shortcuts model.shortcuts
        , Attr.tabindex -1
        ]
        [ page ]

    -- subscriptions
    Shortcut.subscription ShortcutMsg shortcuts model.shortcuts

    -- update
    ShortcutMsg m ->
        let
            ( state, fired ) =
                Shortcut.update shortcuts m model.shortcuts

            next =
                { model | shortcuts = state }
        in
        case fired of
            Just msg ->
                update msg next

            Nothing ->
                ( next, Cmd.none )

`listen` is an attribute of an element, so that it can stop the browser's own
action for the keys (Ctrl+K, `/`); with the `host` of [Klar.Modal](Klar-Modal)
put it in the `attributes` of the host, which can take focus already.
`subscription` catches the key presses that happen while nothing has focus, so
that shortcuts keep working after a dialog has closed.

**When shortcuts fire**: while the user types in a text field, a text area, a
select or any editable element, a shortcut fires only if it is marked
`inInputs`, also when it uses Ctrl, Alt or Cmd. Keys pressed inside a modal
dialog ([Klar.Modal](Klar-Modal), [Klar.Drawer](Klar-Drawer) or the
[command palette](Klar-CommandPalette)) or inside an open popup (a menu, a
context menu, the list of a select), but not in a field, only reach shortcuts
with Ctrl, Alt or Cmd (not Ctrl+A or Cmd+A, which select everything) and those
marked `inInputs`: a sequence like `g o` must not take the user away behind an
open dialog. `Escape` in a popup is the popup's own and never fires a shortcut.
Everywhere else every shortcut fires.

**Keys that are already taken** never fire a shortcut: a key that a component
handled (an arrow in a menu, `Escape` that closes a dialog, `Enter` in the
command palette) prevents its default action, and a shortcut ignores a key press
whose default action was prevented. The `Enter` or `Escape` that ends the
composition of an input method (Japanese, Chinese, Korean) is never a shortcut
either. Holding a key down does not repeat a shortcut.

**Keyboards**: a symbol typed with AltGr (on a German keyboard `[` is AltGr and

1.  counts as the plain symbol, not as Ctrl+Alt, and in a field it is text that
    never fires a shortcut. With Ctrl, Alt or Cmd held, a letter or digit is also
    found by the key's place on the keyboard, so `mod (char 'k')` fires on a Russian
    or Greek layout, and `alt (char 'a')` with Option and A on a Mac (where the key
    types "å"). On a Mac `mod` is Cmd; Ctrl counts as `mod` too, except in a text
    field, where Ctrl+A, Ctrl+E and Ctrl+K keep their editing meaning. To show the
    keys, give the same `Keys` to [Klar.Kbd](Klar-Kbd), which writes them for a PC
    or a Mac.


# Defining shortcuts

@docs Shortcut, shortcut, inInputs, keysOf, groupOf, labelOf, firesInInputs, conflicts


# Keys

@docs Keys, char, function, escape, enter, tab, space, backspace, delete, home, end, pageUp, pageDown, up, down, left, right
@docs mod, alt, shift, sequence


# Wiring

@docs State, init, Msg, update, listen, subscription

-}

import Browser.Events
import Html exposing (Attribute)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Internal.Keys as Notation


{-| One keyboard shortcut: keys, a group and a label for the help sheet, and the
message to send. The type is opaque, so that it can grow; make one with `shortcut`
and read it with `keysOf`, `groupOf` and `labelOf`.
-}
type Shortcut msg
    = Shortcut (Entry msg)


type alias Entry msg =
    { keys : String
    , group : String
    , label : String
    , msg : msg
    , inInputs : Bool
    }


unwrap : Shortcut msg -> Entry msg
unwrap (Shortcut entry) =
    entry


{-| A shortcut. The arguments are the keys, the group, the label and the message
to send. The group and the label are for [Klar.ShortcutHelp](Klar-ShortcutHelp),
so write them for people.

    Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette

    Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to orders" GoToOrders

`mod` is Ctrl, or Cmd on a Mac. The help sheet, the command palette and
[Klar.Kbd](Klar-Kbd) write it for the `platform` they are given.

-}
shortcut : Keys -> String -> String -> msg -> Shortcut msg
shortcut (Notation.Keys keys) group label msg =
    Shortcut { keys = keys, group = group, label = label, msg = msg, inInputs = False }


{-| Lets the shortcut fire while the user types in a field (a text field, a text
area, a select or an editable element), and inside a modal dialog. Without it
the shortcut does not fire while the user types, not even with Ctrl, Alt or Cmd,
and inside a dialog only combinations with Ctrl, Alt or Cmd (except Ctrl+A)
fire. Use it for keys that make sense while typing, like `escape` or
`mod (char 'k')`. A character typed with AltGr never fires a shortcut in a field,
with or without this.

    Shortcut.shortcut Shortcut.escape "Navigation" "Close" CloseMenu
        |> Shortcut.inInputs

-}
inInputs : Shortcut msg -> Shortcut msg
inInputs (Shortcut entry) =
    Shortcut { entry | inInputs = True }


{-| The keys of a shortcut.
-}
keysOf : Shortcut msg -> Keys
keysOf (Shortcut entry) =
    Notation.Keys entry.keys


{-| The heading a shortcut is listed under in the help sheet.
-}
groupOf : Shortcut msg -> String
groupOf (Shortcut entry) =
    entry.group


{-| What a shortcut does, as written for the help sheet.
-}
labelOf : Shortcut msg -> String
labelOf (Shortcut entry) =
    entry.label


{-| Whether the shortcut was marked with `inInputs`.
-}
firesInInputs : Shortcut msg -> Bool
firesInInputs (Shortcut entry) =
    entry.inInputs


{-| The shortcuts of a list that can never fire, each with the label of the one
that takes its keys first: a second shortcut with the same keys (unless only the
second is marked `inInputs`, which then still fires in fields), and a sequence
that begins with the keys of another shortcut (`g` alone hides `g o`). An empty
list means that every shortcut can fire, which a test of the application can
check when it puts lists together:

    Shortcut.conflicts (History.shortcuts Locale.en historyMessages ++ shortcuts) == []

-}
conflicts : List (Shortcut msg) -> List { keys : Keys, label : String, hiddenBy : String }
conflicts wrapped =
    let
        entries =
            List.map unwrap wrapped

        hides earlier later =
            let
                first =
                    Notation.steps earlier.keys

                second =
                    Notation.steps later.keys
            in
            if List.isEmpty first then
                -- an empty sequence is never pressed
                False

            else if first == second then
                earlier.inInputs || not later.inInputs

            else
                List.length first < List.length second && List.take (List.length first) second == first

        check ( index, later ) =
            entries
                |> List.indexedMap Tuple.pair
                |> List.filter (\( other, earlier ) -> other /= index && (other < index || List.length (Notation.steps earlier.keys) < List.length (Notation.steps later.keys)) && hides earlier later)
                |> List.head
                |> Maybe.map (\( _, earlier ) -> { keys = Notation.Keys later.keys, label = later.label, hiddenBy = earlier.label })
    in
    entries
        |> List.indexedMap Tuple.pair
        |> List.filterMap check



-- KEYS


{-| The keys of a shortcut: one key, a key with modifiers, or a sequence of them.
Build them with `char`, the named keys, `mod`, `alt`, `shift` and `sequence`, and
show them with [Klar.Kbd](Klar-Kbd). The type is opaque: two `Keys` can be
compared with `==`.
-}
type alias Keys =
    Notation.Keys


{-| A letter, a digit or a symbol: `char 'k'`, `char '?'`, `char '/'`. Letters are
not case sensitive (`char 'K'` is `char 'k'`); use `shift` for the shifted key.
-}
char : Char -> Keys
char c =
    case c of
        ' ' ->
            Notation.Keys "space"

        _ ->
            Notation.Keys (String.fromChar (Char.toLower c))


{-| A function key, `function 1` to `function 12`. A number outside that range is
taken as the nearest one.
-}
function : Int -> Keys
function n =
    Notation.Keys ("f" ++ String.fromInt (clamp 1 12 n))


{-| The Escape key.
-}
escape : Keys
escape =
    Notation.Keys "esc"


{-| The Enter key.
-}
enter : Keys
enter =
    Notation.Keys "enter"


{-| The Tab key.
-}
tab : Keys
tab =
    Notation.Keys "tab"


{-| The space bar.
-}
space : Keys
space =
    Notation.Keys "space"


{-| The Backspace key.
-}
backspace : Keys
backspace =
    Notation.Keys "backspace"


{-| The Delete key.
-}
delete : Keys
delete =
    Notation.Keys "delete"


{-| The Home key.
-}
home : Keys
home =
    Notation.Keys "home"


{-| The End key.
-}
end : Keys
end =
    Notation.Keys "end"


{-| The Page Up key.
-}
pageUp : Keys
pageUp =
    Notation.Keys "pageup"


{-| The Page Down key.
-}
pageDown : Keys
pageDown =
    Notation.Keys "pagedown"


{-| The up arrow.
-}
up : Keys
up =
    Notation.Keys "up"


{-| The down arrow.
-}
down : Keys
down =
    Notation.Keys "down"


{-| The left arrow.
-}
left : Keys
left =
    Notation.Keys "left"


{-| The right arrow.
-}
right : Keys
right =
    Notation.Keys "right"


{-| Ctrl, or Cmd on a Mac, held with the keys: `mod (char 'k')`. On a sequence it
applies to every key of the sequence.
-}
mod : Keys -> Keys
mod =
    withModifier "mod"


{-| Alt (Option on a Mac) held with the keys: `alt up`.
-}
alt : Keys -> Keys
alt =
    withModifier "alt"


{-| Shift held with the keys: `shift enter`, `mod (shift (char 'n'))`. It counts for
letters and named keys, not for symbols.
-}
shift : Keys -> Keys
shift =
    withModifier "shift"


{-| Several keys one after the other, each within 1.2 seconds of the one before:
`sequence [ char 'g', char 'o' ]`. A sequence of one is that key, and an empty
list is a key that is never pressed.
-}
sequence : List Keys -> Keys
sequence list =
    Notation.Keys (String.join " " (List.map (\(Notation.Keys keys) -> keys) list))


withModifier : String -> Keys -> Keys
withModifier modifier (Notation.Keys keys) =
    Notation.Keys (keys |> String.words |> List.map (\step -> Notation.normalizeStep (modifier ++ "+" ++ step)) |> String.join " ")



-- STATE


{-| What the shortcuts hold on to between key presses: the keys of a sequence
that is waiting for its next key, and when the last of them was pressed. Make one
with `init` and keep it in your model.
-}
type State
    = State { pending : List String, at : Float }


{-| The state to start with, when no sequence is under way.
-}
init : State
init =
    State { pending = [], at = 0 }


{-| A message from `listen` or `subscription`. Wrap it in one of your own
messages and pass it to `update`.
-}
type Msg
    = Fired Int String
    | Pending (List String) Float
    | Cleared


sequenceTimeout : Float
sequenceTimeout =
    1200


{-| Applies a message from `listen` or `subscription`. The result is the new
state and, when a shortcut fired, the message of that shortcut: handle it like
any other message of your application (see the wiring at the top of this page).
Give it the same list of shortcuts as `listen`. When two shortcuts have the same
keys, the one that fires is the first of the list that may fire where the key
was pressed (in a field, the first one marked `inInputs`).
-}
update : List (Shortcut msg) -> Msg -> State -> ( State, Maybe msg )
update wrapped msg (State state) =
    case msg of
        Fired index keys ->
            let
                shortcuts =
                    List.map unwrap wrapped

                -- the shortcut that `decide` chose, unless the list changed since
                chosen =
                    case List.drop index shortcuts of
                        found :: _ ->
                            if found.keys == keys then
                                Just found

                            else
                                firstWithKeys keys shortcuts

                        [] ->
                            firstWithKeys keys shortcuts
            in
            ( State { state | pending = [] }, Maybe.map .msg chosen )

        Pending keys time ->
            ( State { pending = keys, at = time }, Nothing )

        Cleared ->
            ( State { state | pending = [] }, Nothing )


firstWithKeys : String -> List (Entry msg) -> Maybe (Entry msg)
firstWithKeys keys shortcuts =
    shortcuts
        |> List.filter (\candidate -> candidate.keys == keys)
        |> List.head



-- EVENTS


type alias KeyInfo =
    { key : String
    , code : String
    , ctrl : Bool
    , meta : Bool
    , alt : Bool
    , shift : Bool
    , repeat : Bool
    , time : Float
    , targetTag : String
    , editable : Bool
    , inModal : Bool
    , inPopup : Bool
    , handled : Bool
    , composing : Bool
    , mac : Bool
    }


keyInfo : Decoder KeyInfo
keyInfo =
    Decode.succeed KeyInfo
        |> andMap (Decode.field "key" Decode.string)
        |> andMap (optional "code" Decode.string "")
        |> andMap (Decode.field "ctrlKey" Decode.bool)
        |> andMap (Decode.field "metaKey" Decode.bool)
        |> andMap (Decode.field "altKey" Decode.bool)
        |> andMap (Decode.field "shiftKey" Decode.bool)
        |> andMap (optional "repeat" Decode.bool False)
        |> andMap (optional "timeStamp" Decode.float 0)
        |> andMap (Decode.oneOf [ Decode.at [ "target", "tagName" ] Decode.string, Decode.succeed "" ])
        |> andMap (Decode.oneOf [ Decode.at [ "target", "isContentEditable" ] Decode.bool, Decode.succeed False ])
        |> andMap (Decode.oneOf [ Decode.field "target" (insideModal 0), Decode.succeed False ])
        |> andMap (Decode.oneOf [ Decode.field "target" (insidePopup 0), Decode.succeed False ])
        -- a component inside (a menu, a dialog, the palette) has handled the key
        |> andMap (optional "defaultPrevented" Decode.bool False)
        |> andMap composing
        |> andMap onMac


andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)


optional : String -> Decoder a -> a -> Decoder a
optional name decoder fallback =
    Decode.oneOf [ Decode.field name decoder, Decode.succeed fallback ]


{-| The press belongs to the composition of an input method (Japanese, Chinese,
Korean): the Enter that confirms the text or the Escape that cancels it.
Browsers say so with `isComposing`, and older ones with the `keyCode` 229.
-}
composing : Decoder Bool
composing =
    Decode.map2 (||)
        (optional "isComposing" Decode.bool False)
        (optional "keyCode" Decode.int 0 |> Decode.map ((==) 229))


{-| Is the keyboard a Mac's? Read from the window the event belongs to; an event
without one (a test) is a PC.
-}
onMac : Decoder Bool
onMac =
    Decode.map2 (++)
        (Decode.oneOf [ Decode.at [ "view", "navigator", "userAgentData", "platform" ] Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.at [ "view", "navigator", "platform" ] Decode.string, Decode.succeed "" ])
        |> Decode.map
            (\platform ->
                List.any (\word -> String.contains word (String.toLower platform)) [ "mac", "iphone", "ipad", "ipod" ]
            )


{-| Is the node inside a modal dialog (`aria-modal="true"`: a `Modal`, a
`Drawer`, the command palette)? Walks up through `parentElement`.
-}
insideModal : Int -> Decoder Bool
insideModal depth =
    if depth > 40 then
        Decode.succeed False

    else
        Decode.oneOf
            [ Decode.field "ariaModal" Decode.string
                |> Decode.andThen
                    (\value ->
                        if value == "true" then
                            Decode.succeed True

                        else
                            Decode.fail "not modal"
                    )
            , Decode.field "parentElement" (Decode.lazy (\_ -> insideModal (depth + 1)))
            , Decode.succeed False
            ]


{-| Is the node inside an open popup (a menu, a context menu, the list of a
select or a date picker: `.klar-layer` or `.klar-popup`)? Walks up through
`parentElement`.
-}
insidePopup : Int -> Decoder Bool
insidePopup depth =
    if depth > 40 then
        Decode.succeed False

    else
        Decode.oneOf
            [ Decode.field "className" Decode.string
                |> Decode.andThen
                    (\names ->
                        let
                            tokens =
                                String.words names
                        in
                        if List.member "klar-layer" tokens || List.member "klar-popup" tokens then
                            Decode.succeed True

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "parentElement" (Decode.lazy (\_ -> insidePopup (depth + 1)))
            , Decode.succeed False
            ]


{-| An attribute for the focusable root element of the application (give it
`tabindex -1`). It hears the key presses of everything inside the element and
prevents the browser's own action for the ones that trigger a shortcut, so
Ctrl+K does not reach the browser. A key that only starts a sequence is not
prevented, and a key that an element inside has already handled (its default
action is prevented) is left alone.

    Html.div
        [ Shortcut.listen ShortcutMsg shortcuts model.shortcuts
        , Attr.tabindex -1
        ]
        [ page ]

-}
listen : (Msg -> msg) -> List (Shortcut msg) -> State -> Attribute msg
listen toMsg shortcuts state =
    Events.preventDefaultOn "keydown"
        (keyInfo
            |> Decode.andThen
                (\info ->
                    case decide shortcuts state info of
                        Just ( m, prevent ) ->
                            Decode.succeed ( toMsg m, prevent )

                        Nothing ->
                            Decode.fail "no shortcut"
                )
        )


{-| Catches the key presses that happen while nothing has focus (the target is
the page itself), so that shortcuts keep working after a dialog has closed and
focus was lost. Key presses on a focused element are left to `listen`.
-}
subscription : (Msg -> msg) -> List (Shortcut msg) -> State -> Sub msg
subscription toMsg shortcuts state =
    Browser.Events.onKeyDown
        (keyInfo
            |> Decode.andThen
                (\info ->
                    if info.targetTag == "BODY" || info.targetTag == "HTML" || info.targetTag == "" then
                        case decide shortcuts state info of
                            Just ( m, _ ) ->
                                Decode.succeed (toMsg m)

                            Nothing ->
                                Decode.fail "no shortcut"

                    else
                        Decode.fail "handled by listen"
                )
        )


{-| A name for a key press, and whether it was made with Ctrl, Alt or Cmd (and
not just typed with AltGr).
-}
type alias Press =
    { step : String
    , modified : Bool
    }


{-| What a key press means: the message to send, and whether the browser's
default action should be prevented.
-}
decide : List (Shortcut msg) -> State -> KeyInfo -> Maybe ( Msg, Bool )
decide wrapped (State state) info =
    if info.repeat || info.handled || info.composing || isModifierOnly info.key then
        Nothing

    else
        let
            entries =
                List.indexedMap Tuple.pair (List.map unwrap wrapped)

            typing =
                info.editable || isFormField info.targetTag

            text =
                typedAsText info

            -- The press as its key names it, and then, with Ctrl, Alt or Cmd
            -- held, by the place of the key: Ctrl and the K key is `mod+k` on a
            -- Russian layout too, Option and A is `alt+a` on a Mac.
            presses =
                { step = canonical typing info, modified = (info.ctrl || info.meta || info.alt) && not text }
                    :: (case physical typing info of
                            Just step ->
                                [ { step = step, modified = True } ]

                            Nothing ->
                                []
                       )

            -- While the user types in a field only the shortcuts marked
            -- `inInputs` fire (with or without Ctrl, Alt or Cmd), and never for
            -- a character typed with AltGr: that is text. Plain keys are also
            -- for the page and not for a dialog or a popup, where `g m` would
            -- take the user away from it: there only combinations with Ctrl,
            -- Alt or Cmd get through, and Ctrl+A stays "select all". Escape in
            -- a popup closes the popup.
            allowed press candidate =
                if info.inPopup && press.step == "esc" then
                    False

                else if typing then
                    candidate.inInputs && not text

                else if info.inModal || info.inPopup then
                    candidate.inInputs || (press.modified && press.step /= "mod+a")

                else
                    True

            -- the steps already pressed, unless the sequence has timed out
            earlier =
                if info.time - state.at < sequenceTimeout || info.time == 0 then
                    state.pending

                else
                    []

            outcome press =
                let
                    usable =
                        List.filter (\( _, candidate ) -> allowed press candidate) entries

                    sofar =
                        earlier ++ [ press.step ]

                    matching wanted =
                        usable
                            |> List.filter (\( _, candidate ) -> Notation.steps candidate.keys == wanted)
                            |> List.head

                    -- does a longer sequence begin with these steps?
                    continues stepsPressed =
                        usable
                            |> List.any
                                (\( _, candidate ) ->
                                    let
                                        wanted =
                                            Notation.steps candidate.keys
                                    in
                                    List.length wanted > List.length stepsPressed && List.take (List.length stepsPressed) wanted == stepsPressed
                                )

                    sequenceMatch =
                        if List.isEmpty earlier then
                            Nothing

                        else
                            matching sofar
                in
                case ( sequenceMatch, matching [ press.step ] ) of
                    ( Just ( index, found ), _ ) ->
                        Just ( Fired index found.keys, True )

                    ( Nothing, Just ( index, found ) ) ->
                        Just ( Fired index found.keys, True )

                    ( Nothing, Nothing ) ->
                        if continues sofar then
                            Just ( Pending sofar info.time, False )

                        else if continues [ press.step ] then
                            -- a wrong key in the middle of a sequence: start over with this one
                            Just ( Pending [ press.step ] info.time, False )

                        else
                            Nothing
        in
        case firstJust outcome presses of
            Just found ->
                Just found

            Nothing ->
                if List.isEmpty state.pending then
                    Nothing

                else
                    Just ( Cleared, False )


firstJust : (a -> Maybe b) -> List a -> Maybe b
firstJust f list =
    case list of
        [] ->
            Nothing

        first :: rest ->
            case f first of
                Just found ->
                    Just found

                Nothing ->
                    firstJust f rest


isFormField : String -> Bool
isFormField tag =
    tag == "INPUT" || tag == "TEXTAREA" || tag == "SELECT"


isModifierOnly : String -> Bool
isModifierOnly key =
    key == "Control" || key == "Shift" || key == "Alt" || key == "Meta" || key == "AltGraph" || key == "CapsLock" || key == "OS" || key == "Fn"


{-| Text typed through the AltGr layer, like `[` on a German keyboard (AltGr and
8), or through Option on a Mac ("å" for Option and A, a dead key for Option and
N). Windows reports AltGr as Ctrl and Alt together, and the Mac's Option key as
Alt; the character that comes out is all the user meant.
-}
typedAsText : KeyInfo -> Bool
typedAsText info =
    info.alt
        && (info.key
                == "Dead"
                || (String.length info.key == 1 && not (isAsciiLetterOrDigit info.key) && info.key /= " ")
           )


isAsciiLetterOrDigit : String -> Bool
isAsciiLetterOrDigit key =
    case String.toList key of
        [ c ] ->
            Char.isAlphaNum c

        _ ->
            False


{-| The canonical name of a key press: `mod+k`, `shift+n`, `esc`, `?`.
-}
canonical : Bool -> KeyInfo -> String
canonical typing info =
    let
        key =
            keyName info.key

        isLetter =
            String.length key == 1 && Char.isAlpha (String.toList key |> List.head |> Maybe.withDefault ' ')

        shiftMatters =
            info.shift && (isLetter || String.length key > 1)

        altGr =
            typedAsText info
    in
    String.concat
        [ modifiersOf typing altGr info
        , if shiftMatters then
            "shift+"

          else
            ""
        , key
        ]


{-| The press named by the place of its key (`KeyK`, `Digit1`), for a letter or a
digit pressed with Ctrl, Alt or Cmd whose key is not that letter or digit: a key
of another alphabet, a symbol of an AZERTY digit row, or what Option makes of it
on a Mac.
-}
physical : Bool -> KeyInfo -> Maybe String
physical typing info =
    if (info.ctrl || info.meta || info.alt) && not (isAsciiLetterOrDigit info.key) then
        placeOf info.code
            |> Maybe.map
                (\key ->
                    modifiersOf typing False info
                        ++ (if info.shift then
                                "shift+"

                            else
                                ""
                           )
                        ++ key
                )

    else
        Nothing


{-| `"KeyK"` is `k`, `"Digit1"` is `1`.
-}
placeOf : String -> Maybe String
placeOf code =
    if String.length code == 4 && String.startsWith "Key" code then
        Just (String.toLower (String.dropLeft 3 code))

    else if String.length code == 6 && String.startsWith "Digit" code then
        Just (String.dropLeft 5 code)

    else
        Nothing


{-| `mod+` and `alt+` for the modifiers held. On a Mac `mod` is Cmd, and Ctrl
also counts as `mod` except in a field, where Ctrl+A, Ctrl+E and Ctrl+K edit
the text: there it is a modifier of its own that no shortcut uses.
-}
modifiersOf : Bool -> Bool -> KeyInfo -> String
modifiersOf typing altGr info =
    let
        ctrl =
            info.ctrl && not altGr

        ctrlApart =
            ctrl && info.mac && typing
    in
    String.concat
        [ if ctrlApart then
            "ctrl+"

          else
            ""
        , if (ctrl && not ctrlApart) || info.meta then
            "mod+"

          else
            ""
        , if info.alt && not altGr then
            "alt+"

          else
            ""
        ]


keyName : String -> String
keyName key =
    case key of
        "Escape" ->
            "esc"

        " " ->
            "space"

        "ArrowUp" ->
            "up"

        "ArrowDown" ->
            "down"

        "ArrowLeft" ->
            "left"

        "ArrowRight" ->
            "right"

        _ ->
            String.toLower key
