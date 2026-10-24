module Klar.TimePicker exposing
    ( view
    , State, init, Msg, update
    , Time, toString, toMinutes, fromMinutes
    , time, isInvalid, text, setTime, clear, setText, validate
    , isOpen, open, close
    , Attribute, min, max, step
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, size, locale, disabled, readOnly, clearable, alignEnd, name
    )

{-| A 24-hour time field: type `14:30` or pick a time from a list.

Use when: the user enters a time of day only, such as an order cut-off.
Do not use when: the user enters a date and a time together (as `Klar.DateTimePicker`).
Quick path: `init`, `update`, `view`, `time`

It holds a time of day only. For a date and a time together see
[Klar.DateTimePicker](Klar-DateTimePicker).

    import Klar.TimePicker as TimePicker

    -- model
    { cutoff : TimePicker.State }   -- TimePicker.init "cutoff"

    -- msg
    CutoffMsg TimePicker.Msg

    -- update
    CutoffMsg m ->
        let
            ( cutoff, cmd ) =
                TimePicker.update m model.cutoff
        in
        ( { model | cutoff = cutoff }, Cmd.map CutoffMsg cmd )

    -- view
    TimePicker.view CutoffMsg
        [ TimePicker.label "Order cut-off"
        , TimePicker.step 15
        , TimePicker.min { hour = 8, minute = 0 }
        , TimePicker.max { hour = 16, minute = 0 }
        ]
        model.cutoff

    -- read
    TimePicker.time model.cutoff   -- Maybe { hour : Int, minute : Int }

The state holds the chosen time, and there are no out-messages: compare
`TimePicker.time` before and after `update` to react to a change. The time is
accepted when the user leaves the field, presses `Enter`, types a full `hh:mm`,
or picks a time from the list. Until then `time` keeps the last accepted value.
When the text cannot be read, `time` is `Nothing`, `isInvalid` is `True`, and
the field shows a message such as "Invalid time" or "The time cannot be before
08:00". A form should call `validate` when it is submitted, because the user may
never have left the field.

The list offers a time every `step` minutes (15 by default) between `min` and
`max`. The field itself also accepts times between the steps, such as 09:37, as
long as they are inside `min` and `max`. Typed text is read like `14:30`,
`14.30`, `1430`, `930` and `14`; the Norwegian prefix `kl`, as in `kl 14:30`, is
ignored in every locale. There is no AM or PM: hours run from 0 to 23.

The list opens when the field is clicked, with `ArrowDown`, `ArrowUp` or
`Alt+ArrowDown`, or from the clock button. The keyboard focus stays in the
field, which is a combobox with a listbox popup: `ArrowUp` and `ArrowDown` move
through the list, `PageUp` and `PageDown` move by eight, `Enter` chooses, and
`Escape` or `Alt+ArrowUp` closes it. When the field holds a time that is not in
the list, nothing is highlighted as the list opens, so `Enter` never changes it
by itself. Typing while the list is open scrolls it to the nearest time.

The list closes on a press outside it, and `Escape` closes only the list, not an
enclosing [Klar.Modal](Klar-Modal). It is placed like the calendar of
[Klar.DatePicker](Klar-DatePicker): CSS anchor positioning keeps it from being
clipped by a scrolling parent, and without it such a parent can clip it. The
built-in text (placeholder, button label and error messages) comes from
`locale`; the default is English. To work with the chosen time, `toString`,
`toMinutes` and `fromMinutes` convert between a `Time` and text or minutes.


# View

@docs view


# State

@docs State, init, Msg, update


# Times

@docs Time, toString, toMinutes, fromMinutes


# The chosen time

@docs time, isInvalid, text, setTime, clear, setText, validate


# The list popup

@docs isOpen, open, close


# Limits and steps

@docs Attribute, min, max, step


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Look and behavior

@docs placeholder, size, locale, disabled, readOnly, clearable, alignEnd, name

-}

import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Calendar.Parse as Parse exposing (TimeProblem)
import Klar.Calendar.Popup as Popup
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))
import Task



-- TIME


{-| A time of day in 24-hour time, as a record with two fields: `hour` (0 to 23)
and `minute` (0 to 59). Write the record yourself or make one with
`fromMinutes`.

    { hour = 14, minute = 30 }

-}
type alias Time =
    { hour : Int
    , minute : Int
    }


{-| A time as `hh:mm`, with two digits for each part.

    TimePicker.toString { hour = 8, minute = 5 } -- "08:05"

-}
toString : Time -> String
toString =
    Parse.formatTime


{-| Minutes since midnight, to compare or calculate with times.

    TimePicker.toMinutes { hour = 14, minute = 30 } -- 870

-}
toMinutes : Time -> Int
toMinutes =
    Parse.toMinutes


{-| A time from minutes since midnight. It wraps around midnight, in both
directions.

    TimePicker.fromMinutes 870 -- { hour = 14, minute = 30 }

    TimePicker.fromMinutes 1500 -- { hour = 1, minute = 0 }

    TimePicker.fromMinutes -60 -- { hour = 23, minute = 0 }

-}
fromMinutes : Int -> Time
fromMinutes =
    Parse.fromMinutes



-- STATE


{-| The state of one time field: the accepted time, any text that is still being
typed, whether the list is open, and the highlighted entry. Make it with `init`,
keep it in your model, and read it with `time`, `text` and `isInvalid`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , time : Maybe Time
    , draft : Maybe String
    , problem : Maybe TimeProblem
    , open : Bool
    , highlight : Maybe Int
    }


{-| An empty field. The `String` is the DOM id of the text input and must be
unique on the page; the clock button and the list get ids derived from it
(`<id>-button`, `<id>-popup` and `<id>-popup-list`).

    TimePicker.init "cutoff"

-}
init : String -> State
init id =
    State
        { id = id
        , time = Nothing
        , draft = Nothing
        , problem = Nothing
        , open = False
        , highlight = Nothing
        }


{-| The accepted time, or `Nothing` when the field is empty or its text could not
be read. While the user is typing it keeps the previous value until the text is
a full `hh:mm` or confirmed (see the module documentation).
-}
time : State -> Maybe Time
time (State s) =
    s.time


{-| The text in the field that has not been replaced by the formatted time yet:
text the user is still typing, or text that could not be read. Together with
`time` it tells an empty field from garbage: `time == Nothing && text /= ""`
means there is text that is not a time (yet). Use `isInvalid` to ask whether the
text was tried and rejected; see also [DatePicker.text](Klar-DatePicker#text).
-}
text : State -> String
text (State s) =
    Maybe.withDefault "" s.draft


{-| `True` when the last attempt to read the field failed: the text is not a
time, or the time is outside `min` and `max`. The field then shows the matching
message.

Text is only tried when the user has typed a full `hh:mm`, leaves the field or
presses `Enter`, and when you call `validate`, so call `validate` first when you
check this on submit.

-}
isInvalid : State -> Bool
isInvalid (State s) =
    s.problem /= Nothing


{-| `True` while the list of times is open. A field that is `disabled` or
`readOnly` never draws it.
-}
isOpen : State -> Bool
isOpen (State s) =
    s.open


{-| Sets the time, or empties the field with `Nothing`. The field shows the time
as `hh:mm`; text that was being typed is dropped. The time is not checked
against `min` and `max`.

    TimePicker.setTime (Just { hour = 16, minute = 0 }) model.cutoff

-}
setTime : Maybe Time -> State -> State
setTime maybeTime (State s) =
    State { s | time = maybeTime, draft = Nothing, problem = Nothing }


{-| Empties the field. The same as `setTime Nothing`.
-}
clear : State -> State
clear =
    setTime Nothing


{-| Fills the field with text as if the user had typed it. The text is read when
the user leaves the field or presses `Enter`, or when you call `validate`; until
then `time` keeps its old value.

    TimePicker.setText "14:30" model.cutoff

-}
setText : String -> State -> State
setText value (State s) =
    State { s | draft = Just value, problem = Nothing }


{-| Reads the pending text now, as if the user had left the field: readable text
becomes the time and is shown as `hh:mm`, text that cannot be read sets the
problem that `isInvalid` reports. Pass the same attributes as to `view`, because
`min` and `max` decide what is valid.

Use it when a form is submitted: the user may never have left the field.

    TimePicker.validate attributes model.cutoff

-}
validate : List Attribute -> State -> State
validate attributes (State s) =
    State (commit (rulesOf (configure attributes)) s)


{-| Opens the list and moves the focus to the text input, where it stays.
Pending text is read first, and the list scrolls to the time closest to the
chosen one (or to 08:00). The limits and the step come from the attributes, so
pass the same list as to `view`.
-}
open : List Attribute -> State -> ( State, Cmd Msg )
open attributes (State s) =
    openPopup (rulesOf (configure attributes)) s


{-| Closes the list and gives the focus back to the field. Does nothing when the
list is already closed.
-}
close : State -> ( State, Cmd Msg )
close (State s) =
    closePopup s



-- UPDATE


{-| What the view knows about the limits when it sends a message.
-}
type alias Rules =
    { min : Maybe Time
    , max : Maybe Time
    , step : Int
    }


{-| The messages of a time field. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.
-}
type Msg
    = Typed Rules String
    | Blurred Rules
    | Clicked Rules
    | Entered Rules
    | Moved Rules Int
    | OpenRequested Rules
    | Toggled Rules
    | Hovered Int
    | Picked Int
    | Closed
    | Refocused
    | Cleared
    | Noop


rowHeight : Float
rowHeight =
    32


{-| The list opens around 08:00 when nothing is chosen.
-}
defaultMinutes : Int
defaultMinutes =
    480


{-| Handles a message of the field: typing, keys, the clock button, the list and
the clear button. Returns the new state and the command that moves the browser
focus or scrolls the list. Map the command with the constructor of your own
`Msg`.

    CutoffMsg m ->
        let
            ( cutoff, cmd ) =
                TimePicker.update m model.cutoff
        in
        ( { model | cutoff = cutoff }, Cmd.map CutoffMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        Typed rules typed ->
            let
                draft =
                    { s | draft = Just typed, problem = Nothing, highlight = Nothing }

                accepted =
                    if looksComplete typed then
                        accept rules draft

                    else
                        draft
            in
            ( State accepted
            , if s.open then
                case Parse.time { min = Nothing, max = Nothing } typed of
                    Ok (Just parsed) ->
                        case nearest (optionsOf rules) (Parse.toMinutes parsed) of
                            Just ( index, _ ) ->
                                centerOn (listId s.id) index

                            Nothing ->
                                Cmd.none

                    _ ->
                        Cmd.none

              else
                Cmd.none
            )

        Blurred rules ->
            ( State { s | open = False, highlight = Nothing } |> mapInner (commit rules), Cmd.none )

        Clicked rules ->
            if s.open then
                ( State s, Cmd.none )

            else
                openPopup rules s

        Entered rules ->
            if s.open then
                case s.highlight of
                    Just minutes ->
                        pick minutes s

                    Nothing ->
                        ( State { s | open = False } |> mapInner (commit rules), Cmd.none )

            else if s.draft /= Nothing && s.problem == Nothing then
                ( State (commit rules s), Cmd.none )

            else
                openPopup rules s

        Moved rules delta ->
            if s.open then
                move rules delta s

            else
                openPopup rules s

        OpenRequested rules ->
            if s.open then
                ( State s, Cmd.none )

            else
                openPopup rules s

        Toggled rules ->
            if s.open then
                closePopup s

            else
                openPopup rules s

        Hovered minutes ->
            ( State { s | highlight = Just minutes }, Cmd.none )

        Picked minutes ->
            pick minutes s

        Closed ->
            closePopup s

        Refocused ->
            -- Focus went into the list (a click on its scrollbar): give it back to the field.
            ( State s, Internal.focus s.id Noop )

        Cleared ->
            ( State { s | time = Nothing, draft = Nothing, problem = Nothing, highlight = Nothing }
            , Internal.focus s.id Noop
            )

        Noop ->
            ( State s, Cmd.none )


mapInner : (Inner -> Inner) -> State -> State
mapInner change (State s) =
    State (change s)


{-| Typed text has a full `hh:mm`.
-}
looksComplete : String -> Bool
looksComplete typed =
    let
        trimmed =
            String.trim typed
    in
    String.length trimmed == 5 && String.slice 2 3 trimmed == ":"


accept : Rules -> Inner -> Inner
accept rules s =
    case s.draft of
        Nothing ->
            s

        Just typed ->
            case Parse.time { min = rules.min, max = rules.max } typed of
                Ok maybeTime ->
                    { s | time = maybeTime, problem = Nothing }

                Err problem ->
                    { s | time = Nothing, problem = Just problem }


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


{-| The times offered in the list.
-}
optionsOf : Rules -> List Int
optionsOf rules =
    let
        stepSize =
            Basics.max 1 rules.step

        lower =
            rules.min |> Maybe.map Parse.toMinutes |> Maybe.withDefault 0

        upper =
            rules.max |> Maybe.map Parse.toMinutes |> Maybe.withDefault 1439

        first =
            (lower + stepSize - 1) // stepSize * stepSize
    in
    if first > upper then
        []

    else
        List.range 0 ((upper - first) // stepSize)
            |> List.map (\index -> first + index * stepSize)


{-| The option closest to a time, with its index. A tie goes to the later one.
-}
nearest : List Int -> Int -> Maybe ( Int, Int )
nearest options minutes =
    options
        |> List.indexedMap Tuple.pair
        |> List.foldl
            (\( index, option ) best ->
                case best of
                    Nothing ->
                        Just ( index, option )

                    Just ( _, bestOption ) ->
                        if abs (option - minutes) <= abs (bestOption - minutes) then
                            Just ( index, option )

                        else
                            best
            )
            Nothing


listId : String -> String
listId id =
    id ++ "-popup-list"


optionId : String -> Int -> String
optionId id minutes =
    id ++ "-popup-opt-" ++ String.fromInt minutes


centerOn : String -> Int -> Cmd Msg
centerOn id index =
    Dom.getViewportOf id
        |> Task.andThen
            (\viewport ->
                Dom.setViewportOf id 0 (toFloat index * rowHeight - (viewport.viewport.height - rowHeight) / 2)
            )
        |> Task.attempt (\_ -> Noop)


openPopup : Rules -> Inner -> ( State, Cmd Msg )
openPopup rules s =
    let
        committed =
            commit rules s

        options =
            optionsOf rules

        target =
            committed.time
                |> Maybe.map Parse.toMinutes
                |> Maybe.withDefault defaultMinutes

        best =
            nearest options target

        -- Only a time that is in the list is highlighted, so Enter never
        -- changes 09:37 into 09:35 by itself.
        highlight =
            case committed.time of
                Just chosen ->
                    if List.member (Parse.toMinutes chosen) options then
                        Just (Parse.toMinutes chosen)

                    else
                        Nothing

                Nothing ->
                    Nothing
    in
    ( State { committed | open = True, highlight = highlight }
    , Cmd.batch
        [ Internal.focus s.id Noop
        , case best of
            Just ( index, _ ) ->
                centerOn (listId s.id) index

            Nothing ->
                Cmd.none
        ]
    )


closePopup : Inner -> ( State, Cmd Msg )
closePopup s =
    ( State { s | open = False, highlight = Nothing }
    , if s.open then
        Internal.focus s.id Noop

      else
        Cmd.none
    )


pick : Int -> Inner -> ( State, Cmd Msg )
pick minutes s =
    ( State
        { s
            | time = Just (Parse.fromMinutes minutes)
            , draft = Nothing
            , problem = Nothing
            , open = False
            , highlight = Nothing
        }
    , Internal.focus s.id Noop
    )


{-| Moves the highlight through the list.
-}
move : Rules -> Int -> Inner -> ( State, Cmd Msg )
move rules delta s =
    let
        options =
            optionsOf rules

        count =
            List.length options

        currentIndex =
            s.highlight
                |> Maybe.andThen (\minutes -> nearest options minutes)
                |> Maybe.map Tuple.first

        -- Where the highlight starts: the typed time, the chosen time, or 08:00.
        startMinutes =
            case s.draft of
                Just typed ->
                    case Parse.time { min = Nothing, max = Nothing } typed of
                        Ok (Just parsed) ->
                            Parse.toMinutes parsed

                        _ ->
                            defaultMinutes

                Nothing ->
                    s.time |> Maybe.map Parse.toMinutes |> Maybe.withDefault defaultMinutes

        nextIndex =
            case currentIndex of
                Just index ->
                    Basics.max 0 (Basics.min (count - 1) (index + delta))

                Nothing ->
                    -- The first option at or after the start going down, the last one at or before it going up.
                    if delta > 0 then
                        options
                            |> List.indexedMap Tuple.pair
                            |> List.filter (\( _, option ) -> option >= startMinutes)
                            |> List.head
                            |> Maybe.map (\( index, _ ) -> Basics.min (count - 1) (index + delta - 1))
                            |> Maybe.withDefault (count - 1)

                    else
                        options
                            |> List.indexedMap Tuple.pair
                            |> List.filter (\( _, option ) -> option <= startMinutes)
                            |> List.reverse
                            |> List.head
                            |> Maybe.map (\( index, _ ) -> Basics.max 0 (index + delta + 1))
                            |> Maybe.withDefault 0

        chosen =
            options |> List.drop nextIndex |> List.head
    in
    case chosen of
        Just minutes ->
            ( State { s | highlight = Just minutes }
            , Internal.ensureVisible { listId = listId s.id, index = nextIndex, rowHeight = rowHeight } Noop
            )

        Nothing ->
            ( State s, Cmd.none )



-- ATTRIBUTES


{-| A setting of a time field. Make them with the functions below and pass a
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
    , min : Maybe Time
    , max : Maybe Time
    , step : Int
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
        , min = Nothing
        , max = Nothing
        , step = 15
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
to screen readers: a required time that is missing, or a time that conflicts
with another field. While the picker has a complaint of its own about the typed
text ("Invalid time"), that message is shown instead.

    TimePicker.error "Choose a cut-off time"

-}
error : String -> Attribute
error value =
    updateField (Field.setError (Just value))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    TimePicker.errorMaybe model.cutoffError

-}
errorMaybe : Maybe String -> Attribute
errorMaybe value =
    updateField (Field.setError value)


{-| Marks the field as required: an asterisk after the label, and
`aria-required` on the input. The picker does not enforce it; when the time is
missing, test `time` for `Nothing` yourself and pass an `error`.
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
`hh:mm` in English.
-}
placeholder : String -> Attribute
placeholder value =
    Attribute (\config -> { config | placeholder = Just value })


{-| Disables the field and its clock button: the text cannot be focused or
changed and the list cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The time can be seen, selected and copied but not changed, and the list does
not open. Unlike `disabled`, the field can still be focused. Default: `False`.
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


{-| The language of the built-in text: placeholder, button and list labels, the
"No times to choose" notice and the error messages. The time format is always
24-hour `hh:mm`. The default is `Locale.default`, which is English; see
[Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| The earliest time that can be chosen or typed. The list starts at the first
time of its step at or after it, and a typed time before it shows "The time
cannot be before" followed by the limit. Default: 00:00.

    TimePicker.min { hour = 8, minute = 0 }

-}
min : Time -> Attribute
min value =
    Attribute (\config -> { config | min = Just value })


{-| The latest time that can be chosen or typed. The list stops at the last time
of its step at or before it, and a typed time after it shows "The time cannot be
after" followed by the limit. Default: 23:59.

    TimePicker.max { hour = 16, minute = 0 }

-}
max : Time -> Attribute
max value =
    Attribute (\config -> { config | max = Just value })


{-| Minutes between the times in the list, from 1 to 60 (other numbers are cut to
that range). Default: 15.

The times are multiples of the step counted from midnight, so a step that divides
60 (5, 10, 15, 20, 30 or 60) lines the list up with the hour. Typed times
between the steps are accepted whatever the step is.

-}
step : Int -> Attribute
step value =
    Attribute (\config -> { config | step = Basics.max 1 (Basics.min 60 value) })


{-| Aligns the right edge of the list with the right edge of the field, instead
of the left edges. Use it for a field near the right side of the page, so that
the list does not run out of the window.
-}
alignEnd : Attribute
alignEnd =
    Attribute (\config -> { config | alignEnd = True })


{-| The `name` attribute of the text input, for a plain HTML `form`. The value
that is sent is the text in the field. Default: none.
-}
name : String -> Attribute
name value =
    Attribute (\config -> { config | name = Just value })


rulesOf : Config -> Rules
rulesOf config =
    { min = config.min, max = config.max, step = config.step }



-- VIEW


type alias Strings =
    { placeholder : String
    , openList : String
    , list : String
    , empty : String
    , clear : String
    }


strings : Locale -> Strings
strings lang =
    Locale.pick lang
        { nb =
            { placeholder = "tt:mm"
            , openList = "Åpne liste med klokkeslett"
            , list = "Klokkeslett"
            , empty = "Ingen tidspunkt å velge"
            , clear = "Tøm feltet"
            }
        , en =
            { placeholder = "hh:mm"
            , openList = "Open list of times"
            , list = "Times"
            , empty = "No times to choose"
            , clear = "Clear field"
            }
        }


{-| The field: a text input with a clock button, and the list of times while it
is open. The first argument wraps the picker's messages in one of yours.

    TimePicker.view CutoffMsg
        [ TimePicker.label "Order cut-off", TimePicker.step 30 ]
        model.cutoff

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
                    s.time |> Maybe.map Parse.formatTime |> Maybe.withDefault ""

        field =
            config.field
                |> Field.setId s.id
                |> (case s.problem of
                        Just problem ->
                            Field.setError (Just (Parse.timeMessage config.locale problem))

                        Nothing ->
                            identity
                   )

        inactive =
            config.disabled || config.readOnly

        showClear =
            config.clearable && shown /= "" && not inactive

        keys =
            if s.open then
                [ ( "ArrowDown", toMsg (Moved rules 1) )
                , ( "ArrowUp", toMsg (Moved rules -1) )
                , ( "PageDown", toMsg (Moved rules 8) )
                , ( "PageUp", toMsg (Moved rules -8) )
                , ( "Enter", toMsg (Entered rules) )
                , ( "Alt+ArrowUp", toMsg Closed )
                , ( "Escape", toMsg Closed )
                ]

            else
                [ ( "ArrowDown", toMsg (OpenRequested rules) )
                , ( "ArrowUp", toMsg (OpenRequested rules) )
                , ( "Alt+ArrowDown", toMsg (OpenRequested rules) )
                , ( "Enter", toMsg (Entered rules) )
                ]
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div [ Internal.cls [ "klar-anchor", "klar-anchor--block", "klar-timepicker" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Internal.sizeSuffix config.size
                    , "klar-timepicker__box"
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
                        ++ [ Internal.cls [ "klar-input__control", "klar-timepicker__control" ]
                           , Attr.type_ "text"
                           , Attr.value shown
                           , Attr.placeholder (Maybe.withDefault words.placeholder config.placeholder)
                           , Attr.disabled config.disabled
                           , Attr.readonly config.readOnly
                           , Attr.attribute "autocomplete" "off"
                           , Attr.attribute "role" "combobox"
                           , Attr.attribute "aria-haspopup" "listbox"
                           , Attr.attribute "aria-autocomplete" "list"
                           , Attr.attribute "aria-expanded" (boolString (s.open && not inactive))
                           , Internal.attrIf (s.open && not inactive) (Attr.attribute "aria-controls" (listId s.id))
                           , case ( s.open, s.highlight ) of
                                ( True, Just minutes ) ->
                                    Attr.attribute "aria-activedescendant" (optionId s.id minutes)

                                _ ->
                                    Internal.noAttr
                           , Internal.attrMaybe Attr.name config.name
                           , Events.onInput (\typed -> toMsg (Typed rules typed))
                           , Popup.onBlurOutside (s.id ++ "-popup") (toMsg (Blurred rules))
                           , if inactive then
                                Internal.noAttr

                             else
                                Events.onClick (toMsg (Clicked rules))
                           , if inactive then
                                Internal.noAttr

                             else if s.open then
                                Popup.onKeys keys

                             else
                                Internal.onKeys keys
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
                    , Attr.attribute "aria-label" words.openList
                    , Attr.attribute "aria-haspopup" "listbox"
                    , Attr.attribute "aria-expanded" (boolString (s.open && not inactive))
                    , Attr.disabled inactive
                    , Events.onClick (toMsg (Toggled rules))
                    ]
                    [ Icon.view Icon.clock ]
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
        options =
            optionsOf rules

        selectedMinutes =
            Maybe.map Parse.toMinutes s.time

        viewOption minutes =
            Html.div
                [ Internal.cls
                    [ "klar-timepicker__option"
                    , if Just minutes == selectedMinutes && s.draft == Nothing then
                        "klar-timepicker__option--selected"

                      else
                        ""
                    , if Just minutes == s.highlight then
                        "klar-timepicker__option--highlighted"

                      else
                        ""
                    ]
                , Attr.id (optionId s.id minutes)
                , Attr.attribute "role" "option"
                , Attr.attribute "aria-selected" (boolString (Just minutes == selectedMinutes && s.draft == Nothing))
                , Events.onClick (toMsg (Picked minutes))
                , Events.onMouseEnter (toMsg (Hovered minutes))
                ]
                [ Html.text (Parse.formatTime (Parse.fromMinutes minutes)) ]
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Popup.onPressOutside (toMsg Closed)
        ]
        [ Html.div
            [ Internal.cls
                [ "klar-popup"
                , "klar-timepicker__popup"
                , if config.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
            , Attr.id (s.id ++ "-popup")
            , Popup.holdFocus (toMsg Noop)
            , Internal.onClickStop (toMsg Noop)
            , Events.on "focusin" (Decode.succeed (toMsg Refocused))
            ]
            [ if List.isEmpty options then
                Html.div [ Internal.cls [ "klar-timepicker__empty" ] ] [ Html.text words.empty ]

              else
                Html.div
                    [ Internal.cls [ "klar-timepicker__list" ]
                    , Attr.id (listId s.id)
                    , Attr.tabindex -1
                    , Attr.attribute "role" "listbox"
                    , Attr.attribute "aria-label" words.list
                    ]
                    (List.map viewOption options)
            ]
        ]


boolString : Bool -> String
boolString value =
    if value then
        "true"

    else
        "false"
