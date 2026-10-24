module Klar.NumberInput exposing
    ( view, Attribute
    , State, Msg, init, update
    , value, setValue, setLimits, clear, isValid, isTouched
    , parse, parseIn
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , min, max, step, noSteppers
    , decimals, grouped, prefixText, suffixText, alignRight, placeholder, size
    , disabled, readOnly, name
    , locale
    )

{-| A number field that understands how people write numbers. It keeps the
text the user types ("1 234,5" or "12.5") and turns it into a number, so it is
stateful.

Use when: the value is a number that people type in their own way, with limits, decimals or a unit.
Do not use when: the value is plain text (use `Klar.TextInput`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.NumberInput as NumberInput

    type alias Model =
        { quantity : NumberInput.State }

    init : Model
    init =
        { quantity = NumberInput.init "line-quantity" }

    -- update
    QuantityMsg inner ->
        let
            ( quantity, cmd ) =
                NumberInput.update inner model.quantity
        in
        ( { model | quantity = quantity }, Cmd.map QuantityMsg cmd )

    -- view
    NumberInput.view QuantityMsg
        [ NumberInput.label "Quantity"
        , NumberInput.min 1
        , NumberInput.max 500
        , NumberInput.suffixText "pcs"
        ]
        model.quantity

    -- read the number
    NumberInput.value model.quantity -- Maybe Float

The `String` given to `init` is the DOM id of the input, so there is no `id`
attribute. The application reads the number with `value`, reacts to changes by
comparing `value` before and after `update`, and uses `isTouched` to show errors
only after the user has been in the field once.

The input is a text input with a numeric keyboard hint, not the browser's
`type="number"`, so what the user types is kept as typed until the field is
left.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker,
the hint and the error message around the input and connects them for screen
readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). The number
field is always inside the wrapper, so it does not move when an error comes and
goes.

**Typing.** The field reads what is typed in the language of the field
(`locale`), the way `Klar.Format` writes numbers. In English a point is the
decimal point and a comma groups thousands: `1,234.5` and `1234.5` are both
1234.5, and `1,234` is 1234. In Norwegian a comma is the decimal comma, and a
space or a point groups thousands, as people write them: `1 234,5`, `1.234,5`
and `1234,5` are all 1234.5, `10.000` is ten thousand and `1,234` is 1.234.
Spaces and apostrophes are ignored in both. The other separator than the
decimal one that cannot group thousands is read as the decimal separator: `1,5`,
`12,34` and `0,500` in English, `1.5`, `12.25` and `0.500` in Norwegian. A
number written with both separators is read with the last one as the decimal
separator, so `1.234,56` and `1,234.56` are both 1234.56. Whatever the field
reads, it shows when it is left, so a reading the user did not mean is seen at
once. See `parseIn`.

**What the field shows.** The number is written by `Klar.Format` when the user
leaves the field, with the separators of the language: a point as the decimal
point in English and a comma in Norwegian, and with `grouped` a comma between
the thousands in English (`100,000`) and a no-break space in Norwegian
(`100 000`). The range error writes its limits in the same way. A negative
number begins with the minus sign of the keyboard, so that the text can be
edited and copied into a spreadsheet.

**Errors.** Text that is not a number shows the built-in error "Must be a
number". A number outside `min` and `max` shows the built-in range error, such
as "Must be between 1 and 500 pcs" ("Must be at least ..." or "Must be at most
..." when only one limit is set, with the `suffixText` unit added). Both replace
the application's own `error` until they are fixed. While the user is typing the
messages wait until the field is left, because "-" or "1," may be the start of a
number; only text with letters in it is reported at once.

**A typed number is never changed.** A number outside `min` and `max` is never
moved into the range behind the user's back. If someone types a discount of 55 %
where the highest allowed is 50, the field keeps 55 (it does not quietly become
50), shows the built-in error "Must be between 0 and 50" once the field is left,
and `isValid` is `False` from the first keystroke until it is fixed. The same
holds for a number you put in with `setValue`. Only stepping, with the + and -
buttons or the keyboard, moves a number into the range, because the user asked
for exactly that.

`isValid` knows the limits from the attributes of the view, which the field
learns when the user focuses, types in, leaves or steps it. A number that you
put in with `setValue` before any of that, such as one loaded from a server,
needs `setLimits` once, with the same attributes you give to `view`.

**Keyboard.** Arrow up and down change the number by `step`, and with Shift (or
with page up and page down) by ten steps. Stepping keeps to the grid of the steps
from `min` (or 0), as the browser's own number field does: with a step of 5, 3
goes up to 5. Stepping never leaves `min` and `max`. A pasted number that
carries the unit of the field (`12 kg`, `USD 12`) is read without it.
Leaving the field, or pressing Enter, rounds the number to `decimals` (half
away from zero, on the decimal digits, as `Klar.Format` rounds: `1.005` is
`1.01`) and formats it; Enter still lets a surrounding form submit. Escape
throws away the text being typed and brings back the number from before; its
default is then prevented, so a dialog around the field stays open. The + and -
buttons are not in the Tab order.

**Phones.** A field whose `min` is 0 or more asks for the numeric keyboard
(`inputmode` decimal, or numeric with `decimals 0`). A field that takes
negative numbers, or has no `min`, gets the full keyboard, because the numeric
keyboard of an iPhone has no minus key; give a field for amounts that cannot be
negative `min 0`.

**Accessibility.** The input has the role `spinbutton` with `aria-valuemin`,
`aria-valuemax` and `aria-valuenow`, and an `aria-valuetext` that is the text
of the field with its unit, so a screen reader reads "1 234,5 kg" as the field
shows it and not "1234.5".

The built-in texts (the errors, the names of the + and - buttons) and the number
format (the decimal and thousands separators, in what is shown and what is read)
follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# The number

@docs value, setValue, setLimits, clear, isValid, isTouched


# Reading numbers

@docs parse, parseIn


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Range and steps

@docs min, max, step, noSteppers


# Display

@docs decimals, grouped, prefixText, suffixText, alignRight, placeholder, size


# State and browser hints

@docs disabled, readOnly, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.TextField as TextField
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of a number field: the text being typed, the number read from it
and whether the user has been in the field. Make one with `init`, keep it in
your model and give it to `view` and `update`.
-}
type State
    = State Fields


type alias Fields =
    { id : String
    , value : Maybe Float
    , draft : Maybe String
    , touched : Bool
    , focused : Bool

    -- the number before the text being typed, for Escape
    , before : Maybe Float

    -- the `min` and `max` the field last saw (in a message of the view, or from
    -- `setLimits`), so that `isValid` can tell whether the number is inside them
    , range : ( Maybe Float, Maybe Float )
    }


{-| An empty field. The `String` is the DOM id of the input; it must be unique
on the page, because the label, hint and error point at it. To start with a
number, use `setValue`.

    NumberInput.init "line-quantity" |> NumberInput.setValue (Just 12)

-}
init : String -> State
init id =
    State { id = id, value = Nothing, draft = Nothing, touched = False, focused = False, before = Nothing, range = ( Nothing, Nothing ) }


{-| The number in the field, or `Nothing` when the field is empty or the text
is not a number. A number outside `min` and `max` is returned as it was typed;
`isValid` tells whether it is inside them.
-}
value : State -> Maybe Float
value (State state) =
    state.value


{-| Shows a number, or an empty field for `Nothing`, and throws away any text
that was being typed. The number is not moved into `min` and `max`: `isValid`
tells whether it is inside the limits the field knows (see `setLimits`). It is
shown as the attributes of the view say (`decimals`, `grouped`, `locale`), so
the decimal separator matches the language.
-}
setValue : Maybe Float -> State -> State
setValue maybe (State state) =
    State { state | value = maybe, draft = Nothing }


{-| Tells the state the limits (`min` and `max`) in the given attributes, so that
`isValid` knows them before the user has touched the field. Pass the list you
give to `view`; the other attributes in it are ignored. The number is never
changed.

A field learns its limits by itself when the user focuses, types in, leaves or
steps it. This is for a number that you put in with `setValue` before that, such
as a value loaded from a server, and for limits that change while the field is
on the screen.

    quantity : List (NumberInput.Attribute Msg)
    quantity =
        [ NumberInput.label "Quantity", NumberInput.min 1, NumberInput.max 500 ]

    NumberInput.init "line-quantity"
        |> NumberInput.setLimits quantity
        |> NumberInput.setValue (Just 700)
        |> NumberInput.isValid
    --> False

-}
setLimits : List (Attribute msg) -> State -> State
setLimits attributes (State state) =
    let
        config =
            configure attributes
    in
    State { state | range = ( config.min, config.max ) }


{-| Empties the field and forgets that the user has been in it (`isTouched` is
`False` again), for example for a "Clear form" button.
-}
clear : State -> State
clear (State state) =
    State { state | value = Nothing, draft = Nothing, touched = False }


{-| `True` when the field is empty or holds a number inside `min` and `max`, and
`False` when the text is not a number or the number is outside them. It answers
at once, also while the user is still typing, although the field's own messages
wait until the field is left. A number outside the limits is never moved into
them (only stepping does that), so the application decides what to do.

The limits are the ones the field was last given: by the attributes of the view,
which the field learns when the user focuses, types in, leaves or steps it, or
by `setLimits`. An empty field counts as valid: for a number that is required,
also check `value` for `Nothing`.

-}
isValid : State -> Bool
isValid ((State state) as current) =
    isReadable current && withinRange state.range state.value


{-| The text in the field is empty or a number (whatever its size). The number
was read from the text as it was typed (`readTyped`).
-}
isReadable : State -> Bool
isReadable (State state) =
    case state.draft of
        Nothing ->
            True

        Just raw ->
            String.trim raw == "" || state.value /= Nothing


withinRange : ( Maybe Float, Maybe Float ) -> Maybe Float -> Bool
withinRange ( low, high ) maybeNumber =
    case maybeNumber of
        Nothing ->
            True

        Just number ->
            not (isBelow low number) && not (isAbove high number)


isBelow : Maybe Float -> Float -> Bool
isBelow low number =
    Maybe.map (\bound -> number < bound) low |> Maybe.withDefault False


isAbove : Maybe Float -> Float -> Bool
isAbove high number =
    Maybe.map (\bound -> number > bound) high |> Maybe.withDefault False


{-| `True` once the user has left the field, pressed Enter in it or used one of
the stepper buttons. Use it to show errors only after the first visit. `clear`
makes it `False` again.
-}
isTouched : State -> Bool
isTouched (State state) =
    state.touched



-- UPDATE


type alias Rules =
    { min : Maybe Float
    , max : Maybe Float
    , step : Float
    , decimals : Maybe Int

    -- the language the text is read in: a comma groups thousands in English
    -- and is the decimal comma in Norwegian
    , locale : Locale

    -- the prefix and suffix texts, which a pasted number may carry ("12 kg")
    , units : List String
    }


{-| The messages a number field sends: typing, focus, leaving the field and the
steppers. `view` wraps them with the function you give it; hand them to `update`
when they come back.
-}
type Msg
    = Typed Rules String
    | Focused Rules
    | Committed Rules
    | Entered Rules
    | Stepped Rules Float
    | Reverted
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` puts the focus back
in the input after a stepper button was used, so pass it on with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Typed rules raw ->
            -- Every message brings the limits the view was given, so that
            -- `isValid` is right while the user is still typing.
            ( State
                { state
                    | draft = Just raw
                    , value = readTyped rules raw
                    , range = rangeOf rules
                    , before =
                        if state.draft == Nothing then
                            state.value

                        else
                            state.before
                }
            , Cmd.none
            )

        Focused rules ->
            ( State { state | focused = True, range = rangeOf rules }, Cmd.none )

        Committed rules ->
            -- the field was left
            ( State (commit rules { state | focused = False }), Cmd.none )

        Entered rules ->
            -- Enter: format the number, but the cursor stays
            ( State (commit rules state), Cmd.none )

        Stepped rules multiplier ->
            let
                base =
                    case state.draft of
                        Just raw ->
                            readTyped rules raw |> Maybe.withDefault (Maybe.withDefault 0 state.value)

                        Nothing ->
                            Maybe.withDefault 0 state.value

                places =
                    Basics.max (decimalPlaces rules.step)
                        (Basics.max (decimalPlaces base) (Maybe.withDefault 0 rules.decimals))

                next =
                    roundTo places (onGrid rules base multiplier)
                        |> roundToDecimals rules
                        |> keepInRange rules
            in
            ( State { state | value = Just next, draft = Nothing, touched = True, range = rangeOf rules }
            , Internal.focus state.id Noop
            )

        Reverted ->
            -- Escape: the text being typed goes, the number from before is back
            ( State { state | draft = Nothing, value = state.before }, Cmd.none )

        Noop ->
            ( State state, Cmd.none )


{-| The field was left (or Enter was pressed): the text becomes a formatted
number. The number is rounded to the decimals the field was given, but never
moved into `min` and `max`: a number outside them stays as typed and is shown
as an error.
-}
commit : Rules -> Fields -> Fields
commit rules state =
    let
        seen =
            { state | touched = True, range = rangeOf rules }
    in
    case state.draft of
        Nothing ->
            seen

        Just raw ->
            if String.trim raw == "" then
                { seen | draft = Nothing, value = Nothing }

            else
                case readTyped rules raw of
                    Just number ->
                        { seen | draft = Nothing, value = Just (roundToDecimals rules number) }

                    Nothing ->
                        seen


rangeOf : Rules -> ( Maybe Float, Maybe Float )
rangeOf rules =
    ( rules.min, rules.max )


roundToDecimals : Rules -> Float -> Float
roundToDecimals rules number =
    case rules.decimals of
        Just places ->
            roundTo places number

        Nothing ->
            number


{-| What the user typed, read in the language of the field. A unit of the field
at the start or the end (`12 kg`, `USD 12`, as a spreadsheet copies it) is
left out of the reading; the text itself is kept as it was typed.
-}
readTyped : Rules -> String -> Maybe Float
readTyped rules raw =
    case parseIn rules.locale raw of
        Just number ->
            Just number

        Nothing ->
            parseIn rules.locale (withoutUnits rules.units raw)


withoutUnits : List String -> String -> String
withoutUnits units raw =
    List.foldl
        (\unit text ->
            let
                trimmed =
                    String.trim text

                lower =
                    String.toLower trimmed

                mark =
                    String.toLower (String.trim unit)
            in
            if mark == "" then
                text

            else if String.startsWith mark lower then
                String.dropLeft (String.length mark) trimmed

            else if String.endsWith mark lower then
                String.dropRight (String.length mark) trimmed

            else
                text
        )
        raw
        units


{-| One step (or ten) up or down from `base`, on the grid of the steps: from
`min` (or 0) in steps of `step`, as the browser's own number field steps. A
number between two points of the grid goes to the next one in the direction of
the key (3 with a step of 5 goes up to 5 and down to 0), and that counts as the
first step.
-}
onGrid : Rules -> Float -> Float -> Float
onGrid rules base multiplier =
    let
        stepSize =
            safeStep rules.step

        anchor =
            Maybe.withDefault 0 rules.min

        offset =
            (base - anchor) / stepSize

        nearest =
            toFloat (round offset)

        points =
            if abs (offset - nearest) < 1.0e-9 then
                nearest + multiplier

            else if multiplier > 0 then
                toFloat (ceiling offset) + (multiplier - 1)

            else
                toFloat (floor offset) + (multiplier + 1)
    in
    anchor + points * stepSize


{-| Used by the steppers and arrow keys only: stepping stops at the limits.
-}
keepInRange : Rules -> Float -> Float
keepInRange rules number =
    let
        atLeast =
            case rules.min of
                Just low ->
                    Basics.max low number

                Nothing ->
                    number
    in
    case rules.max of
        Just high ->
            Basics.min high atLeast

        Nothing ->
            atLeast


safeStep : Float -> Float
safeStep amount =
    if amount > 0 then
        amount

    else
        1


{-| Rounds as `Klar.Format` writes the number: on its decimal digits, half away
from zero, so that `1.005` with two decimals is `1.01` (not `1.00`, as
multiplying with floating point gives) and `-0.125` is `-0.13`, and the number
that is kept is the number that is shown.
-}
roundTo : Int -> Float -> Float
roundTo places number =
    if places < 0 || isNaN number || isInfinite number then
        number

    else
        Format.decimal Locale.en places number
            |> String.replace "," ""
            |> String.replace "−" "-"
            |> String.toFloat
            |> Maybe.withDefault number



-- ATTRIBUTES


{-| A setting of a number field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type Adornment
    = Adornment String


type alias Config =
    { field : Field.Config
    , placeholder : String
    , min : Maybe Float
    , max : Maybe Float
    , step : Float
    , decimals : Maybe Int
    , grouped : Bool
    , prefix : Maybe Adornment
    , suffix : Maybe Adornment
    , noSteppers : Bool
    , alignRight : Bool
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , name : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , placeholder = ""
        , min = Nothing
        , max = Nothing
        , step = 1
        , decimals = Nothing
        , grouped = False
        , prefix = Nothing
        , suffix = Nothing
        , noSteppers = False
        , alignRight = False
        , disabled = False
        , readOnly = False
        , size = Medium
        , name = Nothing
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label shown above the field. It is connected to the input, so clicking
it focuses the input and screen readers read it as the name of the input. Give
every field a label, or hide it with `labelHidden`.
-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. The field's own messages, for
text that is not a number and for a number outside `min` and `max`, replace this
one until they are fixed, so it is the place for rules of your own, such as a
business rule.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` on the input. This does not validate anything; an empty field
still counts as valid, so check `value` for `Nothing` yourself and show an
`error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| Text shown inside the empty field, for example a sample value. It is not a
substitute for a `label`, and it disappears as soon as the user types. Default:
none.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\config -> { config | placeholder = text })


{-| The smallest allowed number. The stepper buttons and the arrow keys stop
here. A smaller number that is typed is kept as it is: the field shows the
built-in error ("Must be at least ..." or "Must be between ..."), and `isValid`
is `False` until it is fixed. Default: no lower limit.

    NumberInput.min 1

-}
min : Float -> Attribute msg
min number =
    Attribute (\config -> { config | min = Just number })


{-| The largest allowed number, in the same way as `min`: stepping stops here,
and a larger number that is typed is kept, shown with the built-in error and
reported by `isValid`. Default: no upper limit.

    NumberInput.max 500

-}
max : Float -> Attribute msg
max number =
    Attribute (\config -> { config | max = Just number })


{-| How much the arrow keys and the stepper buttons change the number. With
Shift, or with page up and page down, the change is ten times as big. Default 1;
a step of zero or less counts as 1.

    NumberInput.step 0.5

-}
step : Float -> Attribute msg
step amount =
    Attribute (\config -> { config | step = amount })


{-| A fixed number of decimals: the number is rounded to it when the field is
left, and it is always shown with exactly that many (`2` shows 12.5 as `12.50`).
`0` gives whole numbers, and phones show the numeric keyboard. Without it the
number keeps the decimals it has.
-}
decimals : Int -> Attribute msg
decimals places =
    Attribute (\config -> { config | decimals = Just (Basics.max 0 places) })


{-| Shows thousands separators, as `Klar.Format` writes them: 1234567 appears as
`1,234,567` in English and as `1 234 567` (with no-break spaces) in Norwegian.
The range error writes its limits the same way. What the user types is read in
the same language (see `parseIn`), so `1,234.5` is a number in English and
`1 234,5` in Norwegian. Default: no separators.
-}
grouped : Attribute msg
grouped =
    Attribute (\config -> { config | grouped = True })


{-| A unit or currency shown before the number, inside the field. Screen readers
read it with the number.

    NumberInput.prefixText "USD"

-}
prefixText : String -> Attribute msg
prefixText text =
    Attribute (\config -> { config | prefix = Just (Adornment text) })


{-| A unit shown after the number, inside the field, such as `kg`, `pcs` or `%`.
Screen readers read it with the number, and the range error repeats it ("Must be
between 1 and 500 pcs").

    NumberInput.suffixText "kg"

-}
suffixText : String -> Attribute msg
suffixText text =
    Attribute (\config -> { config | suffix = Just (Adornment text) })


{-| Hides the + and - buttons at the end of the field, for a field where
stepping makes no sense, such as a price. They are shown by default, and never
while the field is `disabled` or `readOnly`. The buttons are not in the Tab
order; keyboard users have the arrow keys either way.
-}
noSteppers : Attribute msg
noSteppers =
    Attribute (\config -> { config | noSteppers = True })


{-| Aligns the number to the right, for columns of amounts. Default: left.
-}
alignRight : Attribute msg
alignRight =
    Attribute (\config -> { config | alignRight = True })


{-| While `True` the field is dimmed and cannot be focused or changed. Default
`False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the user can focus the field and select its text, but not
change it. Default `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px) at the default density (see `Klar.Theme` for the others), from
[Klar.Theme](Klar-Theme). Default `Medium`.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.
-}
name : String -> Attribute msg
name value_ =
    Attribute (\config -> { config | name = Just value_ })


{-| The language of the built-in texts and of the number format: the error
messages, the names of the stepper buttons ("Increase value" and "Decrease
value"), the separators the number is written with (`12.5` in English, `12,5` in
Norwegian; with `grouped`, `1,234.5` and `1 234,5`) and the way what the user
types is read (see `parseIn`). Default `Locale.default`, which is English. Texts
you pass in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| A number field with its label, hint and error message. The first argument
wraps the field's own messages in one of yours, and the state comes last.

    NumberInput.view QuantityMsg
        [ NumberInput.label "Quantity"
        , NumberInput.min 1
        ]
        model.quantity

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes ((State state) as current) =
    let
        config =
            configure attributes

        rules =
            { min = config.min
            , max = config.max
            , step = config.step
            , decimals = config.decimals
            , locale = config.locale
            , units = List.filter (\unit -> unit /= "") [ adornmentText config.prefix, adornmentText config.suffix ]
            }

        -- While typing, "-" or "," is just the start of a number: the message
        -- waits until the field is left, unless the text has letters in it.
        showParseError =
            not (isReadable current)
                && (not state.focused || hasForeignCharacters (Maybe.withDefault "" state.draft))

        -- Built-in errors win over the application's own until they are fixed.
        builtInError =
            if showParseError then
                Just (Locale.pick config.locale { nb = "Må være et tall", en = "Must be a number" })

            else
                rangeError config current

        field =
            config.field
                |> Field.setId state.id
                |> Field.setError
                    (case builtInError of
                        Just message ->
                            Just message

                        Nothing ->
                            config.field.error
                    )

        inactive =
            config.disabled || config.readOnly

        shown =
            displayText config current

        atMin =
            case ( state.value, config.min ) of
                ( Just number, Just low ) ->
                    number <= low

                _ ->
                    False

        atMax =
            case ( state.value, config.max ) of
                ( Just number, Just high ) ->
                    number >= high

                _ ->
                    False

        -- "12 500,00 USD" for a screen reader, as the field shows it (in the
        -- language of the field, with the unit); nothing while the field is
        -- empty (a unit alone is not a value)
        spokenValue =
            if String.trim shown == "" then
                Internal.noAttr

            else
                Attr.attribute "aria-valuetext"
                    (String.join " "
                        (List.filter (\part -> part /= "")
                            [ adornmentText config.prefix, shown, adornmentText config.suffix ]
                        )
                    )

        -- The phone keyboards for numbers have no minus key on an iPhone, so a
        -- field that takes negative numbers gets the full keyboard.
        keyboard =
            case config.min of
                Just low ->
                    if low >= 0 then
                        Attr.attribute "inputmode"
                            (if config.decimals == Just 0 then
                                "numeric"

                             else
                                "decimal"
                            )

                    else
                        Internal.noAttr

                Nothing ->
                    Internal.noAttr
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-input"
                , "klar-input--" ++ Internal.sizeSuffix config.size
                , "klar-number"
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
            [ viewAdornment "prefix" config.prefix
            , Html.input
                (Field.controlAttributes field
                    ++ [ Internal.cls
                            [ "klar-input__control"
                            , "klar-number__control"
                            , if config.alignRight then
                                "klar-number__control--end"

                              else
                                ""
                            ]
                       , Attr.type_ "text"
                       , keyboard
                       , Attr.attribute "autocomplete" "off"
                       , Attr.attribute "role" "spinbutton"
                       , Internal.attrMaybe (\low -> Attr.attribute "aria-valuemin" (String.fromFloat low)) config.min
                       , Internal.attrMaybe (\high -> Attr.attribute "aria-valuemax" (String.fromFloat high)) config.max
                       , Internal.attrMaybe (\number -> Attr.attribute "aria-valuenow" (String.fromFloat (keepInRange rules number))) state.value
                       , spokenValue
                       , Attr.value shown
                       , Attr.placeholder config.placeholder
                       , Attr.disabled config.disabled
                       , Attr.readonly config.readOnly
                       , Internal.attrMaybe Attr.name config.name
                       , Events.onInput (\text -> toMsg (Typed rules text))
                       , Events.onFocus (toMsg (Focused rules))
                       , Events.onBlur (toMsg (Committed rules))
                       , Internal.attrIf (not inactive) (Events.preventDefaultOn "keydown" (keyDecoder toMsg rules (state.draft /= Nothing)))
                       ]
                )
                []
            , viewAdornment "suffix" config.suffix
            , if not config.noSteppers && not inactive then
                viewSteppers toMsg config.locale rules atMin atMax

              else
                Html.text ""
            ]
        )


{-| "Must be between 0 and 50 pcs" when the number is outside `min` and `max`.
It waits while the user is still typing, like the "not a number" error.
-}
rangeError : Config -> State -> Maybe String
rangeError config (State state) =
    case state.value of
        Nothing ->
            Nothing

        Just number ->
            let
                typing =
                    state.focused && state.draft /= Nothing

                unit =
                    case adornmentText config.suffix of
                        "" ->
                            ""

                        text ->
                            "\u{00A0}" ++ text

                show bound =
                    readableNumber config.locale config.grouped (decimalPlaces bound) bound

                message =
                    case ( config.min, config.max ) of
                        ( Just low, Just high ) ->
                            Locale.pick config.locale
                                { nb = "Må være mellom " ++ show low ++ " og " ++ show high ++ unit
                                , en = "Must be between " ++ show low ++ " and " ++ show high ++ unit
                                }

                        ( Just low, Nothing ) ->
                            Locale.pick config.locale
                                { nb = "Må være minst " ++ show low ++ unit
                                , en = "Must be at least " ++ show low ++ unit
                                }

                        ( Nothing, Just high ) ->
                            Locale.pick config.locale
                                { nb = "Må være høyst " ++ show high ++ unit
                                , en = "Must be at most " ++ show high ++ unit
                                }

                        ( Nothing, Nothing ) ->
                            ""
            in
            if typing || withinRange ( config.min, config.max ) (Just number) then
                Nothing

            else
                Just message


viewSteppers : (Msg -> msg) -> Locale -> Rules -> Bool -> Bool -> Html msg
viewSteppers toMsg lang rules atMin atMax =
    Html.span [ Internal.cls [ "klar-number__steps" ] ]
        [ stepper toMsg
            (Locale.pick lang { nb = "Reduser verdien", en = "Decrease value" })
            Icon.minus
            atMin
            (Stepped rules -1)
        , stepper toMsg
            (Locale.pick lang { nb = "Øk verdien", en = "Increase value" })
            Icon.plus
            atMax
            (Stepped rules 1)
        ]


stepper : (Msg -> msg) -> String -> Icon.Icon -> Bool -> Msg -> Html msg
stepper toMsg label_ icon blocked msg =
    Html.button
        [ Internal.cls [ "klar-number__step" ]
        , Attr.type_ "button"
        , Attr.tabindex -1
        , Attr.attribute "aria-label" label_
        , Attr.title label_
        , Attr.disabled blocked
        , Internal.onMouseDownPrevent (toMsg Noop)
        , Events.onClick (toMsg msg)
        ]
        [ Icon.sized Icon.Small icon ]


keyDecoder : (Msg -> msg) -> Rules -> Bool -> Decode.Decoder ( msg, Bool )
keyDecoder toMsg rules editing =
    Decode.map2 Tuple.pair TextField.composing Internal.keyEvent
        |> Decode.andThen
            (\( isComposing, event ) ->
                if isComposing then
                    Decode.fail "composing"

                else if event.ctrl || event.meta || event.alt then
                    Decode.fail "modifier"

                else
                    case event.key of
                        "Escape" ->
                            if editing then
                                -- prevented, so that a dialog around the field
                                -- knows the key was used and stays open
                                Decode.succeed ( toMsg Reverted, True )

                            else
                                Decode.fail "nothing to undo"

                        "ArrowUp" ->
                            Decode.succeed ( toMsg (Stepped rules (stepsFor event.shift)), True )

                        "ArrowDown" ->
                            Decode.succeed ( toMsg (Stepped rules (negate (stepsFor event.shift))), True )

                        "PageUp" ->
                            Decode.succeed ( toMsg (Stepped rules 10), True )

                        "PageDown" ->
                            Decode.succeed ( toMsg (Stepped rules -10), True )

                        "Enter" ->
                            -- Format the number, but let the form submit.
                            Decode.succeed ( toMsg (Entered rules), False )

                        _ ->
                            Decode.fail "unhandled key"
            )


stepsFor : Bool -> Float
stepsFor shift =
    if shift then
        10

    else
        1


viewAdornment : String -> Maybe Adornment -> Html msg
viewAdornment position adornment =
    case adornment of
        Just (Adornment text) ->
            Html.span
                [ Internal.cls [ "klar-input__adornment", "klar-input__adornment--text", "klar-input__" ++ position ] ]
                [ Html.text text ]

        Nothing ->
            Html.text ""


adornmentText : Maybe Adornment -> String
adornmentText adornment =
    case adornment of
        Just (Adornment text) ->
            text

        Nothing ->
            ""


displayText : Config -> State -> String
displayText config (State state) =
    case state.draft of
        Just raw ->
            raw

        Nothing ->
            case state.value of
                Just number ->
                    case config.decimals of
                        Just fixed ->
                            fieldNumber config.locale config.grouped fixed number

                        Nothing ->
                            -- the decimals the number has, but not the noise of
                            -- floating point: 0.1 + 0.2 is shown as 0.3
                            fieldNumber config.locale config.grouped (decimalPlaces number) number
                                |> withoutTrailingZeros config.locale

                Nothing ->
                    ""


{-| `0.3000000000` is `0.3`, `12.0` is `12`: the zeros at the end of the
decimals are dropped, and the decimal separator with them when nothing is left.
-}
withoutTrailingZeros : Locale -> String -> String
withoutTrailingZeros lang text =
    let
        separator =
            Locale.decimalSeparator lang
    in
    case String.split separator text of
        [ whole, fraction ] ->
            let
                kept =
                    dropTrailingZeros fraction
            in
            if kept == "" then
                whole

            else
                whole ++ separator ++ kept

        _ ->
            text


dropTrailingZeros : String -> String
dropTrailingZeros digits =
    if String.endsWith "0" digits then
        dropTrailingZeros (String.dropRight 1 digits)

    else
        digits



-- NUMBERS


{-| Number of decimals a number is written with (at most 10).
-}
decimalPlaces : Float -> Int
decimalPlaces number =
    let
        text =
            String.fromFloat (abs number)
    in
    if String.contains "e" text then
        10

    else
        case String.split "." text of
            [ _, fraction ] ->
                Basics.min 10 (String.length fraction)

            _ ->
                0


{-| A number as a person reads it in a message, written by `Klar.Format`: the
separators of the language (a comma for thousands and a point for decimals in
English, a no-break space and a comma in Norwegian). The thousands separators
are left out unless `useGrouping` says so.
-}
readableNumber : Locale -> Bool -> Int -> Float -> String
readableNumber lang useGrouping places number =
    let
        text =
            Format.decimal lang places number
    in
    if useGrouping then
        text

    else
        String.replace (Locale.thousandSeparator lang) "" text


{-| A number as the field shows it. It is the number of `readableNumber`, but
with the minus sign of the keyboard instead of the real minus sign that
`Klar.Format` writes, so that the text can be edited and copied into a
spreadsheet.
-}
fieldNumber : Locale -> Bool -> Int -> Float -> String
fieldNumber lang useGrouping places number =
    String.replace "−" "-" (readableNumber lang useGrouping places number)


{-| Reads a number the way people write it, in no language in particular: `,`
and `.` both work as the decimal separator, spaces and apostrophes are ignored,
and a leading `-` or `+` is allowed. A single `.` or `,` is always a decimal
separator. Gives `Nothing` for anything else, and for empty text.

    NumberInput.parse "12,5" --> Just 12.5

    NumberInput.parse "1 234,56" --> Just 1234.56

    NumberInput.parse "1.234,56" --> Just 1234.56

    NumberInput.parse "1,234.56" --> Just 1234.56

    NumberInput.parse "1.234" --> Just 1.234

    NumberInput.parse "1,234" --> Just 1.234

    NumberInput.parse "twelve" --> Nothing

The field itself reads what is typed with `parseIn`, which lets the language
decide what a lone comma means.

-}
parse : String -> Maybe Float
parse =
    readNumber Nothing


{-| Reads a number the way the field does while the user types, in the language
of the field. It reads like `parse`, except that a lone separator between groups
of three digits is what the language says it is. In English a comma groups
thousands, so `1,234` is 1234, as `Klar.Format` writes it, and a point is the
decimal point. In Norwegian a comma is the decimal comma, so `1,234` is 1.234,
and a point groups thousands, as many write it, so `10.000` is 10000. The other
separator than the decimal one that cannot group thousands (`1,5`, `12,34`,
`0,500` in English, `1.5`, `12.25`, `0.500` in Norwegian) is the decimal
separator, and a number written with both separators is read with the last one
as the decimal separator (`1.234,56` and `1,234.56` are 1234.56 in both).
Spaces, no-break spaces and apostrophes are ignored.

    NumberInput.parseIn Locale.en "1,234.5" --> Just 1234.5

    NumberInput.parseIn Locale.en "1,234" --> Just 1234

    NumberInput.parseIn Locale.en "1,5" --> Just 1.5

    NumberInput.parseIn Locale.nb "1 234,5" --> Just 1234.5

    NumberInput.parseIn Locale.nb "1234,5" --> Just 1234.5

    NumberInput.parseIn Locale.nb "1,234" --> Just 1.234

    NumberInput.parseIn Locale.nb "10.000" --> Just 10000

    NumberInput.parseIn Locale.nb "1.5" --> Just 1.5

Whatever `Klar.Format.decimal` writes in a language, `parseIn` reads back with
the same language.

-}
parseIn : Locale -> String -> Maybe Float
parseIn lang =
    readNumber (groupingPoint lang)


{-| The separator that groups thousands when it stands alone between groups of
three digits: the one that is not the decimal separator of the language. A comma
in English (`1,234`), and a point in Norwegian, where many write `10.000` for
ten thousand although the standard is a space.
-}
groupingPoint : Locale -> Maybe Char
groupingPoint lang =
    if Locale.decimalSeparator lang == "," then
        Just '.'

    else
        Just ','


readNumber : Maybe Char -> String -> Maybe Float
readNumber grouping raw =
    let
        compact =
            String.filter (\c -> not (isSpaceLike c)) raw

        ( negative, body ) =
            splitSign compact
    in
    if body == "" then
        Nothing

    else if not (String.all (\c -> Char.isDigit c || isSeparator c) body) then
        Nothing

    else
        splitNumber grouping body
            |> Maybe.andThen toNumber
            |> Maybe.map
                (\number ->
                    if negative then
                        negate number

                    else
                        number
                )


{-| Letters and other characters that no number is written with.
-}
hasForeignCharacters : String -> Bool
hasForeignCharacters raw =
    raw
        |> String.filter (\c -> not (isSpaceLike c))
        |> String.any (\c -> not (Char.isDigit c || isSeparator c || c == '-' || c == '+' || c == '−' || c == '–'))


isSpaceLike : Char -> Bool
isSpaceLike c =
    c == ' ' || c == '\u{00A0}' || c == '\u{202F}' || c == '\u{2009}' || c == '\t' || c == '\'' || c == '’'


isSeparator : Char -> Bool
isSeparator c =
    c == ',' || c == '.'


splitSign : String -> ( Bool, String )
splitSign text =
    case String.uncons text of
        Just ( '-', rest ) ->
            ( True, rest )

        Just ( '−', rest ) ->
            ( True, rest )

        Just ( '–', rest ) ->
            ( True, rest )

        Just ( '+', rest ) ->
            ( False, rest )

        _ ->
            ( False, text )


{-| Whole digits (without thousands separators) and fraction digits. `grouping`
is the character that the language groups thousands with, if it is a comma or a
point.
-}
splitNumber : Maybe Char -> String -> Maybe ( String, String )
splitNumber grouping body =
    let
        separators =
            String.toList body |> List.filter isSeparator
    in
    case List.reverse separators of
        [] ->
            Just ( body, "" )

        lastSeparator :: earlier ->
            case uniqueChars earlier of
                [] ->
                    -- One separator: the decimal separator, unless it is the
                    -- thousands separator of the language and the digits are
                    -- grouped by three (`1,234` in English, but not `0,500`,
                    -- which is a decimal comma by any language).
                    if grouping == Just lastSeparator && wellGrouped lastSeparator body && not (String.startsWith "0" body) then
                        Just ( String.filter (\c -> c /= lastSeparator) body, "" )

                    else
                        Just (splitAtLast lastSeparator body)

                [ thousands ] ->
                    if thousands /= lastSeparator then
                        let
                            ( whole, fraction ) =
                                splitAtLast lastSeparator body
                        in
                        if wellGrouped thousands whole then
                            Just ( String.filter (\c -> c /= thousands) whole, fraction )

                        else
                            Nothing

                    else if wellGrouped thousands body then
                        Just ( String.filter (\c -> c /= thousands) body, "" )

                    else
                        Nothing

                _ ->
                    Nothing


splitAtLast : Char -> String -> ( String, String )
splitAtLast separator text =
    case List.reverse (String.split (String.fromChar separator) text) of
        fraction :: wholeParts ->
            ( String.join (String.fromChar separator) (List.reverse wholeParts), fraction )

        [] ->
            ( text, "" )


{-| `1.234.567`: one to three digits, then groups of exactly three.
-}
wellGrouped : Char -> String -> Bool
wellGrouped separator text =
    case String.split (String.fromChar separator) text of
        first :: rest ->
            String.length first
                >= 1
                && String.length first
                <= 3
                && List.all (\group -> String.length group == 3) rest

        [] ->
            False


uniqueChars : List Char -> List Char
uniqueChars chars =
    List.foldl
        (\c seen ->
            if List.member c seen then
                seen

            else
                seen ++ [ c ]
        )
        []
        chars


toNumber : ( String, String ) -> Maybe Float
toNumber ( whole, fraction ) =
    if whole == "" && fraction == "" then
        Nothing

    else if not (String.all Char.isDigit whole && String.all Char.isDigit fraction) then
        Nothing

    else
        String.toFloat
            ((if whole == "" then
                "0"

              else
                whole
             )
                ++ (if fraction == "" then
                        ""

                    else
                        "." ++ fraction
                   )
            )
