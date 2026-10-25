module Api.Workflows exposing (send)

{-| Simulated request transport. Handling happens on arrival, so pause/cancel can
invalidate an in-flight worker before it writes server state.
-}

import Backend.WorkflowServer as Server exposing (Request, Server)
import Process
import Task


send : (Request -> msg) -> Request -> Server -> Cmd msg
send received request server =
    Process.sleep (Server.delay request server) |> Task.perform (always (received request))
