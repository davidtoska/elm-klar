module Api.Types exposing
    ( Activity
    , ActivityKind(..)
    , ApiError(..)
    , Country
    , CountryCode
    , FieldError
    , Lookups
    , Order
    , OrderId
    , OrderInput
    , OrderQuery
    , OrderStatus(..)
    , Owner
    , OwnerId
    , Page
    , Priority(..)
    , Product
    , Summary
    , Warehouse
    , WarehouseId
    , activityKey
    , allOrderStatuses
    , allPriorities
    , allowedNextStatuses
    , countryCode
    , countryCodeText
    , countryName
    , isEditable
    , orderId
    , orderIdText
    , orderStatusLabel
    , ownerId
    , ownerIdText
    , ownerName
    , priorityLabel
    , warehouseId
    , warehouseIdText
    , warehouseName
    )

{-| The contract between the pages and the backend: the records that cross the
boundary, and the errors a request can end in.

The showcase has no real server. `Backend.Server` plays that role with plain
functions over an in-memory database; `Api` wraps them so every call behaves
like an HTTP request (a delay, and sometimes a failure). When a real server
exists, only `Api` changes, and these types are what its JSON decoders produce.

-}

import Klar.Date exposing (Date)
import Time



-- ORDERS


{-| The number of an order ("ORD-10001"). A type of its own, so that an order
number cannot be mixed up with a customer name or a warehouse code.
-}
type OrderId
    = OrderId String


orderId : String -> OrderId
orderId =
    OrderId


orderIdText : OrderId -> String
orderIdText (OrderId text) =
    text


{-| Where an order is in its life.
-}
type OrderStatus
    = Draft
    | Confirmed
    | Picking
    | Shipped
    | Delivered
    | Cancelled


type Priority
    = Low
    | Normal
    | High
    | Urgent


type alias Order =
    { id : OrderId
    , customer : String
    , email : String
    , country : CountryCode
    , city : String
    , status : OrderStatus
    , priority : Priority
    , owner : Maybe OwnerId
    , warehouse : WarehouseId
    , created : Date
    , due : Date
    , delivered : Maybe Date
    , lines : Int
    , total : Float
    , note : String
    }


{-| What the editor sends when an order is created or changed. The server
decides the id, the status and the creation date.
-}
type alias OrderInput =
    { customer : String
    , email : String
    , country : Maybe CountryCode
    , city : String
    , priority : Priority
    , owner : Maybe OwnerId
    , warehouse : Maybe WarehouseId
    , due : Maybe Date
    , lines : Maybe Int
    , total : Maybe Float
    , note : String
    }


allOrderStatuses : List OrderStatus
allOrderStatuses =
    [ Draft, Confirmed, Picking, Shipped, Delivered, Cancelled ]


allPriorities : List Priority
allPriorities =
    [ Low, Normal, High, Urgent ]


{-| The statuses an order can move to from its current one. An order is cancelled
until it has shipped; after that it only moves on. The server enforces the same
rules, so a page can offer exactly these.
-}
allowedNextStatuses : OrderStatus -> List OrderStatus
allowedNextStatuses status =
    case status of
        Draft ->
            [ Confirmed, Cancelled ]

        Confirmed ->
            [ Picking, Cancelled ]

        Picking ->
            [ Shipped, Cancelled ]

        Shipped ->
            [ Delivered ]

        Delivered ->
            []

        Cancelled ->
            []


{-| Whether the details of an order can still be edited: not once it has shipped.
-}
isEditable : OrderStatus -> Bool
isEditable status =
    List.member status [ Draft, Confirmed, Picking ]


orderStatusLabel : OrderStatus -> String
orderStatusLabel status =
    case status of
        Draft ->
            "Draft"

        Confirmed ->
            "Confirmed"

        Picking ->
            "Picking"

        Shipped ->
            "Shipped"

        Delivered ->
            "Delivered"

        Cancelled ->
            "Cancelled"


priorityLabel : Priority -> String
priorityLabel priority =
    case priority of
        Low ->
            "Low"

        Normal ->
            "Normal"

        High ->
            "High"

        Urgent ->
            "Urgent"



-- LISTS


{-| One page of a list that is searched, filtered and sorted on the server.
`total` counts all matching rows, not just the ones on this page.
-}
type alias Page a =
    { rows : List a
    , total : Int
    , page : Int
    , pageSize : Int
    }


{-| What a list of orders is asked for. `sort` is a column key and whether it
ascends.
-}
type alias OrderQuery =
    { search : String
    , statuses : List OrderStatus
    , sort : Maybe ( String, Bool )
    , page : Int
    , pageSize : Int
    }



-- REFERENCE DATA


{-| The two-letter code of a country ("NL"). A type of its own, so that a country
cannot be mixed up with a city or a warehouse.
-}
type CountryCode
    = CountryCode String


countryCode : String -> CountryCode
countryCode =
    CountryCode


countryCodeText : CountryCode -> String
countryCodeText (CountryCode text) =
    text


{-| The code of a warehouse ("RTM").
-}
type WarehouseId
    = WarehouseId String


warehouseId : String -> WarehouseId
warehouseId =
    WarehouseId


warehouseIdText : WarehouseId -> String
warehouseIdText (WarehouseId text) =
    text


{-| The id of an owner. Not the name: two people can have the same name.
-}
type OwnerId
    = OwnerId String


ownerId : String -> OwnerId
ownerId =
    OwnerId


ownerIdText : OwnerId -> String
ownerIdText (OwnerId text) =
    text


{-| The name for an id, from the list the server sent. An id the list does not
have is shown as it is written.
-}
countryName : List Country -> CountryCode -> String
countryName countries code =
    countries
        |> List.filter (\c -> c.code == code)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault (countryCodeText code)


warehouseName : List Warehouse -> WarehouseId -> String
warehouseName warehouses id =
    warehouses
        |> List.filter (\w -> w.id == id)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault (warehouseIdText id)


ownerName : List Owner -> OwnerId -> String
ownerName owners id =
    owners
        |> List.filter (\o -> o.id == id)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault (ownerIdText id)


type alias Country =
    { code : CountryCode
    , name : String
    , region : String
    }


type alias Warehouse =
    { id : WarehouseId
    , name : String
    , city : String
    , country : CountryCode
    }


{-| Someone who looks after orders. The order holds the `OwnerId`; the name is
looked up in the list of owners.
-}
type alias Owner =
    { id : OwnerId
    , name : String
    }


{-| The reference data the order form points at.
-}
type alias Lookups =
    { countries : List Country
    , warehouses : List Warehouse
    , owners : List Owner
    , customers : List String
    }


type alias Product =
    { sku : String
    , name : String
    , category : List String
    , price : Float
    , stock : Int
    , reorderLevel : Int
    , supplier : String
    , active : Bool
    }



-- OVERVIEW


type ActivityKind
    = OrderCreated
    | OrderShipped
    | OrderDelivered
    | OrderCancelled


type alias Activity =
    { at : Time.Posix
    , kind : ActivityKind
    , orderId : OrderId
    , customer : String
    }


{-| A stable word for the kind of event, for building ids.
-}
activityKey : ActivityKind -> String
activityKey kind =
    case kind of
        OrderCreated ->
            "created"

        OrderShipped ->
            "shipped"

        OrderDelivered ->
            "delivered"

        OrderCancelled ->
            "cancelled"


{-| Everything the overview page shows, from one request.
-}
type alias Summary =
    { orders : Int
    , open : Int
    , overdue : Int
    , revenue : Float
    , onTimeRate : Float
    , byStatus : List ( OrderStatus, Int )
    , perDay : List ( Date, Int )
    , revenueByCountry : List ( String, Float )
    , attention : List Order
    , activity : List Activity
    }



-- ERRORS


{-| Why a request failed.
-}
type ApiError
    = NetworkDown
    | TimedOut
    | ServerFailed Int
    | NotFound
    | Conflict String
    | ValidationFailed (List FieldError)


{-| A problem with one field of what was sent. `field` is the DOM id of the
control in the form, so the form can show the message where it belongs.
-}
type alias FieldError =
    { field : String
    , message : String
    }
