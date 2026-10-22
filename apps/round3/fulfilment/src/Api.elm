module Api exposing
    ( Kind(..)
    , Sim
    , arm
    , fromNames
    , initialSim
    , isArmed
    , read
    , toggleSlow
    , write
    )

{-| The request/response layer: runs a `Backend` function now, delivers the answer later as a
`Cmd`, and can make any kind of request fail once (`arm`) or slow (`toggleSlow`), so that the
failure and loading states can be seen and tested. A real application would replace this
module with `Http`.
-}

import Backend exposing (Db)
import Klar.Remote as Remote
import Process
import Task
import Time


type Kind
    = ListRequest
    | DetailRequest
    | SaveRequest
    | BulkRequest
    | PaletteRequest
    | ViewsRequest


type alias Sim =
    { slow : Bool
    , armed : List Kind
    }


initialSim : Sim
initialSim =
    { slow = False, armed = [] }


toggleSlow : Sim -> Sim
toggleSlow sim =
    { sim | slow = not sim.slow }


arm : Kind -> Sim -> Sim
arm kind sim =
    if List.member kind sim.armed then
        { sim | armed = List.filter ((/=) kind) sim.armed }

    else
        { sim | armed = kind :: sim.armed }


isArmed : Kind -> Sim -> Bool
isArmed kind sim =
    List.member kind sim.armed


{-| Takes the armed failure of this kind, if there is one.
-}
take : Kind -> Sim -> ( Sim, Bool )
take kind sim =
    if List.member kind sim.armed then
        ( { sim | armed = List.filter ((/=) kind) sim.armed }, True )

    else
        ( sim, False )


injected : Remote.Problem
injected =
    Remote.problem Remote.network
        |> Remote.withDetail "The connection was lost (simulated failure)."


delay : Sim -> Kind -> Float
delay sim kind =
    let
        base =
            case kind of
                PaletteRequest ->
                    250

                DetailRequest ->
                    500

                _ ->
                    600
    in
    if sim.slow then
        base + 3000

    else
        base


deliver : Sim -> Kind -> (Result Remote.Problem a -> Time.Posix -> msg) -> Result Remote.Problem a -> Cmd msg
deliver sim kind toMsg result =
    Process.sleep (delay sim kind)
        |> Task.andThen (\_ -> Time.now)
        |> Task.perform (toMsg result)


{-| A request that only reads.
-}
read :
    Kind
    -> Sim
    -> Db
    -> (Db -> Result Remote.Problem a)
    -> (Result Remote.Problem a -> Time.Posix -> msg)
    -> ( Sim, Cmd msg )
read kind sim db run toMsg =
    let
        ( next, fails ) =
            take kind sim
    in
    ( next
    , deliver sim
        kind
        toMsg
        (if fails then
            Err injected

         else
            run db
        )
    )


{-| A request that changes the database. The server does the work at once and the answer is
slow; a request that fails changes nothing.
-}
write :
    Kind
    -> Sim
    -> Db
    -> (Db -> ( Db, Result Remote.Problem a ))
    -> (Result Remote.Problem a -> Time.Posix -> msg)
    -> ( Sim, Db, Cmd msg )
write kind sim db run toMsg =
    let
        ( next, fails ) =
            take kind sim
    in
    if fails then
        ( next, db, deliver sim kind toMsg (Err injected) )

    else
        let
            ( changed, result ) =
                run db
        in
        ( next, changed, deliver sim kind toMsg result )


{-| `list`, `detail`, `save`, `bulk`, `palette`, `views` arm a failure; `slow` slows everything down.
-}
fromNames : List String -> Sim
fromNames names =
    { slow = List.member "slow" names
    , armed =
        List.filterMap
            (\name ->
                case name of
                    "list" ->
                        Just ListRequest

                    "detail" ->
                        Just DetailRequest

                    "save" ->
                        Just SaveRequest

                    "bulk" ->
                        Just BulkRequest

                    "palette" ->
                        Just PaletteRequest

                    "views" ->
                        Just ViewsRequest

                    _ ->
                        Nothing
            )
            names
    }
