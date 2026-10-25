module Page.Gallery.ServerLists exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: a list that lives on a server.

`Klar.ServerList` owns the table, the filter bar and the saved views of the orders below, the
page, the total and the ticket of each request. This page keeps the request (a function over
240 orders behind `Process.sleep`), the columns and the fields. The server can be slow, can
answer out of order (the first request is the slow one: type quickly and watch the last answer
win) and can fail. The request log under the table says which request left and which answer
came. A second card shows a `RemoteView` whose "Try again" keeps keyboard focus, and a toast
that is taken away from `update` when the retry works.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.Card as Card
import Klar.Date as Date exposing (Date)
import Klar.FilterBar as FilterBar
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Overlay as Overlay
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.SegmentedControl as SegmentedControl
import Klar.ServerList as ServerList
import Klar.Settings as Settings
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Process
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Task
import Time



-- DATA


type alias Order =
    { id : String
    , customer : String
    , status : String
    , total : Float
    }


allOrders : List Order
allOrders =
    List.range 1 240
        |> List.map
            (\n ->
                { id = "SO-" ++ String.fromInt (1000 + n)
                , customer = pick [ "Aurora Logistics", "Fjord Foods", "Birch Hardware", "Cedar Supplies", "Delta Freight", "Evergreen Market" ] (n * 7)
                , status = pick [ "open", "packed", "shipped" ] (n * 5)
                , total = toFloat (modBy 37 (n * 13) * 45 + 20)
                }
            )


pick : List String -> Int -> String
pick items n =
    items |> List.drop (modBy (List.length items) n) |> List.head |> Maybe.withDefault ""


fields : List (Rule.Field Order)
fields =
    [ Rule.textField "customer" "Customer" .customer
    , Rule.choiceField "status" "Status" [ { value = "open", label = "Open" }, { value = "packed", label = "Packed" }, { value = "shipped", label = "Shipped" } ] .status
    , Rule.numberField "total" "Total" (.total >> Just)
    ]


initialViews : List SavedViews.SavedView
initialViews =
    [ SavedViews.savedView "Open orders" (Rule.allOf [ Rule.is "status" "open" ]) |> SavedViews.asDefault
    , SavedViews.savedView "Large orders" (Rule.allOf [ Rule.when "total" Rule.GreaterOrEqual [ "1000" ] ])
    , SavedViews.savedView "Shipped (team)" (Rule.allOf [ Rule.is "status" "shipped" ]) |> SavedViews.asShared
    ]


{-| The server: filter by the rule and the search text, sort, cut out one page.
-}
search : Date -> ServerList.Request -> ServerList.Page Order
search today request =
    let
        needle =
            String.toLower request.query.search

        matching =
            allOrders
                |> List.filter (Rule.matches today fields request.rule)
                |> List.filter (\order -> String.contains needle (String.toLower (order.id ++ " " ++ order.customer)))
                |> sortBy request.query.sort
    in
    { rows = matching |> List.drop ((request.query.page - 1) * request.query.pageSize) |> List.take request.query.pageSize
    , total = List.length matching
    }


sortBy : List ( Table.ColumnId, Table.Direction ) -> List Order -> List Order
sortBy levels orders =
    List.foldr (\( column, direction ) rows -> List.sortWith (compareOn column direction) rows) orders levels


compareOn : Table.ColumnId -> Table.Direction -> Order -> Order -> Basics.Order
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
    case ( direction, order ) of
        ( Table.Descending, LT ) ->
            GT

        ( Table.Descending, GT ) ->
            LT

        _ ->
            order



-- MODEL


type Speed
    = Fast
    | Slow
    | OutOfOrder


speeds : List ( String, Speed, String )
speeds =
    [ ( "fast", Fast, "Fast" ), ( "slow", Slow, "Slow (1.5 s)" ), ( "jumbled", OutOfOrder, "Out of order" ) ]


type alias Model =
    { orders : ServerList.State String Order
    , speed : Speed
    , failing : Bool
    , sent : Int
    , log : List String
    , exportNote : String
    , today : Date
    , zone : Time.Zone
    , supplier : Remote String
    , supplierFailing : Bool
    , toasts : Toast.State Msg
    }


type Msg
    = OrdersMsg (ServerList.Msg Order)
    | SaveView
    | SpeedChosen String
    | FailingToggled Bool
    | GotAnswer Int ServerList.Request (Result Remote.Problem (ServerList.Page Order))
    | ExportAll
    | ShipFirst
    | OpenAddress
    | GotZone Time.Zone
    | SupplierRetry
    | SupplierFailingToggled Bool
    | GotSupplier (Result Remote.Problem String) Time.Posix
    | ToastMsg Toast.Msg
    | NoOp


init : ( Model, Cmd Msg )
init =
    let
        step =
            ServerList.init "server-orders" initialViews

        model =
            { orders = step.state
            , speed = Fast
            , failing = False
            , sent = 0
            , log = []
            , exportNote = ""
            , today = Date.fromPosix Time.utc (Time.millisToPosix 0)
            , zone = Time.utc
            , supplier = Loading
            , supplierFailing = True
            , toasts = Toast.init "server-list-toasts"
            }
    in
    follow step model
        |> andThen (\m -> ( m, Cmd.batch [ Time.here |> Task.perform GotZone, loadSupplier m ] ))


andThen : (Model -> ( Model, Cmd Msg )) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen next ( model, cmd ) =
    let
        ( after, more ) =
            next model
    in
    ( after, Cmd.batch [ cmd, more ] )



-- UPDATE


update : Config.Config -> Msg -> Model -> ( Model, Cmd Msg )
update playground msg model =
    case msg of
        OrdersMsg m ->
            follow (ServerList.update m model.orders) model

        SaveView ->
            follow (ServerList.startSaveView model.orders) model

        SpeedChosen value ->
            ( { model | speed = speeds |> List.filter (\( name, _, _ ) -> name == value) |> List.head |> Maybe.map (\( _, speed, _ ) -> speed) |> Maybe.withDefault model.speed }, Cmd.none )

        FailingToggled on ->
            ( { model | failing = on }, Cmd.none )

        GotAnswer number request result ->
            follow (ServerList.update (ServerList.gotPage request result) model.orders)
                { model | log = ("answer " ++ String.fromInt number ++ " arrived") :: model.log |> List.take 8 }

        ShipFirst ->
            -- the server accepted the change: show it at once, with no round trip
            ( { model | orders = ServerList.mapRows (shipFirst model.orders) model.orders }, Cmd.none )

        OpenAddress ->
            -- a link from elsewhere, or Back: the list goes where the address says
            follow (ServerList.fromQueryString "search=fjord&sort=-total&size=10" model.orders) model

        ExportAll ->
            ( { model | exportNote = describeTarget (ServerList.target Ids.string model.orders) }, Cmd.none )

        GotZone zone ->
            ( { model | zone = zone }, Cmd.none )

        SupplierRetry ->
            ( { model | supplier = Remote.refresh model.supplier }
            , Cmd.batch [ loadSupplier model, Klar.focus "supplier-body" NoOp ]
            )

        SupplierFailingToggled on ->
            ( { model | supplierFailing = on }, Cmd.none )

        GotSupplier result at ->
            let
                next =
                    { model | supplier = Remote.refreshWith model.supplier result at }
            in
            case result of
                Ok _ ->
                    -- the failure toast of an earlier try is stale now
                    ( { next | toasts = Toast.dismiss "supplier" model.toasts }, Cmd.none )

                Err problem ->
                    let
                        ( toasts, cmd ) =
                            Toast.push
                                (Options.klarToast playground
                                    (List.concat
                                        [ Config.keep playground "Toast" "tone" (Toast.tone Danger)
                                        , Config.keep playground "Toast" "key" (Toast.key "supplier")
                                        , Config.keep playground "Toast" "title" (Toast.title "Could not load the supplier")
                                        , Config.keep playground "Toast" "message" (Toast.message (Remote.title Klar.Locale.default problem))
                                        ]
                                    )
                                )
                                model.toasts
                    in
                    ( { next | toasts = toasts }, Cmd.map ToastMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        NoOp ->
            ( model, Cmd.none )


{-| What the list says, as commands: its own, the request for the server, and the saved views
to store (nothing is stored on this page).
-}
follow : ServerList.Step String Order -> Model -> ( Model, Cmd Msg )
follow step model =
    case step.request of
        Just request ->
            let
                number =
                    model.sent + 1
            in
            ( { model
                | orders = step.state
                , sent = number
                , log = ("request " ++ String.fromInt number ++ ": page " ++ String.fromInt request.query.page ++ ", search \"" ++ request.query.search ++ "\", " ++ String.fromInt (Rule.conditionCount request.rule) ++ " filters") :: model.log |> List.take 8
              }
            , Cmd.batch [ Cmd.map OrdersMsg step.cmd, answer model number request ]
            )

        Nothing ->
            ( { model | orders = step.state }, Cmd.map OrdersMsg step.cmd )


{-| The backend call: wait, then answer or fail. In an application this is an HTTP request.
-}
answer : Model -> Int -> ServerList.Request -> Cmd Msg
answer model number request =
    let
        delay =
            case model.speed of
                Fast ->
                    250

                Slow ->
                    1500

                OutOfOrder ->
                    -- every second request is the slow one, so answers cross
                    if modBy 2 number == 1 then
                        1800

                    else
                        200

        result =
            if model.failing then
                Err (Remote.problem Remote.server)

            else
                Ok (search model.today request)
    in
    Process.sleep (toFloat delay)
        |> Task.perform (\_ -> GotAnswer number request result)


loadSupplier : Model -> Cmd Msg
loadSupplier model =
    Process.sleep 700
        |> Task.andThen (\_ -> Time.now)
        |> Task.perform
            (\at ->
                GotSupplier
                    (if model.supplierFailing then
                        Err (Remote.problem Remote.network)

                     else
                        Ok "Fjord Foods"
                    )
                    at
            )


describeTarget : Maybe (ServerList.Target String) -> String
describeTarget target =
    case target of
        Nothing ->
            "Nothing is selected."

        Just (ServerList.Picked ids) ->
            "Export request: these " ++ String.fromInt (List.length ids) ++ " orders: " ++ String.join ", " ids

        Just (ServerList.Matching { query, rule, except }) ->
            "Export request: all matching (search \"" ++ query.search ++ "\", " ++ String.fromInt (Rule.conditionCount rule) ++ " filters), except " ++ String.fromInt (List.length except) ++ " orders"


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Overlay.host
        { attributes = []
        , page =
            [ Doc.configuredPage playground
                { title = "Server lists"
                , description = "A table, a filter bar and saved views over rows that live on a server, with no glue in the application: Klar.ServerList compares the query, goes back to page 1, tickets the requests and drops late answers. Make the server slow, jumble the answers or let it fail."
                }
                [ Doc.configuredSection playground [] "An inbox" "" [ inbox playground locale model ]
                , Doc.configuredSection playground [] "A page that is one RemoteView" "" [ supplier playground locale model ]
                ]
            ]
        , overlays = [ Toast.view ToastMsg (Options.klarToast playground (List.concat [ Config.keep playground "Toast" "locale" (Toast.locale locale) ])) model.toasts ]
        }


inbox : Config.Config -> Locale -> Model -> Html Msg
inbox playground locale model =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
        [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
            [ SegmentedControl.view
                (Options.klarSegmentedControl playground
                    (List.concat
                        [ Config.keep playground "SegmentedControl" "label" (SegmentedControl.label "Speed of the server")
                        , Config.keep playground "SegmentedControl" "labelHidden" SegmentedControl.labelHidden
                        , Config.keep playground "SegmentedControl" "options" (SegmentedControl.options (List.map (\( name, _, text ) -> SegmentedControl.option name text) speeds))
                        , Config.keep playground "SegmentedControl" "selected" (SegmentedControl.selected (speeds |> List.filter (\( _, speed, _ ) -> speed == model.speed) |> List.head |> Maybe.map (\( name, _, _ ) -> name) |> Maybe.withDefault "fast"))
                        , Config.keep playground "SegmentedControl" "onChange" (SegmentedControl.onChange SpeedChosen)
                        ]
                    )
                )
            , Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "The server fails"), Config.keep playground "Switch" "checked" (Switch.checked model.failing), Config.keep playground "Switch" "onCheck" (Switch.onCheck FailingToggled) ]))
            , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "secondary" Button.secondary, Config.keep playground "Button" "onClick" (Button.onClick SaveView) ])) "Save view ..."
            ]
        , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
            [ ServerList.viewSavedViews OrdersMsg (Options.klarSavedViews playground (List.concat [ Config.keep playground "SavedViews" "locale" (SavedViews.locale locale) ])) model.orders
            , Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "grow" Layout.grow ]))
                [ ServerList.viewFilterBar OrdersMsg
                    (Options.klarFilterBar playground
                        (List.concat
                            [ Config.keep playground "FilterBar" "fields" (FilterBar.fields fields)
                            , Config.keep playground "FilterBar" "totalCount" (FilterBar.totalCount (List.length allOrders))
                            , Config.keep playground "FilterBar" "today" (FilterBar.today model.today)
                            , Config.keep playground "FilterBar" "locale" (FilterBar.locale locale)
                            ]
                        )
                    )
                    model.orders
                ]
            ]
        , ServerList.viewTable OrdersMsg
            (Options.klarTable playground
                (List.concat
                    [ Config.keep playground
                        "Table"
                        "columns"
                        (Table.columns
                            [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                            , Table.text (Table.columnId "customer") "Customer" .customer []
                            , Table.status (Table.columnId "status") "Status" (\order -> ( statusTone order.status, order.status )) []
                            , Table.float (Table.columnId "total") "Total" 2 .total []
                            ]
                        )
                    , Config.keep playground "Table" "rowId" (Table.rowId Ids.string .id)
                    , Config.keep playground "Table" "ariaLabel" (Table.ariaLabel "Orders")
                    , Config.keep playground "Table" "locale" (Table.locale locale)
                    , Config.keep playground "Table" "settings" (Table.settings (Settings.withZone model.zone Settings.default))
                    , Config.keep playground "Table" "searchable" Table.searchable
                    , Config.keep playground "Table" "selectable" Table.selectable
                    , Config.keep playground "Table" "bulkActions" (Table.bulkActions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.download), Config.keep playground "Button" "onClick" (Button.onClick ExportAll) ])) "Export all selected ..." ])
                    , Config.keep playground "Table" "exportCsv" (Table.exportCsv "orders.csv")
                    , Config.keep playground "Table" "pageSizes" (Table.pageSizes [ 10, 25, 50 ])
                    ]
                )
            )
            model.orders
        , if model.exportNote == "" then
            Html.text ""

          else
            Options.alertView playground (Options.klarAlert playground (List.concat [ Config.keep playground "Alert" "tone" (Alert.tone Info), Config.keep playground "Alert" "title" (Alert.title "A request for your backend") ])) model.exportNote
        , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
            [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "secondary" Button.secondary, Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick ShipFirst) ])) "Ship the first order (mapRows)"
            , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "secondary" Button.secondary, Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick OpenAddress) ])) "Open an address (fromQueryString)"
            ]
        , Text.secondary ("The address of the list (toQueryString): #/orders?" ++ ServerList.toQueryString model.orders)
        , Html.pre [ Attr.id "server-log", Attr.style "font-size" "12px", Attr.style "margin" "0" ] [ Html.text (String.join "\n" (List.reverse model.log)) ]
        ]


{-| The first order on the page, shipped.
-}
shipFirst : ServerList.State String Order -> Order -> Order
shipFirst orders order =
    if Just order.id == (ServerList.rows orders |> Remote.toMaybe |> Maybe.andThen List.head |> Maybe.map .id) then
        { order | status = "shipped" }

    else
        order


statusTone : String -> Tone
statusTone status =
    case status of
        "open" ->
            Warning

        "shipped" ->
            Success

        _ ->
            Info


supplier : Config.Config -> Locale -> Model -> Html Msg
supplier playground locale model =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
        [ Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "The supplier request fails"), Config.keep playground "Switch" "checked" (Switch.checked model.supplierFailing), Config.keep playground "Switch" "onCheck" (Switch.onCheck SupplierFailingToggled) ]))
        , Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "Supplier"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 3) ]))
            (RemoteView.view
                (Options.klarRemoteView playground
                    (List.concat
                        [ Config.keep playground "RemoteView" "id" (RemoteView.id "supplier-body")
                        , Config.keep playground "RemoteView" "onRetry" (RemoteView.onRetry SupplierRetry)
                        , Config.keep playground "RemoteView" "loadingLabel" (RemoteView.loadingLabel "Loading supplier")
                        , Config.keep playground "RemoteView" "locale" (RemoteView.locale locale)
                        , Config.keep playground "RemoteView" "settings" (RemoteView.settings (Settings.withZone model.zone Settings.default))
                        ]
                    )
                )
                model.supplier
                (\name -> [ Text.paragraph name ])
            )
        ]
