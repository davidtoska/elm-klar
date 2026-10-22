module Api exposing
    ( Mode(..)
    , Net
    , addNote
    , assign
    , detail
    , init
    , lookup
    , modeLabel
    , orders
    , pack
    , saveViews
    , setStatus
    , share
    , undoPack
    )

{-| The layer between the application and the dummy backend: every call
returns a `Cmd` that answers after a delay, and sometimes with a failure. The
`Mode` is chosen from the top bar, so every state of the interface can be seen.
-}

import Backend.Db as Db exposing (Db)
import Domain exposing (..)
import Klar.Date exposing (Date)
import Klar.Remote as Remote exposing (Problem)
import Klar.SavedViews exposing (SavedView)
import Process
import Task
import Time


type Mode
    = Normal
    | Slow
    | Failing
    | Flaky
    | NoData


type alias Net =
    { mode : Mode
    , counter : Int
    }


init : Net
init =
    { mode = Normal, counter = 0 }


modeLabel : Mode -> String
modeLabel mode =
    case mode of
        Normal ->
            "Normal"

        Slow ->
            "Slow (3 s)"

        Failing ->
            "Every request fails"

        Flaky ->
            "Every second request fails"

        NoData ->
            "No orders"


{-| Sends the answer after a delay. The caller keeps `net` in its model and
counts one more request for each call.
-}
respond : Net -> Result Problem a -> (Result Problem a -> msg) -> Cmd msg
respond net computed toMsg =
    let
        delay =
            case net.mode of
                Slow ->
                    3000

                _ ->
                    300 + modBy 5 (net.counter * 7) * 90

        fails =
            case net.mode of
                Failing ->
                    True

                Flaky ->
                    modBy 2 net.counter == 0

                _ ->
                    False

        outcome =
            if fails then
                Err (failure net.counter)

            else
                computed
    in
    Process.sleep (toFloat delay)
        |> Task.perform (\_ -> toMsg outcome)


failure : Int -> Problem
failure counter =
    case modBy 3 counter of
        0 ->
            Remote.problem Remote.timeout

        1 ->
            Remote.problem Remote.network

        _ ->
            Remote.problem Remote.server |> Remote.withCode "503"


orders : Net -> Date -> Query -> Db -> (Result Problem { total : Int, rows : List OrderSummary } -> msg) -> Cmd msg
orders net today query db toMsg =
    let
        found =
            case net.mode of
                NoData ->
                    { total = 0, rows = [] }

                _ ->
                    Db.search today query db
    in
    respond net (Ok found) toMsg


lookup : Net -> String -> Db -> (Result Problem (List OrderSummary) -> msg) -> Cmd msg
lookup net text db toMsg =
    respond net (Ok (Db.lookup text db)) toMsg


detail : Net -> OrderId -> Db -> (Result Problem Detail -> msg) -> Cmd msg
detail net id db toMsg =
    let
        found =
            case id of
                OrderId n ->
                    Db.detail n db
                        |> Result.fromMaybe (Remote.problem Remote.notFound |> Remote.withTitle "Order not found")
    in
    respond net found toMsg


setStatus : Net -> Time.Posix -> OrderId -> Status -> Db -> (Result Problem Db -> msg) -> Cmd msg
setStatus net now id target db toMsg =
    respond net (Db.setStatus now id target db) toMsg


pack : Net -> Time.Posix -> List OrderId -> Db -> (Result Problem ( Db, { packed : List OrderId, skipped : Int } ) -> msg) -> Cmd msg
pack net now ids db toMsg =
    respond net (Ok (Db.pack now ids db)) toMsg


undoPack : Net -> Time.Posix -> List OrderId -> Db -> (Result Problem Db -> msg) -> Cmd msg
undoPack net now ids db toMsg =
    respond net (Ok (Db.undoPack now ids db)) toMsg


assign : Net -> Time.Posix -> String -> List OrderId -> Db -> (Result Problem Db -> msg) -> Cmd msg
assign net now person ids db toMsg =
    respond net (Ok (Db.assign now person ids db)) toMsg


addNote : Net -> Time.Posix -> OrderId -> String -> Db -> (Result Problem Db -> msg) -> Cmd msg
addNote net now id text db toMsg =
    respond net (Db.addNote now id text db) toMsg


saveViews : Net -> List SavedView -> Db -> (Result Problem Db -> msg) -> Cmd msg
saveViews net views db toMsg =
    respond net (Ok (Db.setViews views db)) toMsg


share : Net -> String -> Db -> (Result Problem Db -> msg) -> Cmd msg
share net name db toMsg =
    respond net (Ok (Db.setShared name db)) toMsg
