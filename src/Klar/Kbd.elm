module Klar.Kbd exposing
    ( view, key, toString
    , Attribute, platform, locale, small, inline
    , Platform, mac, pc, platformFromUserAgent
    )

{-| Keyboard keys as key caps, for hints and documentation: "Ctrl K",
"Shift Enter", or a sequence such as "G then O".

Use when: a hint or help text must show a keyboard shortcut as key caps.
Do not use when: you need to listen to the shortcut (as `Klar.Shortcut`) or list all shortcuts (as `Klar.ShortcutHelp`).

    import Klar.Kbd as Kbd
    import Klar.Shortcut as Shortcut

    -- the same value that Shortcut.shortcut listens to
    openPalette : Shortcut.Keys
    openPalette =
        Shortcut.mod (Shortcut.char 'k')

    Kbd.view [] openPalette

    Kbd.view [ Kbd.small ] (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])

The keys are the typed [Klar.Shortcut](Klar-Shortcut) `Keys`, so the hint that
the application shows and the shortcut that it listens to are one value, and a
key is never written as a string. `Shortcut.mod` is Ctrl on most keyboards and
Cmd on a Mac. Plain Elm cannot tell which keyboard the user has, so it is
`platform`: `pc` by default (Ctrl, Alt, Shift) or `mac` (the symbols for Cmd,
Option and Shift, in the order a Mac writes them). The application can read
`navigator.userAgent` in its flags and give it to `platformFromUserAgent`.

**Screen readers** do not read the key caps, which are decoration. They get one
phrase instead, in the language of `locale`: "Control plus K", "Shift plus
Enter", "G then O", "Command plus question mark". The symbols for Cmd and Option
on a Mac are read by name.

Use `view` next to a label ("Search Ctrl K"), in the text of a help page
(`inline`), or in a [Klar.Tooltip](Klar-Tooltip). The hint of a
[Klar.Menu](Klar-Menu) item and the shortcut of a tooltip are plain text:
`toString` writes the same keys as a `String` for them.

    Menu.item "Duplicate" Duplicate
        |> Menu.withHint (Kbd.toString [ Kbd.platform model.platform ] duplicateKeys)

This module only shows keys. The shortcut itself is made and listened to with
[Klar.Shortcut](Klar-Shortcut), and [Klar.ShortcutHelp](Klar-ShortcutHelp) lists
all of them.

A key that [Klar.Shortcut](Klar-Shortcut) has no value for (`Fn`, `Insert`, a
mouse "Click") is a plain text with `key`. It is shown and read exactly as it is
written, never translated, and `platform` does not change it.


# Keys

@docs view, key, toString


# Attributes

@docs Attribute, platform, locale, small, inline


# Platform

@docs Platform, mac, pc, platformFromUserAgent

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Shortcut as Shortcut exposing (Keys)



-- ATTRIBUTES


{-| A setting of the key caps. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. Keys send no messages, so the
type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { platform : Platform
    , locale : Locale
    , look : Look
    }


type Look
    = Normal
    | Small
    | Inline


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { platform = Pc, locale = Locale.default, look = Normal }
        attributes


{-| Which keyboard to write the keys for: `pc` (the default) or `mac`. Make one
with `pc`, `mac` or `platformFromUserAgent`.
-}
type Platform
    = Pc
    | Mac


{-| Windows, Linux and everything that is not a Mac: Ctrl, Alt and Shift are
written as words. This is the default.
-}
pc : Platform
pc =
    Pc


{-| A Mac (and an iPhone or iPad with a keyboard): the `mod` key is Cmd and is
shown as ⌘, Alt is Option (⌥) and Shift is ⇧. Enter, Tab, Backspace and Delete
are shown as their symbols as well, and the modifiers come before the key in the
order a Mac writes them (⌥ ⇧ ⌘).
-}
mac : Platform
mac =
    Mac


{-| Reads the platform from the text of `navigator.userAgent` or
`navigator.platform`, which the application passes in as a flag: anything that
names a Mac, an iPhone, an iPad or an iPod is `mac`, everything else (also an
empty text) is `pc`. The text is only a guess about the keyboard, and a user can
change it, so use it for hints and nothing else.

    -- index.html:  Elm.Main.init({ flags: { userAgent: navigator.userAgent } })
    Kbd.platformFromUserAgent flags.userAgent

-}
platformFromUserAgent : String -> Platform
platformFromUserAgent text =
    let
        lower =
            String.toLower text
    in
    if List.any (\word -> String.contains word lower) [ "mac", "iphone", "ipad", "ipod" ] then
        Mac

    else
        Pc


{-| The keyboard to write the keys for. The default is `pc`.

    Kbd.view [ Kbd.platform Kbd.mac ] (Shortcut.mod (Shortcut.char 'k'))

-}
platform : Platform -> Attribute
platform value =
    Attribute (\config -> { config | platform = value })


{-| The language of the text that screen readers get and of the word between the
steps of a sequence ("then"). The default is `Locale.default`, which is
`Locale.en`. The caps themselves (`Ctrl`, `K`) are the same in every language.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| Compact caps (16px) for a menu, a tooltip or a field that shows its shortcut
at the end. The default is 20px.
-}
small : Attribute
small =
    Attribute (\config -> { config | look = Small })


{-| Caps that follow the size of the surrounding text, for a key in a sentence
or a paragraph: they do not make the line taller. This replaces `small`, and the
other way round.
-}
inline : Attribute
inline =
    Attribute (\config -> { config | look = Inline })



-- VIEW


{-| The key caps for these keys: one cap for each key, grouped as one
combination for each step of a sequence, with the word "then" between the steps.
Keys with no steps (an empty `sequence`) draw nothing.

    Kbd.view [] (Shortcut.shift Shortcut.enter) -- Shift Enter

    Kbd.view [ Kbd.platform Kbd.mac ] (Shortcut.mod (Shortcut.shift (Shortcut.char 'n'))) -- ⇧ ⌘ N

-}
view : List Attribute -> Keys -> Html msg
view attributes keys =
    let
        config =
            configure attributes

        steps =
            stepsOf config keys
    in
    if List.isEmpty steps then
        Html.text ""

    else
        Html.span [ Internal.cls [ "klar-keys", lookClass config.look ] ]
            [ Html.span [ Internal.cls [ "klar-keys__caps" ], Attr.attribute "aria-hidden" "true" ]
                (steps
                    |> List.map viewStep
                    |> List.intersperse
                        (Html.span [ Internal.cls [ "klar-keys__then" ] ] [ Html.text (thenWord config) ])
                )
            , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (spokenSteps config steps) ]
            ]


{-| One key cap with a text of your own, for a key that
[Klar.Shortcut](Klar-Shortcut) does not know. The text is shown and read as it
is written; an empty text draws nothing.

    Kbd.key [] "Fn"

    Kbd.key [ Kbd.inline ] "Click"

-}
key : List Attribute -> String -> Html msg
key attributes text =
    let
        config =
            configure attributes
    in
    if String.isEmpty (String.trim text) then
        Html.text ""

    else
        Html.span [ Internal.cls [ "klar-keys", lookClass config.look ] ]
            [ Html.kbd [ Internal.cls [ "klar-kbd" ] ] [ Html.text (String.trim text) ] ]


{-| The same keys as plain text, for the places that take a `String`: the hint of
a menu item, the shortcut of a tooltip, a label. A PC writes the caps with a plus
between them (`Ctrl+Shift+K`), a Mac with a space (`⇧ ⌘ K`), and the steps of a
sequence are joined with "then" (`G then O`). The text can be given to
[`Tooltip.shortcut`](Klar-Tooltip#shortcut), which reads both spellings.

    Kbd.toString [] (Shortcut.mod (Shortcut.char 'k')) -- "Ctrl+K"

    Kbd.toString [ Kbd.platform Kbd.mac ] (Shortcut.mod (Shortcut.char 'k')) -- "⌘ K"

-}
toString : List Attribute -> Keys -> String
toString attributes keys =
    let
        config =
            configure attributes
    in
    stepsOf config keys
        |> List.map (stepText config.platform)
        |> String.join (" " ++ thenWord config ++ " ")


stepText : Platform -> List Cap -> String
stepText which caps =
    case which of
        Pc ->
            caps |> List.map .shown |> String.join "+"

        Mac ->
            caps |> List.map .shown |> String.join " "


lookClass : Look -> String
lookClass look =
    case look of
        Normal ->
            ""

        Small ->
            "klar-keys--sm"

        Inline ->
            "klar-keys--inline"


viewStep : List Cap -> Html msg
viewStep caps =
    Html.kbd [ Internal.cls [ "klar-kbd-combo" ] ]
        (List.map (\cap -> Html.kbd [ Internal.cls [ "klar-kbd" ] ] [ Html.text cap.shown ]) caps)


thenWord : Config -> String
thenWord config =
    Locale.pick config.locale { nb = "deretter", en = "then" }


spokenSteps : Config -> List (List Cap) -> String
spokenSteps config steps =
    steps
        |> List.map (\caps -> caps |> List.map .spoken |> String.join (Locale.pick config.locale { nb = " pluss ", en = " plus " }))
        |> String.join (" " ++ thenWord config ++ " ")



-- CAPS


{-| What is written on a cap, and what a screen reader says for it.
-}
type alias Cap =
    { shown : String
    , spoken : String
    }


{-| The caps of every step. The words come from `Shortcut.keycaps` (so the keys
are decoded in one place only); this module chooses the symbols and the spoken
names. A word it does not know is shown and read as it is.
-}
stepsOf : Config -> Keys -> List (List Cap)
stepsOf config keys =
    Shortcut.keycaps keys
        |> List.map (capsOfStep config)
        -- an empty sequence has one step without keys
        |> List.filter (\caps -> not (List.isEmpty caps))


{-| The last word of a step is the key itself, the ones before it are modifiers.
A Mac writes the modifiers in a fixed order: Option, Shift, Command.
-}
capsOfStep : Config -> List String -> List Cap
capsOfStep config words =
    case List.reverse words of
        [] ->
            []

        last :: modifiersBackwards ->
            let
                modifiers =
                    List.reverse modifiersBackwards

                ordered =
                    case config.platform of
                        Pc ->
                            modifiers

                        Mac ->
                            List.sortBy modifierRank modifiers
            in
            List.map (capOf config) (ordered ++ [ last ])


modifierRank : String -> Int
modifierRank word =
    case String.toLower word of
        "alt" ->
            1

        "shift" ->
            2

        "ctrl" ->
            3

        _ ->
            0


capOf : Config -> String -> Cap
capOf config word =
    let
        say texts =
            Locale.pick config.locale texts

        onPlatform texts =
            case config.platform of
                Pc ->
                    texts.pc

                Mac ->
                    texts.mac

        same text =
            { shown = text, spoken = text }
    in
    case String.toLower word of
        "ctrl" ->
            { shown = onPlatform { pc = "Ctrl", mac = "⌘" }
            , spoken =
                onPlatform
                    { pc = say { nb = "Kontroll", en = "Control" }
                    , mac = say { nb = "Kommando", en = "Command" }
                    }
            }

        "alt" ->
            { shown = onPlatform { pc = "Alt", mac = "⌥" }
            , spoken =
                onPlatform
                    { pc = "Alt"
                    , mac = say { nb = "Valg", en = "Option" }
                    }
            }

        "shift" ->
            { shown = onPlatform { pc = "Shift", mac = "⇧" }
            , spoken = say { nb = "Skift", en = "Shift" }
            }

        "esc" ->
            { shown = "Esc", spoken = "Escape" }

        "enter" ->
            { shown = onPlatform { pc = "Enter", mac = "↩" }
            , spoken = onPlatform { pc = "Enter", mac = say { nb = "Retur", en = "Return" } }
            }

        "space" ->
            { shown = "Space", spoken = say { nb = "Mellomrom", en = "Space" } }

        "tab" ->
            { shown = onPlatform { pc = "Tab", mac = "⇥" }
            , spoken = say { nb = "Tabulator", en = "Tab" }
            }

        "↑" ->
            { shown = "↑", spoken = say { nb = "Pil opp", en = "Up arrow" } }

        "↓" ->
            { shown = "↓", spoken = say { nb = "Pil ned", en = "Down arrow" } }

        "←" ->
            { shown = "←", spoken = say { nb = "Pil venstre", en = "Left arrow" } }

        "→" ->
            { shown = "→", spoken = say { nb = "Pil høyre", en = "Right arrow" } }

        "backspace" ->
            { shown = onPlatform { pc = "Backspace", mac = "⌫" }, spoken = "Backspace" }

        "delete" ->
            { shown = onPlatform { pc = "Del", mac = "⌦" }
            , spoken = say { nb = "Slett", en = "Delete" }
            }

        "home" ->
            same "Home"

        "end" ->
            same "End"

        "pageup" ->
            { shown = "PgUp", spoken = "Page Up" }

        "pagedown" ->
            { shown = "PgDn", spoken = "Page Down" }

        _ ->
            case symbolName config.locale word of
                Just name ->
                    { shown = word, spoken = name }

                Nothing ->
                    same word


{-| The spoken name of a punctuation mark. A screen reader at its default
setting skips many of them, so "Press ? for help" would lose the key.
-}
symbolName : Locale -> String -> Maybe String
symbolName which symbol =
    let
        say texts =
            Just (Locale.pick which texts)
    in
    case symbol of
        "?" ->
            say { nb = "spørsmålstegn", en = "question mark" }

        "!" ->
            say { nb = "utropstegn", en = "exclamation mark" }

        "/" ->
            say { nb = "skråstrek", en = "slash" }

        "\\" ->
            say { nb = "omvendt skråstrek", en = "backslash" }

        "+" ->
            say { nb = "pluss", en = "plus" }

        "-" ->
            say { nb = "minus", en = "minus" }

        "=" ->
            say { nb = "er lik", en = "equals" }

        "," ->
            say { nb = "komma", en = "comma" }

        "." ->
            say { nb = "punktum", en = "period" }

        ";" ->
            say { nb = "semikolon", en = "semicolon" }

        ":" ->
            say { nb = "kolon", en = "colon" }

        "'" ->
            say { nb = "apostrof", en = "apostrophe" }

        "\"" ->
            say { nb = "anførselstegn", en = "quotation mark" }

        "`" ->
            say { nb = "bakvendt apostrof", en = "backtick" }

        "[" ->
            say { nb = "venstre hakeparentes", en = "left bracket" }

        "]" ->
            say { nb = "høyre hakeparentes", en = "right bracket" }

        "(" ->
            say { nb = "venstre parentes", en = "left parenthesis" }

        ")" ->
            say { nb = "høyre parentes", en = "right parenthesis" }

        "{" ->
            say { nb = "venstre krøllparentes", en = "left brace" }

        "}" ->
            say { nb = "høyre krøllparentes", en = "right brace" }

        "<" ->
            say { nb = "mindre enn", en = "less than" }

        ">" ->
            say { nb = "større enn", en = "greater than" }

        "*" ->
            say { nb = "stjerne", en = "asterisk" }

        "#" ->
            say { nb = "firkant", en = "hash" }

        "@" ->
            say { nb = "krøllalfa", en = "at sign" }

        "_" ->
            say { nb = "understrek", en = "underscore" }

        "~" ->
            say { nb = "tilde", en = "tilde" }

        "^" ->
            say { nb = "sirkumfleks", en = "caret" }

        "%" ->
            say { nb = "prosent", en = "percent" }

        "$" ->
            say { nb = "dollar", en = "dollar" }

        "&" ->
            say { nb = "og-tegn", en = "ampersand" }

        "|" ->
            say { nb = "loddrett strek", en = "vertical bar" }

        _ ->
            Nothing
