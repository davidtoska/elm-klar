module Api exposing
    ( Backend
    , Dataset(..)
    , Latency(..)
    , Mode(..)
    , Simulation
    , changeStatus
    , createOrder
    , deleteOrder
    , getOrder
    , init
    , listOrders
    , listProducts
    , lookups
    , requestCount
    , setDataset
    , setLatency
    , setMode
    , simulation
    , summary
    , updateOrder
    )

{-| The only module the pages talk to.

Every call is a request/response exchange, like HTTP: it returns a `Cmd` that
delivers a `Result ApiError a` after a delay, and `Err` when the (simulated)
network or server misbehaves. Pages therefore have to deal with loading, failure
and retry for real.

Behind the transport the server is still the synchronous fake in
`Backend.Server`. `Backend` is opaque and carries the in-memory database plus the
simulation settings (latency, failure mode, data volume), so the showcase can
switch the "network" off and show what the interface does. When a real server
exists, this module becomes the HTTP client; the functions keep their shape.

    Api.listOrders query OrdersLoaded backend
        |> Tuple.mapFirst (\b -> { model | backend = b })

-}

import Api.Types exposing (ApiError(..), Lookups, Order, OrderId, OrderInput, OrderQuery, OrderStatus, Page, Product, Summary)
import Backend.Database as Database exposing (Database)
import Backend.Server as Server
import Process
import Task


type Backend
    = Backend State


type alias State =
    { db : Database
    , sim : Simulation
    , requests : Int
    }



-- SIMULATION


{-| How the pretend network behaves.
-}
type alias Simulation =
    { mode : Mode
    , latency : Latency
    , dataset : Dataset
    }


type Mode
    = Normal
    | Offline
    | ServerDown
    | Timeouts
    | Flaky


type Latency
    = Fast
    | Typical
    | Slow


type Dataset
    = Small
    | Large


init : Backend
init =
    Backend
        { db = Database.seed
        , sim = { mode = Normal, latency = Typical, dataset = Small }
        , requests = 0
        }


simulation : Backend -> Simulation
simulation (Backend state) =
    state.sim


requestCount : Backend -> Int
requestCount (Backend state) =
    state.requests


setMode : Mode -> Backend -> Backend
setMode mode (Backend state) =
    let
        sim =
            state.sim
    in
    Backend { state | sim = { sim | mode = mode } }


setLatency : Latency -> Backend -> Backend
setLatency latency (Backend state) =
    let
        sim =
            state.sim
    in
    Backend { state | sim = { sim | latency = latency } }


{-| Switching the data volume replaces the database (edits are lost).
-}
setDataset : Dataset -> Backend -> Backend
setDataset dataset (Backend state) =
    let
        sim =
            state.sim
    in
    Backend
        { state
            | sim = { sim | dataset = dataset }
            , db =
                case dataset of
                    Small ->
                        Database.seed

                    Large ->
                        Database.seedLarge
        }


{-| Which error, if any, request number `n` gets in this mode.
-}
failureFor : Mode -> Int -> Maybe ApiError
failureFor mode n =
    case mode of
        Normal ->
            Nothing

        Offline ->
            Just NetworkDown

        ServerDown ->
            Just (ServerFailed 503)

        Timeouts ->
            Just TimedOut

        Flaky ->
            if modBy 3 n == 0 then
                Just
                    (if modBy 2 (n // 3) == 0 then
                        ServerFailed 500

                     else
                        NetworkDown
                    )

            else
                Nothing


delayFor : Simulation -> Int -> Maybe ApiError -> Float
delayFor sim n failure =
    let
        base =
            case sim.latency of
                Fast ->
                    120

                Typical ->
                    450

                Slow ->
                    2600

        jitter =
            modBy 5 n * 35
    in
    case failure of
        Just TimedOut ->
            toFloat (3500 + jitter)

        Just NetworkDown ->
            toFloat (200 + jitter)

        _ ->
            toFloat (base + jitter)


{-| The transport: run the server function now, deliver its result later. A
failed request never reaches the server, so it changes nothing.
-}
send : (Database -> ( Database, Result ApiError a )) -> (Result ApiError a -> msg) -> Backend -> ( Backend, Cmd msg )
send run toMsg (Backend state) =
    let
        n =
            state.requests + 1

        failure =
            failureFor state.sim.mode n

        ( db, result ) =
            case failure of
                Just error ->
                    ( state.db, Err error )

                Nothing ->
                    run state.db
    in
    ( Backend { state | db = db, requests = n }
    , Process.sleep (delayFor state.sim n failure)
        |> Task.perform (\_ -> toMsg result)
    )


fetch : (Database -> a) -> (Result ApiError a -> msg) -> Backend -> ( Backend, Cmd msg )
fetch read =
    send (\db -> ( db, Ok (read db) ))



-- OVERVIEW


{-| Everything the overview page shows.
-}
summary : (Result ApiError Summary -> msg) -> Backend -> ( Backend, Cmd msg )
summary =
    fetch Server.summary



-- ORDERS


{-| One page of orders, searched, filtered and sorted on the server.
-}
listOrders : OrderQuery -> (Result ApiError (Page Order) -> msg) -> Backend -> ( Backend, Cmd msg )
listOrders query =
    fetch (Server.queryOrders query)


{-| One order by id (`NotFound` if it does not exist).
-}
getOrder : OrderId -> (Result ApiError Order -> msg) -> Backend -> ( Backend, Cmd msg )
getOrder id =
    send (\db -> ( db, Server.findOrder id db ))


createOrder : OrderInput -> (Result ApiError Order -> msg) -> Backend -> ( Backend, Cmd msg )
createOrder input =
    send (Server.createOrder input)


updateOrder : OrderId -> OrderInput -> (Result ApiError Order -> msg) -> Backend -> ( Backend, Cmd msg )
updateOrder id input =
    send (Server.updateOrder id input)


changeStatus : OrderId -> OrderStatus -> (Result ApiError Order -> msg) -> Backend -> ( Backend, Cmd msg )
changeStatus id status =
    send (Server.changeStatus id status)


deleteOrder : OrderId -> (Result ApiError () -> msg) -> Backend -> ( Backend, Cmd msg )
deleteOrder id =
    send (Server.deleteOrder id)


{-| The reference data the order form points at: countries, warehouses, owners.
-}
lookups : (Result ApiError Lookups -> msg) -> Backend -> ( Backend, Cmd msg )
lookups =
    fetch Server.lookups



-- PRODUCTS


{-| Every product (the products table filters and sorts them itself).
-}
listProducts : (Result ApiError (List Product) -> msg) -> Backend -> ( Backend, Cmd msg )
listProducts =
    fetch Server.listProducts
