module Domain exposing
    ( Detail
    , HistoryEntry
    , Line
    , Note
    , OrderId(..)
    , Person
    , PersonId(..)
    , Status(..)
    , Summary
    , allStatuses
    , allowedNext
    , assigneeName
    , cannotBeUndone
    , fields
    , isLate
    , me
    , orderIdFromString
    , orderIdToString
    , personIdFromString
    , personIdToString
    , statusFromKey
    , statusKey
    , statusLabel
    , statusTone
    )

import Klar.Date as Date exposing (Date)
import Klar.Rule as Rule
import Klar.Theme exposing (Tone(..))
import Time


type OrderId
    = OrderId Int


type PersonId
    = PersonId Int


type Status
    = New
    | Picking
    | Packed
    | Shipped
    | Delivered
    | Cancelled


type alias Person =
    { id : PersonId
    , name : String
    }


type alias Summary =
    { id : OrderId
    , customer : String
    , status : Status
    , created : Date
    , due : Date
    , total : Float
    , assignee : Maybe PersonId
    , lineCount : Int
    }


type alias Line =
    { sku : String
    , name : String
    , quantity : Int
    , unitPrice : Float
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


me : PersonId
me =
    PersonId 1


orderIdToString : OrderId -> String
orderIdToString (OrderId n) =
    "ORD-" ++ String.fromInt n


orderIdFromString : String -> Maybe OrderId
orderIdFromString text =
    if String.startsWith "ORD-" text then
        String.toInt (String.dropLeft 4 text) |> Maybe.map OrderId

    else
        Nothing


personIdToString : PersonId -> String
personIdToString (PersonId n) =
    String.fromInt n


personIdFromString : String -> Maybe PersonId
personIdFromString text =
    String.toInt text |> Maybe.map PersonId


assigneeName : List Person -> Maybe PersonId -> String
assigneeName people assignee =
    case assignee of
        Nothing ->
            ""

        Just id ->
            people
                |> List.filter (\p -> p.id == id)
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault "Unknown"


allStatuses : List Status
allStatuses =
    [ New, Picking, Packed, Shipped, Delivered, Cancelled ]


statusLabel : Status -> String
statusLabel status =
    case status of
        New ->
            "New"

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


statusKey : Status -> String
statusKey status =
    String.toLower (statusLabel status)


statusFromKey : String -> Maybe Status
statusFromKey key =
    allStatuses |> List.filter (\s -> statusKey s == key) |> List.head


statusTone : Status -> Tone
statusTone status =
    case status of
        New ->
            Neutral

        Picking ->
            Info

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
allowedNext : Status -> List Status
allowedNext status =
    case status of
        New ->
            [ Picking, Cancelled ]

        Picking ->
            [ Packed, Cancelled ]

        Packed ->
            [ Picking, Shipped, Cancelled ]

        Shipped ->
            [ Delivered ]

        Delivered ->
            []

        Cancelled ->
            []


{-| Moving back to picking can be undone by packing again; the rest cannot.
-}
cannotBeUndone : Status -> Status -> Bool
cannotBeUndone _ to =
    List.member to [ Shipped, Delivered, Cancelled ]


{-| What the filter bar can talk about. `today` makes "late" mean something.
-}
fields : Date -> List Person -> List (Rule.Field Summary)
fields today people =
    [ Rule.choiceField "status"
        "Status"
        (List.map (\s -> { value = statusKey s, label = statusLabel s }) allStatuses)
        (.status >> statusKey)
    , Rule.textField "customer" "Customer" .customer
    , Rule.dateField "created" "Created" (.created >> Just)
    , Rule.dateField "due" "Due" (.due >> Just)
    , Rule.numberField "total" "Total" (.total >> Just)
    , Rule.choiceField "assignee"
        "Assigned to"
        (List.map (\p -> { value = personIdToString p.id, label = p.name }) people)
        (\o -> o.assignee |> Maybe.map personIdToString |> Maybe.withDefault "")
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf, Rule.IsEmpty ]
    , Rule.boolField "late"
        "Late"
        (isLate today)
    ]


isLate : Date -> Summary -> Bool
isLate today order =
    Date.compare order.due today == LT && not (List.member order.status [ Shipped, Delivered, Cancelled ])
