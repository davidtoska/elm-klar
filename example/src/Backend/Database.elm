module Backend.Database exposing (Database, seed, seedLarge)

{-| The in-memory database of the dummy server: just lists, replaced as a whole
by every change.
-}

import Api.Types exposing (Order, Product)
import Backend.Generate as Generate


type alias Database =
    { orders : List Order
    , products : List Product
    , nextNumber : Int
    }


fromCount : Int -> Database
fromCount count =
    { orders = Generate.orders count
    , products = Generate.products 1500
    , nextNumber = 10000 + count + 1
    }


{-| 88 orders: a few pages, so paging and filtering can be tried at once.
-}
seed : Database
seed =
    fromCount 88


{-| 2 500 orders, for seeing how the tables and charts cope with a real load.
-}
seedLarge : Database
seedLarge =
    fromCount 2500
