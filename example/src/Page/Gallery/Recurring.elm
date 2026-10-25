module Page.Gallery.Recurring exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: recurring dates.

The field (`Klar.RecurrencePicker`) is shown with the start date that drives
its monthly choices, in both languages and as a read-only line. The rest of the
page is `Klar.Recurrence` on its own: a table of rules with their words and their
RRULE text, the month-end demonstration, and the next twelve dates of a rule
that the reader chooses. The gallery pretends it is `Showcase.Sample.today`.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.Format as Format
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Recurrence as Recurrence exposing (Rule)
import Klar.RecurrencePicker as RecurrencePicker
import Klar.Select as Select
import Klar.Text as Text
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Time exposing (Month(..), Weekday(..))



-- MODEL


type alias Model =
    { startDate : DatePicker.State
    , picker : RecurrencePicker.State
    , norwegian : RecurrencePicker.State
    , loaded : RecurrencePicker.State
    , skipping : RecurrencePicker.State
    , chooser : Select.State Int
    }


type Msg
    = StartMsg DatePicker.Msg
    | PickerMsg RecurrencePicker.Msg
    | NorwegianMsg RecurrencePicker.Msg
    | LoadedMsg RecurrencePicker.Msg
    | SkippingMsg RecurrencePicker.Msg
    | ChooserMsg (Select.Msg Int)


today : Date
today =
    Sample.today


init : ( Model, Cmd Msg )
init =
    ( { startDate = DatePicker.init "recurrence-start" |> DatePicker.setDate (Just today)
      , picker = RecurrencePicker.init "recurrence-picker" today
      , norwegian =
            RecurrencePicker.init "recurrence-norwegian" today
                |> setExample 2
      , loaded =
            RecurrencePicker.init "recurrence-loaded" today
                |> setExample 5
      , skipping =
            RecurrencePicker.init "recurrence-skipping" today
                |> setExample 12
      , chooser = Select.init "recurrence-chooser" |> Select.setValue 2
      }
    , Cmd.none
    )


{-| Puts the n-th rule of the table into a picker, as an application does with
a rule it loaded from a server.
-}
setExample : Int -> RecurrencePicker.State -> RecurrencePicker.State
setExample index picker =
    RecurrencePicker.setValue (ruleAt index) picker


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartMsg inner ->
            let
                ( startDate, cmd ) =
                    DatePicker.update inner model.startDate

                moved =
                    case DatePicker.date startDate of
                        Just date ->
                            RecurrencePicker.setStart date model.picker

                        Nothing ->
                            model.picker
            in
            ( { model | startDate = startDate, picker = moved }, Cmd.map StartMsg cmd )

        PickerMsg inner ->
            let
                ( picker, cmd ) =
                    RecurrencePicker.update inner model.picker
            in
            ( { model | picker = picker }, Cmd.map PickerMsg cmd )

        NorwegianMsg inner ->
            let
                ( norwegian, cmd ) =
                    RecurrencePicker.update inner model.norwegian
            in
            ( { model | norwegian = norwegian }, Cmd.map NorwegianMsg cmd )

        LoadedMsg inner ->
            let
                ( loaded, cmd ) =
                    RecurrencePicker.update inner model.loaded
            in
            ( { model | loaded = loaded }, Cmd.map LoadedMsg cmd )

        SkippingMsg inner ->
            let
                ( skipping, cmd ) =
                    RecurrencePicker.update inner model.skipping
            in
            ( { model | skipping = skipping }, Cmd.map SkippingMsg cmd )

        ChooserMsg inner ->
            let
                ( chooser, cmd ) =
                    Select.update inner model.chooser
            in
            ( { model | chooser = chooser }, Cmd.map ChooserMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- THE EXAMPLE RULES


{-| The rules of the table, with the words that introduce them.
-}
examples : List ( String, Maybe Rule )
examples =
    [ ( "Every day", ok Recurrence.daily [] )
    , ( "Every weekday", ok (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri ]) [] )
    , ( "Every second week, two days", ok (Recurrence.weekly Mon [ Thu ]) [ Recurrence.every 2 ] )
    , ( "A day of the month", ok (Recurrence.monthlyOnDay 15) [] )
    , ( "The n-th weekday of the month", ok (Recurrence.monthlyOnWeekday Recurrence.second Tue) [] )
    , ( "The last Friday, with an end", ok (Recurrence.monthlyOnWeekday Recurrence.last Fri) [ Recurrence.ends (Recurrence.until endOf2027) ] )
    , ( "The last day of every month", ok (Recurrence.monthlyOnDay 31) [] )
    , ( "The 31st, skipping short months", ok (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) [] )
    , ( "Every third month, ten times", ok (Recurrence.monthlyOnDay 1) [ Recurrence.every 3, Recurrence.ends (Recurrence.after 10) ] )
    , ( "A date every year", ok (Recurrence.yearlyOnDate Oct 20) [] )
    , ( "29 February", ok (Recurrence.yearlyOnDate Feb 29) [] )
    , ( "The third Tuesday of a month", ok (Recurrence.yearlyOnWeekday Recurrence.third Tue Oct) [] )
    , ( "A skipped date", ok Recurrence.daily [ Recurrence.every 7, Recurrence.except [ Date.addDays 14 today, Date.addDays 28 today ] ] )
    ]


ok : Recurrence.Pattern -> List Recurrence.Option -> Maybe Rule
ok pattern options =
    Recurrence.rule pattern options |> Result.toMaybe


ruleAt : Int -> Maybe Rule
ruleAt index =
    examples |> List.drop index |> List.head |> Maybe.andThen Tuple.second


endOf2027 : Date
endOf2027 =
    Date.fromParts 2027 12 31 |> Maybe.withDefault today



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Recurring dates"
        , description = "Rules like every second Tuesday: the field that builds one, and the module that gives its dates, its description in plain language and its RRULE text. A rule is a set of calendar dates, without a time or a time zone: your application attaches those to each date."
        }
        [ fieldSection locale model
        , wordsSection
        , monthEndSection
        , nextSection model
        ]


mono : String -> Html msg
mono text =
    Html.code [ Attr.style "font-size" "var(--klar-text-sm)", Attr.style "overflow-wrap" "anywhere" ] [ Html.text text ]



-- THE FIELD


fieldSection : Locale -> Model -> Html Msg
fieldSection locale model =
    Doc.section "The field"
        "Choose how often, which days and how it ends. The sentence under the fields is built by Klar.Recurrence and is the only live region; the next dates follow it. The last weekday cannot be turned off, and the field says why. Where a day may be missing (the 31st, 29 February) it asks what to do. The language switch in the top bar changes the built-in text."
        [ Doc.example
            { title = "A field that builds a rule"
            , description = Just "The start date drives the choices of a monthly rule: try the 29th, 30th or 31st, or the last Tuesday of a month. What the application reads is a Maybe Rule, and a problem while the form is incomplete."
            , code = Just fieldCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ DatePicker.view StartMsg
                    [ DatePicker.label "Start date"
                    , DatePicker.today today
                    , DatePicker.locale locale
                    , DatePicker.hint "The first delivery. The monthly choices follow this date."
                    ]
                    model.startDate
                , RecurrencePicker.view PickerMsg
                    [ RecurrencePicker.label "Repeat"
                    , RecurrencePicker.today today
                    , RecurrencePicker.locale locale
                    ]
                    model.picker
                , whatTheApplicationSees model.picker
                ]
            )
        , Doc.example
            { title = "Norwegian"
            , description = Just "A rule that was loaded (an example from the table, put in with setRule) in Norwegian Bokmål, whatever the language switch says."
            , code = Just "RecurrencePicker.view RepeatMsg\n    [ RecurrencePicker.locale Locale.nb ]\n    model.repeat"
            }
            (RecurrencePicker.view NorwegianMsg
                [ RecurrencePicker.label "Gjenta"
                , RecurrencePicker.today today
                , RecurrencePicker.locale Locale.nb
                ]
                model.norwegian
            )
        , Doc.example
            { title = "Skipped dates"
            , description = Just "A loaded rule that skips dates shows them as tags with a button each, and Remove all. The field never adds a skipped date, and it keeps one that no longer fits the rule until it is removed: switch the rule to monthly and the dates stay."
            , code = Just "RecurrencePicker.setValue (Just rule) model.repeat   -- rule made with Recurrence.except [ ... ]"
            }
            (RecurrencePicker.view SkippingMsg
                [ RecurrencePicker.label "Repeat"
                , RecurrencePicker.today today
                , RecurrencePicker.locale locale
                ]
                model.skipping
            )
        , Doc.example
            { title = "Read-only"
            , description = Just "Only the label and the sentence, for a page that shows a saved rule. The state is the same as for the field: the first is a rule loaded with setRule, the second a field that does not repeat."
            , code = Just "RecurrencePicker.view RepeatMsg [ RecurrencePicker.readOnly True ] model.repeat"
            }
            (Layout.stack [ Layout.gap 4 ]
                [ RecurrencePicker.view LoadedMsg
                    [ RecurrencePicker.label "Repeat"
                    , RecurrencePicker.locale locale
                    , RecurrencePicker.readOnly True
                    ]
                    model.loaded
                , RecurrencePicker.view LoadedMsg
                    [ RecurrencePicker.label "Repeat"
                    , RecurrencePicker.locale locale
                    , RecurrencePicker.readOnly True
                    ]
                    (RecurrencePicker.init "recurrence-not-repeating" today)
                ]
            )
        ]


whatTheApplicationSees : RecurrencePicker.State -> Html msg
whatTheApplicationSees picker =
    let
        rule =
            case RecurrencePicker.value picker of
                Just found ->
                    "Just a rule: " ++ Recurrence.toRRule found

                Nothing ->
                    case RecurrencePicker.problem picker of
                        Just problem ->
                            "Nothing, because: " ++ RecurrencePicker.problemText Locale.en problem

                        Nothing ->
                            "Nothing: the date does not repeat"
    in
    Layout.stack [ Layout.gap 1 ]
        [ Text.caption "What the application reads (RecurrencePicker.value, isValid, problem)"
        , mono rule
        ]


fieldCode : String
fieldCode =
    """-- model
{ repeat : RecurrencePicker.State }   -- RecurrencePicker.init "repeat" firstDelivery

-- update
RepeatMsg m ->
    let
        ( repeat, cmd ) =
            RecurrencePicker.update m model.repeat
    in
    ( { model | repeat = repeat }, Cmd.map RepeatMsg cmd )

DeliveryDateChanged date ->
    ( { model | repeat = RecurrencePicker.setStart date model.repeat }, Cmd.none )

-- view
RecurrencePicker.view RepeatMsg
    [ RecurrencePicker.label "Repeat"
    , RecurrencePicker.today model.today
    ]
    model.repeat

-- read
RecurrencePicker.value model.repeat     -- Maybe Rule
RecurrencePicker.isValid model.repeat   -- save only when True: Nothing can also mean half filled in
RecurrencePicker.problem model.repeat   -- Maybe Problem: why it is not valid"""



-- WORDS AND RRULE


wordsSection : Html msg
wordsSection =
    Doc.section "Rules, words and RRULE"
        "Every rule can be described in plain language, in English and Norwegian Bokmål, and written as the value of an iCalendar RRULE for a backend. The rule is read back from the text (fromRRule), and anything outside the practical subset is a problem that names it, never a guess."
        [ Doc.example
            { title = "Example rules"
            , description = Just "describe Locale.en, describe Locale.nb and toRRule of each rule. The skipped date of the last rule is not part of an RRULE (iCalendar keeps it in EXDATE), so it is read separately."
            , code = Just wordsCode
            }
            (Html.table [ Attr.class "showcase-doc__props" ]
                [ Html.thead []
                    [ Html.tr []
                        [ Html.th [] [ Html.text "Rule" ]
                        , Html.th [] [ Html.text "English" ]
                        , Html.th [] [ Html.text "Norwegian" ]
                        , Html.th [] [ Html.text "RRULE" ]
                        ]
                    ]
                , Html.tbody []
                    (List.map wordsRow examples)
                ]
            )
        , Doc.example
            { title = "What is outside the subset"
            , description = Just "The problem says what is not supported, in both languages; the part is shown as the RRULE has it. A rule that leaves out its day takes it from the start of the series (here today), as RFC 5545 says: FREQ=WEEKLY and FREQ=YEARLY are read."
            , code = Just "Recurrence.fromRRule { start = model.today } \"FREQ=HOURLY\"\n    |> Result.mapError (Recurrence.problemText Locale.en)\n--> Err \"Not supported in a recurrence rule: FREQ=HOURLY.\""
            }
            (Layout.stack [ Layout.gap 2 ]
                (List.map rejected
                    [ "FREQ=HOURLY"
                    , "FREQ=WEEKLY"
                    , "FREQ=YEARLY"
                    , "FREQ=MONTHLY;BYDAY=MO"
                    , "FREQ=MONTHLY;BYDAY=5TU"
                    , "FREQ=MONTHLY;BYMONTHDAY=1,15"
                    , "FREQ=DAILY;COUNT=3;UNTIL=20271231"
                    , "FREQ=DAILY;UNTIL=20271231T235959Z"
                    ]
                )
            )
        ]


wordsRow : ( String, Maybe Rule ) -> Html msg
wordsRow ( name, maybeRule ) =
    case maybeRule of
        Just rule ->
            Html.tr []
                [ Html.td [] [ Html.text name ]
                , Html.td [] [ Html.text (Recurrence.describe Locale.en rule) ]
                , Html.td [] [ Html.text (Recurrence.describe Locale.nb rule) ]
                , Html.td [] [ mono (Recurrence.toRRule rule) ]
                ]

        Nothing ->
            Html.tr [] [ Html.td [] [ Html.text name ], Html.td [] [ Html.text "not a valid rule" ] ]


rejected : String -> Html msg
rejected text =
    case Recurrence.fromRRule { start = today } text of
        Ok rule ->
            Layout.stack [ Layout.gap 0 ]
                [ mono text, Text.muted ("read as: " ++ Recurrence.describe Locale.en rule) ]

        Err problem ->
            Layout.stack [ Layout.gap 0 ]
                [ mono text
                , Text.muted (Recurrence.problemText Locale.en problem)
                , Text.muted (Recurrence.problemText Locale.nb problem)
                ]


wordsCode : String
wordsCode =
    """Recurrence.rule (Recurrence.weekly Mon [ Thu ])
    [ Recurrence.every 2 ]
    |> Result.map (Recurrence.describe Locale.en)
--> Ok "Every 2 weeks on Monday and Thursday"

Recurrence.rule (Recurrence.weekly Mon [ Thu ]) [ Recurrence.every 2 ]
    |> Result.map Recurrence.toRRule
--> Ok "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH"

Recurrence.fromRRule { start = firstDelivery } "FREQ=MONTHLY;BYDAY=-1FR;UNTIL=20271231"
    |> Result.map (Recurrence.describe Locale.nb)
--> Ok "Den siste fredagen i hver måned til 31. desember 2027" """



-- MONTH ENDS


monthEndSection : Html msg
monthEndSection =
    Doc.section "Months that are too short"
        "\"Monthly on the 31st\" has no 31st in April. By default the rule uses the last day of that month, which is what a run of invoices on the 31st wants; skippingMissingDays skips such months instead, the way RFC 5545 does. The same choice covers 29 February in the years that have none."
        [ Doc.example
            { title = "The 31st, from 31 January 2026"
            , description = Just "Twelve dates each. The default follows the month ends (28 February), the other skips February, April, June, September and November."
            , code = Just "Recurrence.monthlyOnDay 31\n\nRecurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays"
            }
            (Layout.grid [ Layout.minColumn 260, Layout.gap 6 ]
                [ monthEndList "Default: the last day of the month" (Recurrence.monthlyOnDay 31) (day 2026 1 31) 12
                , monthEndList "Skipping months without a 31st" (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) (day 2026 1 31) 12
                ]
            )
        , Doc.example
            { title = "29 February, from 2024"
            , description = Just "Six dates each: 28 February in the years without a leap day, or only the leap years."
            , code = Just "Recurrence.yearlyOnDate Feb 29\n\nRecurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays"
            }
            (Layout.grid [ Layout.minColumn 260, Layout.gap 6 ]
                [ monthEndList "Default: 28 February in other years" (Recurrence.yearlyOnDate Feb 29) (day 2024 2 29) 6
                , monthEndList "Skipping years without it" (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) (day 2024 2 29) 6
                ]
            )
        ]


day : Int -> Int -> Int -> Date
day year month d =
    Date.fromParts year month d |> Maybe.withDefault today


monthEndList : String -> Recurrence.Pattern -> Date -> Int -> Html msg
monthEndList title pattern start limit =
    case Recurrence.rule pattern [] of
        Ok rule ->
            Layout.stack [ Layout.gap 1 ]
                [ Text.caption title
                , Text.muted (Recurrence.describe Locale.en rule)
                , Html.ol
                    [ Attr.style "margin" "var(--klar-space-1) 0 0"
                    , Attr.style "padding-left" "var(--klar-space-6)"
                    , Attr.style "font-variant-numeric" "tabular-nums"
                    ]
                    (Recurrence.occurrences { start = start, from = start, limit = limit } rule
                        |> List.map (\date -> Html.li [] [ Html.text (Locale.weekdayLong Locale.en (Date.weekday date) ++ " " ++ Format.dateLong Locale.en date) ])
                    )
                ]

        Err problem ->
            Text.muted (Recurrence.problemText Locale.en problem)



-- THE NEXT DATES


nextSection : Model -> Html Msg
nextSection model =
    let
        chosen =
            Select.value model.chooser |> Maybe.andThen ruleAt
    in
    Doc.section "The next twelve dates"
        "Choose a rule, and its next dates are listed as a calendar would. They come from Recurrence.occurrences, counted from a start date (today in this gallery), and a rule that ends after fewer dates stops there."
        [ Doc.example
            { title = "A rule and its dates"
            , description = Just "occurrences { start, from, limit } is all it takes: the dates on or after from, at most limit, counted from start, so \"after 10 times\" ends after ten dates even when from is later."
            , code = Just "Recurrence.occurrences { start = today, from = today, limit = 12 } rule"
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Select.view ChooserMsg
                    [ Select.label "Rule"
                    , Select.options (List.indexedMap (\index ( name, _ ) -> Select.option index name) examples)
                    ]
                    model.chooser
                , case chosen of
                    Just rule ->
                        dateTiles rule

                    Nothing ->
                        Text.muted "Choose a rule."
                ]
            )
        ]


dateTiles : Rule -> Html msg
dateTiles rule =
    let
        found =
            Recurrence.occurrences { start = today, from = today, limit = 12 } rule

        note =
            case Recurrence.count { start = today } rule of
                Just total ->
                    if total > List.length found then
                        String.fromInt (List.length found) ++ " of " ++ String.fromInt total ++ " dates"

                    else
                        String.fromInt total ++ " dates in all: the rule ends"

                Nothing ->
                    if List.length found < 12 then
                        "The rule has no more dates."

                    else
                        "The first 12 dates of a series that goes on"
    in
    Layout.stack [ Layout.gap 3 ]
        [ Text.strong (Recurrence.describe Locale.en rule)
        , if List.isEmpty found then
            Text.muted "No dates match the rule."

          else
            Html.ol
                [ Attr.style "display" "grid"
                , Attr.style "grid-template-columns" "repeat(auto-fill, minmax(6.5rem, 1fr))"
                , Attr.style "gap" "var(--klar-space-2)"
                , Attr.style "margin" "0"
                , Attr.style "padding" "0"
                , Attr.style "list-style" "none"
                ]
                (List.map tile found)
        , Text.muted note
        ]


tile : Date -> Html msg
tile date =
    Html.li
        [ Attr.style "border" "1px solid var(--klar-border)"
        , Attr.style "border-radius" "var(--klar-radius)"
        , Attr.style "background" "var(--klar-surface)"
        , Attr.style "padding" "var(--klar-space-2) var(--klar-space-3)"
        , Attr.style "display" "flex"
        , Attr.style "flex-direction" "column"
        , Attr.style "font-variant-numeric" "tabular-nums"
        ]
        [ Html.span [ Attr.style "color" "var(--klar-text-muted)", Attr.style "font-size" "var(--klar-text-sm)" ]
            [ Html.text (Locale.monthShort Locale.en (Date.month date) ++ " " ++ String.fromInt (Date.year date)) ]
        , Html.span [ Attr.style "font-size" "var(--klar-text-xl)", Attr.style "font-weight" "var(--klar-weight-bold)" ]
            [ Html.text (String.fromInt (Date.day date)) ]
        , Html.span [ Attr.style "color" "var(--klar-text-secondary)" ]
            [ Html.text (Locale.weekdayLong Locale.en (Date.weekday date)) ]
        ]
