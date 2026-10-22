module Main exposing (main)

{-| A server-mode inbox: a `Table` whose rows live on the server, a `FilterBar` and `SavedViews`
that edit one `Rule` and the table's query, and the glue that every such list needs:

  - compare the query and the rule before and after each `update`;
  - go back to page 1 when the rule changed;
  - nothing to debounce: the search box and the filter fields of the table already wait 350 ms in
    server mode, the filter bar changes its rule only when the user applies a filter, and a sort
    click or a page change should ask at once;
  - give each request a ticket and drop answers that are not for the latest one.

The "server" is `search`, a function over an in-memory list behind `Process.sleep`.
Type `fail` in the search box to see the failure: the first time the table has no rows to keep, and
after a good page the old rows stay with "Old data from ..." and a retry.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Date as Date exposing (Date)
import Klar.FilterBar as FilterBar
import Klar.Layout as Layout
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Rule as Rule exposing (Rule)
import Klar.SavedViews as SavedViews
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Process
import Task
import Time



-- DOMAIN


type alias OrderRow =
    { id : String
    , customer : String
    , status : String
    , total : Float
    }


{-| What the server needs to answer: the table's query and the rule.
-}
type alias Request =
    { query : Table.Query
    , rule : Rule
    }


type alias Page =
    { rows : List OrderRow
    , total : Int
    }


fields : List (Rule.Field OrderRow)
fields =
    [ Rule.textField "customer" "Customer" .customer
    , Rule.choiceField "status" "Status" statusChoices .status
    , Rule.numberField "total" "Total" (.total >> Just)
    ]


statusChoices : List Rule.Choice
statusChoices =
    [ { value = "open", label = "Open" }
    , { value = "packed", label = "Packed" }
    , { value = "shipped", label = "Shipped" }
    ]


{-| A rule is plain data: one condition inside the root group.
-}
whereField : String -> Rule.Operator -> List String -> Rule
whereField field operator values =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children = [ Rule.ConditionRule { id = 1, field = field, operator = operator, values = values } ]
        }


initialViews : List SavedViews.SavedView
initialViews =
    [ SavedViews.savedView "Open orders" (whereField "status" Rule.Is [ "open" ]) |> SavedViews.asDefault
    , SavedViews.savedView "Large orders" (whereField "total" Rule.GreaterOrEqual [ "1000" ])
    , SavedViews.savedView "Shipped (team)" (whereField "status" Rule.Is [ "shipped" ]) |> SavedViews.asShared
    ]



-- MODEL


type alias Model =
    { table : Table.State String
    , filterBar : FilterBar.State
    , views : SavedViews.State
    , page : Remote (List OrderRow)
    , total : Int
    , ticket : Int
    , today : Date
    }


type Msg
    = TableMsg Table.Msg
    | FilterBarMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | SaveView
    | GotPage Int Time.Posix (Result Remote.Problem Page)
    | Retry


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : ( Model, Cmd Msg )
init =
    let
        views =
            SavedViews.init "order-views" |> SavedViews.setViews initialViews

        rule =
            SavedViews.defaultView views |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup
    in
    request
        { table = Table.init "orders"
        , filterBar = FilterBar.init "order-filters" |> FilterBar.setRule rule
        , views = SavedViews.setActive (Just "Open orders") views
        , page = Loading
        , total = 0
        , ticket = 0
        , today = Date.fromPosix Time.utc (Time.millisToPosix 0)
        }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            askIfChanged model { model | table = table } (Cmd.map TableMsg cmd)

        FilterBarMsg m ->
            let
                ( filterBar, cmd ) =
                    FilterBar.update m model.filterBar
            in
            askIfChanged model { model | filterBar = filterBar } (Cmd.map FilterBarMsg cmd)

        ViewsMsg m ->
            let
                ( views, cmd ) =
                    SavedViews.update m model.views

                next =
                    { model | views = views }
            in
            if SavedViews.revision views /= SavedViews.revision model.views then
                -- the user applied a view (or "Reset"): load its rule into the filter bar
                let
                    active =
                        SavedViews.active views

                    rule =
                        active |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup

                    -- a view that holds a query puts the table's search, sort and filters back too
                    table =
                        case active |> Maybe.andThen .query of
                            Just q ->
                                Table.setQuery q next.table

                            Nothing ->
                                next.table
                in
                askIfChanged model { next | filterBar = FilterBar.setRule rule next.filterBar, table = table } (Cmd.map ViewsMsg cmd)

            else
                ( next, Cmd.map ViewsMsg cmd )

        SaveView ->
            -- the same form as "Save current view ...", opened from a button
            let
                ( views, cmd ) =
                    SavedViews.startSave model.views
            in
            ( { model | views = views }, Cmd.map ViewsMsg cmd )

        GotPage ticket at result ->
            if ticket /= model.ticket then
                -- an answer to a question that is no longer asked
                ( model, Cmd.none )

            else
                case result of
                    Ok page ->
                        ( { model | page = Remote.refreshWith model.page (Ok page.rows) at, total = page.total }, Cmd.none )

                    Err problem ->
                        -- with rows on the screen they stay as old data; without, the table shows the failure
                        ( { model | page = Remote.refreshWith model.page (Err problem) at }, Cmd.none )

        Retry ->
            request model


{-| Compare before and after. If the query or the rule changed, ask again with a new ticket. A new
rule starts at page 1: page 7 of the old answer means nothing for the new one.
-}



-- KLAR GAP: no server-mode helper; comparing query and rule, resetting the page and the ticket (about 30 lines) are the same in every server-mode list.


askIfChanged : Model -> Model -> Cmd Msg -> ( Model, Cmd Msg )
askIfChanged before after cmd =
    let
        ruleChanged =
            FilterBar.rule after.filterBar /= FilterBar.rule before.filterBar

        next =
            if ruleChanged then
                { after | table = Table.setPage 1 after.table }

            else
                after
    in
    if ruleChanged || Table.query next.table /= Table.query before.table then
        let
            ( asked, askCmd ) =
                request { next | ticket = next.ticket + 1 }
        in
        ( asked, Cmd.batch [ cmd, askCmd ] )

    else
        ( next, cmd )


{-| Ask now. Rows that are already on the screen stay (dimmed and busy, see `Remote.refresh`) while the answer comes.
-}
request : Model -> ( Model, Cmd Msg )
request model =
    ( { model | page = Remote.refresh model.page }
    , search model.today fields { query = Table.query model.table, rule = FilterBar.rule model.filterBar }
        |> Task.andThen (\result -> Time.now |> Task.map (\at -> ( at, result )))
        |> Task.perform (\( at, result ) -> GotPage model.ticket at result)
    )



-- VIEW


view : Model -> Html Msg
view model =
    Layout.stack [ Layout.gap 3, Layout.padding 4 ]
        [ Klar.stylesheet
        , PageHeader.view [ PageHeader.title "Inbox", PageHeader.subtitle "Orders from the server", PageHeader.actions [ Button.view [ Button.secondary, Button.onClick SaveView ] "Save view ..." ] ]
        , Layout.row [ Layout.gap 2, Layout.alignStart ]
            [ SavedViews.view ViewsMsg [ SavedViews.current (FilterBar.rule model.filterBar), SavedViews.currentQuery (Table.query model.table) ] model.views
            , Layout.stack [ Layout.grow ]
                [ FilterBar.view FilterBarMsg
                    [ FilterBar.fields fields
                    , FilterBar.totalCount allOrdersCount
                    , FilterBar.matchCount (Just model.total |> keepIf (Remote.isLoaded model.page))
                    , FilterBar.counting (Remote.isRefreshing model.page || Remote.isLoading model.page)
                    , FilterBar.today model.today
                    ]
                    model.filterBar
                ]
            ]
        , Table.view TableMsg
            [ Table.columns columns
            , Table.server { total = model.total }
            , Table.rows model.page
            , Table.rowId Table.stringIds .id
            , Table.searchable
            , Table.onRefresh Retry
            , Table.onRetry Retry
            ]
            model.table
        ]


keepIf : Bool -> Maybe a -> Maybe a
keepIf condition value =
    if condition then
        value

    else
        Nothing


columns : List (Table.Column OrderRow Msg)
columns =
    [ Table.text idColumn "OrderRow" .id [ Table.pinned ]
    , Table.text customerColumn "Customer" .customer []
    , Table.status statusColumn "Status" (\order -> ( statusTone order.status, order.status )) []
    , Table.float totalColumn "Total" 2 .total []
    ]


idColumn : Table.ColumnId
idColumn =
    Table.columnId "id"


customerColumn : Table.ColumnId
customerColumn =
    Table.columnId "customer"


statusColumn : Table.ColumnId
statusColumn =
    Table.columnId "status"


totalColumn : Table.ColumnId
totalColumn =
    Table.columnId "total"


statusTone : String -> Tone
statusTone status =
    case status of
        "open" ->
            Warning

        "shipped" ->
            Success

        _ ->
            Info



-- THE SERVER (a stand-in: replace `search` with a request that sends `Request` as JSON or a URL)


allOrdersCount : Int
allOrdersCount =
    List.length allOrders


allOrders : List OrderRow
allOrders =
    List.range 1 240
        |> List.map
            (\n ->
                { id = "SO-" ++ String.fromInt (1000 + n)
                , customer = pick customers (n * 7)
                , status = pick [ "open", "packed", "shipped" ] (n * 5)
                , total = toFloat (modBy 37 (n * 13) * 45 + 20)
                }
            )


customers : List String
customers =
    [ "Aurora Logistics", "Fjord Foods", "Birch Hardware", "Cedar Supplies", "Delta Freight", "Evergreen Market" ]


pick : List String -> Int -> String
pick items n =
    items |> List.drop (modBy (List.length items) n) |> List.head |> Maybe.withDefault ""


{-| Filter by the rule and the search text, sort, cut out one page, after a pause.
Searching for `fail` answers with a problem.
-}
search : Date -> List (Rule.Field OrderRow) -> Request -> Task.Task Never (Result Remote.Problem Page)
search today ruleFields req =
    Process.sleep 400
        |> Task.map
            (\_ ->
                if String.toLower req.query.search == "fail" then
                    Err (Remote.problem Remote.server)

                else
                    let
                        needle =
                            String.toLower req.query.search

                        matching =
                            allOrders
                                |> List.filter (Rule.matches today ruleFields req.rule)
                                |> List.filter (\o -> String.contains needle (String.toLower (o.id ++ " " ++ o.customer)))
                                |> sortBy req.query.sort
                    in
                    Ok
                        { rows = matching |> List.drop ((req.query.page - 1) * req.query.pageSize) |> List.take req.query.pageSize
                        , total = List.length matching
                        }
            )


sortBy : List ( Table.ColumnId, Table.Direction ) -> List OrderRow -> List OrderRow
sortBy levels orders =
    -- the primary level is first, and List.sortWith is stable: sort by the last level first
    List.foldr (\( column, direction ) rows -> List.sortWith (compareOn column direction) rows) orders levels


compareOn : Table.ColumnId -> Table.Direction -> OrderRow -> OrderRow -> Basics.Order
compareOn column direction a b =
    let
        order =
            case Table.columnName column of
                "customer" ->
                    compare a.customer b.customer

                "status" ->
                    compare a.status b.status

                "total" ->
                    compare a.total b.total

                _ ->
                    compare a.id b.id
    in
    case direction of
        Table.Ascending ->
            order

        Table.Descending ->
            case order of
                LT ->
                    GT

                GT ->
                    LT

                EQ ->
                    EQ
