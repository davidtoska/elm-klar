module Api exposing (Next(..), Sim, call, initialSim)

{-| The request/response layer in front of the `Backend`: a Cmd that answers after
a delay, or with a failure of the pretend network. The backend functions themselves
run when the answer arrives (see `Main`).
-}

import Klar.Remote as Remote
import Process
import Task


type Next
    = Works
    | NetworkDown
    | TimesOut
    | ServerFails


type alias Sim =
    { next : Next
    , delayMs : Float
    }


initialSim : Sim
initialSim =
    { next = Works, delayMs = 700 }


call : Sim -> (Result Remote.Problem () -> msg) -> Cmd msg
call sim toMsg =
    let
        result =
            case sim.next of
                Works ->
                    Ok ()

                NetworkDown ->
                    Err (Remote.problem Remote.network)

                TimesOut ->
                    Err (Remote.problem Remote.timeout)

                ServerFails ->
                    Err (Remote.problem Remote.server |> Remote.withCode "503")
    in
    Process.sleep sim.delayMs
        |> Task.perform (\_ -> toMsg result)
