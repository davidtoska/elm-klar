module Api exposing (loadLookups, loadSuppliers, save)

{-| The request/response layer: every call is a Cmd that answers after a delay.
-}

import Backend exposing (Behaviour, Db, SaveRequest)
import Domain exposing (Lookups, SaveError, Supplier)
import Klar.Remote as Remote
import Process
import Task


after : Int -> a -> Cmd a
after ms value =
    Process.sleep (toFloat ms) |> Task.perform (\_ -> value)


loadLookups : (Result Remote.Problem Lookups -> msg) -> Cmd msg
loadLookups toMsg =
    after 500 (toMsg (Ok Backend.lookups))


loadSuppliers : Db -> (Result Remote.Problem (List Supplier) -> msg) -> Cmd msg
loadSuppliers db toMsg =
    after 400 (toMsg (Ok db.suppliers))


{-| The answer carries the new database; the caller keeps it.
-}
save : Behaviour -> Db -> SaveRequest -> (Db -> Result SaveError Supplier -> msg) -> Cmd msg
save behaviour db request toMsg =
    let
        ( db2, result ) =
            Backend.save behaviour db request
    in
    after 900 (toMsg db2 result)
