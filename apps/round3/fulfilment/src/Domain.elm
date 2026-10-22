module Domain exposing
    ( Detail
    , HistoryEntry
    , Line
    , Note
    , OrderId(..)
    , Page
    , Request
    , Status(..)
    , Summary
    , allStatuses
    , assignees
    , currentUser
    , fields
    , nextSteps
    , orderIds
    , orderNumber
    , statusKey
    , statusLabel
    , statusTone
    , undoable
    )

{-| The vocabulary of the Fulfilment desk: orders, their lines, history and notes, the status
steps that are allowed, and the fields a saved view can talk about.
-}

import Klar.Date exposing (Date)
import Klar.Rule as Rule
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Time


type OrderId
    = OrderId Int


orderIds : Table.RowIds OrderId
orderIds =
    Table.rowIds
        { toKey = \(OrderId n) -> String.fromInt n
        , fromKey = \key -> String.toInt key |> Maybe.map OrderId
        }


orderNumber : OrderId -> String
orderNumber (OrderId n) =
    "SO-" ++ String.fromInt (1000 + n)


type Status
    = Received
    | Picking
    | Packed
    | Shipped
    | Delivered
    | Cancelled


allStatuses : List Status
allStatuses =
    [ Received, Picking, Packed, Shipped, Delivered, Cancelled ]


statusLabel : Status -> String
statusLabel status =
    case status of
        Received ->
            "Received"

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
        Received ->
            Neutral

        Picking ->
            Info

        Packed ->
            Primary

        Shipped ->
            Warning

        Delivered ->
            Success

        Cancelled ->
            Danger


{-| The steps an order may take from a status. Anything else is refused by the backend too.
-}
nextSteps : Status -> List Status
nextSteps status =
    case status of
        Received ->
            [ Picking, Cancelled ]

        Picking ->
            [ Packed, Received, Cancelled ]

        Packed ->
            [ Shipped, Picking, Cancelled ]

        Shipped ->
            [ Delivered ]

        Delivered ->
            []

        Cancelled ->
            []


{-| A step that can be taken back with one more step is quick; the others ask first.
-}
undoable : Status -> Status -> Bool
undoable from to =
    List.member from (nextSteps to) && List.member to [ Received, Picking, Packed ]


currentUser : String
currentUser =
    "Ingrid Moe"


assignees : List String
assignees =
    [ "Ingrid Moe", "Tor Berg", "Maja Lund", "Jonas Vik", "Sara Dahl" ]


type alias Summary =
    { id : OrderId
    , number : String
    , customer : String
    , status : Status
    , created : Date
    , due : Date
    , totalMinor : Int
    , assignee : Maybe String
    }


type alias Line =
    { sku : String
    , name : String
    , quantity : Int
    , unitMinor : Int
    }


type alias HistoryEntry =
    { id : String
    , at : Time.Posix
    , by : String
    , text : String
    , tone : Tone
    }


type alias Note =
    { id : Int
    , at : Time.Posix
    , by : String
    , text : String
    }


type alias Detail =
    { summary : Summary
    , lines : List Line
    , history : List HistoryEntry
    , notes : List Note
    }


{-| What the server needs to answer a list: the table's query and the rule.
-}
type alias Request =
    { query : Table.Query
    , rule : Rule.Rule
    }


type alias Page =
    { rows : List Summary
    , total : Int
    }


{-| What a rule (a filter chip or a saved view) can talk about.
-}
fields : List (Rule.Field Summary)
fields =
    [ Rule.choiceField "status"
        "Status"
        (List.map (\s -> { value = statusKey s, label = statusLabel s }) allStatuses)
        (.status >> statusKey)
    , Rule.textField "customer" "Customer" .customer
    , Rule.textField "number" "Order number" .number
    , Rule.choiceField "assignee"
        "Assigned to"
        (List.map (\name -> { value = name, label = name }) assignees)
        (.assignee >> Maybe.withDefault "")
    , Rule.dateField "created" "Created" (.created >> Just)
    , Rule.dateField "due" "Due" (.due >> Just)
    , Rule.numberField "total" "Total" (\o -> Just (toFloat o.totalMinor / 100))
    ]


statusKey : Status -> String
statusKey status =
    String.toLower (statusLabel status)
