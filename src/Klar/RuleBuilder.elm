module Klar.RuleBuilder exposing
    ( view
    , State, init, Msg, update
    , rule, setRule, clear
    , showIssues, hideIssues, issues, focusId, focusNode, focusIssue
    , Attribute, fields, today, maxDepth, label, locale
    , matchCount, totalCount, counting
    , json, importJson, actions
    )

{-| A visual editor for rules: groups of conditions that the user builds,
rearranges and reads as a sentence, drawn with thin gray connector lines.

Use when: users need the full power of nested "all of" and "any of" groups of conditions.
Do not use when: a row of filter chips above a table is enough (use `Klar.FilterBar`).
Quick path: `init`, `update`, `view`, `rule`

It edits a [Klar.Rule](Klar-Rule) `Rule` and never sees your rows: the
application runs the rule with `Rule.matches` and passes the number of matching
rows with `matchCount`. Use it when users need the full power of nested "all
of" and "any of" groups. For a row of filter chips above a table,
[Klar.FilterBar](Klar-FilterBar) is the lighter choice; both work on the same
`Rule`.

    import Klar.Rule as Rule
    import Klar.RuleBuilder as RuleBuilder

    -- model
    { rules : RuleBuilder.State } -- RuleBuilder.init "order-rules"

    -- update
    RulesMsg m ->
        let
            ( rules, cmd ) =
                RuleBuilder.update m model.rules
        in
        ( { model | rules = rules }, Cmd.map RulesMsg cmd )
        -- compare RuleBuilder.rule rules with RuleBuilder.rule model.rules
        -- to react to a change (save the rule, count the matches ...)

    -- view
    RuleBuilder.view RulesMsg
        [ RuleBuilder.fields orderFields
        , RuleBuilder.matchCount (Just (List.length matching))
        , RuleBuilder.today today
        , RuleBuilder.json
        ]
        model.rules

    -- the orders that match the rule
    matching =
        List.filter (Rule.matches today orderFields (RuleBuilder.rule model.rules)) model.orders

`orderFields` is a `List (Rule.Field Order)` made with `Rule.textField` and
friends. For a large data set the application can show `counting True` while it
works out the count.

**The outcome is yours.** A rule is only the condition: what happens when it
matches (a discount, a tag, a route) is neither in `Rule` nor in the builder. For
"if the category is X and the quantity is above Y, take Z off" keep one builder
per outcome, next to the control for the outcome, in a list of your own, and ask
each rule about the row:

    import Klar.Date exposing (Date)
    import Klar.Rule as Rule
    import Klar.RuleBuilder as RuleBuilder

    type alias Order =
        { category : String, quantity : Int }

    type alias PriceRule =
        { when : RuleBuilder.State, discountPercent : Float }

    orderFields : List (Rule.Field Order)
    orderFields =
        [ Rule.textField "category" "Category" .category
        , Rule.numberField "quantity" "Quantity" (.quantity >> toFloat >> Just)
        ]

    discountFor : Date -> List PriceRule -> Order -> Float
    discountFor today priceRules order =
        priceRules
            |> List.filter (\priceRule -> Rule.matches today orderFields (RuleBuilder.rule priceRule.when) order)
            |> List.map .discountPercent
            |> List.maximum
            |> Maybe.withDefault 0

Each `PriceRule` has its own `RuleBuilder.init` id, and the message of its builder
carries the index of the rule. Rules kept outside a `Klar.Form` report their
problems into it with `Form.outside`.

**Editors**: the field picker is a searchable [Klar.Select](Klar-Select),
grouped by the heading given with `Rule.inGroup`; the operators come from
`Rule.operatorsFor`. The value editor follows the field and the operator: a
text input, a number input (read by `Rule.parseNumber`: a decimal comma or
point and separators between the thousands, two inputs for "between"), a
[Klar.DatePicker](Klar-DatePicker) (the operand is stored as ISO `YYYY-MM-DD`),
a number of days for "in the last / next N days", a
[Klar.Select](Klar-Select) for one choice and a
[Klar.MultiSelect](Klar-MultiSelect) for "is any of" and "is none of". Yes or
no fields and "is empty" take no value.

**Issues** (`Rule.validate`) are shown on the node that has them: a red line
around the control and a short message. A node shows its issues once the user
has tried to fill it in (typed, picked, or left a value field), so a fresh,
empty condition is not red. `showIssues` shows every issue at once, for example
when the user tries to save. `issues` lists them for the application, and
`focusIssue` (or `focusNode` for one node) moves the focus to the control that
needs attention, so that a Save that finds an incomplete rule never leaves the
user looking at a button. `focusId` is the DOM id of that control, for a
`Form.Problem` that points into the builder: nothing is read from the page.

**A rule with an outcome.** The builder only says _when_; what happens then (a
discount, a label, a route) is the application's. In a form, declare it as a
row: `Spec.conditions` and the outcome's own field in one sub-form, `Spec.rows`
around it, and the form adds, removes, saves and checks the pairs (see
[`Klar.Form`](Klar-Form)). Outside a form, keep one record per rule, with a number
that stays with it when others are removed, and give each builder an id made from
that number:

    type alias PriceRule =
        { key : Int
        , when : RuleBuilder.State -- RuleBuilder.init ("price-rule-" ++ String.fromInt key)
        , discount : Maybe Float
        }

Draw the discount next to `RuleBuilder.view` in the same card, and focus the
first unfinished builder with `focusIssue`.

**Keyboard**: every control is reached with `Tab`. The pickers open with
`Enter`, `Space` or `ArrowDown` and search as you type; "All" and "Any" switch
with the arrow keys; the menu of a group (the three dots) moves, duplicates and
removes it. `Enter` in a value field does nothing destructive, and `Delete` or
`Backspace` never removes a condition or a group: they have buttons of their
own, and a removal, a reset or an import can be undone with the "Undo" button
that appears. Groups can be collapsed to a one-line summary.

**State and text**: the state holds the rule and what the user is doing with
it (collapsed groups, open pickers and menus, the JSON and import panels, the
last change that can be undone). The built-in text (buttons, issue messages,
the summary sentence) follows `locale`, which is English by default; the labels
of fields and choices come from the application.


# View

@docs view


# State

@docs State, init, Msg, update


# The rule

@docs rule, setRule, clear


# Issues and focus

@docs showIssues, hideIssues, issues, focusId, focusNode, focusIssue


# Attributes

@docs Attribute, fields, today, maxDepth, label, locale


# Match count

@docs matchCount, totalCount, counting


# Toolbar

@docs json, importJson, actions

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Date exposing (Date)
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Link as Link
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Rule as Rule exposing (Combinator(..), Condition, Field, FieldKind, Group, Rule(..))
import Klar.RuleBuilder.Editor as Editor
import Klar.RuleBuilder.Support as Support
import Klar.SegmentedControl as SegmentedControl
import Klar.Spinner as Spinner
import Klar.Theme exposing (Size(..), Tone(..))
import Set exposing (Set)



-- STATE


{-| The state of one rule builder: the rule and what the user is doing with it
(collapsed groups, open pickers and menus, the JSON and import panels, the
change that can be undone). Make one with `init`, keep it in your model and pass
it to `view` and `update`. Read the rule with `rule`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , rule : Rule
    , collapsed : Set Int
    , touched : Set Int
    , revealed : Bool
    , menus : Dict Int Menu.State
    , panel : Panel
    , importText : String
    , importProblem : Maybe ImportProblem
    , undo : Maybe Undo
    , controls : Editor.Controls
    }


type Panel
    = NoPanel
    | JsonPanel
    | ImportPanel


type ImportProblem
    = NotJson
    | NotARule
    | TooDeep Int Int


type alias Undo =
    { reason : UndoReason
    , rule : Rule
    , focus : String
    }


type UndoReason
    = RemovedCondition
    | RemovedGroup
    | ClearedAll
    | ImportedRule


{-| A rule builder with an empty rule, which matches every row. The `String` is
the DOM id of the builder and must be unique on the page; the ids of its inner
controls start with it.

    RuleBuilder.init "order-rules"

-}
init : String -> State
init id =
    State
        { id = id
        , rule = Rule.emptyGroup
        , collapsed = Set.empty
        , touched = Set.empty
        , revealed = False
        , menus = Dict.empty
        , panel = NoPanel
        , importText = ""
        , importProblem = Nothing
        , undo = Nothing
        , controls = Editor.emptyControls id
        }


{-| The rule being built. The root is always a group, with the id 0. Compare it
before and after `update` to find out whether the user changed the rule.
-}
rule : State -> Rule
rule (State s) =
    s.rule


{-| Replaces the rule, for example with a saved one. A rule that is a lone
condition is put in a group, and the nodes are renumbered from 0 if the root
does not have the id 0 or an id occurs twice. Collapsed groups and other state
are kept for the nodes that still exist; an offer to undo is dropped.
-}
setRule : Rule -> State -> State
setRule newRule (State s) =
    State (keepLive { s | rule = normalize newRule, undo = Nothing })


{-| Starts over with an empty rule. Unlike the "Reset" button of the toolbar it
does not offer to undo.
-}
clear : State -> State
clear (State s) =
    State (keepLive { s | rule = Rule.emptyGroup, undo = Nothing })


{-| Shows every issue now, also on nodes the user has not touched yet. Call it
when the user tries to save an incomplete rule.
-}
showIssues : State -> State
showIssues (State s) =
    State { s | revealed = True }


{-| Hides the issues again until the user touches a node, for example after a
successful save.
-}
hideIssues : State -> State
hideIssues (State s) =
    State { s | revealed = False, touched = Set.empty }


{-| Every issue the builder can show, for the fields given: the checks of
`Rule.validate` and the two the builder adds (an operator that does not fit the
field, a number of days that cannot be read). Each names the node it belongs to.
It is what a form or a save button asks before it lets the rule through; the
language is the one of the messages.

    RuleBuilder.issues Locale.en orderFields model.rules
    -- [ { nodeId = 2, message = "Enter a valid number" } ]

-}
issues : Locale -> List (Field row) -> State -> List Rule.Issue
issues lang fieldList (State s) =
    Editor.extraIssues lang fieldList s.rule ++ Rule.validate lang fieldList s.rule


{-| The DOM id of the control that stands for a node when the focus has to go
there: the first control a user fills in on a condition (the field picker when no
field is chosen, then the operator or the first value), the "add condition"
button of a group. Use it as the `field` of a `Form.Problem` that points at the
node, so that the summary of a form moves the focus into the builder. Nothing
needs to be read from the page: the id is made from the id given to `init`.
A node that does not exist leads to the "add condition" button of the whole rule.
-}
focusId : List (Field row) -> State -> Int -> String
focusId fieldList (State s) node =
    case findNode node s.rule of
        Just (ConditionRule condition) ->
            Editor.focusDomId s.id fieldList condition

        Just (GroupRule group) ->
            addRuleDomId s.id group.id

        Nothing ->
            addRuleDomId s.id 0


{-| Moves the focus to a node of the rule (see `focusId`). Map the command with
the constructor you wrap the builder's messages in.

    RuleBuilder.focusNode orderFields model.rules 2 |> Cmd.map RulesMsg

Nothing happens while the builder is not on screen.

-}
focusNode : List (Field row) -> State -> Int -> Cmd Msg
focusNode fieldList state node =
    Internal.focus (focusId fieldList state node) NoOp


{-| Moves the focus to the first node that has an issue (see `issues`), or to
the "add condition" button of the whole rule when there is none, for example
when the user presses Save on an empty rule. Use it with `showIssues`:

    ( RuleBuilder.showIssues rules, RuleBuilder.focusIssue orderFields rules |> Cmd.map RulesMsg )

-}
focusIssue : List (Field row) -> State -> Cmd Msg
focusIssue fieldList state =
    case issues Locale.default fieldList state of
        first :: _ ->
            focusNode fieldList state first.nodeId

        [] ->
            focusNode fieldList state 0


normalize : Rule -> Rule
normalize =
    Support.normalize


allIds : Rule -> List Int
allIds node =
    case node of
        ConditionRule condition ->
            [ condition.id ]

        GroupRule group ->
            group.id :: List.concatMap allIds group.children


{-| Forget UI state that belongs to nodes that are gone.
-}
keepLive : Inner -> Inner
keepLive s =
    let
        live =
            Support.nodeIds s.rule

        isLive id =
            Set.member id live
    in
    { s
        | collapsed = Set.filter isLive s.collapsed
        , touched = Set.filter isLive s.touched
        , menus = Dict.filter (\id _ -> isLive id) s.menus
        , controls = Editor.prune live s.controls
    }


{-| A change made by the user. Any change ends the offer to undo the last
removal.
-}
edit : Rule -> Inner -> Inner
edit newRule s =
    if newRule == s.rule then
        s

    else
        keepLive { s | rule = newRule, undo = Nothing }



-- UPDATE


{-| A message from the builder. Wrap it in one of your own messages and pass it
to `update`.
-}
type Msg
    = EditorMsg Editor.Msg
    | CombinatorPicked Int Combinator
    | NegationToggled Int
    | CollapseToggled Int
    | ConditionAdded Int (Maybe ( String, Support.Info ))
    | GroupAdded Int (Maybe ( String, Support.Info ))
    | Removed Int
    | Duplicated Int
    | Moved Int Int
    | MenuMsg Int Menu.Msg
    | ClearClicked
    | UndoClicked
    | PanelToggled Panel
    | ImportTyped String
    | ImportApplied Int
    | NoOp


{-| Applies a message from the builder. The command moves keyboard focus (to a
new condition, to a neighbour after a removal ...), so map it with `Cmd.map`.
Compare `rule` before and after to react to a change.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        EditorMsg inner ->
            let
                outcome =
                    Editor.update inner s.rule s.controls

                touched =
                    case outcome.touched of
                        Just node ->
                            Set.insert node s.touched

                        Nothing ->
                            s.touched
            in
            ( State (edit outcome.rule { s | controls = outcome.controls, touched = touched })
            , Cmd.map EditorMsg outcome.cmd
            )

        CombinatorPicked id combinator ->
            ( State (edit (Rule.setCombinator id combinator s.rule) s), Cmd.none )

        NegationToggled id ->
            ( State (edit (Rule.toggleNegated id s.rule) s), Cmd.none )

        CollapseToggled id ->
            ( State
                { s
                    | collapsed =
                        if Set.member id s.collapsed then
                            Set.remove id s.collapsed

                        else
                            Set.insert id s.collapsed
                }
            , Cmd.none
            )

        ConditionAdded groupId first ->
            let
                newId =
                    Rule.nextId s.rule
            in
            ( State (edit (Rule.addCondition (stubs first) groupId s.rule) { s | collapsed = Set.remove groupId s.collapsed })
            , Internal.focus (Editor.fieldDomId s.id newId) NoOp
            )

        GroupAdded parentId first ->
            let
                groupId =
                    Rule.nextId s.rule

                withGroup =
                    Rule.addGroup parentId s.rule

                conditionId =
                    Rule.nextId withGroup
            in
            ( State (edit (Rule.addCondition (stubs first) groupId withGroup) { s | collapsed = Set.remove parentId s.collapsed })
            , Internal.focus (Editor.fieldDomId s.id conditionId) NoOp
            )

        Removed id ->
            remove id s

        Duplicated id ->
            ( State (edit (Rule.duplicate id s.rule) s), Cmd.none )

        Moved id delta ->
            let
                newRule =
                    Rule.move id delta s.rule

                isCondition =
                    Support.findCondition id s.rule /= Nothing

                target =
                    case parentOf id newRule of
                        Just group ->
                            let
                                index =
                                    indexOf id group.children

                                count =
                                    List.length group.children
                            in
                            if delta < 0 then
                                if index == 0 then
                                    "-down"

                                else
                                    "-up"

                            else if index == count - 1 then
                                "-up"

                            else
                                "-down"

                        Nothing ->
                            "-up"
            in
            ( State (edit newRule s)
            , if isCondition then
                Internal.focus (nodeDomId s.id id ++ target) NoOp

              else
                Cmd.none
            )

        MenuMsg groupId inner ->
            let
                menu =
                    Dict.get groupId s.menus |> Maybe.withDefault (Menu.init (menuDomId s.id groupId))

                ( newMenu, cmd ) =
                    Menu.update inner menu
            in
            ( State
                { s
                    | menus =
                        if Set.member groupId (Support.nodeIds s.rule) then
                            Dict.insert groupId newMenu s.menus

                        else
                            Dict.remove groupId s.menus
                }
            , Cmd.map (MenuMsg groupId) cmd
            )

        ClearClicked ->
            if Rule.isEmpty s.rule && List.isEmpty (childrenOf s.rule) then
                ( State s, Cmd.none )

            else
                let
                    cleared =
                        keepLive { s | rule = Rule.emptyGroup }
                in
                ( State { cleared | undo = Just { reason = ClearedAll, rule = s.rule, focus = clearDomId s.id } }
                , Internal.focus (undoDomId s.id) NoOp
                )

        UndoClicked ->
            case s.undo of
                Just undo ->
                    ( State (keepLive { s | rule = undo.rule, undo = Nothing })
                    , Internal.focus undo.focus NoOp
                    )

                Nothing ->
                    ( State s, Cmd.none )

        PanelToggled panel ->
            if s.panel == panel then
                ( State { s | panel = NoPanel, importProblem = Nothing }, Cmd.none )

            else
                ( State { s | panel = panel, importProblem = Nothing }
                , if panel == ImportPanel then
                    Internal.focus (importDomId s.id) NoOp

                  else
                    Cmd.none
                )

        ImportTyped text ->
            ( State { s | importText = text, importProblem = Nothing }, Cmd.none )

        ImportApplied limit ->
            case Decode.decodeString Rule.decoder s.importText of
                Ok decoded ->
                    let
                        depth =
                            Rule.depth decoded
                    in
                    if depth > limit then
                        -- Not trimmed: cutting groups off would change what the
                        -- rule means. The text stays, so it can be simplified.
                        ( State { s | importProblem = Just (TooDeep depth limit) }
                        , Internal.focus (importDomId s.id) NoOp
                        )

                    else
                        let
                            imported =
                                keepLive
                                    { s
                                        | rule = normalize decoded
                                        , panel = NoPanel
                                        , importText = ""
                                        , importProblem = Nothing
                                        , revealed = True
                                        , collapsed = Set.empty
                                        , menus = Dict.empty
                                        , controls = Editor.resetControls s.controls
                                    }
                        in
                        ( State { imported | undo = Just { reason = ImportedRule, rule = s.rule, focus = importButtonDomId s.id } }
                        , Internal.focus (importButtonDomId s.id) NoOp
                        )

                Err _ ->
                    ( State
                        { s
                            | importProblem =
                                case Decode.decodeString Decode.value s.importText of
                                    Ok _ ->
                                        Just NotARule

                                    Err _ ->
                                        Just NotJson
                        }
                    , Internal.focus (importDomId s.id) NoOp
                    )

        NoOp ->
            ( State s, Cmd.none )


stubs : Maybe ( String, Support.Info ) -> List (Field ())
stubs first =
    case first of
        Just ( id, info ) ->
            [ Support.stub id info ]

        Nothing ->
            []


{-| Removes a node, offers to undo it, and moves focus to the neighbour (or
to the group's "add" button when the group is now empty).
-}
remove : Int -> Inner -> ( State, Cmd Msg )
remove id s =
    case ( findNode id s.rule, parentOf id s.rule ) of
        ( Just node, Just parent ) ->
            let
                index =
                    indexOf id parent.children

                siblings =
                    List.filter (\child -> Rule.idOf child /= id) parent.children

                neighbour =
                    case List.head (List.drop index siblings) of
                        Just next ->
                            Just next

                        Nothing ->
                            List.head (List.drop (index - 1) siblings)

                focusTarget =
                    case neighbour of
                        Just sibling ->
                            anchorDomId s.id sibling

                        Nothing ->
                            addRuleDomId s.id parent.id

                edited =
                    edit (Rule.remove id s.rule) s
            in
            ( State
                { edited
                    | undo =
                        Just
                            { reason =
                                case node of
                                    GroupRule _ ->
                                        RemovedGroup

                                    ConditionRule _ ->
                                        RemovedCondition
                            , rule = s.rule
                            , focus = anchorDomId s.id node
                            }
                    , touched =
                        if List.isEmpty siblings then
                            Set.insert parent.id edited.touched

                        else
                            edited.touched
                }
            , Internal.focus focusTarget NoOp
            )

        _ ->
            ( State s, Cmd.none )



-- TREE HELPERS


findNode : Int -> Rule -> Maybe Rule
findNode id node =
    if Rule.idOf node == id then
        Just node

    else
        case node of
            GroupRule group ->
                List.foldl
                    (\child found ->
                        case found of
                            Just _ ->
                                found

                            Nothing ->
                                findNode id child
                    )
                    Nothing
                    group.children

            ConditionRule _ ->
                Nothing


parentOf : Int -> Rule -> Maybe Group
parentOf id node =
    case node of
        GroupRule group ->
            if List.any (\child -> Rule.idOf child == id) group.children then
                Just group

            else
                List.foldl
                    (\child found ->
                        case found of
                            Just _ ->
                                found

                            Nothing ->
                                parentOf id child
                    )
                    Nothing
                    group.children

        ConditionRule _ ->
            Nothing


indexOf : Int -> List Rule -> Int
indexOf id children =
    children
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, child ) -> Rule.idOf child == id)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


childrenOf : Rule -> List Rule
childrenOf node =
    case node of
        GroupRule group ->
            group.children

        ConditionRule _ ->
            []


rootGroup : Rule -> Group
rootGroup node =
    case node of
        GroupRule group ->
            group

        ConditionRule condition ->
            { id = 0, combinator = All, negated = False, children = [ ConditionRule condition ] }


{-| Ids of every node below (and including) this one.
-}
subtreeIds : Rule -> List Int
subtreeIds =
    allIds



-- DOM IDS


nodeDomId : String -> Int -> String
nodeDomId prefix id =
    prefix ++ "-n" ++ String.fromInt id


toggleDomId : String -> Int -> String
toggleDomId prefix id =
    nodeDomId prefix id ++ "-toggle"


bodyDomId : String -> Int -> String
bodyDomId prefix id =
    nodeDomId prefix id ++ "-body"


menuDomId : String -> Int -> String
menuDomId prefix id =
    nodeDomId prefix id ++ "-menu"


addRuleDomId : String -> Int -> String
addRuleDomId prefix id =
    nodeDomId prefix id ++ "-add-rule"


addGroupDomId : String -> Int -> String
addGroupDomId prefix id =
    nodeDomId prefix id ++ "-add-group"


{-| The control that stands for a node when focus has to go to it.
-}
anchorDomId : String -> Rule -> String
anchorDomId prefix node =
    case node of
        GroupRule group ->
            toggleDomId prefix group.id

        ConditionRule condition ->
            nodeDomId prefix condition.id ++ "-remove"


clearDomId : String -> String
clearDomId prefix =
    prefix ++ "-clear"


undoDomId : String -> String
undoDomId prefix =
    prefix ++ "-undo"


importDomId : String -> String
importDomId prefix =
    prefix ++ "-import"


importButtonDomId : String -> String
importButtonDomId prefix =
    prefix ++ "-import-toggle"


jsonDomId : String -> String
jsonDomId prefix =
    prefix ++ "-json"


importPanelDomId : String -> String
importPanelDomId prefix =
    prefix ++ "-import-panel"



-- ATTRIBUTES


{-| A setting of the builder. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The type parameters are
the row type of your fields and your message type.
-}
type Attribute row msg
    = Attribute (Config row msg -> Config row msg)


type alias Config row msg =
    { fields : List (Field row)
    , locale : Locale
    , matchCount : Maybe Int
    , totalCount : Maybe Int
    , counting : Bool
    , today : Maybe Date
    , json : Bool
    , importJson : Bool
    , maxDepth : Int
    , label : Maybe String
    , actions : List (Html msg)
    }


configure : List (Attribute row msg) -> Config row msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { fields = []
        , locale = Locale.default
        , matchCount = Nothing
        , totalCount = Nothing
        , counting = False
        , today = Nothing
        , json = False
        , importJson = False
        , maxDepth = 4
        , label = Nothing
        , actions = []
        }
        attributes


{-| What the rules can talk about: the fields the user can pick for a
condition, made with `Rule.textField` and the other field functions. The first
field is the one a new condition starts with. The default is no fields.

    RuleBuilder.fields
        [ Rule.textField "country" "Country" .country
        , Rule.numberField "total" "Total" (.total >> Just)
        ]

-}
fields : List (Field row) -> Attribute row msg
fields value =
    Attribute (\config -> { config | fields = value })


{-| The language of the builder's own text: buttons, issue messages, the summary
sentence. The default is `Locale.default`, which is `Locale.en`. Field labels and
choices come from the application.
-}
locale : Locale -> Attribute row msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| How many rows the rule matches, counted by the application (for example
with `Rule.matches`). Shown next to the summary as "1,482 matches". `Nothing`,
the default, shows no count.
-}
matchCount : Maybe Int -> Attribute row msg
matchCount value =
    Attribute (\config -> { config | matchCount = value })


{-| The number of rows before filtering. With a `matchCount` the count reads
"1,482 of 3,000 matches". Without a `matchCount` nothing is shown.
-}
totalCount : Int -> Attribute row msg
totalCount value =
    Attribute (\config -> { config | totalCount = Just value })


{-| While `True` the builder shows a spinner and "Running ..." instead of the
count, for a large data set that takes time to filter. The default is `False`.
-}
counting : Bool -> Attribute row msg
counting value =
    Attribute (\config -> { config | counting = value })


{-| Today's date, for the date pickers of date fields: it marks the day, powers
their "Today" button and completes short input. It does not change what a rule
matches; give the same date to `Rule.matches`.
-}
today : Date -> Attribute row msg
today value =
    Attribute (\config -> { config | today = Just value })


{-| Adds a "Show JSON" button to the toolbar. It opens the rule as JSON
(`Rule.encode`, indented) with a "Download" link that saves it as `rule.json`.
-}
json : Attribute row msg
json =
    Attribute (\config -> { config | json = True })


{-| Adds an "Import JSON" button to the toolbar: the user pastes a rule as JSON
(the format of `Rule.decoder`) and applies it. Text that is not valid JSON, or
not a rule, gives a message. So does a rule with more levels of groups than
`maxDepth` allows: it is refused, never trimmed, because cutting groups off would
change what the rule means. A valid rule replaces the current one, and the
replacement can be undone.
-}
importJson : Attribute row msg
importJson =
    Attribute (\config -> { config | importJson = True })


{-| How many levels of groups a rule may have, counting the outermost group. The
default is 4, and values below 1 count as 1. Groups on the deepest level get no
"Add group" button, and an imported rule that is deeper is refused. A rule that
the application gives with `setRule` is shown as it is.
-}
maxDepth : Int -> Attribute row msg
maxDepth value =
    Attribute (\config -> { config | maxDepth = max 1 value })


{-| The accessible name of the builder. The default is "Rule builder".
-}
label : String -> Attribute row msg
label value =
    Attribute (\config -> { config | label = Just value })


{-| Extra buttons at the end of the builder's toolbar, such as a "Save rule"
button. They are your own `Html`, and their messages are yours.

    RuleBuilder.actions
        [ Button.view [ Button.primary, Button.onClick SaveRule ] "Save rule" ]

-}
actions : List (Html msg) -> Attribute row msg
actions value =
    Attribute (\config -> { config | actions = value })



-- VIEW


type alias Ctx row msg =
    { toMsg : Msg -> msg
    , config : Config row msg
    , state : Inner
    , issues : Dict Int String
    , texts : Texts
    }


type alias Position =
    { index : Int
    , count : Int
    }


{-| The builder: the tree of groups and conditions, then the summary sentence
(`Rule.describe`) with the match count, and the toolbar ("Reset", the JSON and
import buttons if asked for, and your `actions`). The first argument turns the
builder's messages into yours.

    RuleBuilder.view RulesMsg [ RuleBuilder.fields orderFields ] model.rules

-}
view : (Msg -> msg) -> List (Attribute row msg) -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        t =
            texts config.locale

        ctx =
            { toMsg = toMsg
            , config = config
            , state = s
            , issues = visibleIssues config s
            , texts = t
            }
    in
    Html.div
        [ Internal.cls [ "klar-rules" ]
        , Attr.id s.id
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (Maybe.withDefault t.builder config.label)
        , Attr.tabindex -1
        ]
        [ viewGroup ctx 0 Nothing (rootGroup s.rule)
        , viewFooter ctx
        ]


visibleIssues : Config row msg -> Inner -> Dict Int String
visibleIssues config s =
    (Editor.extraIssues config.locale config.fields s.rule ++ Rule.validate config.locale config.fields s.rule)
        |> List.filter (\issue -> s.revealed || Set.member issue.nodeId s.touched)
        |> List.foldl
            (\issue found ->
                if Dict.member issue.nodeId found then
                    found

                else
                    Dict.insert issue.nodeId issue.message found
            )
            Dict.empty


viewGroup : Ctx row msg -> Int -> Maybe Position -> Group -> Html msg
viewGroup ctx depth position group =
    let
        prefix =
            ctx.state.id

        collapsed =
            Set.member group.id ctx.state.collapsed

        invalid =
            Dict.member group.id ctx.issues
    in
    Html.div
        [ Internal.cls
            [ "klar-rules__group"
            , if depth == 0 then
                "klar-rules__group--root"

              else
                "klar-rules__group--nested"
            , if modBy 2 depth == 1 then
                "klar-rules__group--odd"

              else
                ""
            , if invalid then
                "klar-rules__group--invalid"

              else
                ""
            , if group.negated then
                "klar-rules__group--negated"

              else
                ""
            , if collapsed then
                "klar-rules__group--collapsed"

              else
                ""
            ]
        , Attr.id (nodeDomId prefix group.id)
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (groupName ctx.texts depth position group)
        ]
        [ viewHead ctx depth position group collapsed
        , if collapsed then
            Html.text ""

          else
            viewBody ctx depth group
        ]


groupName : Texts -> Int -> Maybe Position -> Group -> String
groupName t depth position group =
    let
        how =
            (if group.negated then
                t.not ++ " "

             else
                ""
            )
                ++ (case group.combinator of
                        All ->
                            t.all

                        Any ->
                            t.any
                   )
                ++ " "
                ++ t.ofTheFollowing
    in
    case position of
        Just pos ->
            t.groupN (pos.index + 1) ++ ": " ++ String.toLower how

        Nothing ->
            if depth == 0 then
                how

            else
                t.groupN 1 ++ ": " ++ String.toLower how


viewHead : Ctx row msg -> Int -> Maybe Position -> Group -> Bool -> Html msg
viewHead ctx depth position group collapsed =
    let
        t =
            ctx.texts

        prefix =
            ctx.state.id

        count =
            Rule.conditionCount (GroupRule group)

        hiddenIssues =
            if collapsed then
                subtreeIds (GroupRule group)
                    |> List.filter (\id -> Dict.member id ctx.issues)
                    |> List.length

            else
                0

        peek =
            if hasComplete ctx.config.fields (GroupRule group) then
                Rule.describe ctx.config.locale ctx.config.fields (GroupRule { group | negated = False })

            else
                t.noComplete
    in
    Html.div [ Internal.cls [ "klar-rules__head" ] ]
        [ Button.iconOnly
            [ Button.ghost
            , Button.small
            , Button.id (toggleDomId prefix group.id)
            , Button.expanded (not collapsed)

            -- the body is not in the page while the group is collapsed
            , Button.htmlAttrs [ Internal.attrIf (not collapsed) (Attr.attribute "aria-controls" (bodyDomId prefix group.id)) ]
            , Button.onClick (ctx.toMsg (CollapseToggled group.id))
            ]
            (if collapsed then
                Icon.chevronRight

             else
                Icon.chevronDown
            )
            (if collapsed then
                t.expand

             else
                t.collapse
            )
        , viewCombinator ctx group
        , Html.span [ Internal.cls [ "klar-rules__phrase" ] ] [ Html.text t.ofTheFollowing ]
        , Html.span [ Internal.cls [ "klar-rules__negate" ] ]
            [ Checkbox.view
                [ Checkbox.label t.not
                , Checkbox.checked group.negated
                , Checkbox.onCheck (\_ -> ctx.toMsg (NegationToggled group.id))
                , Checkbox.id (nodeDomId prefix group.id ++ "-not")
                ]
            ]
        , if collapsed then
            Html.span [ Internal.cls [ "klar-rules__peek", "klar-truncate" ], Attr.title peek ] [ Html.text peek ]

          else
            Html.text ""
        , Html.span [ Internal.cls [ "klar-rules__head-end" ] ]
            [ if hiddenIssues > 0 then
                Badge.view [ Badge.tone Danger, Badge.size Small ] (t.issues hiddenIssues)

              else
                Html.text ""
            , Html.span [ Internal.cls [ "klar-rules__count", "klar-tabular" ] ] [ Html.text (t.conditions count) ]
            , case position of
                Just pos ->
                    viewGroupMenu ctx group pos

                Nothing ->
                    Html.text ""
            ]
        ]


hasComplete : List (Field row) -> Rule -> Bool
hasComplete fieldList node =
    case node of
        ConditionRule condition ->
            Rule.fieldById fieldList condition.field
                |> Maybe.map (\field -> Rule.isComplete field condition)
                |> Maybe.withDefault False

        GroupRule group ->
            List.any (hasComplete fieldList) group.children


viewCombinator : Ctx row msg -> Group -> Html msg
viewCombinator ctx group =
    let
        t =
            ctx.texts
    in
    Html.span [ Internal.cls [ "klar-rules__combinator" ] ]
        [ SegmentedControl.view
            [ SegmentedControl.id (nodeDomId ctx.state.id group.id ++ "-combinator")
            , SegmentedControl.ariaLabel t.combine
            , SegmentedControl.size Small
            , SegmentedControl.options
                [ SegmentedControl.option "all" t.all
                , SegmentedControl.option "any" t.any
                ]
            , SegmentedControl.selected
                (Just
                    (case group.combinator of
                        All ->
                            "all"

                        Any ->
                            "any"
                    )
                )
            , SegmentedControl.onSelect
                (\value ->
                    ctx.toMsg
                        (CombinatorPicked group.id
                            (if value == "any" then
                                Any

                             else
                                All
                            )
                        )
                )
            ]
        ]


viewGroupMenu : Ctx row msg -> Group -> Position -> Html msg
viewGroupMenu ctx group position =
    let
        t =
            ctx.texts

        menu =
            Dict.get group.id ctx.state.menus
                |> Maybe.withDefault (Menu.init (menuDomId ctx.state.id group.id))

        disabledIf condition item =
            if condition then
                Menu.disabledItem item

            else
                item
    in
    Menu.view (\inner -> ctx.toMsg (MenuMsg group.id inner))
        [ Menu.kebab t.groupActions
        , Menu.alignEnd
        , Menu.trigger [ Button.small ]
        , Menu.items
            [ Menu.item t.moveGroupUp (ctx.toMsg (Moved group.id -1))
                |> Menu.withIcon Icon.arrowUp
                |> disabledIf (position.index == 0)
            , Menu.item t.moveGroupDown (ctx.toMsg (Moved group.id 1))
                |> Menu.withIcon Icon.arrowDown
                |> disabledIf (position.index >= position.count - 1)
            , Menu.item t.duplicateGroup (ctx.toMsg (Duplicated group.id))
                |> Menu.withIcon Icon.copy
            , Menu.separator
            , Menu.item t.removeGroup (ctx.toMsg (Removed group.id))
                |> Menu.withIcon Icon.trash
                |> Menu.danger
            ]
        ]
        menu


viewBody : Ctx row msg -> Int -> Group -> Html msg
viewBody ctx depth group =
    let
        count =
            List.length group.children

        children =
            List.indexedMap
                (\index child ->
                    ( String.fromInt (Rule.idOf child)
                    , viewChild ctx depth group { index = index, count = count } child
                    )
                )
                group.children
    in
    Html.div [ Internal.cls [ "klar-rules__body" ], Attr.id (bodyDomId ctx.state.id group.id) ]
        [ Keyed.ul [ Internal.cls [ "klar-rules__children" ] ]
            (children ++ [ ( "add", viewAddLine ctx depth group ) ])
        ]


viewChild : Ctx row msg -> Int -> Group -> Position -> Rule -> Html msg
viewChild ctx depth parent position child =
    Html.li
        [ Internal.cls
            [ "klar-rules__child"
            , case child of
                GroupRule _ ->
                    "klar-rules__child--group"

                ConditionRule _ ->
                    "klar-rules__child--condition"
            ]
        ]
        [ if position.index > 0 then
            Html.span [ Internal.cls [ "klar-rules__joiner" ] ]
                [ Html.text
                    (case parent.combinator of
                        All ->
                            ctx.texts.and

                        Any ->
                            ctx.texts.or
                    )
                ]

          else
            Html.text ""
        , case child of
            GroupRule group ->
                viewGroup ctx (depth + 1) (Just position) group

            ConditionRule condition ->
                viewCondition ctx position condition
        ]


viewCondition : Ctx row msg -> Position -> Condition -> Html msg
viewCondition ctx position condition =
    let
        t =
            ctx.texts

        base =
            nodeDomId ctx.state.id condition.id

        issue =
            Dict.get condition.id ctx.issues

        settings =
            { toMsg = ctx.toMsg << EditorMsg
            , fields = ctx.config.fields
            , locale = ctx.config.locale
            , controls = ctx.state.controls
            , issue = issue
            , layout = Editor.Inline
            , today = ctx.config.today
            , onEnter = Nothing
            }

        action suffix icon text disabled msg =
            Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.id (base ++ suffix)
                , Button.disabled disabled
                , Button.onClick (ctx.toMsg msg)
                ]
                icon
                text
    in
    Html.div
        [ Internal.cls
            [ "klar-rules__condition"
            , if issue /= Nothing then
                "klar-rules__condition--invalid"

              else
                ""
            ]
        , Attr.id base
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (t.ruleN (position.index + 1))
        ]
        [ Html.div [ Internal.cls [ "klar-rules__editor" ] ]
            [ Editor.viewField settings condition
            , Editor.viewOperator settings condition
            , Editor.viewValues settings condition
            ]
        , Html.div [ Internal.cls [ "klar-rules__actions" ] ]
            [ action "-up" Icon.arrowUp t.moveUp (position.index == 0) (Moved condition.id -1)
            , action "-down" Icon.arrowDown t.moveDown (position.index >= position.count - 1) (Moved condition.id 1)
            , action "-dup" Icon.copy t.duplicate False (Duplicated condition.id)
            , action "-remove" Icon.close t.remove False (Removed condition.id)
            ]
        , case issue of
            Just message ->
                Html.p [ Internal.cls [ "klar-rules__issue" ], Attr.id (base ++ "-issue") ]
                    [ Icon.sized Icon.Small Icon.errorCircle
                    , Html.span [] [ Html.text message ]
                    ]

            Nothing ->
                Html.text ""
        ]


viewAddLine : Ctx row msg -> Int -> Group -> Html msg
viewAddLine ctx depth group =
    let
        t =
            ctx.texts

        prefix =
            ctx.state.id

        first =
            ctx.config.fields |> List.head |> Maybe.map (\field -> ( Rule.fieldId field, Support.infoOf field ))

        isEmpty =
            List.isEmpty group.children
    in
    Html.li [ Internal.cls [ "klar-rules__child", "klar-rules__child--add" ] ]
        [ Html.div [ Internal.cls [ "klar-rules__add" ] ]
            [ Button.view
                [ Button.ghost
                , Button.small
                , Button.icon Icon.plus
                , Button.id (addRuleDomId prefix group.id)
                , Button.ariaLabel t.addRuleLong
                , Button.onClick (ctx.toMsg (ConditionAdded group.id first))
                ]
                t.addRule
            , if depth + 1 < ctx.config.maxDepth then
                Button.view
                    [ Button.ghost
                    , Button.small
                    , Button.icon Icon.plus
                    , Button.id (addGroupDomId prefix group.id)
                    , Button.ariaLabel t.addGroupLong
                    , Button.onClick (ctx.toMsg (GroupAdded group.id first))
                    ]
                    t.addGroup

              else
                Html.text ""
            , case Dict.get group.id ctx.issues of
                Just message ->
                    Html.span [ Internal.cls [ "klar-rules__issue", "klar-rules__issue--inline" ] ]
                        [ Icon.sized Icon.Small Icon.errorCircle
                        , Html.span [] [ Html.text message ]
                        ]

                Nothing ->
                    if isEmpty then
                        Html.span [ Internal.cls [ "klar-rules__empty" ] ]
                            [ Html.text
                                (if depth == 0 then
                                    t.rootEmpty

                                 else
                                    t.groupEmpty
                                )
                            ]

                    else
                        Html.text ""
            ]
        ]



-- FOOTER


viewFooter : Ctx row msg -> Html msg
viewFooter ctx =
    let
        t =
            ctx.texts

        s =
            ctx.state

        config =
            ctx.config

        isEmpty =
            List.isEmpty (childrenOf s.rule)
    in
    Html.div [ Internal.cls [ "klar-rules__footer" ] ]
        [ Html.div [ Internal.cls [ "klar-rules__summary" ] ]
            [ Html.span [ Internal.cls [ "klar-rules__summary-icon" ] ] [ Icon.view Icon.filter ]
            , Html.p [ Internal.cls [ "klar-rules__sentence" ] ]
                [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (t.summary ++ ": ") ]
                , Html.text (Rule.describe config.locale config.fields s.rule)
                ]
            , viewCount ctx
            ]
        , Html.div [ Internal.cls [ "klar-rules__toolbar" ] ]
            (List.concat
                [ [ Button.view
                        [ Button.ghost
                        , Button.small
                        , Button.icon Icon.refresh
                        , Button.id (clearDomId s.id)
                        , Button.disabled isEmpty
                        , Button.onClick (ctx.toMsg ClearClicked)
                        ]
                        t.reset
                  ]
                , if config.json then
                    [ Button.view
                        [ Button.ghost
                        , Button.small
                        , Button.icon Icon.code
                        , Button.expanded (s.panel == JsonPanel)

                        -- the panel is only in the page while it is open
                        , Button.htmlAttrs [ Internal.attrIf (s.panel == JsonPanel) (Attr.attribute "aria-controls" (jsonDomId s.id)) ]
                        , Button.onClick (ctx.toMsg (PanelToggled JsonPanel))
                        ]
                        (if s.panel == JsonPanel then
                            t.hideJson

                         else
                            t.showJson
                        )
                    ]

                  else
                    []
                , if config.importJson then
                    [ Button.view
                        [ Button.ghost
                        , Button.small
                        , Button.icon Icon.upload
                        , Button.id (importButtonDomId s.id)
                        , Button.expanded (s.panel == ImportPanel)
                        , Button.htmlAttrs [ Internal.attrIf (s.panel == ImportPanel) (Attr.attribute "aria-controls" (importPanelDomId s.id)) ]
                        , Button.onClick (ctx.toMsg (PanelToggled ImportPanel))
                        ]
                        t.importJson
                    ]

                  else
                    []
                , config.actions
                , [ Html.span [ Internal.cls [ "klar-rules__undo" ], Attr.attribute "role" "status" ]
                        (case s.undo of
                            Just undo ->
                                [ Html.span [] [ Html.text (undoText t undo.reason) ]
                                , Button.view
                                    [ Button.link
                                    , Button.id (undoDomId s.id)
                                    , Button.onClick (ctx.toMsg UndoClicked)
                                    ]
                                    t.undo
                                ]

                            Nothing ->
                                []
                        )
                  ]
                ]
            )
        , case s.panel of
            JsonPanel ->
                if config.json then
                    viewJson ctx

                else
                    Html.text ""

            ImportPanel ->
                if config.importJson then
                    viewImport ctx

                else
                    Html.text ""

            NoPanel ->
                Html.text ""
        ]


viewCount : Ctx row msg -> Html msg
viewCount ctx =
    let
        config =
            ctx.config

        number =
            Format.int config.locale
    in
    Html.span [ Internal.cls [ "klar-rules__matches", "klar-tabular" ], Attr.attribute "aria-live" "polite" ]
        (if config.counting then
            [ Spinner.view [ Spinner.size Small ], Html.text ctx.texts.counting ]

         else
            case config.matchCount of
                Just n ->
                    case config.totalCount of
                        Just total ->
                            [ Html.strong [] [ Html.text (number n) ]
                            , Html.text (" " ++ ctx.texts.of_ ++ " " ++ number total ++ " " ++ ctx.texts.hits)
                            ]

                        Nothing ->
                            [ Html.strong [] [ Html.text (number n) ]
                            , Html.text (" " ++ ctx.texts.hits)
                            ]

                Nothing ->
                    []
        )


undoText : Texts -> UndoReason -> String
undoText t reason =
    case reason of
        RemovedCondition ->
            t.removedRule

        RemovedGroup ->
            t.removedGroup

        ClearedAll ->
            t.cleared

        ImportedRule ->
            t.imported


viewJson : Ctx row msg -> Html msg
viewJson ctx =
    let
        text =
            Encode.encode 2 (Rule.encode ctx.state.rule)
    in
    Html.div [ Internal.cls [ "klar-rules__panel" ] ]
        [ Html.div [ Internal.cls [ "klar-rules__panel-head" ] ]
            [ Html.span [ Internal.cls [ "klar-rules__panel-title" ] ] [ Html.text "JSON" ]
            , Button.view
                [ Button.ghost
                , Button.small
                , Button.icon Icon.download
                , Button.href (Link.download { fileName = ctx.texts.fileName, mimeType = "application/json", content = text })
                ]
                ctx.texts.download
            ]
        , Html.pre
            [ Internal.cls [ "klar-rules__json" ]
            , Attr.id (jsonDomId ctx.state.id)
            , Attr.tabindex 0
            , Attr.attribute "aria-label" "JSON"
            ]
            [ Html.code [] [ Html.text text ] ]
        ]


viewImport : Ctx row msg -> Html msg
viewImport ctx =
    let
        t =
            ctx.texts

        s =
            ctx.state

        problemId =
            importDomId s.id ++ "-error"
    in
    Html.div [ Internal.cls [ "klar-rules__panel" ], Attr.id (importPanelDomId s.id) ]
        [ Html.label [ Internal.cls [ "klar-field__label" ], Attr.for (importDomId s.id) ] [ Html.text t.importLabel ]
        , Html.textarea
            [ Internal.cls
                [ "klar-rules__import"
                , if s.importProblem /= Nothing then
                    "klar-rules__import--invalid"

                  else
                    ""
                ]
            , Attr.id (importDomId s.id)
            , Attr.value s.importText
            , Attr.rows 6
            , Attr.spellcheck False
            , Attr.placeholder "{ \"type\": \"group\", \"combinator\": \"all\", \"children\": [ ... ] }"
            , Events.onInput (\text -> ctx.toMsg (ImportTyped text))
            , Internal.attrIf (s.importProblem /= Nothing) (Attr.attribute "aria-invalid" "true")
            , Internal.attrIf (s.importProblem /= Nothing) (Attr.attribute "aria-describedby" problemId)
            ]
            []
        , case s.importProblem of
            Just problem ->
                Html.p [ Internal.cls [ "klar-rules__issue" ], Attr.id problemId, Attr.attribute "role" "alert" ]
                    [ Icon.sized Icon.Small Icon.errorCircle
                    , Html.span []
                        [ Html.text
                            (case problem of
                                NotJson ->
                                    t.notJson

                                NotARule ->
                                    t.notARule

                                TooDeep depth limit ->
                                    t.tooDeep depth limit
                            )
                        ]
                    ]

            Nothing ->
                Html.p [ Internal.cls [ "klar-rules__hint" ] ] [ Html.text t.importHint ]
        , Html.div [ Internal.cls [ "klar-rules__panel-actions" ] ]
            [ Button.view [ Button.primary, Button.small, Button.onClick (ctx.toMsg (ImportApplied ctx.config.maxDepth)) ] t.apply
            , Button.view [ Button.small, Button.onClick (ctx.toMsg (PanelToggled ImportPanel)) ] t.cancel
            ]
        ]



-- TEXT


type alias Texts =
    { builder : String
    , all : String
    , any : String
    , ofTheFollowing : String
    , combine : String
    , not : String
    , and : String
    , or : String
    , conditions : Int -> String
    , issues : Int -> String
    , addRule : String
    , addRuleLong : String
    , addGroup : String
    , addGroupLong : String
    , moveUp : String
    , moveDown : String
    , duplicate : String
    , remove : String
    , moveGroupUp : String
    , moveGroupDown : String
    , duplicateGroup : String
    , removeGroup : String
    , groupActions : String
    , collapse : String
    , expand : String
    , rootEmpty : String
    , groupEmpty : String
    , noComplete : String
    , ruleN : Int -> String
    , groupN : Int -> String
    , summary : String
    , of_ : String
    , hits : String
    , counting : String
    , reset : String
    , showJson : String
    , hideJson : String
    , importJson : String
    , importLabel : String
    , importHint : String
    , apply : String
    , cancel : String
    , download : String
    , fileName : String
    , notJson : String
    , notARule : String
    , tooDeep : Int -> Int -> String
    , undo : String
    , removedRule : String
    , removedGroup : String
    , cleared : String
    , imported : String
    }


texts : Locale -> Texts
texts lang =
    Locale.pick lang
        { nb =
            { builder = "Regelbygger"
            , all = "Alle"
            , any = "Minst én"
            , ofTheFollowing = "av følgende"
            , combine = "Hvilke regler må stemme"
            , not = "Ikke"
            , and = "og"
            , or = "eller"
            , conditions =
                \n ->
                    if n == 1 then
                        "1 regel"

                    else
                        String.fromInt n ++ " regler"
            , issues =
                \n ->
                    if n == 1 then
                        "1 feil"

                    else
                        String.fromInt n ++ " feil"
            , addRule = "Regel"
            , addRuleLong = "Legg til regel"
            , addGroup = "Gruppe"
            , addGroupLong = "Legg til gruppe"
            , moveUp = "Flytt opp"
            , moveDown = "Flytt ned"
            , duplicate = "Dupliser"
            , remove = "Fjern"
            , moveGroupUp = "Flytt gruppen opp"
            , moveGroupDown = "Flytt gruppen ned"
            , duplicateGroup = "Dupliser gruppen"
            , removeGroup = "Fjern gruppen"
            , groupActions = "Handlinger for gruppen"
            , collapse = "Skjul gruppen"
            , expand = "Vis gruppen"
            , rootEmpty = "Ingen regler ennå. Alle rader tas med."
            , groupEmpty = "Gruppen er tom."
            , noComplete = "Ingen fullstendige regler"
            , ruleN = \n -> "Regel " ++ String.fromInt n
            , groupN = \n -> "Gruppe " ++ String.fromInt n
            , summary = "Sammendrag"
            , of_ = "av"
            , hits = "treff"
            , counting = "Kjører ..."
            , reset = "Nullstill"
            , showJson = "Vis JSON"
            , hideJson = "Skjul JSON"
            , importJson = "Importer JSON"
            , importLabel = "Lim inn en regel som JSON"
            , importHint = "Regelen erstatter den du har nå. Du kan angre etterpå."
            , apply = "Bruk"
            , cancel = "Avbryt"
            , download = "Last ned"
            , fileName = "regel.json"
            , notJson = "Teksten er ikke gyldig JSON."
            , notARule = "JSON-en beskriver ikke en regel (type, combinator, children ...)."
            , tooDeep =
                \depth limit ->
                    "Regelen har "
                        ++ levelsNb depth
                        ++ " med grupper, men høyst "
                        ++ levelsNb limit
                        ++ " er tillatt. Forenkle regelen og prøv igjen."
            , undo = "Angre"
            , removedRule = "Regelen ble fjernet."
            , removedGroup = "Gruppen ble fjernet."
            , cleared = "Alle regler ble fjernet."
            , imported = "Regelen ble importert."
            }
        , en =
            { builder = "Rule builder"
            , all = "All"
            , any = "Any"
            , ofTheFollowing = "of the following"
            , combine = "Which conditions must match"
            , not = "Not"
            , and = "and"
            , or = "or"
            , conditions =
                \n ->
                    if n == 1 then
                        "1 condition"

                    else
                        String.fromInt n ++ " conditions"
            , issues =
                \n ->
                    if n == 1 then
                        "1 issue"

                    else
                        String.fromInt n ++ " issues"
            , addRule = "Condition"
            , addRuleLong = "Add condition"
            , addGroup = "Group"
            , addGroupLong = "Add group"
            , moveUp = "Move up"
            , moveDown = "Move down"
            , duplicate = "Duplicate"
            , remove = "Remove"
            , moveGroupUp = "Move group up"
            , moveGroupDown = "Move group down"
            , duplicateGroup = "Duplicate group"
            , removeGroup = "Remove group"
            , groupActions = "Group actions"
            , collapse = "Collapse group"
            , expand = "Expand group"
            , rootEmpty = "No conditions yet. Every row is included."
            , groupEmpty = "The group is empty."
            , noComplete = "No complete conditions"
            , ruleN = \n -> "Condition " ++ String.fromInt n
            , groupN = \n -> "Group " ++ String.fromInt n
            , summary = "Summary"
            , of_ = "of"
            , hits = "matches"
            , counting = "Running ..."
            , reset = "Reset"
            , showJson = "Show JSON"
            , hideJson = "Hide JSON"
            , importJson = "Import JSON"
            , importLabel = "Paste a rule as JSON"
            , importHint = "It replaces the current rule. You can undo it afterwards."
            , apply = "Apply"
            , cancel = "Cancel"
            , download = "Download"
            , fileName = "rule.json"
            , notJson = "The text is not valid JSON."
            , notARule = "The JSON does not describe a rule (type, combinator, children ...)."
            , tooDeep =
                \depth limit ->
                    "The rule has "
                        ++ levelsEn depth
                        ++ " of groups, but at most "
                        ++ levelsEn limit
                        ++ " are allowed. Simplify the rule and try again."
            , undo = "Undo"
            , removedRule = "The condition was removed."
            , removedGroup = "The group was removed."
            , cleared = "All conditions were removed."
            , imported = "The rule was imported."
            }
        }


{-| The number of levels as text for the `Locale.nb` locale, in the singular or the
plural.
-}
levelsNb : Int -> String
levelsNb n =
    if n == 1 then
        "1 nivå"

    else
        String.fromInt n ++ " nivåer"


{-| "1 level", "4 levels"
-}
levelsEn : Int -> String
levelsEn n =
    if n == 1 then
        "1 level"

    else
        String.fromInt n ++ " levels"
