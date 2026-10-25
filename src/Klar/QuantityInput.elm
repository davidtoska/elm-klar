module Klar.QuantityInput exposing
    ( view
    , Unit, unit
    , State, Msg, init, update, raw, selected, setValue, setUnit, touch, reset, value
    , Limits, between, atLeast, atMost
    , Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText, limits, placeholder, disabled, readOnly, name, locale
    )

{-| A quantity with an application's own unit type, keeping exactly the number
text entered until the application explicitly changes it.

Use when: a number must be entered together with a unit such as kg, m or percent.
Do not use when: the unit is fixed, use `Klar.NumberInput.suffixText`, or for currency use `Klar.MoneyInput`.
Quick path: `unit`, `init`, `setUnit`, `update`, `view`, `value`

    import Klar.QuantityInput as Quantity

    -- in the model: quantity : Quantity.State
    -- initial value: Quantity.init "order-weight" |> Quantity.setUnit unitIds Kilograms
    -- in update:
    QuantityMsg inner ->
        let
            ( quantity, cmd ) =
                Quantity.update inner model.quantity
        in
        ( { model | quantity = quantity }, Cmd.map QuantityMsg cmd )

    -- use the same attributes and catalogue when drawing and reading:
    Quantity.view QuantityMsg attributes catalogue model.quantity

    Quantity.value attributes catalogue model.quantity
    -- Result String (Maybe { amount : Float, unit : UnitId })

`catalogue` is `{ ids = unitIds, units = [ Quantity.unit Kilograms "Kilograms" "kg", ... ] }`.
The unit select is native: keyboard arrows, typeahead and platform accessibility
are supplied by the browser. A change of unit changes only the unit, never the
number text. The application decides whether and how to convert a measurement;
there is no implicit factor, percent scaling or dimension conversion.

`value` validates with the current attributes and catalogue, so a language change,
a new limit or a removed unit cannot leave a previously valid cached value behind.
It returns `Ok Nothing` for a blank optional quantity, a complete typed quantity
for valid input, and a localized `Err` for incomplete, invalid, out-of-range or
unavailable-unit input. A trailing decimal separator is incomplete, not silently
accepted as a whole number. Numeric parsing otherwise follows `Klar.NumberInput.parseIn`.
The number is a finite Float; use `Klar.MoneyInput` for exact currency arithmetic.

Validation is shown after blur or `touch`; `value` is strict immediately, also
before the first blur. Built-in errors are delayed during IME composition, and composing
text is never returned as a valid quantity. No blur rounding, formatting, stepping
or range clamping is performed. Limits describe the numeric amount in the selected
unit; supply different attributes when different units have different bounds.

@docs view


# Units

@docs Unit, unit


# State and values

@docs State, Msg, init, update, raw, selected, setValue, setUnit, touch, reset, value


# Valid limits

@docs Limits, between, atLeast, atMost


# Attributes

@docs Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText, limits, placeholder, disabled, readOnly, name, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.NumberInput as NumberInput


{-| A unit with your own id, a human label and a compact symbol. Ids must be unique.
-}
type Unit id
    = Unit { id : id, label : String, symbol : String }


{-| Creates an option, for example `unit Kilograms "Kilograms" "kg"`. Percent is
an ordinary unit: an entered 25 means `{ amount = 25, unit = Percent }`, not 0.25.
-}
unit : id -> String -> String -> Unit id
unit id label_ symbol =
    Unit { id = id, label = label_, symbol = symbol }


{-| Exact raw text, a unit key and interaction state; never contains functions.
-}
type State
    = State { id : String, raw : String, unit : Maybe String, touched : Bool, composing : Bool }


{-| Creates a blank quantity without choosing a unit. The string is a unique DOM id.
-}
init : String -> State
init id =
    State { id = id, raw = "", unit = Nothing, touched = False, composing = False }


{-| Internal editing messages; pass them to `update`.
-}
type Msg
    = Typed String
    | UnitPicked String
    | Blurred
    | CompositionStarted
    | CompositionFinished String


{-| Keeps text and unit changes exactly as entered. Never converts or reformats.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    ( State
        (case msg of
            Typed text ->
                { state | raw = text }

            UnitPicked key ->
                { state
                    | unit =
                        if key == "" then
                            Nothing

                        else
                            Just (String.dropLeft 5 key)
                }

            Blurred ->
                { state | touched = True }

            CompositionStarted ->
                { state | composing = True }

            CompositionFinished text ->
                { state | composing = False, raw = text }
        )
    , Cmd.none
    )


{-| Exact number text, including invalid or incomplete input.
-}
raw : State -> String
raw (State state) =
    state.raw


{-| The selected application's unit id, if its key decodes. Use `value` to check
that the unit still exists in the current catalogue.
-}
selected : Ids id -> State -> Maybe id
selected ids (State state) =
    state.unit |> Maybe.andThen (Ids.fromKey ids)


{-| Explicitly replaces raw number text without changing its unit or formatting it.
-}
setValue : String -> State -> State
setValue text (State state) =
    State { state | raw = text, composing = False }


{-| Explicitly selects a unit without converting or changing the number text.
-}
setUnit : Ids id -> id -> State -> State
setUnit ids id (State state) =
    State { state | unit = Just (Ids.toKey ids id) }


{-| Shows current validation, for example after an attempted submit.
-}
touch : State -> State
touch (State state) =
    State { state | touched = True }


{-| Clears number text, unit and touched state, preserving the DOM id.
-}
reset : State -> State
reset (State state) =
    init state.id


{-| A valid finite numeric interval. Construct one with `between`, `atLeast` or `atMost`.
-}
type Limits
    = Limits { minimum : Maybe Float, maximum : Maybe Float }


finite : Float -> Bool
finite number =
    not (isNaN number || isInfinite number)


{-| Inclusive finite bounds. Returns `Nothing` for reversed bounds or NaN/infinity.
-}
between : Float -> Float -> Maybe Limits
between low high =
    if finite low && finite high && low <= high then
        Just (Limits { minimum = Just low, maximum = Just high })

    else
        Nothing


{-| An inclusive lower bound. Returns `Nothing` for NaN or infinity.
-}
atLeast : Float -> Maybe Limits
atLeast low =
    if finite low then
        Just (Limits { minimum = Just low, maximum = Nothing })

    else
        Nothing


{-| An inclusive upper bound. Returns `Nothing` for NaN or infinity.
-}
atMost : Float -> Maybe Limits
atMost high =
    if finite high then
        Just (Limits { minimum = Nothing, maximum = Just high })

    else
        Nothing


{-| Display and validation settings. Later attributes win; no limits by default.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config, limits : Maybe Limits, placeholder : String, disabled : Bool, readOnly : Bool, name : Maybe String, locale : Locale }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) acc -> change acc)
        { field = Field.empty, limits = Nothing, placeholder = "", disabled = False, readOnly = False, name = Nothing, locale = Locale.default }
        attributes


fieldAttribute : (Field.Config -> Field.Config) -> Attribute msg
fieldAttribute change =
    Attribute (\c -> { c | field = change c.field })


{-| The field label. Defaults to the localized word "Quantity".
-}
label : String -> Attribute msg
label text =
    fieldAttribute (Field.setLabel text)


{-| Hides the label visually while retaining its accessible name.
-}
labelHidden : Attribute msg
labelHidden =
    fieldAttribute Field.setLabelHidden


{-| Help text shared by the number input and the unit select. None by default.
-}
hint : String -> Attribute msg
hint text =
    fieldAttribute (Field.setHint text)


{-| An application error, also rejected by `value`. None by default.
-}
error : String -> Attribute msg
error text =
    errorMaybe (Just text)


{-| Sets or clears an application error. `value` rejects it immediately; it is
shown without waiting for blur. Built-in validation takes precedence when touched.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    fieldAttribute (Field.setError maybe)


{-| Requires both a number and a unit. Optional by default.
-}
required : Attribute msg
required =
    fieldAttribute (Field.setRequired True)


{-| Text after an optional label, for example "(optional)". None by default.
-}
optionalText : String -> Attribute msg
optionalText text =
    fieldAttribute (Field.setOptionalText text)


{-| Numeric limits, interpreted in the selected unit. No limits by default.
-}
limits : Limits -> Attribute msg
limits bounds =
    Attribute (\c -> { c | limits = Just bounds })


{-| Number input placeholder. Empty by default.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\c -> { c | placeholder = text })


{-| Disables both controls. Defaults to `False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\c -> { c | disabled = value_ })


{-| Makes the number read only and disables changing the unit. Defaults to `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value_ =
    Attribute (\c -> { c | readOnly = value_ })


{-| Native form field name for the raw number; the unit uses `<name>-unit`.
Neither name is set by default. Application submission should use `value`.
-}
name : String -> Attribute msg
name text =
    Attribute (\c -> { c | name = Just text })


{-| Numeric parsing and built-in error language. Defaults to English.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\c -> { c | locale = value_ })


{-| Reads and validates using the current settings and unit catalogue. Returns
`Ok Nothing` for a blank optional input, or the complete quantity, or a localized
error. Errors include external `error`, missing units and unfinished composition.
-}
value : List (Attribute msg) -> { ids : Ids id, units : List (Unit id) } -> State -> Result String (Maybe { amount : Float, unit : id })
value attributes catalogue state =
    validate (configure attributes) catalogue state


validate : Config -> { ids : Ids id, units : List (Unit id) } -> State -> Result String (Maybe { amount : Float, unit : id })
validate c catalogue (State state) =
    let
        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        text =
            String.trim state.raw

        chosen =
            List.filter (\(Unit option) -> Just (Ids.toKey catalogue.ids option.id) == state.unit) catalogue.units |> List.head

        rangeError amount =
            case c.limits of
                Nothing ->
                    Nothing

                Just (Limits bounds) ->
                    let
                        lowBad =
                            Maybe.map (\low -> amount < low) bounds.minimum |> Maybe.withDefault False

                        highBad =
                            Maybe.map (\high -> amount > high) bounds.maximum |> Maybe.withDefault False

                        number =
                            String.fromFloat >> String.replace "." (Locale.decimalSeparator c.locale)
                    in
                    if lowBad || highBad then
                        Just
                            (case ( bounds.minimum, bounds.maximum ) of
                                ( Just low, Just high ) ->
                                    pick ("Must be between " ++ number low ++ " and " ++ number high) ("Må være mellom " ++ number low ++ " og " ++ number high)

                                ( Just low, Nothing ) ->
                                    pick ("Must be at least " ++ number low) ("Må være minst " ++ number low)

                                ( Nothing, Just high ) ->
                                    pick ("Must be at most " ++ number high) ("Må være høyst " ++ number high)

                                _ ->
                                    ""
                            )

                    else
                        Nothing
    in
    if state.composing then
        Err (pick "Finish entering the number" "Skriv ferdig tallet")

    else if text == "" then
        if c.field.required then
            Err (pick "Enter a quantity" "Oppgi en mengde")

        else
            Maybe.map Err c.field.error |> Maybe.withDefault (Ok Nothing)

    else if String.endsWith "." text || String.endsWith "," text then
        Err (pick "Finish entering the number" "Skriv ferdig tallet")

    else
        case NumberInput.parseIn c.locale text of
            Nothing ->
                Err (pick "Must be a number" "Må være et tall")

            Just amount ->
                if not (finite amount) then
                    Err (pick "Must be a finite number" "Må være et endelig tall")

                else
                    case chosen of
                        Nothing ->
                            Err
                                (if state.unit == Nothing then
                                    pick "Choose a unit" "Velg en enhet"

                                 else
                                    pick "The selected unit is unavailable" "Den valgte enheten er utilgjengelig"
                                )

                        Just (Unit option) ->
                            case rangeError amount of
                                Just message ->
                                    Err message

                                Nothing ->
                                    case c.field.error of
                                        Just message ->
                                            Err message

                                        Nothing ->
                                            Ok (Just { amount = amount, unit = option.id })


{-| The field, with a number textbox and a native unit select. Both controls keep
their DOM position while validation changes. Unit ids must be unique in the catalogue.
-}
view : (Msg -> msg) -> List (Attribute msg) -> { ids : Ids id, units : List (Unit id) } -> State -> Html msg
view toMsg attributes catalogue state_ =
    let
        (State state) =
            state_

        c =
            configure attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        problem =
            case validate c catalogue state_ of
                Err message ->
                    if state.touched && not state.composing then
                        Just message

                    else
                        c.field.error

                Ok _ ->
                    c.field.error

        baseField =
            c.field |> Field.setId state.id |> Field.setError problem

        field =
            if baseField.label == Nothing then
                Field.setLabel (pick "Quantity" "Mengde") baseField

            else
                baseField

        known =
            List.any (\(Unit option) -> Just (Ids.toKey catalogue.ids option.id) == state.unit) catalogue.units

        unitName =
            pick "Unit for " "Enhet for " ++ Maybe.withDefault (pick "quantity" "mengde") field.label

        select =
            Html.select
                ([ Attr.id (state.id ++ "-unit"), Internal.cls [ "klar-quantity__unit" ], Attr.attribute "aria-label" unitName, Attr.disabled (c.disabled || c.readOnly), Attr.value (Maybe.map ((++) "unit:") state.unit |> Maybe.withDefault ""), Events.onInput (UnitPicked >> toMsg), Events.onBlur (toMsg Blurred), Internal.attrMaybe (Attr.name << (\text -> text ++ "-unit")) c.name ]
                    ++ Field.describedByAttributes field
                    ++ [ Internal.attrIf (problem /= Nothing) (Attr.attribute "aria-invalid" "true")
                       , Internal.attrIf (field.required || String.trim state.raw /= "") (Attr.attribute "aria-required" "true")
                       ]
                )
                ((if state.unit /= Nothing && not known then
                    [ Html.option [ Attr.value (Maybe.map ((++) "unit:") state.unit |> Maybe.withDefault ""), Attr.disabled True, Attr.selected True ] [ Html.text (pick "Unavailable unit" "Utilgjengelig enhet") ] ]

                  else
                    []
                 )
                    ++ [ Html.option [ Attr.value "", Attr.selected (state.unit == Nothing) ] [ Html.text (pick "Choose unit" "Velg enhet") ] ]
                    ++ List.map
                        (\(Unit option) ->
                            Html.option [ Attr.value ("unit:" ++ Ids.toKey catalogue.ids option.id), Attr.selected (state.unit == Just (Ids.toKey catalogue.ids option.id)) ]
                                [ Html.text
                                    (option.label
                                        ++ (if option.symbol == "" then
                                                ""

                                            else
                                                " (" ++ option.symbol ++ ")"
                                           )
                                    )
                                ]
                        )
                        catalogue.units
                )
    in
    Field.view field
        (Html.div [ Internal.classes [ ( "klar-quantity", True ), ( "klar-quantity--invalid", problem /= Nothing ), ( "klar-quantity--disabled", c.disabled ) ] ]
            [ Html.input
                (Field.controlAttributes field
                    ++ [ Attr.type_ "text"
                       , Attr.attribute "inputmode" "decimal"
                       , Internal.cls [ "klar-quantity__number" ]
                       , Attr.value state.raw
                       , Attr.placeholder c.placeholder
                       , Attr.disabled c.disabled
                       , Attr.readonly c.readOnly
                       , Internal.attrMaybe Attr.name c.name
                       , Events.onInput (Typed >> toMsg)
                       , Events.onBlur (toMsg Blurred)
                       , Events.on "compositionstart" (Decode.succeed (toMsg CompositionStarted))
                       , Events.on "compositionend" (Decode.map (CompositionFinished >> toMsg) (Decode.at [ "target", "value" ] Decode.string))
                       ]
                )
                []
            , select
            ]
        )
