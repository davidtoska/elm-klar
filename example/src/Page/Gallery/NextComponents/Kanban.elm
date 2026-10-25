module Page.Gallery.NextComponents.Kanban exposing (Model, Msg, init, subscriptions, update, view)

{-| A transport-neutral dispatch board, with a full stage and an empty destination.
-}

import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Ids as Ids exposing (Ids)
import Klar.Kanban as Kanban
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Time


type OrderId
    = OrderId Int


type Stage
    = Waiting
    | Picking
    | Dispatched


type alias Order =
    { id : OrderId, number : String, customer : String, summary : String }


type Mode
    = Data
    | Loading
    | Failure
    | Refreshing
    | Stale
    | Empty


orderIds : Ids OrderId
orderIds =
    Ids.make { toKey = \(OrderId value) -> String.fromInt value, fromKey = String.toInt >> Maybe.map OrderId }


stageIds : Ids Stage
stageIds =
    Ids.list
        (\stage ->
            case stage of
                Waiting ->
                    "waiting"

                Picking ->
                    "picking"

                Dispatched ->
                    "dispatched"
        )
        [ Waiting, Picking, Dispatched ]


type alias Model =
    { board : Kanban.State
    , columns : List (Kanban.Column Stage Order)
    , mode : Mode
    , issue : Maybe Kanban.Problem
    , lastMove : Maybe String
    , opened : Maybe OrderId
    }


type Msg
    = BoardMsg Kanban.Msg
    | Mode Mode
    | Reset
    | Retry
    | Open OrderId
    | NoOp


initialColumns : List (Kanban.Column Stage Order)
initialColumns =
    [ Kanban.column Waiting
        "Waiting"
        [ { id = OrderId 1042, number = "ORD-1042", customer = "Northline Tools", summary = "3 lines · Bergen" }
        , { id = OrderId 1043, number = "ORD-1043", customer = "Fjord Supply", summary = "12 lines · Oslo" }
        , { id = OrderId 1044, number = "ORD-1044", customer = "Harbour Workshop", summary = "2 lines · Trondheim" }
        ]
    , let
        col =
            Kanban.column Picking
                "Picking"
                [ { id = OrderId 1045, number = "ORD-1045", customer = "Coastal Goods", summary = "8 lines · Stavanger" } ]
      in
      Kanban.limit 1 |> Maybe.map (\maximum -> Kanban.withLimit maximum col) |> Maybe.withDefault col
    , Kanban.column Dispatched "Dispatched" []
    ]


init : ( Model, Cmd Msg )
init =
    ( { board = Kanban.init "dispatch-board", columns = initialColumns, mode = Data, issue = Nothing, lastMove = Nothing, opened = Nothing }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BoardMsg inner ->
            let
                ( board, cmd ) =
                    Kanban.update inner model.board
            in
            case ( model.mode, Kanban.move orderIds stageIds model.board board ) of
                ( Data, Just change ) ->
                    case Kanban.applyMove orderIds stageIds .id change model.columns of
                        Ok columns ->
                            ( { model | board = board, columns = columns, issue = Nothing, lastMove = Just ("Moved order " ++ Ids.toKey orderIds (Kanban.cardId change) ++ " to " ++ Ids.toKey stageIds (Kanban.target change) ++ ", position " ++ String.fromInt (Kanban.position change + 1)) }, Cmd.map BoardMsg cmd )

                        Err issue ->
                            ( { model | board = board, issue = Just issue }, Cmd.map BoardMsg cmd )

                _ ->
                    ( { model | board = board }, Cmd.map BoardMsg cmd )

        Mode mode ->
            ( { model | mode = mode }, Cmd.none )

        Reset ->
            init

        Retry ->
            ( { model | mode = Data }, Klar.focus "dispatch-board" NoOp )

        Open orderId ->
            ( { model | opened = Just orderId }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


remote : Model -> Remote (List (Kanban.Column Stage Order))
remote model =
    case model.mode of
        Data ->
            Remote.Loaded model.columns

        Loading ->
            Remote.Loading

        Failure ->
            Remote.Failed (Remote.problem Remote.network)

        Refreshing ->
            Remote.refresh (Remote.Loaded model.columns)

        Stale ->
            Remote.refreshWith (Remote.Loaded model.columns) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)

        Empty ->
            Remote.Loaded []


view : Settings -> Locale -> Model -> Html Msg
view settings locale model =
    Layout.stack [ Layout.gap 3 ]
        [ Text.paragraph "Move orders between stages without dragging. Picking is deliberately full; arrow navigation skips that stage, while the empty Dispatched stage is available. A move stays a proposal until you confirm it."
        , Layout.row [ Layout.wrap, Layout.gap 2 ]
            (List.map (\( title, mode ) -> Button.view [ Button.small, Button.pressed (model.mode == mode), Button.onClick (Mode mode) ] title)
                [ ( "Data", Data ), ( "Loading", Loading ), ( "Failure", Failure ), ( "Refreshing", Refreshing ), ( "Old data", Stale ), ( "No stages", Empty ) ]
                ++ [ Button.view [ Button.small, Button.onClick Reset ] "Reset board" ]
            )
        , Kanban.view BoardMsg
            [ Kanban.locale locale, Kanban.settings settings, Kanban.onRetry Retry, Kanban.onOpen Open ]
            { label = "Dispatch stages"
            , columns = remote model
            , columnIds = stageIds
            , cardIds = orderIds
            , cardId = .id
            , title = .number
            , content = \order -> Layout.stack [ Layout.gap 2 ] [ Text.text order.customer, Text.secondary order.summary, Badge.view [ Badge.tone Info ] "Order" ]
            }
            model.board
        , case model.issue of
            Just issue ->
                Alert.view [ Alert.tone Danger, Alert.polite ] (Kanban.problemText locale issue)

            Nothing ->
                case model.lastMove of
                    Just message ->
                        Alert.view [ Alert.tone Success, Alert.polite ] message

                    Nothing ->
                        Html.text ""
        , case model.opened of
            Just orderId ->
                Text.secondary ("Opened order " ++ Ids.toKey orderIds orderId ++ ". The card-title action is separate from moving.")

            Nothing ->
                Html.text ""
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
