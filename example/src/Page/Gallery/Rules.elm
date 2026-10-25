module Page.Gallery.Rules exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: the rule builder, the filter bar and saved views.

The main example is a workbench where the three components edit one rule and a
table of the 3,000 sample orders is filtered with `Rule.matches`.

-}

import Api.Types as Types exposing (OrderId, OrderStatus(..), Priority(..), allOrderStatuses, allPriorities, orderStatusLabel, priorityLabel)
import Html exposing (Html)
import Html.Lazy
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Date as Date
import Klar.FilterBar as FilterBar
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Modal as Modal
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Remote as Remote
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))
import Klar.RuleBuilder as RuleBuilder
import Klar.SavedViews as SavedViews
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme
import Process
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import View.Ids exposing (orderRows)
import View.Labels as Labels



-- MODEL


type alias Model =
    { workbench : Bench
    , table : Table.State OrderId
    , applied : Rule
    , matchCount : Int
    , slow : Bool
    , counting : Bool
    , version : Int
    , empty : RuleBuilder.State
    , invalid : RuleBuilder.State
    , narrow : RuleBuilder.State
    , narrowCount : Int
    , quick : FilterBar.State
    , quickCount : Int
    , noViews : SavedViews.State
    , dialog : Modal.State
    , draft : RuleBuilder.State
    , dialogRule : Rule
    , dialogCount : Int
    , norwegian : Bench
    , norwegianCount : Int
    }


{-| The three components that edit one rule, and the rule they share.
-}
type alias Bench =
    { builder : RuleBuilder.State
    , filters : FilterBar.State
    , views : SavedViews.State
    , rule : Rule
    }


type Msg
    = WorkbenchMsg BenchMsg
    | TableMsg Table.Msg
    | ResetAll
    | SlowToggled Bool
    | Counted Int
    | EmptyMsg RuleBuilder.Msg
    | InvalidMsg RuleBuilder.Msg
    | CheckInvalid
    | HideInvalid
    | NarrowMsg RuleBuilder.Msg
    | QuickMsg FilterBar.Msg
    | NoViewsMsg SavedViews.Msg
    | DialogOpened
    | DialogMsg Modal.Msg
    | DraftMsg RuleBuilder.Msg
    | DialogApplied
    | DialogCancelled
    | NorwegianMsg BenchMsg


type BenchMsg
    = BuilderMsg RuleBuilder.Msg
    | FiltersMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | NewViewAsked


init : ( Model, Cmd Msg )
init =
    ( { workbench = newBench "rules-bench" preloaded seededViews (Just "Confirmed and urgent or large")
      , table = Table.init "rules-bench-table"
      , applied = preloaded
      , matchCount = countMatches preloaded
      , slow = False
      , counting = False
      , version = 0
      , empty = RuleBuilder.init "rules-empty"
      , invalid = RuleBuilder.init "rules-invalid" |> RuleBuilder.setRule invalidRule |> RuleBuilder.showIssues
      , narrow = RuleBuilder.init "rules-narrow" |> RuleBuilder.setRule narrowRule
      , narrowCount = countMatches narrowRule
      , quick = FilterBar.init "rules-quick"
      , quickCount = List.length Sample.orders
      , noViews = SavedViews.init "rules-no-views"
      , dialog = Modal.init "rules-dialog"
      , draft = RuleBuilder.init "rules-dialog-builder"
      , dialogRule = dialogStart
      , dialogCount = countMatches dialogStart
      , norwegian = newBench "rules-nb" norwegianRule norwegianViews (Just "Bekreftet i Oslo")
      , norwegianCount = countWith norwegianFields norwegianRule
      }
    , Cmd.none
    )


newBench : String -> Rule -> List SavedViews.SavedView -> Maybe String -> Bench
newBench id rule views active =
    let
        builder =
            RuleBuilder.init id |> RuleBuilder.setRule rule
    in
    { builder = builder
    , filters = FilterBar.init (id ++ "-filters") |> FilterBar.setRule rule
    , views = SavedViews.init (id ++ "-views") |> SavedViews.setViews views |> SavedViews.setActive active
    , rule = RuleBuilder.rule builder
    }



-- RULES


condition : Int -> String -> Operator -> List String -> Rule
condition id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


group : Int -> Combinator -> List Rule -> Rule
group id combinator children =
    GroupRule { id = id, combinator = combinator, negated = False, children = children }


{-| "Status is Confirmed and (Priority is Urgent or Total > 5000)"
-}
preloaded : Rule
preloaded =
    group 0
        All
        [ condition 1 "status" Is [ "confirmed" ]
        , group 2
            Any
            [ condition 3 "priority" Is [ "urgent" ]
            , condition 4 "total" GreaterThan [ "5000" ]
            ]
        ]


urgent : Rule
urgent =
    condition 1 "priority" Is [ "urgent" ]


confirmed : Rule
confirmed =
    condition 1 "status" Is [ "confirmed" ]


overdue : Rule
overdue =
    condition 1 "overdue" IsTrue []


unassigned : Rule
unassigned =
    condition 1 "owner" IsEmpty []


createdRecently : Rule
createdRecently =
    condition 1 "created" InLastDays [ "30" ]


large : Rule
large =
    condition 1 "total" GreaterThan [ "5000" ]


notCreatedRecently : Rule
notCreatedRecently =
    GroupRule
        { id = 0
        , combinator = All
        , negated = True
        , children = [ condition 1 "created" InLastDays [ "90" ] ]
        }


seededViews : List SavedViews.SavedView
seededViews =
    [ SavedViews.savedView "All confirmed orders" confirmed
        |> SavedViews.asDefault
    , SavedViews.savedView "Urgent orders" urgent
        |> SavedViews.withNote "Checked every morning by the order desk"
        |> SavedViews.asShared
    , SavedViews.savedView "Confirmed and urgent or large" preloaded
        |> SavedViews.withNote "The starting point of the workbench"
    , SavedViews.savedView "Not created in the last 90 days" notCreatedRecently
    , SavedViews.savedView "Rotterdam and Hamburg" (condition 1 "city" IsAnyOf [ "Rotterdam", "Hamburg" ])
    ]


presets : List ( String, Rule )
presets =
    [ ( "Urgent", urgent )
    , ( "Confirmed", confirmed )
    , ( "Overdue", overdue )
    , ( "Unassigned", unassigned )
    , ( "Created in the last 30 days", createdRecently )
    , ( "Total over 5,000", large )
    ]


{-| Everything that can be wrong with a rule at once: a value that is not a
number, an empty text, dates the wrong way round, a field that does not exist,
an empty group and an operator that does not fit the field.
-}
invalidRule : Rule
invalidRule =
    group 0
        All
        [ condition 1 "total" GreaterThan [ "five thousand" ]
        , condition 2 "customer" Contains [ "" ]
        , condition 3 "created" Between [ "2026-10-01", "2026-09-01" ]
        , condition 4 "carrier" Is [ "dhl" ]
        , group 5 Any []
        , condition 6 "priority" GreaterThan [ "high" ]
        ]


narrowRule : Rule
narrowRule =
    group 0
        All
        [ condition 1 "city" IsAnyOf [ "Rotterdam", "Hamburg", "Gothenburg", "Oslo", "Copenhagen" ]
        , condition 2 "created" Between [ "2026-08-01", "2026-09-30" ]
        , condition 3 "lines" GreaterOrEqual [ "12" ]
        ]


{-| Long enough that the body of the dialog scrolls: in a dialog of the default
width every condition takes two lines.
-}
dialogStart : Rule
dialogStart =
    group 0
        All
        [ condition 1 "status" IsAnyOf [ "confirmed", "picking" ]
        , condition 2 "created" InLastDays [ "90" ]
        , group 3
            Any
            [ condition 4 "priority" Is [ "urgent" ]
            , condition 5 "total" GreaterOrEqual [ "6000" ]
            , condition 6 "lines" GreaterThan [ "20" ]
            ]
        , condition 7 "due" Before [ "2026-11-01" ]
        , condition 8 "city" IsNot [ "Oslo" ]
        , condition 9 "owner" IsNoneOf [ "Liam Chen" ]
        , condition 10 "customer" NotContains [ "Ltd" ]
        , condition 11 "warehouse" IsAnyOf [ "RTM", "HAM", "GOT", "CHI" ]
        , condition 12 "country" IsNoneOf [ "NO", "SE" ]
        ]


norwegianRule : Rule
norwegianRule =
    group 0
        All
        [ condition 1 "status" Is [ "confirmed" ]
        , condition 2 "city" Is [ "Oslo" ]
        ]


norwegianViews : List SavedViews.SavedView
norwegianViews =
    [ SavedViews.savedView "Haster" urgent |> SavedViews.asDefault
    , SavedViews.savedView "Bekreftet i Oslo" norwegianRule |> SavedViews.withNote "Gjennomgås hver uke"
    ]



-- FIELDS


orderFields : List (Rule.Field Types.Order)
orderFields =
    [ Rule.textField "customer" "Customer" .customer |> Rule.inGroup "Order"
    , Rule.choiceField "status" "Status" (statusChoices Locale.en) (.status >> statusValue) |> Rule.inGroup "Order"
    , Rule.choiceField "priority" "Priority" (priorityChoices Locale.en) (.priority >> priorityValue) |> Rule.inGroup "Order"
    , Rule.numberField "total" "Total" (.total >> Just) |> Rule.inGroup "Order"
    , Rule.numberField "lines" "Order lines" (.lines >> toFloat >> Just) |> Rule.inGroup "Order"
    , Rule.boolField "overdue" "Overdue" isOverdue |> Rule.inGroup "Order"
    , Rule.dateField "created" "Created" (.created >> Just) |> Rule.inGroup "Dates"
    , Rule.dateField "due" "Due date" (.due >> Just) |> Rule.inGroup "Dates"
    , Rule.dateField "delivered" "Delivered on" .delivered |> Rule.inGroup "Dates"
    , Rule.choiceField "owner" "Owner" ownerChoices (.owner >> Maybe.map Sample.ownerName >> Maybe.withDefault "") |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf, Rule.IsNoneOf ] |> Rule.inGroup "Handling"
    , Rule.choiceField "warehouse" "Warehouse" warehouseChoices (.warehouse >> Types.warehouseIdText) |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf, Rule.IsNoneOf ] |> Rule.inGroup "Handling"
    , Rule.choiceField "country" "Country" countryChoices (.country >> Types.countryCodeText) |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf, Rule.IsNoneOf ] |> Rule.inGroup "Delivery"
    , Rule.choiceField "city" "City" cityChoices .city |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf, Rule.IsNoneOf ] |> Rule.inGroup "Delivery"
    ]


{-| The same fields with Norwegian labels, for the example that shows the `Locale.nb`
locale: the labels of fields and choices are the application's own.
-}
norwegianFields : List (Rule.Field Types.Order)
norwegianFields =
    [ Rule.textField "customer" "Kunde" .customer |> Rule.inGroup "Ordre"
    , Rule.choiceField "status" "Status" (statusChoices Locale.nb) (.status >> statusValue) |> Rule.inGroup "Ordre"
    , Rule.choiceField "priority" "Prioritet" (priorityChoices Locale.nb) (.priority >> priorityValue) |> Rule.inGroup "Ordre"
    , Rule.numberField "total" "Totalsum" (.total >> Just) |> Rule.inGroup "Ordre"
    , Rule.boolField "overdue" "Forsinket" isOverdue |> Rule.inGroup "Ordre"
    , Rule.dateField "created" "Opprettet" (.created >> Just) |> Rule.inGroup "Ordre"
    , Rule.choiceField "city" "By" cityChoices .city |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf, Rule.IsNoneOf ] |> Rule.inGroup "Levering"
    ]


cityChoices : List Rule.Choice
cityChoices =
    Sample.cities
        |> List.sort
        |> List.map (\city -> { value = city, label = city })


countryChoices : List Rule.Choice
countryChoices =
    List.map (\country -> { value = Types.countryCodeText country.code, label = country.name }) Sample.countries


ownerChoices : List Rule.Choice
ownerChoices =
    List.map (\name -> { value = name, label = name }) Sample.owners


warehouseChoices : List Rule.Choice
warehouseChoices =
    List.map (\warehouse -> { value = Types.warehouseIdText warehouse.id, label = warehouse.name }) Sample.warehouses


statusChoices : Locale -> List Rule.Choice
statusChoices locale =
    List.map (\status -> { value = statusValue status, label = statusText locale status }) allOrderStatuses


priorityChoices : Locale -> List Rule.Choice
priorityChoices locale =
    List.map (\priority -> { value = priorityValue priority, label = priorityText locale priority }) allPriorities


statusValue : OrderStatus -> String
statusValue status =
    case status of
        Draft ->
            "draft"

        Confirmed ->
            "confirmed"

        Picking ->
            "picking"

        Shipped ->
            "shipped"

        Delivered ->
            "delivered"

        Cancelled ->
            "cancelled"


statusText : Locale -> OrderStatus -> String
statusText locale status =
    if locale == Locale.nb then
        case status of
            Draft ->
                "Utkast"

            Confirmed ->
                "Bekreftet"

            Picking ->
                "Plukkes"

            Shipped ->
                "Sendt"

            Delivered ->
                "Levert"

            Cancelled ->
                "Kansellert"

    else
        orderStatusLabel status


priorityValue : Priority -> String
priorityValue priority =
    case priority of
        Low ->
            "low"

        Normal ->
            "normal"

        High ->
            "high"

        Urgent ->
            "urgent"


priorityText : Locale -> Priority -> String
priorityText locale priority =
    if locale == Locale.nb then
        case priority of
            Low ->
                "Lav"

            Normal ->
                "Normal"

            High ->
                "Høy"

            Urgent ->
                "Haster"

    else
        priorityLabel priority


{-| Open and due before today. The rule builder cannot work this out from the
other fields, so the application offers it as a field of its own.
-}
isOverdue : Types.Order -> Bool
isOverdue order =
    order.status /= Delivered && order.status /= Cancelled && Date.compare order.due Sample.today == LT


{-| The conditions that take part in filtering (an incomplete one does not).
-}
completeConditions : List (Rule.Field row) -> Rule -> Int
completeConditions fields rule =
    case rule of
        ConditionRule c ->
            case Rule.fieldById fields c.field of
                Just field ->
                    if Rule.isComplete field c then
                        1

                    else
                        0

                Nothing ->
                    0

        GroupRule g ->
            List.sum (List.map (completeConditions fields) g.children)


countMatches : Rule -> Int
countMatches =
    countWith orderFields


countWith : List (Rule.Field Types.Order) -> Rule -> Int
countWith fields rule =
    List.foldl
        (\order n ->
            if Rule.matches Sample.today fields rule order then
                n + 1

            else
                n
        )
        0
        Sample.orders



-- UPDATE


type Source
    = FromBuilder
    | FromFilters
    | FromViews
    | FromPage


{-| Gives a rule to the components that did not make it. The one that made it
keeps its own state: setting its own rule would throw away its undo.
-}
syncRule : Source -> Rule -> Bench -> Bench
syncRule source rule bench =
    let
        builder =
            if source == FromBuilder then
                bench.builder

            else
                RuleBuilder.setRule rule bench.builder
    in
    { bench
        | builder = builder
        , filters =
            if source == FromFilters then
                bench.filters

            else
                FilterBar.setRule rule bench.filters
        , rule = RuleBuilder.rule builder
    }


{-| Applies a message to the three components. When it changed the rule, the
rule goes to the other two and the source is returned.
-}
updateBench : BenchMsg -> Bench -> ( Bench, Cmd BenchMsg, Maybe Source )
updateBench msg bench =
    case msg of
        BuilderMsg inner ->
            let
                ( builder, cmd ) =
                    RuleBuilder.update inner bench.builder
            in
            if RuleBuilder.rule builder /= RuleBuilder.rule bench.builder then
                ( syncRule FromBuilder (RuleBuilder.rule builder) { bench | builder = builder }
                , Cmd.map BuilderMsg cmd
                , Just FromBuilder
                )

            else
                ( { bench | builder = builder }, Cmd.map BuilderMsg cmd, Nothing )

        FiltersMsg inner ->
            let
                ( filters, cmd ) =
                    FilterBar.update inner bench.filters
            in
            if FilterBar.rule filters /= FilterBar.rule bench.filters then
                ( syncRule FromFilters (FilterBar.rule filters) { bench | filters = filters }
                , Cmd.map FiltersMsg cmd
                , Just FromFilters
                )

            else
                ( { bench | filters = filters }, Cmd.map FiltersMsg cmd, Nothing )

        NewViewAsked ->
            -- What a command or a shortcut does: the list opens with the save form.
            let
                ( views, cmd ) =
                    SavedViews.startSave bench.views
            in
            ( { bench | views = views }, Cmd.map ViewsMsg cmd, Nothing )

        ViewsMsg inner ->
            let
                ( views, cmd ) =
                    SavedViews.update inner bench.views
            in
            if SavedViews.revision views /= SavedViews.revision bench.views then
                -- the user applied a view or reset: load the rule of the active one
                ( syncRule FromViews
                    (SavedViews.active views |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup)
                    { bench | views = views }
                , Cmd.map ViewsMsg cmd
                , Just FromViews
                )

            else
                ( { bench | views = views }, Cmd.map ViewsMsg cmd, Nothing )


{-| The rule of the workbench changed: run it. Typing in the rule builder waits
for a pause, a big data set takes its time, anything else is immediate.
-}
runRule : Source -> Model -> ( Model, Cmd Msg )
runRule source model =
    let
        rule =
            model.workbench.rule

        version =
            model.version + 1
    in
    if model.slow then
        -- a big data set: say so while it runs
        ( { model | counting = True, version = version }
        , Process.sleep 900 |> Task.perform (\_ -> Counted version)
        )

    else if source == FromBuilder then
        -- typing in the builder: run the rule when the user pauses
        ( { model | version = version }
        , Process.sleep 250 |> Task.perform (\_ -> Counted version)
        )

    else
        ( { model | applied = rule, matchCount = countMatches rule, counting = False, version = version }
        , Cmd.none
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WorkbenchMsg inner ->
            let
                ( bench, cmd, changed ) =
                    updateBench inner model.workbench

                ( next, work ) =
                    case changed of
                        Just source ->
                            runRule source { model | workbench = bench }

                        Nothing ->
                            ( { model | workbench = bench }, Cmd.none )
            in
            ( next, Cmd.batch [ Cmd.map WorkbenchMsg cmd, work ] )

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        ResetAll ->
            runRule FromPage { model | workbench = syncRule FromPage Rule.emptyGroup model.workbench }

        SlowToggled on ->
            ( { model | slow = on }, Cmd.none )

        Counted version ->
            if version == model.version then
                ( { model
                    | applied = model.workbench.rule
                    , matchCount = countMatches model.workbench.rule
                    , counting = False
                  }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        EmptyMsg inner ->
            let
                ( state, cmd ) =
                    RuleBuilder.update inner model.empty
            in
            ( { model | empty = state }, Cmd.map EmptyMsg cmd )

        InvalidMsg inner ->
            let
                ( state, cmd ) =
                    RuleBuilder.update inner model.invalid
            in
            ( { model | invalid = state }, Cmd.map InvalidMsg cmd )

        CheckInvalid ->
            ( { model | invalid = RuleBuilder.showIssues model.invalid }, Cmd.none )

        HideInvalid ->
            ( { model | invalid = RuleBuilder.hideIssues model.invalid }, Cmd.none )

        NarrowMsg inner ->
            let
                ( state, cmd ) =
                    RuleBuilder.update inner model.narrow
            in
            ( { model
                | narrow = state
                , narrowCount =
                    if RuleBuilder.rule state /= RuleBuilder.rule model.narrow then
                        countMatches (RuleBuilder.rule state)

                    else
                        model.narrowCount
              }
            , Cmd.map NarrowMsg cmd
            )

        QuickMsg inner ->
            let
                ( state, cmd ) =
                    FilterBar.update inner model.quick
            in
            ( { model
                | quick = state
                , quickCount =
                    if FilterBar.rule state /= FilterBar.rule model.quick then
                        countMatches (FilterBar.rule state)

                    else
                        model.quickCount
              }
            , Cmd.map QuickMsg cmd
            )

        NoViewsMsg inner ->
            let
                ( state, cmd ) =
                    SavedViews.update inner model.noViews
            in
            ( { model | noViews = state }, Cmd.map NoViewsMsg cmd )

        DialogOpened ->
            let
                ( dialog, cmd ) =
                    Modal.open "rules-dialog-open" model.dialog
            in
            -- the dialog works on a copy of the rule
            ( { model
                | dialog = dialog
                , draft =
                    model.draft
                        |> RuleBuilder.setRule model.dialogRule
                        |> RuleBuilder.hideIssues
              }
            , Cmd.map DialogMsg cmd
            )

        DialogMsg inner ->
            let
                ( dialog, cmd ) =
                    Modal.update inner model.dialog
            in
            ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )

        DraftMsg inner ->
            let
                ( state, cmd ) =
                    RuleBuilder.update inner model.draft
            in
            ( { model | draft = state }, Cmd.map DraftMsg cmd )

        DialogApplied ->
            let
                edited =
                    RuleBuilder.rule model.draft
            in
            if List.isEmpty (Rule.validate Locale.en orderFields edited) then
                let
                    ( dialog, cmd ) =
                        Modal.close model.dialog
                in
                ( { model | dialog = dialog, dialogRule = edited, dialogCount = countMatches edited }
                , Cmd.map DialogMsg cmd
                )

            else
                ( { model | draft = RuleBuilder.showIssues model.draft }, Cmd.none )

        DialogCancelled ->
            let
                ( dialog, cmd ) =
                    Modal.close model.dialog
            in
            ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )

        NorwegianMsg inner ->
            let
                ( bench, cmd, changed ) =
                    updateBench inner model.norwegian
            in
            ( { model
                | norwegian = bench
                , norwegianCount =
                    case changed of
                        Just _ ->
                            countWith norwegianFields bench.rule

                        Nothing ->
                            model.norwegianCount
              }
            , Cmd.map NorwegianMsg cmd
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Overlay.host
        { attributes = []
        , page =
            [ Doc.page
                { title = "Rules and filters"
                , description = "Rules that filter data: a rule builder with groups and conditions, a filter bar with quick filters above a table, and saved views. All three edit the same data model (Klar.Rule), which the application runs with Rule.matches."
                }
                [ workbench locale model
                , ruleBuilders locale model
                , filterBars locale model
                , savedViews locale model
                , norwegian model
                , api
                ]
            ]
        , overlays = [ viewDialog locale model ]
        }


viewDialog : Locale -> Model -> Overlay Msg
viewDialog locale model =
    Modal.view DialogMsg
        [ Modal.title "Edit rule"
        , Modal.subtitle "Orders to review this week"
        , Modal.locale locale
        , Modal.footer
            [ Button.view [ Button.onClick DialogCancelled ] "Cancel"
            , Button.view [ Button.primary, Button.onClick DialogApplied ] "Apply rule"
            ]
        ]
        model.dialog
        [ RuleBuilder.view DraftMsg
            [ RuleBuilder.fields orderFields
            , RuleBuilder.locale locale
            , RuleBuilder.today Sample.today
            , RuleBuilder.label "Rule for the review list"
            ]
            model.draft
        ]


{-| Saved views and the filter bar above the rule builder, all editing one rule.
The views button sits above the bar rather than next to it: side by side the bar
gets a narrow column (and runs off a phone screen).
-}
viewBench :
    { toMsg : BenchMsg -> Msg
    , locale : Locale
    , fields : List (Rule.Field Types.Order)
    , quick : List ( String, Rule )
    , matchCount : Int
    , counting : Bool
    , label : String
    }
    -> Bench
    -> Html Msg
viewBench options bench =
    Layout.stack [ Layout.gap 4 ]
        [ Layout.stack [ Layout.gap 3, Layout.alignStart ]
            [ Layout.row [ Layout.gap 2, Layout.alignCenter ]
                [ SavedViews.view (ViewsMsg >> options.toMsg)
                    [ SavedViews.current bench.rule
                    , SavedViews.size Theme.Small
                    , SavedViews.locale options.locale
                    ]
                    bench.views
                , Button.view [ Button.ghost, Button.small, Button.onClick (options.toMsg NewViewAsked) ] "New view ..."
                ]
            , FilterBar.view (FiltersMsg >> options.toMsg)
                [ FilterBar.fields options.fields
                , FilterBar.quick options.quick
                , FilterBar.today Sample.today
                , FilterBar.locale options.locale
                ]
                bench.filters
            ]
        , RuleBuilder.view (BuilderMsg >> options.toMsg)
            [ RuleBuilder.fields options.fields
            , RuleBuilder.locale options.locale
            , RuleBuilder.matchCount (Just options.matchCount)
            , RuleBuilder.totalCount (List.length Sample.orders)
            , RuleBuilder.counting options.counting
            , RuleBuilder.today Sample.today
            , RuleBuilder.json
            , RuleBuilder.importJson
            , RuleBuilder.label options.label
            ]
            bench.builder
        ]


{-| The number of sample orders as the page writes it: "3,000".
-}
orderCount : String
orderCount =
    Format.int Locale.en (List.length Sample.orders)


workbench : Locale -> Model -> Html Msg
workbench locale model =
    Doc.section "Workbench"
        ("Saved views, the filter bar and the rule builder edit one and the same rule, and the table of "
            ++ orderCount
            ++ " orders is filtered with Rule.matches as you go. Change the rule in one place and the others follow. A view is marked “modified” when the rule is no longer the same as the saved one."
        )
        [ Doc.example
            { title = orderCount ++ " orders, one rule"
            , description = Just "Preloaded: Status is Confirmed and (Priority is Urgent or Total > 5000). The application runs the rule a quarter of a second after you stop typing; switch on the slow count to see the “Running ...” state that a large data set gives. A condition that is not complete yet shows as a dashed chip in the filter bar and does not filter. “Show JSON” and “Import JSON” in the toolbar of the rule builder take the rule out and in as JSON."
            , code = Just workbenchCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ viewBench
                    { toMsg = WorkbenchMsg
                    , locale = locale
                    , fields = orderFields
                    , quick = presets
                    , matchCount = model.matchCount
                    , counting = model.counting
                    , label = "Rule for the order list"
                    }
                    model.workbench
                , Checkbox.view
                    [ Checkbox.id "rules-slow-count"
                    , Checkbox.label "Simulate a slow count (large data set)"
                    , Checkbox.hint "The rule runs 0.9 seconds after the last change; meanwhile the rule builder says “Running ...” and the table is dimmed."
                    , Checkbox.checked model.slow
                    , Checkbox.onCheck SlowToggled
                    ]
                , Html.Lazy.lazy4 viewTable locale model.applied model.counting model.table
                ]
            )
        ]


{-| The table filters its 3,000 rows with the rule in `view`; rendering it
lazily keeps typing in the builder fast (it is redrawn when the applied rule,
the counting flag or the table's own state changes, not on every keystroke
elsewhere).
-}
viewTable : Locale -> Rule -> Bool -> Table.State OrderId -> Html Msg
viewTable locale applied counting table =
    Table.view TableMsg
        [ Table.columns orderColumns
        , Table.remote
            (if counting then
                Remote.refresh (Remote.Loaded Sample.orders)

             else
                Remote.Loaded Sample.orders
            )
        , Table.rowId orderRows .id
        , Table.rowFilter (Rule.matches Sample.today orderFields applied)
        , Table.activeExternalFilters (completeConditions orderFields applied)
        , Table.onResetFilters ResetAll
        , Table.ariaLabel "Orders"
        , Table.locale locale
        , Table.maxHeight 420
        , Table.pageSizes [ 25, 50, 100 ]
        ]
        table


orderColumns : List (Table.Column Types.Order Msg)
orderColumns =
    [ Table.text (Table.columnId "id") "Order" (.id >> Types.orderIdText) [ Table.width 100 ]
    , Table.text (Table.columnId "customer") "Customer" .customer [ Table.minWidth 180 ]
    , Table.badge (Table.columnId "status") "Status" (\order -> ( Labels.statusTone order.status, orderStatusLabel order.status )) [ Table.width 124 ]
    , Table.status (Table.columnId "priority") "Priority" (\order -> ( Labels.priorityTone order.priority, priorityLabel order.priority )) [ Table.width 100 ]
    , Table.text (Table.columnId "owner") "Owner" (.owner >> Maybe.map Sample.ownerName >> Maybe.withDefault "") [ Table.width 130 ]
    , Table.int (Table.columnId "lines") "Lines" .lines [ Table.width 80 ]
    , Table.float (Table.columnId "total") "Total" 2 .total [ Table.width 112 ]
    , Table.date (Table.columnId "created") "Created" .created [ Table.width 112 ]
    , Table.date (Table.columnId "due") "Due" .due [ Table.width 112 ]
    ]


workbenchCode : String
workbenchCode =
    """-- the fields: what a rule can talk about, and how to read it from an order
orderFields : List (Rule.Field Order)
orderFields =
    [ Rule.textField "customer" "Customer" .customer
    , Rule.choiceField "status" "Status" statusChoices (.status >> statusValue)
    , Rule.numberField "total" "Total" (.total >> Just)
    , Rule.boolField "overdue" "Overdue" isOverdue
    , Rule.dateField "created" "Created" (.created >> Just)
    ]

countMatches : Rule -> Int
countMatches rule =
    List.length (List.filter (Rule.matches today orderFields rule) orders)

-- one rule in the model; whoever changed it hands it on to the others
BuilderMsg m ->
    let
        ( builder, cmd ) =
            RuleBuilder.update m model.builder
    in
    if RuleBuilder.rule builder /= RuleBuilder.rule model.builder then
        let
            rule =
                RuleBuilder.rule builder
        in
        ( { model
            | builder = builder
            , filters = FilterBar.setRule rule model.filters
            , rule = rule
            , matches = countMatches rule
          }
        , Cmd.map BuilderMsg cmd
        )

    else
        ( { model | builder = builder }, Cmd.map BuilderMsg cmd )

-- FiltersMsg is the same the other way round

ViewsMsg m ->
    let
        ( views, cmd ) =
            SavedViews.update m model.views
    in
    if SavedViews.revision views /= SavedViews.revision model.views then
        -- the user applied a view: load its rule into the other components
        let
            rule =
                SavedViews.active views |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup
        in
        ( { model
            | views = views
            , builder = RuleBuilder.setRule rule model.builder
            , filters = FilterBar.setRule rule model.filters
            , rule = rule
            , matches = countMatches rule
          }
        , Cmd.map ViewsMsg cmd
        )

    else
        ( { model | views = views }, Cmd.map ViewsMsg cmd )

SavedViews.view ViewsMsg [ SavedViews.current model.rule ] model.views

RuleBuilder.view BuilderMsg
    [ RuleBuilder.fields orderFields
    , RuleBuilder.matchCount (Just model.matches)
    , RuleBuilder.totalCount (List.length orders)
    , RuleBuilder.counting model.counting
    , RuleBuilder.today today
    , RuleBuilder.json
    , RuleBuilder.importJson
    ]
    model.builder

Table.view TableMsg
    [ Table.columns columns
    , Table.remote (Remote.refresh (Remote.Loaded orders)) -- dimmed while counting
    , Table.rowFilter (Rule.matches today orderFields model.rule)
    , Table.activeExternalFilters (Rule.conditionCount model.rule)
    , Table.onResetFilters ResetAll
    ]
    model.table"""


ruleBuilders : Locale -> Model -> Html Msg
ruleBuilders locale model =
    Doc.section "Rule builder"
        "A tree of groups and conditions, drawn with thin gray lines. A group is “All” (and) or “Any” (or) of its conditions and can be turned around with “Not”; the three-dot menu of a group moves, duplicates and removes it, and a group can be collapsed to one line. The field picker searches and groups the fields; the value editor follows the field type and the operator. Keyboard: Tab moves through every control. Enter, Space or ArrowDown opens a picker, type to search, Enter chooses. All and Any switch with the arrow keys. Enter in a value field does nothing, and Delete or Backspace never removes a condition: use the Remove button, and take it back with “Undo”."
        [ Doc.example
            { title = "Empty rule"
            , description = Just "Without conditions the rule lets every row through. “Condition” adds a condition on the first field and moves focus to its field picker; “Group” adds a subgroup with one condition. Groups nest at most three levels here (maxDepth)."
            , code = Just emptyCode
            }
            (RuleBuilder.view EmptyMsg
                [ RuleBuilder.fields orderFields
                , RuleBuilder.locale locale
                , RuleBuilder.today Sample.today
                , RuleBuilder.maxDepth 3
                ]
                model.empty
            )
        , Doc.example
            { title = "Issues are shown on the rule"
            , description = Just "Rule.validate runs all the time. A condition shows its issues once the user has tried to fill it in, or when the application asks for it with RuleBuilder.showIssues (here at start-up and with “Check the rule”); RuleBuilder.hideIssues takes them away again until the user touches a condition. An unknown field and a condition that does not fit its field typically come from old JSON."
            , code = Just invalidCode
            }
            (RuleBuilder.view InvalidMsg
                [ RuleBuilder.fields orderFields
                , RuleBuilder.locale locale
                , RuleBuilder.today Sample.today
                , RuleBuilder.actions
                    [ Button.view [ Button.small, Button.icon Icon.clipboardCheck, Button.onClick CheckInvalid ] "Check the rule"
                    , Button.view [ Button.small, Button.ghost, Button.icon Icon.eyeOff, Button.onClick HideInvalid ] "Hide issues"
                    ]
                ]
                model.invalid
            )
        , Doc.example
            { title = "Narrow space and long lists"
            , description =
                Just
                    ("The rows wrap neatly when space is tight: values go to the next line, the buttons stay fixed on the right. City has "
                        ++ String.fromInt (List.length cityChoices)
                        ++ " choices and Country "
                        ++ String.fromInt (List.length countryChoices)
                        ++ ", and “is any of” uses a multi-select with search."
                    )
            , code = Just narrowCode
            }
            -- as many columns as fit (two from about 520px): on a phone the
            -- text goes under the builder, which then has the whole width
            (Layout.grid [ Layout.minColumn 250, Layout.gap 4 ]
                [ RuleBuilder.view NarrowMsg
                    [ RuleBuilder.fields orderFields
                    , RuleBuilder.locale locale
                    , RuleBuilder.today Sample.today
                    , RuleBuilder.matchCount (Just model.narrowCount)
                    ]
                    model.narrow
                , Layout.stack [ Layout.gap 2 ]
                    [ Text.subheading "What the rule says"
                    , Text.paragraph (Rule.describe locale orderFields (RuleBuilder.rule model.narrow))
                    , Text.caption "The summary is made by Rule.describe and is the same sentence that the rule builder shows at the bottom."
                    ]
                ]
            )
        , Doc.example
            { title = "In a dialog that scrolls"
            , description = Just "The rule is edited on a copy and taken into use with “Apply rule”; if it is not valid, all issues are shown instead. The pickers open above the scrolling body of the dialog and are not cut off by it, and Escape in a picker closes only the picker."
            , code = Just dialogCode
            }
            (Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Button.view
                    [ Button.id "rules-dialog-open"
                    , Button.icon Icon.edit
                    , Button.onClick DialogOpened
                    ]
                    "Edit rule ..."
                , Text.secondary
                    (Rule.describe locale orderFields model.dialogRule
                        ++ " ("
                        ++ ordersText locale model.dialogCount
                        ++ ")"
                    )
                ]
            )
        ]


ordersText : Locale -> Int -> String
ordersText locale n =
    Format.int locale n ++ " " ++ Format.plural locale n { one = "order", other = "orders" }


emptyCode : String
emptyCode =
    """RuleBuilder.view EmptyMsg
    [ RuleBuilder.fields orderFields
    , RuleBuilder.today today
    , RuleBuilder.maxDepth 3
    ]
    model.empty"""


invalidCode : String
invalidCode =
    """-- show all issues now, for example when the user tries to save
{ model | rules = RuleBuilder.showIssues model.rules }

-- hide them again until the user touches a condition, for example after saving
{ model | rules = RuleBuilder.hideIssues model.rules }

-- the issues themselves, one for each node that has a problem
Rule.validate locale orderFields (RuleBuilder.rule model.rules)  -- List Rule.Issue"""


narrowCode : String
narrowCode =
    """RuleBuilder.view NarrowMsg
    [ RuleBuilder.fields orderFields
    , RuleBuilder.matchCount (Just model.matches)
    ]
    model.narrow

-- the rule as a sentence, such as: City is any of Rotterdam, Hamburg, ...
Rule.describe locale orderFields (RuleBuilder.rule model.narrow)"""


dialogCode : String
dialogCode =
    """DialogOpened ->
    let
        ( dialog, cmd ) =
            Modal.open "edit-rule-button" model.dialog
    in
    -- work on a copy
    ( { model
        | dialog = dialog
        , draft = RuleBuilder.setRule model.rule model.draft |> RuleBuilder.hideIssues
      }
    , Cmd.map DialogMsg cmd
    )

DialogApplied ->
    let
        edited =
            RuleBuilder.rule model.draft
    in
    if List.isEmpty (Rule.validate locale orderFields edited) then
        let
            ( dialog, cmd ) =
                Modal.close model.dialog
        in
        ( { model | dialog = dialog, rule = edited }, Cmd.map DialogMsg cmd )

    else
        ( { model | draft = RuleBuilder.showIssues model.draft }, Cmd.none )"""


filterBars : Locale -> Model -> Html Msg
filterBars locale model =
    Doc.section "Filter bar"
        "Quick filters above a table: the active conditions as chips, “Add filter” opens a small editor (field, operator, value), and ready-made filters as toggle pills. The filters are an ordinary Rule (an “all of” group), so they can be given to Rule.matches or opened in the rule builder. Keyboard: Tab moves through the pills, chips and buttons; Enter on a chip opens it; in the editor, Enter in the value field applies the filter, and Escape closes the editor and gives focus back."
        [ Doc.example
            { title = "Quick filters and match count"
            , description = Just "Click a chip to change it. An incomplete condition is shown dashed and does not filter."
            , code = Just filterCode
            }
            (FilterBar.view QuickMsg
                [ FilterBar.fields orderFields
                , FilterBar.quick presets
                , FilterBar.matchCount (Just model.quickCount)
                , FilterBar.totalCount (List.length Sample.orders)
                , FilterBar.today Sample.today
                , FilterBar.locale locale
                ]
                model.quick
            )
        ]


filterCode : String
filterCode =
    """FilterBar.view FiltersMsg
    [ FilterBar.fields orderFields
    , FilterBar.quick [ ( "Urgent", urgent ), ( "Confirmed", confirmed ) ]
    , FilterBar.matchCount (Just model.matches)
    , FilterBar.totalCount (List.length orders)
    , FilterBar.today today
    ]
    model.filters

List.filter (Rule.matches today orderFields (FilterBar.rule model.filters)) orders"""


savedViews : Locale -> Model -> Html Msg
savedViews locale model =
    Doc.section "Saved views"
        "A dropdown button with named rules. Applying a view goes through the application: it compares SavedViews.revision before and after update and loads the rule of SavedViews.active. The component stores nothing, and without ports there is no local storage, so the application keeps SavedViews.views where it keeps the user's settings. Keyboard: ArrowDown on the button opens the list, ArrowUp, ArrowDown, Home and End move between the views, Enter applies the view that has focus, and Escape cancels a rename, a deletion or a save and otherwise closes the list."
        [ Doc.example
            { title = "No saved views yet"
            , description = Just "The name must be filled in and must not exist already (upper and lower case count as the same). Deleting is confirmed on the row, not in a dialog."
            , code = Just savedViewsCode
            }
            (Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ SavedViews.view NoViewsMsg
                    [ SavedViews.current (FilterBar.rule model.quick)
                    , SavedViews.locale locale
                    ]
                    model.noViews
                , Text.muted
                    ("Saves the filter from the example above: "
                        ++ Rule.describe locale orderFields (FilterBar.rule model.quick)
                    )
                ]
            )
        ]


savedViewsCode : String
savedViewsCode =
    """SavedViews.view ViewsMsg
    [ SavedViews.current (FilterBar.rule model.filters) ]
    model.views

SavedViews.views model.views   -- List SavedView, to store them
SavedViews.active model.views  -- Maybe SavedView"""


norwegian : Model -> Html Msg
norwegian model =
    Doc.section "Norwegian"
        "All three components have built-in text in English and Norwegian (locale). The labels of fields, choices and views come from the application; here they are Norwegian too."
        [ Doc.example
            { title = "Locale Nb"
            , description = Nothing
            , code = Just norwegianCode
            }
            (viewBench
                { toMsg = NorwegianMsg
                , locale = Locale.nb
                , fields = norwegianFields
                , quick = [ ( "Haster", urgent ) ]
                , matchCount = model.norwegianCount
                , counting = False
                , label = "Regel for ordrelisten"
                }
                model.norwegian
            )
        ]


norwegianCode : String
norwegianCode =
    """RuleBuilder.view NorwegianMsg
    [ RuleBuilder.locale Locale.nb
    , RuleBuilder.fields norwegianFields
    ]
    model.norwegian

norwegianFields : List (Rule.Field Order)
norwegianFields =
    [ Rule.textField "customer" "Kunde" .customer
    , Rule.numberField "total" "Totalsum" (.total >> Just)
    , Rule.dateField "created" "Opprettet" (.created >> Just)
    ]"""


api : Html Msg
api =
    Doc.section "API"
        "The rule builder and the filter bar are stateful components (init, update, view) that hold the rule; the application reads it with rule and reacts by comparing before and after update. There are no out-messages."
        [ Doc.example { title = "Klar.Rule", description = Just "The rule as plain data, with no HTML: the components edit it and the application runs it.", code = Nothing }
            (Doc.props
                [ { name = "textField / numberField / dateField / boolField / choiceField", type_ = "String -> String -> (row -> value) -> Field row", description = "A field: its id (what saved rules refer to), its label and how to read the value from a row. A choice field also takes its choices, and the getter of a number or date field returns a Maybe." }
                , { name = "inGroup", type_ = "String -> Field row -> Field row", description = "Lists the field under a heading in the field picker." }
                , { name = "matches", type_ = "Date -> List (Field row) -> Rule -> row -> Bool", description = "Does the row satisfy the rule? Incomplete conditions and conditions on unknown fields are ignored, so an empty rule matches every row." }
                , { name = "validate", type_ = "Locale -> List (Field row) -> Rule -> List Issue", description = "What is missing or wrong, for each node, in the language of the locale." }
                , { name = "describe", type_ = "Locale -> List (Field row) -> Rule -> String", description = "The rule as a sentence: “Status is Confirmed and (Priority is Urgent or Total > 5000)”." }
                , { name = "encode / decoder", type_ = "Rule -> Value / Decoder Rule", description = "The rule as JSON, to store it or send it to a backend." }
                , { name = "emptyGroup", type_ = "Rule", description = "A group with nothing in it: the usual starting point, and it matches every row." }
                ]
            )
        , Doc.example { title = "Klar.RuleBuilder", description = Nothing, code = Nothing }
            (Doc.props
                [ { name = "init", type_ = "String -> State", description = "An empty rule. The string is the DOM id and must be unique on the page." }
                , { name = "rule / setRule", type_ = "State -> Rule / Rule -> State -> State", description = "The rule being built. setRule puts a lone condition in a group and numbers the nodes again if an id occurs twice." }
                , { name = "clear", type_ = "State -> State", description = "An empty rule, without an offer to undo." }
                , { name = "showIssues / hideIssues", type_ = "State -> State", description = "Show all issues now (for example when saving), or hide them until the user touches a condition again." }
                , { name = "fields", type_ = "List (Rule.Field row) -> Attribute", description = "The fields a rule can use. The first one is the field a new condition starts with." }
                , { name = "matchCount / totalCount", type_ = "Maybe Int / Int", description = "The number of matches, counted by the application: “1,482 of 3,000 matches”." }
                , { name = "counting", type_ = "Bool", description = "Shows “Running ...” while the application works." }
                , { name = "json / importJson", type_ = "Attribute", description = "“Show JSON” with a download link, and “Import JSON” with an error message and undo." }
                , { name = "maxDepth", type_ = "Int", description = "How deep groups may nest (4 by default)." }
                , { name = "today / locale / label / actions", type_ = "Attribute", description = "Today's date for the date pickers, the language, the accessible name and your own buttons in the toolbar." }
                ]
            )
        , Doc.example { title = "Klar.FilterBar", description = Nothing, code = Nothing }
            (Doc.props
                [ { name = "rule", type_ = "State -> Rule", description = "The filters as a Rule, for Rule.matches. Compare it before and after update to find out whether the filters changed." }
                , { name = "setRule / clear", type_ = "Rule -> State -> State / State -> State", description = "Show these filters, or remove them all. setRule also shows rules from the rule builder: conditions become chips and groups become chips that can only be removed." }
                , { name = "isOpen / close", type_ = "State -> Bool / State -> State", description = "Is the editor open; close it without applying." }
                , { name = "fields", type_ = "List (Rule.Field row) -> Attribute", description = "The fields that can be filtered on." }
                , { name = "quick", type_ = "List ( String, Rule ) -> Attribute", description = "Ready-made filters as toggle pills." }
                , { name = "matchCount / totalCount", type_ = "Maybe Int / Int", description = "The number of matches at the end of the bar." }
                , { name = "today / locale / label / addLabel", type_ = "Attribute", description = "Today's date, the language, the accessible name and the text of the add button." }
                ]
            )
        , Doc.example { title = "Klar.SavedViews", description = Nothing, code = Nothing }
            (Doc.props
                [ { name = "views / setViews", type_ = "State -> List SavedView / List SavedView -> State -> State", description = "All views: name, rule, note and whether it is the default. The application stores them." }
                , { name = "active / setActive", type_ = "State -> Maybe SavedView / Maybe String -> State -> State", description = "The view the user applied last." }
                , { name = "revision", type_ = "State -> Int", description = "Goes up every time the user applies a view or resets. Compare it before and after update." }
                , { name = "isOpen", type_ = "State -> Bool", description = "Is the list open?" }
                , { name = "defaultView", type_ = "State -> Maybe SavedView", description = "The view “Reset” returns to." }
                , { name = "current", type_ = "Rule -> Attribute", description = "The rule on show now: what “Save current view” saves, and what the active view is compared with (“modified”)." }
                , { name = "savedView / withNote / asDefault", type_ = "SavedView", description = "Make views, for example from stored data." }
                , { name = "size / alignEnd / label / locale", type_ = "Attribute", description = "The size of the button, which way the list opens, the text of the button and the language." }
                ]
            )
        ]
