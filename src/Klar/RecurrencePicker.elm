module Klar.RecurrencePicker exposing
    ( view
    , State, init, Msg, update
    , value, setValue, isValid, problem, Problem, problemText
    , start, setStart
    , Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText
    , today, size, locale, disabled, readOnly
    )

{-| A form field that builds a repeating [Klar.Recurrence](Klar-Recurrence) rule:
how often (daily, weekly, monthly, yearly), every how many, on which days, how
it ends, with a sentence that says what the rule means and the next dates it
gives.

Use when: a person sets up something that repeats: a standing order, a delivery schedule, a recurring invoice.
Do not use when: you need a single date (as `Klar.DatePicker`) or the dates of a rule without a form (as `Klar.Recurrence`).
Quick path: `init`, `update`, `view`, `value`

See also [Klar.DatePicker](Klar-DatePicker) and [Klar.Recurrence](Klar-Recurrence).

    import Klar.Date exposing (Date)
    import Klar.Recurrence exposing (Rule)
    import Klar.RecurrencePicker as RecurrencePicker

    -- model: the picker needs the date the series starts on
    { repeat : RecurrencePicker.State }   -- RecurrencePicker.init "standing-order-repeat" firstDelivery

    -- msg
    RepeatMsg RecurrencePicker.Msg

    -- update
    RepeatMsg m ->
        let
            ( repeat, cmd ) =
                RecurrencePicker.update m model.repeat
        in
        ( { model | repeat = repeat }, Cmd.map RepeatMsg cmd )

    -- the delivery date was changed somewhere else
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
    RecurrencePicker.isValid model.repeat   -- False while the form is half filled in

The value is a `Maybe Rule`. `Nothing` means the date does not repeat, and also
that the form is not complete yet (the number of weeks is empty, "after" has no
number); `isValid` tells these apart (`problem` says why), and the field shows
the reason under itself. Save only when `isValid` is `True`. The state holds the
value and there are no out-messages: compare `value` before and after `update`
to react to a change.

The application gives the start date. The options for a monthly rule follow it
("On day 20", "On the third Tuesday", "On the last Tuesday" when the start is
the last one, and "On the last day of the month" when the start is the last day
of a month shorter than 31 days), and so does the weekday that is ticked first. Call `setStart`
when the date changes. A rule loaded from a server is put in with `setValue`.

**The form.** "Repeat" chooses between no repetition, daily, weekly, monthly and
yearly. The others show what that needs: "Every [2] weeks", the seven weekdays,
the choice of the day of the month, and how the rule ends: never, after a
number of times, or on a date (a [Klar.DatePicker](Klar-DatePicker)). The last
ticked weekday cannot be turned off, since a weekly rule needs a day; the field
says so in a message that screen readers announce politely. For "the 31st" of a
month, and 29 February, it asks what happens when there is no such day: use the
last day (the default) or skip the month. Below the fields a sentence says what
the rule means, in the language of the field, and the next five dates follow; both
are made by [Klar.Recurrence](Klar-Recurrence).

**The end.** An end date before the start date is a problem (`EndBeforeStart`):
the field has no `value` until it is changed, and says so under the fields. The
number of times and the interval are whole numbers from 1 to 2 147 483 647, the
same limits as in [Klar.Recurrence](Klar-Recurrence), so every rule that module
accepts can be shown.

**Skipped dates.** A rule can skip dates (`Recurrence.except`). The field does
not add any, but it shows the ones a loaded rule has, each as a tag with a button
that removes it, and a "Remove all" button; the keyboard focus moves to the next
date, or back to the field. A skipped date that no longer fits the rule (a
Tuesday in a rule that now repeats on Thursdays) stays in the list until it is
removed: nothing is dropped behind the user's back.

Everything is built from the components of this package, so the keyboard works
as it does there: the arrow keys in the choice of frequency, the weekdays as
check boxes, the spinbutton for the interval, the calendar of the date field. The
whole field is one `fieldset` with the label as its legend, and the fields that
come and go keep their place, so the keyboard focus stays where it is when the
frequency changes. The sentence is the one `aria-live="polite"` region, so a screen
reader hears the new meaning after each change, and the list of dates is not
announced. The only other message that can be announced is the status line about
the weekday that cannot be turned off (`role="status"`), which is empty until the
user tries.

With `readOnly` the field shows its label and the sentence and nothing else. The
built-in text follows `locale` (English by default).

**What this is not.** A rule is a set of calendar dates. A time of day and a time
zone are not part of it; your application adds them to each date.


# View

@docs view


# State

@docs State, init, Msg, update


# The rule

@docs value, setValue, isValid, problem, Problem, problemText


# The start date

@docs start, setStart


# Attributes

@docs Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText


# Look and behavior

@docs today, size, locale, disabled, readOnly

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.CheckboxGroup as CheckboxGroup
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.Field as Field
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.NumberInput as NumberInput
import Klar.Radio as Radio
import Klar.Recurrence as Recurrence exposing (Rule)
import Klar.Recurrence.RRule as RRule
import Klar.Recurrence.Spec as Spec
import Klar.Recurrence.Words as Words
import Klar.SegmentedControl as SegmentedControl
import Klar.Tag as Tag
import Klar.Theme exposing (Size(..))
import Time



-- STATE


{-| Everything the field keeps: the chosen frequency, the numbers and the dates
in its inputs, the days that are ticked, and the start date. Make it with
`init`, keep it in your model, and read the rule with `value`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , start : Date
    , frequency : Frequency
    , interval : NumberInput.State
    , weekdays : List Int
    , weekdaysChosen : Bool
    , refusals : Int
    , by : By
    , missing : Spec.Missing
    , end : EndKind
    , count : NumberInput.State
    , endDate : DatePicker.State
    , endDateVisited : Bool
    , exceptions : List Date
    }


type Frequency
    = Once
    | Daily
    | Weekly
    | Monthly
    | Yearly


type EndKind
    = EndNever
    | EndAfter
    | EndOn


{-| How a monthly or yearly rule finds its day. The first three follow the start
date; `Own` is a day that a rule loaded with `setValue` has, which the start does
not give.
-}
type By
    = ByDay
    | ByNth
    | ByLast
    | ByLastDay
    | Own Anchor


type Anchor
    = AnchorDay Int Int
    | AnchorNth Spec.Ordinal Int Int
    | AnchorLastDay Int


intervalLimits : List (NumberInput.Attribute msg)
intervalLimits =
    [ NumberInput.min 1, NumberInput.max (toFloat Spec.largest), NumberInput.decimals 0 ]


countLimits : List (NumberInput.Attribute msg)
countLimits =
    [ NumberInput.min 1, NumberInput.max (toFloat Spec.largest), NumberInput.decimals 0 ]


{-| A field that does not repeat. The `String` is the DOM id of the first control
(the choice of frequency) and must be unique on the page; the other parts get
ids made from it (`<id>-interval`, `<id>-weekdays`, `<id>-by`, `<id>-end`,
`<id>-count`, `<id>-until`, `<id>-summary` ...). The date is the start of the
series, which the options for a monthly rule follow.

    RecurrencePicker.init "standing-order-repeat" firstDelivery

-}
init : String -> Date -> State
init id startDate =
    State
        { id = id
        , start = startDate
        , frequency = Once
        , interval = NumberInput.init (id ++ "-interval") |> NumberInput.setValue (Just 1) |> NumberInput.setLimits intervalLimits
        , weekdays = [ Date.weekday startDate ]
        , weekdaysChosen = False
        , refusals = 0
        , by = ByDay
        , missing = Spec.UseLastDay
        , end = EndNever
        , count = NumberInput.init (id ++ "-count") |> NumberInput.setValue (Just 10) |> NumberInput.setLimits countLimits
        , endDate = DatePicker.init (id ++ "-until")
        , endDateVisited = False
        , exceptions = []
        }


{-| The date the series starts on, as given to `init` or `setStart`.
-}
start : State -> Date
start (State s) =
    s.start


{-| Moves the start date. The choices for a monthly or yearly rule follow it, and
so does the weekday of a weekly rule while nobody has chosen weekdays. A choice
the user made stays, and so does a rule that was put in with `setValue`.
-}
setStart : Date -> State -> State
setStart date (State s) =
    State
        { s
            | start = date
            , weekdays =
                if s.weekdaysChosen then
                    s.weekdays

                else
                    [ Date.weekday date ]
        }



-- THE RULE


type Built
    = NotRepeating
    | Complete Rule
    | Incomplete Problem


build : Inner -> Built
build s =
    case s.frequency of
        Once ->
            NotRepeating

        _ ->
            case ( wholeNumber (NumberInput.value s.interval), endOf s ) of
                ( Nothing, _ ) ->
                    Incomplete NeedsInterval

                ( Just _, Err found ) ->
                    Incomplete found

                ( Just every, Ok end ) ->
                    case
                        Recurrence.rule (patternOf s)
                            [ Recurrence.every every
                            , Recurrence.ends end
                            , Recurrence.except s.exceptions
                            ]
                    of
                        Ok rule ->
                            Complete rule

                        Err found ->
                            -- what the field cannot check itself, such as an end in the year 10000
                            Incomplete (Invalid found)


endOf : Inner -> Result Problem Recurrence.End
endOf s =
    case s.end of
        EndNever ->
            Ok Recurrence.never

        EndAfter ->
            case wholeNumber (NumberInput.value s.count) of
                Just n ->
                    Ok (Recurrence.after n)

                Nothing ->
                    Err NeedsCount

        EndOn ->
            case DatePicker.value s.endDate of
                Just date ->
                    if Date.compare date s.start == LT then
                        Err EndBeforeStart

                    else
                        Ok (Recurrence.until date)

                Nothing ->
                    Err NeedsEndDate


{-| A whole number from 1 up to the largest that a rule takes, or `Nothing`.
-}
wholeNumber : Maybe Float -> Maybe Int
wholeNumber maybe =
    case maybe of
        Just number ->
            if number >= 1 && number <= toFloat Spec.largest && number == toFloat (round number) then
                Just (round number)

            else
                Nothing

        Nothing ->
            Nothing


patternOf : Inner -> Recurrence.Pattern
patternOf s =
    case s.frequency of
        Weekly ->
            case List.map toWeekday s.weekdays of
                day :: others ->
                    Recurrence.weekly day others

                [] ->
                    Recurrence.weekly (toWeekday (Date.weekday s.start)) []

        Monthly ->
            case anchorOf s of
                AnchorDay _ day ->
                    withMissing s (Recurrence.monthlyOnDay day)

                AnchorNth ordinal weekday _ ->
                    Recurrence.monthlyOnWeekday (toOrdinal ordinal) (toWeekday weekday)

                AnchorLastDay _ ->
                    -- the 31st, or the last day of a shorter month
                    Recurrence.monthlyOnDay 31

        Yearly ->
            case anchorOf s of
                AnchorDay month day ->
                    withMissing s (Recurrence.yearlyOnDate (toMonth month) day)

                AnchorNth ordinal weekday month ->
                    Recurrence.yearlyOnWeekday (toOrdinal ordinal) (toWeekday weekday) (toMonth month)

                AnchorLastDay month ->
                    -- 29 February is 28 February in the other years
                    Recurrence.yearlyOnDate (toMonth month) (Date.daysInMonth 2024 month)

        _ ->
            Recurrence.daily


withMissing : Inner -> Recurrence.Pattern -> Recurrence.Pattern
withMissing s pattern =
    case s.missing of
        Spec.Skip ->
            Recurrence.skippingMissingDays pattern

        Spec.UseLastDay ->
            pattern


{-| The rule the field holds. `Nothing` means that the date does not repeat, and
also that the form is not complete yet, so check `isValid` before you save:
`value` alone cannot tell "does not repeat" from "half filled in". The rule is
counted from the start date of the field.

    if RecurrencePicker.isValid model.repeat then
        save (RecurrencePicker.value model.repeat)

    else
        -- the field already shows why under itself
        ( model, Cmd.none )

-}
value : State -> Maybe Rule
value (State s) =
    case build s of
        Complete rule ->
            Just rule

        _ ->
            Nothing


{-| Whether `value` is what the user means: `True` when the field does not
repeat or holds a complete rule, `False` while a number is missing or cannot be
used, the end date is not chosen, or the end date is before the start date (see
`problem`).
-}
isValid : State -> Bool
isValid state =
    problem state == Nothing


{-| Why the field is not valid: a number that is missing or cannot be used, an
end date that is not chosen, or an end date that is before the start date.
`Nothing` when the field is complete, and when it does not repeat at all. The
field itself shows the message under its fields, and `problemText` gives it in
words (for a summary of the form's problems).
-}
problem : State -> Maybe Problem
problem (State s) =
    case build s of
        Incomplete found ->
            Just found

        _ ->
            Nothing


{-| What is missing from the field. It is opaque, so that more can be added;
`problemText` says it in a sentence.
-}
type Problem
    = NeedsInterval
    | NeedsCount
    | NeedsEndDate
    | EndBeforeStart
    | Invalid Recurrence.Problem


{-| The problem in a sentence, in the language of the locale.

    RecurrencePicker.problem model.repeat
        |> Maybe.map (RecurrencePicker.problemText Locale.en)

-}
problemText : Locale -> Problem -> String
problemText lang found =
    case found of
        NeedsInterval ->
            Locale.pick lang
                { nb = "Skriv inn hvor ofte det gjentas: et helt tall, 1 eller mer."
                , en = "Enter how often it repeats: a whole number, 1 or more."
                }

        NeedsCount ->
            Locale.pick lang
                { nb = "Skriv inn hvor mange ganger det gjentas: et helt tall, 1 eller mer."
                , en = "Enter how many times it repeats: a whole number, 1 or more."
                }

        NeedsEndDate ->
            Locale.pick lang
                { nb = "Velg datoen den slutter."
                , en = "Choose the date it ends."
                }

        EndBeforeStart ->
            Locale.pick lang
                { nb = "Sluttdatoen er før startdatoen."
                , en = "The end date is before the start date."
                }

        Invalid found_ ->
            Recurrence.problemText lang found_


{-| Shows a rule in the field, or "Does not repeat" for `Nothing`: for a rule
loaded from a server. Everything the rule says is put in the inputs (the
interval, the days, the end), and the dates it skips are kept. A text the user was
typing is dropped.

The field shows the rule as it is and never changes it. The day of a monthly or
yearly rule is kept as the rule has it, also when it is the day of the start date:
the choice is listed (once, with the choices that follow the start date) and
`setStart` does not move it. A rule that is loaded with an end date before the
start date has no `value` and the problem `EndBeforeStart` until one of them is
changed.

    RecurrencePicker.setValue (Just rule) model.repeat

-}
setValue : Maybe Rule -> State -> State
setValue maybeRule (State s) =
    case maybeRule of
        Nothing ->
            State { s | frequency = Once, exceptions = [] }

        Just rule ->
            case RRule.fromText (Recurrence.toRRule rule) of
                Err _ ->
                    State s

                Ok spec ->
                    State (fill spec (Recurrence.exceptions rule) s)


fill : Spec.Spec -> List Date -> Inner -> Inner
fill spec skipped s =
    let
        withEnd =
            case spec.end of
                Spec.Never ->
                    { s | end = EndNever }

                Spec.After n ->
                    { s | end = EndAfter, count = NumberInput.setValue (Just (toFloat n)) s.count }

                Spec.Until date ->
                    { s | end = EndOn, endDate = DatePicker.setValue (Just date) s.endDate }

        common =
            { withEnd
                | interval = NumberInput.setValue (Just (toFloat spec.every)) s.interval
                , exceptions = skipped
                , refusals = 0
            }
    in
    case spec.pattern of
        Spec.Daily ->
            { common | frequency = Daily }

        Spec.Weekly days ->
            { common | frequency = Weekly, weekdays = days, weekdaysChosen = True }

        -- The month of a monthly day is 0: it follows the start date when the
        -- frequency becomes yearly, and it is not compared while it is monthly.
        Spec.MonthlyDay day missing ->
            { common | frequency = Monthly, by = Own (AnchorDay 0 day), missing = keepMissing (day >= 29) missing s }

        Spec.MonthlyWeekday ordinal weekday ->
            { common | frequency = Monthly, by = Own (AnchorNth ordinal weekday 0) }

        Spec.YearlyDate month day missing ->
            { common | frequency = Yearly, by = Own (AnchorDay month day), missing = keepMissing (month == 2 && day == 29) missing s }

        Spec.YearlyWeekday ordinal weekday month ->
            { common | frequency = Yearly, by = Own (AnchorNth ordinal weekday month) }


{-| What a choice means for a start date.
-}
anchorFor : Frequency -> Date -> By -> Anchor
anchorFor frequency startDate by =
    case by of
        ByDay ->
            AnchorDay (Date.month startDate) (Date.day startDate)

        ByNth ->
            AnchorNth (ordinalOfStart startDate) (Date.weekday startDate) (Date.month startDate)

        ByLast ->
            if offersLast startDate then
                AnchorNth Spec.Last (Date.weekday startDate) (Date.month startDate)

            else
                anchorFor frequency startDate ByNth

        ByLastDay ->
            if offersLastDay frequency startDate then
                AnchorLastDay (Date.month startDate)

            else
                anchorFor frequency startDate ByDay

        Own anchor ->
            followStart startDate anchor


{-| A loaded monthly day has no month of its own (0): it takes the month of the
start date.
-}
followStart : Date -> Anchor -> Anchor
followStart startDate anchor =
    case anchor of
        AnchorDay 0 day ->
            AnchorDay (Date.month startDate) day

        AnchorNth ordinal weekday 0 ->
            AnchorNth ordinal weekday (Date.month startDate)

        AnchorLastDay 0 ->
            AnchorLastDay (Date.month startDate)

        _ ->
            anchor


{-| The pattern a choice gives, with the missing-day question at its default. Two
choices with the same pattern here mean the same rule: a monthly rule does not
look at the month, "the last day of April" is "30 April", and "29 February"
that uses 28 February in other years is "the last day of February". The
question is still asked about the choice that is listed.
-}
patternFor : Inner -> By -> Recurrence.Pattern
patternFor s by =
    patternOf { s | by = by, missing = Spec.UseLastDay }


{-| The question about a missing day is only asked for a day that can be
missing; a loaded rule on another day (made canonical as "skip") keeps the
default, so the question starts at "use the last day" when it comes up.
-}
keepMissing : Bool -> Spec.Missing -> Inner -> Spec.Missing
keepMissing canBeMissing missing s =
    if canBeMissing then
        missing

    else
        s.missing


anchorOf : Inner -> Anchor
anchorOf s =
    anchorFor s.frequency s.start s.by


{-| The first, second, third or fourth weekday of the month that the start date
is, and the last for a fifth.
-}
ordinalOfStart : Date -> Spec.Ordinal
ordinalOfStart startDate =
    case (Date.day startDate - 1) // 7 of
        0 ->
            Spec.First

        1 ->
            Spec.Second

        2 ->
            Spec.Third

        3 ->
            Spec.Fourth

        _ ->
            Spec.Last


{-| Whether no later day of the month has the same weekday as the date.
-}
endsMonth : Date -> Bool
endsMonth date =
    Date.day date + 7 > Date.daysInMonth (Date.year date) (Date.month date)


{-| Whether "the last Tuesday" is a choice of its own: the start date is the last
such weekday of its month and not also the fifth, which `ByNth` already says as
"the last".
-}
offersLast : Date -> Bool
offersLast date =
    endsMonth date && ordinalOfStart date /= Spec.Last


{-| Whether "the last day of the month" is a choice of its own, that is a rule
that `ByDay` does not already give. Monthly: the start date is the last day of a
month shorter than 31 days (the 31st is already the last day of every shorter
month). Yearly: only 28 February of a common year, because "the last day of
February" is then the 29th in leap years; on any other last day of a month the
date itself is the last day every year.
-}
offersLastDay : Frequency -> Date -> Bool
offersLastDay frequency date =
    let
        lastOfItsMonth =
            Date.day date == Date.daysInMonth (Date.year date) (Date.month date)
    in
    case frequency of
        Monthly ->
            lastOfItsMonth && Date.day date < 31

        Yearly ->
            lastOfItsMonth && Date.month date == 2 && Date.day date == 28

        _ ->
            False


{-| The choices a monthly or yearly rule offers: the day, the n-th weekday, the
last weekday and the last day of the month when the start gives them, one choice
per rule (a choice that gives the same rule as an earlier one is left out). A
rule that was loaded has its own choice, which stands in the place of the one
that means the same, or comes last when the start gives none of them.
-}
choices : Inner -> List By
choices s =
    let
        candidates =
            [ ByDay, ByNth ]
                ++ (if offersLast s.start then
                        [ ByLast ]

                    else
                        []
                   )
                ++ (if offersLastDay s.frequency s.start then
                        [ ByLastDay ]

                    else
                        []
                   )

        derived =
            List.foldl
                (\by kept ->
                    if List.any (\other -> patternFor s other == patternFor s by) kept then
                        kept

                    else
                        kept ++ [ by ]
                )
                []
                candidates
    in
    case s.by of
        Own anchor ->
            let
                same by =
                    patternFor s by == patternFor s (Own anchor)
            in
            if List.any same derived then
                List.map
                    (\by ->
                        if same by then
                            Own anchor

                        else
                            by
                    )
                    derived

            else
                derived ++ [ Own anchor ]

        _ ->
            derived


toWeekday : Int -> Time.Weekday
toWeekday n =
    case n of
        1 ->
            Time.Mon

        2 ->
            Time.Tue

        3 ->
            Time.Wed

        4 ->
            Time.Thu

        5 ->
            Time.Fri

        6 ->
            Time.Sat

        _ ->
            Time.Sun


toMonth : Int -> Time.Month
toMonth n =
    case n of
        1 ->
            Time.Jan

        2 ->
            Time.Feb

        3 ->
            Time.Mar

        4 ->
            Time.Apr

        5 ->
            Time.May

        6 ->
            Time.Jun

        7 ->
            Time.Jul

        8 ->
            Time.Aug

        9 ->
            Time.Sep

        10 ->
            Time.Oct

        11 ->
            Time.Nov

        _ ->
            Time.Dec


toOrdinal : Spec.Ordinal -> Recurrence.Ordinal
toOrdinal ordinal =
    case ordinal of
        Spec.First ->
            Recurrence.first

        Spec.Second ->
            Recurrence.second

        Spec.Third ->
            Recurrence.third

        Spec.Fourth ->
            Recurrence.fourth

        Spec.Last ->
            Recurrence.last



-- UPDATE


{-| The messages of the field. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.
-}
type Msg
    = FrequencyChosen Frequency
    | IntervalMsg NumberInput.Msg
    | WeekdaysChanged (List Int)
    | ByChosen By
    | MissingChosen Spec.Missing
    | EndChosen EndKind
    | CountMsg NumberInput.Msg
    | EndDateMsg DatePicker.Msg
    | ExceptionRemoved Date
    | ExceptionsCleared
    | Ignored


{-| Handles a message of the field. Returns the new state and the command that
moves the keyboard focus (after a stepper button of a number field, for
example). Map the command with the constructor of your own `Msg`.

    RepeatMsg m ->
        let
            ( repeat, cmd ) =
                RecurrencePicker.update m model.repeat
        in
        ( { model | repeat = repeat }, Cmd.map RepeatMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        FrequencyChosen frequency ->
            ( State { s | frequency = frequency, refusals = 0 }, Cmd.none )

        IntervalMsg inner ->
            let
                ( interval, cmd ) =
                    NumberInput.update inner s.interval
            in
            ( State { s | interval = interval }, Cmd.map IntervalMsg cmd )

        WeekdaysChanged days ->
            if List.isEmpty days then
                -- the last weekday cannot be turned off: say so, do not just ignore the click
                ( State { s | refusals = s.refusals + 1 }, Cmd.none )

            else
                ( State { s | weekdays = List.sort days, weekdaysChosen = True, refusals = 0 }, Cmd.none )

        ByChosen by ->
            ( State { s | by = by }, Cmd.none )

        MissingChosen missing ->
            ( State { s | missing = missing }, Cmd.none )

        EndChosen end ->
            ( State { s | end = end }, Cmd.none )

        CountMsg inner ->
            let
                ( count, cmd ) =
                    NumberInput.update inner s.count
            in
            ( State { s | count = count }, Cmd.map CountMsg cmd )

        EndDateMsg inner ->
            let
                ( endDate, cmd ) =
                    DatePicker.update inner s.endDate
            in
            ( State { s | endDate = endDate, endDateVisited = True }, Cmd.map EndDateMsg cmd )

        ExceptionRemoved date ->
            let
                remaining =
                    List.filter (\other -> other /= date) s.exceptions

                position =
                    s.exceptions
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( _, other ) -> other == date)
                        |> List.head
                        |> Maybe.map Tuple.first
                        |> Maybe.withDefault 0

                -- the button of the date that took its place, else the one before, else the field
                neighbour =
                    case List.drop position remaining of
                        next :: _ ->
                            Just next

                        [] ->
                            List.head (List.reverse remaining)
            in
            ( State { s | exceptions = remaining }
            , Internal.focus (Maybe.withDefault s.id (Maybe.map (removeId s.id) neighbour)) Ignored
            )

        ExceptionsCleared ->
            ( State { s | exceptions = [] }, Internal.focus s.id Ignored )

        Ignored ->
            ( State s, Cmd.none )



-- ATTRIBUTES


{-| A setting of the field. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , size : Size
    , locale : Locale
    , today : Maybe Date
    , disabled : Bool
    , readOnly : Bool
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , size = Medium
        , locale = Locale.default
        , today = Nothing
        , disabled = False
        , readOnly = False
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The legend of the field: its name, above the choices. Without it the legend
is the built-in "Repeat", kept for screen readers only.
-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Keeps the label for screen readers but does not show it, for a field whose
purpose is clear from what surrounds it. Needs `label`.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| A line of help under the field. It describes the whole group
(`aria-describedby`), so screen readers read it when the focus enters.
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| An error message of your application, shown under the field and announced to
screen readers (`role="alert"`). While the field has a problem of its own (see
`problem`) that message is shown instead.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Puts a `*` after the label. It only marks the field and checks nothing: "Does
not repeat" is a valid answer.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| Today, from the application (the library never reads the clock). The date
field of "ends on" marks it, and the next dates start from today when it is
later than the start date. Without it the list shows the first dates of the
series.
-}
today : Date -> Attribute msg
today date =
    Attribute (\config -> { config | today = Just date })


{-| The size of the controls: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). Default: `Medium`.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| The language of the built-in text, of the sentence and of the dates (see
[Klar.Locale](Klar-Locale)). Default: `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })


{-| Disables every control. Takes a `Bool` so that it can come from your model,
for example while a form is saved. Default: `False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| Shows the label and the sentence only ("Every 2 weeks on Monday and
Thursday"), with no controls and no list of dates, for a page that displays a
saved rule. Default: `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })



-- TEXT


type alias Strings =
    { repeat : String
    , frequency : String
    , once : String
    , daily : String
    , weekly : String
    , monthly : String
    , yearly : String
    , repeatEvery : String
    , repeatOn : String
    , ends : String
    , never : String
    , afterCount : String
    , onDate : String
    , afterPrefix : String
    , endDate : String
    , count : String
    , nextDates : String
    , firstDates : String
    , andMore : String
    , noDates : String
    , skipped : String
    , removeAll : String
    }


strings : Locale -> Strings
strings lang =
    Locale.pick lang
        { nb =
            { repeat = "Gjenta"
            , frequency = "Hvor ofte"
            , once = "Gjentas ikke"
            , daily = "Daglig"
            , weekly = "Ukentlig"
            , monthly = "Månedlig"
            , yearly = "Årlig"
            , repeatEvery = "Gjenta hver"
            , repeatOn = "Gjenta på"
            , ends = "Slutter"
            , never = "Aldri"
            , afterCount = "Etter et antall ganger"
            , onDate = "På en dato"
            , afterPrefix = "Etter"
            , endDate = "Sluttdato"
            , count = "Antall ganger"
            , nextDates = "Neste datoer"
            , firstDates = "Første datoer"
            , andMore = "og flere"
            , noDates = "Ingen datoer passer til regelen."
            , skipped = "Datoer som hoppes over"
            , removeAll = "Fjern alle"
            }
        , en =
            { repeat = "Repeat"
            , frequency = "Frequency"
            , once = "Does not repeat"
            , daily = "Daily"
            , weekly = "Weekly"
            , monthly = "Monthly"
            , yearly = "Yearly"
            , repeatEvery = "Repeat every"
            , repeatOn = "Repeat on"
            , ends = "Ends"
            , never = "Never"
            , afterCount = "After a number of times"
            , onDate = "On a date"
            , afterPrefix = "After"
            , endDate = "End date"
            , count = "Number of times"
            , nextDates = "Next dates"
            , firstDates = "First dates"
            , andMore = "and more"
            , noDates = "No dates match the rule."
            , skipped = "Skipped dates"
            , removeAll = "Remove all"
            }
        }


{-| "Every" and "weeks", with the right forms for the number.
-}
everyWords : Locale -> Frequency -> Maybe Float -> { prefix : String, unit : String }
everyWords lang frequency number =
    let
        n =
            number |> Maybe.map round |> Maybe.withDefault 2

        pick one other =
            Format.plural lang n { one = one, other = other }

        -- Norwegian counts with an ordinal: hver 2. uke
        nth unit =
            if n == 1 then
                unit

            else
                ". " ++ unit
    in
    case frequency of
        Daily ->
            Locale.pick lang
                { nb = { prefix = "Hver", unit = nth "dag" }
                , en = { prefix = "Every", unit = pick "day" "days" }
                }

        Weekly ->
            Locale.pick lang
                { nb = { prefix = "Hver", unit = nth "uke" }
                , en = { prefix = "Every", unit = pick "week" "weeks" }
                }

        Monthly ->
            Locale.pick lang
                { nb = { prefix = "Hver", unit = nth "måned" }
                , en = { prefix = "Every", unit = pick "month" "months" }
                }

        _ ->
            Locale.pick lang
                { nb = { prefix = "Hvert", unit = nth "år" }
                , en = { prefix = "Every", unit = pick "year" "years" }
                }


{-| The words of one choice of the day of a monthly or yearly rule.
-}
anchorLabel : Locale -> Frequency -> Anchor -> String
anchorLabel lang frequency anchor =
    case anchor of
        AnchorDay month day ->
            Locale.pick lang
                { nb =
                    if frequency == Yearly then
                        "Den " ++ String.fromInt day ++ ". " ++ Locale.monthLong lang month

                    else
                        "Den " ++ String.fromInt day ++ ". i måneden"
                , en =
                    if frequency == Yearly then
                        "On " ++ String.fromInt day ++ " " ++ Locale.monthLong lang month

                    else
                        "On day " ++ String.fromInt day ++ " of the month"
                }

        AnchorNth ordinal weekday month ->
            let
                phrase =
                    Words.ordinalDay lang ordinal weekday
            in
            Locale.pick lang
                { nb =
                    if frequency == Yearly then
                        "Den " ++ phrase ++ " i " ++ Locale.monthLong lang month

                    else
                        "Den " ++ phrase ++ " i måneden"
                , en =
                    if frequency == Yearly then
                        "On the " ++ phrase ++ " of " ++ Locale.monthLong lang month

                    else
                        "On the " ++ phrase ++ " of the month"
                }

        AnchorLastDay month ->
            Locale.pick lang
                { nb =
                    if frequency == Yearly then
                        "Den siste dagen i " ++ Locale.monthLong lang month

                    else
                        "Den siste dagen i måneden"
                , en =
                    if frequency == Yearly then
                        "On the last day of " ++ Locale.monthLong lang month

                    else
                        "On the last day of the month"
                }


{-| What to ask when the day may be missing: for the 29th to the 31st of a
month, and for 29 February.
-}
missingQuestion : Locale -> Inner -> Maybe { legend : String, useLast : String, skip : String }
missingQuestion lang s =
    case ( s.frequency, anchorOf s ) of
        ( Monthly, AnchorDay _ day ) ->
            if day >= 29 then
                Just
                    (Locale.pick lang
                        { nb =
                            { legend = "I måneder uten dag " ++ String.fromInt day
                            , useLast = "Bruk siste dag i måneden"
                            , skip = "Hopp over måneden"
                            }
                        , en =
                            { legend = "In months without day " ++ String.fromInt day
                            , useLast = "Use the last day of the month"
                            , skip = "Skip the month"
                            }
                        }
                    )

            else
                Nothing

        ( Yearly, AnchorDay 2 29 ) ->
            Just
                (Locale.pick lang
                    { nb = { legend = "I år uten 29. februar", useLast = "Bruk 28. februar", skip = "Hopp over året" }
                    , en = { legend = "In years without 29 February", useLast = "Use 28 February", skip = "Skip the year" }
                    }
                )

        _ ->
            Nothing


refusalText : Locale -> Inner -> String
refusalText lang s =
    let
        day =
            s.weekdays |> List.head |> Maybe.withDefault 1 |> Locale.weekdayLong lang
    in
    Locale.pick lang
        { nb = capitalize day ++ " kan ikke slås av: minst én ukedag må være valgt."
        , en = day ++ " cannot be turned off: at least one weekday has to be selected."
        }


capitalize : String -> String
capitalize text =
    case String.uncons text of
        Just ( first, rest ) ->
            String.cons (Char.toUpper first) rest

        Nothing ->
            text



-- VIEW


{-| The field. The first argument wraps the messages of the field in one of
yours.

    RecurrencePicker.view RepeatMsg
        [ RecurrencePicker.label "Repeat"
        , RecurrencePicker.today model.today
        ]
        model.repeat

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        text =
            strings config.locale

        built =
            build s

        legendText =
            case config.field.label of
                Just given ->
                    given

                Nothing ->
                    text.repeat

        field =
            Field.setId s.id config.field
                |> (\base ->
                        { base
                            | label = Just legendText
                            , labelHidden = config.field.label == Nothing || config.field.labelHidden
                            , error = shownError config s built
                        }
                   )
    in
    Field.viewGroup field
        (Html.fieldset
            (Field.describedByAttributes field
                ++ [ Attr.id (s.id ++ "-fieldset")
                   , Internal.cls
                        [ "klar-recurrence"
                        , if config.readOnly then
                            "klar-recurrence--readonly"

                          else
                            ""
                        , if field.error /= Nothing then
                            "klar-recurrence--invalid"

                          else
                            ""
                        ]
                   ]
            )
            [ viewLegend field legendText
            , if config.readOnly then
                viewReadOnly config built

              else
                viewBody toMsg config text built s
            ]
        )


{-| The message under the field: the problem the field has of its own when it
can be shown without getting in the way of someone who is typing, else the
message of the application.

A number field and the date field show their own messages when their text is
wrong; this one covers a field that is empty, once it has been visited.

-}
shownError : Config -> Inner -> Built -> Maybe String
shownError config s built =
    case built of
        Incomplete found ->
            if visited s found then
                Just (problemText config.locale found)

            else
                config.field.error

        _ ->
            config.field.error


visited : Inner -> Problem -> Bool
visited s found =
    case found of
        NeedsInterval ->
            NumberInput.isTouched s.interval && NumberInput.isValid s.interval

        NeedsCount ->
            NumberInput.isTouched s.count && NumberInput.isValid s.count

        NeedsEndDate ->
            s.endDateVisited && DatePicker.isValid s.endDate

        EndBeforeStart ->
            True

        Invalid _ ->
            True


viewLegend : Field.Config -> String -> Html msg
viewLegend field legendText =
    Html.legend
        [ Internal.cls
            [ "klar-field__label"
            , "klar-recurrence__legend"
            , if field.labelHidden then
                "klar-sr-only"

              else
                ""
            ]
        , Attr.id (Field.labelId field)
        ]
        [ Html.text legendText
        , Internal.viewIf field.required
            (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
        , case ( field.required, field.optionalText ) of
            ( False, Just optional ) ->
                Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

            _ ->
                Html.text ""
        ]


viewReadOnly : Config -> Built -> Html msg
viewReadOnly config built =
    Html.p [ Internal.cls [ "klar-recurrence__summary" ] ]
        [ Html.text (summaryText config.locale built) ]


summaryText : Locale -> Built -> String
summaryText lang built =
    case built of
        NotRepeating ->
            (strings lang).once

        Complete rule ->
            Recurrence.describe lang rule

        Incomplete _ ->
            ""


viewBody : (Msg -> msg) -> Config -> Strings -> Built -> Inner -> Html msg
viewBody toMsg config text built s =
    let
        repeating =
            s.frequency /= Once
    in
    Keyed.node "div"
        [ Internal.cls [ "klar-recurrence__body" ] ]
        (List.filterMap identity
            [ Just ( "frequency", viewFrequency toMsg config text s )
            , onlyIf repeating ( "interval", viewInterval toMsg config text s )
            , onlyIf (s.frequency == Weekly) ( "weekdays", viewWeekdays toMsg config text s )
            , onlyIf (s.frequency == Monthly || s.frequency == Yearly) ( "by", viewBy toMsg config text s )
            , missingQuestion config.locale s
                |> Maybe.map (\question -> ( "missing", viewMissing toMsg config question s ))
            , onlyIf repeating ( "end", viewEnd toMsg config text s )
            , onlyIf (repeating && not (List.isEmpty s.exceptions)) ( "skipped", viewSkipped toMsg config text s )
            , Just ( "summary", viewSummary config built s )
            , onlyIf repeating ( "preview", viewPreview config text built s )
            ]
        )


onlyIf : Bool -> a -> Maybe a
onlyIf condition thing =
    if condition then
        Just thing

    else
        Nothing


viewFrequency : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewFrequency toMsg config text s =
    SegmentedControl.view
        [ SegmentedControl.id s.id
        , SegmentedControl.label text.frequency
        , SegmentedControl.labelHidden
        , SegmentedControl.options
            [ SegmentedControl.option Once text.once
            , SegmentedControl.option Daily text.daily
            , SegmentedControl.option Weekly text.weekly
            , SegmentedControl.option Monthly text.monthly
            , SegmentedControl.option Yearly text.yearly
            ]
        , SegmentedControl.selected s.frequency
        , SegmentedControl.onChange (FrequencyChosen >> toMsg)
        , SegmentedControl.size config.size
        , SegmentedControl.disabled config.disabled
        ]


viewInterval : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewInterval toMsg config text s =
    let
        words =
            everyWords config.locale s.frequency (NumberInput.value s.interval)
    in
    Html.div [ Internal.cls [ "klar-recurrence__interval" ] ]
        [ NumberInput.view (\inner -> toMsg (IntervalMsg inner))
            (intervalLimits
                ++ [ NumberInput.label text.repeatEvery
                   , NumberInput.labelHidden
                   , NumberInput.prefixText words.prefix
                   , NumberInput.suffixText words.unit
                   , NumberInput.size config.size
                   , NumberInput.locale config.locale
                   , NumberInput.disabled config.disabled
                   ]
            )
            s.interval
        ]


viewWeekdays : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewWeekdays toMsg config text s =
    Html.div [ Internal.cls [ "klar-recurrence__weekdays" ] ]
        [ CheckboxGroup.view
            [ CheckboxGroup.id (s.id ++ "-weekdays")
            , CheckboxGroup.label text.repeatOn
            , CheckboxGroup.options
                (List.map
                    (\weekday -> CheckboxGroup.option (String.fromInt weekday) (Locale.weekdayLong config.locale weekday))
                    (List.range 1 7)
                )
            , CheckboxGroup.selected (List.map String.fromInt s.weekdays)
            , CheckboxGroup.onChange (\keys -> toMsg (WeekdaysChanged (List.filterMap String.toInt keys)))
            , CheckboxGroup.horizontal
            , CheckboxGroup.size config.size
            , CheckboxGroup.disabled config.disabled
            , CheckboxGroup.locale config.locale
            ]
        , viewRefusal config s
        ]


{-| The reason why the last weekday did not turn off. The element is always
there, so that a screen reader that listens to it hears the text when it
appears; each refusal is a new text node, so that it is read again.
-}
viewRefusal : Config -> Inner -> Html msg
viewRefusal config s =
    Keyed.node "p"
        [ Internal.cls [ "klar-recurrence__note" ]
        , Attr.id (s.id ++ "-note")
        , Attr.attribute "role" "status"
        ]
        (if s.refusals > 0 then
            [ ( String.fromInt s.refusals, Html.text (refusalText config.locale s) ) ]

         else
            []
        )


viewBy : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewBy toMsg config text s =
    Html.div [ Internal.cls [ "klar-recurrence__by" ] ]
        [ Radio.view
            [ Radio.id (s.id ++ "-by")
            , Radio.label text.repeatOn
            , Radio.options
                (List.map (\by -> Radio.option by (anchorLabel config.locale s.frequency (anchorFor s.frequency s.start by))) (choices s))
            , Radio.selected (Just (shownBy s))
            , Radio.onChange (ByChosen >> toMsg)
            , Radio.size config.size
            , Radio.disabled config.disabled
            ]
        ]


{-| The choice that is ticked. A choice the start no longer offers (the last
weekday after the start moved, the last day of the month in a yearly rule) is
shown as the listed choice that gives the same rule: the n-th weekday, the day.
-}
shownBy : Inner -> By
shownBy s =
    let
        offered =
            choices s
    in
    if List.member s.by offered then
        s.by

    else
        offered
            |> List.filter (\by -> patternFor s by == patternFor s s.by)
            |> List.head
            |> Maybe.withDefault ByDay


viewMissing : (Msg -> msg) -> Config -> { legend : String, useLast : String, skip : String } -> Inner -> Html msg
viewMissing toMsg config question s =
    Html.div [ Internal.cls [ "klar-recurrence__missing" ] ]
        [ Radio.view
            [ Radio.id (s.id ++ "-missing")
            , Radio.label question.legend
            , Radio.options
                [ Radio.option Spec.UseLastDay question.useLast
                , Radio.option Spec.Skip question.skip
                ]
            , Radio.selected (Just s.missing)
            , Radio.onChange (MissingChosen >> toMsg)
            , Radio.horizontal
            , Radio.size config.size
            , Radio.disabled config.disabled
            ]
        ]


viewEnd : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewEnd toMsg config text s =
    Keyed.node "div"
        [ Internal.cls [ "klar-recurrence__end" ] ]
        (( "choice"
         , Radio.view
            [ Radio.id (s.id ++ "-end")
            , Radio.label text.ends
            , Radio.options
                [ Radio.option EndNever text.never
                , Radio.option EndAfter text.afterCount
                , Radio.option EndOn text.onDate
                ]
            , Radio.selected (Just s.end)
            , Radio.onChange (EndChosen >> toMsg)
            , Radio.horizontal
            , Radio.size config.size
            , Radio.disabled config.disabled
            ]
         )
            :: (case s.end of
                    EndNever ->
                        []

                    EndAfter ->
                        [ ( "count"
                          , Html.div [ Internal.cls [ "klar-recurrence__end-field" ] ]
                                [ NumberInput.view (\inner -> toMsg (CountMsg inner))
                                    (countLimits
                                        ++ [ NumberInput.label text.count
                                           , NumberInput.labelHidden
                                           , NumberInput.prefixText text.afterPrefix
                                           , NumberInput.suffixText (timesWord config.locale (NumberInput.value s.count))
                                           , NumberInput.size config.size
                                           , NumberInput.locale config.locale
                                           , NumberInput.disabled config.disabled
                                           ]
                                    )
                                    s.count
                                ]
                          )
                        ]

                    EndOn ->
                        [ ( "date"
                          , Html.div [ Internal.cls [ "klar-recurrence__end-field" ] ]
                                [ DatePicker.view (\inner -> toMsg (EndDateMsg inner))
                                    ([ DatePicker.label text.endDate
                                     , DatePicker.labelHidden
                                     , DatePicker.size config.size
                                     , DatePicker.locale config.locale
                                     , DatePicker.disabled config.disabled
                                     ]
                                        ++ (case config.today of
                                                Just date ->
                                                    [ DatePicker.today date ]

                                                Nothing ->
                                                    []
                                           )
                                    )
                                    s.endDate
                                ]
                          )
                        ]
               )
        )


timesWord : Locale -> Maybe Float -> String
timesWord lang number =
    let
        n =
            number |> Maybe.map round |> Maybe.withDefault 2
    in
    Locale.pick lang
        { nb =
            if n == 1 then
                "gang"

            else
                "ganger"
        , en =
            if n == 1 then
                "time"

            else
                "times"
        }


{-| The dates that the rule skips, each with a button that takes it out, and a
button that takes them all out. The dates that no longer fit the rule (a Tuesday
skipped in a rule that has moved to Thursdays) stay in the list until they are
removed: nothing is dropped behind the user's back.
-}
viewSkipped : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewSkipped toMsg config text s =
    Html.div
        [ Internal.cls [ "klar-recurrence__skipped" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-labelledby" (s.id ++ "-skipped-title")
        ]
        [ Html.p
            [ Internal.cls [ "klar-recurrence__skipped-title" ]
            , Attr.id (s.id ++ "-skipped-title")
            ]
            [ Html.text text.skipped ]
        , Html.ul [ Internal.cls [ "klar-recurrence__skipped-list" ] ]
            (List.map
                (\date ->
                    Html.li [ Internal.cls [ "klar-recurrence__skipped-item" ] ]
                        [ Tag.view
                            ([ Tag.size config.size, Tag.locale config.locale ]
                                ++ (if config.disabled then
                                        []

                                    else
                                        [ Tag.onRemove (toMsg (ExceptionRemoved date))
                                        , Tag.removeId (removeId s.id date)
                                        ]
                                   )
                            )
                            (Format.dateLong config.locale date)
                        ]
                )
                s.exceptions
            )
        , Internal.viewIf (not config.disabled)
            (Button.view [ Button.link, Button.small, Button.onClick (toMsg ExceptionsCleared) ] text.removeAll)
        ]


{-| The DOM id of the button that takes a skipped date out.
-}
removeId : String -> Date -> String
removeId id date =
    id ++ "-skip-" ++ Date.toIso date


viewSummary : Config -> Built -> Inner -> Html msg
viewSummary config built s =
    Html.p
        [ Internal.cls [ "klar-recurrence__summary" ]
        , Attr.id (s.id ++ "-summary")
        , Attr.attribute "aria-live" "polite"
        , Attr.attribute "aria-atomic" "true"
        ]
        [ Html.text (summaryText config.locale built) ]


{-| The next five dates, from today when the application gave it and it is
later than the start, and from the start otherwise. A sixth date is looked for,
only to say "and more".
-}
viewPreview : Config -> Strings -> Built -> Inner -> Html msg
viewPreview config text built s =
    case built of
        Complete rule ->
            let
                from =
                    case config.today of
                        Just date ->
                            if Date.compare date s.start == GT then
                                date

                            else
                                s.start

                        Nothing ->
                            s.start

                found =
                    Recurrence.occurrences { start = s.start, from = from, limit = 6 } rule
            in
            Html.div [ Internal.cls [ "klar-recurrence__preview" ], Attr.id (s.id ++ "-preview") ]
                [ Html.p [ Internal.cls [ "klar-recurrence__preview-title" ] ]
                    [ Html.text
                        (if from == s.start then
                            text.firstDates

                         else
                            text.nextDates
                        )
                    ]
                , if List.isEmpty found then
                    Html.p [ Internal.cls [ "klar-recurrence__none" ] ] [ Html.text text.noDates ]

                  else
                    Html.ol [ Internal.cls [ "klar-recurrence__dates" ] ]
                        (List.map (viewDate config.locale) (List.take 5 found)
                            ++ [ Internal.viewIf (List.length found > 5)
                                    (Html.li [ Internal.cls [ "klar-recurrence__more" ] ] [ Html.text text.andMore ])
                               ]
                        )
                ]

        _ ->
            Html.text ""


viewDate : Locale -> Date -> Html msg
viewDate lang date =
    Html.li [ Internal.cls [ "klar-recurrence__date" ] ]
        [ Html.time [ Attr.attribute "datetime" (Date.toIso date) ]
            [ Html.text (Locale.weekdayLong lang (Date.weekday date) ++ " " ++ Format.dateLong lang date) ]
        ]
