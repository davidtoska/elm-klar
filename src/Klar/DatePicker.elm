module Klar.DatePicker exposing
    ( view
    , State, init, Msg, update
    , date, isInvalid, text, setDate, clear, setText, validate
    , isOpen, open, close, visibleMonth
    , Attribute, today, min, max, disabledWhen
    , markers, weekNumbers, alignEnd
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, size, locale, disabled, readOnly, clearable, name
    )

{-| A date field: type the date or pick it in a calendar.

For a period with a from and a to date use
[Klar.DateRangePicker](Klar-DateRangePicker), for a date with a time of day
[Klar.DateTimePicker](Klar-DateTimePicker), and for a calendar that is always
visible [Klar.Calendar](Klar-Calendar).

    import Klar.DatePicker as DatePicker

    -- model
    { dueDate : DatePicker.State }   -- DatePicker.init "due-date"

    -- msg
    DueDateMsg DatePicker.Msg

    -- update
    DueDateMsg m ->
        let
            ( dueDate, cmd ) =
                DatePicker.update m model.dueDate
        in
        ( { model | dueDate = dueDate }, Cmd.map DueDateMsg cmd )

    -- view
    DatePicker.view DueDateMsg
        [ DatePicker.label "Due date"
        , DatePicker.today model.today
        , DatePicker.min model.today
        , DatePicker.clearable
        ]
        model.dueDate

    -- read
    DatePicker.date model.dueDate   -- Maybe Date

Here `model.today` is a [Klar.Date](Klar-Date) value that the application keeps.
The library never reads the clock: get the time with `Time.now` and turn it into
a date with `Date.fromPosix`.

The state holds the chosen date, and there are no out-messages: compare
`DatePicker.date` before and after `update` to react to a change. The date is
accepted when the user leaves the field, presses `Enter`, types a complete
date, or picks a day. Until then `date` keeps the last accepted value. When the
text cannot be read, `date` is `Nothing`, `isInvalid` is `True`, and the field
shows a message such as "Invalid date" or "The date cannot be before
2026-01-01". That message replaces an `error` of your own for as long as it
lasts. A form should call `validate` when it is submitted, because the user may
never have left the field.

Typed dates are read leniently. With the default English locale the field shows
`2026-10-20`, and with the Norwegian locale (`Locale.nb`) `20.10.2026`; both forms are
understood whatever the locale, and so are `20/10/2026` (slash dates are day
first, never month first), `20.10.26` (a two-digit year), `20102026` or
`20261020` (digits only), `20.10` (this year), `t` or `today`, and `+3` or `-7`
(days from today). The Norwegian shortcuts `i dag` and `idag` also mean today,
and work in every locale. A two-digit year counts as 20xx up to ten years after
the current year and as 19xx beyond that, unless only the other century fits
`min` and `max`: in a field with `max` set to today, a year that would lie in the
future counts as 19xx, so `01.01.30` is 1930 in 2026.

The application gives the field `today` (for the marker in the calendar, the
"Today" button and the short forms above) and, when needed, `min`, `max` and
`disabledWhen`.

Keyboard: `ArrowDown` or `Alt+ArrowDown` in the field opens the calendar. So
does `Enter`, unless the user has just typed something that was not taken yet:
then `Enter` takes the text as the date. In the calendar the arrow keys,
`PageUp`, `PageDown`, `Home` and `End` move, `Enter` picks, and `Escape` closes
the calendar and returns to the field (inside the month and year choosers it
goes back one step first). `Tab` out of the calendar closes it. The keys of the
calendar are described in [Klar.Calendar](Klar-Calendar).

The calendar is a `role="dialog"` popup. Where the browser supports CSS anchor
positioning, it is never clipped by a table, card or modal body and opens above
the field when there is no room below. Other browsers draw it just below the
field with plain positioning: a parent that scrolls or hides its overflow can
clip it there, and it does not move above the field. It closes on a press
outside it. `Escape` closes only the calendar, not an enclosing
[Klar.Modal](Klar-Modal). The built-in text (placeholder, button labels, error
messages, month and weekday names) comes from `locale`; the default is English.


# View

@docs view


# State

@docs State, init, Msg, update


# The date

@docs date, isInvalid, text, setDate, clear, setText, validate


# The calendar popup

@docs isOpen, open, close, visibleMonth


# Limits and today

@docs Attribute, today, min, max, disabledWhen


# Calendar

@docs markers, weekNumbers, alignEnd


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Look and behavior

@docs placeholder, size, locale, disabled, readOnly, clearable, name

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Calendar as Calendar
import Klar.Calendar.Parse as Parse exposing (Problem, Rules)
import Klar.Calendar.Popup as Popup
import Klar.Calendar.Util as Util
import Klar.Date as Date exposing (Date)
import Klar.Field as Field
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of one date field: the accepted date, any text that is still
being typed, whether the calendar is open, and the calendar itself. Make it with
`init`, keep it in your model, and read it with `date`, `text` and `isInvalid`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , date : Maybe Date
    , draft : Maybe String
    , problem : Maybe Problem
    , open : Bool
    , calendar : Calendar.State
    }


{-| An empty field. The `String` is the DOM id of the text input and must be
unique on the page; the calendar button and the popup get ids derived from it
(`<id>-button` and `<id>-popup`).

    DatePicker.init "due-date"

-}
init : String -> State
init id =
    State
        { id = id
        , date = Nothing
        , draft = Nothing
        , problem = Nothing
        , open = False
        , calendar = Calendar.init (id ++ "-popup-cal")
        }


{-| The accepted date, or `Nothing` when the field is empty or its text could not
be read. While the user is typing it keeps the previous value until the text is
complete or confirmed (see the module documentation).
-}
date : State -> Maybe Date
date (State s) =
    s.date


{-| The text in the field that has not been replaced by the formatted date yet:
text the user is still typing, or text that could not be read. Together with
`date` it tells an empty field from garbage: `date == Nothing && text /= ""`
means there is text that is not a date (yet). Use `isInvalid` to ask whether the
text was tried and rejected.
-}
text : State -> String
text (State s) =
    Maybe.withDefault "" s.draft


{-| `True` when the last attempt to read the field failed: the text is not a
date, the date is outside `min` and `max`, or the day is excluded by
`disabledWhen`. The field then shows the matching message.

Text is only tried when it looks complete (ten characters, such as `2026-10-20`
or `20.10.2026`), when the user leaves the field or presses `Enter`, and when
you call `validate`, so call `validate` first when you check this on submit.

-}
isInvalid : State -> Bool
isInvalid (State s) =
    s.problem /= Nothing


{-| `True` while the calendar popup is open. A field that is `disabled` or
`readOnly` never draws it.
-}
isOpen : State -> Bool
isOpen (State s) =
    s.open


{-| The first month the calendar shows, as `{ year, month }` (January is 1).
For an application that loads marks (deliveries, public holidays) one month at a
time: compare it before and after `update` and fetch when it changes. Only
meaningful once the calendar has been opened; before that it is a placeholder.
-}
visibleMonth : State -> { year : Int, month : Int }
visibleMonth (State s) =
    Calendar.visibleMonth s.calendar


{-| Sets the date, or empties the field with `Nothing`. The field shows the
date formatted for the locale; text that was being typed is dropped. The date is
not checked against `min`, `max` or `disabledWhen`.

    DatePicker.setDate (Just invoice.dueDate) model.dueDate

-}
setDate : Maybe Date -> State -> State
setDate maybeDate (State s) =
    State
        { s
            | date = maybeDate
            , draft = Nothing
            , problem = Nothing
            , calendar = Calendar.select maybeDate s.calendar
        }


{-| Empties the field. The same as `setDate Nothing`.
-}
clear : State -> State
clear =
    setDate Nothing


{-| Fills the field with text as if the user had typed it. The text is read when
the user leaves the field or presses `Enter`, or when you call `validate`; until
then `date` keeps its old value.

    DatePicker.setText "2026-10-20" model.dueDate

-}
setText : String -> State -> State
setText value (State s) =
    State { s | draft = Just value, problem = Nothing }


{-| Reads the pending text now, as if the user had left the field: readable text
becomes the date and is shown formatted, text that cannot be read sets the
problem that `isInvalid` reports. Pass the same attributes as to `view`, because
`today`, the limits and the locale decide what is valid.

Use it when a form is submitted: the user may never have left the field.

    DatePicker.validate attributes model.dueDate

-}
validate : List Attribute -> State -> State
validate attributes (State s) =
    State (commit (rulesOf (configure attributes)) s)


{-| Opens the calendar and moves the focus into it, after reading any pending
text. It opens on the chosen date, or else on the day given with `today`, kept
inside `min` and `max`. Pass the same attributes as to `view`: the limits come
from them.
-}
open : List Attribute -> State -> ( State, Cmd Msg )
open attributes (State s) =
    openPopup (rulesOf (configure attributes)) s


{-| Closes the calendar and gives the focus back to the field. Does nothing when
the calendar is already closed.
-}
close : State -> ( State, Cmd Msg )
close (State s) =
    closePopup s



-- UPDATE


{-| The messages of a date field. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.
-}
type Msg
    = Typed Rules String
    | Blurred Rules
    | Entered Rules
    | OpenRequested Rules
    | Toggled Rules
    | Closed
    | Left
    | Escaped
    | CalendarMsg Calendar.Msg
    | PickedToday Date
    | Cleared
    | Noop


{-| Handles a message of the field: typing, keys, the calendar button, the
calendar and the clear button. Returns the new state and the command that moves
the browser focus. Map the command with the constructor of your own `Msg`.

    DueDateMsg m ->
        let
            ( dueDate, cmd ) =
                DatePicker.update m model.dueDate
        in
        ( { model | dueDate = dueDate }, Cmd.map DueDateMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        Typed rules typed ->
            let
                draft =
                    { s | draft = Just typed, problem = Nothing }
            in
            ( State
                (if Parse.isComplete typed then
                    accept rules draft

                 else
                    draft
                )
            , Cmd.none
            )

        Blurred rules ->
            ( State (commit rules s), Cmd.none )

        Entered rules ->
            if s.draft /= Nothing && s.problem == Nothing then
                ( State (commit rules s), Cmd.none )

            else
                openPopup rules s

        OpenRequested rules ->
            openPopup rules s

        Toggled rules ->
            if s.open then
                closePopup s

            else
                openPopup rules s

        Closed ->
            closePopup s

        Left ->
            ( State { s | open = False }, Cmd.none )

        Escaped ->
            case Calendar.back s.calendar of
                Just ( calendar, cmd ) ->
                    ( State { s | calendar = calendar }, Cmd.map CalendarMsg cmd )

                Nothing ->
                    closePopup s

        CalendarMsg inner ->
            let
                ( calendar, cmd, event ) =
                    Calendar.updateWithEvent inner s.calendar
            in
            case event of
                Just (Calendar.DayPicked day) ->
                    pick day { s | calendar = calendar }

                _ ->
                    ( State { s | calendar = calendar }, Cmd.map CalendarMsg cmd )

        PickedToday day ->
            pick day s

        Cleared ->
            ( State
                { s
                    | date = Nothing
                    , draft = Nothing
                    , problem = Nothing
                    , calendar = Calendar.select Nothing s.calendar
                }
            , Internal.focus s.id Noop
            )

        Noop ->
            ( State s, Cmd.none )


{-| Reads the typed text and keeps what it says, but leaves the text as typed.
-}
accept : Rules -> Inner -> Inner
accept rules s =
    case s.draft of
        Nothing ->
            s

        Just typed ->
            case Parse.date rules typed of
                Ok maybeDate ->
                    { s | date = maybeDate, problem = Nothing }

                Err problem ->
                    { s | date = Nothing, problem = Just problem }


{-| Like `accept`, and replaces the text with the formatted date.
-}
commit : Rules -> Inner -> Inner
commit rules s =
    let
        accepted =
            accept rules s
    in
    if accepted.problem == Nothing then
        { accepted | draft = Nothing }

    else
        accepted


openPopup : Rules -> Inner -> ( State, Cmd Msg )
openPopup rules s =
    let
        committed =
            commit rules s

        -- The calendar opens on the date, or on today; kept inside the limits.
        target =
            (case committed.date of
                Just day ->
                    day

                Nothing ->
                    Maybe.withDefault (Calendar.focusedDay committed.calendar) rules.today
            )
                |> Util.clampTo rules.min rules.max

        calendar =
            committed.calendar
                |> Calendar.select committed.date
                |> Calendar.showDate target
    in
    ( State { committed | open = True, calendar = calendar }
    , Cmd.map CalendarMsg (Calendar.focus calendar)
    )


closePopup : Inner -> ( State, Cmd Msg )
closePopup s =
    ( State { s | open = False }
    , if s.open then
        Internal.focus s.id Noop

      else
        Cmd.none
    )


pick : Date -> Inner -> ( State, Cmd Msg )
pick day s =
    ( State
        { s
            | date = Just day
            , draft = Nothing
            , problem = Nothing
            , open = False
            , calendar = Calendar.select (Just day) s.calendar
        }
    , Internal.focus s.id Noop
    )



-- ATTRIBUTES


{-| A setting of a date field. Make them with the functions below and pass a
list to `view`, `validate` or `open`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , placeholder : Maybe String
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
    , alignEnd : Bool
    , name : Maybe String
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , placeholder = Nothing
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
        , alignEnd = False
        , name = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label above the field, tied to the text input. Give every field a label,
or hide it with `labelHidden`: it is the name that screen readers announce.
-}
label : String -> Attribute
label value =
    updateField (Field.setLabel value)


{-| Keeps the label for screen readers but does not show it, for a field in a
toolbar or a table row. Needs `label`.
-}
labelHidden : Attribute
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text below the field. It is linked to the input with
`aria-describedby`, so screen readers read it together with the field.
-}
hint : String -> Attribute
hint value =
    updateField (Field.setHint value)


{-| An error message from your application, shown below the field and announced
to screen readers: a required date that is missing, or a date that conflicts
with another field. While the picker has a complaint of its own about the typed
text ("Invalid date"), that message is shown instead.

    DatePicker.error "Choose a due date"

-}
error : String -> Attribute
error value =
    updateField (Field.setError (Just value))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DatePicker.errorMaybe model.dueDateError

-}
errorMaybe : Maybe String -> Attribute
errorMaybe value =
    updateField (Field.setError value)


{-| Marks the field as required: an asterisk after the label, and
`aria-required` on the input. The picker does not enforce it; when the date is
missing, test `date` for `Nothing` yourself and pass an `error`.
-}
required : Attribute
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.
-}
optionalText : String -> Attribute
optionalText value =
    updateField (Field.setOptionalText value)


{-| The text shown in the empty field. Default: the format hint of the locale,
`yyyy-mm-dd` in English.
-}
placeholder : String -> Attribute
placeholder value =
    Attribute (\config -> { config | placeholder = Just value })


{-| Disables the field and its calendar button: the text cannot be focused or
changed and the calendar cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The date can be seen, selected and copied but not changed, and the calendar
does not open. Unlike `disabled`, the field can still be focused. Default:
`False`.
-}
readOnly : Bool -> Attribute
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| Shows a small × button in the field while it has text; it empties the field
and puts the focus back in it. The button is not in the tab order, and its
accessible name is "Clear field". Default: no button.
-}
clearable : Attribute
clearable =
    Attribute (\config -> { config | clearable = True })


{-| The size of the field, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text (placeholder, button labels, error
messages, names of months and weekdays) and the format in which the field shows
a date: `2026-10-20` in English, `20.10.2026` in Norwegian. It also decides which
order is tried first for digits-only input such as `20102026`. The default is
`Locale.default`, which is English; see [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, powers the "Today" button (which picks today and
closes the calendar), completes the short forms `20.10`, `t`, `+3` and `-7`, and
decides how a two-digit year is read.

Without it there is no "Today" button, the short forms are not understood, and an
empty field opens its calendar on January 2000 (or on the nearest month inside
`min` and `max`).

-}
today : Date -> Attribute
today value =
    Attribute (\config -> { config | today = Just value })


{-| The earliest date that can be chosen or typed. A typed date before it shows
"The date cannot be before" followed by the limit, and the calendar disables the
earlier days. Default: no limit.
-}
min : Date -> Attribute
min value =
    Attribute (\config -> { config | min = Just value })


{-| The latest date that can be chosen or typed. A typed date after it shows
"The date cannot be after" followed by the limit, and the calendar disables the
later days. Default: no limit.
-}
max : Date -> Attribute
max value =
    Attribute (\config -> { config | max = Just value })


{-| Dates that cannot be used, such as weekends or public holidays. The
calendar shows them disabled, and a typed one shows "The date is not available".
Default: every date is allowed.

    DatePicker.disabledWhen (\day -> Date.weekday day >= 6)

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


{-| Aligns the right edge of the calendar popup with the right edge of the
field, instead of the left edges. Use it for a field near the right side of the
page, so that the popup does not run out of the window.
-}
alignEnd : Attribute
alignEnd =
    Attribute (\config -> { config | alignEnd = True })


{-| The `name` attribute of the text input, for a plain HTML `form`. The value
that is sent is the text in the field, formatted for the locale. Default: none.
-}
name : String -> Attribute
name value =
    Attribute (\config -> { config | name = Just value })


rulesOf : Config -> Rules
rulesOf config =
    { locale = config.locale
    , today = config.today
    , min = config.min
    , max = config.max
    , isDisabled = config.disabledWhen
    }


calendarAttributes : Config -> List Calendar.Attribute
calendarAttributes config =
    List.filterMap identity
        [ Maybe.map Calendar.today config.today
        , Maybe.map Calendar.min config.min
        , Maybe.map Calendar.max config.max
        , Just (Calendar.disabledWhen config.disabledWhen)
        , Just (Calendar.locale config.locale)
        , Just (Calendar.markers config.markers)
        , if config.weekNumbers then
            Just Calendar.weekNumbers

          else
            Nothing
        ]



-- VIEW


type alias Strings =
    { placeholder : String
    , openCalendar : String
    , dialog : String
    , today : String
    , clear : String
    }


strings : Locale -> Strings
strings lang =
    Locale.pick lang
        { nb =
            { placeholder = "dd.mm.åååå"
            , openCalendar = "Åpne kalender"
            , dialog = "Velg dato"
            , today = "I dag"
            , clear = "Tøm feltet"
            }
        , en =
            { placeholder = "yyyy-mm-dd"
            , openCalendar = "Open calendar"
            , dialog = "Choose date"
            , today = "Today"
            , clear = "Clear field"
            }
        }


{-| The field: a text input with a calendar button, and the calendar popup while
it is open. The first argument wraps the picker's messages in one of yours.

    DatePicker.view DueDateMsg
        [ DatePicker.label "Due date", DatePicker.today model.today ]
        model.dueDate

-}
view : (Msg -> msg) -> List Attribute -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        rules =
            rulesOf config

        words =
            strings config.locale

        shown =
            case s.draft of
                Just typed ->
                    typed

                Nothing ->
                    s.date |> Maybe.map (Format.date config.locale) |> Maybe.withDefault ""

        field =
            config.field
                |> Field.setId s.id
                |> (case s.problem of
                        Just problem ->
                            Field.setError (Just (Parse.message config.locale problem))

                        Nothing ->
                            identity
                   )

        inactive =
            config.disabled || config.readOnly

        showClear =
            config.clearable && shown /= "" && not inactive
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div [ Internal.cls [ "klar-anchor", "klar-anchor--block", "klar-datepicker" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Theme.sizeSuffix config.size
                    , "klar-datepicker__box"
                    , if field.error /= Nothing then
                        "klar-input--invalid"

                      else
                        ""
                    , if config.disabled then
                        "klar-input--disabled"

                      else
                        ""
                    , if config.readOnly then
                        "klar-input--readonly"

                      else
                        ""
                    ]
                ]
                [ Html.input
                    (Field.controlAttributes field
                        ++ [ Internal.cls [ "klar-input__control" ]
                           , Attr.type_ "text"
                           , Attr.value shown
                           , Attr.placeholder (Maybe.withDefault words.placeholder config.placeholder)
                           , Attr.disabled config.disabled
                           , Attr.readonly config.readOnly
                           , Attr.attribute "autocomplete" "off"
                           , Attr.attribute "aria-haspopup" "dialog"
                           , Attr.attribute "aria-keyshortcuts" "Alt+ArrowDown"
                           , Internal.attrMaybe Attr.name config.name
                           , Events.onInput (\typed -> toMsg (Typed rules typed))
                           , Events.onBlur (toMsg (Blurred rules))
                           , if inactive then
                                Internal.noAttr

                             else
                                Internal.onKeys
                                    [ ( "ArrowDown", toMsg (OpenRequested rules) )
                                    , ( "Alt+ArrowDown", toMsg (OpenRequested rules) )
                                    , ( "Enter", toMsg (Entered rules) )
                                    ]
                           ]
                    )
                    []
                , if showClear then
                    Html.button
                        [ Internal.cls [ "klar-input__clear" ]
                        , Attr.type_ "button"
                        , Attr.tabindex -1
                        , Attr.attribute "aria-label" words.clear
                        , Events.onClick (toMsg Cleared)
                        ]
                        [ Icon.view Icon.close ]

                  else
                    Html.text ""
                , Html.button
                    [ Internal.cls [ "klar-datepicker__button" ]
                    , Attr.type_ "button"
                    , Attr.id (s.id ++ "-button")
                    , Attr.tabindex -1
                    , Attr.attribute "aria-label" words.openCalendar
                    , Attr.attribute "aria-haspopup" "dialog"
                    , Attr.attribute "aria-expanded" (boolString s.open)
                    , Internal.attrIf s.open (Attr.attribute "aria-controls" (s.id ++ "-popup"))
                    , Attr.disabled inactive
                    , Events.onClick (toMsg (Toggled rules))
                    ]
                    [ Icon.view Icon.calendar ]
                ]
            , if s.open && not inactive then
                viewPopup toMsg config rules words s

              else
                Html.text ""
            ]
        )


viewPopup : (Msg -> msg) -> Config -> Rules -> Strings -> Inner -> Html msg
viewPopup toMsg config rules words s =
    let
        todayBlocked =
            case config.today of
                Just day ->
                    Parse.check rules day |> Result.toMaybe |> (==) Nothing

                Nothing ->
                    True
    in
    Popup.dialog
        { prefix = s.id ++ "-popup"
        , label = words.dialog
        , classes = [ "klar-datepicker__popup" ]
        , alignEnd = config.alignEnd
        , onClose = toMsg Closed
        , onEscape = toMsg Escaped
        , onLeave = toMsg Left
        , noop = toMsg Noop
        }
        [ Calendar.view (\inner -> toMsg (CalendarMsg inner)) (calendarAttributes config) s.calendar
        , case config.today of
            Just day ->
                Html.div [ Internal.cls [ "klar-datepicker__footer" ] ]
                    [ Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.id (s.id ++ "-popup-today")
                        , Button.disabled todayBlocked
                        , Button.onClick (toMsg (PickedToday day))
                        ]
                        words.today
                    ]

            Nothing ->
                Html.text ""
        ]


boolString : Bool -> String
boolString value =
    if value then
        "true"

    else
        "false"
