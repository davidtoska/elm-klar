module Api exposing
    ( Env
    , Panel(..)
    , call
    )

{-| The request layer: every call answers after a pause, with the data or with a problem.

A call is a `Cmd`, as an `Http` request would be. While `outage` is on every call fails, so loading,
failure with retry and old data after a failed refresh are real states of the application. Replacing
this module by `Http` changes nothing else.

-}

import Klar.Remote as Remote
import Process
import Task
import Time


type alias Env =
    { outage : Bool }


type Panel
    = StructurePanel
    | FiguresPanel
    | LevelsPanel
    | CategoriesPanel
    | TransfersPanel
    | MovementsPanel


delay : Panel -> Float
delay panel =
    case panel of
        StructurePanel ->
            500

        FiguresPanel ->
            450

        LevelsPanel ->
            900

        CategoriesPanel ->
            700

        TransfersPanel ->
            1100

        MovementsPanel ->
            1400


{-| Send a call. `compute` runs when the pause is over, as a server would.
-}
call : Env -> Panel -> (() -> a) -> (Result Remote.Problem a -> Time.Posix -> msg) -> Cmd msg
call env panel compute toMsg =
    Process.sleep (delay panel)
        |> Task.andThen (\_ -> Time.now)
        |> Task.map
            (\at ->
                if env.outage then
                    ( Err (Remote.problem Remote.server |> Remote.withCode "503"), at )

                else
                    ( Ok (compute ()), at )
            )
        |> Task.perform (\( result, at ) -> toMsg result at)
