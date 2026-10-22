module Backend.Db exposing
    ( Db
    , Move
    , Sku
    , TransferRec
    , Warehouse
    , Zone
    , baseLevel
    , generate
    , regionNames
    )

{-| The dummy database: regions, warehouses, zones, 60 SKUs, 50 000 movements and
420 transfers, generated deterministically. Everything is derived from one seed, so
the same data comes back on every start.
-}

import Array exposing (Array)
import Domain exposing (Category(..), MovementKind(..), TransferStatus(..), WarehouseStatus(..))


type alias Warehouse =
    { id : Int, region : Int, name : String, status : WarehouseStatus }


type alias Zone =
    { id : Int, warehouse : Int, name : String, code : String }


type alias Sku =
    { id : Int
    , code : String
    , name : String
    , category : Category
    , unitCost : Float
    , reorderLevel : Int
    }


{-| A movement in the compact form the queries scan.
-}
type alias Move =
    { id : Int
    , atMs : Int
    , day : Int
    , kind : MovementKind
    , sku : Int
    , zone : Int
    , qty : Int
    , actor : Int
    }


type alias TransferRec =
    { id : Int
    , atMs : Int
    , day : Int
    , from : Int
    , to : Int
    , status : TransferStatus
    , units : Int
    }


type alias Db =
    { warehouses : Array Warehouse
    , zones : Array Zone
    , skus : Array Sku
    , movements : Array Move
    , transfers : Array TransferRec
    , actors : Array String
    , startDay : Int
    , endDay : Int
    }


regionNames : Array String
regionNames =
    Array.fromList [ "North", "South", "East", "West" ]


warehouseSpecs : List ( Int, String, WarehouseStatus )
warehouseSpecs =
    [ ( 0, "Warehouse N1", Active )
    , ( 0, "Warehouse N2", Active )
    , ( 0, "Warehouse N3", Active )
    , ( 1, "Warehouse S1", Active )
    , ( 1, "Warehouse S2", Active )
    , ( 1, "Warehouse S3", Active )
    , ( 2, "Warehouse E1", Active )
    , ( 2, "Warehouse E2", Active )
    , ( 2, "Warehouse E3", OpeningSoon )
    , ( 3, "Warehouse W1", Active )
    , ( 3, "Warehouse W2", Active )
    , ( 3, "Warehouse W3", Active )
    ]


zoneSpecs : List ( String, String )
zoneSpecs =
    [ ( "Receiving", "R" ), ( "Racking", "K" ), ( "Dispatch", "D" ) ]


skuNames : List ( Category, List String )
skuNames =
    [ ( Electronics, [ "USB hub", "Wireless mouse", "HDMI cable", "Power bank", "Webcam", "Keyboard", "Monitor stand", "Charger", "Headset", "Router" ] )
    , ( Apparel, [ "Work gloves", "Rain jacket", "Wool socks", "Cap", "Fleece", "Safety vest", "Boots", "Scarf", "T-shirt", "Belt" ] )
    , ( Grocery, [ "Olive oil", "Rice 5 kg", "Pasta", "Coffee beans", "Tea bags", "Flour", "Sugar", "Canned tomatoes", "Honey", "Oat flakes" ] )
    , ( Tools, [ "Hammer", "Cordless drill", "Tape measure", "Spirit level", "Wrench set", "Saw", "Screwdriver set", "Pliers", "Utility knife", "Work light" ] )
    , ( Furniture, [ "Desk", "Office chair", "Shelf unit", "Filing cabinet", "Stool", "Bookcase", "Table lamp", "Coat rack", "Bench", "Drawer unit" ] )
    , ( Toys, [ "Building blocks", "Puzzle", "Board game", "Plush bear", "Toy truck", "Doll house", "Card game", "Ball", "Kite", "Train set" ] )
    ]


movementCount : Int
movementCount =
    50000


transferCount : Int
transferCount =
    420


dayMs : Int
dayMs =
    86400000


{-| The stock a zone starts with for one SKU, before the first movement.
-}
baseLevel : Int -> Int -> Int
baseLevel zone sku =
    150 + modBy 450 (zone * 37 + sku * 53 + zone * sku)


{-| Builds the database. `endDay` is the epoch day of the last day with movements
(today); the data covers the 365 days up to and including it.
-}
generate : Int -> Int -> Db
generate endDay offsetMs =
    let
        startDay =
            endDay - 364

        warehouses =
            List.indexedMap
                (\i ( region, name, status ) -> { id = i, region = region, name = name, status = status })
                warehouseSpecs

        zones =
            warehouses
                |> List.concatMap
                    (\w ->
                        List.indexedMap
                            (\j ( zoneName, letter ) ->
                                { id = w.id * 3 + j
                                , warehouse = w.id
                                , name = zoneName
                                , code = "W" ++ String.fromInt (w.id + 1) ++ "-" ++ letter
                                }
                            )
                            zoneSpecs
                    )

        activeZones =
            zones
                |> List.filter
                    (\z ->
                        List.any (\w -> w.id == z.warehouse && w.status == Active) warehouses
                    )
                |> List.map .id
                |> Array.fromList

        skus =
            skuNames
                |> List.concatMap (\( category, names ) -> List.map (\name -> ( category, name )) names)
                |> List.indexedMap
                    (\i ( category, name ) ->
                        { id = i
                        , code = "SKU-" ++ String.fromInt (1001 + i)
                        , name = name
                        , category = category
                        , unitCost = toFloat (5 + modBy 240 (i * 47 + 11))
                        , reorderLevel = 200 + modBy 300 (i * 71 + 5)
                        }
                    )
                |> Array.fromList
    in
    { warehouses = Array.fromList warehouses
    , zones = Array.fromList zones
    , skus = skus
    , movements = makeMovements startDay offsetMs activeZones (Array.length skus)
    , transfers = makeTransfers startDay offsetMs activeZones
    , actors =
        Array.fromList
            [ "Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra", "Barbara Liskov", "Donald Knuth", "Margaret Hamilton" ]
    , startDay = startDay
    , endDay = endDay
    }



-- RANDOM NUMBERS (Park-Miller, small enough for exact Float arithmetic)


next : Int -> Int
next seed =
    modBy 2147483647 (seed * 16807)


{-| The next seed and a number from 0 to n - 1.
-}
draw : Int -> Int -> ( Int, Int )
draw n seed =
    let
        s =
            next seed
    in
    ( s, modBy n s )


makeMovements : Int -> Int -> Array Int -> Int -> Array Move
makeMovements startDay offsetMs zones skuCount =
    let
        stepMs =
            toFloat (365 * dayMs) / toFloat movementCount

        loop i seed acc =
            if i >= movementCount then
                List.reverse acc

            else
                let
                    ( s1, rKind ) =
                        draw 100 seed

                    ( s2, rZone ) =
                        draw (Array.length zones) s1

                    ( s3, rSku ) =
                        draw skuCount s2

                    ( s4, rQty ) =
                        draw 1000 s3

                    ( s5, rJitter ) =
                        draw (floor stepMs) s4

                    ( s6, rActor ) =
                        draw 8 s5

                    kind =
                        kindOf rKind

                    localMs =
                        startDay * dayMs + floor (toFloat i * stepMs) + rJitter

                    move =
                        { id = i + 1
                        , atMs = localMs - offsetMs
                        , day = floor (toFloat localMs / toFloat dayMs)
                        , kind = kind
                        , sku = rSku
                        , zone = Array.get rZone zones |> Maybe.withDefault 0
                        , qty = quantityOf kind rQty
                        , actor = rActor
                        }
                in
                loop (i + 1) s6 (move :: acc)
    in
    Array.fromList (loop 0 20261022 [])


kindOf : Int -> MovementKind
kindOf r =
    if r < 45 then
        Pick

    else if r < 65 then
        Receipt

    else if r < 73 then
        TransferOut

    else if r < 81 then
        TransferIn

    else if r < 88 then
        Adjustment

    else
        Return


quantityOf : MovementKind -> Int -> Int
quantityOf kind r =
    case kind of
        Pick ->
            -(1 + modBy 40 r)

        Receipt ->
            20 + modBy 120 r

        TransferOut ->
            -(10 + modBy 70 r)

        TransferIn ->
            10 + modBy 70 r

        Adjustment ->
            if modBy 2 r == 0 then
                1 + modBy 15 (r // 2)

            else
                -(1 + modBy 15 (r // 2))

        Return ->
            1 + modBy 10 r


makeTransfers : Int -> Int -> Array Int -> Array TransferRec
makeTransfers startDay offsetMs zones =
    let
        stepMs =
            toFloat (365 * dayMs) / toFloat transferCount

        pick seed =
            draw (Array.length zones) seed

        loop i seed acc =
            if i >= transferCount then
                List.reverse acc

            else
                let
                    ( s1, rFrom ) =
                        pick seed

                    ( s2, rTo0 ) =
                        pick s1

                    ( s3, rUnits ) =
                        draw 580 s2

                    ( s4, rJitter ) =
                        draw (floor stepMs) s3

                    ( s5, rStatus ) =
                        draw 100 s4

                    rTo =
                        if rTo0 == rFrom then
                            modBy (Array.length zones) (rTo0 + 1)

                        else
                            rTo0

                    localMs =
                        startDay * dayMs + floor (toFloat i * stepMs) + rJitter

                    status =
                        if i >= transferCount - 4 then
                            InTransit

                        else if rStatus < 7 then
                            Requested

                        else if rStatus < 12 then
                            Cancelled

                        else
                            Received
                in
                loop (i + 1)
                    s5
                    ({ id = i + 1
                     , atMs = localMs - offsetMs
                     , day = floor (toFloat localMs / toFloat dayMs)
                     , from = Array.get rFrom zones |> Maybe.withDefault 0
                     , to = Array.get rTo zones |> Maybe.withDefault 0
                     , status = status
                     , units = 20 + rUnits
                     }
                        :: acc
                    )
    in
    Array.fromList (loop 0 77177 [])
