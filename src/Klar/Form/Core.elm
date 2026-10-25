module Klar.Form.Core exposing (..)

{-| The implementation of the form model. It is not exposed: `Klar.Form`,
`Klar.Form.Spec` and `Klar.Form.Check` are its public faces, and their types are
aliases of the types defined here. Everything is in one module because the
declaration, the state and the views share the same private types (`Raw`,
`Slot`, `Def`); the three public modules only carry the documentation and decide
what an application sees.
-}

import Dict exposing (Dict)
import File exposing (File)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.DateRangePicker as DateRangePicker
import Klar.FileDrop as FileDrop
import Klar.Form.Layout as FormLayout
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.MaskedInput as MaskedInput
import Klar.Money as Money exposing (Currency, Money)
import Klar.MoneyInput as MoneyInput
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Radio as Radio
import Klar.Remote as Remote exposing (Remote)
import Klar.Rule as Rule
import Klar.RuleBuilder as RuleBuilder
import Klar.Select as Select
import Klar.Stepper as Stepper
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
        , steps : List (StepInfo step)
        , defsAt : String -> List Def
        , fieldsAt : String -> fields
        , readAt : String -> Locale -> Data -> Result (List Found) values
        , conditionsAt : String -> List Condition
        , liveAt : String -> Locale -> Data -> List Found
        }


{-| A condition on a field, declared with `shownWhen` or `requiredWhen`: the
field it is about and whether it holds for the data now.
-}
type alias Condition =
    { key : String
    , kind : ConditionKind
    , holds : Data -> Bool
    }


type ConditionKind
    = ShownWhen
    | RequiredWhen


type alias StepInfo step =
    { step : step
    , label : String
    }


{-| Everything the form keeps while it is being edited: the value of every field
(and the open list of a select), the rows of every repeating group, the baseline
for `isDirty`, which fields were left, the problems the server gave and the
current step. It is data only: there is no function in it. Make it with `init`
and keep it in the model.
-}
type State step
    = State Data


type alias Data =
    { slots : Dict String Slot
    , baseline : Dict String Raw
    , touched : Set String
    , server : Dict String String
    , outside : List Outside
    , current : Int
    , attempted : Set Int
    }


type alias Outside =
    { field : String
    , label : String
    , message : String
    , step : Maybe Int
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
    | RuleMsg String RuleBuilder.Msg
    | DateMsg String DatePicker.Msg
    | PeriodMsg String DateRangePicker.Msg
    | MoneyMsg String MoneyInput.Msg
    | MaskedMsg String MaskedInput.Msg
    | Picked String String
    | Toggled String Bool
    | AddRow String
    | RemoveRow String Int
    | GoStep Int
    | FocusField Int String
    | NoOp


{-| A handle to one field. The type says what the value looks like while it is
edited: `String` for a text, `Maybe id` for a choice, `List id` for several,
`Maybe Float` for a number, `Bool` for a switch, `List String` for tags and a
list of files for files. Get the handles from `fields form`; there is no other
way to make one.
-}
type Field control
    = Field
        { key : String
        , label : String
        , empty : control
        , toRaw : control -> Raw
        , fromData : Data -> control
        , plan : Maybe RowsPlan
        }


{-| The control of a repeating group (`rows`): the handles of the rows it has
now. It has no constructor, so a rows field cannot be given a value with `set`;
read the handles of the rows with `rowFields` and load them with `fillRows`.
-}
type Rows rowFields
    = Rows (List rowFields)


{-| A message tied to a field: the DOM id of the control (`field`), the label
the user knows the field by (`label`), what to tell the user (`message`) and,
in a form with steps, the step the field is on. `problems` lists them all.

Write one by hand for something the form model does not hold, such as the
rule builder of a price rule, and hand it to `outside`:

    { field = "price-rule-1"
    , label = "Price rule 1"
    , message = "Add at least one condition."
    , step = Just Pricing
    }

-}
type alias Problem step =
    { field : String
    , label : String
    , message : String
    , step : Maybe step
    }


type alias Found =
    { field : String
    , target : String
    , label : String
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
    , fromData : String -> Data -> control
    , limits : Limits
    , rows : Maybe RowsPlan
    , few : Locale -> Int -> String
    , read : String -> Locale -> Data -> Result (List Found) output
    , reword : Maybe ((Locale -> String) -> Spec control output)
    }


{-| What the control of a field needs from the declaration: the limits and decimals
of a number, the earliest and latest date, the lowest and highest amount, the
currency of an amount and the mask of an identifier. The limits of dates and
amounts are checked by `limitProblems`, from these values.
-}
type alias Limits =
    { min : Maybe Float
    , max : Maybe Float
    , decimals : Maybe Int
    , earliest : Maybe Date
    , latest : Maybe Date
    , lowest : Maybe Money
    , highest : Maybe Money
    , currency : Maybe Currency
    , mask : Maybe MaskedInput.Mask
    }


{-| The declaration while it is being built with `with`. Start it with `define`
and finish it with `build`.
-}
type Builder step fields values
    = Builder
        { prefix : String
        , used : Set String
        , steps : List (StepInfo step)
        , current : Int
        , makers : List (String -> Def)
        , fieldsAt : String -> fields
        , readAt : String -> Locale -> Data -> Result (List Found) values
        , conditionsAt : String -> List Condition
        , liveAt : String -> Locale -> Data -> List Found
        }


{-| A form, a state and a message wrapper, bound once per view with `bind`.
Every control of the form is drawn from it.
-}
type View msg
    = View
        { toMsg : Msg -> msg
        , locale : Locale
        , prefix : String
        , defs : Dict String Def
        , slots : Dict String Slot
        , byField : Dict String String
        , listed : List Listed
        , stepInfo : List { label : String, failed : Bool }
        , current : Int
        , anchor : Maybe String
        , hidden : Set String
        }


type alias Listed =
    { field : String
    , label : String
    , message : String
    , step : Int
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
    | RRule Rule.Rule
    | RRows (List Int)
    | RDate (Maybe Date)
    | RPeriod (Maybe ( Date, Date ))
    | RMoney (Maybe Money)
    | RMasked (Maybe String)


type Slot
    = SText String
    | SSelect (Select.State String)
    | SMulti (MultiSelect.State String)
    | SNumber NumberInput.State
    | STags TagInput.State
    | SFiles FileDrop.State
    | SRule RuleBuilder.State
    | SToggle Bool
    | SRows { order : List Int, next : Int }
    | SDate DatePicker.State
    | SPeriod DateRangePicker.State
    | SMoney MoneyInput.State
    | SMasked MaskedInput.State


{-| What the form knows about one field without knowing its types.
-}
type alias Def =
    { key : String
    , label : String
    , hint : Maybe String
    , required : Bool
    , initial : Raw
    , limits : Limits
    , step : Int
    , rows : Maybe RowsPlan
    }


{-| A repeating group: what one row is, as a function of the prefix of the
row's DOM ids.
-}
type RowsPlan
    = RowsPlan
        { item : String
        , minimum : Int
        , defsAt : String -> List Def
        , conditionsAt : String -> List Condition
        , liveAt : String -> Locale -> Data -> List Found
        }


type Origin
    = FromRule
    | FromServer
    | FromOutside


type alias Diagnosis =
    { field : String
    , target : String
    , label : String
    , message : String
    , step : Int
    , origin : Origin
    }



-- DECLARING


{-| Starts a declaration. The text is the prefix of the DOM ids of the fields
(`"supplier"` gives `supplier-name`, `supplier-legal-name` ...) and of the
summary; it must be different for every form on the page. The other two
arguments are the record constructors `Fields` and `Values`. (A form that is
only used as the rows of another form gets its prefix from the group: the text
is not used.)

    Fm.define "supplier" Fields Values
        |> Fm.with (Fm.text "Name")
        |> Fm.build

-}
define : String -> fields -> values -> Builder step fields values
define prefix fieldsConstructor valuesConstructor =
    Builder
        { prefix = prefix
        , used = Set.empty
        , steps = []
        , current = 0
        , makers = []
        , fieldsAt = \_ -> fieldsConstructor
        , readAt = \_ _ _ -> Ok valuesConstructor
        , conditionsAt = \_ -> []
        , liveAt = \_ _ _ -> []
        }


{-| Adds the next field. It fills the next argument of `Fields` with its handle
and the next argument of `Values` with its output. The DOM id is made from the
form's prefix and the label (`Legal name` becomes `supplier-legal-name`); a
repeated label gets `-2`, `-3` ... so two ids never clash.
-}
with : Spec control output -> Builder step (Field control -> f) (output -> v) -> Builder step f v
with (Spec spec) (Builder b) =
    let
        local =
            uniqueLocal spec.label b.used

        keyAt prefix =
            prefix ++ "-" ++ local

        maker prefix =
            { key = keyAt prefix
            , label = spec.label
            , hint = spec.hint
            , required = spec.required
            , initial = spec.toRaw spec.empty
            , limits = spec.limits
            , step = b.current
            , rows = spec.rows
            }

        handleAt prefix =
            Field
                { key = keyAt prefix
                , label = spec.label
                , empty = spec.empty
                , toRaw = spec.toRaw
                , fromData = spec.fromData (keyAt prefix)
                , plan = spec.rows
                }

        readAt prefix locale data =
            case ( b.readAt prefix locale data, spec.read (keyAt prefix) locale data ) of
                ( Ok constructor, Ok output ) ->
                    Ok (constructor output)

                ( Err found, Ok _ ) ->
                    Err found

                ( Ok _, Err found ) ->
                    Err found

                ( Err before, Err found ) ->
                    Err (before ++ found)
    in
    Builder
        { prefix = b.prefix
        , used = Set.insert local b.used
        , steps = b.steps
        , current = b.current
        , makers = maker :: b.makers
        , fieldsAt = \prefix -> b.fieldsAt prefix (handleAt prefix)
        , readAt = readAt
        , conditionsAt = b.conditionsAt
        , liveAt = b.liveAt
        }


{-| The fields that follow are on this step. The step is a value of the
application's own type, and the text is its label in the stepper and in the
review list. Declare the steps in order, before their fields. A step with no
fields of its own is the review step: its summary lists every problem of every
step.

    Fm.define "supplier" Fields Values
        |> Fm.step Company "Company"
        |> Fm.with (Fm.text "Name" |> Fm.required)
        |> Fm.step Review "Review"
        |> Fm.build

-}
step : step -> String -> Builder step fields values -> Builder step fields values
step value label (Builder b) =
    Builder
        { b
            | steps = b.steps ++ [ { step = value, label = label } ]
            , current = List.length b.steps
        }


{-| A rule over several fields, run when every field of the form is valid on its
own. On a form with steps that means it shows up when the last step is reached;
a rule that belongs to one step goes on the field (`rule`, for a list of rows) or
on the sub-form of a group, which is checked row by row. It
gets the handles, the state (to find the rows of a group with `rowFields`) and
the values, and returns the problems it finds, each tied to a field with
`problem`. Put it last, after the `with` calls: it is a compile error before.

    Fm.define "supplier" Fields Values
        |> Fm.with (Fm.rows { label = "Contacts", item = "Contact" } contact)
        |> Fm.check
            (\f state _ ->
                Fm.rowFields f.contacts state
                    |> List.filter (\row -> Fm.get row.primary state)
                    |> List.drop 1
                    |> List.map (\row -> Fm.problem row.primary "Only one contact can be the primary.")
            )
        |> Fm.build

-}
check : (fields -> State step -> values -> List (Problem step)) -> Builder step fields values -> Builder step fields values
check verdict (Builder b) =
    Builder
        { b
            | readAt =
                \prefix locale data ->
                    case b.readAt prefix locale data of
                        Ok values ->
                            case verdict (b.fieldsAt prefix) (State data) values of
                                [] ->
                                    Ok values

                                found ->
                                    Err (List.map (\p -> { field = p.field, target = p.field, label = p.label, message = p.message }) found)

                        Err found ->
                            Err found
        }


{-| The field is part of the form only while the condition holds: a VAT number
for a company, a delivery address when "ship elsewhere" is on. While it does not,
the field is not drawn (its view is empty), its problems are left out, and the
values get its empty value (`Nothing`, `[]`, `False`), whatever was typed in it.
What was typed is kept, so it comes back when the condition holds again.
Declare such a field without `required`, so that its output can be empty, and
add `requiredWhen` with the same condition to require it while it is shown. Put
it after the `with` calls, like `check`.

    Fm.define "customer" Fields Values
        |> Fm.with (Fm.choice kindIds "Customer kind" |> Fm.required)
        |> Fm.with (Fm.masked MaskedInput.norwegianOrganisationNumber "Organisation number")
        |> Fm.shownWhen isCompany .organisationNumber
        |> Fm.requiredWhen isCompany .organisationNumber
        |> Fm.build

    isCompany : Fields -> Fm.State () -> Bool
    isCompany handles state =
        Fm.get handles.kind state == Just Company

-}
shownWhen : (fields -> State step -> Bool) -> (fields -> Field c) -> Builder step fields values -> Builder step fields values
shownWhen holds pick =
    addCondition ShownWhen holds pick


{-| The field is required while the condition holds: it gets the `*` of a
required field, and an empty value is the problem "Required". Its output keeps
its type (declare it without `required`, so it can be empty when the condition
does not hold). Put it after the `with` calls; see `shownWhen`.
-}
requiredWhen : (fields -> State step -> Bool) -> (fields -> Field c) -> Builder step fields values -> Builder step fields values
requiredWhen holds pick =
    addCondition RequiredWhen holds pick


addCondition : ConditionKind -> (fields -> State step -> Bool) -> (fields -> Field c) -> Builder step fields values -> Builder step fields values
addCondition kind holds pick (Builder b) =
    let
        conditionAt prefix =
            let
                handles =
                    b.fieldsAt prefix

                (Field field) =
                    pick handles
            in
            { key = field.key, kind = kind, holds = \data -> holds handles (State data) }
    in
    Builder { b | conditionsAt = \prefix -> b.conditionsAt prefix ++ [ conditionAt prefix ] }


{-| A rule over several fields that runs at once, without waiting for the rest of
the form: "the end date is after the start date", "the confirmation matches the
email". It gets the locale, the handles and the state, reads the fields with
`get` (so it sees `Nothing` for an empty field and says nothing then), and
returns the problems it finds, each tied to a field with `problem`. A problem
belongs to the step of its field: it shows there once the field was left or
edited, and it keeps the user on that step. Use `check` instead for a rule that
needs the whole record of values. Put it after the `with` calls.

    Fm.define "booking" Fields Values
        |> Fm.with (Fm.date "From" |> Fm.required)
        |> Fm.with (Fm.date "To" |> Fm.required)
        |> Fm.checkFields
            (\locale f state ->
                case ( Fm.get f.from state, Fm.get f.to state ) of
                    ( Just from, Just to ) ->
                        if Date.compare to from == LT then
                            [ Fm.problem f.to (Locale.pick locale { nb = "Til kan ikke være før fra", en = "To cannot be before from" }) ]

                        else
                            []

                    _ ->
                        []
            )
        |> Fm.build

-}
checkFields : (Locale -> fields -> State step -> List (Problem step)) -> Builder step fields values -> Builder step fields values
checkFields verdict (Builder b) =
    Builder
        { b
            | liveAt =
                \prefix locale data ->
                    b.liveAt prefix locale data
                        ++ (verdict locale (b.fieldsAt prefix) (State data)
                                |> List.map (\p -> { field = p.field, target = p.field, label = p.label, message = p.message })
                           )
        }


{-| Finishes the declaration. The result only has the type
`Form step Fields Values` when every `with` matched an argument of both records;
a field missing from one of them is a compile error.
-}
build : Builder step fields values -> Form step fields values
build (Builder b) =
    Form
        { prefix = b.prefix
        , steps = b.steps
        , defsAt = \prefix -> List.map (\make_ -> make_ prefix) (List.reverse b.makers)
        , fieldsAt = b.fieldsAt
        , readAt = b.readAt
        , conditionsAt = b.conditionsAt
        , liveAt = b.liveAt
        }


{-| The handles of the form's fields, as the `Fields` record. A constant: bind
it once at the top level of the module.
-}
fields : Form step fields values -> fields
fields (Form form) =
    form.fieldsAt form.prefix


uniqueLocal : String -> Set String -> String
uniqueLocal label used =
    let
        base =
            slug label

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


rowPrefix : String -> Int -> String
rowPrefix key id =
    key ++ "-" ++ String.fromInt id



-- KINDS


{-| A line of text. Blank is `Nothing` in the output, and the output is trimmed
(the display is not: nothing is changed behind the user's back). Add `required`
to get a `String`. Draw it with `textInput`, or with `textArea` for a long note.
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


{-| Free-form tags, drawn by `tagInput`: type a word, press Enter, get a chip. The
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


{-| Files the user chose or dropped, drawn by `fileDrop`. Empty is `[]`. Files the
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


{-| A date, typed or picked in a calendar, drawn by `datePicker`. Empty is
`Nothing`. Add `required`, `minDate` or `maxDate`. Text that is not a date is
the problem "Invalid date" until it is fixed.
-}
date : String -> Spec (Maybe Date) (Maybe Date)
date label =
    makeRefusing (\locale -> Locale.pick locale { nb = "Ugyldig dato", en = "Invalid date" })
        label
        Nothing
        RDate
        (\raw ->
            case raw of
                RDate value ->
                    Just value

                RUnreadable ->
                    Just Nothing

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


{-| A period from one date to another, both included, drawn by
`dateRangePicker`. Empty is `Nothing`. Add `required`. Text that is not a date,
or an end before the start, is the problem "Invalid period" until it is fixed.
-}
dateRange : String -> Spec (Maybe ( Date, Date )) (Maybe ( Date, Date ))
dateRange label =
    makeRefusing (\locale -> Locale.pick locale { nb = "Ugyldig periode", en = "Invalid period" })
        label
        Nothing
        RPeriod
        (\raw ->
            case raw of
                RPeriod value ->
                    Just value

                RUnreadable ->
                    Just Nothing

                _ ->
                    Nothing
        )
        (\_ value -> Ok value)


{-| An amount of money in one currency, drawn by `moneyInput`. Empty is
`Nothing`. A negative amount is refused unless `minMoney` is below zero. Add
`required`, `minMoney` or `maxMoney`.
-}
money : Currency -> String -> Spec (Maybe Money) (Maybe Money)
money currency label =
    let
        (Spec spec) =
            makeRefusing (\locale -> Locale.pick locale { nb = "Må være et gyldig beløp", en = "Must be an amount" })
                label
                Nothing
                RMoney
                (\raw ->
                    case raw of
                        RMoney value ->
                            Just value

                        RUnreadable ->
                            Just Nothing

                        _ ->
                            Nothing
                )
                (\_ value -> Ok value)

        limits =
            spec.limits
    in
    Spec { spec | limits = { limits | currency = Just currency } }


{-| An identifier with a fixed shape (an organisation number, an IBAN, a postal
code), drawn by `maskedInput`. The value is the identifier without separators
(`MaskedInput.value`); empty is `Nothing`. An identifier that is not complete
or has a wrong check digit is the problem "Incomplete or invalid" until it is
fixed. Add `required`.
-}
masked : MaskedInput.Mask -> String -> Spec (Maybe String) (Maybe String)
masked mask label =
    let
        (Spec spec) =
            makeRefusing (\locale -> Locale.pick locale { nb = "Ufullstendig eller ugyldig", en = "Incomplete or invalid" })
                label
                Nothing
                RMasked
                (\raw ->
                    case raw of
                        RMasked value ->
                            Just value

                        RUnreadable ->
                            Just Nothing

                        _ ->
                            Nothing
                )
                (\_ value -> Ok value)

        limits =
            spec.limits
    in
    Spec { spec | limits = { limits | mask = Just mask } }


{-| The conditions of a rule, edited in a rule builder.

    Fm.conditions "Conditions" priceFields |> Fm.required

-}
conditions : String -> List (Rule.Field ()) -> Spec Rule.Rule (Maybe Rule.Rule)
conditions label ruleFields =
    Spec
        { label = label
        , hint = Nothing
        , required = False
        , empty = Rule.emptyGroup
        , toRaw = RRule
        , fromData = \key data -> ruleIn key data
        , limits = noLimits
        , rows = Nothing
        , few = \locale _ -> Locale.pick locale { nb = "Legg til en betingelse", en = "Add a condition" }
        , read =
            \key locale data ->
                case Dict.get key data.slots of
                    Just (SRule state) ->
                        case RuleBuilder.issues locale ruleFields state of
                            issue :: _ ->
                                Err [ { field = key, target = RuleBuilder.focusId ruleFields state issue.nodeId, label = label, message = issue.message } ]

                            [] ->
                                if Rule.isEmpty (RuleBuilder.rule state) then
                                    Ok Nothing

                                else
                                    Ok (Just (RuleBuilder.rule state))

                    _ ->
                        Ok Nothing
        , reword = Nothing
        }


ruleIn : String -> Data -> Rule.Rule
ruleIn key data =
    case lookup key data of
        Just (RRule rule_) ->
            rule_

        _ ->
            Rule.emptyGroup


{-| A repeating group, such as the contacts of a supplier: every row has the
fields of the form you give, declared once. The `label` names the group (in the
summary, "Add at least 1" and the like), the `item` names one row ("Contact":
the summary says "Contact 2, Email: Required" and the remove button "Remove
contact 2"). The output is the list of the rows' values, in the order of the
rows. `atLeast n` requires n rows and starts the form with n empty rows. Draw
the rows with `rowFields`, the buttons with `addRow` and `removeRow`.

    contact : Fm.Form () ContactFields Contact
    contact =
        Fm.define "contact" ContactFields Contact
            |> Fm.with (Fm.text "Name" |> Fm.required)
            |> Fm.with (Fm.text "Email" |> Fm.required |> Fm.rules [ Validate.email ])
            |> Fm.build

    Fm.rows { label = "Contacts", item = "Contact" } contact |> Fm.atLeast 1

**Keys of the rows.** Every row gets a number when it is added, and the number
stays with the row for as long as it lives: `supplier-contacts-3-email` is the
same row's field after rows 1 and 2 are removed, and a number is never used
twice. Positions ("Contact 2") are only for the words and for problems from the
server. This keeps the state of a select or tag field with its row, makes a
removed row's problems go with it, and lets an application keep a handle.

-}
rows : { label : String, item : String } -> Form () rowFields rowValues -> Spec (Rows rowFields) (List rowValues)
rows names (Form sub) =
    Spec
        { label = names.label
        , hint = Nothing
        , required = False
        , empty = Rows []
        , toRaw = \_ -> RRows []
        , fromData = \key data -> Rows (List.map (\id -> sub.fieldsAt (rowPrefix key id)) (rowIds key data))
        , limits = noLimits
        , rows = Just (RowsPlan { item = names.item, minimum = 0, defsAt = sub.defsAt, conditionsAt = sub.conditionsAt, liveAt = sub.liveAt })
        , few = \locale n -> Locale.pick locale { nb = "Legg til minst " ++ String.fromInt n, en = "Add at least " ++ String.fromInt n }
        , read =
            \key locale data ->
                rowIds key data
                    |> List.indexedMap
                        (\position id ->
                            sub.readAt (rowPrefix key id) locale data
                                |> Result.mapError (List.map (inRow names.item position))
                        )
                    |> collect
        , reword = Nothing
        }


inRow : String -> Int -> Found -> Found
inRow item position found =
    { found | label = rowLabel item position found.label }


rowLabel : String -> Int -> String -> String
rowLabel item position label =
    item ++ " " ++ String.fromInt (position + 1) ++ ", " ++ label


collect : List (Result (List Found) a) -> Result (List Found) (List a)
collect results =
    List.foldr
        (\result acc ->
            case ( result, acc ) of
                ( Ok value, Ok values ) ->
                    Ok (value :: values)

                ( Err found, Ok _ ) ->
                    Err found

                ( Ok _, Err found ) ->
                    Err found

                ( Err first, Err rest ) ->
                    Err (first ++ rest)
        )
        (Ok [])
        results


noLimits : Limits
noLimits =
    { min = Nothing
    , max = Nothing
    , decimals = Nothing
    , earliest = Nothing
    , latest = Nothing
    , lowest = Nothing
    , highest = Nothing
    , currency = Nothing
    , mask = Nothing
    }


make : String -> control -> (control -> Raw) -> (Raw -> Maybe control) -> (Locale -> control -> Result String output) -> Spec control output
make =
    makeRefusing (\locale -> Locale.pick locale { nb = "Må være et tall", en = "Must be a number" })


{-| A kind whose control can hold text that is no value: `refusal` is the
problem while it does (`RUnreadable`).
-}
makeRefusing : (Locale -> String) -> String -> control -> (control -> Raw) -> (Raw -> Maybe control) -> (Locale -> control -> Result String output) -> Spec control output
makeRefusing refusal label empty toRaw fromRaw finish =
    Spec
        { label = label
        , hint = Nothing
        , required = False
        , empty = empty
        , toRaw = toRaw
        , fromData = \key data -> lookup key data |> Maybe.andThen fromRaw |> Maybe.withDefault empty
        , limits = noLimits
        , rows = Nothing
        , few = \locale n -> Locale.pick locale { nb = "Velg minst " ++ String.fromInt n, en = "Choose at least " ++ String.fromInt n }
        , read =
            \key locale data ->
                let
                    raw =
                        lookup key data |> Maybe.withDefault (toRaw empty)

                    refuse message =
                        Err [ { field = key, target = key, label = label, message = message } ]
                in
                case raw of
                    RUnreadable ->
                        refuse (refusal locale)

                    RFiles _ True ->
                        refuse (Locale.pick locale { nb = "Fjern filen som ble avvist", en = "Remove the refused file" })

                    _ ->
                        finish locale (fromRaw raw |> Maybe.withDefault empty)
                            |> Result.mapError (\message -> [ { field = key, target = key, label = label, message = message } ])
        , reword = Nothing
        }


lookup : String -> Data -> Maybe Raw
lookup key data =
    Dict.get key data.slots |> Maybe.map rawOf


rowIds : String -> Data -> List Int
rowIds key data =
    case Dict.get key data.slots of
        Just (SRows group) ->
            group.order

        _ ->
            []



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
        , fromData = spec.fromData
        , limits = spec.limits
        , rows = spec.rows
        , few = spec.few
        , read =
            \key locale data ->
                case spec.read key locale data of
                    Ok (Just output) ->
                        Ok output

                    Ok Nothing ->
                        Err [ { field = key, target = key, label = spec.label, message = message locale } ]

                    Err found ->
                        Err found
        , reword = Just (\replacement -> requiredWith replacement (Spec spec))
        }


{-| A list with at least this many items. It is required, and the message says
how many. On a `rows` group it also starts the form with that many empty rows.

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
            , rows = Maybe.map (\(RowsPlan plan) -> RowsPlan { plan | minimum = n }) spec.rows
            , read =
                \key locale data ->
                    case spec.read key locale data of
                        Ok list ->
                            if List.length list < n then
                                Err [ { field = key, target = key, label = spec.label, message = message locale } ]

                            else
                                Ok list

                        Err found ->
                            Err found
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
        , fromData = spec.fromData
        , limits = spec.limits
        , rows = spec.rows
        , few = spec.few
        , read =
            \key locale data ->
                case spec.read key locale data of
                    Ok [] ->
                        Ok Nothing

                    Ok [ single ] ->
                        Ok (Just single)

                    Ok _ ->
                        Err [ { field = key, target = key, label = spec.label, message = message locale } ]

                    Err found ->
                        Err found
        , reword = Just (\replacement -> oneWith replacement (Spec spec))
        }


{-| A rule on the value the field produces, for what the kind and the other rules
cannot say: a quantity in whole boxes of 6, a box that must be ticked, at most one
contact that is the primary. It runs when the field's own read succeeded (so after
`required`, a refused text and the limits), and a problem is the field's own: it
shows at the field and counts on its step like any other rule. On a group of rows
it sees the list of the rows' values and its problem shows by the add button. The
message is a function of the locale, like `withMessage`.

    Spec.toggle "I accept the terms of delivery"
        |> Spec.rule identity
            (\lang -> Locale.pick lang { nb = "Du må godta vilkårene", en = "Accept the terms to go on" })

    Spec.rows { label = "Contacts", item = "Contact" } contact
        |> Spec.rule
            (\contacts -> List.length (List.filter .primary contacts) <= 1)
            (\lang -> Locale.pick lang { nb = "Bare én kan være hovedkontakt", en = "Only one contact can be the primary" })

-}
rule : (o -> Bool) -> (Locale -> String) -> Spec c o -> Spec c o
rule holds message (Spec spec) =
    Spec
        { spec
            | read =
                \key locale data ->
                    case spec.read key locale data of
                        Ok output ->
                            if holds output then
                                Ok output

                            else
                                Err [ { field = key, target = key, label = spec.label, message = message locale } ]

                        Err found ->
                            Err found
            , reword = Just (\replacement -> rule holds replacement (Spec spec))
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
addCheck verdict (Spec spec) =
    Spec
        { spec
            | read =
                \key locale data ->
                    case spec.read key locale data of
                        Err found ->
                            Err found

                        Ok output ->
                            case verdict locale (spec.fromData key data) of
                                Just message ->
                                    Err [ { field = key, target = key, label = spec.label, message = message } ]

                                Nothing ->
                                    Ok output
            , reword =
                Just
                    (\replacement ->
                        addCheck (\locale value -> verdict locale value |> Maybe.map (\_ -> replacement locale))
                            (Spec spec)
                    )
        }


{-| A number from `low` to `high`, both included. The control shows the limits
and keeps a number outside them as typed (it shows the problem, it does not move
the number). The message writes the numbers as the locale does (`1,5` in
Norwegian).
-}
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
range low high spec =
    addCheck
        (\locale value ->
            case value of
                Just n ->
                    if n < low || n > high then
                        Just
                            (Locale.pick locale
                                { nb = "Må være mellom " ++ formatNumber locale low ++ " og " ++ formatNumber locale high
                                , en = "Must be between " ++ formatNumber locale low ++ " and " ++ formatNumber locale high
                                }
                            )

                    else
                        Nothing

                Nothing ->
                    Nothing
        )
        spec
        |> keeping (\data -> { data | limits = setNumberLimits low high data.limits })


setNumberLimits : Float -> Float -> Limits -> Limits
setNumberLimits low high limits =
    { limits | min = Just low, max = Just high }


{-| A number as people write it in the locale, with the decimals it has.
-}
formatNumber : Locale -> Float -> String
formatNumber locale value =
    let
        places =
            case String.split "." (String.fromFloat value) of
                [ _, fraction ] ->
                    Basics.min 6 (String.length fraction)

                _ ->
                    0
    in
    Format.decimal locale places value


{-| A whole number: no decimals, shown and checked.
-}
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
whole spec =
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
        spec
        |> keeping (\data -> { data | limits = setDecimals data.limits })


setDecimals : Limits -> Limits
setDecimals limits =
    { limits | decimals = Just 0 }


{-| The earliest date the field takes, included. The calendar does not offer
the days before it, a typed date before it is refused at once, and a date put
in with `set` (a loaded record) is the problem "The date cannot be before ..."
until it is changed. A limit that depends on today belongs to the view:
`DatePicker.min model.today` (the declaration is a constant).

    Spec.date "Delivery date" |> Spec.required |> Spec.minDate firstDeliveryDay

-}
minDate : Date -> Spec (Maybe Date) o -> Spec (Maybe Date) o
minDate earliest =
    keeping (\data -> { data | limits = setEarliest earliest data.limits })


setEarliest : Date -> Limits -> Limits
setEarliest earliest limits =
    { limits | earliest = Just earliest }


{-| The latest date the field takes, included, in the same way as `minDate`.
-}
maxDate : Date -> Spec (Maybe Date) o -> Spec (Maybe Date) o
maxDate latest =
    keeping (\data -> { data | limits = setLatest latest data.limits })


setLatest : Date -> Limits -> Limits
setLatest latest limits =
    { limits | latest = Just latest }


{-| The lowest amount the field takes, included, in the currency of the field. An
amount below it is kept as typed and is the problem "Must be at least ...". A
lowest amount below zero allows negative amounts down to it; without one, an
amount must not be negative.

    Spec.money Money.nok "Credit limit" |> Spec.minMoney (Money.zero Money.nok)

-}
minMoney : Money -> Spec (Maybe Money) o -> Spec (Maybe Money) o
minMoney lowest =
    keeping (\data -> { data | limits = setLowest lowest data.limits })


setLowest : Money -> Limits -> Limits
setLowest lowest limits =
    { limits | lowest = Just lowest }


{-| The highest amount the field takes, included, in the same way as `minMoney`.
-}
maxMoney : Money -> Spec (Maybe Money) o -> Spec (Maybe Money) o
maxMoney highest =
    keeping (\data -> { data | limits = setHighest highest data.limits })


setHighest : Money -> Limits -> Limits
setHighest highest limits =
    { limits | highest = Just highest }


{-| A short help text under the field.
-}
hint : String -> Spec c o -> Spec c o
hint help =
    keeping (\data -> { data | hint = Just help })


{-| Changes what the declaration says about the field, in a way that a later
`withMessage` keeps: the rule before is reworded and the change made again on
the result (without this, `hint` or `range` followed by `withMessage` would be
undone by it).
-}
keeping : (SpecData c o -> SpecData c o) -> Spec c o -> Spec c o
keeping change (Spec spec) =
    let
        changed =
            change spec
    in
    Spec { changed | reword = Maybe.map (\reword message -> keeping change (reword message)) spec.reword }


{-| The problem of a date or an amount outside the limits of its field, or of a
negative amount where none is allowed. The limits are data in the declaration,
so one check serves every kind that has them.
-}
limitProblem : Locale -> Limits -> Raw -> Maybe String
limitProblem locale limits raw =
    case raw of
        RDate (Just day) ->
            case ( limits.earliest, limits.latest ) of
                ( Just earliest, _ ) ->
                    if Date.compare day earliest == LT then
                        Just
                            (Locale.pick locale
                                { nb = "Datoen kan ikke være før " ++ Format.date locale earliest
                                , en = "The date cannot be before " ++ Format.date locale earliest
                                }
                            )

                    else
                        latestProblem locale limits.latest day

                ( Nothing, latest ) ->
                    latestProblem locale latest day

        RMoney (Just amount) ->
            moneyProblem locale limits amount

        _ ->
            Nothing


latestProblem : Locale -> Maybe Date -> Date -> Maybe String
latestProblem locale latest day =
    case latest of
        Just bound ->
            if Date.compare day bound == GT then
                Just
                    (Locale.pick locale
                        { nb = "Datoen kan ikke være etter " ++ Format.date locale bound
                        , en = "The date cannot be after " ++ Format.date locale bound
                        }
                    )

            else
                Nothing

        Nothing ->
            Nothing


moneyProblem : Locale -> Limits -> Money -> Maybe String
moneyProblem locale limits amount =
    let
        sameCurrency bound =
            if Money.currencyOf bound == Money.currencyOf amount then
                Just bound

            else
                Nothing

        low =
            Maybe.andThen sameCurrency limits.lowest

        high =
            Maybe.andThen sameCurrency limits.highest

        negativeAllowed =
            Maybe.map Money.isNegative limits.lowest |> Maybe.withDefault False

        below =
            Maybe.map (\bound -> Money.compare amount bound == LT) low |> Maybe.withDefault False

        above =
            Maybe.map (\bound -> Money.compare amount bound == GT) high |> Maybe.withDefault False

        shown bound =
            Money.toAmountString locale bound ++ "\u{00A0}" ++ Money.currencyCode (Money.currencyOf bound)
    in
    if Money.isNegative amount && not negativeAllowed then
        Just (Locale.pick locale { nb = "Beløpet kan ikke være negativt", en = "Must not be negative" })

    else if below || above then
        case ( low, high ) of
            ( Just lowBound, Just highBound ) ->
                Just
                    (Locale.pick locale
                        { nb = "Må være mellom " ++ Money.toAmountString locale lowBound ++ " og " ++ shown highBound
                        , en = "Must be between " ++ Money.toAmountString locale lowBound ++ " and " ++ shown highBound
                        }
                    )

            ( Just lowBound, Nothing ) ->
                Just (Locale.pick locale { nb = "Må være minst " ++ shown lowBound, en = "Must be at least " ++ shown lowBound })

            ( Nothing, Just highBound ) ->
                Just (Locale.pick locale { nb = "Må være maksimalt " ++ shown highBound, en = "Must be at most " ++ shown highBound })

            ( Nothing, Nothing ) ->
                Nothing

    else
        Nothing


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



-- SLOTS


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

        RTags _ ->
            STags (TagInput.init def.key)

        RFiles _ _ ->
            SFiles (FileDrop.init def.key)

        RRule _ ->
            SRule (RuleBuilder.init def.key)

        RRows _ ->
            SRows { order = [], next = 1 }

        RDate _ ->
            SDate (DatePicker.init def.key)

        RPeriod _ ->
            SPeriod (DateRangePicker.init def.key)

        RMoney _ ->
            SMoney
                (MoneyInput.init def.key (Maybe.withDefault Money.nok def.limits.currency)
                    |> MoneyInput.setLimits (moneyLimits def.limits)
                )

        RMasked _ ->
            SMasked (MaskedInput.init def.key (Maybe.withDefault MaskedInput.phone def.limits.mask))


{-| The slots of a list of fields, with the empty rows a group starts with.
-}
seed : List Def -> Dict String Slot
seed defs =
    List.foldl (\def all -> Dict.union (seedOne def) all) Dict.empty defs


seedOne : Def -> Dict String Slot
seedOne def =
    case def.rows of
        Nothing ->
            Dict.singleton def.key (newSlot def)

        Just (RowsPlan plan) ->
            let
                ids =
                    List.range 1 plan.minimum
            in
            seed (List.concatMap (\id -> plan.defsAt (rowPrefix def.key id)) ids)
                |> Dict.insert def.key (SRows { order = ids, next = plan.minimum + 1 })


numberLimits : Limits -> List (NumberInput.Attribute msg)
numberLimits limits =
    List.filterMap identity
        [ Maybe.map NumberInput.min limits.min
        , Maybe.map NumberInput.max limits.max
        ]


dateLimits : Limits -> List DatePicker.Attribute
dateLimits limits =
    List.filterMap identity
        [ Maybe.map DatePicker.min limits.earliest
        , Maybe.map DatePicker.max limits.latest
        ]


{-| The limits of an amount as the field's own attributes, so that the field
says what the form says: a negative amount is allowed when the lowest amount is
below zero.
-}
moneyLimits : Limits -> List (MoneyInput.Attribute msg)
moneyLimits limits =
    List.filterMap identity
        [ Maybe.map MoneyInput.min limits.lowest
        , Maybe.map MoneyInput.max limits.highest
        , if Maybe.map Money.isNegative limits.lowest |> Maybe.withDefault False then
            Just MoneyInput.allowNegative

          else
            Nothing
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
            RTags (TagInput.values state)

        SFiles state ->
            RFiles (FileDrop.values state) (FileDrop.hasProblems state)

        SRule state ->
            RRule (RuleBuilder.rule state)

        SToggle value ->
            RBool value

        SRows group ->
            RRows group.order

        SDate state ->
            if DatePicker.isInvalid state then
                RUnreadable

            else
                RDate (DatePicker.date state)

        SPeriod state ->
            if DateRangePicker.isInvalid state then
                RUnreadable

            else
                RPeriod (DateRangePicker.range state)

        SMoney state ->
            -- every sign allowed and no limits: `isValid` then only asks whether the text is an amount
            if MoneyInput.isValid (MoneyInput.setLimits [ MoneyInput.allowNegative ] state) then
                RMoney (MoneyInput.value state)

            else
                RUnreadable

        SMasked state ->
            if MaskedInput.isValid state then
                RMasked (MaskedInput.value state)

            else
                RUnreadable


putRaw : Raw -> Slot -> Slot
putRaw raw slot =
    case ( raw, slot ) of
        ( RText value, SText _ ) ->
            SText value

        ( RKey key, SSelect state ) ->
            SSelect (Select.setValue key state)

        ( RKeys keys, SMulti state ) ->
            SMulti (MultiSelect.setValues keys state)

        ( RNumber value, SNumber state ) ->
            SNumber (NumberInput.setValue value state)

        ( RTags value, STags state ) ->
            STags (TagInput.setValues value state)

        ( RFiles value _, SFiles state ) ->
            SFiles (FileDrop.setValues value state)

        ( RRule value, SRule state ) ->
            SRule (RuleBuilder.setRule value state)

        ( RBool value, SToggle _ ) ->
            SToggle value

        ( RDate value, SDate state ) ->
            SDate (DatePicker.setDate value state)

        ( RPeriod value, SPeriod state ) ->
            SPeriod (DateRangePicker.setRange value state)

        ( RMoney value, SMoney state ) ->
            SMoney (MoneyInput.setValue value state)

        ( RMasked value, SMasked state ) ->
            SMasked (MaskedInput.setValue value state)

        _ ->
            slot



-- VALUES


{-| A form with every field empty, nothing touched, the first step, a group of
rows with its minimum number of empty rows, and that state as the baseline. Each
field's component gets its DOM id here.
-}
init : Form step fields values -> State step
init (Form form) =
    let
        slots =
            seed (form.defsAt form.prefix)
    in
    State
        { slots = slots
        , baseline = Dict.map (\_ slot -> stable (rawOf slot)) slots
        , touched = Set.empty
        , server = Dict.empty
        , outside = []
        , current = 0
        , attempted = Set.empty
        }


{-| Puts a value in a field, for every kind of field. The type of the handle
decides what is accepted: a select takes a `Maybe CountryId`, a switch a `Bool`.
Use it to load a record. A select shows its label as soon as its options have
arrived; `get` returns the value at once. The rows of a group are loaded with
`fillRows`.

    Fm.init form
        |> Fm.set f.name "Acme Supplies"
        |> Fm.set f.country (Just (CountryId "no"))
        |> Fm.markClean

-}
set : Field c -> c -> State step -> State step
set (Field field) value (State data) =
    State { data | slots = Dict.update field.key (Maybe.map (putRaw (field.toRaw value))) data.slots }


{-| The value of a field as it is edited: `Nothing` for an empty select, `[]` for
an empty multi select, the text as typed.
-}
get : Field c -> State step -> c
get (Field field) (State data) =
    field.fromData data


{-| The browser's `File` values of the accepted files of a `files` field, for the
request the application makes. A file loaded with `set` has none.
-}
rawFiles : Field (List FileDrop.FileInfo) -> State step -> List File
rawFiles (Field field) (State data) =
    case Dict.get field.key data.slots of
        Just (SFiles state) ->
            FileDrop.rawFiles state

        _ ->
            []


{-| The search text of a `select` or `multiSelect` field while its list is open,
and `""` otherwise or for any other kind. With `Select.serverSearch` among the
attributes, fetch the options when it changes: compare it before and after
`update`. It follows the box after a pause of 300 ms in the typing, so write no
debounce of your own.

    FormMsg inner ->
        let
            ( state, cmd ) =
                Fm.update form inner model.form
        in
        if Fm.query fields.customer state /= Fm.query fields.customer model.form then
            ( { model | form = state, customers = Remote.Loading }
            , Cmd.batch [ Cmd.map FormMsg cmd, searchCustomers (Fm.query fields.customer state) ]
            )

        else
            ( { model | form = state }, Cmd.map FormMsg cmd )

-}
query : Field c -> State step -> String
query (Field field) (State data) =
    case Dict.get field.key data.slots of
        Just (SSelect state) ->
            Select.query state

        Just (SMulti state) ->
            MultiSelect.query state

        _ ->
            ""


{-| Puts a value in a `choice` field together with its option, so that the field
shows the option's label also when the options it is drawn with do not have it:
a saved customer in a select that searches the server, whose options are only
the latest hits. For a select with all its options, `set` is enough.

    Fm.setOption fields.customer (Select.option order.customerId order.customerName) state

-}
setOption : Field (Maybe id) -> Select.Option id -> State step -> State step
setOption (Field field) choice_ (State data) =
    State
        { data
            | slots =
                Dict.update field.key
                    (Maybe.map
                        (\slot ->
                            case slot of
                                SSelect state ->
                                    SSelect (Select.setOption (Select.mapOption (keyOf field.toRaw << Just) choice_) state)

                                other ->
                                    other
                        )
                    )
                    data.slots
        }


{-| The DOM id of the element that takes the focus for a field: its control, the
add button of a group of rows, or the first button of a rule builder. For
`Modal.openWith` and `Drawer.openWith`, which take the DOM ids to focus when they
open; to move the focus in an update, `focus` does it for you.

    Drawer.openWith { opener = "edit-customer", focus = [ Fm.domId fields.name ] } model.drawer

-}
domId : Field c -> String
domId (Field field) =
    case field.toRaw field.empty of
        RRule _ ->
            RuleBuilder.focusId [] (RuleBuilder.init field.key) 0

        _ ->
            field.key


{-| The handles of the rows a group has now, in order. Draw one card of fields
for each; the position is for the words ("Contact 2"). A handle is the row's
own: it stays right when other rows are added or removed, and stops working when
its row is removed.

    Fm.rowFields f.contacts model.form
        |> List.indexedMap (\i row -> contactCard v i row)

-}
rowFields : Field (Rows rowFields) -> State step -> List rowFields
rowFields field state =
    case get field state of
        Rows handles ->
            handles


{-| Loads a list of records into the rows of a group: the rows that are there are
replaced by one new row for each item, and `fill` puts the item in the row's
fields. Like `set`, it does not change the baseline; call `markClean` after a
load.

    Fm.fillRows f.contacts
        (\contact row ->
            Fm.set row.name contact.name
                >> Fm.set row.email contact.email
        )
        supplier.contacts

-}
fillRows : Field (Rows rowFields) -> (a -> rowFields -> State step -> State step) -> List a -> State step -> State step
fillRows ((Field field) as handle) fill items (State data) =
    case field.plan of
        Nothing ->
            State data

        Just (RowsPlan plan) ->
            let
                next =
                    case Dict.get field.key data.slots of
                        Just (SRows group) ->
                            group.next

                        _ ->
                            1

                ids =
                    List.range next (next + List.length items - 1)

                -- the slots of the group's own rows, not of a field whose label starts like the group's
                under key =
                    List.any (\id -> String.startsWith (rowPrefix field.key id ++ "-") key) (rowIds field.key data)

                emptied =
                    State
                        { data
                            | slots =
                                data.slots
                                    |> Dict.filter (\key _ -> not (under key))
                                    |> Dict.union (seed (List.concatMap (\id -> plan.defsAt (rowPrefix field.key id)) ids))
                                    |> Dict.insert field.key (SRows { order = ids, next = next + List.length items })
                            , touched = Set.filter (not << under) data.touched
                            , server = Dict.filter (\key _ -> not (under key)) data.server
                        }
            in
            List.map2 fill items (rowFields handle emptied)
                |> List.foldl (\apply state -> apply state) emptied


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
toValues locale ((Form form) as declared) (State data) =
    let
        defs =
            expandedDefs declared data

        standing_ =
            standing (diagnose locale declared data defs) defs
    in
    if List.isEmpty standing_ then
        case form.readAt form.prefix locale (readable declared data defs) of
            Ok values ->
                Ok values

            Err _ ->
                Err []

    else
        Err (List.map (asProblem declared) standing_)


{-| `True` when the values differ from the baseline, rows added and removed
included. Typing a letter and deleting it again is clean again. Only values
count: an open list, a search text or a server problem do not. It covers every
field of every step and every row, so one flag is enough for the leave guard.
-}
isDirty : State step -> Bool
isDirty (State data) =
    Dict.map (\_ slot -> stable (rawOf slot)) data.slots /= data.baseline


{-| The values now become the baseline, after a load or a successful save.
-}
markClean : State step -> State step
markClean (State data) =
    State { data | baseline = Dict.map (\_ slot -> stable (rawOf slot)) data.slots }


{-| Every field goes back to the baseline, removed rows come back and added rows
go. Problems and what was touched are forgotten.
-}
revert : Form step fields values -> State step -> State step
revert (Form form) (State data) =
    State
        { data
            | slots = rebuild data.baseline data.slots (form.defsAt form.prefix)
            , touched = Set.empty
            , server = Dict.empty
            , attempted = Set.empty
        }


rebuild : Dict String Raw -> Dict String Slot -> List Def -> Dict String Slot
rebuild baseline old defs =
    List.foldl (\def all -> Dict.union (rebuildOne baseline old def) all) Dict.empty defs


rebuildOne : Dict String Raw -> Dict String Slot -> Def -> Dict String Slot
rebuildOne baseline old def =
    case def.rows of
        Nothing ->
            Dict.singleton def.key (putRaw (Dict.get def.key baseline |> Maybe.withDefault def.initial) (newSlot def))

        Just (RowsPlan plan) ->
            let
                order =
                    case Dict.get def.key baseline of
                        Just (RRows ids) ->
                            ids

                        _ ->
                            []

                used =
                    case Dict.get def.key old of
                        Just (SRows group) ->
                            group.next

                        _ ->
                            1
            in
            rebuild baseline old (List.concatMap (\id -> plan.defsAt (rowPrefix def.key id)) order)
                |> Dict.insert def.key (SRows { order = order, next = max used (nextAfter order) })


nextAfter : List Int -> Int
nextAfter ids =
    List.maximum ids |> Maybe.map ((+) 1) |> Maybe.withDefault 1



-- UPDATE


{-| Handles a message of the form's controls. A change in a field clears the
server problem of that field. It also answers the buttons that add and remove
rows, the stepper and the lines of the summary, which is why it needs the form.

    FormMsg inner ->
        let
            ( state, cmd ) =
                Fm.update form inner model.form
        in
        ( { model | form = form }, Cmd.map FormMsg cmd )

-}
update : Form step fields values -> Msg -> State step -> ( State step, Cmd Msg )
update declared msg ((State data) as current) =
    case msg of
        Typed key value ->
            case Dict.get key data.slots of
                Just ((SText _) as old) ->
                    ( moved key old (SText value) current, Cmd.none )

                _ ->
                    ( current, Cmd.none )

        Left key ->
            ( touch key current, Cmd.none )

        Toggled key value ->
            case Dict.get key data.slots of
                Just ((SToggle _) as old) ->
                    ( moved key old (SToggle value) current, Cmd.none )

                _ ->
                    ( current, Cmd.none )

        SelectMsg key inner ->
            case Dict.get key data.slots of
                Just ((SSelect before) as old) ->
                    let
                        ( after, cmd ) =
                            Select.update inner before

                        left =
                            Select.isOpen before && not (Select.isOpen after)
                    in
                    ( moved key old (SSelect after) current |> touchIf left key
                    , Cmd.map (SelectMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        MultiMsg key inner ->
            case Dict.get key data.slots of
                Just ((SMulti before) as old) ->
                    let
                        ( after, cmd ) =
                            MultiSelect.update inner before

                        left =
                            MultiSelect.isOpen before && not (MultiSelect.isOpen after)
                    in
                    ( moved key old (SMulti after) current |> touchIf left key
                    , Cmd.map (MultiMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        NumberMsg key inner ->
            case Dict.get key data.slots of
                Just ((SNumber before) as old) ->
                    let
                        ( after, cmd ) =
                            NumberInput.update inner before
                    in
                    ( moved key old (SNumber after) current |> touchIf (NumberInput.isTouched after) key
                    , Cmd.map (NumberMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        TagsMsg key inner ->
            case Dict.get key data.slots of
                Just ((STags before) as old) ->
                    let
                        ( after, cmd ) =
                            TagInput.update inner before
                    in
                    ( moved key old (STags after) current |> touchIf (TagInput.isTouched after) key
                    , Cmd.map (TagsMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        FilesMsg key inner ->
            case Dict.get key data.slots of
                Just ((SFiles before) as old) ->
                    let
                        ( after, cmd ) =
                            FileDrop.update inner before
                    in
                    ( moved key old (SFiles after) current |> touchIf (FileDrop.isTouched after) key
                    , Cmd.map (FilesMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        RuleMsg key inner ->
            case Dict.get key data.slots of
                Just ((SRule before) as old) ->
                    let
                        ( after, cmd ) =
                            RuleBuilder.update inner before
                    in
                    ( moved key old (SRule after) current, Cmd.map (RuleMsg key) cmd )

                _ ->
                    ( current, Cmd.none )

        DateMsg key inner ->
            case Dict.get key data.slots of
                Just ((SDate before) as old) ->
                    let
                        ( after, cmd ) =
                            DatePicker.update inner before
                    in
                    ( moved key old (SDate after) current, Cmd.map (DateMsg key) cmd )

                _ ->
                    ( current, Cmd.none )

        PeriodMsg key inner ->
            case Dict.get key data.slots of
                Just ((SPeriod before) as old) ->
                    let
                        ( after, cmd ) =
                            DateRangePicker.update inner before
                    in
                    ( moved key old (SPeriod after) current, Cmd.map (PeriodMsg key) cmd )

                _ ->
                    ( current, Cmd.none )

        MoneyMsg key inner ->
            case Dict.get key data.slots of
                Just ((SMoney before) as old) ->
                    let
                        ( after, cmd ) =
                            MoneyInput.update inner before
                    in
                    ( moved key old (SMoney after) current |> touchIf (MoneyInput.isTouched after) key
                    , Cmd.map (MoneyMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        MaskedMsg key inner ->
            case Dict.get key data.slots of
                Just ((SMasked before) as old) ->
                    let
                        ( after, cmd ) =
                            MaskedInput.update inner before
                    in
                    ( moved key old (SMasked after) current |> touchIf (MaskedInput.isTouched after) key
                    , Cmd.map (MaskedMsg key) cmd
                    )

                _ ->
                    ( current, Cmd.none )

        Picked key value ->
            case Dict.get key data.slots of
                Just ((SSelect before) as old) ->
                    ( moved key old (SSelect (Select.setValue value before)) current, Cmd.none )

                _ ->
                    ( current, Cmd.none )

        AddRow key ->
            addRowTo declared key current

        RemoveRow key id ->
            removeRowFrom declared key id current

        GoStep index ->
            goToIndex declared index current

        FocusField index key ->
            goToKey declared index key current

        NoOp ->
            ( current, Cmd.none )


{-| Puts the new slot in place. When the value changed, the field is touched
and its server problem is dropped (also when the old value is typed again: the
server said no to a value the user has since changed).
-}
moved : String -> Slot -> Slot -> State step -> State step
moved key before after (State data) =
    let
        next =
            { data | slots = Dict.insert key after data.slots }
    in
    if stable (rawOf before) /= stable (rawOf after) then
        State { next | touched = touchedBy after key next.touched, server = Dict.remove key next.server }

    else
        State next


{-| Which edits show the field's problems at once. A choice, a switch, a picked
date, a tag or a file is a whole answer, so its problem shows when it is given.
A text, a number, an amount and an identifier are typed a character at a time:
"a" is not an email address yet, so their problems wait until the user leaves
the field (`Left`, or the control's own `isTouched`), and from then on they
follow every keystroke. A rule builder is never "left": half a condition is how
a rule is made, so its problems show once the step has been tried, as the
problems of something the form does not draw itself do.
-}
touchedBy : Slot -> String -> Set String -> Set String
touchedBy slot key touched =
    case slot of
        SRule _ ->
            touched

        SText _ ->
            touched

        SNumber _ ->
            touched

        SMoney _ ->
            touched

        SMasked _ ->
            touched

        _ ->
            Set.insert key touched


touch : String -> State step -> State step
touch key (State data) =
    State { data | touched = Set.insert key data.touched }


touchIf : Bool -> String -> State step -> State step
touchIf condition key state =
    if condition then
        touch key state

    else
        state


addRowTo : Form step fields values -> String -> State step -> ( State step, Cmd Msg )
addRowTo declared key (State data) =
    case ( Dict.get key data.slots, findDef key (expandedDefs declared data) |> Maybe.andThen .rows ) of
        ( Just (SRows group), Just (RowsPlan plan) ) ->
            let
                id =
                    group.next

                prefix =
                    rowPrefix key id

                slots =
                    seed (plan.defsAt prefix)
                        |> Dict.union data.slots
                        |> Dict.insert key (SRows { order = group.order ++ [ id ], next = id + 1 })
            in
            ( State { data | slots = slots }
            , focusOn (rowFirstKey (RowsPlan plan) prefix key)
            )

        _ ->
            ( State data, Cmd.none )


removeRowFrom : Form step fields values -> String -> Int -> State step -> ( State step, Cmd Msg )
removeRowFrom declared key id (State data) =
    case ( Dict.get key data.slots, findDef key (expandedDefs declared data) |> Maybe.andThen .rows ) of
        ( Just (SRows group), Just (RowsPlan plan) ) ->
            let
                under k =
                    String.startsWith (rowPrefix key id ++ "-") k

                remaining =
                    List.filter (\other -> other /= id) group.order

                position =
                    List.length (List.filter (\other -> other < id) group.order)

                neighbour =
                    case List.drop position remaining of
                        next :: _ ->
                            Just next

                        [] ->
                            List.reverse remaining |> List.head

                target =
                    neighbour
                        |> Maybe.map (\other -> rowFirstKey (RowsPlan plan) (rowPrefix key other) key)
                        |> Maybe.withDefault key
            in
            ( State
                { data
                    | slots =
                        data.slots
                            |> Dict.filter (\k _ -> not (under k))
                            |> Dict.insert key (SRows { group | order = remaining })
                    , touched = Set.filter (not << under) data.touched
                    , server = Dict.filter (\k _ -> not (under k)) data.server
                }
            , focusOn target
            )

        _ ->
            ( State data, Cmd.none )


{-| The DOM id of the first field of a row, or the group's own id (the add
button) when the row has none.
-}
rowFirstKey : RowsPlan -> String -> String -> String
rowFirstKey (RowsPlan plan) prefix groupKey =
    plan.defsAt prefix |> List.head |> Maybe.map entryOf |> Maybe.withDefault groupKey


{-| The DOM id the focus goes to when it goes to this field: its own, or for a
rule builder (a group that is no control) the button that adds a condition.
-}
entryOf : Def -> String
entryOf def =
    case def.initial of
        RRule _ ->
            RuleBuilder.focusId [] (RuleBuilder.init def.key) 0

        _ ->
            def.key


findDef : String -> List Def -> Maybe Def
findDef key defs =
    defs |> List.filter (\def -> def.key == key) |> List.head


focusOn : String -> Cmd Msg
focusOn key =
    Internal.focus key NoOp



-- DEFS AND PROBLEMS


{-| The fields of the form with the rows of every group in place, each row's
fields labelled with the row's position and put on the step of the group.
-}
expandedDefs : Form step fields values -> Data -> List Def
expandedDefs (Form form) data =
    expand data (form.defsAt form.prefix)


expand : Data -> List Def -> List Def
expand data defs =
    List.concatMap (expandOne data) defs


expandOne : Data -> Def -> List Def
expandOne data def =
    case def.rows of
        Nothing ->
            [ def ]

        Just (RowsPlan plan) ->
            def
                :: (rowIds def.key data
                        |> List.indexedMap
                            (\position id ->
                                plan.defsAt (rowPrefix def.key id)
                                    |> List.map (\sub -> { sub | step = def.step, label = rowLabel plan.item position sub.label })
                                    |> expand data
                            )
                        |> List.concat
                   )


diagnose : Locale -> Form step fields values -> Data -> List Def -> List Diagnosis
diagnose locale ((Form form) as declared) data defs =
    let
        byKey =
            Dict.fromList (List.map (\def -> ( def.key, def )) defs)

        rulesNow =
            conditionsIn declared data

        hidden =
            hiddenAmong rulesNow data (form.defsAt form.prefix)

        visible def =
            not (Set.member def.key hidden)

        reading =
            withoutHidden hidden defs data

        fromFound f =
            case Dict.get f.field byKey of
                Just def ->
                    { field = f.field, target = reachable def f.target, label = def.label, message = f.message, step = def.step, origin = FromRule }

                Nothing ->
                    { field = f.field, target = f.target, label = f.label, message = f.message, step = 0, origin = FromRule }

        client =
            case form.readAt form.prefix locale reading of
                Ok _ ->
                    []

                Err found ->
                    List.map fromFound found

        wanted =
            requiredAmong rulesNow data

        conditional =
            defs
                |> List.filter (\def -> visible def && Set.member def.key wanted && isBlankIn data def)
                |> List.map (\def -> { field = def.key, target = entryOf def, label = def.label, message = requiredText locale, step = def.step, origin = FromRule })

        bounded =
            defs
                |> List.filter visible
                |> List.filterMap
                    (\def ->
                        lookup def.key data
                            |> Maybe.andThen (limitProblem locale def.limits)
                            |> Maybe.map (\message -> { field = def.key, target = entryOf def, label = def.label, message = message, step = def.step, origin = FromRule })
                    )

        live =
            liveIn declared locale reading
                |> List.filter (\f -> not (Set.member f.field hidden))
                |> List.map fromFound

        server =
            defs
                |> List.filter visible
                |> List.filterMap
                    (\def ->
                        Dict.get def.key data.server
                            |> Maybe.map (\message -> { field = def.key, target = entryOf def, label = def.label, message = message, step = def.step, origin = FromServer })
                    )

        fromOutside =
            data.outside
                |> List.map
                    (\o ->
                        { field = o.field, target = o.field, label = o.label, message = o.message, step = Maybe.withDefault 0 o.step, origin = FromOutside }
                    )
    in
    client ++ conditional ++ bounded ++ live ++ server ++ fromOutside


requiredText : Locale -> String
requiredText locale =
    Locale.pick locale { nb = "Må fylles ut", en = "Required" }


{-| Every condition of the form and of the rows of its groups.
-}
conditionsIn : Form step fields values -> Data -> List Condition
conditionsIn (Form form) data =
    form.conditionsAt form.prefix ++ inRows (\(RowsPlan plan) prefix -> plan.conditionsAt prefix) data (form.defsAt form.prefix)


{-| The problems of every `checkFields` of the form and of the rows of its groups.
-}
liveIn : Form step fields values -> Locale -> Data -> List Found
liveIn (Form form) locale data =
    form.liveAt form.prefix locale data ++ inRows (\(RowsPlan plan) prefix -> plan.liveAt prefix locale data) data (form.defsAt form.prefix)


inRows : (RowsPlan -> String -> List a) -> Data -> List Def -> List a
inRows pick data defs =
    List.concatMap
        (\def ->
            case def.rows of
                Just ((RowsPlan plan) as group) ->
                    rowIds def.key data
                        |> List.concatMap
                            (\id ->
                                let
                                    prefix =
                                        rowPrefix def.key id
                                in
                                pick group prefix ++ inRows pick data (plan.defsAt prefix)
                            )

                Nothing ->
                    []
        )
        defs


{-| The keys of the fields that are not shown now: those whose `shownWhen` does
not hold, and every field in the rows of a group that is not shown.
-}
hiddenAmong : List Condition -> Data -> List Def -> Set String
hiddenAmong rulesNow data defs =
    let
        off =
            rulesNow
                |> List.filter (\c -> c.kind == ShownWhen && not (c.holds data))
                |> List.map .key
                |> Set.fromList
    in
    if Set.isEmpty off then
        Set.empty

    else
        hideUnder off False data defs


hideUnder : Set String -> Bool -> Data -> List Def -> Set String
hideUnder off inside data defs =
    List.foldl
        (\def acc ->
            let
                hiddenNow =
                    inside || Set.member def.key off

                withSelf =
                    if hiddenNow then
                        Set.insert def.key acc

                    else
                        acc
            in
            case def.rows of
                Just (RowsPlan plan) ->
                    rowIds def.key data
                        |> List.foldl (\id all -> Set.union (hideUnder off hiddenNow data (plan.defsAt (rowPrefix def.key id))) all) withSelf

                Nothing ->
                    withSelf
        )
        Set.empty
        defs


requiredAmong : List Condition -> Data -> Set String
requiredAmong rulesNow data =
    rulesNow
        |> List.filter (\c -> c.kind == RequiredWhen && c.holds data)
        |> List.map .key
        |> Set.fromList


{-| The data as the values are read from it: a field that is not shown is read
as empty, and a group that is not shown has no rows.
-}
withoutHidden : Set String -> List Def -> Data -> Data
withoutHidden hidden defs data =
    if Set.isEmpty hidden then
        data

    else
        { data
            | slots =
                List.foldl
                    (\def slots ->
                        if Set.member def.key hidden then
                            case Dict.get def.key slots of
                                Just (SRows group) ->
                                    Dict.insert def.key (SRows { group | order = [] }) slots

                                Just _ ->
                                    Dict.insert def.key (newSlot def) slots

                                Nothing ->
                                    slots

                        else
                            slots
                    )
                    data.slots
                    defs
        }


{-| The data with the hidden fields read as empty, for `toValues`.
-}
readable : Form step fields values -> Data -> List Def -> Data
readable ((Form form) as declared) data defs =
    withoutHidden (hiddenAmong (conditionsIn declared data) data (form.defsAt form.prefix)) defs data


isBlankIn : Data -> Def -> Bool
isBlankIn data def =
    case lookup def.key data of
        Just raw ->
            isBlank raw

        Nothing ->
            True


isBlank : Raw -> Bool
isBlank raw =
    case raw of
        RText value ->
            String.trim value == ""

        RKey value ->
            value == Nothing

        RKeys values ->
            List.isEmpty values

        RNumber value ->
            value == Nothing

        RUnreadable ->
            False

        RBool value ->
            not value

        RTags values ->
            List.isEmpty values

        RFiles values _ ->
            List.isEmpty values

        RRule value ->
            Rule.isEmpty value

        RRows ids ->
            List.isEmpty ids

        RDate value ->
            value == Nothing

        RPeriod value ->
            value == Nothing

        RMoney value ->
            value == Nothing

        RMasked value ->
            value == Nothing


{-| Where the focus goes for a problem: the target the rule named, or the way
into the field when it named the field itself (a rule builder is a group, not a
control).
-}
reachable : Def -> String -> String
reachable def target =
    if target == def.key then
        entryOf def

    else
        target


{-| Every problem once, in the order of the declaration: a field has its own
rule's problem first and the server's after it, and the problems given from
outside come last.
-}
standing : List Diagnosis -> List Def -> List Diagnosis
standing found defs =
    let
        known =
            Set.fromList (List.map .key defs)

        ofFields =
            defs
                |> List.filterMap
                    (\def ->
                        found
                            |> List.filter (\d -> d.field == def.key && d.origin /= FromOutside)
                            |> List.head
                    )

        strays =
            List.filter (\d -> d.origin == FromRule && not (Set.member d.field known)) found

        fromOutside =
            List.filter (\d -> d.origin == FromOutside) found
    in
    ofFields ++ strays ++ fromOutside


{-| A rule's problem shows once the field was left or edited, a server problem
always (until its field is edited), and a problem from outside once its step was
tried.
-}
isShown : Data -> Diagnosis -> Bool
isShown data d =
    case d.origin of
        FromRule ->
            Set.member d.field data.touched

        FromServer ->
            True

        FromOutside ->
            Set.member d.step data.attempted


asProblem : Form step fields values -> Diagnosis -> Problem step
asProblem declared d =
    { field = d.target
    , label = d.label
    , message = d.message
    , step = stepAt declared d.step
    }


stepAt : Form step fields values -> Int -> Maybe step
stepAt (Form form) index =
    form.steps |> List.drop index |> List.head |> Maybe.map .step


stepIndex : Form step fields values -> step -> Maybe Int
stepIndex (Form form) value =
    form.steps
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, info ) -> info.step == value)
        |> List.head
        |> Maybe.map Tuple.first



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
`problems`, `toValues` fails while they stand, the stepper marks their step, and
`summary` lists them once their step has been tried (`advance`, `reveal`,
`rejected`). Each is a `Problem` you write by hand; its `field` is the DOM id of
the element the summary moves the focus to, and its `step` the step it belongs
to.

The list replaces the one given before, so compute it from your model and call
it at the end of your `update`, for example in the same place that handles the
messages of the rule builder:

    ( { model | form = Fm.outside declaration (ruleProblems model) model.form }, cmd )

-}
outside : Form step fields values -> List (Problem step) -> State step -> State step
outside declared found (State data) =
    State
        { data
            | outside =
                List.map
                    (\p ->
                        { field = p.field
                        , label = p.label
                        , message = p.message
                        , step = p.step |> Maybe.andThen (stepIndex declared)
                        }
                    )
                    found
        }


{-| A message from the server tied to a field. Map the backend's own field type
to a handle once, in the application:

    fromBackend : Backend.Problem -> Fm.Problem step
    fromBackend p =
        case p.field of
            Backend.Name ->
                Fm.problem f.name p.message

            Backend.Country ->
                Fm.problem f.country p.message

The label and the step are filled in from the declaration. A field in a row has
a handle for each row: `Fm.rowFields f.contacts state`, then the row at the
position the server named.

-}
problem : Field c -> String -> Problem step
problem (Field field) message =
    { field = field.key, label = field.label, message = message, step = Nothing }


{-| The same for a field in a row of a group, counted from 0 as the server
counts. `Nothing` when the group has no such row.
-}
problemInRow : Field (Rows rowFields) -> Int -> (rowFields -> Field c) -> String -> State step -> Maybe (Problem step)
problemInRow group position pick message state =
    if position < 0 then
        Nothing

    else
        rowFields group state
            |> List.drop position
            |> List.head
            |> Maybe.map (\row -> problem (pick row) message)


{-| Gives the form the problems of a failed save. Each is shown at its field
and in the summary until that field is edited, and counts as a problem
(`problems`, `toValues`) for as long. Every problem of the form shows from now
on, the form moves to the step of the first problem (so that its summary is the
one on screen), and the focus goes to the summary. On the review step (the last
step, when it has no fields) the form stays: its summary lists every problem of
every step, each with a button that goes there. A problem for a field the form
does not have is ignored.

The problems are stored whether or not the form is on screen. The `Cmd` focuses
the summary of this form; when the summary is not on screen (the form is on
another page, or not drawn yet) it finds nothing and does nothing, so it is safe
to batch or to drop. Two forms rejected in one reply each focus their own
summary, and the last one wins: keep the `Cmd` of the one the user is looking at.

-}
rejected : List (Problem step) -> Form step fields values -> State step -> ( State step, Cmd Msg )
rejected found ((Form form) as declared) (State data) =
    let
        defs =
            expandedDefs declared data

        known =
            List.map .key defs

        server =
            found
                |> List.filter (\p -> List.member p.field known)
                |> List.foldl (\p all -> Dict.update p.field (\old -> Just (Maybe.withDefault p.message old)) all) Dict.empty

        withServer =
            { data | server = server }

        first =
            standing (diagnose Locale.default declared withServer defs) defs |> List.head

        last =
            max 0 (List.length form.steps - 1)

        onReview =
            data.current == last && isEmptyStep last defs

        landed =
            case ( first, form.steps ) of
                ( Just d, _ :: _ ) ->
                    -- the review step lists every problem of every step: stay there
                    if onReview then
                        withServer

                    else
                        { withServer | current = d.step }

                _ ->
                    withServer
    in
    ( State (revealSteps (allSteps declared) defs landed)
    , FormLayout.focusSummary form.prefix NoOp
    )


{-| Shows every problem now, also for fields the user has not been in, and moves
the focus to the summary. Call it when the user presses Save and `toValues`
returned problems (`advance` does it for you in a form with steps). Fields and
rows added later start quiet again.
-}
reveal : Form step fields values -> State step -> ( State step, Cmd Msg )
reveal ((Form form) as declared) (State data) =
    ( State (revealSteps (allSteps declared) (expandedDefs declared data) data)
    , FormLayout.focusSummary form.prefix NoOp
    )


allSteps : Form step fields values -> List Int
allSteps (Form form) =
    List.range 0 (max 0 (List.length form.steps - 1))


{-| Touches every field of these steps and marks the steps as tried.
-}
revealSteps : List Int -> List Def -> Data -> Data
revealSteps indexes defs data =
    let
        onSteps =
            List.filter (\def -> List.member def.step indexes) defs
    in
    { data
        | touched = List.foldl (\def all -> Set.insert def.key all) data.touched onSteps
        , slots = List.foldl (\def all -> Dict.update def.key (Maybe.map showIssues) all) data.slots onSteps
        , attempted = List.foldl Set.insert data.attempted indexes
    }


showIssues : Slot -> Slot
showIssues slot =
    case slot of
        SRule state ->
            SRule (RuleBuilder.showIssues state)

        _ ->
            slot


{-| Moves the focus to a field, so the application never writes a DOM id. Map
the `Cmd` with your message constructor. Nothing happens when the field is not
on screen.

    Fm.focus f.name |> Cmd.map FormMsg

-}
focus : Field c -> Cmd Msg
focus handle =
    focusOn (domId handle)


{-| Goes to the element a problem is about, for a review list you draw yourself
(the summary does this by itself): the form changes to the step of the problem,
and the focus moves to its element once that step is on screen. The problem is
one of `problems`, or one you gave to `outside`.
-}
goToProblem : Form step fields values -> Problem step -> State step -> ( State step, Cmd Msg )
goToProblem declared p (State data) =
    case p.step |> Maybe.andThen (stepIndex declared) of
        Just index ->
            ( State { data | current = index }, focusOn p.field )

        Nothing ->
            ( State data, focusOn p.field )


{-| A line of the summary: the step it is listed under and the DOM id of the
element it leads to.
-}
goToKey : Form step fields values -> Int -> String -> State step -> ( State step, Cmd Msg )
goToKey (Form form) index key (State data) =
    if List.isEmpty form.steps then
        ( State data, focusOn key )

    else
        ( State { data | current = clamp 0 (List.length form.steps - 1) index }, focusOn key )



-- STEPS


{-| The step the form is on, or `Nothing` in a form that was declared without
steps.

    case Fm.currentStep declaration model.form of
        Just Company ->
            viewCompany model

        Just Contacts ->
            viewContacts model

        _ ->
            Html.text ""

-}
currentStep : Form step fields values -> State step -> Maybe step
currentStep declared (State data) =
    stepAt declared data.current


{-| `True` when the user has tried to leave this step (with `advance`) or the
problems were revealed (`reveal`, `rejected`). Something you draw yourself that
shows problems only after a try, such as the rule builder, asks it.
-}
attempted : Form step fields values -> step -> State step -> Bool
attempted declared value (State data) =
    case stepIndex declared value of
        Just index ->
            Set.member index data.attempted

        Nothing ->
            False


{-| What the Next and Save buttons do. On a step before the last it checks that
step: with problems, they are shown, the step is marked as failed in the stepper
and the focus goes to the summary; without, the form moves on and the focus goes
to the first field of the next step. On the last step it checks the whole form:
with problems, they are all shown and the form goes to the review step (or, when
the last step has fields, to the first step with a problem); without,
`submit` is the record, ready to send. Sending it and keeping the
`FormLayout.Status` stays with the application.

    Submit ->
        let
            next =
                Fm.advance declaration model.form
        in
        ( { model | form = next.state }
        , Cmd.batch [ Cmd.map FormMsg next.cmd, Maybe.map send next.submit |> Maybe.withDefault Cmd.none ]
        )

-}
advance : Form step fields values -> State step -> { state : State step, cmd : Cmd Msg, submit : Maybe values }
advance ((Form form) as declared) ((State data) as current) =
    let
        defs =
            expandedDefs declared data

        found =
            standing (diagnose Locale.default declared data defs) defs

        last =
            max 0 (List.length form.steps - 1)
    in
    if data.current < last then
        case List.filter (\d -> d.step == data.current) found of
            [] ->
                let
                    ( entered, cmd ) =
                        enter declared (data.current + 1) data
                in
                { state = State entered, cmd = cmd, submit = Nothing }

            _ ->
                { state = State (revealSteps [ data.current ] defs data)
                , cmd = FormLayout.focusSummary form.prefix NoOp
                , submit = Nothing
                }

    else
        case ( found, toValues Locale.default declared current ) of
            ( [], Ok values ) ->
                { state = current, cmd = Cmd.none, submit = Just values }

            _ ->
                let
                    target =
                        if not (List.isEmpty form.steps) && isEmptyStep last defs then
                            last

                        else
                            found |> List.head |> Maybe.map .step |> Maybe.withDefault data.current

                    moved_ =
                        { data | current = target }
                in
                { state = State (revealSteps (allSteps declared) defs moved_)
                , cmd = FormLayout.focusSummary form.prefix NoOp
                , submit = Nothing
                }


{-| The Back button: one step back, without checking anything, and the focus goes
to the first field of that step. On the first step it does nothing.
-}
back : Form step fields values -> State step -> ( State step, Cmd Msg )
back declared (State data) =
    if data.current <= 0 then
        ( State data, Cmd.none )

    else
        enter declared (data.current - 1) data |> Tuple.mapFirst State


{-| Goes to a step, for the "Edit" buttons of a review page. Going back is free.
Going forward checks every step on the way, as the stepper does: it stops at the
first one with problems, shows them and puts the focus on the summary.
-}
goTo : Form step fields values -> step -> State step -> ( State step, Cmd Msg )
goTo declared value ((State _) as current) =
    case stepIndex declared value of
        Just index ->
            goToIndex declared index current

        Nothing ->
            ( current, Cmd.none )


goToIndex : Form step fields values -> Int -> State step -> ( State step, Cmd Msg )
goToIndex ((Form form) as declared) target (State data) =
    let
        last =
            max 0 (List.length form.steps - 1)

        index =
            clamp 0 last target
    in
    if index <= data.current then
        enter declared index data |> Tuple.mapFirst State

    else
        let
            defs =
                expandedDefs declared data

            found =
                standing (diagnose Locale.default declared data defs) defs

            blocking =
                List.range data.current (index - 1)
                    |> List.filter (\s -> List.any (\d -> d.step == s) found)
                    |> List.head
        in
        case blocking of
            Nothing ->
                enter declared index data |> Tuple.mapFirst State

            Just bad ->
                ( State (revealSteps [ bad ] defs { data | current = bad })
                , FormLayout.focusSummary form.prefix NoOp
                )


{-| Moves to a step and puts the focus on its first field.
-}
enter : Form step fields values -> Int -> Data -> ( Data, Cmd Msg )
enter ((Form form) as declared) index data =
    let
        defs =
            expandedDefs declared data

        hidden =
            hiddenAmong (conditionsIn declared data) data (form.defsAt form.prefix)

        onStep =
            List.filter (\def -> def.step == index && not (Set.member def.key hidden)) defs

        firstField =
            case List.filter (\def -> not (isGroup def)) onStep |> List.head of
                Just def ->
                    Just (entryOf def)

                Nothing ->
                    List.head onStep |> Maybe.map entryOf
    in
    ( { data | current = index }
    , case firstField of
        Just key ->
            focusOn key

        Nothing ->
            -- a step with no fields of the form: focus its anchor (see `summary`)
            FormLayout.focusSummary form.prefix NoOp
    )


isGroup : Def -> Bool
isGroup def =
    case def.rows of
        Just _ ->
            True

        Nothing ->
            False


{-| A step with no fields of its own: the review step.
-}
isEmptyStep : Int -> List Def -> Bool
isEmptyStep index defs =
    not (List.any (\def -> def.step == index) defs)



-- VIEWS


{-| Binds the form, the state, the language and the message wrapper for one
view. The result carries everything the controls need, so each control is one
call.
-}
bind : Locale -> (Msg -> msg) -> Form step fields values -> State step -> View msg
bind locale toMsg ((Form form) as declared) (State data) =
    let
        defs =
            expandedDefs declared data

        rulesNow =
            conditionsIn declared data

        hidden =
            hiddenAmong rulesNow data (form.defsAt form.prefix)

        wanted =
            requiredAmong rulesNow data

        drawn =
            defs
                |> List.filter (\def -> not (Set.member def.key hidden))
                |> List.map (\def -> { def | required = def.required || Set.member def.key wanted })

        found =
            diagnose locale declared data defs

        visible =
            List.filter (isShown data) found

        winners =
            visible
                |> List.filter (\d -> d.origin /= FromOutside)
                |> List.foldr (\d all -> Dict.insert d.field d all) Dict.empty

        byField =
            Dict.map (\_ d -> d.message) winners

        ofFields =
            defs
                |> List.filterMap
                    (\def ->
                        Dict.get def.key winners
                            |> Maybe.map (\d -> { field = d.target, label = def.label, message = d.message, step = def.step })
                    )

        ofOutside =
            visible
                |> List.filter (\d -> d.origin == FromOutside)
                |> List.map (\d -> { field = d.target, label = d.label, message = d.message, step = d.step })

        shown =
            ofFields ++ ofOutside

        stepLabel index =
            form.steps |> List.drop index |> List.head |> Maybe.map .label |> Maybe.withDefault ""

        listed =
            if List.isEmpty form.steps then
                shown

            else if data.current == List.length form.steps - 1 && isEmptyStep data.current defs then
                standing found defs
                    |> List.map
                        (\d ->
                            { field = d.target
                            , label = d.label ++ " (" ++ stepLabel d.step ++ ")"
                            , message = d.message
                            , step = d.step
                            }
                        )

            else
                List.filter (\p -> p.step == data.current) shown
    in
    View
        { toMsg = toMsg
        , locale = locale
        , prefix = form.prefix
        , defs = Dict.fromList (List.map (\def -> ( def.key, def )) drawn)
        , slots = data.slots
        , byField = byField
        , listed = listed
        , stepInfo =
            form.steps
                |> List.indexedMap (\index info -> { label = info.label, failed = List.any (\p -> p.step == index) shown })
        , current = data.current
        , anchor =
            if not (List.isEmpty form.steps) && isEmptyStep data.current defs then
                Just (stepLabel data.current)

            else
                Nothing
        , hidden = hidden
        }


stepOfListed : List Listed -> String -> Int
stepOfListed listed key =
    listed
        |> List.filter (\p -> p.field == key)
        |> List.head
        |> Maybe.map .step
        |> Maybe.withDefault 0


{-| Everything the declaration says about a field and the view needs: the
attributes that win over the application's own.
-}
fieldDef : View msg -> Field c -> Maybe ( Def, Slot )
fieldDef (View view) (Field field) =
    case ( Dict.get field.key view.defs, Dict.get field.key view.slots ) of
        ( Just def, Just slot ) ->
            Just ( def, slot )

        _ ->
            Nothing


problemOf : View msg -> Def -> Maybe String
problemOf (View view) def =
    Dict.get def.key view.byField


mismatch : View msg -> Field c -> String -> Html msg
mismatch (View view) (Field field) wanted =
    if Set.member field.key view.hidden then
        Html.text ""

    else
        mismatchText (View view) (Field field) wanted


mismatchText : View msg -> Field c -> String -> Html msg
mismatchText (View view) (Field field) wanted =
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


{-| A rule builder for a `conditions` field. The label is the declaration's; the
fields (what a rule can talk about, with the options the user chooses among) and
the other settings are the application's attributes.
-}
ruleBuilder : View msg -> Field Rule.Rule -> List (Rule.Field ()) -> List (RuleBuilder.Attribute () msg) -> Html msg
ruleBuilder ((View view) as bound) field fieldList attributes =
    case fieldDef bound field of
        Just ( def, SRule state ) ->
            RuleBuilder.view (\inner -> view.toMsg (RuleMsg def.key inner))
                (attributes
                    ++ [ RuleBuilder.fields fieldList
                       , RuleBuilder.locale view.locale
                       , RuleBuilder.label def.label
                       ]
                )
                state

        _ ->
            mismatch bound field "conditions"


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
                        [ Maybe.map Switch.hint def.hint
                        , Maybe.map Switch.error (problemOf bound def)
                        ]
                    ++ [ Switch.locale view.locale
                       , Switch.id def.key
                       , Switch.label def.label
                       , Switch.checked value
                       , Switch.onCheck (\on -> view.toMsg (Toggled def.key on))
                       ]
                )

        _ ->
            mismatch bound field "a switch"


{-| A checkbox for a `toggle` field, for a choice that is saved with the form
("I accept the terms of delivery"). The label, the hint, the problem and the
value are the form's; `Spec.rule identity` makes ticking it a must.
-}
checkbox : View msg -> Field Bool -> List (Checkbox.Attribute msg) -> Html msg
checkbox ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SToggle value ) ->
            Checkbox.view
                (attributes
                    ++ List.filterMap identity
                        [ Maybe.map Checkbox.hint def.hint
                        , Maybe.map Checkbox.error (problemOf bound def)
                        ]
                    ++ [ Checkbox.id def.key
                       , Checkbox.label def.label
                       , Checkbox.checked value
                       , Checkbox.onCheck (\on -> view.toMsg (Toggled def.key on))
                       ]
                )

        _ ->
            mismatch bound field "a toggle"


{-| Radio buttons for a `choice` field, for two to five options that people
should see all at once. The options are the same `Select.Option` values a
`select` takes (`Select.option`, `Select.withDescription`,
`Select.disabledOption`), so a choice can move between the two controls without
a change to its options. The label is the legend of the group.
-}
radio : View msg -> Field (Maybe id) -> List (Select.Option id) -> List (Radio.Attribute msg) -> Html msg
radio ((View view) as bound) ((Field field) as handle) options attributes =
    case fieldDef bound handle of
        Just ( def, SSelect state ) ->
            Radio.view
                (attributes
                    ++ declaredAttributes def Radio.hint Radio.required
                    ++ [ Radio.id def.key
                       , Radio.label def.label
                       , Radio.errorMaybe (problemOf bound def)
                       , Radio.options (List.map (radioOption field.toRaw) options)
                       , Radio.selected (Select.value state)
                       , Radio.onSelect (\key -> view.toMsg (Picked def.key key))
                       ]
                )

        _ ->
            mismatch bound handle "a choice"


radioOption : (Maybe id -> Raw) -> Select.Option id -> Radio.Option
radioOption toRaw choice_ =
    Radio.option (keyOf toRaw (Just choice_.value)) choice_.label
        |> (case choice_.description of
                Just text_ ->
                    Radio.withDescription text_

                Nothing ->
                    identity
           )
        |> (if choice_.disabled then
                Radio.disabledOption

            else
                identity
           )


{-| A date picker for a `date` field. The limits of `Spec.minDate` and
`Spec.maxDate` are given to the calendar for you; `today` (for the marker, the
"Today" button and short forms such as `+3`) and a limit that depends on today
are the application's attributes (`DatePicker.today model.today`,
`DatePicker.min model.today`).
-}
datePicker : View msg -> Field (Maybe Date) -> List DatePicker.Attribute -> Html msg
datePicker ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SDate state ) ->
            DatePicker.view (\inner -> view.toMsg (DateMsg def.key inner))
                (attributes
                    ++ declaredAttributes def DatePicker.hint DatePicker.required
                    ++ [ DatePicker.locale view.locale
                       , DatePicker.label def.label
                       , DatePicker.errorMaybe (problemOf bound def)
                       ]
                    ++ dateLimits def.limits
                )
                state

        _ ->
            mismatch bound field "a date"


{-| A date range picker for a `dateRange` field. The earliest and latest day, the
longest period and the presets are the application's attributes
(`DateRangePicker.min`, `DateRangePicker.maxRangeDays`, `DateRangePicker.today`);
a period the picker refuses is a problem of the form until it is fixed.
-}
dateRangePicker : View msg -> Field (Maybe ( Date, Date )) -> List DateRangePicker.Attribute -> Html msg
dateRangePicker ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SPeriod state ) ->
            DateRangePicker.view (\inner -> view.toMsg (PeriodMsg def.key inner))
                (attributes
                    ++ declaredAttributes def DateRangePicker.hint DateRangePicker.required
                    ++ [ DateRangePicker.locale view.locale
                       , DateRangePicker.label def.label
                       , DateRangePicker.errorMaybe (problemOf bound def)
                       ]
                )
                state

        _ ->
            mismatch bound field "a period"


{-| An amount field for a `money` field, in the currency of the declaration.
The limits of `Spec.minMoney` and `Spec.maxMoney` (and with them whether a
negative amount is allowed) are given to the field for you.
-}
moneyInput : View msg -> Field (Maybe Money) -> List (MoneyInput.Attribute msg) -> Html msg
moneyInput ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SMoney state ) ->
            MoneyInput.view (\inner -> view.toMsg (MoneyMsg def.key inner))
                (attributes
                    ++ declaredAttributes def MoneyInput.hint MoneyInput.required
                    ++ [ MoneyInput.locale view.locale
                       , MoneyInput.label def.label
                       , MoneyInput.errorMaybe (problemOf bound def)
                       ]
                    ++ moneyLimits def.limits
                )
                state

        _ ->
            mismatch bound field "an amount"


{-| A masked field for a `masked` field: the identifier is written in its groups
as it is typed, and its check digit is checked.
-}
maskedInput : View msg -> Field (Maybe String) -> List (MaskedInput.Attribute msg) -> Html msg
maskedInput ((View view) as bound) field attributes =
    case fieldDef bound field of
        Just ( def, SMasked state ) ->
            MaskedInput.view (\inner -> view.toMsg (MaskedMsg def.key inner))
                (attributes
                    ++ declaredAttributes def MaskedInput.hint MaskedInput.required
                    ++ [ MaskedInput.locale view.locale
                       , MaskedInput.label def.label
                       , MaskedInput.errorMaybe (problemOf bound def)
                       ]
                )
                state

        _ ->
            mismatch bound field "an identifier"


{-| The button that adds a row to a group, with the group's problem under it
("Add at least 1") when that is showing. The new row is added at the end and its
first field gets the focus. The button's DOM id is the group's: it is where the
summary and the focus after removing the last row lead.

    Fm.addRow v f.contacts [] "Add contact"

-}
addRow : View msg -> Field (Rows rowFields) -> List (Button.Attribute msg) -> String -> Html msg
addRow ((View view) as bound) (Field field) attributes label =
    case Dict.get field.key view.defs of
        Just def ->
            Html.div []
                [ Button.view
                    (Button.icon Icon.plus
                        :: attributes
                        ++ [ Button.id def.key
                           , Button.onClick (view.toMsg (AddRow def.key))
                           ]
                    )
                    label
                , case problemOf bound def of
                    Just message ->
                        Html.p [ Internal.cls [ "klar-field__error" ] ] [ Html.text message ]

                    Nothing ->
                        Html.text ""
                ]

        Nothing ->
            Html.text ""


{-| The button that removes the row at this position (counted from 0, as in
`List.indexedMap` over `rowFields`): an icon button named "Remove contact 2"
from the group's `item`. The focus goes to the next row's first field, or the
previous one, or the add button when no row is left.
-}
removeRow : View msg -> Field (Rows rowFields) -> Int -> List (Button.Attribute msg) -> Html msg
removeRow (View view) (Field field) position attributes =
    case
        ( Dict.get field.key view.defs |> Maybe.andThen .rows
        , Dict.get field.key view.slots
        )
    of
        ( Just (RowsPlan plan), Just (SRows group) ) ->
            case List.drop position group.order |> List.head of
                Just id ->
                    Button.iconOnly
                        (Button.ghost
                            :: attributes
                            ++ [ Button.onClick (view.toMsg (RemoveRow field.key id)) ]
                        )
                        Icon.trash
                        (Locale.pick view.locale
                            { nb = "Fjern " ++ String.toLower plan.item ++ " " ++ String.fromInt (position + 1)
                            , en = "Remove " ++ String.toLower plan.item ++ " " ++ String.fromInt (position + 1)
                            }
                        )

                Nothing ->
                    Html.text ""

        _ ->
            Html.text ""


{-| The steps of the form as a stepper, with the step the form is on and a red
mark on every step that has problems showing. A click on a step goes there; going
forward checks the steps on the way and stops at the first one with problems.
Nothing is drawn for a form without steps. The attributes are the stepper's own
(`Stepper.ariaLabel`, `Stepper.small`).
-}
stepper : View msg -> List (Stepper.Attribute msg) -> Html msg
stepper (View view) attributes =
    if List.isEmpty view.stepInfo then
        Html.text ""

    else
        Stepper.view
            (attributes
                ++ [ Stepper.current view.current
                   , Stepper.onSelect (\index -> view.toMsg (GoStep index))
                   , Stepper.locale view.locale
                   ]
            )
            (List.map
                (\info ->
                    if info.failed then
                        Stepper.step info.label |> Stepper.failed

                    else
                        Stepper.step info.label
                )
                view.stepInfo
            )


{-| The fields of the current step, drawn by the application. Every child has a key
of the step it is on, so when the form moves to the next step Elm makes new inputs
and does not reuse the focused input of the old step for the field at the same place
in the new one (it would blur it with the focus move, which shows "Required" on a
field nobody has touched).
-}
stepBody : View msg -> List (Html msg) -> Html msg
stepBody view children =
    Keyed.node "div" [] (stepKeys view children)


{-| The children with the keys that `stepBody` gives them: the prefix of the form,
the step and the place in the step.
-}
stepKeys : View msg -> List (Html msg) -> List ( String, Html msg )
stepKeys (View view) children =
    List.indexedMap
        (\place child -> ( view.prefix ++ "-step-" ++ String.fromInt view.current ++ "-" ++ String.fromInt place, child ))
        children


{-| The list of problems that are showing, with the labels of the declaration,
as `FormLayout.errorSummary`: the form's own and those given to `outside`. Each line
moves the focus to its element, on another step if need be. On a step it lists
the problems of that step; on the review step (a step with no fields) it lists
every problem of every step, shown or not, with the step in brackets. Nothing
is drawn while there is nothing to list, except on a step with no fields of the
form (a review step, or a step whose fields you draw yourself): there an empty
region named by the step is drawn, because the focus lands there when the form
moves to the step. Put `summary` at the top of every step.
-}
summary : View msg -> Html msg
summary (View view) =
    if List.isEmpty view.listed then
        case view.anchor of
            Just label ->
                -- nothing to list, but a step with no fields of the form needs a place for the focus to land
                Html.div
                    [ Attr.id (view.prefix ++ "-summary")
                    , Attr.tabindex -1
                    , Attr.attribute "role" "group"
                    , Attr.attribute "aria-label" label
                    ]
                    []

            Nothing ->
                Html.text ""

    else
        FormLayout.errorSummary
            [ FormLayout.id view.prefix
            , FormLayout.locale view.locale
            , FormLayout.labels (List.map (\p -> ( p.field, p.label )) view.listed)
            , FormLayout.onFocusField (\key -> view.toMsg (FocusField (stepOfListed view.listed key) key))
            ]
            (List.map (\p -> { field = p.field, message = p.message }) view.listed)



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
