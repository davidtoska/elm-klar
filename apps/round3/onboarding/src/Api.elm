module Api exposing
    ( Reply
    , categories
    , countries
    , createSupplier
    , loadSupplier
    , loadSuppliers
    , paymentTerms
    , patchSupplier
    , updateSupplier
    )

{-| The request layer: every function is a `Cmd` that answers after a delay, the way an HTTP
request would. The "server" is a `Db` that the model hands over and takes back in the reply;
a real application replaces this module with `Http`.
-}

import Backend exposing (Db, Failure, Named, Patch)
import Domain exposing (..)
import Process
import Task


type alias Reply a =
    { db : Db, result : Result Failure a }


after : Float -> a -> Task.Task x a
after ms value =
    Process.sleep ms |> Task.map (\_ -> value)


countries : (Result Failure (List (Named CountryId)) -> msg) -> Cmd msg
countries toMsg =
    after 400 (Ok Backend.countries) |> Task.perform toMsg


categories : (Result Failure (List (Named CategoryId)) -> msg) -> Cmd msg
categories toMsg =
    after 700 (Ok Backend.categories) |> Task.perform toMsg


paymentTerms : (Result Failure (List (Named PaymentTermsId)) -> msg) -> Cmd msg
paymentTerms toMsg =
    after 500 (Ok Backend.paymentTerms) |> Task.perform toMsg


loadSuppliers : Db -> (Result Failure (List Supplier) -> msg) -> Cmd msg
loadSuppliers db toMsg =
    after 500
        (if db.offline then
            Err Backend.Down

         else
            Ok db.suppliers
        )
        |> Task.perform toMsg


loadSupplier : Db -> SupplierId -> (Result Failure Supplier -> msg) -> Cmd msg
loadSupplier db id toMsg =
    after 500
        (if db.offline then
            Err Backend.Down

         else
            Backend.find id db |> Result.fromMaybe Backend.Gone
        )
        |> Task.perform toMsg


createSupplier : Db -> Profile -> List PriceRule -> (Reply Supplier -> msg) -> Cmd msg
createSupplier db profile priceRules toMsg =
    after 900 (Backend.create profile priceRules db)
        |> Task.map (\( newDb, result ) -> { db = newDb, result = result })
        |> Task.perform toMsg


updateSupplier : Db -> SupplierId -> Int -> Profile -> List PriceRule -> (Reply Supplier -> msg) -> Cmd msg
updateSupplier db id expected profile priceRules toMsg =
    after 900 (Backend.update id expected profile priceRules db)
        |> Task.map (\( newDb, result ) -> { db = newDb, result = result })
        |> Task.perform toMsg


patchSupplier : Db -> SupplierId -> Int -> Patch -> (Reply Supplier -> msg) -> Cmd msg
patchSupplier db id expected change toMsg =
    after 600 (Backend.patch id expected change db)
        |> Task.map (\( newDb, result ) -> { db = newDb, result = result })
        |> Task.perform toMsg
