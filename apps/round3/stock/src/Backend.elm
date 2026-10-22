module Backend exposing
    ( Categories
    , Figures
    , Levels
    , Movement
    , MovementKind(..)
    , NodeId(..)
    , Query
    , RegionNode
    , Sku
    , TransferRow
    , WarehouseNode
    , ZoneNode
    , categories
    , figures
    , firstDate
    , kindLabel
    , lastDate
    , levels
    , locate
    , movements
    , nodeLabel
    , zonesOf
    , skuOf
    , structure
    , transfers
    )

{-| A dummy backend: synchronous functions over data that is generated the same way on every run.

Regions contain warehouses, warehouses contain zones. 120 SKUs. 50 000 movements and 2 800
transfers between 1 January and 20 October 2026. One warehouse (the overflow depot) has no stock
and no movements, so the application can say that a warehouse has no data.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Date as Date exposing (Date)
import Set exposing (Set)



-- TYPES


type NodeId
    = RegionId Int
    | WarehouseId Int
    | ZoneId Int


type MovementKind
    = Receipt
    | Issue
    | TransferOut
    | TransferIn
    | Adjustment


type alias Sku =
    { id : Int
    , code : String
    , name : String
    , category : String
    , unitCost : Int
    , reorder : Int
    }


type alias Movement =
    { id : Int
    , day : Int
    , date : Date
    , zone : Int
    , sku : Int
    , kind : MovementKind
    , quantity : Int
    , reference : String
    , skuCode : String
    , product : String
    , category : String
    , warehouse : String
    , zoneName : String
    }


type alias Transfer =
    { id : Int
    , fromZone : Int
    , toZone : Int
    , sku : Int
    , quantity : Int
    , createdDay : Int
    , completedDay : Maybe Int
    }


type alias Query =
    { selection : Maybe NodeId
    , from : Date
    , to : Date
    }


type alias ZoneNode =
    { id : Int, name : String, movements : Int }


type alias WarehouseNode =
    { id : Int, name : String, zones : List ZoneNode, movements : Int }


type alias RegionNode =
    { id : Int, name : String, warehouses : List WarehouseNode, movements : Int }


type alias Figures =
    { hasData : Bool
    , stockValue : Int
    , previousStockValue : Int
    , belowReorder : Int
    , previousBelowReorder : Int
    , openTransfers : Int
    , previousOpenTransfers : Int
    , turnover : Float
    , previousTurnover : Float
    , trend : List Float
    }


type alias Levels =
    { days : List Date
    , current : List Float
    , previous : List (Maybe Float)
    }


type alias Categories =
    { category : String, inbound : Int, outbound : Int }


type alias TransferRow =
    { id : String
    , at : Date
    , title : String
    , description : String
    , done : Bool
    , late : Bool
    }



-- STRUCTURE (static)


regionNames : List String
regionNames =
    [ "North", "East", "South", "West", "Central" ]


warehouseSpecs : List ( Int, String )
warehouseSpecs =
    [ ( 1, "Northgate" )
    , ( 1, "Harbour Point" )
    , ( 1, "Frostvik" )
    , ( 2, "Eastfield" )
    , ( 2, "Riverside" )
    , ( 3, "Southbank" )
    , ( 3, "Marsh Lane" )
    , ( 3, "Kestrel Park" )
    , ( 4, "Westend" )
    , ( 4, "Cliffside" )
    , ( 4, "Overflow depot" )
    , ( 5, "Midtown" )
    , ( 5, "Crossroads" )
    ]


emptyWarehouse : Int
emptyWarehouse =
    11


type alias ZoneRecord =
    { id : Int, warehouseId : Int, name : String }


zoneRecords : List ZoneRecord
zoneRecords =
    let
        zonesOfWarehouse w =
            if modBy 2 w == 0 then
                [ "Receiving", "Racking", "Cold store", "Dispatch" ]

            else
                [ "Receiving", "Racking", "Dispatch" ]
    in
    List.range 1 (List.length warehouseSpecs)
        |> List.concatMap (\w -> List.map (\name -> ( w, name )) (zonesOfWarehouse w))
        |> List.indexedMap (\i ( w, name ) -> { id = i + 1, warehouseId = w, name = name })


zoneById : Dict Int ZoneRecord
zoneById =
    Dict.fromList (List.map (\z -> ( z.id, z )) zoneRecords)


warehouseName : Int -> String
warehouseName id =
    warehouseSpecs
        |> List.drop (id - 1)
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault "?"


warehouseRegion : Int -> Int
warehouseRegion id =
    warehouseSpecs
        |> List.drop (id - 1)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


regionName : Int -> String
regionName id =
    regionNames |> List.drop (id - 1) |> List.head |> Maybe.withDefault "?"


zoneWarehouse : Int -> Int
zoneWarehouse zone =
    Dict.get zone zoneById |> Maybe.map .warehouseId |> Maybe.withDefault 0


stockedZoneIds : List Int
stockedZoneIds =
    zoneRecords
        |> List.filter (\z -> z.warehouseId /= emptyWarehouse)
        |> List.map .id


stockedZoneArray : Array Int
stockedZoneArray =
    Array.fromList stockedZoneIds


{-| The zones a selection stands for (all zones for no selection).
-}
zonesOf : Maybe NodeId -> Set Int
zonesOf selection =
    let
        keep predicate =
            zoneRecords |> List.filter predicate |> List.map .id |> Set.fromList
    in
    case selection of
        Nothing ->
            keep (\_ -> True)

        Just (RegionId r) ->
            keep (\z -> warehouseRegion z.warehouseId == r)

        Just (WarehouseId w) ->
            keep (\z -> z.warehouseId == w)

        Just (ZoneId z) ->
            Set.singleton z


{-| Where a zone is.
-}
locate : Int -> { region : String, warehouse : String, zone : String }
locate zone =
    case Dict.get zone zoneById of
        Just z ->
            { region = regionName (warehouseRegion z.warehouseId)
            , warehouse = warehouseName z.warehouseId
            , zone = z.name
            }

        Nothing ->
            { region = "?", warehouse = "?", zone = "?" }



-- SKUS


categoryNames : Array String
categoryNames =
    Array.fromList [ "Electronics", "Apparel", "Food", "Tools", "Home" ]


baseNames : Array (Array String)
baseNames =
    Array.fromList
        [ Array.fromList [ "Cable organiser", "Charging dock", "Sensor kit", "Battery pack", "Desk lamp", "Router mount", "Label printer", "Signal booster" ]
        , Array.fromList [ "Work gloves", "Rain jacket", "Safety vest", "Wool socks", "Cap", "Overalls", "Thermal shirt", "Boots" ]
        , Array.fromList [ "Oat flakes", "Olive oil", "Rice 5 kg", "Canned beans", "Tea box", "Coffee beans", "Pasta", "Honey jar" ]
        , Array.fromList [ "Torque wrench", "Cordless drill", "Tape measure", "Spirit level", "Socket set", "Hand saw", "Clamp pair", "Pliers" ]
        , Array.fromList [ "Storage bin", "Door mat", "Mug set", "Shelf bracket", "Towel pack", "Curtain rail", "Pot rack", "Laundry basket" ]
        ]


skus : Array Sku
skus =
    Array.initialize 120
        (\i ->
            let
                c =
                    modBy 5 i

                variant =
                    i // 5

                base =
                    Array.get c baseNames
                        |> Maybe.andThen (Array.get (modBy 8 variant))
                        |> Maybe.withDefault "Item"
            in
            { id = i
            , code = "SKU-" ++ String.fromInt (1000 + i)
            , name = base ++ " " ++ String.fromInt (1 + variant // 8)
            , category = Array.get c categoryNames |> Maybe.withDefault "Other"
            , unitCost = 500 + modBy 24500 (hash i 1 // 3)
            , reorder = 150 + modBy 200 (hash i 2 // 5)
            }
        )


skuOf : Int -> Sku
skuOf i =
    Array.get i skus
        |> Maybe.withDefault { id = i, code = "?", name = "?", category = "?", unitCost = 0, reorder = 0 }



-- DETERMINISTIC NUMBERS


mix : Int -> Int
mix n =
    modBy 2147483647 (n * 48271 + 11)


hash : Int -> Int -> Int
hash a b =
    mix (mix (mix (a * 7919 + b * 104729 + 17)))


between : Int -> Int -> Int -> Int
between lo hi h =
    lo + modBy (hi - lo + 1) (h // 11)



-- DATES


baseEpoch : Int
baseEpoch =
    Date.fromParts 2026 1 1 |> Maybe.map Date.toEpochDay |> Maybe.withDefault 0


lastDay : Int
lastDay =
    292


dateOfDay : Int -> Date
dateOfDay d =
    Date.fromEpochDay (baseEpoch + d)


dayOfDate : Date -> Int
dayOfDate d =
    Date.toEpochDay d - baseEpoch


firstDate : Date
firstDate =
    dateOfDay 0


lastDate : Date
lastDate =
    dateOfDay lastDay


dayDates : Array Date
dayDates =
    Array.initialize (lastDay + 1) dateOfDay



-- TRANSFERS AND MOVEMENTS


transferList : List Transfer
transferList =
    List.range 0 2799
        |> List.map
            (\i ->
                let
                    n =
                        Array.length stockedZoneArray

                    fromIndex =
                        modBy n (hash i 3 // 7)

                    toIndex =
                        modBy n (fromIndex + 1 + modBy (n - 1) (hash i 4 // 7))

                    zoneAt k =
                        Array.get k stockedZoneArray |> Maybe.withDefault 1

                    created =
                        modBy 285 (hash i 5 // 7)

                    lag =
                        1 + modBy 6 (hash i 6 // 7)

                    lost =
                        modBy 100 (hash i 7 // 7) < 3
                in
                { id = 1001 + i
                , fromZone = zoneAt fromIndex
                , toZone = zoneAt toIndex
                , sku = modBy 120 (hash i 8 // 7)
                , quantity = between 10 80 (hash i 9)
                , createdDay = created
                , completedDay =
                    if lost || created + lag > lastDay then
                        Nothing

                    else
                        Just (created + lag)
                }
            )


baseCount : Int
baseCount =
    50000
        - List.sum (List.map (\t -> 1 + Maybe.withDefault 0 (Maybe.map (\_ -> 1) t.completedDay)) transferList)


makeMovement : Int -> Int -> Int -> MovementKind -> Int -> String -> Movement
makeMovement day zone skuIndex kind quantity reference =
    let
        sku =
            skuOf skuIndex

        place =
            locate zone
    in
    { id = 0
    , day = day
    , date = Array.get day dayDates |> Maybe.withDefault firstDate
    , zone = zone
    , sku = skuIndex
    , kind = kind
    , quantity = quantity
    , reference = reference
    , skuCode = sku.code
    , product = sku.name
    , category = sku.category
    , warehouse = place.warehouse
    , zoneName = place.zone
    }


baseMovement : Int -> Movement
baseMovement i =
    let
        zone =
            Array.get (modBy (Array.length stockedZoneArray) (hash i 11 // 7)) stockedZoneArray
                |> Maybe.withDefault 1

        skuIndex =
            modBy 120 (hash i 12 // 7)

        day =
            modBy (lastDay + 1) (hash i 13 // 7)

        pick =
            modBy 100 (hash i 14 // 7)

        amount =
            hash i 15
    in
    if pick < 40 then
        makeMovement day zone skuIndex Receipt (between 20 120 amount) ("PO-" ++ String.fromInt (4000 + i))

    else if pick < 92 then
        makeMovement day zone skuIndex Issue (negate (between 10 70 amount)) ("SO-" ++ String.fromInt (7000 + i))

    else
        makeMovement day zone skuIndex Adjustment (between -15 15 amount) ("ADJ-" ++ String.fromInt (900 + i))


transferLegs : Transfer -> List Movement
transferLegs t =
    let
        reference =
            "T-" ++ String.fromInt t.id

        out =
            makeMovement t.createdDay t.fromZone t.sku TransferOut (negate t.quantity) reference
    in
    case t.completedDay of
        Just d ->
            [ out, makeMovement d t.toZone t.sku TransferIn t.quantity reference ]

        Nothing ->
            [ out ]


{-| 50 000 movements, oldest first, numbered from 1.
-}
movements : Array Movement
movements =
    List.range 0 (baseCount - 1)
        |> List.map baseMovement
        |> (++) (List.concatMap transferLegs transferList)
        |> List.sortBy .day
        |> List.indexedMap (\i m -> { m | id = i + 1 })
        |> Array.fromList


kindLabel : MovementKind -> String
kindLabel kind =
    case kind of
        Receipt ->
            "Receipt"

        Issue ->
            "Issue"

        TransferOut ->
            "Transfer out"

        TransferIn ->
            "Transfer in"

        Adjustment ->
            "Adjustment"



-- STRUCTURE


zoneCounts : Dict Int Int
zoneCounts =
    Array.foldl (\m acc -> Dict.update m.zone (\n -> Just (Maybe.withDefault 0 n + 1)) acc) Dict.empty movements


structure : List RegionNode
structure =
    let
        zoneNode z =
            { id = z.id, name = z.name, movements = Dict.get z.id zoneCounts |> Maybe.withDefault 0 }

        warehouseNode w =
            let
                zones =
                    zoneRecords |> List.filter (\z -> z.warehouseId == w) |> List.map zoneNode
            in
            { id = w, name = warehouseName w, zones = zones, movements = List.sum (List.map .movements zones) }

        regionNode r =
            let
                ws =
                    List.range 1 (List.length warehouseSpecs)
                        |> List.filter (\w -> warehouseRegion w == r)
                        |> List.map warehouseNode
            in
            { id = r, name = regionName r, warehouses = ws, movements = List.sum (List.map .movements ws) }
    in
    List.map regionNode (List.range 1 (List.length regionNames))



-- AGGREGATES


stockedIn : Set Int -> List Int
stockedIn zones =
    List.filter (\z -> Set.member z zones) stockedZoneIds


opening : Int -> Int -> Int
opening zone sku =
    200 + modBy 300 (hash zone (sku + 500) // 5)


pairKey : Int -> Int -> Int
pairKey zone sku =
    zone * 1000 + sku


{-| Stock value in minor units, and the pairs below their reorder level, from the quantities of the pairs.
-}
valueAndBelow : List Int -> Dict Int Int -> ( Int, Int )
valueAndBelow zones moved =
    List.foldl
        (\zone acc ->
            List.foldl
                (\sku ( value, below ) ->
                    let
                        s =
                            skuOf sku

                        qty =
                            opening zone sku + Maybe.withDefault 0 (Dict.get (pairKey zone sku) moved)
                    in
                    ( value + qty * s.unitCost
                    , if qty < s.reorder then
                        below + 1

                      else
                        below
                    )
                )
                acc
                (List.range 0 119)
        )
        ( 0, 0 )
        zones


touches : Set Int -> Transfer -> Bool
touches zones t =
    Set.member t.fromZone zones || Set.member t.toZone zones


openAt : Int -> Transfer -> Bool
openAt day t =
    t.createdDay <= day && (case t.completedDay of
                                Nothing ->
                                    True

                                Just d ->
                                    d > day
                           )


figures : Query -> Figures
figures q =
    let
        zones =
            zonesOf q.selection

        stocked =
            stockedIn zones

        s =
            dayOfDate q.from

        e =
            dayOfDate q.to

        len =
            e - s + 1

        pe =
            s - 1

        ps =
            s - len

        addTo key amount dict =
            Dict.update key (\n -> Just (Maybe.withDefault 0 n + amount)) dict

        step m acc =
            if Set.member m.zone zones then
                let
                    key =
                        pairKey m.zone m.sku

                    cost =
                        negate m.quantity * (skuOf m.sku).unitCost

                    issued =
                        m.kind == Issue
                in
                { atEnd =
                    if m.day <= e then
                        addTo key m.quantity acc.atEnd

                    else
                        acc.atEnd
                , atPrevEnd =
                    if m.day <= pe then
                        addTo key m.quantity acc.atPrevEnd

                    else
                        acc.atPrevEnd
                , issued =
                    if issued && m.day >= s && m.day <= e then
                        acc.issued + cost

                    else
                        acc.issued
                , previousIssued =
                    if issued && m.day >= ps && m.day <= pe then
                        acc.previousIssued + cost

                    else
                        acc.previousIssued
                }

            else
                acc

        folded =
            Array.foldl step { atEnd = Dict.empty, atPrevEnd = Dict.empty, issued = 0, previousIssued = 0 } movements

        ( value, below ) =
            valueAndBelow stocked folded.atEnd

        ( previousValue, previousBelow ) =
            valueAndBelow stocked folded.atPrevEnd

        mine =
            List.filter (touches zones) transferList

        ratio part whole =
            if whole > 0 then
                toFloat part / toFloat whole

            else
                0

        lv =
            levels q
    in
    { hasData = not (List.isEmpty stocked)
    , stockValue = value
    , previousStockValue = previousValue
    , belowReorder = below
    , previousBelowReorder = previousBelow
    , openTransfers = List.length (List.filter (openAt e) mine)
    , previousOpenTransfers = List.length (List.filter (openAt pe) mine)
    , turnover = ratio folded.issued value
    , previousTurnover = ratio folded.previousIssued previousValue
    , trend = lv.current
    }


levels : Query -> Levels
levels q =
    let
        zones =
            zonesOf q.selection

        stocked =
            stockedIn zones

        s =
            dayOfDate q.from

        e =
            dayOfDate q.to

        len =
            e - s + 1

        openingTotal =
            List.sum (List.concatMap (\z -> List.map (opening z) (List.range 0 119)) stocked)

        deltas =
            Array.foldl
                (\m acc ->
                    if Set.member m.zone zones then
                        Array.set m.day (Maybe.withDefault 0 (Array.get m.day acc) + m.quantity) acc

                    else
                        acc
                )
                (Array.repeat (lastDay + 1) 0)
                movements

        cumulative =
            deltas
                |> Array.toList
                |> List.foldl
                    (\d ( running, out ) -> ( running + d, running + d :: out ))
                    ( openingTotal, [] )
                |> Tuple.second
                |> List.reverse
                |> Array.fromList

        at day =
            Array.get day cumulative |> Maybe.map toFloat

        days =
            List.range s e
    in
    { days = List.map dateOfDay days
    , current = List.map (\d -> Maybe.withDefault 0 (at d)) days
    , previous = List.map (\d -> at (d - len)) days
    }


categories : Query -> List Categories
categories q =
    let
        zones =
            zonesOf q.selection

        s =
            dayOfDate q.from

        e =
            dayOfDate q.to

        counted =
            Array.foldl
                (\m acc ->
                    if m.day >= s && m.day <= e && Set.member m.zone zones then
                        Dict.update m.category
                            (\n ->
                                let
                                    ( a, b ) =
                                        Maybe.withDefault ( 0, 0 ) n
                                in
                                if m.quantity >= 0 then
                                    Just ( a + 1, b )

                                else
                                    Just ( a, b + 1 )
                            )
                            acc

                    else
                        acc
                )
                Dict.empty
                movements
    in
    Array.toList categoryNames
        |> List.map
            (\name ->
                let
                    ( a, b ) =
                        Dict.get name counted |> Maybe.withDefault ( 0, 0 )
                in
                { category = name, inbound = a, outbound = b }
            )


transfers : Query -> List TransferRow
transfers q =
    let
        zones =
            zonesOf q.selection

        e =
            dayOfDate q.to

        place z =
            let
                p =
                    locate z
            in
            p.warehouse ++ " / " ++ p.zone

        row t =
            let
                completed =
                    t.completedDay |> Maybe.andThen (\d -> if d <= e then Just d else Nothing)

                sku =
                    skuOf t.sku

                happened =
                    Maybe.withDefault t.createdDay completed
            in
            { sortKey = happened * 10000 + t.id
            , row =
                { id = "T-" ++ String.fromInt t.id
                , at = dateOfDay happened
                , title =
                    "Transfer T-"
                        ++ String.fromInt t.id
                        ++ (if completed == Nothing then
                                " in transit"

                            else
                                " received"
                           )
                , description =
                    String.fromInt t.quantity ++ " x " ++ sku.name ++ " from " ++ place t.fromZone ++ " to " ++ place t.toZone
                , done = completed /= Nothing
                , late = completed == Nothing && e - t.createdDay > 7
                }
            }
    in
    transferList
        |> List.filter (\t -> touches zones t && t.createdDay <= e)
        |> List.map row
        |> List.sortBy (\r -> negate r.sortKey)
        |> List.take 8
        |> List.map .row


nodeLabel : NodeId -> String
nodeLabel node =
    case node of
        RegionId r ->
            regionName r ++ " region"

        WarehouseId w ->
            warehouseName w

        ZoneId z ->
            let
                p =
                    locate z
            in
            p.warehouse ++ " / " ++ p.zone
