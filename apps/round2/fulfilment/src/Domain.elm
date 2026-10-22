module Domain exposing
    ( Detail
    , Event
    , Line
    , Note
    , OrderSummary
    , OrderId(..)
    , Query
    , Status(..)
    , allStatuses
    , currentUser
    , fields
    , isIrreversible
    , nextSteps
    , orderIdToString
    , orderRows
    , people
    , statusKey
    , statusLabel
    , statusTone
    )

import Klar.Date exposing (Date)
import Klar.Rule as Rule
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Time


type OrderId
    = OrderId Int


orderIdToString : OrderId -> String
orderIdToString (OrderId n) =
    "ORD-" ++ String.fromInt n


orderRows : Table.RowIds OrderId
orderRows =
    Table.rowIds
        { toKey = \(OrderId n) -> String.fromInt n
        , fromKey = \key -> String.toInt key |> Maybe.map OrderId
        }


type Status
    = New
    | Confirmed
    | Picking
    | Packed
    | Shipped
    | Delivered
    | Cancelled


allStatuses : List Status
allStatuses =
    [ New, Confirmed, Picking, Packed, Shipped, Delivered, Cancelled ]


statusKey : Status -> String
statusKey status =
    case status of
        New ->
            "new"

        Confirmed ->
            "confirmed"

        Picking ->
            "picking"

        Packed ->
            "packed"

        Shipped ->
            "shipped"

        Delivered ->
            "delivered"

        Cancelled ->
            "cancelled"


statusLabel : Status -> String
statusLabel status =
    case status of
        New ->
            "New"

        Confirmed ->
            "Confirmed"

        Picking ->
            "Picking"

        Packed ->
            "Packed"

        Shipped ->
            "Shipped"

        Delivered ->
            "Delivered"

        Cancelled ->
            "Cancelled"


statusTone : Status -> Tone
statusTone status =
    case status of
        New ->
            Info

        Confirmed ->
            Primary

        Picking ->
            Warning

        Packed ->
            Primary

        Shipped ->
            Success

        Delivered ->
            Success

        Cancelled ->
            Danger


{-| The steps an order may take from a status.
-}
nextSteps : Status -> List Status
nextSteps status =
    case status of
        New ->
            [ Confirmed, Cancelled ]

        Confirmed ->
            [ Picking, Cancelled ]

        Picking ->
            [ Packed, Cancelled ]

        Packed ->
            [ Shipped, Picking ]

        Shipped ->
            [ Delivered ]

        Delivered ->
            []

        Cancelled ->
            []


{-| Moving to these statuses cannot be taken back.
-}
isIrreversible : Status -> Bool
isIrreversible target =
    List.member target [ Shipped, Delivered, Cancelled ]


type alias OrderSummary =
    { id : OrderId
    , customer : String
    , status : Status
    , created : Date
    , due : Date
    , total : Float
    , items : Int
    , assignee : Maybe String
    , late : Bool
    }


type alias Line =
    { sku : String
    , product : String
    , quantity : Int
    , unitPrice : Float
    }


type alias Event =
    { id : String
    , at : Time.Posix
    , title : String
    , by : String
    , tone : Tone
    }


type alias Note =
    { at : Time.Posix
    , by : String
    , text : String
    }


type alias Detail =
    { order : OrderSummary
    , email : String
    , shipTo : String
    , lines : List Line
    , history : List Event
    , notes : List Note
    }


{-| What the user asked of the server for the inbox.
-}
type alias Query =
    { search : String
    , sort : List ( String, Table.Direction )
    , page : Int
    , pageSize : Int
    , rule : Rule.Rule
    }


people : List String
people =
    [ "Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra" ]


currentUser : String
currentUser =
    "Ada Lovelace"


fields : List (Rule.Field OrderSummary)
fields =
    [ Rule.choiceField "status"
        "Status"
        (List.map (\s -> { value = statusKey s, label = statusLabel s }) allStatuses)
        (.status >> statusKey)
    , Rule.textField "customer" "Customer" .customer
    , Rule.dateField "created" "Created" (.created >> Just)
    , Rule.dateField "due" "Due" (.due >> Just)
    , Rule.numberField "total" "Total" (.total >> Just)
    , Rule.choiceField "assignee"
        "Assignee"
        (List.map (\p -> { value = p, label = p }) people)
        (.assignee >> Maybe.withDefault "")
    , Rule.boolField "late" "Late" .late
    ]
