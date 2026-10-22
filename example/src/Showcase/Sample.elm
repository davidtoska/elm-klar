module Showcase.Sample exposing
    ( categoryPaths
    , cities
    , countries
    , countryName
    , customers
    , now
    , orderById
    , orders
    , ownerName
    , owners
    , products
    , today
    , warehouseName
    , warehouses
    )

{-| Sample data for the component gallery: thousands of orders and products, the
same on every load. It comes from the generator of the dummy backend, so the
gallery and the real pages show the same kind of data.

Only the gallery uses this module. The real pages talk to `Api`.

-}

import Api.Types exposing (Country, CountryCode, Order, OrderId, OwnerId, Product, Warehouse, WarehouseId, orderIdText)
import Backend.Generate as Generate
import Dict exposing (Dict)
import Klar.Date exposing (Date)
import Time


{-| The gallery pretends it is this day, so relative dates stay stable.
-}
today : Date
today =
    Generate.today


now : Time.Posix
now =
    Generate.now


{-| 3 000 orders. Computed once.
-}
orders : List Order
orders =
    Generate.orders 3000


orderIndex : Dict String Order
orderIndex =
    orders |> List.map (\o -> ( orderIdText o.id, o )) |> Dict.fromList


orderById : OrderId -> Maybe Order
orderById id =
    Dict.get (orderIdText id) orderIndex


{-| 420 company names, all different: for selects that must stay fast with many
options.
-}
customers : List String
customers =
    Generate.customers


countries : List Country
countries =
    Generate.countries


cities : List String
cities =
    Generate.cities


{-| The names of the owners. An order holds an `OwnerId`; `ownerName` turns it into
this name.
-}
owners : List String
owners =
    List.map .name Generate.owners


ownerName : OwnerId -> String
ownerName id =
    Api.Types.ownerName Generate.owners id


countryName : CountryCode -> String
countryName code =
    Api.Types.countryName countries code


warehouseName : WarehouseId -> String
warehouseName id =
    Api.Types.warehouseName warehouses id


warehouses : List Warehouse
warehouses =
    Generate.warehouses


{-| 1 500 products.
-}
products : List Product
products =
    Generate.products 1500


{-| The distinct category paths of the products, such as
`[ "Hardware", "Fasteners", "Bolts" ]`, in alphabetical order: a three-level
hierarchy for tree views.
-}
categoryPaths : List (List String)
categoryPaths =
    products
        |> List.map .category
        |> List.map (\path -> ( String.join "/" path, path ))
        |> Dict.fromList
        |> Dict.values
        |> List.sortBy (String.join "/")
