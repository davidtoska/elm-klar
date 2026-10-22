module Main exposing (main)

{-| A dashboard in which every panel is its own `Remote`.

A period picker (`SegmentedControl`) reloads five panels: `Stat` tiles, a `Chart` line, a
`Chart` donut, a `Tree` of regions and warehouses, and a `Timeline`. Each panel is `Loading`,
`Failed` (with its own retry) or `Loaded` on its own, so one failure never hides the others.
The Activity panel fails on its first request, so retry can be tried. An answer for a period
the user has already left is dropped.

The components draw all four states from the `Remote`; the page writes no case for them.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.Layout as Layout
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SegmentedControl as SegmentedControl
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
    }


type Panel
    = SummaryPanel
    | SalesPanel
    | StatusesPanel
    | RegionsPanel
    | ActivityPanel


type Msg
    = PeriodPicked String
    | Got Period Answer
    | Retry Panel
    | TreeMsg Tree.Msg


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
            }
    in
    ( model, loadAll model )


regionIds : Tree.Ids RegionId
regionIds =
    Tree.nodeIds { toKey = \(RegionId n) -> String.fromInt n, fromKey = \s -> Maybe.map RegionId (String.toInt s) }



-- BACKEND (stand-ins that answer after a pause; replace each with a request)


reply : Int -> (Result Remote.Problem a -> Answer) -> Period -> a -> Cmd Msg
reply ms toAnswer period data =
    Process.sleep (toFloat ms)
        |> Task.perform (\_ -> Got period (toAnswer (Ok data)))


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
            reply 400 GotSummary model.period { orders = days * 41, revenue = scale * 1830.5, previousRevenue = scale * 1710, lateShare = 4.2 }

        SalesPanel ->
            reply 900
                GotSales
                model.period
                { labels = List.map (\n -> "Week " ++ String.fromInt n) (List.range 1 6)
                , thisPeriod = List.map (\n -> scale * toFloat (n + 3) * 12) (List.range 1 6)
                , lastPeriod = List.map (\n -> scale * toFloat (n + 2) * 11) (List.range 1 6)
                }

        StatusesPanel ->
            reply 600 GotStatuses model.period [ ( "Shipped", 62 ), ( "Packed", 21 ), ( "Late", 7 ), ( "Canceled", 3 ) ]

        RegionsPanel ->
            reply 1200
                GotRegions
                model.period
                [ Region (RegionId 1) "North" [ Region (RegionId 11) "Tromsø" [], Region (RegionId 12) "Bodø" [] ]
                , Region (RegionId 2) "South" [ Region (RegionId 21) "Oslo" [], Region (RegionId 22) "Kristiansand" [] ]
                ]

        ActivityPanel ->
            -- fails on the first request, answers on a retry
            if model.activityAttempts == 0 then
                Process.sleep 800
                    |> Task.perform (\_ -> Got model.period (GotActivity (Err (Remote.problem Remote.server))))

            else
                reply 500
                    GotActivity
                    model.period
                    [ Activity "a-3" 1760000000000 "Order 1043 shipped"
                    , Activity "a-2" 1759990000000 "Order 1042 packed"
                    , Activity "a-1" 1759980000000 "Order 1041 created"
                    ]


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
                        , summary = Loading
                        , sales = Loading
                        , statuses = Loading
                        , regions = Loading
                        , activity = Loading
                    }
            in
            ( reloaded, loadAll reloaded )

        TreeMsg m ->
            let
                ( tree, cmd ) =
                    Tree.update m model.tree
            in
            ( { model | tree = tree }, Cmd.map TreeMsg cmd )

        Retry panel ->
            let
                -- KLAR GAP: Remote has no "stale" state, so a reload empties the panel (skeleton) instead of keeping the old data dimmed.
                next =
                    case panel of
                        SummaryPanel ->
                            { model | summary = Loading }

                        SalesPanel ->
                            { model | sales = Loading }

                        StatusesPanel ->
                            { model | statuses = Loading }

                        RegionsPanel ->
                            { model | regions = Loading }

                        ActivityPanel ->
                            { model | activity = Loading, activityAttempts = model.activityAttempts + 1 }
            in
            ( next, load next panel )

        Got period answer ->
            if period /= model.period then
                ( model, Cmd.none )

            else
                ( store answer model, Cmd.none )


store : Answer -> Model -> Model
store answer model =
    case answer of
        GotSummary r ->
            { model | summary = Remote.fromResult r }

        GotSales r ->
            { model | sales = Remote.fromResult r }

        GotStatuses r ->
            { model | statuses = Remote.fromResult r }

        GotRegions r ->
            { model | regions = Remote.fromResult r }

        GotActivity r ->
            { model | activity = Remote.fromResult r }


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
        , Stat.row (viewStats model)
        , Layout.grid [ Layout.columns 2, Layout.gap 4 ]
            [ Card.view [ Card.title "Revenue" ] [ viewSales model ]
            , Card.view [ Card.title "Orders by status" ] [ viewStatuses model ]
            , Card.view [ Card.title "Regions" ] [ viewRegions model ]
            , Card.view [ Card.title "Activity" ] [ viewActivity model ]
            ]
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
        , Stat.remote model.summary (\s -> [ Stat.int s.orders ])
        , Stat.onRetry (Retry SummaryPanel)
        ]
    , Stat.view
        [ Stat.label "Revenue"
        , Stat.remote model.summary
            (\s -> [ Stat.compact s.revenue, Stat.change { current = s.revenue, previous = s.previousRevenue } ])
        , Stat.onRetry (Retry SummaryPanel)
        ]
    , Stat.view
        [ Stat.label "Late"
        , Stat.remote model.summary (\s -> [ Stat.decimal 1 s.lateShare, Stat.unit "%" ])
        , Stat.lowerIsBetter
        , Stat.onRetry (Retry SummaryPanel)
        ]
    ]


viewSales : Model -> Html Msg
viewSales model =
    -- remote and onRetry only: `Chart.loading` after `Chart.remote` would cancel it
    case model.sales of
        Loaded sales ->
            Chart.line [ Chart.categories sales.labels, Chart.remote model.sales, Chart.onRetry (Retry SalesPanel) ]
                [ Chart.series "This period" sales.thisPeriod, Chart.series "Last period" sales.lastPeriod |> Chart.dashed ]

        _ ->
            Chart.line [ Chart.remote model.sales, Chart.onRetry (Retry SalesPanel) ] []


viewStatuses : Model -> Html Msg
viewStatuses model =
    Chart.donut [ Chart.remote model.statuses, Chart.onRetry (Retry StatusesPanel) ]
        (List.map (\( name, share ) -> Chart.segment name share) (Remote.withDefault [] model.statuses))


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
    Timeline.view
        [ Timeline.zone Time.utc
        , Timeline.now (Time.millisToPosix 1760000100000)
        , Timeline.remote model.activity
        , Timeline.onRetry (Retry ActivityPanel)
        ]
        (List.map (\a -> Timeline.event a.id (Time.millisToPosix a.at) a.title) (Remote.withDefault [] model.activity))
