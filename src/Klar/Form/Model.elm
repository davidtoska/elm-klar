module Klar.Form.Model exposing
    ( Form, State, Msg, Field, Ids, Problem, Spec, Builder, View
    , define, with, build, fields, ids
    , text, number, choice, choices, toggle
    , required, atLeast, one, rules, range, whole, hint, withMessage
    , init, set, get, toValues, isDirty, markClean, revert, update
    , problem, rejected, reveal
    , bind, textInput, numberInput, select, multiSelect, switch, summary
    , roundTrip, lostIds
    )

{-| A form declared once: its fields in order, each with a label and its rules.
The declaration gives the application the **handles** of the fields (to put in
the view, to read and set, to tie a server problem to), the **record** the form
produces when it is valid, and everything Klar needs to validate and update it.
The application keeps one [`State`](#State) in its model and one [`Msg`](#Msg)
in its messages, instead of one component state and one message per field.

This is a prototype of the form model (`design/FORM-MODEL.md` in the
repository): it handles text, numbers, one choice, several choices and
switches. Import it as `Fm`.

    import Klar.Form.Model as Fm
    import Klar.Locale as Locale
    import Klar.Validate as Validate

    type alias Fields =
        { name : Fm.Field String
        , country : Fm.Field (Maybe CountryId)
        , categories : Fm.Field (List CategoryId)
        }

    type alias Values =
        { name : String
        , country : CountryId
        , categories : List CategoryId
        }

    form : Fm.Form () Fields Values
    form =
        Fm.define "supplier" Fields Values
            |> Fm.with (Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 80 ])
            |> Fm.with (Fm.choice countryIds "Country" |> Fm.required)
            |> Fm.with (Fm.choices categoryIds "Categories" |> Fm.atLeast 1)
            |> Fm.build

    f : Fields
    f =
        Fm.fields form

    -- model:  { form : Fm.State () }          init: Fm.init form
    -- message: FormMsg Fm.Msg
    -- update:  FormMsg inner -> Fm.update inner model.form |> Tuple.mapBoth ... (Cmd.map FormMsg)
    -- view:
    let
        v =
            Fm.bind Locale.default FormMsg form model.form
    in
    Layout.stack
        [ Fm.textInput v f.name []
        , Fm.select v f.country (Remote.Loaded countries) []
        , Fm.multiSelect v f.categories (Remote.Loaded categories) []
        , Fm.summary v
        ]

Fields and values are filled **by position**, like a decoder pipeline: the
n-th `with` fills the n-th argument of `Fields` and of `Values`. The compiler
refuses a field that is declared but not in the records, and the other way
round; it cannot see two fields of the same type swapped in one of the two
records. Put [`roundTrip`](#roundTrip) in one test to catch that.

Things the compiler refuses (checked, see `design/FORM-MODEL-ERRORS.md`):

  - a field in the pipeline but not in `Fields` or `Values`, and the reverse
  - a field read as another type than it was declared (`Maybe CountryId` against
    `CountryId` when the field is `required`)
  - a text handle given to `select`, a choice handle given to `textInput`
  - a `required` rule on a field that cannot be empty (a switch)


# Types

@docs Form, State, Msg, Field, Ids, Problem, Spec, Builder, View


# Declaring a form

@docs define, with, build, fields, ids


# Kinds of field

@docs text, number, choice, choices, toggle


# Rules

@docs required, atLeast, one, rules, range, whole, hint, withMessage


# Values and state

@docs init, set, get, toValues, isDirty, markClean, revert, update


# Problems from the server

@docs problem, rejected, reveal


# Views

@docs bind, textInput, numberInput, select, multiSelect, switch, summary


# Tests

@docs roundTrip, lostIds

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Form as Form
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Remote as Remote exposing (Remote)
import Klar.Select as Select
import Klar.Switch as Switch
import Klar.TextInput as TextInput
import Klar.Validate as Validate
import Set exposing (Set)



-- TYPES


{-| A form declaration: the fields in order with their rules. It is a constant
(`form`), never part of the model or of a message. The three parameters are the
application's own step type (`()` for a form without steps), the record of
field handles (`Fields`) and the record the form produces (`Values`).
-}
type Form step fields values
    = Form
        { prefix : String
        , defs : List Def
        , fields : fields
        , read : Locale -> Dict String Raw -> Result (List Problem) values
        }


{-| Everything the form keeps while it is being edited: the value of every field
(and the open list of a select), the baseline for `isDirty`, which fields were
left, and the problems the server gave. It is data only: there is no function in
it. Make it with `init` and keep it in the model.
-}
type State step
    = State
        { slots : Dict String Slot
        , baseline : Dict String Raw
        , touched : Set String
        , server : Dict String String
        , reviewed : Bool
        }


{-| What the controls of the form send. Wrap it in one constructor of the
application's message type and pass what comes back to `update`.
-}
type Msg
    = Typed String String
    | Left String
    | SelectMsg String (Select.Msg String)
    | MultiMsg String (MultiSelect.Msg String)
    | NumberMsg String NumberInput.Msg
    | Toggled String Bool
    | FocusField String
    | NoOp


{-| A handle to one field. The type says what the value looks like while it is
edited: `String` for a text, `Maybe id` for a choice, `List id` for several,
`Maybe Float` for a number, `Bool` for a switch. Get the handles from
`fields form`; there is no other way to make one.
-}
type Field control
    = Field
        { key : String
        , label : String
        , empty : control
        , toRaw : control -> Raw
        , fromRaw : Raw -> Maybe control
        }


{-| How the application's id type is written as text, once. Both directions are
needed: `fromKey` must give back what `toKey` wrote (test it with `lostIds`).

    countryIds : Fm.Ids CountryId
    countryIds =
        Fm.ids { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }

-}
type Ids id
    = Ids { toKey : id -> String, fromKey : String -> Maybe id }


{-| A message tied to a field: the DOM id of the control (`field`) and what to
tell the user. It has the shape of `Validate.Error`, so it fits
`Form.errorSummary`.
-}
type alias Problem =
    { field : String
    , message : String
    }


{-| One field's kind, label and rules, as built by `text`, `number`, `choice`
and the others and changed by the rules. `control` is the type of the value
while it is edited, `output` the type the form produces: `required` turns a
`Maybe a` output into `a`.
-}
type Spec control output
    = Spec (SpecData control output)


type alias SpecData control output =
    { label : String
    , hint : Maybe String
    , required : Bool
    , empty : control
    , toRaw : control -> Raw
    , fromRaw : Raw -> Maybe control
    , limits : Limits
    , check : Locale -> control -> Maybe String
    , finish : Locale -> control -> Result String output
    , reword : Maybe ((Locale -> String) -> Spec control output)
    }


type alias Limits =
    { min : Maybe Float
    , max : Maybe Float
    , decimals : Maybe Int
    }


{-| The declaration while it is being built with `with`. Start it with `define`
and finish it with `build`.
-}
type Builder step fields values
    = Builder
        { prefix : String
        , used : Set String
        , defs : List Def
        , fields : fields
        , read : Locale -> Dict String Raw -> Result (List Problem) values
        }


{-| A form, a state and a message wrapper, bound once per view with `bind`.
Every control of the form is drawn from it.
-}
type View msg
    = View
        { toMsg : Msg -> msg
        , locale : Locale
        , prefix : String
        , defs : List Def
        , slots : Dict String Slot
        , shown : Dict String String
        }


{-| The value of a field as the form compares and stores it.
-}
type Raw
    = RText String
    | RKey (Maybe String)
    | RKeys (List String)
    | RNumber (Maybe Float)
    | RUnreadable
    | RBool Bool


type Slot
    = SText String
    | SSelect (Select.State String)
    | SMulti (MultiSelect.State String)
    | SNumber NumberInput.State
    | SToggle Bool


{-| What the form knows about one field without knowing its types.
-}
type alias Def =
    { key : String
    , label : String
    , hint : Maybe String
    , required : Bool
    , initial : Raw
    , limits : Limits
    }



-- DECLARING


{-| Starts a declaration. The text is the prefix of the DOM ids of the fields
(`"supplier"` gives `supplier-name`, `supplier-legal-name` ...) and of the
summary; it must be different for every form on the page. The other two
arguments are the record constructors `Fields` and `Values`.

    Fm.define "supplier" Fields Values
        |> Fm.with (Fm.text "Name")
        |> Fm.build

-}
define : String -> fields -> values -> Builder step fields values
define prefix fieldsConstructor valuesConstructor =
    Builder
        { prefix = prefix
        , used = Set.empty
        , defs = []
        , fields = fieldsConstructor
        , read = \_ _ -> Ok valuesConstructor
        }


{-| Adds the next field. It fills the next argument of `Fields` with its handle
and the next argument of `Values` with its output. The DOM id is made from the
form's prefix and the label (`Legal name` becomes `supplier-legal-name`); a
repeated label gets `-2`, `-3` ... so two ids never clash.
-}
with : Spec control output -> Builder step (Field control -> f) (output -> v) -> Builder step f v
with (Spec spec) (Builder b) =
    let
        key =
            uniqueKey b.prefix spec.label b.used

        def =
            { key = key
            , label = spec.label
            , hint = spec.hint
            , required = spec.required
            , initial = spec.toRaw spec.empty
            , limits = spec.limits
            }

        handle =
            Field
                { key = key
                , label = spec.label
                , empty = spec.empty
                , toRaw = spec.toRaw
                , fromRaw = spec.fromRaw
                }

        readField locale raws =
            let
                raw =
                    Dict.get key raws |> Maybe.withDefault def.initial
            in
            validate locale spec raw

        read locale raws =
            case ( b.read locale raws, readField locale raws ) of
                ( Ok constructor, Ok output ) ->
                    Ok (constructor output)

                ( Err problems, Ok _ ) ->
                    Err problems

                ( Ok _, Err message ) ->
                    Err [ { field = key, message = message } ]

                ( Err problems, Err message ) ->
                    Err (problems ++ [ { field = key, message = message } ])
    in
    Builder
        { prefix = b.prefix
        , used = Set.insert key b.used
        , defs = def :: b.defs
        , fields = b.fields handle
        , read = read
        }


{-| Finishes the declaration. The result only has the type
`Form step Fields Values` when every `with` matched an argument of both records;
a field missing from one of them is a compile error.
-}
build : Builder step fields values -> Form step fields values
build (Builder b) =
    Form
        { prefix = b.prefix
        , defs = List.reverse b.defs
        , fields = b.fields
        , read = b.read
        }


{-| The handles of the form's fields, as the `Fields` record. A constant: bind
it once at the top level of the module.
-}
fields : Form step fields values -> fields
fields (Form form) =
    form.fields


{-| How an id type is written as text and read back. The same pair of functions
as `Table.rowIds`.
-}
ids : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
ids =
    Ids


uniqueKey : String -> String -> Set String -> String
uniqueKey prefix label used =
    let
        base =
            prefix ++ "-" ++ slug label

        free n =
            let
                candidate =
                    base ++ "-" ++ String.fromInt n
            in
            if Set.member candidate used then
                free (n + 1)

            else
                candidate
    in
    if Set.member base used then
        free 2

    else
        base


slug : String -> String
slug label =
    let
        parts =
            label
                |> String.toLower
                |> Internal.sanitizeId
                |> String.split "-"
                |> List.filter (\part -> part /= "")
    in
    if List.isEmpty parts then
        "field"

    else
        String.join "-" parts



-- KINDS


{-| A line of text. Blank is `Nothing` in the output, and the output is trimmed
(the display is not: nothing is changed behind the user's back). Add `required`
to get a `String`.
-}
text : String -> Spec String (Maybe String)
text label =
    make label
        ""
        RText
        (\raw ->
            case raw of
                RText value ->
                    Just value

                _ ->
                    Nothing
        )
        (\_ value ->
            if String.trim value == "" then
                Ok Nothing

            else
                Ok (Just (String.trim value))
        )


{-| A number. Empty is `Nothing`. Add `required`, `range` or `whole`.
-}
number : String -> Spec (Maybe Float) (Maybe Float)
number label =
    make label
        Nothing
        RNumber
        (\raw ->
            case raw of
                RNumber value ->
                    Just value

                RUnreadable ->
                    Just Nothing

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


{-| One of the application's values, chosen in a `select`. Empty is `Nothing`.
Add `required` to get the id itself.
-}
choice : Ids id -> String -> Spec (Maybe id) (Maybe id)
choice (Ids codec) label =
    make label
        Nothing
        (\value -> RKey (Maybe.map codec.toKey value))
        (\raw ->
            case raw of
                RKey Nothing ->
                    Just Nothing

                RKey (Just key) ->
                    Maybe.map Just (codec.fromKey key)

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


{-| Several of the application's values, chosen in a `multiSelect`, in the order
they were chosen. Empty is `[]`. Add `atLeast 1` to make it required.
-}
choices : Ids id -> String -> Spec (List id) (List id)
choices (Ids codec) label =
    make label
        []
        (\values -> RKeys (List.map codec.toKey values))
        (\raw ->
            case raw of
                RKeys keys ->
                    Just (List.filterMap codec.fromKey keys)

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


{-| An on/off choice, drawn by `switch`. Off is the empty value.
-}
toggle : String -> Spec Bool Bool
toggle label =
    make label
        False
        RBool
        (\raw ->
            case raw of
                RBool value ->
                    Just value

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


make : String -> control -> (control -> Raw) -> (Raw -> Maybe control) -> (Locale -> control -> Result String output) -> Spec control output
make label empty toRaw fromRaw finish =
    Spec
        { label = label
        , hint = Nothing
        , required = False
        , empty = empty
        , toRaw = toRaw
        , fromRaw = fromRaw
        , limits = { min = Nothing, max = Nothing, decimals = Nothing }
        , check = \_ _ -> Nothing
        , finish = finish
        , reword = Nothing
        }


validate : Locale -> SpecData control output -> Raw -> Result String output
validate locale spec raw =
    case raw of
        RUnreadable ->
            Err (Locale.pick locale { nb = "Må være et tall", en = "Must be a number" })

        _ ->
            let
                value =
                    spec.fromRaw raw |> Maybe.withDefault spec.empty
            in
            case spec.finish locale value of
                Err message ->
                    Err message

                Ok output ->
                    case spec.check locale value of
                        Just message ->
                            Err message

                        Nothing ->
                            Ok output



-- RULES


{-| The field must have a value: the output loses its `Maybe`. A text must not
be blank, a choice must be made. The label gets the `*` of a required field.

    Fm.text "Name" |> Fm.required -- Spec String String

-}
required : Spec c (Maybe a) -> Spec c a
required =
    requiredWith (\locale -> Locale.pick locale { nb = "Må fylles ut", en = "Required" })


requiredWith : (Locale -> String) -> Spec c (Maybe a) -> Spec c a
requiredWith message (Spec spec) =
    Spec
        { label = spec.label
        , hint = spec.hint
        , required = True
        , empty = spec.empty
        , toRaw = spec.toRaw
        , fromRaw = spec.fromRaw
        , limits = spec.limits
        , check = spec.check
        , finish =
            \locale value ->
                case spec.finish locale value of
                    Ok (Just output) ->
                        Ok output

                    Ok Nothing ->
                        Err (message locale)

                    Err problem_ ->
                        Err problem_
        , reword = Just (\replacement -> requiredWith replacement (Spec spec))
        }


{-| A list with at least this many items. It is required, and the message says
how many.

    Fm.choices categoryIds "Categories" |> Fm.atLeast 1

-}
atLeast : Int -> Spec c (List a) -> Spec c (List a)
atLeast n =
    atLeastWith n
        (\locale ->
            Locale.pick locale
                { nb = "Velg minst " ++ String.fromInt n
                , en = "Choose at least " ++ String.fromInt n
                }
        )


atLeastWith : Int -> (Locale -> String) -> Spec c (List a) -> Spec c (List a)
atLeastWith n message (Spec spec) =
    Spec
        { spec
            | required = n > 0
            , finish =
                \locale value ->
                    case spec.finish locale value of
                        Ok list ->
                            if List.length list < n then
                                Err (message locale)

                            else
                                Ok list

                        Err problem_ ->
                            Err problem_
            , reword = Just (\replacement -> atLeastWith n replacement (Spec spec))
        }


{-| At most one item: the output is `Maybe a` instead of a list.
-}
one : Spec c (List a) -> Spec c (Maybe a)
one =
    oneWith (\locale -> Locale.pick locale { nb = "Velg høyst én", en = "Choose at most one" })


oneWith : (Locale -> String) -> Spec c (List a) -> Spec c (Maybe a)
oneWith message (Spec spec) =
    Spec
        { label = spec.label
        , hint = spec.hint
        , required = spec.required
        , empty = spec.empty
        , toRaw = spec.toRaw
        , fromRaw = spec.fromRaw
        , limits = spec.limits
        , check = spec.check
        , finish =
            \locale value ->
                case spec.finish locale value of
                    Ok [] ->
                        Ok Nothing

                    Ok [ single ] ->
                        Ok (Just single)

                    Ok _ ->
                        Err (message locale)

                    Err problem_ ->
                        Err problem_
        , reword = Just (\replacement -> oneWith replacement (Spec spec))
        }


{-| The existing validators of [Klar.Validate](Klar-Validate) on a text, run on
the text as typed. The first problem wins. Like there, an empty text passes
every validator except `Validate.required`.

    Fm.text "Name" |> Fm.rules [ Validate.maxLength 80 ]

-}
rules : List Validate.Validator -> Spec String o -> Spec String o
rules validators =
    addCheck (\locale value -> Validate.firstError locale validators value)


addCheck : (Locale -> c -> Maybe String) -> Spec c o -> Spec c o
addCheck rule (Spec spec) =
    Spec
        { spec
            | check =
                \locale value ->
                    case spec.check locale value of
                        Just message ->
                            Just message

                        Nothing ->
                            rule locale value
            , reword =
                Just
                    (\replacement ->
                        addCheck (\locale value -> rule locale value |> Maybe.map (\_ -> replacement locale))
                            (Spec spec)
                    )
        }


{-| A number from `low` to `high`, both included. The control shows the limits
and keeps a number outside them as typed (it shows the problem, it does not move
the number).
-}
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
range low high (Spec spec) =
    let
        limits =
            spec.limits

        (Spec checked) =
            addCheck
                (\locale value ->
                    case value of
                        Just n ->
                            if n < low || n > high then
                                Just
                                    (Locale.pick locale
                                        { nb = "Må være mellom " ++ String.fromFloat low ++ " og " ++ String.fromFloat high
                                        , en = "Must be between " ++ String.fromFloat low ++ " and " ++ String.fromFloat high
                                        }
                                    )

                            else
                                Nothing

                        Nothing ->
                            Nothing
                )
                (Spec spec)
    in
    Spec { checked | limits = { limits | min = Just low, max = Just high } }


{-| A whole number: no decimals, shown and checked.
-}
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
whole (Spec spec) =
    let
        limits =
            spec.limits

        (Spec checked) =
            addCheck
                (\locale value ->
                    case value of
                        Just n ->
                            if n /= toFloat (round n) then
                                Just (Locale.pick locale { nb = "Må være et helt tall", en = "Must be a whole number" })

                            else
                                Nothing

                        Nothing ->
                            Nothing
                )
                (Spec spec)
    in
    Spec { checked | limits = { limits | decimals = Just 0 } }


{-| A short help text under the field.
-}
hint : String -> Spec c o -> Spec c o
hint help (Spec spec) =
    Spec { spec | hint = Just help }


{-| Replaces the message of the rule that was added last, in every language: a
function from the locale to the text, so the declaration (a constant) does not
fix the set of languages.

    Fm.text "Name"
        |> Fm.required
        |> Fm.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })

-}
withMessage : (Locale -> String) -> Spec c o -> Spec c o
withMessage message ((Spec spec) as original) =
    case spec.reword of
        Just reword ->
            reword message

        Nothing ->
            original



-- VALUES


{-| A form with every field empty, nothing touched, and that empty state as the
baseline. Each field's component gets its DOM id here.
-}
init : Form step fields values -> State step
init (Form form) =
    let
        slots =
            form.defs
                |> List.map (\def -> ( def.key, newSlot def ))
                |> Dict.fromList
    in
    State
        { slots = slots
        , baseline = Dict.map (\_ slot -> rawOf slot) slots
        , touched = Set.empty
        , server = Dict.empty
        , reviewed = False
        }


newSlot : Def -> Slot
newSlot def =
    case def.initial of
        RText value ->
            SText value

        RKey _ ->
            SSelect (Select.init def.key)

        RKeys _ ->
            SMulti (MultiSelect.init def.key)

        RNumber _ ->
            SNumber (NumberInput.init def.key |> NumberInput.setLimits (numberLimits def.limits))

        RUnreadable ->
            SNumber (NumberInput.init def.key)

        RBool value ->
            SToggle value


numberLimits : Limits -> List (NumberInput.Attribute msg)
numberLimits limits =
    List.filterMap identity
        [ Maybe.map NumberInput.min limits.min
        , Maybe.map NumberInput.max limits.max
        ]


rawOf : Slot -> Raw
rawOf slot =
    case slot of
        SText value ->
            RText value

        SSelect state ->
            RKey (Select.value state)

        SMulti state ->
            RKeys (MultiSelect.values state)

        SNumber state ->
            -- limits off: `isValid` then only asks whether the text is a number
            if NumberInput.isValid (NumberInput.setLimits [] state) then
                RNumber (NumberInput.value state)

            else
                RUnreadable

        SToggle value ->
            RBool value


putRaw : Raw -> Slot -> Slot
putRaw raw slot =
    case ( raw, slot ) of
        ( RText value, SText _ ) ->
            SText value

        ( RKey (Just key), SSelect state ) ->
            SSelect (Select.setValue key state)

        ( RKey Nothing, SSelect state ) ->
            SSelect (Select.clear state)

        ( RKeys keys, SMulti state ) ->
            SMulti (MultiSelect.setValues keys state)

        ( RNumber value, SNumber state ) ->
            SNumber (NumberInput.setValue value state)

        ( RBool value, SToggle _ ) ->
            SToggle value

        _ ->
            slot


{-| Puts a value in a field, for every kind of field. The type of the handle
decides what is accepted: a select takes a `Maybe CountryId`, a switch a `Bool`.
Use it to load a record. A select shows its label as soon as its options have
arrived; `get` returns the value at once.

    Fm.init form
        |> Fm.set f.name "Acme Supplies"
        |> Fm.set f.country (Just (CountryId "no"))
        |> Fm.markClean

-}
set : Field c -> c -> State step -> State step
set (Field field) value (State state) =
    State { state | slots = Dict.update field.key (Maybe.map (putRaw (field.toRaw value))) state.slots }


{-| The value of a field as it is edited: `Nothing` for an empty select, `[]` for
an empty multi select, the text as typed.
-}
get : Field c -> State step -> c
get (Field field) (State state) =
    Dict.get field.key state.slots
        |> Maybe.map rawOf
        |> Maybe.andThen field.fromRaw
        |> Maybe.withDefault field.empty


{-| The record the form produces, or all the problems, in the order of the
declaration, in the given language. An invalid form cannot produce a record.
Rules and `required` run on every field, whether or not the user has been
there.

    case Fm.toValues Locale.default form model.form of
        Ok values ->
            save values

        Err problems ->
            ...

-}
toValues : Locale -> Form step fields values -> State step -> Result (List Problem) values
toValues locale (Form form) (State state) =
    form.read locale (Dict.map (\_ slot -> rawOf slot) state.slots)


{-| `True` when the values differ from the baseline. Typing a letter and
deleting it again is clean again. Only values count: an open list, a search
text or a server problem do not.
-}
isDirty : State step -> Bool
isDirty (State state) =
    Dict.map (\_ slot -> rawOf slot) state.slots /= state.baseline


{-| The values now become the baseline, after a load or a successful save.
-}
markClean : State step -> State step
markClean (State state) =
    State { state | baseline = Dict.map (\_ slot -> rawOf slot) state.slots }


{-| Every field goes back to the baseline. Problems and what was touched are
forgotten.
-}
revert : State step -> State step
revert (State state) =
    State
        { state
            | slots = Dict.map (\key slot -> Dict.get key state.baseline |> Maybe.map (\raw -> putRaw raw slot) |> Maybe.withDefault slot) state.slots
            , touched = Set.empty
            , server = Dict.empty
            , reviewed = False
        }


{-| Handles a message of the form's controls. A change in a field clears the
server problem of that field.

    FormMsg inner ->
        let
            ( form, cmd ) =
                Fm.update inner model.form
        in
        ( { model | form = form }, Cmd.map FormMsg cmd )

-}
update : Msg -> State step -> ( State step, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Typed key value ->
            ( moved key (Dict.get key state.slots) (Just (SText value)) current, Cmd.none )

        Left key ->
            ( touch key current, Cmd.none )

        Toggled key value ->
            ( moved key (Dict.get key state.slots) (Just (SToggle value)) current, Cmd.none )

        SelectMsg key inner ->
            case Dict.get key state.slots of
                Just ((SSelect before) as old) ->
                    let
                        ( after, cmd ) =
                            Select.update inner before

                        left =
                            Select.isOpen before && not (Select.isOpen after)
                    in
                    ( moved key (Just old) (Just (SSelect after)) current |> touchIf left key
                    , Cmd.map (SelectMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        MultiMsg key inner ->
            case Dict.get key state.slots of
                Just ((SMulti before) as old) ->
                    let
                        ( after, cmd ) =
                            MultiSelect.update inner before

                        left =
                            MultiSelect.isOpen before && not (MultiSelect.isOpen after)
                    in
                    ( moved key (Just old) (Just (SMulti after)) current |> touchIf left key
                    , Cmd.map (MultiMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        NumberMsg key inner ->
            case Dict.get key state.slots of
                Just ((SNumber before) as old) ->
                    let
                        ( after, cmd ) =
                            NumberInput.update inner before
                    in
                    ( moved key (Just old) (Just (SNumber after)) current |> touchIf (NumberInput.isTouched after) key
                    , Cmd.map (NumberMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        FocusField key ->
            ( current, Form.focusField key NoOp )

        NoOp ->
            ( current, Cmd.none )


{-| Puts the new slot in place. When the value changed, the field is touched
and its server problem is dropped (also when the old value is typed again: the
server said no to a value the user has since changed).
-}
moved : String -> Maybe Slot -> Maybe Slot -> State step -> State step
moved key before after (State state) =
    case after of
        Nothing ->
            State state

        Just slot ->
            let
                edited =
                    Maybe.map rawOf before /= Just (rawOf slot)

                next =
                    State { state | slots = Dict.insert key slot state.slots }
            in
            if edited then
                touch key next |> dropServer key

            else
                next


touch : String -> State step -> State step
touch key (State state) =
    State { state | touched = Set.insert key state.touched }


touchIf : Bool -> String -> State step -> State step
touchIf condition key state =
    if condition then
        touch key state

    else
        state


dropServer : String -> State step -> State step
dropServer key (State state) =
    State { state | server = Dict.remove key state.server }



-- PROBLEMS FROM THE SERVER


{-| A message from the server tied to a field. Map the backend's own field type
to a handle once, in the application:

    fromBackend : Backend.Problem -> Fm.Problem
    fromBackend p =
        case p.field of
            Backend.Name ->
                Fm.problem f.name p.message

            Backend.Country ->
                Fm.problem f.country p.message

-}
problem : Field c -> String -> Problem
problem (Field field) message =
    { field = field.key, message = message }


{-| Gives the form the problems of a failed save. Each is shown at its field
and in the summary until that field is edited. All the problems of the form show
from now on, and the focus moves to the summary. A problem for a field the form
does not have is ignored.
-}
rejected : List Problem -> Form step fields values -> State step -> ( State step, Cmd Msg )
rejected problems (Form form) (State state) =
    let
        known =
            List.map .key form.defs

        server =
            problems
                |> List.filter (\p -> List.member p.field known)
                |> List.foldl (\p all -> Dict.update p.field (\old -> Just (Maybe.withDefault p.message old)) all) Dict.empty
    in
    ( State { state | server = server, reviewed = True }
    , Form.focusSummary form.prefix NoOp
    )


{-| Shows every problem now, also for fields the user has not been in, and moves
the focus to the summary. Call it when the user presses Save and `toValues`
returned problems.
-}
reveal : Form step fields values -> State step -> ( State step, Cmd Msg )
reveal (Form form) (State state) =
    ( State { state | reviewed = True }
    , Form.focusSummary form.prefix NoOp
    )



-- VIEWS


{-| Binds the form, the state, the language and the message wrapper for one
view. The result carries everything the controls need, so each control is one
call.
-}
bind : Locale -> (Msg -> msg) -> Form step fields values -> State step -> View msg
bind locale toMsg ((Form form) as declared) ((State state) as current) =
    let
        client =
            case toValues locale declared current of
                Ok _ ->
                    []

                Err problems ->
                    problems
                        |> List.filter (\p -> state.reviewed || Set.member p.field state.touched)

        shownClient =
            client |> List.map (\p -> ( p.field, p.message )) |> Dict.fromList
    in
    View
        { toMsg = toMsg
        , locale = locale
        , prefix = form.prefix
        , defs = form.defs
        , slots = state.slots
        , shown = Dict.union shownClient state.server
        }


{-| Everything the declaration says about a field and the view needs: the
attributes that win over the application's own.
-}
fieldDef : View msg -> Field c -> Maybe ( Def, Slot )
fieldDef (View view) (Field field) =
    case ( List.filter (\def -> def.key == field.key) view.defs |> List.head, Dict.get field.key view.slots ) of
        ( Just def, Just slot ) ->
            Just ( def, slot )

        _ ->
            Nothing


problemOf : View msg -> Def -> Maybe String
problemOf (View view) def =
    Dict.get def.key view.shown


mismatch : View msg -> Field c -> String -> Html msg
mismatch (View view) (Field field) wanted =
    Html.p
        [ Attr.id field.key
        , Attr.attribute "role" "alert"
        , Internal.cls [ "klar-field__error" ]
        ]
        [ Html.text
            (Locale.pick view.locale
                { nb = "Feltet «" ++ field.label ++ "» er ikke deklarert som " ++ wanted ++ "."
                , en = "The field \"" ++ field.label ++ "\" is not declared as " ++ wanted ++ "."
                }
            )
        ]


{-| A text input for a `text` field. The id, label, hint, required mark, value,
error and messages are set by the form and win over the application's
attributes; the others (a placeholder, `TextInput.url`, a suffix) are the
application's.
-}
textInput : View msg -> Field String -> List (TextInput.Attribute msg) -> Html msg
textInput ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SText value ) ->
            TextInput.view
                (attributes
                    ++ declaredAttributes def TextInput.hint TextInput.required
                    ++ [ TextInput.locale view.locale
                       , TextInput.id def.key
                       , TextInput.label def.label
                       , TextInput.errorMaybe (problemOf bound def)
                       , TextInput.value value
                       , TextInput.onInput (\typed -> view.toMsg (Typed def.key typed))
                       , TextInput.onBlur (view.toMsg (Left def.key))
                       ]
                )

        _ ->
            mismatch bound field "text"


{-| A number input for a `number` field. The limits of `range` and the decimals
of `whole` are applied for you.
-}
numberInput : View msg -> Field (Maybe Float) -> List (NumberInput.Attribute msg) -> Html msg
numberInput ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SNumber state ) ->
            NumberInput.view (\inner -> view.toMsg (NumberMsg def.key inner))
                (attributes
                    ++ declaredAttributes def NumberInput.hint NumberInput.required
                    ++ [ NumberInput.locale view.locale
                       , NumberInput.label def.label
                       , NumberInput.errorMaybe (problemOf bound def)
                       ]
                    ++ numberLimits def.limits
                    ++ (Maybe.map (\places -> [ NumberInput.decimals places ]) def.limits.decimals |> Maybe.withDefault [])
                )
                state

        _ ->
            mismatch bound field "a number"


{-| A select for a `choice` field. The options are an argument, not an
attribute, so a select without options cannot be drawn.
-}
select : View msg -> Field (Maybe id) -> Remote (List (Select.Option id)) -> List (Select.Attribute String msg) -> Html msg
select ((View view) as bound) ((Field field) as handle) options attributes =
    case fieldDef bound handle of
        Just ( def, SSelect state ) ->
            Select.view (\inner -> view.toMsg (SelectMsg def.key inner))
                (attributes
                    ++ declaredAttributes def Select.hint Select.required
                    ++ [ Select.locale view.locale
                       , Select.label def.label
                       , Select.errorMaybe (problemOf bound def)
                       , Select.remote (Remote.map (List.map (Select.mapOption (keyOf field.toRaw << Just))) options)
                       ]
                )
                state

        _ ->
            mismatch bound handle "a choice"


{-| A multi select for a `choices` field.
-}
multiSelect : View msg -> Field (List id) -> Remote (List (Select.Option id)) -> List (MultiSelect.Attribute String msg) -> Html msg
multiSelect ((View view) as bound) ((Field field) as handle) options attributes =
    case fieldDef bound handle of
        Just ( def, SMulti state ) ->
            MultiSelect.view (\inner -> view.toMsg (MultiMsg def.key inner))
                (attributes
                    ++ declaredAttributes def MultiSelect.hint MultiSelect.required
                    ++ [ MultiSelect.locale view.locale
                       , MultiSelect.label def.label
                       , MultiSelect.errorMaybe (problemOf bound def)
                       , MultiSelect.remote (Remote.map (List.map (Select.mapOption (keyOf field.toRaw << List.singleton))) options)
                       ]
                )
                state

        _ ->
            mismatch bound handle "several choices"


declaredAttributes : Def -> (String -> a) -> a -> List a
declaredAttributes def hintAttribute requiredAttribute =
    List.filterMap identity
        [ Maybe.map hintAttribute def.hint
        , if def.required then
            Just requiredAttribute

          else
            Nothing
        ]


keyOf : (a -> Raw) -> a -> String
keyOf toRaw value =
    case toRaw value of
        RKey (Just key) ->
            key

        RKeys [ key ] ->
            key

        _ ->
            ""


{-| A switch for a `toggle` field. The hint of the declaration is its
description.
-}
switch : View msg -> Field Bool -> List (Switch.Attribute msg) -> Html msg
switch ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SToggle value ) ->
            Switch.view
                (attributes
                    ++ List.filterMap identity
                        [ Maybe.map Switch.description def.hint
                        , Maybe.map Switch.error (problemOf bound def)
                        ]
                    ++ [ Switch.locale view.locale
                       , Switch.id def.key
                       , Switch.label def.label
                       , Switch.checked value
                       , Switch.onToggle (\on -> view.toMsg (Toggled def.key on))
                       ]
                )

        _ ->
            mismatch bound field "a switch"


{-| The list of problems that are showing, with the labels of the declaration,
as `Form.errorSummary`. Each line moves the focus to its field. Nothing is
drawn while no problem is showing.
-}
summary : View msg -> Html msg
summary (View view) =
    let
        problems =
            view.defs
                |> List.filterMap
                    (\def ->
                        Dict.get def.key view.shown
                            |> Maybe.map (\message -> { field = def.key, message = message })
                    )
    in
    Form.errorSummary
        [ Form.id view.prefix
        , Form.locale view.locale
        , Form.labels (List.map (\def -> ( def.key, def.label )) view.defs)
        , Form.onFocusField (\key -> view.toMsg (FocusField key))
        ]
        problems



-- TESTS


{-| For a test: loads a record with your `fill` function into a new form and
reads it back. A form that loses a value, or two fields of the same type that
were swapped in `Fields` or `Values`, gives something else than the record. Use
a sample with a different value in every field.

    Fm.roundTrip form fill sample
        |> Expect.equal (Ok sample)

-}
roundTrip : Form step fields values -> (values -> State step -> State step) -> values -> Result (List Problem) values
roundTrip declared fill values =
    init declared |> fill values |> toValues Locale.en declared


{-| For a test: the values that do not survive `toKey` and `fromKey`. An empty
list is what you want.

    Fm.lostIds countryIds [ CountryId "no", CountryId "se" ]
        |> Expect.equal []

-}
lostIds : Ids id -> List id -> List id
lostIds (Ids codec) values =
    List.filter (\value -> codec.fromKey (codec.toKey value) /= Just value) values
