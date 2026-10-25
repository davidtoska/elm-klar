module SettingsTest exposing (suite)

{-| The settings of the application: the zone of the times, the density
that the shell and `scope` leave on the page, and the small things that came with
them (`Format.dateShort`, `Timeline.dayEvent`, `Stat.money`, `Chart.dates`).
-}

import Expect
import Html
import Html.Attributes as Attr
import Klar.AppShell as AppShell
import Klar.Chart as Chart
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Locale as Locale
import Klar.Money as Money exposing (Money)
import Klar.Settings as Settings exposing (Settings)
import Klar.Stat as Stat
import Klar.Theme exposing (Density(..))
import Klar.Timeline as Timeline
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


suite : Test
suite =
    describe "Klar.Settings"
        [ zones
        , languageAndDay
        , density
        , dateShort
        , dayEvents
        , statMoney
        , chartDates
        ]


{-| 14:05 on 12 March 2024, UTC.
-}
posix : Time.Posix
posix =
    Time.millisToPosix 1710252300000


oslo : Settings
oslo =
    Settings.withZone (Time.customZone 60 []) Settings.default


zones : Test
zones =
    describe "the zone"
        [ test "a zone that was never given writes the time in UTC and says so" <|
            \_ -> Expect.equal "14:05 UTC" (Settings.time Settings.default posix)
        , test "a zone that was given writes the time as it is on the wall" <|
            \_ -> Expect.equal "15:05" (Settings.time oslo posix)
        , test "the date and the time follow the zone and the language" <|
            \_ ->
                Expect.equal
                    [ "2024-03-12 15:05", "12.03.2024 15:05" ]
                    [ Settings.dateTime oslo posix
                    , Settings.dateTime (Settings.withLocale Locale.nb oslo) posix
                    ]
        , test "the day is the day of the zone, which may be the next one" <|
            \_ ->
                let
                    lateEvening =
                        Time.millisToPosix 1710284700000

                    zone =
                        Settings.withZone (Time.customZone 120 []) Settings.default
                in
                Expect.equal
                    ( "2024-03-12", "2024-03-13" )
                    ( Date.toIso (Settings.toDate Settings.default lateEvening)
                    , Date.toIso (Settings.toDate zone lateEvening)
                    )
        , test "the zone for the places that write a time themselves is UTC until it is given" <|
            \_ ->
                Expect.equal
                    ( "14:05", "15:05" )
                    ( Format.time (Settings.zone Settings.default) posix
                    , Format.time (Settings.zone oslo) posix
                    )
        ]


languageAndDay : Test
languageAndDay =
    let
        lateEvening =
            -- 22:05 on 12 March 2024, UTC: already the 13th at UTC+2
            Time.millisToPosix 1710281100000

        box settings =
            Settings.scope settings [ Html.text "inside" ]
                |> Query.fromHtml
    in
    describe "the language, the time now and the day today"
        [ test "the language is English until it is given, then the one given" <|
            \_ ->
                Expect.equal [ Locale.en, Locale.nb ]
                    [ Settings.locale Settings.default
                    , Settings.locale (Settings.withLocale Locale.nb Settings.default)
                    ]
        , test "there is no time now and no day today until the time is given" <|
            \_ -> Expect.equal ( Nothing, Nothing ) ( Settings.now Settings.default, Settings.today Settings.default )
        , test "the time now is read back" <|
            \_ -> Expect.equal (Just posix) (Settings.now (Settings.withNow posix Settings.default))
        , test "the day today is the day of the time now in the zone, which may be the next one" <|
            \_ ->
                Expect.equal [ Just "2024-03-12", Just "2024-03-13" ]
                    [ Settings.default |> Settings.withNow lateEvening |> Settings.today |> Maybe.map Date.toIso
                    , Settings.default |> Settings.withNow lateEvening |> Settings.withZone (Time.customZone 120 []) |> Settings.today |> Maybe.map Date.toIso
                    ]
        , test "the box of the scope has the lang of a given language, and none before" <|
            \_ ->
                Expect.all
                    [ \_ -> box (Settings.withLocale Locale.nb Settings.default) |> Query.has [ Selector.attribute (Attr.attribute "lang" "nb") ]
                    , \_ -> box Settings.default |> Query.hasNot [ Selector.attribute (Attr.attribute "lang" "en") ]
                    ]
                    ()
        , test "the shell takes the language of the settings for its text and its lang" <|
            \_ ->
                AppShell.view [ AppShell.settings (Settings.withLocale Locale.nb Settings.default) ] [ Html.text "page" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-app-shell", Selector.attribute (Attr.attribute "lang" "nb") ]
                        , Query.find [ Selector.class "klar-app-shell__skip" ] >> Query.has [ Selector.text "Hopp til hovedinnhold" ]
                        ]
        , test "a locale given to the shell wins over the settings, before or after them" <|
            \_ ->
                let
                    norwegian =
                        AppShell.settings (Settings.withLocale Locale.nb Settings.default)

                    lang attributes =
                        AppShell.view attributes [ Html.text "page" ]
                            |> Query.fromHtml
                            |> Query.has [ Selector.class "klar-app-shell", Selector.attribute (Attr.attribute "lang" "en") ]
                in
                Expect.all
                    [ \_ -> lang [ AppShell.locale Locale.en, norwegian ]
                    , \_ -> lang [ norwegian, AppShell.locale Locale.en ]
                    , \_ -> lang [ AppShell.settings Settings.default ]
                    , \_ -> lang []
                    ]
                    ()
        , test "the language of the settings writes the date and the time, in UTC until the zone is known" <|
            \_ ->
                Expect.equal
                    [ "12.03.2024 15:05", "12.03.2024 14:05 UTC", "2024-03-12 14:05 UTC" ]
                    [ Settings.dateTime (Settings.withLocale Locale.nb oslo) posix
                    , Settings.dateTime (Settings.withLocale Locale.nb Settings.default) posix
                    , Settings.dateTime Settings.default posix
                    ]
        ]


density : Test
density =
    let
        marked settings =
            Settings.scope settings [ Html.text "inside" ]
                |> Query.fromHtml
    in
    describe "the density"
        [ test "compact and comfortable leave a mark that the stylesheet follows" <|
            \_ ->
                Expect.all
                    [ \_ -> marked (Settings.withDensity Compact Settings.default) |> Query.has [ Selector.attribute (Attr.attribute "data-klar-density" "compact") ]
                    , \_ -> marked (Settings.withDensity Comfortable Settings.default) |> Query.has [ Selector.attribute (Attr.attribute "data-klar-density" "comfortable") ]
                    ]
                    ()
        , test "normal leaves none" <|
            \_ -> marked Settings.default |> Query.hasNot [ Selector.attribute (Attr.attribute "data-klar-density" "normal") ]
        , test "the density is read back" <|
            \_ -> Expect.equal Compact (Settings.density (Settings.withDensity Compact Settings.default))
        , test "the shell carries the density of the settings" <|
            \_ ->
                AppShell.view [ AppShell.settings (Settings.withDensity Compact Settings.default) ] [ Html.text "page" ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-app-shell", Selector.attribute (Attr.attribute "data-klar-density" "compact") ]
        , test "a shell without settings has no mark" <|
            \_ ->
                AppShell.view [] [ Html.text "page" ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "data-klar-density" "compact") ]
        ]


september21 : Date
september21 =
    Date.fromParts 2026 9 21 |> Maybe.withDefault (Date.fromEpochDay 0)


dateShort : Test
dateShort =
    describe "Format.dateShort"
        [ test "English: day and month name" <|
            \_ -> Expect.equal "21 Sep" (Format.dateShort Locale.en september21)
        , test "Norwegian: day, point, month with a point" <|
            \_ -> Expect.equal "21. sep." (Format.dateShort Locale.nb september21)
        , test "no leading zero" <|
            \_ ->
                Expect.equal "3 Jan"
                    (Format.dateShort Locale.en (Date.fromParts 2026 1 3 |> Maybe.withDefault september21))
        ]


dayEvents : Test
dayEvents =
    let
        view events =
            Timeline.view [ Timeline.settings oslo ] events |> Query.fromHtml

        timed =
            Timeline.event "a" posix "Order shipped"

        delivered =
            Timeline.dayEvent "b" september21 "Delivery date"
    in
    describe "Timeline.dayEvent"
        [ test "a day event writes no clock time" <|
            \_ ->
                view [ delivered ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Delivery date" ]
                        , Query.hasNot [ Selector.text "00:00" ]
                        , Query.hasNot [ Selector.tag "time" ]
                        ]
        , test "it sits under the heading of its day" <|
            \_ -> view [ delivered ] |> Query.has [ Selector.tag "h3", Selector.containing [ Selector.text "21 September 2026" ] ]
        , test "a timed event of the same list still writes its time, in the zone of the settings" <|
            \_ -> view [ timed, delivered ] |> Query.has [ Selector.tag "time", Selector.text "15:05" ]
        , test "events of the same day in the same zone share a heading" <|
            \_ ->
                view [ Timeline.dayEvent "c" (Date.fromParts 2024 3 12 |> Maybe.withDefault september21) "Invoice dated", timed ]
                    |> Query.findAll [ Selector.tag "h3" ]
                    |> Query.count (Expect.equal 1)
        ]


dollars : Money
dollars =
    Money.fromMinor Money.usd 123450 |> Maybe.withDefault (Money.zero Money.usd)


nok : Int -> Money
nok minor =
    Money.fromMinor Money.nok minor |> Maybe.withDefault (Money.zero Money.nok)


statMoney : Test
statMoney =
    let
        tile attributes =
            Stat.view (Stat.label "Stock value" :: attributes) |> Query.fromHtml
    in
    describe "Stat.money"
        [ test "an amount is written with the symbol of its currency in the language of the tile" <|
            \_ ->
                Expect.all
                    [ \_ -> tile [ Stat.money dollars ] |> Query.has [ Selector.text "$1,234.50" ]
                    , \_ -> tile [ Stat.money dollars, Stat.locale Locale.nb ] |> Query.has [ Selector.text (Money.toSymbolString Locale.nb dollars) ]
                    ]
                    ()
        , test "the change between two amounts is a percentage" <|
            \_ -> tile [ Stat.money (nok 150000), Stat.moneyChange { current = nok 150000, previous = nok 120000 } ] |> Query.has [ Selector.text "25%" ]
        , test "two currencies have no percentage" <|
            \_ ->
                tile
                    [ Stat.moneyChange
                        { current = nok 150000
                        , previous = Money.fromMinor Money.eur 120000 |> Maybe.withDefault (Money.zero Money.eur)
                        }
                    ]
                    |> Query.hasNot [ Selector.text "%" ]
        ]


chartDates : Test
chartDates =
    let
        days =
            List.range 20 24 |> List.filterMap (Date.fromParts 2026 9)

        chart locale =
            Chart.line [ Chart.dates days, Chart.locale locale ] [ Chart.series "Sales" [ 3, 5, 4, 6, 8 ] ]
                |> Query.fromHtml
    in
    describe "Chart.dates"
        [ test "the axis writes the short date" <|
            \_ -> chart Locale.en |> Query.has [ Selector.class "klar-chart__xlabel", Selector.text "21 Sep" ]
        , test "and the Norwegian one in Norwegian" <|
            \_ -> chart Locale.nb |> Query.has [ Selector.class "klar-chart__xlabel", Selector.text "21. sep." ]
        , test "the tooltip of the label has the whole date" <|
            \_ -> chart Locale.en |> Query.has [ Selector.class "klar-chart__xlabel", Selector.attribute (Attr.title "2026-09-21") ]
        ]
