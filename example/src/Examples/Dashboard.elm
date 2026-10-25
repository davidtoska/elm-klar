module Examples.Dashboard exposing (main)

{-| A dashboard in which every panel is its own `Remote`.

A period picker (`SegmentedControl`) reloads five panels: `Stat` tiles, a `Chart` line, a
`Chart` donut, a `Tree` of regions and warehouses, and a `Timeline`. Each panel is `Loading`,
`Failed` (with its own retry) or `Loaded` on its own, so one failure never hides the others.
A period change or a retry refreshes a panel that has data: the old data stays, dimmed and busy,
and when the refresh fails it stays as old data with a notice. The Activity panel fails on its
first request and the order status panel fails for 90 days, so both can be tried. An answer for
a period the user has already left is dropped.

The components draw every state from the `Remote`; the page writes no case for them.

The pattern:

1.  One `Remote` per panel in the model, never one for the page.
2.  Every component takes its `Remote` once (`Stat.remote`, `Chart.lineRemote`, `Chart.donutRemote`,
    `Timeline.viewRemote`, `Tree.viewRemote`) and an `onRetry` message for that panel only. The
    data is shaped with `Remote.map`; a chart's categories travel with its series in
    `Chart.byCategory`, so the labels always belong to the values, old data included.
3.  Changing the period or retrying calls `Remote.refresh` on the panel and sends the request; the answer goes in with `Remote.refreshWith panel result time`. Data that is there stays (dimmed), a failed refresh keeps it as old data ("Old data from 14:05"), and a panel with no data shows its skeleton or failure. `Alert.stale` with `Remote.staleIn` gives one notice for the page. The message carries
    the period it was asked for, and an answer for another period is dropped.
4.  The zone of "Old data from 14:05" is in the model's `Klar.Settings` (`Time.here` at the start, `Settings.withZone`) and each panel is given it (`Stat.settings`, `Chart.settings`, `Timeline.settings`).
    The Activity panel fails on its first request and the order status panel fails for 90 days, on purpose.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SegmentedControl as SegmentedControl
import Klar.Settings as Settings exposing (Settings)
import Klar.Stat as Stat
import Klar.Timeline as Timeline
import Klar.Tree as Tree
import Process
import Task
import Time



-- MODEL


type Period
    = Week
    | Month
    | Quarter


type RegionId
    = RegionId Int


type alias Summary =
    { orders : Int, revenue : Float, previousRevenue : Float, lateShare : Float }


type alias Sales =
    { labels : List String, thisPeriod : List Float, lastPeriod : List Float }


type Region
    = Region RegionId String (List Region)


type alias Activity =
    { id : String, at : Int, title : String }


type alias Model =
    { period : Period
    , summary : Remote Summary
    , sales : Remote Sales
    , statuses : Remote (List ( String, Float ))
    , regions : Remote (List Region)
    , activity : Remote (List Activity)
    , activityAttempts : Int
    , tree : Tree.State RegionId
    , settings : Settings
    }


type Panel
    = SummaryPanel
    | SalesPanel
    | StatusesPanel
    | RegionsPanel
    | ActivityPanel


type Msg
    = PeriodPicked String
    | Got Period Time.Posix Answer
    | RetryStale
    | Retry Panel
    | TreeMsg Tree.Msg
    | GotZone Time.Zone


type Answer
    = GotSummary (Result Remote.Problem Summary)
    | GotSales (Result Remote.Problem Sales)
    | GotStatuses (Result Remote.Problem (List ( String, Float )))
    | GotRegions (Result Remote.Problem (List Region))
    | GotActivity (Result Remote.Problem (List Activity))


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> init
        , update = update
        , view = \model -> { title = "Dashboard", body = [ Klar.stylesheet, view model ] }
        , subscriptions = \_ -> Sub.none
        }


init : ( Model, Cmd Msg )
init =
    let
        model =
            { period = Month
            , summary = Loading
            , sales = Loading
            , statuses = Loading
            , regions = Loading
            , activity = Loading
            , activityAttempts = 0
            , tree = Tree.init "regions"
            , settings = Settings.default
            }
    in
    ( model, Cmd.batch [ loadAll model, Task.perform GotZone Time.here ] )


regionIds : Ids RegionId
regionIds =
    Ids.make { toKey = \(RegionId n) -> String.fromInt n, fromKey = \s -> Maybe.map RegionId (String.toInt s) }



-- BACKEND (stand-ins that answer after a pause; replace each with a request)


reply : Int -> (Result Remote.Problem a -> Answer) -> Period -> Result Remote.Problem a -> Cmd Msg
reply ms toAnswer period result =
    Process.sleep (toFloat ms)
        |> Task.andThen (\_ -> Time.now)
        |> Task.perform (\at -> Got period at (toAnswer result))


down : Result Remote.Problem a
down =
    Err (Remote.problem Remote.server)


loadAll : Model -> Cmd Msg
loadAll model =
    Cmd.batch (List.map (load model) [ SummaryPanel, SalesPanel, StatusesPanel, RegionsPanel, ActivityPanel ])


load : Model -> Panel -> Cmd Msg
load model panel =
    let
        days =
            periodDays model.period

        scale =
            toFloat days
    in
    case panel of
        SummaryPanel ->
            reply 400 GotSummary model.period (Ok { orders = days * 41, revenue = scale * 1830.5, previousRevenue = scale * 1710, lateShare = 4.2 })

        SalesPanel ->
            reply 900
                GotSales
                model.period
                (Ok
                    { labels = List.map (\n -> "Week " ++ String.fromInt n) (List.range 1 6)
                    , thisPeriod = List.map (\n -> scale * toFloat (n + 3) * 12) (List.range 1 6)
                    , lastPeriod = List.map (\n -> scale * toFloat (n + 2) * 11) (List.range 1 6)
                    }
                )

        StatusesPanel ->
            -- fails for 90 days, so the old numbers stay with a notice
            if model.period == Quarter then
                reply 600 GotStatuses model.period down

            else
                reply 600 GotStatuses model.period (Ok [ ( "Shipped", 62 ), ( "Packed", 21 ), ( "Late", 7 ), ( "Canceled", 3 ) ])

        RegionsPanel ->
            reply 1200
                GotRegions
                model.period
                (Ok
                    [ Region (RegionId 1) "North" [ Region (RegionId 11) "Tromsø" [], Region (RegionId 12) "Bodø" [] ]
                    , Region (RegionId 2) "South" [ Region (RegionId 21) "Oslo" [], Region (RegionId 22) "Kristiansand" [] ]
                    ]
                )

        ActivityPanel ->
            -- fails on the first request, answers on a retry
            if model.activityAttempts == 0 then
                reply 800 GotActivity model.period down

            else
                reply 500
                    GotActivity
                    model.period
                    (Ok
                        [ Activity "a-3" 1760000000000 "Order 1043 shipped"
                        , Activity "a-2" 1759990000000 "Order 1042 packed"
                        , Activity "a-1" 1759980000000 "Order 1041 created"
                        ]
                    )


periodDays : Period -> Int
periodDays period =
    case period of
        Week ->
            7

        Month ->
            30

        Quarter ->
            90



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PeriodPicked key ->
            let
                reloaded =
                    { model
                        | period = periodFromKey key
                        , summary = Remote.refresh model.summary
                        , sales = Remote.refresh model.sales
                        , statuses = Remote.refresh model.statuses
                        , regions = Remote.refresh model.regions
                        , activity = Remote.refresh model.activity
                    }
            in
            ( reloaded, loadAll reloaded )

        GotZone zone ->
            ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

        TreeMsg m ->
            let
                ( tree, cmd ) =
                    Tree.update m model.tree
            in
            ( { model | tree = tree }, Cmd.map TreeMsg cmd )

        Retry panel ->
            let
                next =
                    refreshPanel panel model
            in
            ( next, load next panel )

        RetryStale ->
            let
                stale =
                    List.filterMap
                        (\( panel, remoteIsStale ) ->
                            if remoteIsStale then
                                Just panel

                            else
                                Nothing
                        )
                        [ ( SummaryPanel, Remote.isStale model.summary )
                        , ( SalesPanel, Remote.isStale model.sales )
                        , ( StatusesPanel, Remote.isStale model.statuses )
                        , ( RegionsPanel, Remote.isStale model.regions )
                        , ( ActivityPanel, Remote.isStale model.activity )
                        ]

                next =
                    List.foldl refreshPanel model stale
            in
            ( next, Cmd.batch (List.map (load next) stale) )

        Got period at answer ->
            if period /= model.period then
                ( model, Cmd.none )

            else
                ( store at answer model, Cmd.none )


{-| Data that is there stays (dimmed and busy); a panel with nothing yet shows its skeleton.
-}
refreshPanel : Panel -> Model -> Model
refreshPanel panel model =
    case panel of
        SummaryPanel ->
            { model | summary = Remote.refresh model.summary }

        SalesPanel ->
            { model | sales = Remote.refresh model.sales }

        StatusesPanel ->
            { model | statuses = Remote.refresh model.statuses }

        RegionsPanel ->
            { model | regions = Remote.refresh model.regions }

        ActivityPanel ->
            { model | activity = Remote.refresh model.activity, activityAttempts = model.activityAttempts + 1 }


store : Time.Posix -> Answer -> Model -> Model
store at answer model =
    case answer of
        GotSummary r ->
            { model | summary = Remote.refreshWith model.summary r at }

        GotSales r ->
            { model | sales = Remote.refreshWith model.sales r at }

        GotStatuses r ->
            { model | statuses = Remote.refreshWith model.statuses r at }

        GotRegions r ->
            { model | regions = Remote.refreshWith model.regions r at }

        GotActivity r ->
            { model | activity = Remote.refreshWith model.activity r at }


periodFromKey : String -> Period
periodFromKey key =
    case key of
        "7" ->
            Week

        "90" ->
            Quarter

        _ ->
            Month



-- VIEW


view : Model -> Html Msg
view model =
    Layout.stack [ Layout.gap 4, Layout.padding 4 ]
        [ PageHeader.view [ PageHeader.title "Operations", PageHeader.actions [ periodPicker model.period ] ]
        , Alert.stale [] RetryStale (staleNames model)
        , Stat.row (viewStats model)
        , Layout.grid [ Layout.columns 2, Layout.gap 4 ]
            [ Card.view [ Card.title "Revenue" ] [ viewSales model ]
            , Card.view [ Card.title "Orders by status" ] [ viewStatuses model ]
            , Card.view [ Card.title "Regions" ] [ viewRegions model ]
            , Card.view [ Card.title "Activity" ] [ viewActivity model ]
            ]
        ]


staleNames : Model -> List String
staleNames model =
    List.concat
        [ Remote.staleIn "figures" model.summary
        , Remote.staleIn "revenue" model.sales
        , Remote.staleIn "order statuses" model.statuses
        , Remote.staleIn "regions" model.regions
        , Remote.staleIn "activity" model.activity
        ]


periodPicker : Period -> Html Msg
periodPicker period =
    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Period"
        , SegmentedControl.options
            [ SegmentedControl.option "7" "7 days"
            , SegmentedControl.option "30" "30 days"
            , SegmentedControl.option "90" "90 days"
            ]
        , SegmentedControl.selected (Just (String.fromInt (periodDays period)))
        , SegmentedControl.onSelect PeriodPicked
        ]


viewStats : Model -> List (Html Msg)
viewStats model =
    [ Stat.view
        [ Stat.label "Orders"
        , Stat.settings model.settings
        , Stat.remote model.summary (\s -> [ Stat.int s.orders ])
        , Stat.onRetry (Retry SummaryPanel)
        ]
    , Stat.view
        [ Stat.label "Revenue"
        , Stat.settings model.settings
        , Stat.remote model.summary
            (\s -> [ Stat.abbreviated s.revenue, Stat.change { current = s.revenue, previous = s.previousRevenue } ])
        , Stat.onRetry (Retry SummaryPanel)
        ]
    , Stat.view
        [ Stat.label "Late"
        , Stat.settings model.settings
        , Stat.remote model.summary (\s -> [ Stat.decimal 1 s.lateShare, Stat.unit "%" ])
        , Stat.lowerIsBetter
        , Stat.onRetry (Retry SummaryPanel)
        ]
    ]


viewSales : Model -> Html Msg
viewSales model =
    Chart.lineRemote
        [ Chart.settings model.settings
        , Chart.onRetry (Retry SalesPanel)
        ]
        (Remote.map
            (\sales ->
                Chart.byCategory sales.labels
                    [ Chart.series "This period" sales.thisPeriod
                    , Chart.series "Last period" sales.lastPeriod |> Chart.dashed
                    ]
            )
            model.sales
        )


viewStatuses : Model -> Html Msg
viewStatuses model =
    Chart.donutRemote [ Chart.settings model.settings, Chart.onRetry (Retry StatusesPanel) ]
        (Remote.map (List.map (\( name, share ) -> Chart.segment name share)) model.statuses)


viewRegions : Model -> Html Msg
viewRegions model =
    Tree.viewRemote TreeMsg
        [ Tree.ariaLabel "Regions", Tree.onReload (Retry RegionsPanel) ]
        model.tree
        (Remote.map (List.map toNode) model.regions)


toNode : Region -> Tree.Node RegionId
toNode (Region id name children) =
    if List.isEmpty children then
        Tree.leaf regionIds id name

    else
        Tree.branch regionIds id name (List.map toNode children)


viewActivity : Model -> Html Msg
viewActivity model =
    Timeline.viewRemote
        [ Timeline.settings model.settings
        , Timeline.now (Time.millisToPosix 1760000100000)
        , Timeline.onRetry (Retry ActivityPanel)
        ]
        (Remote.map (List.map (\a -> Timeline.event a.id (Time.millisToPosix a.at) a.title)) model.activity)
