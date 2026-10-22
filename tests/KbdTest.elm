module KbdTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Html
import Html.Attributes as Attr
import Klar.Kbd as Kbd
import Klar.Locale as Locale
import Klar.Shortcut as Shortcut exposing (Keys)
import Support.ActionsQuery as ActionsQuery
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.Kbd"
        [ toStringTests
        , spokenTests
        , renderTests
        , keyTests
        , platformTests
        , propertyTests
        ]



-- THE KEYS


openPalette : Keys
openPalette =
    Shortcut.mod (Shortcut.char 'k')


newOrder : Keys
newOrder =
    Shortcut.mod (Shortcut.shift (Shortcut.char 'n'))


goToOrders : Keys
goToOrders =
    Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]


mac : List Kbd.Attribute
mac =
    [ Kbd.platform Kbd.mac ]



-- AS TEXT


toStringTests : Test
toStringTests =
    describe "toString"
        [ test "a PC writes words with a plus between them" <|
            \_ ->
                Expect.all
                    [ \_ -> Kbd.toString [] openPalette |> Expect.equal "Ctrl+K"
                    , \_ -> Kbd.toString [] newOrder |> Expect.equal "Ctrl+Shift+N"
                    , \_ -> Kbd.toString [] (Shortcut.shift Shortcut.enter) |> Expect.equal "Shift+Enter"
                    , \_ -> Kbd.toString [] (Shortcut.alt Shortcut.up) |> Expect.equal "Alt+↑"
                    ]
                    ()
        , test "a Mac writes symbols, Option and Shift before Command, with a space" <|
            \_ ->
                Expect.all
                    [ \_ -> Kbd.toString mac openPalette |> Expect.equal "⌘ K"
                    , \_ -> Kbd.toString mac newOrder |> Expect.equal "⇧ ⌘ N"
                    , \_ -> Kbd.toString mac (Shortcut.mod (Shortcut.alt (Shortcut.shift (Shortcut.char 'k')))) |> Expect.equal "⌥ ⇧ ⌘ K"
                    ]
                    ()
        , test "the PC is the default" <|
            \_ ->
                Kbd.toString [] openPalette
                    |> Expect.equal (Kbd.toString [ Kbd.platform Kbd.pc ] openPalette)
        , test "a sequence joins its steps with 'then', in the language asked for" <|
            \_ ->
                Expect.all
                    [ \_ -> Kbd.toString [] goToOrders |> Expect.equal "G then O"
                    , \_ -> Kbd.toString [ Kbd.locale Locale.nb ] goToOrders |> Expect.equal "G deretter O"
                    , \_ -> Kbd.toString [] (Shortcut.mod goToOrders) |> Expect.equal "Ctrl+G then Ctrl+O"
                    ]
                    ()
        , test "the named keys" <|
            \_ ->
                Expect.all
                    [ \_ -> Kbd.toString [] Shortcut.escape |> Expect.equal "Esc"
                    , \_ -> Kbd.toString [] Shortcut.space |> Expect.equal "Space"
                    , \_ -> Kbd.toString [] Shortcut.tab |> Expect.equal "Tab"
                    , \_ -> Kbd.toString [] Shortcut.backspace |> Expect.equal "Backspace"
                    , \_ -> Kbd.toString [] Shortcut.delete |> Expect.equal "Del"
                    , \_ -> Kbd.toString [] Shortcut.pageUp |> Expect.equal "PgUp"
                    , \_ -> Kbd.toString [] Shortcut.pageDown |> Expect.equal "PgDn"
                    , \_ -> Kbd.toString [] Shortcut.home |> Expect.equal "Home"
                    , \_ -> Kbd.toString [] (Shortcut.function 5) |> Expect.equal "F5"
                    , \_ -> Kbd.toString [] (Shortcut.char '?') |> Expect.equal "?"
                    , \_ -> Kbd.toString [] (Shortcut.char ' ') |> Expect.equal "Space"
                    ]
                    ()
        , test "the named keys on a Mac" <|
            \_ ->
                Expect.all
                    [ \_ -> Kbd.toString mac Shortcut.enter |> Expect.equal "↩"
                    , \_ -> Kbd.toString mac Shortcut.tab |> Expect.equal "⇥"
                    , \_ -> Kbd.toString mac Shortcut.backspace |> Expect.equal "⌫"
                    , \_ -> Kbd.toString mac Shortcut.delete |> Expect.equal "⌦"
                    , \_ -> Kbd.toString mac Shortcut.escape |> Expect.equal "Esc"
                    ]
                    ()
        , test "the plus key" <|
            \_ ->
                Kbd.toString [] (Shortcut.mod (Shortcut.char '+')) |> Expect.equal "Ctrl++"
        , test "no steps, no text" <|
            \_ ->
                Kbd.toString [] (Shortcut.sequence []) |> Expect.equal ""
        ]



-- WHAT A SCREEN READER GETS


says : String -> List Kbd.Attribute -> Keys -> Expect.Expectation
says phrase attributes keys =
    Kbd.view attributes keys
        |> Query.fromHtml
        |> Query.find [ Selector.class "klar-sr-only" ]
        |> Query.has [ Selector.exactText phrase ]


spokenTests : Test
spokenTests =
    describe "what a screen reader reads"
        [ test "a combination is joined with 'plus', the modifiers by their names" <|
            \_ ->
                Expect.all
                    [ \_ -> says "Control plus K" [] openPalette
                    , \_ -> says "Control plus Shift plus N" [] newOrder
                    , \_ -> says "Shift plus Enter" [] (Shortcut.shift Shortcut.enter)
                    , \_ -> says "Alt plus Up arrow" [] (Shortcut.alt Shortcut.up)
                    ]
                    ()
        , test "a Mac says Command and Option, never the symbol" <|
            \_ ->
                Expect.all
                    [ \_ -> says "Command plus K" mac openPalette
                    , \_ -> says "Shift plus Command plus N" mac newOrder
                    , \_ -> says "Option plus Page Up" mac (Shortcut.alt Shortcut.pageUp)
                    , \_ -> says "Return" mac Shortcut.enter
                    ]
                    ()
        , test "a sequence is read step by step" <|
            \_ ->
                says "G then O" [] goToOrders
        , test "a punctuation mark is spelled out, because a screen reader may skip it" <|
            \_ ->
                Expect.all
                    [ \_ -> says "question mark" [] (Shortcut.char '?')
                    , \_ -> says "Control plus slash" [] (Shortcut.mod (Shortcut.char '/'))
                    , \_ -> says "Control plus plus" [] (Shortcut.mod (Shortcut.char '+'))
                    ]
                    ()
        , test "in Norwegian" <|
            \_ ->
                Expect.all
                    [ \_ -> says "Kontroll pluss K" [ Kbd.locale Locale.nb ] openPalette
                    , \_ -> says "Kommando pluss K" [ Kbd.locale Locale.nb, Kbd.platform Kbd.mac ] openPalette
                    , \_ -> says "G deretter O" [ Kbd.locale Locale.nb ] goToOrders
                    , \_ -> says "Skift pluss Pil opp" [ Kbd.locale Locale.nb ] (Shortcut.shift Shortcut.up)
                    , \_ -> says "Control plus Page Down" [] (Shortcut.mod Shortcut.pageDown)
                    ]
                    ()
        , test "the caps are hidden from the screen reader" <|
            \_ ->
                Kbd.view [] openPalette
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-keys__caps" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
        ]



-- WHAT IS DRAWN


capCount : List Kbd.Attribute -> Keys -> Int
capCount attributes keys =
    Kbd.view attributes keys
        |> Query.fromHtml
        |> ActionsQuery.count [ Selector.class "klar-kbd" ]


renderTests : Test
renderTests =
    describe "view"
        [ test "one cap for each key, one combination for each step" <|
            \_ ->
                Expect.all
                    [ \_ -> capCount [] openPalette |> Expect.equal 2
                    , \_ -> capCount [] newOrder |> Expect.equal 3
                    , \_ -> capCount [] goToOrders |> Expect.equal 2
                    , \_ -> capCount [] (Shortcut.mod goToOrders) |> Expect.equal 4
                    ]
                    ()
        , test "the caps are kbd elements with the text on them" <|
            \_ ->
                Kbd.view [] openPalette
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "kbd", Selector.class "klar-kbd" ]
                    |> Query.first
                    |> Query.has [ Selector.exactText "Ctrl" ]
        , test "the word between the steps of a sequence" <|
            \_ ->
                Kbd.view [] goToOrders
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-keys__then" ]
                    |> Query.has [ Selector.exactText "then" ]
        , test "a single step has no 'then'" <|
            \_ ->
                Kbd.view [] openPalette
                    |> Query.fromHtml
                    |> ActionsQuery.absent [ Selector.class "klar-keys__then" ]
        , test "keys with no steps draw nothing" <|
            \_ ->
                Html.div [] [ Kbd.view [] (Shortcut.sequence []) ]
                    |> Query.fromHtml
                    |> ActionsQuery.absent [ Selector.tag "kbd" ]
        , test "small and inline are two sizes, the later one wins" <|
            \_ ->
                Expect.all
                    [ \_ -> hasLook "klar-keys--sm" [ Kbd.small ]
                    , \_ -> hasLook "klar-keys--inline" [ Kbd.inline ]
                    , \_ -> hasLook "klar-keys--inline" [ Kbd.small, Kbd.inline ]
                    , \_ -> hasLook "klar-keys--sm" [ Kbd.inline, Kbd.small ]
                    ]
                    ()
        ]


hasLook : String -> List Kbd.Attribute -> Expect.Expectation
hasLook className attributes =
    Kbd.view attributes openPalette
        |> Query.fromHtml
        |> Query.has [ Selector.class className ]



-- A KEY BY ITS TEXT


keyTests : Test
keyTests =
    describe "key"
        [ test "shows and reads the text as it is written" <|
            \_ ->
                Kbd.key [] "Fn"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "kbd" ]
                    |> Query.has [ Selector.exactText "Fn" ]
        , test "is not hidden from the screen reader" <|
            \_ ->
                Kbd.key [] "Fn"
                    |> Query.fromHtml
                    |> ActionsQuery.absent [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
        , test "a platform does not change it" <|
            \_ ->
                Kbd.key mac "Ctrl"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "kbd" ]
                    |> Query.has [ Selector.exactText "Ctrl" ]
        , test "the text is trimmed, and an empty text draws nothing" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Kbd.key [] "  Insert "
                            |> Query.fromHtml
                            |> Query.find [ Selector.tag "kbd" ]
                            |> Query.has [ Selector.exactText "Insert" ]
                    , \_ ->
                        Html.div [] [ Kbd.key [] "   ", Kbd.key [] "" ]
                            |> Query.fromHtml
                            |> ActionsQuery.absent [ Selector.tag "kbd" ]
                    ]
                    ()
        , test "markup in the text stays text" <|
            \_ ->
                Kbd.key [] "<b>x</b>"
                    |> Query.fromHtml
                    |> ActionsQuery.absent [ Selector.tag "b" ]
        ]



-- THE PLATFORM


platformTests : Test
platformTests =
    describe "platformFromUserAgent"
        [ test "a Mac, an iPhone, an iPad" <|
            \_ ->
                Expect.all
                    [ \_ -> isMac "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
                    , \_ -> isMac "MacIntel"
                    , \_ -> isMac "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
                    , \_ -> isMac "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)"
                    ]
                    ()
        , test "Windows, Linux, Android and nothing at all are PCs" <|
            \_ ->
                Expect.all
                    [ \_ -> isPc "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
                    , \_ -> isPc "Win32"
                    , \_ -> isPc "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
                    , \_ -> isPc "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36"
                    , \_ -> isPc ""
                    ]
                    ()
        ]


isMac : String -> Expect.Expectation
isMac text =
    Kbd.toString [ Kbd.platform (Kbd.platformFromUserAgent text) ] openPalette
        |> Expect.equal "⌘ K"


isPc : String -> Expect.Expectation
isPc text =
    Kbd.toString [ Kbd.platform (Kbd.platformFromUserAgent text) ] openPalette
        |> Expect.equal "Ctrl+K"



-- FOR ANY KEYS


{-| Keys built from every part there is: a letter, a digit or a symbol, perhaps
with the three modifiers, perhaps a sequence of two.
-}
anyKeys : Fuzzer Keys
anyKeys =
    Fuzz.map5
        (\letter useMod useAlt useShift second ->
            let
                wrapped =
                    Shortcut.char letter
                        |> maybe useShift Shortcut.shift
                        |> maybe useAlt Shortcut.alt
                        |> maybe useMod Shortcut.mod
            in
            case second of
                Just other ->
                    Shortcut.sequence [ wrapped, Shortcut.char other ]

                Nothing ->
                    wrapped
        )
        printable
        Fuzz.bool
        Fuzz.bool
        Fuzz.bool
        (Fuzz.maybe printable)


{-| A letter, a digit or a symbol that can be typed: no space or control character,
which `Shortcut.char` cannot hold.
-}
printable : Fuzzer Char
printable =
    Fuzz.intRange 33 126 |> Fuzz.map Char.fromCode


maybe : Bool -> (a -> a) -> a -> a
maybe condition change value =
    if condition then
        change value

    else
        value


propertyTests : Test
propertyTests =
    describe "for any keys"
        [ fuzz anyKeys "a Mac and a PC draw the same number of caps" <|
            \keys ->
                capCount mac keys |> Expect.equal (capCount [] keys)
        , fuzz anyKeys "the text is never empty" <|
            \keys ->
                String.isEmpty (Kbd.toString [] keys) |> Expect.equal False
        , fuzz2 anyKeys Fuzz.bool "the language never changes the caps, only the words" <|
            \keys useMac ->
                let
                    platformAttribute =
                        [ Kbd.platform
                            (if useMac then
                                Kbd.mac

                             else
                                Kbd.pc
                            )
                        ]
                in
                capCount (Kbd.locale Locale.nb :: platformAttribute) keys
                    |> Expect.equal (capCount platformAttribute keys)
        ]
