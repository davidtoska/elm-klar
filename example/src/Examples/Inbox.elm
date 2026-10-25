module Examples.Inbox exposing (main)

{-| A server-mode inbox: a `Table` whose rows live on the server, a `FilterBar` and `SavedViews`
that edit one `Rule` and the table's query. `Klar.ServerList` owns the three and the glue
between them (compare the query and the rule, go back to page 1 when the rule changed, load an
applied view, give each request a ticket and drop late answers). This program keeps only what is
its own: the request to the server, the columns and the fields.

The "server" is `search`, a function over an in-memory list behind `Process.sleep`.
Type `fail` in the search box to see the failure: the first time the table has no rows to keep, and
after a good page the old rows stay with "Old data from ..." and a retry.

The pattern:

1.  Keep one `ServerList.State id row` in the model. `ServerList.init "orders" views` makes it and the first request; the saved views are the ones you have stored.
2.  Every message of the list is one constructor: `OrdersMsg (ServerList.Msg row)`, handled with `ServerList.update`. It returns a `Step`: the new `state`, a `cmd` to map, the `request` to send when the query or the rule changed, and the `save` list when the saved views changed.
3.  One function (`follow`) turns a `Step` into commands. The request has the table's `Query` and the filter bar's `Rule`; the application sends it however it likes and answers with `ServerList.gotPage request result`. The list drops an answer to an old request.
4.  The three parts are drawn with `ServerList.viewSavedViews`, `ServerList.viewFilterBar` and `ServerList.viewTable`, which add what they own (the rows, the total, the retry, the match count) to the attributes you give them (`Table.columns`, `FilterBar.fields`, ...).
5.  For bulk actions on a selection, `ServerList.target` gives the ids that were picked or, after "Select all N matching", the query, the rule and the exceptions.

Nothing here compares a query, resets a page or counts tickets: the list does. Type `fail` in the search box to see the failure state.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Date as Date exposing (Date)
import Klar.FilterBar as FilterBar
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.ServerList as ServerList
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


initialViews : List SavedViews.SavedView
initialViews =
    [ SavedViews.savedView "Open orders" (Rule.allOf [ Rule.is "status" "open" ]) |> SavedViews.asDefault
    , SavedViews.savedView "Large orders" (Rule.allOf [ Rule.when "total" Rule.GreaterOrEqual [ "1000" ] ])
    , SavedViews.savedView "Shipped (team)" (Rule.allOf [ Rule.is "status" "shipped" ]) |> SavedViews.asShared
    ]



-- MODEL


type alias Model =
    { orders : ServerList.State String OrderRow
    , today : Date -- for the date picker of the filter bar; it comes with GotToday right after start
    }


type Msg
    = OrdersMsg (ServerList.Msg OrderRow)
    | SaveView
    | GotToday Date


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
        step =
            ServerList.init "orders" initialViews

        ( model, cmd ) =
            follow { orders = step.state, today = Date.fromPosix Time.utc (Time.millisToPosix 0) } step
    in
    ( model, Cmd.batch [ cmd, Task.perform GotToday today ] )


{-| Today in the time zone of the user.
-}
today : Task.Task Never Date
today =
    Task.map2 Date.fromPosix Time.here Time.now



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OrdersMsg m ->
            follow model (ServerList.update m model.orders)

        SaveView ->
            -- the same form as "Save current view ...", opened from a button
            follow model (ServerList.startSaveView model.orders)

        GotToday date ->
            ( { model | today = date }, Cmd.none )


{-| The one place that turns what the list says into commands: its own command, the request
for the server (when the query changed), and the saved views to store (here nothing is stored,
so `step.save` is ignored; send it to your backend).
-}
follow : Model -> ServerList.Step String OrderRow -> ( Model, Cmd Msg )
follow model step =
    ( { model | orders = step.state }
    , Cmd.batch
        [ Cmd.map OrdersMsg step.cmd
        , case step.request of
            Just request ->
                search request
                    |> Task.perform (\result -> OrdersMsg (ServerList.gotPage request result))

            Nothing ->
                Cmd.none
        ]
    )



-- VIEW


view : Model -> Html Msg
view model =
    Layout.stack [ Layout.gap 3, Layout.padding 4 ]
        [ Klar.stylesheet
        , PageHeader.view [ PageHeader.title "Inbox", PageHeader.subtitle "Orders from the server", PageHeader.actions [ Button.view [ Button.secondary, Button.onClick SaveView ] "Save view ..." ] ]
        , Layout.row [ Layout.gap 2, Layout.alignStart ]
            [ ServerList.viewSavedViews OrdersMsg [] model.orders
            , Layout.stack [ Layout.grow ]
                [ ServerList.viewFilterBar OrdersMsg
                    [ FilterBar.fields fields
                    , FilterBar.totalCount allOrdersCount
                    , FilterBar.today model.today
                    ]
                    model.orders
                ]
            ]
        , ServerList.viewTable OrdersMsg
            [ Table.columns columns
            , Table.rowId Ids.string .id
            , Table.searchable
            ]
            model.orders
        ]


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
search : ServerList.Request -> Task.Task Never (Result Remote.Problem (ServerList.Page OrderRow))
search req =
    Process.sleep 400
        |> Task.andThen (\_ -> today)
        |> Task.map
            (\now ->
                if String.toLower req.query.search == "fail" then
                    Err (Remote.problem Remote.server)

                else
                    let
                        needle =
                            String.toLower req.query.search

                        matching =
                            allOrders
                                |> List.filter (Rule.matches now fields req.rule)
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
