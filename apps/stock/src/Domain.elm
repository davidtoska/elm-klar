module Domain exposing
    ( Category(..)
    , Figures
    , FlowByCategory
    , LevelPoint
    , MovementKind(..)
    , MovementRow
    , NodeId(..)
    , Overview
    , Period
    , RegionId(..)
    , Scope(..)
    , Transfer
    , TransferStatus(..)
    , TreeRegion
    , TreeWarehouse
    , TreeZone
    , WarehouseId(..)
    , WarehouseStatus(..)
    , ZoneId(..)
    , allCategories
    , allKinds
    , categoryName
    , kindFromKey
    , kindKey
    , kindName
    , nodeIds
    , scopeOfNode
    , transferIsOpen
    )

{-| The vocabulary of the stock domain: regions, warehouses, zones, SKUs,
movements and transfers. Plain data, no Klar.
-}

import Klar.Date exposing (Date)
import Klar.Tree as Tree
import Time


type RegionId
    = RegionId Int


type WarehouseId
    = WarehouseId Int


type ZoneId
    = ZoneId Int


{-| A node of the tree of locations.
-}
type NodeId
    = RegionNode RegionId
    | WarehouseNode WarehouseId
    | ZoneNode ZoneId


nodeIds : Tree.Ids NodeId
nodeIds =
    Tree.nodeIds { toKey = nodeToKey, fromKey = nodeFromKey }


nodeToKey : NodeId -> String
nodeToKey node =
    case node of
        RegionNode (RegionId n) ->
            "r" ++ String.fromInt n

        WarehouseNode (WarehouseId n) ->
            "w" ++ String.fromInt n

        ZoneNode (ZoneId n) ->
            "z" ++ String.fromInt n


nodeFromKey : String -> Maybe NodeId
nodeFromKey key =
    let
        number =
            String.dropLeft 1 key |> String.toInt
    in
    case ( String.left 1 key, number ) of
        ( "r", Just n ) ->
            Just (RegionNode (RegionId n))

        ( "w", Just n ) ->
            Just (WarehouseNode (WarehouseId n))

        ( "z", Just n ) ->
            Just (ZoneNode (ZoneId n))

        _ ->
            Nothing


{-| What the whole page is filtered by.
-}
type Scope
    = Everything
    | InRegion RegionId
    | InWarehouse WarehouseId
    | InZone ZoneId


scopeOfNode : Maybe NodeId -> Scope
scopeOfNode selected =
    case selected of
        Nothing ->
            Everything

        Just (RegionNode id) ->
            InRegion id

        Just (WarehouseNode id) ->
            InWarehouse id

        Just (ZoneNode id) ->
            InZone id


type Category
    = Electronics
    | Apparel
    | Grocery
    | Tools
    | Furniture
    | Toys


allCategories : List Category
allCategories =
    [ Electronics, Apparel, Grocery, Tools, Furniture, Toys ]


categoryName : Category -> String
categoryName category =
    case category of
        Electronics ->
            "Electronics"

        Apparel ->
            "Apparel"

        Grocery ->
            "Grocery"

        Tools ->
            "Tools"

        Furniture ->
            "Furniture"

        Toys ->
            "Toys"


type MovementKind
    = Receipt
    | Pick
    | TransferIn
    | TransferOut
    | Adjustment
    | Return


allKinds : List MovementKind
allKinds =
    [ Receipt, Pick, TransferIn, TransferOut, Adjustment, Return ]


kindName : MovementKind -> String
kindName kind =
    case kind of
        Receipt ->
            "Receipt"

        Pick ->
            "Pick"

        TransferIn ->
            "Transfer in"

        TransferOut ->
            "Transfer out"

        Adjustment ->
            "Adjustment"

        Return ->
            "Return"


kindKey : MovementKind -> String
kindKey kind =
    case kind of
        Receipt ->
            "receipt"

        Pick ->
            "pick"

        TransferIn ->
            "transfer-in"

        TransferOut ->
            "transfer-out"

        Adjustment ->
            "adjustment"

        Return ->
            "return"


kindFromKey : String -> Maybe MovementKind
kindFromKey key =
    List.filter (\kind -> kindKey kind == key) allKinds |> List.head


type WarehouseStatus
    = Active
    | OpeningSoon


type alias TreeZone =
    { id : ZoneId, name : String, code : String }


type alias TreeWarehouse =
    { id : WarehouseId
    , name : String
    , status : WarehouseStatus
    , movementCount : Int
    , zones : List TreeZone
    }


type alias TreeRegion =
    { id : RegionId, name : String, warehouses : List TreeWarehouse }


type alias Period =
    { from : Date, to : Date }


{-| The four figures at the top.
-}
type alias Figures =
    { stockValue : Float
    , belowReorder : Int
    , openTransfers : Int
    , turnover : Float
    }


type alias LevelPoint =
    { label : String, units : Float, reorder : Float }


type alias FlowByCategory =
    { category : Category, received : Float, shipped : Float }


type alias Overview =
    { hasData : Bool
    , figures : Figures
    , previous : Figures
    , levels : List LevelPoint
    , flows : List FlowByCategory
    }


type alias MovementRow =
    { id : Int
    , reference : String
    , at : Time.Posix
    , kind : MovementKind
    , skuCode : String
    , skuName : String
    , category : Category
    , region : String
    , warehouse : String
    , zone : String
    , quantity : Int
    , actor : String
    }


type TransferStatus
    = Requested
    | InTransit
    | Received
    | Cancelled


transferIsOpen : TransferStatus -> Bool
transferIsOpen status =
    status == Requested || status == InTransit


type alias Transfer =
    { id : Int
    , reference : String
    , at : Time.Posix
    , from : String
    , to : String
    , status : TransferStatus
    , units : Int
    }
