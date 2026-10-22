module Klar.Form.Model exposing
    ( Form, State, Msg, Field, Problem, Spec, Builder, View
    , define, with, build, fields
    , text, number, choice, choices, toggle, tags, files
    , required, atLeast, one, rules, range, whole, hint, withMessage
    , init, set, get, toValues, isDirty, markClean, revert, update
    , problems, hasProblems, outside, problem, rejected, reveal, focus, goToProblem
    , bind, textInput, textArea, numberInput, select, multiSelect, switch, tagInput, fileDrop, summary
    , roundTrip, lostIds
    )

{-| A form declared once: its fields in order, each with a label and its rules.
The declaration gives the application the **handles** of the fields (to put in
the view, to read and set, to tie a server problem to), the **record** the form
produces when it is valid, and everything Klar needs to validate and update it.
The application keeps one [`State`](#State) in its model and one [`Msg`](#Msg)
in its messages, instead of one component state and one message per field.

This is a prototype of the form model (`design/FORM-MODEL.md` in the
repository): it handles text, numbers, one choice, several choices, switches,
tags and files. Import it as `Fm`.

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

@docs Form, State, Msg, Field, Problem, Spec, Builder, View


# Declaring a form

@docs define, with, build, fields


# Kinds of field

@docs text, number, choice, choices, toggle, tags, files


# Rules

@docs required, atLeast, one, rules, range, whole, hint, withMessage


# Values and state

@docs init, set, get, toValues, isDirty, markClean, revert, update


# Problems and focus

@docs problems, hasProblems, outside, problem, rejected, reveal, focus, goToProblem


# Views

@docs bind, textInput, textArea, numberInput, select, multiSelect, switch, tagInput, fileDrop, summary


# Tests

@docs roundTrip, lostIds

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Remote as Remote exposing (Remote)
import Klar.Select as Select
import Klar.Switch as Switch
import Klar.TagInput as TagInput
import Klar.TextArea as TextArea
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
        , read : Locale -> Dict String Raw -> Result (List (Problem step)) values
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
        , outside : List (Problem step)
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
    | TagsMsg String TagInput.Msg
    | FilesMsg String FileDrop.Msg
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


{-| A message tied to a field: the DOM id of the control (`field`), the label
the user knows the field by (`label`), what to tell the user (`message`) and,
in a form with steps, the step the field is on. `problems` lists them all.

Write one by hand for something the form model does not hold, such as the
rule builder of a price rule, and hand it to `outside`:

    { field = "price-rule-1"
    , label = "Price rule 1"
    , message = "Add at least one condition."
    , step = Nothing
    }

-}
type alias Problem step =
    { field : String
    , label : String
    , message : String
    , step : Maybe step
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
    , few : Locale -> Int -> String
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
        , read : Locale -> Dict String Raw -> Result (List (Problem step)) values
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
        , byField : Dict String String
        , shown : List ShownProblem
        }


type alias ShownProblem =
    { field : String
    , label : String
    , message : String
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
    | RTags (List String)
    | RFiles (List FileDrop.FileInfo) Bool


type Slot
    = SText String
    | SSelect (Select.State String)
    | SMulti (MultiSelect.State String)
    | SNumber NumberInput.State
    | STags TagInput.State
    | SFiles FileDrop.State
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

                ( Err found, Ok _ ) ->
                    Err found

                ( Ok _, Err message ) ->
                    Err [ { field = key, label = spec.label, message = message, step = Nothing } ]

                ( Err found, Err message ) ->
                    Err (found ++ [ { field = key, label = spec.label, message = message, step = Nothing } ])
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
choice codec label =
    make label
        Nothing
        (\value -> RKey (Maybe.map (Ids.toKey codec) value))
        (\raw ->
            case raw of
                RKey Nothing ->
                    Just Nothing

                RKey (Just key) ->
                    Maybe.map Just (Ids.fromKey codec key)

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


{-| Several of the application's values, chosen in a `multiSelect`, in the order
they were chosen. Empty is `[]`. Add `atLeast 1` to make it required.
-}
choices : Ids id -> String -> Spec (List id) (List id)
choices codec label =
    make label
        []
        (\values -> RKeys (List.map (Ids.toKey codec) values))
        (\raw ->
            case raw of
                RKeys keys ->
                    Just (List.filterMap (Ids.fromKey codec) keys)

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


{-| Free-form tags, drawn by `tags`: type a word, press Enter, get a chip. The
order is the order they were added. Empty is `[]`. Add `atLeast 1` to make it
required, and give the delimiters, the limit and a rule for a single tag to the
view (`TagInput.delimiters`, `TagInput.maxTags`, `TagInput.validate`).

    Fm.tags "Certifications" |> Fm.atLeast 1

-}
tags : String -> Spec (List String) (List String)
tags label =
    let
        (Spec spec) =
            make label
                []
                RTags
                (\raw ->
                    case raw of
                        RTags value ->
                            Just value

                        _ ->
                            Nothing
                )
                (\_ value -> Ok value)
    in
    Spec { spec | few = \locale n -> Locale.pick locale { nb = "Legg til minst " ++ String.fromInt n, en = "Add at least " ++ String.fromInt n } }


{-| Files the user chose or dropped, drawn by `files`. Empty is `[]`. Files the
drop zone refused (wrong type, too large) are not in the value; while one of
them is still listed the field has the problem "Remove the refused file". Add
`atLeast 1` to require a file, or `one` for a single file (`one |> required`
for a file that must be there). The size and type limits belong to the view
(`FileDrop.accept`, `FileDrop.maxSize`).

    Fm.files "Signed contract" |> Fm.one |> Fm.required

-}
files : String -> Spec (List FileDrop.FileInfo) (List FileDrop.FileInfo)
files label =
    let
        (Spec spec) =
            make label
                []
                (\value -> RFiles value False)
                (\raw ->
                    case raw of
                        RFiles value _ ->
                            Just value

                        _ ->
                            Nothing
                )
                (\_ value -> Ok value)
    in
    Spec { spec | few = \locale n -> Locale.pick locale { nb = "Legg ved minst " ++ String.fromInt n, en = "Attach at least " ++ String.fromInt n } }


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
        , few = \locale n -> Locale.pick locale { nb = "Velg minst " ++ String.fromInt n, en = "Choose at least " ++ String.fromInt n }
        , finish = finish
        , reword = Nothing
        }


validate : Locale -> SpecData control output -> Raw -> Result String output
validate locale spec raw =
    case raw of
        RUnreadable ->
            Err (Locale.pick locale { nb = "Må være et tall", en = "Must be a number" })

        RFiles _ True ->
            Err (Locale.pick locale { nb = "Fjern filen som ble avvist", en = "Remove the refused file" })

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
        , few = spec.few
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
atLeast n (Spec first) =
    atLeastWith n (\locale -> first.few locale n) (Spec first)


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
    oneWith (\locale -> Locale.pick locale { nb = "Bare én er tillatt", en = "Only one is allowed" })


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
        , few = spec.few
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
the text as typed. The first problem wins. A blank text passes every rule, also
`Validate.custom` and `Validate.required`: an optional field that is left empty
is fine, and a field that must be filled in says so with `required`, not with
a rule.

    Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 80 ]

-}
rules : List Validate.Validator -> Spec String o -> Spec String o
rules validators =
    addCheck
        (\locale value ->
            if String.trim value == "" then
                Nothing

            else
                Validate.firstError locale validators value
        )


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
        , baseline = Dict.map (\_ slot -> stable (rawOf slot)) slots
        , touched = Set.empty
        , server = Dict.empty
        , outside = []
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

        RTags _ ->
            STags (TagInput.init def.key)

        RFiles _ _ ->
            SFiles (FileDrop.init def.key)

        RBool value ->
            SToggle value


numberLimits : Limits -> List (NumberInput.Attribute msg)
numberLimits limits =
    List.filterMap identity
        [ Maybe.map NumberInput.min limits.min
        , Maybe.map NumberInput.max limits.max
        ]


{-| The value without what is only on the screen: a refused file is listed but
is not part of the value, so adding one does not make the form dirty.
-}
stable : Raw -> Raw
stable raw =
    case raw of
        RFiles value _ ->
            RFiles value False

        _ ->
            raw


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

        STags state ->
            RTags (TagInput.tags state)

        SFiles state ->
            RFiles (FileDrop.files state) (FileDrop.hasProblems state)

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

        ( RTags value, STags state ) ->
            STags (TagInput.setTags value state)

        ( RFiles value _, SFiles state ) ->
            SFiles (FileDrop.setFiles value state)

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
there. A problem the server gave that still stands (its field has not been
edited) and every problem given to `outside` count too: the form is not valid
while they are there, so a record is never produced behind them.

    case Fm.toValues Locale.default form model.form of
        Ok values ->
            save values

        Err found ->
            ...

-}
toValues : Locale -> Form step fields values -> State step -> Result (List (Problem step)) values
toValues locale (Form form) (State state) =
    let
        client =
            form.read locale (Dict.map (\_ slot -> rawOf slot) state.slots)

        clientProblems =
            case client of
                Ok _ ->
                    []

                Err found ->
                    found

        standing =
            form.defs
                |> List.filterMap
                    (\def ->
                        case List.filter (\p -> p.field == def.key) clientProblems of
                            first :: _ ->
                                Just first

                            [] ->
                                Dict.get def.key state.server
                                    |> Maybe.map (\message -> { field = def.key, label = def.label, message = message, step = Nothing })
                    )

        everything =
            standing ++ state.outside
    in
    case client of
        Ok values ->
            if List.isEmpty everything then
                Ok values

            else
                Err everything

        Err _ ->
            Err everything


{-| `True` when the values differ from the baseline. Typing a letter and
deleting it again is clean again. Only values count: an open list, a search
text or a server problem do not.
-}
isDirty : State step -> Bool
isDirty (State state) =
    Dict.map (\_ slot -> stable (rawOf slot)) state.slots /= state.baseline


{-| The values now become the baseline, after a load or a successful save.
-}
markClean : State step -> State step
markClean (State state) =
    State { state | baseline = Dict.map (\_ slot -> stable (rawOf slot)) state.slots }


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

        TagsMsg key inner ->
            case Dict.get key state.slots of
                Just ((STags before) as old) ->
                    let
                        ( after, cmd ) =
                            TagInput.update inner before
                    in
                    ( moved key (Just old) (Just (STags after)) current |> touchIf (TagInput.isTouched after) key
                    , Cmd.map (TagsMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        FilesMsg key inner ->
            case Dict.get key state.slots of
                Just ((SFiles before) as old) ->
                    let
                        ( after, cmd ) =
                            FileDrop.update inner before
                    in
                    ( moved key (Just old) (Just (SFiles after)) current |> touchIf (FileDrop.isTouched after) key
                    , Cmd.map (FilesMsg key) cmd
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
                    Maybe.map (rawOf >> stable) before /= Just (stable (rawOf slot))

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



-- PROBLEMS AND FOCUS


{-| Everything that is wrong now, in the order of the declaration: the rules of
every field (whether or not the user has been there), the problems the server
gave that still stand, and the problems given to `outside`. A field has at most
one problem from the form, its own rule first and then the server's. This is the
list `toValues` gives when it fails, and the list for a review page or a count;
`summary` and the field's own message show the part of it that has come to
light.

    Fm.problems Locale.default form model.form
        |> List.map (\p -> p.label ++ ": " ++ p.message)

-}
problems : Locale -> Form step fields values -> State step -> List (Problem step)
problems locale declared current =
    case toValues locale declared current of
        Ok _ ->
            []

        Err found ->
            found


{-| `True` when `problems` is not empty. Use it to keep a Save button quiet or to
colour a step: the language does not matter for the answer.
-}
hasProblems : Form step fields values -> State step -> Bool
hasProblems declared current =
    not (List.isEmpty (problems Locale.default declared current))


{-| Gives the form the problems of something it does not hold itself, such as
the rule builder of a price rule. They count like the form's own: they are in
`problems`, `toValues` fails while they stand, and `summary` lists them once the
problems have been revealed (`reveal`, `rejected`). Each is a `Problem` you write
by hand; its `field` is the DOM id of the element the summary moves the focus
to.

The list replaces the one given before, so compute it from your model and call
it at the end of your `update`, for example in the same place that handles the
messages of the rule builder:

    ( { model | form = Fm.outside (ruleProblems model) model.form }, cmd )

-}
outside : List (Problem step) -> State step -> State step
outside found (State state) =
    State { state | outside = found }


{-| A message from the server tied to a field. Map the backend's own field type
to a handle once, in the application:

    fromBackend : Backend.Problem -> Fm.Problem step
    fromBackend p =
        case p.field of
            Backend.Name ->
                Fm.problem f.name p.message

            Backend.Country ->
                Fm.problem f.country p.message

-}
problem : Field c -> String -> Problem step
problem (Field field) message =
    { field = field.key, label = field.label, message = message, step = Nothing }


{-| Gives the form the problems of a failed save. Each is shown at its field
and in the summary until that field is edited, and counts as a problem
(`problems`, `toValues`) for as long. All the problems of the form show from now
on, and the focus moves to the summary. A problem for a field the form does not
have is ignored.

The problems are stored whether or not the form is on screen. The `Cmd` focuses
the summary of this form; when the summary is not on screen (the form is on
another page, or not drawn yet) it finds nothing and does nothing, so it is safe
to batch or to drop. Two forms rejected in one reply each focus their own
summary, and the last one wins: keep the `Cmd` of the one the user is looking at.

-}
rejected : List (Problem step) -> Form step fields values -> State step -> ( State step, Cmd Msg )
rejected found (Form form) (State state) =
    let
        known =
            List.map .key form.defs

        server =
            found
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


{-| Moves the focus to a field, so the application never writes a DOM id. Map
the `Cmd` with your message constructor. Nothing happens when the field is not
on screen.

    Fm.focus f.name |> Cmd.map FormMsg

-}
focus : Field c -> Cmd Msg
focus (Field field) =
    Form.focusField field.key NoOp


{-| Moves the focus to the element a problem is about, for a review list you
draw yourself (the summary does this by itself). The problem is one of
`problems`, or one you gave to `outside`.
-}
goToProblem : Form step fields values -> Problem step -> State step -> ( State step, Cmd Msg )
goToProblem _ p state =
    ( state, Form.focusField p.field NoOp )



-- VIEWS


{-| Binds the form, the state, the language and the message wrapper for one
view. The result carries everything the controls need, so each control is one
call.
-}
bind : Locale -> (Msg -> msg) -> Form step fields values -> State step -> View msg
bind locale toMsg (Form form) (State state) =
    let
        client =
            case form.read locale (Dict.map (\_ slot -> rawOf slot) state.slots) of
                Ok _ ->
                    []

                Err found ->
                    found
                        |> List.filter (\p -> state.reviewed || Set.member p.field state.touched)

        shownClient =
            client |> List.map (\p -> ( p.field, p.message )) |> Dict.fromList

        shownByField =
            Dict.union shownClient state.server

        ofForm =
            form.defs
                |> List.filterMap
                    (\def ->
                        Dict.get def.key shownByField
                            |> Maybe.map (\message -> { field = def.key, label = def.label, message = message })
                    )

        ofOutside =
            if state.reviewed then
                List.map (\p -> { field = p.field, label = p.label, message = p.message }) state.outside

            else
                []
    in
    View
        { toMsg = toMsg
        , locale = locale
        , prefix = form.prefix
        , defs = form.defs
        , slots = state.slots
        , byField = shownByField
        , shown = ofForm ++ ofOutside
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
    Dict.get def.key view.byField


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


{-| A multi-line text area for a `text` field: the same field as `textInput`,
drawn for a long note. Give the number of rows and the maximum length as
attributes (`TextArea.rows`, `TextArea.maxLength`).
-}
textArea : View msg -> Field String -> List (TextArea.Attribute msg) -> Html msg
textArea ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SText value ) ->
            TextArea.view
                (attributes
                    ++ declaredAttributes def TextArea.hint TextArea.required
                    ++ [ TextArea.locale view.locale
                       , TextArea.id def.key
                       , TextArea.label def.label
                       , TextArea.errorMaybe (problemOf bound def)
                       , TextArea.value value
                       , TextArea.onInput (\typed -> view.toMsg (Typed def.key typed))
                       , TextArea.onBlur (view.toMsg (Left def.key))
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


{-| A tag field for a `tags` field. The label, hint, required mark, error and
messages are set by the form; the delimiters, the limit, the placeholder and
a rule for a single tag are the application's attributes.
-}
tagInput : View msg -> Field (List String) -> List (TagInput.Attribute msg) -> Html msg
tagInput ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, STags state ) ->
            TagInput.view (\inner -> view.toMsg (TagsMsg def.key inner))
                (attributes
                    ++ declaredAttributes def TagInput.hint TagInput.required
                    ++ [ TagInput.locale view.locale
                       , TagInput.label def.label
                       , TagInput.errorMaybe (problemOf bound def)
                       ]
                )
                state

        _ ->
            mismatch bound field "tags"


{-| A drop zone for a `files` field. The type and size limits and the number of
files are the application's attributes (`FileDrop.accept`, `FileDrop.maxSize`,
`FileDrop.maxFiles`); `one` does not limit the zone by itself.
-}
fileDrop : View msg -> Field (List FileDrop.FileInfo) -> List (FileDrop.Attribute msg) -> Html msg
fileDrop ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SFiles state ) ->
            FileDrop.view (\inner -> view.toMsg (FilesMsg def.key inner))
                (attributes
                    ++ declaredAttributes def FileDrop.hint FileDrop.required
                    ++ [ FileDrop.locale view.locale
                       , FileDrop.label def.label
                       , FileDrop.errorMaybe (problemOf bound def)
                       ]
                )
                state

        _ ->
            mismatch bound field "files"


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
as `Form.errorSummary`: the form's own and those given to `outside`. Each line
moves the focus to its element. Nothing is drawn while no problem is showing.
-}
summary : View msg -> Html msg
summary (View view) =
    Form.errorSummary
        [ Form.id view.prefix
        , Form.locale view.locale
        , Form.labels (List.map (\p -> ( p.field, p.label )) view.shown)
        , Form.onFocusField (\key -> view.toMsg (FocusField key))
        ]
        (List.map (\p -> { field = p.field, message = p.message }) view.shown)



-- TESTS


{-| For a test: loads a record with your `fill` function into a new form and
reads it back. A form that loses a value, or two fields of the same type that
were swapped in `Fields` or `Values`, gives something else than the record. Use
a sample with a different value in every field.

    Fm.roundTrip form fill sample
        |> Expect.equal (Ok sample)

-}
roundTrip : Form step fields values -> (values -> State step -> State step) -> values -> Result (List (Problem step)) values
roundTrip declared fill values =
    init declared |> fill values |> toValues Locale.en declared


{-| For a test: the values that do not survive `toKey` and `fromKey`. An empty
list is what you want.

    Fm.lostIds countryIds [ CountryId "no", CountryId "se" ]
        |> Expect.equal []

-}
lostIds : Ids id -> List id -> List id
lostIds codec values =
    List.filter (\value -> Ids.fromKey codec (Ids.toKey codec value) /= Just value) values
