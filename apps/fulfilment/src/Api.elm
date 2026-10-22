module Api exposing
    ( Net
    , addNote
    , assign
    , changeStatus
    , getOrder
    , normal
    , pack
    , saveViews
    , search
    )

{-| The request and response layer in front of `Backend`: every call is a `Cmd`
that answers later, slowly or not at all, depending on the simulated network.

A write is checked against the database when it is sent, and applied to the
database as it is when the answer arrives (like a server that owns the data), so
the answer is a function of the database.

-}

import Backend exposing (Db, Packing, Page, Request, Target)
import Domain exposing (Detail, OrderId, PersonId, Status)
import Klar.Remote as Remote exposing (Problem)
import Klar.SavedViews exposing (SavedView)
import Process
import Task


type alias Net =
    { slow : Bool
    , readsFail : Bool
    , savesFail : Bool
    }


normal : Net
normal =
    { slow = False, readsFail = False, savesFail = False }


delay : Net -> Float
delay net =
    if net.slow then
        3000

    else
        450


answer : Net -> Result Problem a -> (Result Problem a -> msg) -> Cmd msg
answer net result toMsg =
    Process.sleep (delay net)
        |> Task.perform (\_ -> toMsg result)


read : Net -> Result Problem a -> (Result Problem a -> msg) -> Cmd msg
read net result toMsg =
    if net.readsFail then
        answer net (Err (Remote.problem Remote.network)) toMsg

    else
        answer net result toMsg


write : Net -> Result Problem a -> (Result Problem a -> msg) -> Cmd msg
write net result toMsg =
    if net.savesFail then
        answer net (Err (Remote.problem Remote.server |> Remote.withCode "503")) toMsg

    else
        answer net result toMsg


rejected : String -> Problem
rejected reason =
    Remote.problem Remote.conflict
        |> Remote.withTitle "The change was refused"
        |> Remote.withDetail reason


search : Net -> Db -> Request -> (Result Problem Page -> msg) -> Cmd msg
search net db request toMsg =
    read net (Ok (Backend.search db request)) toMsg


getOrder : Net -> Db -> OrderId -> (Result Problem Detail -> msg) -> Cmd msg
getOrder net db id toMsg =
    read net
        (Backend.get db id
            |> Result.fromMaybe (Remote.problem Remote.notFound |> Remote.withTitle "Order not found")
        )
        toMsg


changeStatus : Net -> Db -> OrderId -> Status -> (Result Problem (Db -> Db) -> msg) -> Cmd msg
changeStatus net db id status toMsg =
    write net
        (Backend.changeStatus db id status
            |> Result.map (\_ current -> Backend.changeStatus current id status |> Result.withDefault current)
            |> Result.mapError rejected
        )
        toMsg


assign : Net -> Target -> PersonId -> (Result Problem (Db -> Db) -> msg) -> Cmd msg
assign net target person toMsg =
    write net (Ok (\current -> Backend.assign current target person)) toMsg


pack : Net -> Target -> (Result Problem (Db -> ( Db, Packing )) -> msg) -> Cmd msg
pack net target toMsg =
    write net (Ok (\current -> Backend.pack current target)) toMsg


addNote : Net -> Db -> OrderId -> String -> (Result Problem (Db -> Db) -> msg) -> Cmd msg
addNote net db id text toMsg =
    write net
        (Backend.addNote db id text
            |> Result.map (\_ current -> Backend.addNote current id text |> Result.withDefault current)
            |> Result.mapError rejected
        )
        toMsg


saveViews : Net -> List SavedView -> (Result Problem (Db -> Db) -> msg) -> Cmd msg
saveViews net views toMsg =
    write net (Ok (\current -> Backend.setViews current views)) toMsg
