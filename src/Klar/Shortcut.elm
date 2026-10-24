module Klar.Shortcut exposing
    ( Shortcut, shortcut, inInputs, keysOf, groupOf, labelOf, firesInInputs
    , Keys, char, function, escape, enter, tab, space, backspace, delete, home, end, pageUp, pageDown, up, down, left, right
    , mod, alt, shift, sequence
    , State, init, Msg, update, listen, subscription
    , keycaps
    )

{-| Global keyboard shortcuts for the whole application, including sequences of
two keys such as `g` then `m`.

Use when: the application needs global keyboard shortcuts, including sequences of two keys.
Do not use when: a key only matters inside one component (use that component's own key handling).
Quick path: `init`, `listen`, `subscription`, `update`

A shortcut is the keys, a group and a label (which
[Klar.ShortcutHelp](Klar-ShortcutHelp) lists) and the message to send. Keep all
shortcuts in one list and give that list to `listen`, `subscription` and
`update`.

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
[command palette](Klar-CommandPalette)), but not in a field, only reach
shortcuts with Ctrl, Alt or Cmd (not Ctrl+A or Cmd+A, which select everything)
and those marked `inInputs`: a sequence like `g o` must not take the user away
behind an open dialog. Everywhere else every shortcut fires. Holding a key down
does not repeat a shortcut. A symbol typed with AltGr (on a German keyboard `[`
is AltGr and 8) counts as the plain symbol, not as Ctrl+Alt, and in a field it is
text that never fires a shortcut.


# Defining shortcuts

@docs Shortcut, shortcut, inInputs, keysOf, groupOf, labelOf, firesInInputs


# Keys

@docs Keys, char, function, escape, enter, tab, space, backspace, delete, home, end, pageUp, pageDown, up, down, left, right
@docs mod, alt, shift, sequence


# Wiring

@docs State, init, Msg, update, listen, subscription


# Showing keys

@docs keycaps

-}

import Browser.Events
import Html exposing (Attribute)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)


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

`mod` is Ctrl, or Cmd on a Mac, depending on the keyboard. The help sheet and
`keycaps` always write it as "Ctrl".

-}
shortcut : Keys -> String -> String -> msg -> Shortcut msg
shortcut (Keys keys) group label msg =
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
    Keys entry.keys


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



-- KEYS


{-| The keys of a shortcut: one key, a key with modifiers, or a sequence of them.
Build them with `char`, the named keys, `mod`, `alt`, `shift` and `sequence`.
-}
type Keys
    = Keys String


{-| A letter, a digit or a symbol: `char 'k'`, `char '?'`, `char '/'`. Letters are
not case sensitive (`char 'K'` is `char 'k'`); use `shift` for the shifted key.
-}
char : Char -> Keys
char c =
    case c of
        ' ' ->
            Keys "space"

        _ ->
            Keys (String.fromChar (Char.toLower c))


{-| A function key, `function 1` to `function 12`. A number outside that range is
taken as the nearest one.
-}
function : Int -> Keys
function n =
    Keys ("f" ++ String.fromInt (clamp 1 12 n))


{-| The Escape key.
-}
escape : Keys
escape =
    Keys "esc"


{-| The Enter key.
-}
enter : Keys
enter =
    Keys "enter"


{-| The Tab key.
-}
tab : Keys
tab =
    Keys "tab"


{-| The space bar.
-}
space : Keys
space =
    Keys "space"


{-| The Backspace key.
-}
backspace : Keys
backspace =
    Keys "backspace"


{-| The Delete key.
-}
delete : Keys
delete =
    Keys "delete"


{-| The Home key.
-}
home : Keys
home =
    Keys "home"


{-| The End key.
-}
end : Keys
end =
    Keys "end"


{-| The Page Up key.
-}
pageUp : Keys
pageUp =
    Keys "pageup"


{-| The Page Down key.
-}
pageDown : Keys
pageDown =
    Keys "pagedown"


{-| The up arrow.
-}
up : Keys
up =
    Keys "up"


{-| The down arrow.
-}
down : Keys
down =
    Keys "down"


{-| The left arrow.
-}
left : Keys
left =
    Keys "left"


{-| The right arrow.
-}
right : Keys
right =
    Keys "right"


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
    Keys (String.join " " (List.map (\(Keys keys) -> keys) list))


withModifier : String -> Keys -> Keys
withModifier modifier (Keys keys) =
    Keys (keys |> String.words |> List.map (\step -> normalizeStep (modifier ++ "+" ++ step)) |> String.join " ")



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
    = Fired String
    | Pending (List String) Float
    | Cleared


sequenceTimeout : Float
sequenceTimeout =
    1200


{-| Applies a message from `listen` or `subscription`. The result is the new
state and, when a shortcut fired, the message of that shortcut: handle it like
any other message of your application (see the wiring at the top of this page).
Give it the same list of shortcuts as `listen`.
-}
update : List (Shortcut msg) -> Msg -> State -> ( State, Maybe msg )
update wrapped msg (State state) =
    let
        shortcuts =
            List.map unwrap wrapped
    in
    case msg of
        Fired keys ->
            ( State { state | pending = [] }
            , shortcuts
                |> List.filter (\candidate -> candidate.keys == keys)
                |> List.head
                |> Maybe.map .msg
            )

        Pending keys time ->
            ( State { pending = keys, at = time }, Nothing )

        Cleared ->
            ( State { state | pending = [] }, Nothing )



-- EVENTS


type alias KeyInfo =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , alt : Bool
    , shift : Bool
    , repeat : Bool
    , time : Float
    , targetTag : String
    , editable : Bool
    , inModal : Bool
    }


keyInfo : Decoder KeyInfo
keyInfo =
    Decode.map8
        (\key ctrl meta altKey shiftKey repeat time ( tag, editable, modal ) ->
            { key = key
            , ctrl = ctrl
            , meta = meta
            , alt = altKey
            , shift = shiftKey
            , repeat = repeat
            , time = time
            , targetTag = tag
            , editable = editable
            , inModal = modal
            }
        )
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        (Decode.field "altKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "timeStamp" Decode.float, Decode.succeed 0 ])
        (Decode.map3 (\tag editable modal -> ( tag, editable, modal ))
            (Decode.oneOf [ Decode.at [ "target", "tagName" ] Decode.string, Decode.succeed "" ])
            (Decode.oneOf [ Decode.at [ "target", "isContentEditable" ] Decode.bool, Decode.succeed False ])
            (Decode.oneOf [ Decode.field "target" (insideModal 0), Decode.succeed False ])
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


{-| An attribute for the focusable root element of the application (give it
`tabindex -1`). It hears the key presses of everything inside the element and
prevents the browser's own action for the ones that trigger a shortcut, so
Ctrl+K does not reach the browser. A key that only starts a sequence is not
prevented.

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


{-| What a key press means: the message to send, and whether the browser's
default action should be prevented.
-}
decide : List (Shortcut msg) -> State -> KeyInfo -> Maybe ( Msg, Bool )
decide wrapped (State state) info =
    let
        shortcuts =
            List.map unwrap wrapped
    in
    if info.repeat || isModifierOnly info.key then
        Nothing

    else
        let
            pressed =
                canonical info

            hasModifier =
                (info.ctrl || info.meta || info.alt) && not (typedWithAltGr info)

            typing =
                info.editable || isFormField info.targetTag

            -- While the user types in a field only the shortcuts marked
            -- `inInputs` fire (with or without Ctrl, Alt or Cmd), and never for
            -- a character typed with AltGr: that is text. Plain keys are also
            -- for the page and not for a dialog, where `g m` would take the
            -- user away from it: inside a dialog only combinations with Ctrl,
            -- Alt or Cmd get through, and Ctrl+A stays "select all".
            allowed candidate =
                if typing then
                    candidate.inInputs && not (typedWithAltGr info)

                else if info.inModal then
                    candidate.inInputs || (hasModifier && pressed /= "mod+a")

                else
                    True

            usable =
                List.filter allowed shortcuts

            -- the steps already pressed, unless the sequence has timed out
            earlier =
                if info.time - state.at < sequenceTimeout || info.time == 0 then
                    state.pending

                else
                    []

            sofar =
                earlier ++ [ pressed ]

            sequenceMatch =
                if List.isEmpty earlier then
                    Nothing

                else
                    usable
                        |> List.filter (\candidate -> steps candidate.keys == sofar)
                        |> List.head

            singleMatch =
                usable
                    |> List.filter (\candidate -> steps candidate.keys == [ pressed ])
                    |> List.head

            -- does a longer sequence begin with these steps?
            continues stepsPressed =
                usable
                    |> List.any
                        (\candidate ->
                            let
                                wanted =
                                    steps candidate.keys
                            in
                            List.length wanted > List.length stepsPressed && List.take (List.length stepsPressed) wanted == stepsPressed
                        )
        in
        case ( sequenceMatch, singleMatch ) of
            ( Just found, _ ) ->
                Just ( Fired found.keys, True )

            ( Nothing, Just found ) ->
                Just ( Fired found.keys, True )

            ( Nothing, Nothing ) ->
                if continues sofar then
                    Just ( Pending sofar info.time, False )

                else if continues [ pressed ] then
                    -- a wrong key in the middle of a sequence: start over with this one
                    Just ( Pending [ pressed ] info.time, False )

                else if not (List.isEmpty state.pending) then
                    Just ( Cleared, False )

                else
                    Nothing


isFormField : String -> Bool
isFormField tag =
    tag == "INPUT" || tag == "TEXTAREA" || tag == "SELECT"


isModifierOnly : String -> Bool
isModifierOnly key =
    key == "Control" || key == "Shift" || key == "Alt" || key == "Meta" || key == "AltGraph" || key == "CapsLock"


{-| A symbol typed through the AltGr layer, like `[` on a German keyboard
(AltGr and 8). Windows reports AltGr as Ctrl and Alt together, and the Mac's
Option key as Alt; the character that comes out is all the user meant.
-}
typedWithAltGr : KeyInfo -> Bool
typedWithAltGr info =
    info.alt
        && String.length info.key
        == 1
        && not (Char.isAlphaNum (String.toList info.key |> List.head |> Maybe.withDefault 'a'))
        && info.key
        /= " "


{-| The canonical name of a key press: `mod+k`, `shift+n`, `esc`, `?`.
-}
canonical : KeyInfo -> String
canonical info =
    let
        key =
            keyName info.key

        isLetter =
            String.length key == 1 && Char.isAlpha (String.toList key |> List.head |> Maybe.withDefault ' ')

        shiftMatters =
            info.shift && (isLetter || String.length key > 1)

        altGr =
            typedWithAltGr info
    in
    String.concat
        [ if (info.ctrl && not altGr) || info.meta then
            "mod+"

          else
            ""
        , if info.alt && not altGr then
            "alt+"

          else
            ""
        , if shiftMatters then
            "shift+"

          else
            ""
        , key
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


{-| `"g m"` -> `[ "g", "m" ]`; `"mod+k"` -> `[ "mod+k" ]`.
-}
steps : String -> List String
steps keys =
    keys
        |> String.words
        |> List.map normalizeStep


normalizeStep : String -> String
normalizeStep original =
    let
        step =
            String.toLower original

        parts =
            String.split "+" step
                |> List.filter (\part -> part /= "")
                |> List.map modifierName

        isModifier part =
            part == "mod" || part == "alt" || part == "shift"

        key =
            -- the plus key itself: "+", "mod++", "shift++"
            if step == "+" || String.endsWith "++" step then
                "+"

            else
                parts |> List.filter (not << isModifier) |> List.reverse |> List.head |> Maybe.withDefault ""

        has modifier =
            List.member modifier parts
    in
    String.concat
        [ if has "mod" then
            "mod+"

          else
            ""
        , if has "alt" then
            "alt+"

          else
            ""
        , if has "shift" then
            "shift+"

          else
            ""
        , key
        ]


{-| Other names for the modifiers: `ctrl` and `cmd` are `mod`, `option` is `alt`. A
modifier that is not known would otherwise be taken for the key and swallowed.
-}
modifierName : String -> String
modifierName part =
    case part of
        "ctrl" ->
            "mod"

        "control" ->
            "mod"

        "cmd" ->
            "mod"

        "command" ->
            "mod"

        "meta" ->
            "mod"

        "option" ->
            "alt"

        _ ->
            part


{-| Key caps as text, one list per step of the sequence, for a place that needs the
names of the keys. To draw them, give the `Keys` to `Kbd.view` of [Klar.Kbd](Klar-Kbd).

    Shortcut.keycaps (Shortcut.mod (Shortcut.char 'k')) == [ [ "Ctrl", "K" ] ]

    Shortcut.keycaps (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'm' ]) == [ [ "G" ], [ "M" ] ]

    Shortcut.keycaps (Shortcut.char '?') == [ [ "?" ] ]

    Shortcut.keycaps (Shortcut.mod (Shortcut.char '+')) == [ [ "Ctrl", "+" ] ]

`mod` means Ctrl, or Cmd on a Mac, depending on the keyboard, but it is always
written as "Ctrl" here. The arrow keys are shown as arrows.

-}
keycaps : Keys -> List (List String)
keycaps (Keys keys) =
    steps keys
        |> List.map (\step -> List.map capName (stepParts step))


{-| The modifiers and the key of a step, as `steps` normalizes it: `"mod+k"` is
`[ "mod", "k" ]`, `"mod++"` is `[ "mod", "+" ]` and `"+"` is `[ "+" ]`.
-}
stepParts : String -> List String
stepParts step =
    if step == "+" then
        [ "+" ]

    else if String.endsWith "++" step then
        (String.dropRight 2 step |> String.split "+" |> List.filter (\part -> part /= "")) ++ [ "+" ]

    else
        String.split "+" step |> List.filter (\part -> part /= "")


capName : String -> String
capName part =
    case part of
        "mod" ->
            "Ctrl"

        "alt" ->
            "Alt"

        "shift" ->
            "Shift"

        "esc" ->
            "Esc"

        "enter" ->
            "Enter"

        "space" ->
            "Space"

        "tab" ->
            "Tab"

        "up" ->
            "↑"

        "down" ->
            "↓"

        "left" ->
            "←"

        "right" ->
            "→"

        other ->
            String.toUpper other
