module Api exposing (Net, movements, overview, transfers, tree)

{-| The layer between the page and the dummy backend: every call returns a `Cmd`
that answers after a delay, and can fail. The page cannot tell this from HTTP, and
it never calls `Backend.Query` directly.
-}

import Array exposing (Array)
import Backend.Db exposing (Db)
import Backend.Query as Query
import Domain exposing (MovementRow, Overview, Period, Scope, Transfer, TreeRegion)
import Klar.Remote as Remote exposing (Problem)
import Process
import Task


{-| The "developer tools" of the dummy network.
-}
type alias Net =
    { slow : Bool, failing : Bool }


request : Int -> Net -> (Result Problem a -> msg) -> (() -> a) -> Cmd msg
request baseMs net toMsg compute =
    Process.sleep
        (toFloat
            (if net.slow then
                baseMs * 6

             else
                baseMs
            )
        )
        |> Task.map
            (\_ ->
                if net.failing then
                    Err (Remote.problem Remote.server |> Remote.withCode "503")

                else
                    Ok (compute ())
            )
        |> Task.perform toMsg


tree : Net -> Db -> (Result Problem (List TreeRegion) -> msg) -> Cmd msg
tree net db toMsg =
    request 300 net toMsg (\() -> Query.tree db)


overview : Net -> Db -> Scope -> Period -> (Result Problem Overview -> msg) -> Cmd msg
overview net db scope period toMsg =
    request 600 net toMsg (\() -> Query.overview db scope period)


transfers : Net -> Db -> Scope -> (Result Problem (List Transfer) -> msg) -> Cmd msg
transfers net db scope toMsg =
    request 450 net toMsg (\() -> Query.transfers db scope)


movements : Net -> Db -> Scope -> (Result Problem (Array MovementRow) -> msg) -> Cmd msg
movements net db scope toMsg =
    request 800 net toMsg (\() -> Query.movementRows db scope)
