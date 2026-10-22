module Backend.Api exposing
    ( Mode(..)
    , Response
    , categories
    , levels
    , movements
    , regions
    , summary
    , transfers
    )

{-| The request layer in front of the dummy database: every function returns a `Cmd` that
answers after a simulated delay, and fails when the backend is switched to `Failing`.
-}

import Array exposing (Array)
import Backend.Data as Data
import Klar.Remote as Remote
import Process
import Task
import Time


type Mode
    = Healthy
    | Failing


type alias Response a =
    { at : Time.Posix
    , result : Result Remote.Problem a
    }


respond : Mode -> Float -> Remote.Kind -> (Response a -> msg) -> (() -> a) -> Cmd msg
respond mode delay kind toMsg compute =
    Process.sleep delay
        |> Task.andThen (\_ -> Time.now)
        |> Task.map
            (\now ->
                { at = now
                , result =
                    case mode of
                        Healthy ->
                            Ok (compute ())

                        Failing ->
                            Err (Remote.problem kind)
                }
            )
        |> Task.perform toMsg


regions : Mode -> (Response (List Data.Region) -> msg) -> Cmd msg
regions mode toMsg =
    respond mode 350 Remote.network toMsg (\_ -> Data.regions)


summary : Mode -> Data.Query -> (Response Data.Summary -> msg) -> Cmd msg
summary mode query toMsg =
    respond mode 700 Remote.server toMsg (\_ -> Data.summary query)


levels : Mode -> Data.Query -> (Response Data.Levels -> msg) -> Cmd msg
levels mode query toMsg =
    respond mode 900 Remote.timeout toMsg (\_ -> Data.levels query)


categories : Mode -> Data.Query -> (Response (List Data.Category) -> msg) -> Cmd msg
categories mode query toMsg =
    respond mode 500 Remote.server toMsg (\_ -> Data.categories query)


transfers : Mode -> Data.Query -> Int -> (Response { items : List Data.TransferOrder, hasMore : Bool } -> msg) -> Cmd msg
transfers mode query limit toMsg =
    respond mode 600 Remote.network toMsg (\_ -> Data.transfersIn query limit)


{-| The whole movement table, as the one big list the client works on.
-}
movements : Mode -> (Response (Array Data.Movement) -> msg) -> Cmd msg
movements mode toMsg =
    respond mode 1400 Remote.server toMsg (\_ -> Data.movements)
