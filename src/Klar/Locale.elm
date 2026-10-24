module Klar.Locale exposing
    ( Locale, en, nb, default, all, pick
    , name, toCode, fromCode
    , thousandSeparator, decimalSeparator
    , firstDayOfWeek, monthLong, monthShort, weekdayLong, weekdayShort
    )

{-| The language and the regional conventions of the text the library writes
itself: placeholders such as "Search ...", the labels of icon buttons, month
names, validation messages, number separators.

Use when: the text the library writes itself must come in another language than English, or you pick between two of your own texts.
Do not use when: you need to translate your own labels and messages, which stay in your application.
Quick path: `Settings.withLocale`, `Settings.locale`, `fromCode`, `pick`

    import Klar.Locale as Locale exposing (Locale)

    Locale.pick model.locale { nb = "Neste", en = "Next" }

Every component that has built-in text of its own has a `locale` attribute; the
default is `Locale.default`, which is English:

    Select.view CountryMsg [ Select.locale Locale.nb ] model.country

Two languages are built in: English (`Locale.en`) and Norwegian Bokmål
(`Locale.nb`). The type is opaque, so that more languages can be added in a later
version without breaking your code. Text of your application never goes through
the library: your own labels, column titles and messages come from your
application, and `pick` is just a convenient way to choose between two of them.

Switch the language of a whole page by keeping it in the [Klar.Settings](Klar-Settings)
of your model (`Settings.withLocale`) and passing `Settings.locale model.settings` to
every component; `AppShell.locale` also sets the `lang` attribute of the page content
from it, which screen readers use to choose the voice.


# Choosing a language

@docs Locale, en, nb, default, all, pick


# Names and codes

@docs name, toCode, fromCode


# Numbers

@docs thousandSeparator, decimalSeparator


# Calendar

@docs firstDayOfWeek, monthLong, monthShort, weekdayLong, weekdayShort

-}


{-| The language of the built-in text. Make one with `en` or `nb`, or read it
from a language code with `fromCode`.
-}
type Locale
    = Nb
    | En


{-| English, international: the week starts on Monday and a date is written the
ISO way (`2026-10-20`), so it reads the same in every country. This is the default.
-}
en : Locale
en =
    En


{-| Norwegian Bokmål.
-}
nb : Locale
nb =
    Nb


{-| The language used when nothing else is said: English.
-}
default : Locale
default =
    en


{-| Every language, for a language switcher.
-}
all : List Locale
all =
    [ en, nb ]


{-| Chooses between a Norwegian and an English text. A language that is added in
a later version and has no text here gets the English one.

    Locale.pick Locale.en { nb = "Lagre", en = "Save" } -- "Save"

-}
pick : Locale -> { nb : a, en : a } -> a
pick locale texts =
    case locale of
        Nb ->
            texts.nb

        En ->
            texts.en


{-| The name of a language, in that language: for a language switcher.

    Locale.name Locale.nb -- "Norsk (bokmål)"

    Locale.name Locale.en -- "English"

-}
name : Locale -> String
name locale =
    pick locale { nb = "Norsk (bokmål)", en = "English" }


{-| The language code for the `lang` attribute: `"en"` or `"nb"`.
-}
toCode : Locale -> String
toCode locale =
    pick locale { nb = "nb", en = "en" }


{-| Reads a language code as a browser gives it (`navigator.language`, which your
application gets in its flags) or as you stored it. Only the language counts, not
the region or the case: `"en-US"`, `"en_GB"` and `"EN"` are English, `"nb-NO"` and
`"no"` are Bokmål. Nynorsk (`"nn"`, `"nn-NO"`) is read as Bokmål too, which its
readers understand better than English.

    Locale.fromCode "nb-NO" -- Just Locale.nb

    Locale.fromCode "en-US" -- Just Locale.en

    Locale.fromCode "sv-SE" -- Nothing

Fall back to `Locale.default` on `Nothing`.

-}
fromCode : String -> Maybe Locale
fromCode code =
    let
        language =
            code
                |> String.trim
                |> String.toLower
                |> String.replace "_" "-"
                |> String.split "-"
                |> List.head
                |> Maybe.withDefault ""
    in
    case language of
        "nb" ->
            Just nb

        "no" ->
            Just nb

        "nn" ->
            Just nb

        "en" ->
            Just en

        _ ->
            Nothing


{-| What separates groups of three digits: a comma in English and a
non-breaking space in Norwegian.
-}
thousandSeparator : Locale -> String
thousandSeparator locale =
    pick locale { nb = "\u{00A0}", en = "," }


{-| What separates the decimals: a point in English and a comma in Norwegian.
-}
decimalSeparator : Locale -> String
decimalSeparator locale =
    pick locale { nb = ",", en = "." }


{-| The first day of the week in calendars, from 1 (Monday) to 7 (Sunday).
Both languages start the week on Monday, like ISO 8601.
-}
firstDayOfWeek : Locale -> Int
firstDayOfWeek _ =
    1


{-| The name of a month, from 1 (January) to 12 (December); an empty text for
any other number.

    Locale.monthLong Locale.en 3 -- "March"

    Locale.monthLong Locale.nb 3 -- "mars"

-}
monthLong : Locale -> Int -> String
monthLong locale month =
    let
        names =
            pick locale
                { nb = [ "januar", "februar", "mars", "april", "mai", "juni", "juli", "august", "september", "oktober", "november", "desember" ]
                , en = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]
                }
    in
    nth month names


{-| The short name of a month, from 1 (January) to 12 (December): `Mar` or `mar`.
-}
monthShort : Locale -> Int -> String
monthShort locale month =
    let
        names =
            pick locale
                { nb = [ "jan", "feb", "mar", "apr", "mai", "jun", "jul", "aug", "sep", "okt", "nov", "des" ]
                , en = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]
                }
    in
    nth month names


{-| The short name of a day of the week, from 1 (Monday) to 7 (Sunday): `Mo` or
`ma`.
-}
weekdayShort : Locale -> Int -> String
weekdayShort locale day =
    let
        names =
            pick locale
                { nb = [ "ma", "ti", "on", "to", "fr", "lø", "sø" ]
                , en = [ "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" ]
                }
    in
    nth day names


{-| The name of a day of the week, from 1 (Monday) to 7 (Sunday).

    Locale.weekdayLong Locale.en 2 -- "Tuesday"

-}
weekdayLong : Locale -> Int -> String
weekdayLong locale day =
    let
        names =
            pick locale
                { nb = [ "mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lørdag", "søndag" ]
                , en = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ]
                }
    in
    nth day names


{-| The text at a position counted from 1, or an empty text outside the list.
-}
nth : Int -> List String -> String
nth position names =
    if position < 1 then
        ""

    else
        names |> List.drop (position - 1) |> List.head |> Maybe.withDefault ""
