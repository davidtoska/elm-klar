module View.Ids exposing (orderRows)

{-| How the ids of the showcase are written for the tables. A table keeps its
selection and its open rows as text inside its `State`; the `Klar.Ids` of an id type
tell it how, so the pages work with `OrderId` and never with the text.
-}

import Api.Types as Types exposing (OrderId)
import Klar.Ids as Ids exposing (Ids)
import Klar.Table as Table


orderRows : Ids OrderId
orderRows =
    Ids.make { toKey = Types.orderIdText, fromKey = Types.orderId >> Just }
