module Klar.RuleBuilder.Editor exposing
    ( Controls
    , Layout(..)
    , Msg
    , Outcome
    , Settings
    , anyOpen
    , chipParts
    , emptyControls
    , extraIssues
    , fieldDomId
    , focusDomId
    , hasValueEditor
    , isKnownField
    , operatorDomId
    , prune
    , resetControls
    , update
    , valueDomId
    , viewField
    , viewOperator
    , viewValues
    )

{-| The condition editor shared by `Klar.RuleBuilder` (one compact line per
condition) and `Klar.FilterBar` (a small form in a popover): the field picker,
the operator picker and the value editors, which depend on the kind of field
and the operator.

    field                -> searchable select, grouped by `Field.group`
    operator             -> select with `Rule.operatorsFor kind`
    text                 -> text input
    number               -> text input with decimal handling, two for "between"
    date                 -> date picker (ISO `YYYY-MM-DD` operand), two for "between"
    date, last/next N    -> number input ("days")
    choice               -> searchable select
    choice, any/none of  -> multi select
    boolean, empty ops   -> nothing

The editor works on a `Rule` by node id, so the same code edits a condition
deep inside a rule tree and a lone draft condition (a bare `ConditionRule`).

The pickers are stateful components (`Klar.Select`, `Klar.MultiSelect`,
`Klar.DatePicker`). Their states live in `Controls`, keyed by node id and role,
are created when first needed, and are synced from the rule before every
render and before every update - so a rule loaded from JSON shows correctly.
After an update the new value is compared with the rule's, and written into
the rule when it changed.

This module is internal to the rules group. Applications use
`Klar.RuleBuilder` and `Klar.FilterBar`.

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.MultiSelect as MultiSelect
import Klar.Rule as Rule exposing (Condition, Field, FieldKind(..), Operands(..), Operator(..), Rule(..))
import Klar.RuleBuilder.Support exposing (findCondition, replaceCondition, stub)
import Klar.Select as Select
import Klar.TextInput as TextInput
import Set exposing (Set)



-- CONTROLS


{-| The states of the pickers inside the editor: selects keyed by
`( node id, role )` (role `"field"`, `"op"`, `"v0"`, `"v1"`), multi selects
by node id, date pickers by `( node id, operand index )`.
-}
type Controls
    = Controls
        { prefix : String
        , selects : Dict ( Int, String ) Select.State
        , multis : Dict Int MultiSelect.State
        , dates : Dict ( Int, Int ) DatePicker.State
        }


{-| No controls yet. The prefix makes the DOM ids of the controls unique on
the page (use the DOM id of the component).
-}
emptyControls : String -> Controls
emptyControls prefix =
    Controls { prefix = prefix, selects = Dict.empty, multis = Dict.empty, dates = Dict.empty }


resetControls : Controls -> Controls
resetControls (Controls c) =
    emptyControls c.prefix


{-| Forget the controls of nodes that no longer exist.
-}
prune : Set Int -> Controls -> Controls
prune live (Controls c) =
    Controls
        { c
            | selects = Dict.filter (\( node, _ ) _ -> Set.member node live) c.selects
            , multis = Dict.filter (\node _ -> Set.member node live) c.multis
            , dates = Dict.filter (\( node, _ ) _ -> Set.member node live) c.dates
        }


{-| Is a popup of an embedded control open? Then Escape belongs to it.
-}
anyOpen : Controls -> Bool
anyOpen (Controls c) =
    List.any Select.isOpen (Dict.values c.selects)
        || List.any MultiSelect.isOpen (Dict.values c.multis)
        || List.any DatePicker.isOpen (Dict.values c.dates)


{-| Forget the value pickers of a node (its values were reset).
-}
dropValues : Int -> Controls -> Controls
dropValues node (Controls c) =
    Controls
        { c
            | selects = Dict.filter (\( owner, role ) _ -> owner /= node || role == "field" || role == "op") c.selects
            , multis = Dict.remove node c.multis
            , dates = Dict.filter (\( owner, _ ) _ -> owner /= node) c.dates
        }


selectState : Controls -> Int -> String -> String -> Select.State
selectState (Controls c) node role domId =
    Dict.get ( node, role ) c.selects |> Maybe.withDefault (Select.init domId)


syncSelect : String -> Select.State -> Select.State
syncSelect wanted state =
    if wanted == "" then
        if Select.value state == Nothing then
            state

        else
            Select.clear state

    else if Select.value state == Just wanted then
        state

    else
        Select.setValue wanted state


syncMany : List String -> MultiSelect.State -> MultiSelect.State
syncMany wanted state =
    if MultiSelect.values state == wanted then
        state

    else
        MultiSelect.setValues wanted state


{-| Show the rule's value in the picker, unless the picker already has it
(that would throw away what the user is typing).
-}
syncDate : String -> DatePicker.State -> DatePicker.State
syncDate value state =
    let
        wanted =
            Date.fromIso value
    in
    if DatePicker.date state == wanted then
        state

    else
        DatePicker.setDate wanted state



-- DOM IDS


nodeDomId : String -> Int -> String
nodeDomId prefix node =
    prefix ++ "-n" ++ String.fromInt node


fieldDomId : String -> Int -> String
fieldDomId prefix node =
    nodeDomId prefix node ++ "-field"


operatorDomId : String -> Int -> String
operatorDomId prefix node =
    nodeDomId prefix node ++ "-op"


valueDomId : String -> Int -> Int -> String
valueDomId prefix node index =
    nodeDomId prefix node ++ "-v" ++ String.fromInt index


{-| The control a user fills in next for this condition: the first value,
the operator when it takes no value, or the field picker when no field is
chosen yet.
-}
focusDomId : String -> List (Field row) -> Condition -> String
focusDomId prefix fields condition =
    case Rule.fieldById fields condition.field of
        Nothing ->
            fieldDomId prefix condition.id

        Just field ->
            if shapeOf field.kind condition.operator == NoValue then
                operatorDomId prefix condition.id

            else
                valueDomId prefix condition.id 0



-- UPDATE


type Msg
    = FieldMsg Int (List ( String, FieldKind )) Select.Msg
    | OperatorMsg Int FieldKind Select.Msg
    | ChoiceMsg Int Int Select.Msg
    | ManyMsg Int MultiSelect.Msg
    | ValueTyped Int Int String
    | ValueLeft Int
    | DateMsg Int Int DatePicker.Msg
    | Ignored


{-| What an editor message did: the new rule and controls, a command, and the
node the user tried to fill in (typed, picked or left a value), if any, so
the owner can start showing that node's issues.
-}
type alias Outcome =
    { rule : Rule
    , controls : Controls
    , cmd : Cmd Msg
    , touched : Maybe Int
    }


update : Msg -> Rule -> Controls -> Outcome
update msg rule ((Controls c) as controls) =
    let
        condition node =
            findCondition node rule
    in
    case msg of
        FieldMsg node kinds inner ->
            let
                current =
                    condition node |> Maybe.map .field |> Maybe.withDefault ""

                before =
                    selectState controls node "field" (fieldDomId c.prefix node) |> syncSelect current

                ( after, cmd ) =
                    Select.update inner before

                stored =
                    Controls { c | selects = Dict.insert ( node, "field" ) after c.selects }
            in
            case Select.value after of
                Just picked ->
                    if picked /= current then
                        { rule =
                            case lookup picked kinds of
                                Just kind ->
                                    let
                                        withField =
                                            Rule.setField [ stub picked kind ] node picked rule
                                    in
                                    -- the first field of a new condition gets that kind's usual operator
                                    case ( current, List.head (Rule.operatorsFor kind) ) of
                                        ( "", Just usual ) ->
                                            Rule.setOperator node usual withField

                                        _ ->
                                            withField

                                Nothing ->
                                    Rule.setField [] node picked rule
                        , controls = dropValues node stored
                        , cmd = Cmd.map (FieldMsg node kinds) cmd
                        , touched = Nothing
                        }

                    else
                        { rule = rule, controls = stored, cmd = Cmd.map (FieldMsg node kinds) cmd, touched = Nothing }

                Nothing ->
                    { rule = rule, controls = stored, cmd = Cmd.map (FieldMsg node kinds) cmd, touched = Nothing }

        OperatorMsg node kind inner ->
            let
                current =
                    condition node |> Maybe.map .operator

                before =
                    selectState controls node "op" (operatorDomId c.prefix node)
                        |> syncSelect (current |> Maybe.map operatorKey |> Maybe.withDefault "")

                ( after, cmd ) =
                    Select.update inner before

                stored =
                    Controls { c | selects = Dict.insert ( node, "op" ) after c.selects }

                unchanged =
                    { rule = rule, controls = stored, cmd = Cmd.map (OperatorMsg node kind) cmd, touched = Nothing }
            in
            case ( Select.value after |> Maybe.andThen operatorFromKey, current ) of
                ( Just picked, Just old ) ->
                    if picked /= old then
                        let
                            reset =
                                inputChanged (shapeOf kind old) (shapeOf kind picked)

                            cleared =
                                if reset then
                                    Rule.setOperator node IsEmpty rule

                                else
                                    rule
                        in
                        { rule = Rule.setOperator node picked cleared
                        , controls =
                            if reset then
                                dropValues node stored

                            else
                                stored
                        , cmd = Cmd.map (OperatorMsg node kind) cmd
                        , touched = Nothing
                        }

                    else
                        unchanged

                _ ->
                    unchanged

        ChoiceMsg node index inner ->
            let
                role =
                    "v" ++ String.fromInt index

                current =
                    valueAt node index rule

                before =
                    selectState controls node role (valueDomId c.prefix node index) |> syncSelect current

                ( after, cmd ) =
                    Select.update inner before

                picked =
                    Select.value after |> Maybe.withDefault ""

                changed =
                    picked /= current
            in
            { rule =
                if changed then
                    Rule.setValue node index picked rule

                else
                    rule
            , controls = Controls { c | selects = Dict.insert ( node, role ) after c.selects }
            , cmd = Cmd.map (ChoiceMsg node index) cmd
            , touched =
                if changed || (Select.isOpen before && not (Select.isOpen after)) then
                    Just node

                else
                    Nothing
            }

        ManyMsg node inner ->
            let
                current =
                    condition node |> Maybe.map (.values >> List.filter (\value -> value /= "")) |> Maybe.withDefault []

                before =
                    Dict.get node c.multis
                        |> Maybe.withDefault (MultiSelect.init (valueDomId c.prefix node 0))
                        |> syncMany current

                ( after, cmd ) =
                    MultiSelect.update inner before

                picked =
                    MultiSelect.values after

                changed =
                    picked /= current
            in
            { rule =
                if changed then
                    setValues node picked rule

                else
                    rule
            , controls = Controls { c | multis = Dict.insert node after c.multis }
            , cmd = Cmd.map (ManyMsg node) cmd
            , touched =
                if changed || (MultiSelect.isOpen before && not (MultiSelect.isOpen after)) then
                    Just node

                else
                    Nothing
            }

        ValueTyped node index text ->
            { rule = Rule.setValue node index text rule, controls = controls, cmd = Cmd.none, touched = Just node }

        ValueLeft node ->
            { rule = rule, controls = controls, cmd = Cmd.none, touched = Just node }

        DateMsg node index inner ->
            let
                current =
                    valueAt node index rule

                before =
                    Dict.get ( node, index ) c.dates
                        |> Maybe.withDefault (DatePicker.init (valueDomId c.prefix node index))
                        |> syncDate current

                ( after, cmd ) =
                    DatePicker.update inner before

                changed =
                    DatePicker.date after /= DatePicker.date before

                newRule =
                    if changed then
                        Rule.setValue node index (DatePicker.date after |> Maybe.map Date.toIso |> Maybe.withDefault "") rule

                    else
                        rule
            in
            { rule = newRule
            , controls = Controls { c | dates = Dict.insert ( node, index ) after c.dates }
            , cmd = Cmd.map (DateMsg node index) cmd
            , touched =
                if changed || DatePicker.isInvalid after then
                    Just node

                else
                    Nothing
            }

        Ignored ->
            { rule = rule, controls = controls, cmd = Cmd.none, touched = Nothing }


lookup : String -> List ( String, a ) -> Maybe a
lookup key pairs =
    pairs |> List.filter (\( k, _ ) -> k == key) |> List.head |> Maybe.map Tuple.second


setValues : Int -> List String -> Rule -> Rule
setValues node values rule =
    case findCondition node rule of
        Just condition ->
            replaceCondition { condition | values = values } rule

        Nothing ->
            rule



-- VIEW


{-| `Inline` for one line per condition (the rule builder), `Stacked` for a
small vertical form (the filter bar's popover).
-}
type Layout
    = Inline
    | Stacked


type alias Settings row msg =
    { toMsg : Msg -> msg
    , fields : List (Field row)
    , locale : Locale
    , controls : Controls
    , issue : Maybe String
    , layout : Layout
    , today : Maybe Date
    , onEnter : Maybe msg
    }


prefixOf : Controls -> String
prefixOf (Controls c) =
    c.prefix


{-| Which part of the condition an issue is about: no known field, an
operator that does not belong to the field, or the values.
-}
type Blame
    = BlameField
    | BlameOperator
    | BlameValues


blame : List (Field row) -> Condition -> Blame
blame fields condition =
    case Rule.fieldById fields condition.field of
        Nothing ->
            BlameField

        Just field ->
            if List.member condition.operator (Rule.operatorsFor field.kind) then
                BlameValues

            else
                BlameOperator


issueFor : Blame -> Settings row msg -> Condition -> Maybe String
issueFor part settings condition =
    if blame settings.fields condition == part then
        settings.issue

    else
        Nothing


{-| The field picker: searchable, fields with a `group` under a heading.
-}
viewField : Settings row msg -> Condition -> Html msg
viewField settings condition =
    let
        t =
            texts settings.locale

        known =
            Rule.fieldById settings.fields condition.field

        unknown =
            if known == Nothing && condition.field /= "" then
                [ Select.option condition.field (t.unknownField ++ ": " ++ condition.field) |> Select.disabledOption ]

            else
                []

        options =
            unknown
                ++ List.map
                    (\field ->
                        case field.group of
                            Just group ->
                                Select.option field.id field.label |> Select.withGroup group

                            Nothing ->
                                Select.option field.id field.label
                    )
                    settings.fields

        state =
            selectState settings.controls condition.id "field" (fieldDomId (prefixOf settings.controls) condition.id)
                |> syncSelect condition.field

        kinds =
            List.map (\field -> ( field.id, field.kind )) settings.fields
    in
    Html.div [ Internal.cls [ "klar-rule-editor__field" ] ]
        [ Select.view (\inner -> settings.toMsg (FieldMsg condition.id kinds inner))
            [ Select.label t.field
            , Select.labelHidden
            , Select.options options
            , Select.placeholder t.chooseField
            , Select.searchPlaceholder t.searchField
            , Select.visibleRows 10
            , Select.locale settings.locale
            , Select.errorMaybe (issueFor BlameField settings condition)
            ]
            state
        ]


{-| The operator picker: the operators that make sense for the field.
-}
viewOperator : Settings row msg -> Condition -> Html msg
viewOperator settings condition =
    let
        t =
            texts settings.locale

        domId =
            operatorDomId (prefixOf settings.controls) condition.id
    in
    Html.div [ Internal.cls [ "klar-rule-editor__operator" ] ]
        [ case Rule.fieldById settings.fields condition.field of
            Nothing ->
                Select.view (\_ -> settings.toMsg Ignored)
                    [ Select.label t.operator
                    , Select.labelHidden
                    , Select.placeholder "–"
                    , Select.disabled True
                    , Select.locale settings.locale
                    ]
                    (Select.init domId)

            Just field ->
                let
                    operators =
                        Rule.operatorsFor field.kind

                    stray =
                        if List.member condition.operator operators then
                            []

                        else
                            [ Select.option (operatorKey condition.operator) (Rule.operatorLabel settings.locale field.kind condition.operator)
                                |> Select.disabledOption
                            ]

                    state =
                        selectState settings.controls condition.id "op" domId
                            |> syncSelect (operatorKey condition.operator)
                in
                Select.view (\inner -> settings.toMsg (OperatorMsg condition.id field.kind inner))
                    [ Select.label t.operator
                    , Select.labelHidden
                    , Select.options
                        (stray
                            ++ List.map
                                (\operator ->
                                    Select.option (operatorKey operator) (Rule.operatorLabel settings.locale field.kind operator)
                                        |> Select.withKeywords (operatorWords settings.locale operator)
                                )
                                operators
                        )
                    , Select.searchPlaceholder t.searchOperator
                    , Select.visibleRows 11
                    , Select.locale settings.locale
                    , Select.errorMaybe (issueFor BlameOperator settings condition)
                    ]
                    state
        ]


{-| Does this condition need a value editor (a field is chosen and the
operator takes operands)?
-}
hasValueEditor : List (Field row) -> Condition -> Bool
hasValueEditor fields condition =
    case Rule.fieldById fields condition.field of
        Just field ->
            shapeOf field.kind condition.operator /= NoValue

        Nothing ->
            False


isKnownField : List (Field row) -> Condition -> Bool
isKnownField fields condition =
    Rule.fieldById fields condition.field /= Nothing


{-| The value editor(s) for the condition's field and operator. Empty when
the operator takes no value.
-}
viewValues : Settings row msg -> Condition -> Html msg
viewValues settings condition =
    case Rule.fieldById settings.fields condition.field of
        Nothing ->
            Html.text ""

        Just field ->
            let
                t =
                    texts settings.locale
            in
            case shapeOf field.kind condition.operator of
                NoValue ->
                    Html.text ""

                Single input ->
                    Html.div [ Internal.cls [ "klar-rule-editor__values" ] ]
                        [ viewInput settings condition 0 t.value input ]

                Range input ->
                    Html.div [ Internal.cls [ "klar-rule-editor__values", "klar-rule-editor__values--range" ] ]
                        [ viewInput settings condition 0 t.from input
                        , Html.div [ Internal.cls [ "klar-rule-editor__range-end" ] ]
                            [ Html.span [ Internal.cls [ "klar-rule-editor__and" ], Attr.attribute "aria-hidden" "true" ] [ Html.text t.and ]
                            , viewInput settings condition 1 t.to input
                            ]
                        ]

                Many choices ->
                    Html.div [ Internal.cls [ "klar-rule-editor__values" ] ]
                        [ viewMany settings condition choices ]


viewInput : Settings row msg -> Condition -> Int -> String -> Input -> Html msg
viewInput settings condition index label input =
    let
        t =
            texts settings.locale

        value =
            condition.values |> List.drop index |> List.head |> Maybe.withDefault ""
    in
    case input of
        TextIn ->
            viewText settings condition index { label = label, value = value, placeholder = t.textPlaceholder, numeric = Nothing, suffix = Nothing, modifier = "text" }

        NumberIn ->
            viewText settings condition index { label = label, value = value, placeholder = t.numberPlaceholder, numeric = Just "decimal", suffix = Nothing, modifier = "number" }

        DaysIn ->
            viewText settings condition index { label = label, value = value, placeholder = "30", numeric = Just "numeric", suffix = Just t.days, modifier = "days" }

        DateIn ->
            viewDate settings condition index label value

        ChoiceIn choices ->
            viewChoice settings condition index label value choices


viewText :
    Settings row msg
    -> Condition
    -> Int
    -> { label : String, value : String, placeholder : String, numeric : Maybe String, suffix : Maybe String, modifier : String }
    -> Html msg
viewText settings condition index options =
    Html.div [ Internal.cls [ "klar-rule-editor__value", "klar-rule-editor__value--" ++ options.modifier ] ]
        [ TextInput.view
            (List.filterMap identity
                [ Just (TextInput.id (valueDomId (prefixOf settings.controls) condition.id index))
                , Just (TextInput.label options.label)
                , Just TextInput.labelHidden
                , Just (TextInput.value options.value)
                , Just (TextInput.placeholder options.placeholder)
                , Just (TextInput.onInput (\text -> settings.toMsg (ValueTyped condition.id index text)))
                , Just (TextInput.onBlur (settings.toMsg (ValueLeft condition.id)))
                , Just (TextInput.autocomplete "off")
                , Just (TextInput.locale settings.locale)
                , Just (TextInput.errorMaybe (issueFor BlameValues settings condition))
                , Maybe.map TextInput.inputMode options.numeric
                , Maybe.map TextInput.suffixText options.suffix
                , Maybe.map TextInput.onEnter settings.onEnter
                ]
            )
        ]


viewDate : Settings row msg -> Condition -> Int -> String -> String -> Html msg
viewDate settings condition index label value =
    let
        (Controls c) =
            settings.controls

        state =
            Dict.get ( condition.id, index ) c.dates
                |> Maybe.withDefault (DatePicker.init (valueDomId c.prefix condition.id index))
                |> syncDate value
    in
    Html.div [ Internal.cls [ "klar-rule-editor__value", "klar-rule-editor__value--date" ] ]
        [ DatePicker.view (\inner -> settings.toMsg (DateMsg condition.id index inner))
            (List.filterMap identity
                [ Just (DatePicker.label label)
                , Just DatePicker.labelHidden
                , Just (DatePicker.locale settings.locale)
                , Just (DatePicker.errorMaybe (issueFor BlameValues settings condition))
                , Maybe.map DatePicker.today settings.today
                , if index == 1 then
                    Just DatePicker.alignEnd

                  else
                    Nothing
                ]
            )
            state
        ]


viewChoice : Settings row msg -> Condition -> Int -> String -> String -> List Rule.Choice -> Html msg
viewChoice settings condition index label value choices =
    let
        t =
            texts settings.locale

        stray =
            if value /= "" && not (List.any (\choice -> choice.value == value) choices) then
                [ Select.option value value |> Select.disabledOption ]

            else
                []

        state =
            selectState settings.controls condition.id ("v" ++ String.fromInt index) (valueDomId (prefixOf settings.controls) condition.id index)
                |> syncSelect value
    in
    Html.div [ Internal.cls [ "klar-rule-editor__value", "klar-rule-editor__value--choice" ] ]
        [ Select.view (\inner -> settings.toMsg (ChoiceMsg condition.id index inner))
            [ Select.label label
            , Select.labelHidden
            , Select.options (stray ++ List.map (\choice -> Select.option choice.value choice.label) choices)
            , Select.placeholder t.chooseValue
            , Select.locale settings.locale
            , Select.errorMaybe (issueFor BlameValues settings condition)
            ]
            state
        ]


viewMany : Settings row msg -> Condition -> List Rule.Choice -> Html msg
viewMany settings condition choices =
    let
        t =
            texts settings.locale

        (Controls c) =
            settings.controls

        chosen =
            List.filter (\value -> value /= "") condition.values

        stray =
            chosen
                |> List.filter (\value -> not (List.any (\choice -> choice.value == value) choices))
                |> List.map (\value -> Select.option value value)

        state =
            Dict.get condition.id c.multis
                |> Maybe.withDefault (MultiSelect.init (valueDomId c.prefix condition.id 0))
                |> syncMany chosen
    in
    Html.div [ Internal.cls [ "klar-rule-editor__value", "klar-rule-editor__value--many" ] ]
        [ MultiSelect.view (\inner -> settings.toMsg (ManyMsg condition.id inner))
            [ MultiSelect.label t.values
            , MultiSelect.labelHidden
            , MultiSelect.options (List.map (\choice -> Select.option choice.value choice.label) choices ++ stray)
            , MultiSelect.placeholder t.chooseValues
            , MultiSelect.maxVisibleChips 4
            , MultiSelect.locale settings.locale
            , MultiSelect.errorMaybe (issueFor BlameValues settings condition)
            ]
            state
        ]



-- SHAPES


type Shape
    = NoValue
    | Single Input
    | Range Input
    | Many (List Rule.Choice)


type Input
    = TextIn
    | NumberIn
    | DaysIn
    | DateIn
    | ChoiceIn (List Rule.Choice)


shapeOf : FieldKind -> Operator -> Shape
shapeOf kind operator =
    case Rule.operandsOf operator of
        NoOperand ->
            NoValue

        OneOperand ->
            Single (inputFor kind operator)

        TwoOperands ->
            Range (inputFor kind operator)

        ManyOperands ->
            case kind of
                ChoiceKind choices ->
                    Many choices

                _ ->
                    Single (inputFor kind operator)


inputFor : FieldKind -> Operator -> Input
inputFor kind operator =
    case kind of
        TextKind ->
            TextIn

        NumberKind ->
            NumberIn

        DateKind ->
            if operator == InLastDays || operator == InNextDays then
                DaysIn

            else
                DateIn

        BooleanKind ->
            TextIn

        ChoiceKind choices ->
            ChoiceIn choices


{-| Does switching operator change what kind of value is typed (a date versus
a number of days)? Then the old values make no sense and are cleared.
-}
inputChanged : Shape -> Shape -> Bool
inputChanged before after =
    case ( inputKey before, inputKey after ) of
        ( Just a, Just b ) ->
            a /= b

        _ ->
            False


inputKey : Shape -> Maybe String
inputKey shape =
    let
        key input =
            case input of
                TextIn ->
                    "text"

                NumberIn ->
                    "number"

                DaysIn ->
                    "days"

                DateIn ->
                    "date"

                ChoiceIn _ ->
                    "choice"
    in
    case shape of
        NoValue ->
            Nothing

        Single input ->
            Just (key input)

        Range input ->
            Just (key input)

        Many _ ->
            Just "choice"



-- OPERATORS


allOperators : List Operator
allOperators =
    [ Is, IsNot, Contains, NotContains, StartsWith, EndsWith, Equals, NotEquals, LessThan, LessOrEqual, GreaterThan, GreaterOrEqual, Between, Before, After, OnOrBefore, OnOrAfter, InLastDays, InNextDays, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty, IsTrue, IsFalse ]


{-| The option value of an operator in the operator picker.
-}
operatorKey : Operator -> String
operatorKey operator =
    case operator of
        Is ->
            "is"

        IsNot ->
            "isNot"

        Contains ->
            "contains"

        NotContains ->
            "notContains"

        StartsWith ->
            "startsWith"

        EndsWith ->
            "endsWith"

        Equals ->
            "eq"

        NotEquals ->
            "neq"

        LessThan ->
            "lt"

        LessOrEqual ->
            "lte"

        GreaterThan ->
            "gt"

        GreaterOrEqual ->
            "gte"

        Between ->
            "between"

        Before ->
            "before"

        After ->
            "after"

        OnOrBefore ->
            "onOrBefore"

        OnOrAfter ->
            "onOrAfter"

        InLastDays ->
            "inLastDays"

        InNextDays ->
            "inNextDays"

        IsAnyOf ->
            "anyOf"

        IsNoneOf ->
            "noneOf"

        IsEmpty ->
            "empty"

        IsNotEmpty ->
            "notEmpty"

        IsTrue ->
            "true"

        IsFalse ->
            "false"


operatorFromKey : String -> Maybe Operator
operatorFromKey key =
    allOperators |> List.filter (\operator -> operatorKey operator == key) |> List.head


{-| Words that find the symbolic operators in the picker's search box
("greater" finds ">").
-}
operatorWords : Locale -> Operator -> List String
operatorWords locale operator =
    let
        pick nb en =
            Locale.pick locale { nb = nb, en = en }
    in
    case operator of
        Equals ->
            pick [ "lik", "er lik" ] [ "equals" ]

        NotEquals ->
            pick [ "ulik", "ikke lik" ] [ "not equal" ]

        LessThan ->
            pick [ "mindre enn" ] [ "less than" ]

        LessOrEqual ->
            pick [ "høyst", "mindre eller lik" ] [ "at most" ]

        GreaterThan ->
            pick [ "større enn", "over" ] [ "greater than", "more than" ]

        GreaterOrEqual ->
            pick [ "minst", "større eller lik" ] [ "at least" ]

        _ ->
            []



-- CHIPS


{-| A condition in words, in three parts so a chip can style them:
`{ field = "Status", operator = "is any of", value = "Open, Paid +3" }`. `title`
has every value (for the tooltip); `value` is shortened after two values.
-}
chipParts : Locale -> List (Field row) -> Condition -> { field : String, operator : String, value : String, title : String, complete : Bool }
chipParts locale fields condition =
    let
        t =
            texts locale
    in
    case Rule.fieldById fields condition.field of
        Nothing ->
            let
                name =
                    if condition.field == "" then
                        t.noField

                    else
                        t.unknownField ++ ": " ++ condition.field
            in
            { field = name, operator = "", value = "", title = name, complete = False }

        Just field ->
            let
                values =
                    List.filter (\value -> String.trim value /= "") condition.values

                isDays =
                    condition.operator == InLastDays || condition.operator == InNextDays

                labelOf value =
                    case field.kind of
                        ChoiceKind choices ->
                            choices
                                |> List.filter (\choice -> choice.value == value)
                                |> List.head
                                |> Maybe.map .label
                                |> Maybe.withDefault value

                        DateKind ->
                            if isDays then
                                value

                            else
                                Date.fromIso value |> Maybe.map (Format.date locale) |> Maybe.withDefault value

                        TextKind ->
                            Rule.quote locale value

                        _ ->
                            value

                first =
                    List.head condition.values |> Maybe.withDefault ""

                ( operatorText, short, long ) =
                    if isDays then
                        let
                            words =
                                if String.trim first == "" then
                                    "…"

                                else if Rule.parseNumber first == Just 1 then
                                    first ++ " " ++ t.day

                                else
                                    first ++ " " ++ t.days
                        in
                        ( if condition.operator == InLastDays then
                            t.last

                          else
                            t.next
                        , words
                        , words
                        )

                    else
                        let
                            labels =
                                List.map labelOf values
                        in
                        ( Rule.operatorLabel locale field.kind condition.operator
                        , case Rule.operandsOf condition.operator of
                            NoOperand ->
                                ""

                            OneOperand ->
                                labels |> List.head |> Maybe.withDefault "…"

                            TwoOperands ->
                                case condition.values of
                                    low :: high :: _ ->
                                        orEllipsis (labelOrEmpty labelOf low) ++ " – " ++ orEllipsis (labelOrEmpty labelOf high)

                                    _ ->
                                        "…"

                            ManyOperands ->
                                if List.isEmpty labels then
                                    "…"

                                else if List.length labels > 2 then
                                    String.join ", " (List.take 2 labels) ++ " " ++ t.more (List.length labels - 2)

                                else
                                    String.join ", " labels
                        , case Rule.operandsOf condition.operator of
                            ManyOperands ->
                                String.join ", " labels

                            _ ->
                                ""
                        )
            in
            { field = field.label
            , operator = operatorText
            , value = short
            , title =
                String.join " "
                    (List.filter (\part -> part /= "")
                        [ field.label
                        , operatorText
                        , if long /= "" then
                            long

                          else
                            short
                        ]
                    )
            , complete = Rule.isComplete field condition
            }


labelOrEmpty : (String -> String) -> String -> String
labelOrEmpty labelOf value =
    if String.trim value == "" then
        ""

    else
        labelOf value


orEllipsis : String -> String
orEllipsis text =
    if text == "" then
        "…"

    else
        text



-- RULE HELPERS


valueAt : Int -> Int -> Rule -> String
valueAt node index rule =
    findCondition node rule
        |> Maybe.andThen (\condition -> List.head (List.drop index condition.values))
        |> Maybe.withDefault ""


{-| Problems `Rule.validate` does not look for, or describes too loosely: an
operator that does not belong to the field (from hand-written or old JSON),
and "in the last / next N days" without a number (it asks for a number of
days, not a date). They come first, so they win over `Rule.validate`'s message
for the same node.
-}
extraIssues : Locale -> List (Field row) -> Rule -> List Rule.Issue
extraIssues locale fields rule =
    case rule of
        GroupRule group ->
            List.concatMap (extraIssues locale fields) group.children

        ConditionRule condition ->
            case Rule.fieldById fields condition.field of
                Just field ->
                    if not (List.member condition.operator (Rule.operatorsFor field.kind)) then
                        [ { nodeId = condition.id, message = (texts locale).invalidOperator } ]

                    else if shapeOf field.kind condition.operator == Single DaysIn && not (Rule.isComplete field condition) then
                        [ { nodeId = condition.id, message = (texts locale).invalidDays } ]

                    else
                        []

                Nothing ->
                    []



-- TEXT


type alias Texts =
    { field : String
    , operator : String
    , value : String
    , values : String
    , from : String
    , to : String
    , and : String
    , day : String
    , days : String
    , chooseField : String
    , searchField : String
    , searchOperator : String
    , chooseValue : String
    , chooseValues : String
    , unknownField : String
    , noField : String
    , invalidOperator : String
    , invalidDays : String
    , textPlaceholder : String
    , numberPlaceholder : String
    , last : String
    , next : String
    , more : Int -> String
    }


texts : Locale -> Texts
texts locale =
    Locale.pick locale
        { nb =
            { field = "Felt"
            , operator = "Betingelse"
            , value = "Verdi"
            , values = "Verdier"
            , from = "Fra"
            , to = "Til"
            , and = "og"
            , day = "dag"
            , days = "dager"
            , chooseField = "Velg felt ..."
            , searchField = "Søk etter felt ..."
            , searchOperator = "Søk ..."
            , chooseValue = "Velg verdi ..."
            , chooseValues = "Velg verdier ..."
            , unknownField = "Ukjent felt"
            , noField = "Uten felt"
            , invalidOperator = "Betingelsen passer ikke til feltet"
            , invalidDays = "Skriv inn et antall dager"
            , textPlaceholder = "Tekst"
            , numberPlaceholder = "Tall"
            , last = "siste"
            , next = "neste"
            , more = \n -> "+" ++ String.fromInt n
            }
        , en =
            { field = "Field"
            , operator = "Operator"
            , value = "Value"
            , values = "Values"
            , from = "From"
            , to = "To"
            , and = "and"
            , day = "day"
            , days = "days"
            , chooseField = "Choose field ..."
            , searchField = "Search fields ..."
            , searchOperator = "Search ..."
            , chooseValue = "Choose value ..."
            , chooseValues = "Choose values ..."
            , unknownField = "Unknown field"
            , noField = "No field"
            , invalidOperator = "The operator does not fit the field"
            , invalidDays = "Enter a number of days"
            , textPlaceholder = "Text"
            , numberPlaceholder = "Number"
            , last = "in the last"
            , next = "in the next"
            , more = \n -> "+" ++ String.fromInt n
            }
        }
