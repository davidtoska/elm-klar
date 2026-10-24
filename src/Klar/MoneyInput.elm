module Klar.MoneyInput exposing
    ( view, Attribute
    , State, Msg, init, update
    , value, text, problem, setValue, currencyOf, setCurrency, setLimits, clear, touch, isValid, isTouched
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , min, max, allowNegative
    , alignRight, placeholder, size
    , disabled, readOnly, name
    , locale
    )

{-| A field for an amount of money in one currency. It keeps the text the user
types ("1 234,5", "1,234.50", "kr 100") and reads it into an exact
[Klar.Money](Klar-Money), so it is stateful.

Use when: the user types an amount of money in one currency and the application needs it as an exact `Klar.Money`.
Do not use when: the number is not money (`Klar.NumberInput`) or an amount is only shown (`Klar.Money`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.Money as Money
    import Klar.MoneyInput as MoneyInput

    type alias Model =
        { price : MoneyInput.State }

    init : Model
    init =
        { price = MoneyInput.init "line-price" Money.nok }

    -- update
    PriceMsg inner ->
        let
            ( price, cmd ) =
                MoneyInput.update inner model.price
        in
        ( { model | price = price }, Cmd.map PriceMsg cmd )

    -- view
    MoneyInput.view PriceMsg
        [ MoneyInput.label "Unit price"
        , MoneyInput.min (Money.zero Money.nok)
        , MoneyInput.required
        ]
        model.price

    -- read the amount
    MoneyInput.value model.price -- Maybe Money

The first `String` given to `init` is the DOM id of the input, so there is no `id`
attribute. The second is the currency, which is a required argument and not an
attribute: an amount without a currency means nothing. The application reads the
amount with `value`, reacts to changes by comparing `value` before and after
`update`, and uses `isTouched` to show its own errors only after the user has been
in the field once. `text` is what the field shows, and `problem` the message it
shows, for an error summary of your own.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and `optionalText`
are the common field attributes. They come with the field wrapper
([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they mean the same
in all of them. The field is always inside the wrapper, so it does not move when an
error comes and goes.

**The currency is always in view.** The code of the currency (`NOK`) stands at the
end of the field, so the person typing always sees which currency is meant, and a
screen reader reads it as the description of the field.

**Typing.** The field reads the text like `Money.parse` does, in the language of
the field (`locale`). `.` and `,` both work as the decimal separator, `1 234,50` and
`1,234.50` are both 1234.50, and the text may come with the currency (`NOK 1 234`,
`1 234,50 kr`), a minus sign or parentheses for a negative amount (`(100)`), and the
Norwegian `1 234,-`. In English `1,234` is 1234 and in Norwegian it is 1.234. In
Norwegian `10.000` is refused as unclear, not read as ten: many people write ten
thousand that way. What is typed is kept as typed while the field has the focus.

**What the field shows.** When the user leaves the field (or presses Enter) the
amount is written with the grouping and the separators of the language and exactly the
decimals of the currency: `1 234,50` for NOK in Norwegian, `1,500` for JPY, `1,234.567`
for KWD. A negative amount begins with the minus sign of the keyboard, so that the
text can be copied into a spreadsheet.

**Nothing is rounded for you.** An amount with more decimals than the currency has
(`12.505` NOK) is kept as typed, shows the error "NOK has 2 decimals" at once, and
`value` is `Nothing` until it is fixed: only the person who typed it knows whether it
should be 12.50 or 12.51. For the same reason `1,234` in a field for a currency with
three decimals (KWD) in English is refused as unclear, not guessed.

**Limits and negative amounts.** `min` and `max` take amounts. An amount outside them
is never moved into the range: it stays as typed, shows "Must be between 10.00 and
5,000.00 NOK" once the field is left, and `isValid` is `False` from the first
keystroke. A negative amount is refused unless the field has `allowNegative`, since
most amounts are not negative. A limit in another currency is a mistake in the
program; the field shows that, and is invalid, instead of ignoring the limit.

`isValid` knows the limits from the attributes of the view, which the field learns
when the user focuses, types in or leaves it. An amount that you put in with
`setValue` before that, such as one loaded from a server, needs `setLimits` once, with
the same attributes you give to `view`. `problem` takes the attributes itself, so it
always judges by the limits you give it.

**What the user types wins.** While the user is typing in the field, `setValue`
leaves the field alone, so an amount that is loaded again (a poll, a push from the
server) does not overwrite a half-typed one; the application learns the result by
comparing `value` before and after `update`.

**A percentage, a weight, a count.** The field is for money. A number with a unit
(`kg`, `pcs`, `%`) is a [NumberInput](Klar-NumberInput) with `suffixText`.

**Keyboard and accessibility.** Enter formats the amount and still lets a
surrounding form submit; the Enter that ends an IME composition only picks the
characters. The input is a text field with a numeric keyboard hint
(`inputmode="decimal"`, or `numeric` for a currency without decimals; a field that
`allowNegative` leaves the hint out, because the numeric keypad of a phone has no
minus key). Errors are announced when they appear.

The built-in texts (the errors) and the number format follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# The amount

@docs value, text, problem, setValue, currencyOf, setCurrency, setLimits, clear, touch, isValid, isTouched


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Limits

@docs min, max, allowNegative


# Display

@docs alignRight, placeholder, size


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
import Klar.Internal as Internal
import Klar.Internal.Composition as Composition
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Currency, Money)
import Klar.Money.Currencies as Currencies
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of an amount field: the text being typed, the amount read from it, the
currency and whether the user has been in the field. Make one with `init`, keep it in
your model and give it to `view` and `update`.
-}
type State
    = State Fields


type alias Fields =
    { id : String
    , currency : Currency
    , value : Maybe Money

    -- the text while it is not yet an amount written the way the field writes it:
    -- what the user typed, kept as typed until the field is left
    , draft : Maybe String

    -- why the draft is not an amount
    , problem : Maybe Money.Problem
    , touched : Bool
    , focused : Bool

    -- what the field last saw in the attributes of the view (or was told by
    -- `setLimits`), so that `isValid` is right while the user is still typing;
    -- `Nothing` until it has seen them: then it does not judge the amount by
    -- rules it does not know
    , rules : Maybe Rules
    }


{-| The attributes of the view that matter to what is typed: the language it is read
in, the limits and whether it may be negative. Every message of the view brings them.
-}
type alias Rules =
    { locale : Locale
    , min : Maybe Money
    , max : Maybe Money
    , negative : Bool
    }


noRules : Rules
noRules =
    { locale = Locale.default, min = Nothing, max = Nothing, negative = False }


{-| The rules the field has seen, or the plain ones (English, no limits, no negative
amounts) for the little it needs them for before it has seen any.
-}
rulesOf : Fields -> Rules
rulesOf state =
    Maybe.withDefault noRules state.rules


{-| An empty field for amounts in a currency. The `String` is the DOM id of the
input; it must be unique on the page, because the label, hint and error point at it.
To start with an amount, use `setValue`.

    MoneyInput.init "line-price" Money.nok

-}
init : String -> Currency -> State
init id cur =
    State
        { id = id
        , currency = cur
        , value = Nothing
        , draft = Nothing
        , problem = Nothing
        , touched = False
        , focused = False
        , rules = Nothing
        }


{-| The amount in the field, or `Nothing` when the field is empty or the text is not
an amount in the currency of the field (it has too many decimals, for instance). An
amount outside `min` and `max`, or a negative one that is not allowed, is returned as
it was typed; `isValid` tells whether it is acceptable.
-}
value : State -> Maybe Money
value (State state) =
    state.value


{-| The text in the field, as the field shows it in this language: what the user is
typing, text that is not an amount (kept as typed), or the amount written with the
grouping and the decimals of the language (`1 234,50` in Norwegian). `""` for an
empty field. Together with `value` it tells an empty field from one with text that
is not an amount.

    MoneyInput.text Locale.nb model.price -- "1 234,50"

-}
text : Locale -> State -> String
text lang current =
    displayText lang current


{-| The message the field shows under itself about what is in it, in the language of
the attributes, or `Nothing`: "NOK has 2 decimals", "Must be between 10.00 and
5,000.00 NOK". It is judged by the limits in the attributes you pass, which are the
ones you give to `view`, and it follows the same timing as the field: the start of an
amount (`-`, `1,`) has no message while the user is typing it. Your own `error` is not
part of it. For an error summary of your own:

    MoneyInput.problem priceAttributes model.price

-}
problem : List (Attribute msg) -> State -> Maybe String
problem attributes current =
    builtInError (configure attributes) current


{-| The currency of the field.
-}
currencyOf : State -> Currency
currencyOf (State state) =
    state.currency


{-| Shows an amount, or an empty field for `Nothing`. The field takes the currency of
the amount (a field for NOK that is given an amount in EUR shows EUR, which is hard to
miss); `Nothing` keeps the currency. The amount is not moved into `min` and `max`:
`isValid` tells whether it is inside the limits the field knows (see `setLimits`).

While the user is typing in the field (it has the focus and text they typed), it
changes nothing: what they type wins over an amount loaded again from the server, and
the application learns the result by comparing `value` before and after `update`.
-}
setValue : Maybe Money -> State -> State
setValue maybe (State state) =
    if state.focused && state.draft /= Nothing then
        State state

    else
        case maybe of
            Just money ->
                State { state | currency = Money.currencyOf money, value = Just money, draft = Nothing, problem = Nothing }

            Nothing ->
                State { state | value = Nothing, draft = Nothing, problem = Nothing }


{-| Changes the currency of the field, for example when the user chooses another one
from a list next to it. The number stays and is read again in the new currency: 100.50
in a field for NOK becomes 100.50 in a field for USD. In a currency with fewer
decimals (JPY) it would have to be rounded, and it is not: the text stays as it is and
the field says "JPY has no decimals". The text is read in the language the field last
saw in its attributes (from a message of the view, or from `setLimits`).
-}
setCurrency : Currency -> State -> State
setCurrency cur (State state) =
    if cur == state.currency then
        State state

    else
        case ( state.draft, state.value ) of
            ( Just raw, _ ) ->
                State (readDraft (rulesOf state).locale { state | currency = cur } raw)

            ( Nothing, Just money ) ->
                case Money.fromDecimalString cur (Money.toDecimalString money) of
                    Ok moved ->
                        State { state | currency = cur, value = Just moved, problem = Nothing }

                    Err _ ->
                        State (readDraft (rulesOf state).locale { state | currency = cur } (writtenAmount (rulesOf state).locale money))

            ( Nothing, Nothing ) ->
                State { state | currency = cur }


{-| Tells the state the limits in the given attributes (`min`, `max` and
`allowNegative`) and their language, so that `isValid` and `setCurrency` know them
before the user has touched the field. Pass the list you give to `view`; the other
attributes in it are ignored. The amount is never changed.

A field learns its limits by itself when the user focuses, types in or leaves it. This
is for an amount that you put in with `setValue` before that, such as one loaded from
a server, and for limits that change while the field is on the screen. Until the field
has learned its limits, in one way or the other, `isValid` does not judge the amount by
them: a credit note that you load into a field that has `allowNegative` is never
reported invalid because the field has not heard of `allowNegative` yet. It is not
reported invalid for a limit it does not know either, so give a loaded amount its
`setLimits` to have it checked.

    price : List (MoneyInput.Attribute Msg)
    price =
        [ MoneyInput.label "Price", MoneyInput.min (Money.zero Money.nok) ]

    MoneyInput.init "line-price" Money.nok
        |> MoneyInput.setLimits price
        |> MoneyInput.setValue (Money.fromMinor Money.nok -500)
        |> MoneyInput.isValid
    --> False

    -- and with allowNegative among the attributes, a credit note is fine
    MoneyInput.init "line-credit" Money.nok
        |> MoneyInput.setLimits [ MoneyInput.allowNegative ]
        |> MoneyInput.setValue (Money.fromMinor Money.nok -500)
        |> MoneyInput.isValid
    --> True

-}
setLimits : List (Attribute msg) -> State -> State
setLimits attributes (State state) =
    let
        config =
            configure attributes
    in
    State { state | rules = Just { locale = config.locale, min = config.min, max = config.max, negative = config.negative } }


{-| Empties the field and forgets that the user has been in it (`isTouched` is
`False` again), for example for a "Clear form" button. The currency stays.
-}
clear : State -> State
clear (State state) =
    State { state | value = Nothing, draft = Nothing, problem = Nothing, touched = False }


{-| Counts the field as visited, as if the user had been in it and left. Use it when
the application wants to show the errors of all fields at once, such as after a
failed attempt to submit.
-}
touch : State -> State
touch (State state) =
    State { state | touched = True }


{-| `True` when the field is empty or holds an amount that is acceptable, and `False`
when the text is not an amount in the currency, the amount is negative where that is
not allowed, or it is outside `min` and `max`. It answers at once, also while the user
is still typing, although the field's own messages wait until the field is left. An
amount outside the limits is never moved into them, so the application decides what
to do.

An empty field counts as valid: for an amount that is required, also check `value`
for `Nothing`.

The field judges the amount by the limits it knows: the attributes it saw in a message of
the view, or the ones of `setLimits`. An amount that was put in with `setValue` and has
not been given limits is only checked for being an amount.

-}
isValid : State -> Bool
isValid (State state) =
    case state.rules of
        Nothing ->
            state.problem == Nothing

        Just rules ->
            state.problem == Nothing && limitProblem state.currency rules state.value == Nothing


{-| `True` once the user has left the field or pressed Enter in it, or `touch` was
used. Use it to show errors of your own only after the first visit. `clear` makes it
`False` again.
-}
isTouched : State -> Bool
isTouched (State state) =
    state.touched



-- UPDATE


{-| The messages an amount field sends: typing, focus and leaving the field. `view`
wraps them with the function you give it; hand them to `update` when they come back.
-}
type Msg
    = Typed Rules String
    | Focused Rules
    | Committed Rules
    | Entered Rules


{-| Moves the field on after one of its messages. There is never anything to do for
the runtime, so the `Cmd` is always `Cmd.none`; it is there so that the field is wired
like the others (`Cmd.map`).
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Typed rules raw ->
            ( State (withDraft rules state raw), Cmd.none )

        Focused rules ->
            ( State { state | focused = True, rules = Just rules }, Cmd.none )

        Committed rules ->
            -- the field was left
            ( State (commit rules { state | focused = False }), Cmd.none )

        Entered rules ->
            -- Enter: write the amount, but the cursor stays
            ( State (commit rules state), Cmd.none )


{-| The text as typed: read into an amount, or into the reason it is not one. A blank
text is no amount and no problem.
-}
withDraft : Rules -> Fields -> String -> Fields
withDraft rules state raw =
    readDraft rules.locale { state | rules = Just rules } raw


{-| Reads a text in a language and keeps it as the text of the field.
-}
readDraft : Locale -> Fields -> String -> Fields
readDraft lang state raw =
    if String.trim raw == "" then
        { state | draft = Just raw, value = Nothing, problem = Nothing }

    else
        case Money.parse lang state.currency raw of
            Ok money ->
                { state | draft = Just raw, value = Just money, problem = Nothing }

            Err refusal ->
                { state | draft = Just raw, value = Nothing, problem = Just refusal }


{-| The field was left (or Enter was pressed): the text becomes a written amount.
Text that is not an amount stays as it is, with its error. An amount outside `min` and
`max` is written, and stays outside them.
-}
commit : Rules -> Fields -> Fields
commit rules state =
    let
        seen =
            { state | touched = True, rules = Just rules }
    in
    case state.draft of
        Nothing ->
            seen

        Just raw ->
            if String.trim raw == "" then
                { seen | draft = Nothing, value = Nothing, problem = Nothing }

            else
                case Money.parse rules.locale state.currency raw of
                    Ok money ->
                        { seen | draft = Nothing, value = Just money, problem = Nothing }

                    Err refusal ->
                        { seen | value = Nothing, problem = Just refusal }


{-| The amount as the field writes it for editing: the grouping and decimals of the
language, with the minus sign of the keyboard.
-}
writtenAmount : Locale -> Money -> String
writtenAmount lang money =
    String.replace "−" "-" (Money.toAmountString lang money)


{-| The limits and the sign: what is wrong with an amount that was read, or `Nothing`.
-}
limitProblem : Currency -> Rules -> Maybe Money -> Maybe Limit
limitProblem cur rules maybeMoney =
    case maybeMoney of
        Nothing ->
            Nothing

        Just money ->
            if Money.isNegative money && not rules.negative then
                Just IsNegative

            else
                case List.filterMap (wrongCurrency cur) [ rules.min, rules.max ] of
                    wrong :: _ ->
                        Just (LimitInOtherCurrency wrong)

                    [] ->
                        if isBelow rules.min money || isAbove rules.max money then
                            Just OutOfLimits

                        else
                            Nothing


type Limit
    = IsNegative
    | LimitInOtherCurrency Currency
    | OutOfLimits


wrongCurrency : Currency -> Maybe Money -> Maybe Currency
wrongCurrency cur limit =
    case limit of
        Just bound ->
            if Money.currencyOf bound /= cur then
                Just (Money.currencyOf bound)

            else
                Nothing

        Nothing ->
            Nothing


isBelow : Maybe Money -> Money -> Bool
isBelow low money =
    Maybe.map (\bound -> Money.compare money bound == LT) low |> Maybe.withDefault False


isAbove : Maybe Money -> Money -> Bool
isAbove high money =
    Maybe.map (\bound -> Money.compare money bound == GT) high |> Maybe.withDefault False



-- ATTRIBUTES


{-| A setting of an amount field. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , placeholder : Maybe String
    , min : Maybe Money
    , max : Maybe Money
    , negative : Bool
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
        , placeholder = Nothing
        , min = Nothing
        , max = Nothing
        , negative = False
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
label textOfLabel =
    updateField (Field.setLabel textOfLabel)


{-| Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| Help text shown under the field, for example what the amount is for. Screen
readers read it together with the label (`aria-describedby`).
-}
hint : String -> Attribute msg
hint textOfHint =
    updateField (Field.setHint textOfHint)


{-| Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. The field's own messages, for text
that is not an amount and for an amount outside the limits, replace this one until
they are fixed, so it is the place for rules of your own, such as a business rule or a
message from the server.
-}
error : String -> Attribute msg
error textOfError =
    updateField (Field.setError (Just textOfError))


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
optionalText textOfOptional =
    updateField (Field.setOptionalText textOfOptional)


{-| Text shown inside the empty field. Without it the field shows a zero with the
decimals of the currency (`0,00` for NOK in Norwegian, `0.000` for KWD in English),
which tells how the amount is written. It is not a substitute for a `label`, and it
disappears as soon as the user types.
-}
placeholder : String -> Attribute msg
placeholder textOfPlaceholder =
    Attribute (\config -> { config | placeholder = Just textOfPlaceholder })


{-| The smallest allowed amount. An amount below it is kept as it is typed: the field
shows the built-in error ("Must be at least 10.00 NOK" or "Must be between ...") and
`isValid` is `False` until it is fixed. Default: no lower limit. The amount must be in
the currency of the field.

    MoneyInput.min (Money.zero Money.nok)

-}
min : Money -> Attribute msg
min money =
    Attribute (\config -> { config | min = Just money })


{-| The largest allowed amount, in the same way as `min`: a larger amount that is typed
is kept, shown with the built-in error and reported by `isValid`. Default: no upper
limit.

    -- the credit limit of the customer, a Money that came with the record
    MoneyInput.max customer.creditLimit

-}
max : Money -> Attribute msg
max money =
    Attribute (\config -> { config | max = Just money })


{-| Allows a negative amount (a credit note, a discount, a correction). Without it a
negative amount is kept as typed, shown with the error "Must not be negative", and
`isValid` is `False`.
-}
allowNegative : Attribute msg
allowNegative =
    Attribute (\config -> { config | negative = True })


{-| Aligns the amount to the right, for columns of amounts. Default: left.
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
(40px), from [Klar.Theme](Klar-Theme). Default `Medium`.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| The HTML `name` of the input. A native form sends the text under this name.
Default: none.
-}
name : String -> Attribute msg
name value_ =
    Attribute (\config -> { config | name = Just value_ })


{-| The language of the built-in texts and of the number format: the error messages,
the separators the amount is written with (`1,234.50` in English, `1 234,50` in
Norwegian) and the way what the user types is read (see `Money.parse`). Default
`Locale.default`, which is English. Texts you pass in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| An amount field with its label, hint and error message. The first argument wraps
the field's own messages in one of yours, and the state comes last.

    MoneyInput.view PriceMsg
        [ MoneyInput.label "Unit price"
        , MoneyInput.min (Money.zero Money.nok)
        ]
        model.price

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes ((State state) as current) =
    let
        config =
            configure attributes

        rules =
            { locale = config.locale, min = config.min, max = config.max, negative = config.negative }

        -- Built-in errors win over the application's own until they are fixed.
        field =
            config.field
                |> Field.setId state.id
                |> Field.setError
                    (case builtInError config current of
                        Just message ->
                            Just message

                        Nothing ->
                            config.field.error
                    )

        inactive =
            config.disabled || config.readOnly

        currencyId =
            state.id ++ "-currency"

        describedBy =
            currencyId
                :: List.filterMap identity
                    [ Maybe.map (\_ -> Field.hintId field) field.hint
                    , Maybe.map (\_ -> state.id ++ "-error") field.error
                    ]
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-input"
                , "klar-input--" ++ Internal.sizeSuffix config.size
                , "klar-money"
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
                [ Attr.id state.id
                , Attr.attribute "aria-describedby" (String.join " " describedBy)
                , Internal.attrIf (field.error /= Nothing) (Attr.attribute "aria-invalid" "true")
                , Internal.attrIf field.required (Attr.attribute "aria-required" "true")
                , Internal.cls
                    [ "klar-input__control"
                    , "klar-money__control"
                    , if config.alignRight then
                        "klar-money__control--end"

                      else
                        ""
                    ]
                , Attr.type_ "text"
                , Internal.attrMaybe (Attr.attribute "inputmode") (keyboard config.negative state.currency)
                , Attr.attribute "autocomplete" "off"
                , Attr.attribute "spellcheck" "false"
                , Attr.value (displayText config.locale current)
                , Attr.placeholder (placeholderText config state.currency)
                , Attr.disabled config.disabled
                , Attr.readonly config.readOnly
                , Internal.attrMaybe Attr.name config.name
                , Events.onInput (\typed -> toMsg (Typed rules typed))
                , Events.onFocus (toMsg (Focused rules))
                , Events.onBlur (toMsg (Committed rules))
                , Internal.attrIf (not inactive) (Events.preventDefaultOn "keydown" (enterDecoder (toMsg (Entered rules))))
                ]
                []
            , Html.span
                [ Internal.cls [ "klar-input__adornment", "klar-input__adornment--text", "klar-money__currency" ]
                , Attr.id currencyId
                ]
                [ Html.text (Money.currencyCode state.currency) ]
            ]
        )


{-| The on-screen keyboard of a phone: the decimal pad, or the numeric pad for a
currency without decimals. Neither has a minus key, so a field that allows negative
amounts leaves the choice to the phone.
-}
keyboard : Bool -> Currency -> Maybe String
keyboard negative cur =
    if negative then
        Nothing

    else if Money.decimals cur == 0 then
        Just "numeric"

    else
        Just "decimal"


placeholderText : Config -> Currency -> String
placeholderText config cur =
    case config.placeholder of
        Just own ->
            own

        Nothing ->
            Money.toAmountString config.locale (Money.zero cur)


displayText : Locale -> State -> String
displayText lang (State state) =
    case state.draft of
        Just raw ->
            raw

        Nothing ->
            case state.value of
                Just money ->
                    writtenAmount lang money

                Nothing ->
                    ""


{-| Enter writes the amount, and is not cancelled: a surrounding form still submits.
The Enter that ends an IME composition is left to the input method.
-}
enterDecoder : msg -> Decode.Decoder ( msg, Bool )
enterDecoder msg =
    Composition.unlessComposing Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.key == "Enter" && not (event.ctrl || event.meta || event.alt) then
                    Decode.succeed ( msg, False )

                else
                    Decode.fail "unhandled key"
            )



-- BUILT-IN ERRORS


{-| The message of the field itself, or `Nothing`. The messages that no more typing
can fix (more decimals than the currency has, a letter) show at once; the others wait
until the field is left, because `-` or `1,` may be the start of an amount.
-}
builtInError : Config -> State -> Maybe String
builtInError config (State state) =
    let
        typing =
            state.focused && state.draft /= Nothing
    in
    case state.problem of
        Just refusal ->
            let
                raw =
                    Maybe.withDefault "" state.draft
            in
            if not state.focused || hasTooManyDecimals config.locale state.currency raw || hasForeignCharacters state.currency raw then
                Just (Money.problemText config.locale refusal)

            else
                Nothing

        Nothing ->
            if typing then
                Nothing

            else
                limitProblem state.currency { locale = config.locale, min = config.min, max = config.max, negative = config.negative } state.value
                    |> Maybe.map (limitText config state.currency)


{-| A problem that more typing cannot fix: the text is an amount, but with more
decimals than the currency has. (Text that `parse` refuses and `parseRounded` accepts
is exactly that.)
-}
hasTooManyDecimals : Locale -> Currency -> String -> Bool
hasTooManyDecimals lang cur raw =
    Result.toMaybe (Money.parseRounded lang cur raw) /= Nothing


{-| Letters and other characters that no amount is written with, apart from the ones
in the marks that `Money.parse` takes away around an amount of this currency (its code,
its symbol and the other ways it is written): someone may be typing `NOK 100`, `RMB 100`
or `Mex$ 100`. It is the same list that reading uses, so the two cannot disagree.
-}
hasForeignCharacters : Currency -> String -> Bool
hasForeignCharacters cur raw =
    let
        written =
            String.toLower (String.concat (Currencies.marks (Money.currencyCode cur)))
    in
    raw
        |> String.filter (\c -> not (c == ' ' || c == '\u{00A0}' || c == '\u{202F}' || c == '\u{2009}' || c == '\t' || c == '\'' || c == '’'))
        |> String.toLower
        |> String.any
            (\c ->
                not
                    (Char.isDigit c
                        || String.contains (String.fromChar c) ",.-+−–()"
                        || String.contains (String.fromChar c) written
                    )
            )


limitText : Config -> Currency -> Limit -> String
limitText config cur limit =
    let
        code =
            Money.currencyCode cur

        pick nb en =
            Locale.pick config.locale { nb = nb, en = en }

        shown money =
            Money.toAmountString config.locale money

        unit =
            "\u{00A0}" ++ code
    in
    case limit of
        IsNegative ->
            pick "Beløpet kan ikke være negativt" "Must not be negative"

        LimitInOtherCurrency other ->
            pick
                ("Grensen er i " ++ Money.currencyCode other ++ ", men feltet gjelder " ++ code)
                ("The limit is in " ++ Money.currencyCode other ++ ", but the field is for " ++ code)

        OutOfLimits ->
            case ( config.min, config.max ) of
                ( Just low, Just high ) ->
                    pick
                        ("Må være mellom " ++ shown low ++ " og " ++ shown high ++ unit)
                        ("Must be between " ++ shown low ++ " and " ++ shown high ++ unit)

                ( Just low, Nothing ) ->
                    pick
                        ("Må være minst " ++ shown low ++ unit)
                        ("Must be at least " ++ shown low ++ unit)

                ( Nothing, Just high ) ->
                    pick
                        ("Må være maksimalt " ++ shown high ++ unit)
                        ("Must be at most " ++ shown high ++ unit)

                ( Nothing, Nothing ) ->
                    ""
