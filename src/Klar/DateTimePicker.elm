module Klar.DateTimePicker exposing
    ( view
    , State, init, Msg, update
    , DateTime, dateTime, isInvalid, text, setDateTime, clear, setText, validate
    , Attribute, today, min, max, disabledWhen, markers, weekNumbers
    , minTime, maxTime, step
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , size, locale, disabled, readOnly, clearable
    )

{-| A date and a time in one control: a [Klar.DatePicker](Klar-DatePicker) and a
[Klar.TimePicker](Klar-TimePicker) side by side under one label.

Use when: the date and the time belong together, such as the moment of a pick-up.
Do not use when: you need a date alone (as `Klar.DatePicker`) or a time alone (as `Klar.TimePicker`).
Quick path: `init`, `update`, `view`, `dateTime`

    import Klar.DateTimePicker as DateTimePicker

    -- model
    { pickup : DateTimePicker.State }   -- DateTimePicker.init "pickup"

    -- msg
    PickupMsg DateTimePicker.Msg

    -- update
    PickupMsg m ->
        let
            ( pickup, cmd ) =
                DateTimePicker.update m model.pickup
        in
        ( { model | pickup = pickup }, Cmd.map PickupMsg cmd )

    -- view
    DateTimePicker.view PickupMsg
        [ DateTimePicker.label "Pick-up time"
        , DateTimePicker.today model.today
        , DateTimePicker.min model.today
        , DateTimePicker.step 15
        ]
        model.pickup

    -- read
    DateTimePicker.dateTime model.pickup   -- Maybe { date : Date, time : Time }

Here `model.today` is a [Klar.Date](Klar-Date) value that the application keeps;
the library never reads the clock.

The state holds both parts, and there are no out-messages: compare `dateTime`
before and after `update` to react to a change. `dateTime` is `Just` only when
both parts hold an accepted value. When one part is empty or its text cannot be
read it is `Nothing`, and `isInvalid` tells unreadable from empty.

The two parts behave as described for [Klar.DatePicker](Klar-DatePicker) (typed
dates, the calendar, its keyboard support) and
[Klar.TimePicker](Klar-TimePicker) (typed times, the list, its keyboard support).
Their text inputs have the DOM ids `<id>-date` and `<id>-time`. Each part shows
its own message below its input when its text cannot be read, such as "Invalid
date" or "The time cannot be before 08:00". A text is read when the user leaves
its input, presses `Enter`, or has typed a complete date or time. A form should
also call `validate` when it is submitted, because the user may never have left
the inputs; `text` and `setText` give and set the text of both inputs, for
example to pre-fill them from a stored value.

The label, the hint and the error of your application belong to the pair: the
label sits above both inputs and names the group that holds them, the hint and
the error below, and both describe the group (`aria-describedby`, with the ids
`<id>-hint` and `<id>-error` as in [Klar.Field](Klar-Field)). The error is
announced when it appears, and `required` sets `aria-required` on both inputs.
`size`, `locale`, `disabled`, `readOnly` and `clearable` apply to both parts.
The limits are separate: `min`, `max` and `disabledWhen` restrict the date,
`minTime` and `maxTime` the time of day, on every date. The built-in text comes
from `locale`; the default is English.


# View

@docs view


# State

@docs State, init, Msg, update


# The value

@docs DateTime, dateTime, isInvalid, text, setDateTime, clear, setText, validate


# Date limits and today

@docs Attribute, today, min, max, disabledWhen, markers, weekNumbers


# Time limits and steps

@docs minTime, maxTime, step


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Look and behavior

@docs size, locale, disabled, readOnly, clearable

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Calendar as Calendar
import Klar.Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Size(..))
import Klar.TimePicker as TimePicker exposing (Time)



-- STATE


{-| The state of one date and time control: a date field and a time field. Make
it with `init`, keep it in your model, and read it with `dateTime` and
`isInvalid`.
-}
type State
    = State
        { id : String
        , date : DatePicker.State
        , time : TimePicker.State
        }


{-| A date and a time of day together, as a record. The `date` is a
[Klar.Date](Klar-Date) and the `time` a `Time` from
[Klar.TimePicker](Klar-TimePicker). There is no time zone: both are what the
user sees in the fields.

    { date = october20 -- from Date.fromParts 2026 10 20
    , time = { hour = 14, minute = 30 }
    }

-}
type alias DateTime =
    { date : Date
    , time : Time
    }


{-| An empty control. The `String` must be unique on the page: the date input
gets the DOM id `<id>-date`, the time input `<id>-time`, and the label
`<id>-label`.

    DateTimePicker.init "pickup"

-}
init : String -> State
init id =
    State
        { id = id
        , date = DatePicker.init (id ++ "-date")
        , time = TimePicker.init (id ++ "-time")
        }


{-| The date and the time, when both parts hold an accepted value. `Nothing`
when either part is empty or its text could not be read.
-}
dateTime : State -> Maybe DateTime
dateTime (State s) =
    Maybe.map2 DateTime (DatePicker.date s.date) (TimePicker.time s.time)


{-| `True` when either part could not be read: the date is not a date, lies
outside `min` and `max` or is excluded by `disabledWhen`, or the time is not a
time or lies outside `minTime` and `maxTime`. Each part shows its own message
below its input.

Text is only tried when it looks complete (a full `hh:mm`, or a date of ten
characters such as `2026-10-20`), when the user leaves its input or presses
`Enter`, and when you call `validate`, so call `validate` first when you check
this on submit.

-}
isInvalid : State -> Bool
isInvalid (State s) =
    DatePicker.isInvalid s.date || TimePicker.isInvalid s.time


{-| The text in the two inputs that has not been replaced by a formatted value
yet: text the user is still typing, or text that could not be read. Each part is
empty when its input shows an accepted value or nothing. Together with
`dateTime` it tells empty inputs from garbage: `dateTime == Nothing` and a
`text` that is not empty means there is text that is not (yet) a date or a time.
Use `isInvalid` to ask whether the text was tried and rejected; see also
[DatePicker.text](Klar-DatePicker#text) and
[TimePicker.text](Klar-TimePicker#text).
-}
text : State -> { date : String, time : String }
text (State s) =
    { date = DatePicker.text s.date
    , time = TimePicker.text s.time
    }


{-| Sets both parts, or empties both with `Nothing`. The fields show the date
and the time formatted for the locale; text that was being typed is dropped. The
values are not checked against the limits.

    DateTimePicker.setDateTime (Just shipment.pickup) model.pickup

-}
setDateTime : Maybe DateTime -> State -> State
setDateTime maybeValue (State s) =
    State
        { s
            | date = DatePicker.setDate (Maybe.map .date maybeValue) s.date
            , time = TimePicker.setTime (Maybe.map .time maybeValue) s.time
        }


{-| Empties both parts. The same as `setDateTime Nothing`.
-}
clear : State -> State
clear =
    setDateTime Nothing


{-| Fills the two inputs with text as if the user had typed it, for example to
pre-fill them from text that you stored. The texts are read when the user leaves
an input or presses `Enter`, or when you call `validate`; until then `dateTime`
keeps its old value.

    DateTimePicker.setText { date = "2026-10-20", time = "14:30" } model.pickup

-}
setText : { date : String, time : String } -> State -> State
setText texts (State s) =
    State
        { s
            | date = DatePicker.setText texts.date s.date
            , time = TimePicker.setText texts.time s.time
        }


{-| Reads the pending text of both inputs now, as if the user had left them:
readable text becomes the date or the time and is shown formatted, text that
cannot be read sets the problem that `isInvalid` reports. Pass the same
attributes as to `view`, because `today`, the limits and the locale decide what
is valid.

Use it when a form is submitted: the user may never have left the inputs.

    DateTimePicker.validate attributes model.pickup

-}
validate : List Attribute -> State -> State
validate attributes (State s) =
    let
        config =
            configure attributes
    in
    State
        { s
            | date = DatePicker.validate (dateAttributesOf config) s.date
            , time = TimePicker.validate (timeAttributesOf config) s.time
        }



-- UPDATE


{-| The messages of a date and time control. Wrap them in one constructor of
your own `Msg`, give that constructor to `view`, and pass what comes back to
`update`.
-}
type Msg
    = DateMsg DatePicker.Msg
    | TimeMsg TimePicker.Msg


{-| Handles a message of the control: everything the date field and the time
field do. Returns the new state and the command that moves the browser focus.
Map the command with the constructor of your own `Msg`.

    PickupMsg m ->
        let
            ( pickup, cmd ) =
                DateTimePicker.update m model.pickup
        in
        ( { model | pickup = pickup }, Cmd.map PickupMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        DateMsg inner ->
            let
                ( date, cmd ) =
                    DatePicker.update inner s.date
            in
            ( State { s | date = date }, Cmd.map DateMsg cmd )

        TimeMsg inner ->
            let
                ( time, cmd ) =
                    TimePicker.update inner s.time
            in
            ( State { s | time = time }, Cmd.map TimeMsg cmd )



-- ATTRIBUTES


{-| A setting of a date and time control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , disabled : Bool
    , readOnly : Bool
    , clearable : Bool
    , size : Size
    , locale : Locale
    , today : Maybe Date
    , min : Maybe Date
    , max : Maybe Date
    , disabledWhen : Date -> Bool
    , markers : List Calendar.Marker
    , weekNumbers : Bool
    , step : Int
    , minTime : Maybe Time
    , maxTime : Maybe Time
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , disabled = False
        , readOnly = False
        , clearable = False
        , size = Medium
        , locale = Locale.default
        , today = Nothing
        , min = Nothing
        , max = Nothing
        , disabledWhen = \_ -> False
        , markers = []
        , weekNumbers = False
        , step = 15
        , minTime = Nothing
        , maxTime = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label above the two fields. It names the group that holds them; the two
inputs are named "Date" and "Time" for screen readers. Give the control a label,
or hide it with `labelHidden`.
-}
label : String -> Attribute
label value =
    updateField (Field.setLabel value)


{-| Keeps the label for screen readers but does not show it, for a control in a
toolbar or a table row. Needs `label`.
-}
labelHidden : Attribute
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text below the two fields. It describes the group that holds
them (`aria-describedby`), so screen readers read it when the focus enters.
-}
hint : String -> Attribute
hint value =
    updateField (Field.setHint value)


{-| An error message from your application, shown below the two fields and
announced to screen readers (`role="alert"`): a required date and time that is
missing, or one that conflicts with another field. It also describes the group
that holds the fields, and it does not replace the messages of the parts about
unreadable text, which appear below their own inputs.

    DateTimePicker.error "Choose a pick-up time"

-}
error : String -> Attribute
error value =
    updateField (Field.setError (Just value))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateTimePicker.errorMaybe model.pickupError

-}
errorMaybe : Maybe String -> Attribute
errorMaybe value =
    updateField (Field.setError value)


{-| Marks the control as required: an asterisk after the label, and
`aria-required` on both inputs. The control does not enforce it; when the date or
the time is missing, test `dateTime` for `Nothing` yourself and pass an `error`.
-}
required : Attribute
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a control that is not `required`, such as
"(optional)". Default: none.
-}
optionalText : String -> Attribute
optionalText value =
    updateField (Field.setOptionalText value)


{-| Disables both fields and their buttons: they cannot be focused or changed
and the popups cannot be opened. Takes a `Bool` so that it can come straight
from your model, for example while a form is saving. Default: `False`.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The date and the time can be seen, selected and copied but not changed, and
the popups do not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.
-}
readOnly : Bool -> Attribute
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| Shows a small × button in each field while it has text; a button empties its
own field and puts the focus back in it. The buttons are not in the tab order,
and their accessible name is "Clear field". Default: no buttons.
-}
clearable : Attribute
clearable =
    Attribute (\config -> { config | clearable = True })


{-| The size of both fields, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text of both fields (placeholders, button
labels, error messages, names of months and weekdays) and the format in which
the date is shown: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, powers the "Today" button, and completes the short
forms `20.10`, `t`, `+3` and `-7` in the date field.

Without it there is no "Today" button, the short forms are not understood, and an
empty date field opens its calendar on January 2000 (or on the nearest month
inside `min` and `max`).

-}
today : Date -> Attribute
today value =
    Attribute (\config -> { config | today = Just value })


{-| The earliest date that can be chosen or typed: a typed date before it shows
"The date cannot be before" followed by the limit, and the calendar disables the
earlier days. The time of day has its own limit, `minTime`. Default: no limit.
-}
min : Date -> Attribute
min value =
    Attribute (\config -> { config | min = Just value })


{-| The latest date that can be chosen or typed: a typed date after it shows
"The date cannot be after" followed by the limit, and the calendar disables the
later days. The time of day has its own limit, `maxTime`. Default: no limit.
-}
max : Date -> Attribute
max value =
    Attribute (\config -> { config | max = Just value })


{-| Dates that cannot be used, such as weekends or public holidays. The
calendar shows them disabled, and a typed one shows "The date is not available".
Default: every date is allowed.

    DateTimePicker.disabledWhen (\day -> Date.weekday day >= 6)

-}
disabledWhen : (Date -> Bool) -> Attribute
disabledWhen predicate =
    Attribute (\config -> { config | disabledWhen = predicate })


{-| Marks on days in the calendar, such as deliveries or deadlines. Make them
with `Calendar.dot` and `Calendar.count` from [Klar.Calendar](Klar-Calendar).
Default: none.
-}
markers : List Calendar.Marker -> Attribute
markers value =
    Attribute (\config -> { config | markers = value })


{-| Shows ISO 8601 week numbers in the calendar. Default: off.
-}
weekNumbers : Attribute
weekNumbers =
    Attribute (\config -> { config | weekNumbers = True })


{-| Minutes between the times in the list, from 1 to 60 (other numbers are cut to
that range). A divisor of 60 (5, 10, 15, 20, 30 or 60) lines the list up with
the hour, and typed times between the steps are accepted whatever the step is.
The default is 15; see [TimePicker.step](Klar-TimePicker#step).
-}
step : Int -> Attribute
step value =
    Attribute (\config -> { config | step = value })


{-| The earliest time of day that can be chosen or typed, on every date. Default:
00:00.

    DateTimePicker.minTime { hour = 8, minute = 0 }

-}
minTime : Time -> Attribute
minTime value =
    Attribute (\config -> { config | minTime = Just value })


{-| The latest time of day that can be chosen or typed, on every date. Default:
23:59.

    DateTimePicker.maxTime { hour = 16, minute = 0 }

-}
maxTime : Time -> Attribute
maxTime value =
    Attribute (\config -> { config | maxTime = Just value })



-- VIEW


{-| The control: a date field and a time field side by side under one label. The
first argument wraps the picker's messages in one of yours.

    DateTimePicker.view PickupMsg
        [ DateTimePicker.label "Pick-up time"
        , DateTimePicker.today model.today
        ]
        model.pickup

-}
view : (Msg -> msg) -> List Attribute -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        -- The label belongs to the pair, not to one input: the pair is a labelled
        -- group (the label is a plain text, not a `<label for>` that would point
        -- at nothing), and the two inputs keep their own (hidden) labels. The hint
        -- and the error belong to the pair too: `Field.viewGroup` draws them, and
        -- the group is described by them (below). The inputs are `aria-required`
        -- through their own `required` (see `dateAttributesOf`).
        field =
            Field.setId s.id config.field

        labelNode =
            case field.label of
                Just labelText ->
                    [ Html.span
                        [ Internal.cls
                            [ "klar-field__label"
                            , if field.labelHidden then
                                "klar-sr-only"

                              else
                                ""
                            ]
                        , Attr.id (Field.labelId field)
                        ]
                        [ Html.text labelText
                        , Internal.viewIf field.required
                            (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
                        , case ( field.required, field.optionalText ) of
                            ( False, Just optional ) ->
                                Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

                            _ ->
                                Html.text ""
                        ]
                    ]

                Nothing ->
                    []
    in
    Field.viewGroup field
        (Html.div [ Internal.cls [ "klar-datetimepicker-field" ] ]
            (labelNode
                ++ [ Html.div
                        ([ Internal.cls [ "klar-datetimepicker" ]
                         , Attr.attribute "role" "group"
                         ]
                            ++ (case field.label of
                                    Just _ ->
                                        [ Attr.attribute "aria-labelledby" (Field.labelId field) ]

                                    Nothing ->
                                        []
                               )
                            ++ Field.describedByAttributes field
                        )
                        [ Html.div [ Internal.cls [ "klar-datetimepicker__date" ] ]
                            [ DatePicker.view (\inner -> toMsg (DateMsg inner)) (dateAttributesOf config) s.date ]
                        , Html.div [ Internal.cls [ "klar-datetimepicker__time" ] ]
                            [ TimePicker.view (\inner -> toMsg (TimeMsg inner)) (timeAttributesOf config) s.time ]
                        ]
                   ]
            )
        )


{-| The built-in names of the two inputs, for screen readers (their labels are
hidden).
-}
partNames : Locale -> { date : String, time : String }
partNames lang =
    Locale.pick lang
        { nb = { date = "Dato", time = "Klokkeslett" }
        , en = { date = "Date", time = "Time" }
        }


{-| What the date field gets from the attributes of the control. `view` draws it
with these, and `validate` reads the text by the same rules. The field is
`required` when the control is, which puts `aria-required` on the input (the
asterisk is in the hidden label, which nobody sees).
-}
dateAttributesOf : Config -> List DatePicker.Attribute
dateAttributesOf config =
    List.filterMap identity
        [ Just (DatePicker.label (partNames config.locale).date)
        , Just DatePicker.labelHidden
        , Just (DatePicker.locale config.locale)
        , Just (DatePicker.size config.size)
        , Just (DatePicker.disabled config.disabled)
        , Just (DatePicker.readOnly config.readOnly)
        , Just (DatePicker.disabledWhen config.disabledWhen)
        , Just (DatePicker.markers config.markers)
        , Maybe.map DatePicker.today config.today
        , Maybe.map DatePicker.min config.min
        , Maybe.map DatePicker.max config.max
        , if config.clearable then
            Just DatePicker.clearable

          else
            Nothing
        , if config.weekNumbers then
            Just DatePicker.weekNumbers

          else
            Nothing
        , if config.field.required then
            Just DatePicker.required

          else
            Nothing
        ]


{-| What the time field gets from the attributes of the control, like
`dateAttributesOf`.
-}
timeAttributesOf : Config -> List TimePicker.Attribute
timeAttributesOf config =
    List.filterMap identity
        [ Just (TimePicker.label (partNames config.locale).time)
        , Just TimePicker.labelHidden
        , Just (TimePicker.locale config.locale)
        , Just (TimePicker.size config.size)
        , Just (TimePicker.disabled config.disabled)
        , Just (TimePicker.readOnly config.readOnly)
        , Just (TimePicker.step config.step)
        , Maybe.map TimePicker.min config.minTime
        , Maybe.map TimePicker.max config.maxTime
        , if config.clearable then
            Just TimePicker.clearable

          else
            Nothing
        , if config.field.required then
            Just TimePicker.required

          else
            Nothing
        ]
