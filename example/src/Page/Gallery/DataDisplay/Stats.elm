module Page.Gallery.DataDisplay.Stats exposing (Model, Msg, init, update, view)

{-| The key figure section: a row of tiles, and single tiles in their states.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Card as Card
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Stat as Stat
import Klar.Theme exposing (Size(..), Tone(..))
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { shipments : Remote Int
    , clicks : Int
    }


type Msg
    = Reload
    | Loaded (Result Problem Int)
    | Clicked


init : Model
init =
    { shipments = Remote.Failure (Remote.problem Remote.timeout)
    , clicks = 0
    }


update : Bool -> Msg -> Model -> ( Model, Cmd Msg )
update failing msg model =
    case msg of
        Reload ->
            ( { model | shipments = Remote.Loading }
            , Cmd.map Loaded (Pretend.respond failing 1284)
            )

        Loaded result ->
            ( { model | shipments = Remote.fromResult result }, Cmd.none )

        Clicked ->
            ( { model | clicks = model.clicks + 1 }, Cmd.none )



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    let
        trendUp =
            [ 12, 14, 13, 17, 16, 19, 18, 21, 24, 23, 26, 29 ]

        trendDown =
            [ 22, 21, 23, 20, 19, 19, 17, 18, 16, 15, 14, 14 ]
    in
    Doc.section "Key figures"
        "A number with a name, a change and a short trend. The color of the change follows direction and meaning: up is good, unless the number is something you want low. The arrow and a hidden word (“increase”, “decrease”) carry the direction, so the color is never the only signal. A clickable tile is a button: Tab moves the focus, Enter or Space clicks."
        [ Doc.example
            { title = "A row of key figures"
            , description = Nothing
            , code = Just """Stat.row
    [ Stat.view
        [ Stat.label "Open orders"
        , Stat.int 1284
        , Stat.delta 4.2
        , Stat.deltaLabel "vs. last week"
        , Stat.trend [ 12, 14, 13, 17 ]
        ]
    , Stat.view
        [ Stat.label "Delivery time"
        , Stat.decimal 1 14.5
        , Stat.unit "days"
        , Stat.delta -8.5
        , Stat.lowerIsBetter
        ]
    ]"""
            }
            (Stat.row
                [ Stat.view
                    [ Stat.label "Open orders"
                    , Stat.int 1284
                    , Stat.delta 4.2
                    , Stat.deltaLabel "vs. last week"
                    , Stat.trend trendUp
                    , Stat.locale locale
                    ]
                , Stat.view
                    [ Stat.label "Average delivery time"
                    , Stat.decimal 1 14.5
                    , Stat.unit "days"
                    , Stat.delta -8.5
                    , Stat.lowerIsBetter
                    , Stat.deltaLabel "vs. last week"
                    , Stat.trend trendDown
                    , Stat.locale locale
                    ]
                , Stat.view
                    [ Stat.label "Warehouse utilization"
                    , Stat.value (Format.percent locale 0 0.87)
                    , Stat.delta 0
                    , Stat.deltaLabel "vs. last week"
                    , Stat.locale locale
                    ]
                , Stat.view
                    [ Stat.label "Revenue"
                    , Stat.compact 4200000
                    , Stat.unit "USD"
                    , Stat.delta -1.3
                    , Stat.caption "Last 30 days"
                    , Stat.locale locale
                    ]
                ]
            )
        , Doc.example
            { title = "Single tiles and states"
            , description = Just "Loading shows a skeleton of the same height. A failure shows a short message and “Try again” without moving the rest. The first tile fetches from the pretend backend: it starts failed, and “Try again” or “Reload the first tile” fetches it. With “Simulate failures” switched on, it fails again."
            , code = Just """Stat.view
    [ Stat.label "Shipments today"
    , Stat.onRetry Reload
    , Stat.remote model.shipments (\\n -> [ Stat.int n, Stat.delta 2.4 ])
    ]

Stat.view [ Stat.label "Loading", Stat.loading True ]

Stat.view [ Stat.label "Alerts", Stat.int 37, Stat.icon Icon.bell, Stat.onClick OpenAlerts ]

Stat.view [ Stat.label "Backlog", Stat.int 218, Stat.delta 3.1, Stat.deltaText "+7 orders", Stat.lowerIsBetter ]"""
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2 ]
                    [ Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick Reload ] "Reload the first tile" ]
                , Layout.grid [ Layout.minColumn 220, Layout.gap 3 ]
                    [ Stat.view
                        [ Stat.label "Shipments today"
                        , Stat.onRetry Reload
                        , Stat.remote model.shipments
                            (\n -> [ Stat.int n, Stat.delta 2.4, Stat.deltaLabel "vs. yesterday" ])
                        , Stat.locale locale
                        ]
                    , Stat.view [ Stat.label "Loading", Stat.loading True, Stat.locale locale ]
                    , Stat.view
                        [ Stat.label "Clickable, with an icon"
                        , Stat.int 37
                        , Stat.icon Icon.bell
                        , Stat.caption
                            (if model.clicks == 0 then
                                "Open alerts"

                             else
                                "Open alerts · clicked " ++ Format.int locale model.clicks ++ " " ++ Format.plural locale model.clicks { one = "time", other = "times" }
                            )
                        , Stat.onClick Clicked
                        , Stat.locale locale
                        ]
                    , Stat.view
                        [ Stat.label "Large"
                        , Stat.size Large
                        , Stat.int 12840
                        , Stat.unit "hours"
                        , Stat.delta 12
                        , Stat.deltaTone Primary
                        , Stat.locale locale
                        ]
                    , Stat.view [ Stat.label "Small", Stat.size Small, Stat.int 12, Stat.delta -3, Stat.locale locale ]
                    , Stat.view
                        [ Stat.label "A very long name for the key figure that does not fit on one line"
                        , Stat.value (Format.int locale 1000000000000)
                        , Stat.unit "units"
                        , Stat.locale locale
                        ]
                    , Stat.view
                        [ Stat.label "Order backlog"
                        , Stat.int 218
                        , Stat.delta 3.1
                        , Stat.deltaText "+7 orders"
                        , Stat.lowerIsBetter
                        , Stat.deltaLabel "since yesterday"
                        , Stat.locale locale
                        ]
                    , Stat.view
                        [ Stat.label "Perfect orders"
                        , Stat.value (Format.percent locale 1 0.962)
                        , Stat.delta 1.1
                        , Stat.trend trendUp
                        , Stat.trendTone Success
                        , Stat.locale locale
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "Inside a card"
            , description = Just "A flat tile has no border and no background of its own, for a tile that sits in a card or another bordered container."
            , code = Just """Card.view []
    [ Stat.view [ Stat.label "Picked today", Stat.int 842, Stat.flat ] ]"""
            }
            (Layout.grid [ Layout.minColumn 260, Layout.gap 4 ]
                [ Card.view []
                    [ Stat.view [ Stat.label "Picked today", Stat.int 842, Stat.delta 6.4, Stat.flat, Stat.locale locale ] ]
                , Card.view []
                    [ Stat.view [ Stat.label "Open returns", Stat.int 31, Stat.delta 12.5, Stat.lowerIsBetter, Stat.flat, Stat.locale locale ] ]
                ]
            )
        ]
