module Event exposing (encode)

{-| The raw event of a movement, as the warehouse system would have sent it.
-}

import Domain exposing (MovementRow, categoryName, kindKey)
import Json.Encode as Encode
import Klar.Date as Date
import Klar.Format as Format
import Time


encode : MovementRow -> Encode.Value
encode row =
    Encode.object
        [ ( "id", Encode.string row.reference )
        , ( "type", Encode.string ("stock." ++ kindKey row.kind) )
        , ( "occurred_at", Encode.string (iso row.at) )
        , ( "quantity", Encode.int row.quantity )
        , ( "sku"
          , Encode.object
                [ ( "code", Encode.string row.skuCode )
                , ( "name", Encode.string row.skuName )
                , ( "category", Encode.string (categoryName row.category) )
                ]
          )
        , ( "location"
          , Encode.object
                [ ( "region", Encode.string row.region )
                , ( "warehouse", Encode.string row.warehouse )
                , ( "zone", Encode.string row.zone )
                ]
          )
        , ( "actor", Encode.string row.actor )
        , ( "meta"
          , Encode.object
                [ ( "source", Encode.string "scanner" )
                , ( "batch", Encode.int (modBy 97 row.id) )
                , ( "corrected", Encode.bool (row.kind == Domain.Adjustment) )
                , ( "note", Encode.null )
                ]
          )
        ]


iso : Time.Posix -> String
iso at =
    Date.toIso (Date.fromPosix Time.utc at) ++ "T" ++ Format.time Time.utc at ++ ":00Z"
