module Page.Overview exposing (Model, Msg, init, subscriptions, takeEffects, update, view)

{-| The overview: key figures, charts and the activity feed from one request, and
the orders that need attention. Everything has a loading and a failed state, and
the whole page can be retried.
-}

import Api exposing (Backend)
import Api.Problem as Problem
import Api.Types as Types exposing (Activity, ActivityKind(..), ApiError, Order, Summary)
import Backend.Generate as Generate
import Html exposing (Html)
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.Date as Date
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale as Locale
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Stat as Stat
import Klar.Theme exposing (Tone(..))
import Klar.Timeline as Timeline
import Page.Effect as Effect exposing (Context, Effect(..))
import Route
import View.Labels as Labels



-- MODEL


type alias Model =
    { summary : Remote Summary
    , effects : Effect.Outbox
    }


init : Context -> Backend -> ( Model, Backend, Cmd Msg )
init _ backend =
    let
        ( backend1, cmd ) =
            Api.summary Loaded backend
    in
    ( { summary = Remote.Loading, effects = Effect.empty }, backend1, cmd )


{-| The effects the last update left for `Main` to carry out.
-}
takeEffects : Model -> ( Model, Effect.Outbox )
takeEffects =
    Effect.take



-- UPDATE


type Msg
    = Loaded (Result ApiError Summary)
    | Retry
    | Open Order


update : Context -> Msg -> Backend -> Model -> ( Model, Backend, Cmd Msg )
update context msg backend model =
    case msg of
        Loaded (Ok summary) ->
            ( { model | summary = Remote.Loaded summary }, backend, Cmd.none )

        Loaded (Err error) ->
            ( { model | summary = Remote.Failed (Problem.toProblem error) }, backend, Cmd.none )

        Retry ->
            let
                ( backend1, cmd ) =
                    Api.summary Loaded backend
            in
            ( { model | summary = Remote.Loading }, backend1, cmd )

        Open order ->
            ( { model | effects = Effect.push (Go (Route.OrderDetail order.id)) model.effects }, backend, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Context -> Model -> Effect.View Msg
view context model =
    { content =
        Layout.stack [ Layout.gap 5 ]
            [ PageHeader.view
                [ PageHeader.title "Overview"
                , PageHeader.subtitle "Orders, revenue and delivery performance at a glance."
                ]
            , case model.summary of
                Remote.Failed problem ->
                    Card.view []
                        [ ErrorState.view [ ErrorState.onRetry Retry, ErrorState.locale context.locale ] problem ]

                _ ->
                    viewSummary context model.summary
            ]
    , overlays = []
    }


viewSummary : Context -> Remote Summary -> Html Msg
viewSummary context summary =
    Layout.stack [ Layout.gap 5 ]
        [ Layout.grid [ Layout.minColumn 210, Layout.gap 4 ]
            [ Stat.view
                [ Stat.label "Open orders"
                , Stat.icon Icon.clipboard
                , Stat.locale context.locale
                , Stat.settings context.settings
                , Stat.remote summary (\s -> [ Stat.int s.open, Stat.caption ("of " ++ Format.int context.locale s.orders ++ " orders") ])
                ]
            , Stat.view
                [ Stat.label "Overdue"
                , Stat.icon Icon.warning
                , Stat.locale context.locale
                , Stat.settings context.settings
                , Stat.remote summary
                    (\s ->
                        [ Stat.int s.overdue
                        , Stat.caption "past their due date"
                        , Stat.deltaTone
                            (if s.overdue == 0 then
                                Success

                             else
                                Danger
                            )
                        ]
                    )
                ]
            , Stat.view
                [ Stat.label "Revenue, last 30 days"
                , Stat.icon Icon.trendUp
                , Stat.locale context.locale
                , Stat.settings context.settings
                , Stat.remote summary (\s -> [ Stat.compact s.revenue, Stat.unit "USD", Stat.caption "orders that are not cancelled" ])
                ]
            , Stat.view
                [ Stat.label "On-time delivery"
                , Stat.icon Icon.clock
                , Stat.locale context.locale
                , Stat.settings context.settings
                , Stat.remote summary (\s -> [ Stat.value (Format.percent context.locale 1 s.onTimeRate), Stat.caption "delivered on or before the due date" ])
                ]
            ]
        , Layout.grid [ Layout.minColumn 420, Layout.gap 4 ]
            [ Card.view [ Card.headingLevel 2, Card.title "Orders per day", Card.subtitle "Created in the last 30 days" ]
                [ chartOrSkeleton summary (perDayChart context) ]
            , Card.view [ Card.headingLevel 2, Card.title "Orders by status", Card.subtitle "Where the orders are in their life" ]
                [ chartOrSkeleton summary (statusChart context) ]
            , Card.view [ Card.headingLevel 2, Card.title "Revenue by country", Card.subtitle "The six largest markets, in USD" ]
                [ chartOrSkeleton summary (countryChart context) ]
            , Card.view [ Card.headingLevel 2, Card.title "On-time delivery", Card.subtitle "Share of delivered orders that arrived in time" ]
                [ chartOrSkeleton summary (onTimeGauge context) ]
            , Card.view
                [ Card.headingLevel 2
                , Card.title "Needs attention"
                , Card.subtitle "Overdue or urgent orders that are still open"
                , Card.flush
                ]
                [ ListItem.viewRemote
                    [ ListItem.ariaLabel "Orders that need attention"
                    , ListItem.emptyState
                        [ EmptyState.title "Nothing needs attention"
                        , EmptyState.description "No open order is overdue or urgent right now."
                        ]
                    , ListItem.skeletonRows 4
                    ]
                    (Remote.map (.attention >> List.map (\order -> ( Types.orderIdText order.id, attentionRow context order ))) summary)
                ]
            , Card.view [ Card.headingLevel 2, Card.title "Recent activity", Card.subtitle "The latest things that happened to orders" ]
                [ activity context summary ]
            ]
        ]


chartOrSkeleton : Remote Summary -> (Summary -> Html Msg) -> Html Msg
chartOrSkeleton summary toChart =
    case summary of
        Remote.Loaded s ->
            toChart s

        _ ->
            Skeleton.block 200


perDayChart : Context -> Summary -> Html Msg
perDayChart context summary =
    Chart.line
        [ -- The card above already shows the title.
          Chart.ariaLabel "Orders created per day"
        , Chart.categories (List.map (Tuple.first >> dayLabel context) summary.perDay)
        , Chart.area
        , Chart.maxLabels 6
        , Chart.includeZero True
        , Chart.locale context.locale
        , Chart.settings context.settings
        ]
        [ Chart.series "Orders" (List.map (Tuple.second >> toFloat) summary.perDay) ]


dayLabel : Context -> Date.Date -> String
dayLabel context date =
    String.fromInt (Date.day date) ++ " " ++ Locale.monthShort context.locale (Date.month date)


statusChart : Context -> Summary -> Html Msg
statusChart context summary =
    Chart.donut
        [ Chart.ariaLabel "Orders by status"
        , Chart.centerLabel (Format.int context.locale summary.orders)
        , Chart.centerCaption "orders"
        , Chart.locale context.locale
        , Chart.settings context.settings
        ]
        (List.map
            (\( status, n ) ->
                Chart.segment (Types.orderStatusLabel status) (toFloat n)
                    |> Chart.segmentTone (Labels.statusTone status)
            )
            summary.byStatus
        )


countryChart : Context -> Summary -> Html Msg
countryChart context summary =
    Chart.bar
        [ Chart.ariaLabel "Revenue by country"
        , Chart.categories (List.map Tuple.first summary.revenueByCountry)
        , Chart.horizontal
        , Chart.valueLabels
        , Chart.locale context.locale
        , Chart.settings context.settings
        , Chart.valueFormat (\amount -> Format.currency context.locale "$" 0 amount)
        ]
        [ Chart.series "Revenue" (List.map Tuple.second summary.revenueByCountry) ]


onTimeGauge : Context -> Summary -> Html Msg
onTimeGauge context summary =
    Chart.gauge
        [ Chart.ariaLabel "On-time delivery"
        , Chart.range 0 100
        , Chart.thresholds [ ( 80, Danger ), ( 90, Warning ), ( 100, Success ) ]
        , Chart.unit "%"
        , Chart.locale context.locale
        , Chart.settings context.settings
        ]
        (summary.onTimeRate * 100)


attentionRow : Context -> Order -> Html Msg
attentionRow context order =
    ListItem.view
        [ ListItem.avatar order.customer
        , ListItem.secondary (Types.orderIdText order.id ++ " · due " ++ Format.date context.locale order.due)
        , ListItem.meta (Types.priorityLabel order.priority)
        , ListItem.onClick (Open order)
        ]
        order.customer


activity : Context -> Remote Summary -> Html Msg
activity context summary =
    Timeline.view
        [ Timeline.remote summary
        , Timeline.skeletonRows 4
        , Timeline.emptyTitle "No activity yet"

        -- The dummy backend pretends it is this moment, so "Today" and
        -- "Yesterday" mean the same as in its data.
        , Timeline.now Generate.now
        , Timeline.settings context.settings
        , Timeline.compact
        , Timeline.ariaLabel "Recent activity"
        , Timeline.locale context.locale
        ]
        (summary
            |> Remote.toMaybe
            |> Maybe.map (.activity >> List.map activityEvent)
            |> Maybe.withDefault []
        )


activityEvent : Activity -> Timeline.Event Msg
activityEvent item =
    let
        ( title, tone, icon ) =
            case item.kind of
                OrderCreated ->
                    ( "Order " ++ Types.orderIdText item.orderId ++ " created", Info, Icon.plus )

                OrderShipped ->
                    ( "Order " ++ Types.orderIdText item.orderId ++ " shipped", Primary, Icon.send )

                OrderDelivered ->
                    ( "Order " ++ Types.orderIdText item.orderId ++ " delivered", Success, Icon.check )

                OrderCancelled ->
                    ( "Order " ++ Types.orderIdText item.orderId ++ " cancelled", Danger, Icon.close )
    in
    Timeline.event (Types.orderIdText item.orderId ++ "-" ++ Types.activityKey item.kind) item.at title
        |> Timeline.withTone tone
        |> Timeline.withIcon icon
        |> Timeline.withDescription item.customer
