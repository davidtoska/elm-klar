module Page.Gallery.DataDisplay.Stats exposing (Model, Msg, init, update, view)

{-| The key figure section: a row of tiles, and single tiles in their states.
-}

import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Card as Card
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.RemoteView as RemoteView
import Klar.Stat as Stat
import Klar.Theme exposing (Size(..), Tone(..))
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { shipments : Remote Int
    , clicks : Int
    }


type Msg
    = Reload
    | RetryTile
    | Focused
    | Loaded (Result Problem Int)
    | Clicked


init : Model
init =
    { shipments = Remote.Failed (Remote.problem Remote.timeout)
    , clicks = 0
    }


update : Bool -> Msg -> Model -> ( Model, Cmd Msg )
update failing msg model =
    case msg of
        Reload ->
            ( { model | shipments = Remote.Loading }
            , Cmd.map Loaded (Pretend.respond failing 1284)
            )

        RetryTile ->
            -- "Try again" is replaced by the skeleton: focus goes to the tile (its id).
            ( { model | shipments = Remote.Loading }
            , Cmd.batch
                [ Cmd.map Loaded (Pretend.respond failing 1284)
                , Klar.focus "shipments-tile" Focused
                ]
            )

        Focused ->
            ( model, Cmd.none )

        Loaded result ->
            ( { model | shipments = Remote.fromResult result }, Cmd.none )

        Clicked ->
            ( { model | clicks = model.clicks + 1 }, Cmd.none )



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    let
        trendUp =
            [ 12, 14, 13, 17, 16, 19, 18, 21, 24, 23, 26, 29 ]

        trendDown =
            [ 22, 21, 23, 20, 19, 19, 17, 18, 16, 15, 14, 14 ]
    in
    Doc.configuredSection playground
        [ "Stat" ]
        "Key figures"
        "A number with a name, a change and a short trend. The color of the change follows direction and meaning: up is good, unless the number is something you want low. The arrow and a hidden word (“increase”, “decrease”) carry the direction, so the color is never the only signal. A clickable tile is a button: Tab moves the focus, Enter or Space clicks."
        [ Doc.configuredExample playground
            [ "Stat" ]
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
                    (Options.klarStat playground
                        (List.concat
                            [ Config.keep playground "Stat" "label" (Stat.label "Open orders")
                            , Config.keep playground "Stat" "int" (Stat.int 1284)
                            , Config.keep playground "Stat" "delta" (Stat.delta 4.2)
                            , Config.keep playground "Stat" "deltaLabel" (Stat.deltaLabel "vs. last week")
                            , Config.keep playground "Stat" "trend" (Stat.trend trendUp)
                            , Config.keep playground "Stat" "locale" (Stat.locale locale)
                            ]
                        )
                    )
                , Stat.view
                    (Options.klarStat playground
                        (List.concat
                            [ Config.keep playground "Stat" "label" (Stat.label "Average delivery time")
                            , Config.keep playground "Stat" "decimal" (Stat.decimal 1 14.5)
                            , Config.keep playground "Stat" "unit" (Stat.unit "days")
                            , Config.keep playground "Stat" "delta" (Stat.delta -8.5)
                            , Config.keep playground "Stat" "lowerIsBetter" Stat.lowerIsBetter
                            , Config.keep playground "Stat" "deltaLabel" (Stat.deltaLabel "vs. last week")
                            , Config.keep playground "Stat" "trend" (Stat.trend trendDown)
                            , Config.keep playground "Stat" "locale" (Stat.locale locale)
                            ]
                        )
                    )
                , Stat.view
                    (Options.klarStat playground
                        (List.concat
                            [ Config.keep playground "Stat" "label" (Stat.label "Warehouse utilization")
                            , Config.keep playground "Stat" "value" (Stat.value (Format.percent locale 0 0.87))
                            , Config.keep playground "Stat" "delta" (Stat.delta 0)
                            , Config.keep playground "Stat" "deltaLabel" (Stat.deltaLabel "vs. last week")
                            , Config.keep playground "Stat" "locale" (Stat.locale locale)
                            ]
                        )
                    )
                , Stat.view
                    (Options.klarStat playground
                        (List.concat
                            [ Config.keep playground "Stat" "label" (Stat.label "Revenue")
                            , Config.keep playground "Stat" "abbreviated" (Stat.abbreviated 4200000)
                            , Config.keep playground "Stat" "unit" (Stat.unit "USD")
                            , Config.keep playground "Stat" "delta" (Stat.delta -1.3)
                            , Config.keep playground "Stat" "caption" (Stat.caption "Last 30 days")
                            , Config.keep playground "Stat" "locale" (Stat.locale locale)
                            ]
                        )
                    )
                ]
            )
        , Doc.configuredExample playground
            [ "Stat" ]
            { title = "Single tiles and states"
            , description = Just "Loading shows a skeleton of the same height. A failure shows a short message and “Try again” without moving the rest. The first tile fetches from the pretend backend: it starts failed, and “Try again” or “Reload the first tile” fetches it. With “Simulate failures” switched on, it fails again."
            , code = Just """Stat.view
    [ Stat.label "Shipments today"
    , Stat.id "shipments-tile"
    , Stat.onRetry RetryTile
    , Stat.remote model.shipments (\\n -> [ Stat.int n, Stat.delta 2.4 ])
    ]

Stat.view [ Stat.label "Loading", Stat.remote Remote.Loading (\\_ -> []) ]

Stat.view [ Stat.label "Alerts", Stat.int 37, Stat.icon Icon.bell, Stat.onClick OpenAlerts ]

Stat.view [ Stat.label "Backlog", Stat.int 218, Stat.deltaBy 7, Stat.deltaLabel "orders since yesterday", Stat.lowerIsBetter ]

Stat.view [ Stat.label "Perfect orders", Stat.value "96.2%", Stat.deltaPoints 1.1 ]"""
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick Reload) ])) "Reload the first tile" ]
                , Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 220), Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                    [ Stat.view
                        (Options.klarStat playground
                            (List.concat
                                [ Config.keep playground "Stat" "label" (Stat.label "Shipments today")
                                , Config.keep playground "Stat" "id" (Stat.id "shipments-tile")
                                , Config.keep playground "Stat" "onRetry" (Stat.onRetry RetryTile)
                                , Config.keep playground
                                    "Stat"
                                    "remote"
                                    (Stat.remote model.shipments
                                        (\n -> Options.klarStat playground (List.concat [ Config.keep playground "Stat" "int" (Stat.int n), Config.keep playground "Stat" "delta" (Stat.delta 2.4), Config.keep playground "Stat" "deltaLabel" (Stat.deltaLabel "vs. yesterday") ]))
                                    )
                                , Config.keep playground "Stat" "locale" (Stat.locale locale)
                                ]
                            )
                        )
                    , Stat.view (Options.klarStat playground (List.concat [ Config.keep playground "Stat" "label" (Stat.label "Loading"), Config.keep playground "Stat" "remote" (Stat.remote Remote.Loading (\_ -> [])), Config.keep playground "Stat" "locale" (Stat.locale locale) ]))
                    , Stat.view
                        (Options.klarStat playground
                            (List.concat
                                [ Config.keep playground "Stat" "label" (Stat.label "Clickable, with an icon")
                                , Config.keep playground "Stat" "int" (Stat.int 37)
                                , Config.keep playground "Stat" "icon" (Stat.icon Icon.bell)
                                , Config.keep playground
                                    "Stat"
                                    "caption"
                                    (Stat.caption
                                        (if model.clicks == 0 then
                                            "Open alerts"

                                         else
                                            "Open alerts · clicked " ++ Format.int locale model.clicks ++ " " ++ Format.plural locale model.clicks { one = "time", other = "times" }
                                        )
                                    )
                                , Config.keep playground "Stat" "onClick" (Stat.onClick Clicked)
                                , Config.keep playground "Stat" "locale" (Stat.locale locale)
                                ]
                            )
                        )
                    , Stat.view
                        (Options.klarStat playground
                            (List.concat
                                [ Config.keep playground "Stat" "label" (Stat.label "Large")
                                , Config.keep playground "Stat" "size" (Stat.size Large)
                                , Config.keep playground "Stat" "int" (Stat.int 12840)
                                , Config.keep playground "Stat" "unit" (Stat.unit "hours")
                                , Config.keep playground "Stat" "delta" (Stat.delta 12)
                                , Config.keep playground "Stat" "deltaTone" (Stat.deltaTone Primary)
                                , Config.keep playground "Stat" "locale" (Stat.locale locale)
                                ]
                            )
                        )
                    , Stat.view (Options.klarStat playground (List.concat [ Config.keep playground "Stat" "label" (Stat.label "Small"), Config.keep playground "Stat" "size" (Stat.size Small), Config.keep playground "Stat" "int" (Stat.int 12), Config.keep playground "Stat" "delta" (Stat.delta -3), Config.keep playground "Stat" "locale" (Stat.locale locale) ]))
                    , Stat.view
                        (Options.klarStat playground
                            (List.concat
                                [ Config.keep playground "Stat" "label" (Stat.label "A very long name for the key figure that does not fit on one line")
                                , Config.keep playground "Stat" "value" (Stat.value (Format.int locale 1000000000000))
                                , Config.keep playground "Stat" "unit" (Stat.unit "units")
                                , Config.keep playground "Stat" "locale" (Stat.locale locale)
                                ]
                            )
                        )
                    , Stat.view
                        (Options.klarStat playground
                            (List.concat
                                [ Config.keep playground "Stat" "label" (Stat.label "Order backlog")
                                , Config.keep playground "Stat" "int" (Stat.int 218)
                                , Config.keep playground "Stat" "deltaBy" (Stat.deltaBy 7)
                                , Config.keep playground "Stat" "lowerIsBetter" Stat.lowerIsBetter
                                , Config.keep playground "Stat" "deltaLabel" (Stat.deltaLabel "orders since yesterday")
                                , Config.keep playground "Stat" "locale" (Stat.locale locale)
                                ]
                            )
                        )
                    , Stat.view
                        (Options.klarStat playground
                            (List.concat
                                [ Config.keep playground "Stat" "label" (Stat.label "Perfect orders")
                                , Config.keep playground "Stat" "value" (Stat.value (Format.percent locale 1 0.962))
                                , Config.keep playground "Stat" "deltaPoints" (Stat.deltaPoints 1.1)
                                , Config.keep playground "Stat" "trend" (Stat.trend trendUp)
                                , Config.keep playground "Stat" "trendTone" (Stat.trendTone Success)
                                , Config.keep playground "Stat" "locale" (Stat.locale locale)
                                ]
                            )
                        )
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "Stat" ]
            { title = "Inside a card"
            , description = Just "A flat tile has no border and no background of its own, for a tile that sits in a card or another bordered container."
            , code = Just """Card.view []
    [ Stat.view [ Stat.label "Picked today", Stat.int 842, Stat.flat ] ]"""
            }
            (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 260), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ Card.view (Options.klarCard playground [])
                    [ Stat.view (Options.klarStat playground (List.concat [ Config.keep playground "Stat" "label" (Stat.label "Picked today"), Config.keep playground "Stat" "int" (Stat.int 842), Config.keep playground "Stat" "delta" (Stat.delta 6.4), Config.keep playground "Stat" "flat" Stat.flat, Config.keep playground "Stat" "locale" (Stat.locale locale) ])) ]
                , Card.view (Options.klarCard playground [])
                    [ Stat.view (Options.klarStat playground (List.concat [ Config.keep playground "Stat" "label" (Stat.label "Open returns"), Config.keep playground "Stat" "int" (Stat.int 31), Config.keep playground "Stat" "delta" (Stat.delta 12.5), Config.keep playground "Stat" "lowerIsBetter" Stat.lowerIsBetter, Config.keep playground "Stat" "flat" Stat.flat, Config.keep playground "Stat" "locale" (Stat.locale locale) ])) ]
                ]
            )
        ]
