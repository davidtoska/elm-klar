module Backend.Data exposing
    ( Category
    , Kind(..)
    , Levels
    , Metric
    , Movement
    , Place(..)
    , Query
    , Region
    , Summary
    , TransferOrder
    , TransferStatus(..)
    , Warehouse
    , Zone
    , allKinds
    , categories
    , categoryNames
    , dataEnd
    , dataStart
    , encodeMovement
    , inPeriod
    , kindLabel
    , levels
    , movementCountIn
    , movements
    , placeFromKey
    , placeHasData
    , placeKey
    , placeMatches
    , placeName
    , regions
    , summary
    , transferStatus
    , transfersIn
    )

{-| The dummy database of the stock overview: regions, warehouses, zones, SKUs, 50 000
movements and 300 transfers, all generated from a fixed seed. Everything here is pure and
synchronous; `Backend.Api` puts the delay and the failures in front of it.
-}

import Array exposing (Array)
import Dict exposing (Dict)
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Time



-- TYPES


type Place
    = InRegion String
    | InWarehouse String
    | InZone String


type Kind
    = Receipt
    | Issue
    | Transfer
    | Adjustment
    | Return


type alias Region =
    { id : String
    , name : String
    , movements : Int
    , warehouses : List Warehouse
    }


type alias Warehouse =
    { id : String
    , name : String
    , regionId : String
    , active : Bool
    , movements : Int
    , zones : List Zone
    }


type alias Zone =
    { id : String
    , name : String
    , warehouseId : String
    , movements : Int
    }


type alias Sku =
    { code : String
    , name : String
    , category : String
    , cost : Float
    , reorder : Int
    }


type alias Movement =
    { number : Int
    , id : String
    , at : Time.Posix
    , day : Date
    , regionId : String
    , warehouseId : String
    , warehouse : String
    , zoneId : String
    , zone : String
    , sku : String
    , item : String
    , category : String
    , kind : Kind
    , quantity : Int
    , value : Float
    , balanceAfter : Int
    , reference : String
    }


type TransferStatus
    = Requested
    | InTransit
    | Delayed
    | Received


type alias TransferOrder =
    { id : String
    , fromId : String
    , from : String
    , toId : String
    , to : String
    , item : String
    , quantity : Int
    , requestedAt : Time.Posix
    , receivedAt : Maybe Time.Posix
    , delayed : Bool
    }


type alias Query =
    { place : Maybe Place
    , from : Date
    , to : Date
    }


type alias Metric =
    { current : Float
    , previous : Float
    , trend : List Float
    }


type alias Summary =
    { hasData : Bool
    , stockValue : Metric
    , belowReorder : Metric
    , openTransfers : Metric
    , turnover : Metric
    }


type alias Levels =
    { labels : List String
    , onHand : List Float
    , reorder : List Float
    }


type alias Category =
    { name : String
    , counts : List ( Kind, Int )
    }



-- PLACES


placeKey : Place -> String
placeKey place =
    case place of
        InRegion id ->
            "r:" ++ id

        InWarehouse id ->
            "w:" ++ id

        InZone id ->
            "z:" ++ id


placeFromKey : String -> Maybe Place
placeFromKey key =
    case String.split ":" key of
        [ "r", id ] ->
            Just (InRegion id)

        [ "w", id ] ->
            Just (InWarehouse id)

        [ "z", id ] ->
            Just (InZone id)

        _ ->
            Nothing


placeName : Place -> String
placeName place =
    case place of
        InRegion id ->
            Dict.get id regionNames |> Maybe.withDefault id

        InWarehouse id ->
            Dict.get id warehouseNames |> Maybe.withDefault id

        InZone id ->
            Dict.get id zoneNames |> Maybe.withDefault id


placeMatches : Maybe Place -> Movement -> Bool
placeMatches place movement =
    case place of
        Nothing ->
            True

        Just (InRegion id) ->
            movement.regionId == id

        Just (InWarehouse id) ->
            movement.warehouseId == id

        Just (InZone id) ->
            movement.zoneId == id


{-| Does any stock exist at this place at all?
-}
placeHasData : Maybe Place -> Bool
placeHasData place =
    case place of
        Nothing ->
            True

        Just (InRegion id) ->
            List.any (\w -> w.regionId == id && w.active) warehouseList

        Just (InWarehouse id) ->
            List.any (\w -> w.id == id && w.active) warehouseList

        Just (InZone id) ->
            List.any (\z -> z.id == id && warehouseIsActive z.warehouseId) zoneList


warehouseIsActive : String -> Bool
warehouseIsActive id =
    List.any (\w -> w.id == id && w.active) warehouseList


{-| Which warehouse a place is in, for the transfers (they run between warehouses).
-}
warehouseOfZone : String -> String
warehouseOfZone zoneId =
    String.split "-" zoneId |> List.head |> Maybe.withDefault zoneId


transferTouches : Maybe Place -> TransferOrder -> Bool
transferTouches place transfer =
    case place of
        Nothing ->
            True

        Just (InRegion id) ->
            regionOfWarehouse transfer.fromId == id || regionOfWarehouse transfer.toId == id

        Just (InWarehouse id) ->
            transfer.fromId == id || transfer.toId == id

        Just (InZone id) ->
            transfer.fromId == warehouseOfZone id || transfer.toId == warehouseOfZone id


regionOfWarehouse : String -> String
regionOfWarehouse id =
    String.left 1 id
        |> (\letter ->
                case letter of
                    "n" ->
                        "north"

                    "s" ->
                        "south"

                    "e" ->
                        "east"

                    _ ->
                        "west"
           )



-- MASTER DATA


dataStart : Date
dataStart =
    Date.fromParts 2026 1 1 |> Maybe.withDefault (Date.fromEpochDay 0)


dataEnd : Date
dataEnd =
    Date.fromParts 2026 10 22 |> Maybe.withDefault (Date.fromEpochDay 0)


regionDefs : List ( String, String, List ( String, String ) )
regionDefs =
    [ ( "north", "North", [ ( "n1", "Harbour" ), ( "n2", "Ridge" ), ( "n3", "Fjord" ) ] )
    , ( "south", "South", [ ( "s1", "Meadow" ), ( "s2", "Quarry" ), ( "s3", "Orchard" ) ] )
    , ( "east", "East", [ ( "e1", "Lakeside" ), ( "e2", "Summit" ), ( "e3", "Crossing" ) ] )
    , ( "west", "West", [ ( "w1", "Mill" ), ( "w2", "Bridge" ), ( "w3", "Haven" ) ] )
    ]


zoneDefs : List ( String, String )
zoneDefs =
    [ ( "rec", "Receiving" ), ( "bulk", "Bulk" ), ( "pick", "Picking" ) ]


{-| Haven has never had any stock: the "warehouse with no data".
-}
inactiveWarehouse : String
inactiveWarehouse =
    "w3"


warehouseList : List Warehouse
warehouseList =
    List.concatMap
        (\( regionId, _, whs ) ->
            List.map
                (\( id, name ) ->
                    { id = id
                    , name = name
                    , regionId = regionId
                    , active = id /= inactiveWarehouse
                    , movements = 0
                    , zones = []
                    }
                )
                whs
        )
        regionDefs


warehouseArray : Array Warehouse
warehouseArray =
    Array.fromList warehouseList


zoneList : List Zone
zoneList =
    List.concatMap
        (\w ->
            List.map
                (\( suffix, name ) ->
                    { id = w.id ++ "-" ++ suffix, name = name, warehouseId = w.id, movements = 0 }
                )
                zoneDefs
        )
        warehouseList


regionNames : Dict String String
regionNames =
    Dict.fromList (List.map (\( id, name, _ ) -> ( id, name )) regionDefs)


warehouseNames : Dict String String
warehouseNames =
    Dict.fromList (List.map (\w -> ( w.id, w.name )) warehouseList)


zoneNames : Dict String String
zoneNames =
    Dict.fromList (List.map (\z -> ( z.id, warehouseName z.warehouseId ++ " / " ++ z.name )) zoneList)


warehouseName : String -> String
warehouseName id =
    Dict.get id warehouseNames |> Maybe.withDefault id


categoryNames : List String
categoryNames =
    [ "Electronics", "Packaging", "Tools", "Safety", "Cleaning", "Office" ]


skuNames : List (List String)
skuNames =
    [ [ "Barcode scanner", "Label printer", "Handheld terminal", "Power adapter", "Cable kit", "Battery pack", "Tablet mount", "Sensor tag" ]
    , [ "Carton S", "Carton M", "Carton L", "Pallet wrap", "Tape roll", "Bubble sleeve", "Strapping band", "Pallet EUR" ]
    , [ "Hand trolley", "Cutter", "Spirit level", "Torque wrench", "Pallet jack", "Step stool", "Tool tray", "Clamp set" ]
    , [ "Safety vest", "Work gloves", "Ear protection", "Hard hat", "Safety shoes", "Goggles", "First aid kit", "Floor marking" ]
    , [ "Floor cleaner", "Degreaser", "Wipes", "Bin liners", "Mop head", "Sprayer", "Dust pan", "Hand soap" ]
    , [ "Marker set", "Notebook", "Label roll", "Clipboard", "Stapler", "Pen box", "Folder", "Sticky notes" ]
    ]


skus : Array Sku
skus =
    List.map2
        (\category names -> List.map (\name -> ( category, name )) names)
        categoryNames
        skuNames
        |> List.concat
        |> List.indexedMap
            (\i ( category, name ) ->
                { code = "SKU-" ++ String.fromInt (1001 + i)
                , name = name
                , category = category
                , cost = toFloat (5 + modBy 180 (i * 37)) + 0.5
                , reorder = 120 + modBy 140 (i * 53)
                }
            )
        |> Array.fromList


skuCount : Int
skuCount =
    Array.length skus


openingBalance : Int
openingBalance =
    150



-- POSITIONS: one per warehouse, zone and SKU


positionCount : Int
positionCount =
    Array.length warehouseArray * 3 * skuCount


positionIndex : Int -> Int -> Int -> Int
positionIndex warehouse zone sku =
    (warehouse * 3 + zone) * skuCount + sku


{-| Who owns position `index`: its warehouse index and its zone index.
-}
positionPlace : Int -> ( Int, Int, Int )
positionPlace index =
    let
        sku =
            modBy skuCount index

        cell =
            index // skuCount
    in
    ( cell // 3, modBy 3 cell, sku )


positionInPlace : Maybe Place -> Int -> Bool
positionInPlace place index =
    let
        ( w, z, _ ) =
            positionPlace index

        warehouse =
            Array.get w warehouseArray
    in
    case warehouse of
        Nothing ->
            False

        Just wh ->
            wh.active
                && (case place of
                        Nothing ->
                            True

                        Just (InRegion id) ->
                            wh.regionId == id

                        Just (InWarehouse id) ->
                            wh.id == id

                        Just (InZone id) ->
                            List.any (\( suffix, _ ) -> wh.id ++ "-" ++ suffix == id) (List.drop z zoneDefs |> List.take 1)
                   )



-- MOVEMENTS


type alias Raw =
    { dayOffset : Int
    , secs : Int
    , warehouse : Int
    , zone : Int
    , sku : Int
    , kind : Kind
    , amount : Int
    }


next : Int -> Int
next s =
    modBy 2147483647 (s * 48271)


kindOf : Int -> Kind
kindOf r =
    let
        n =
            modBy 100 r
    in
    if n < 35 then
        Receipt

    else if n < 70 then
        Issue

    else if n < 80 then
        Transfer

    else if n < 88 then
        Adjustment

    else
        Return


activeWarehouses : Array Int
activeWarehouses =
    warehouseList
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, w ) -> w.active)
        |> List.map Tuple.first
        |> Array.fromList


dayCount : Int
dayCount =
    Date.diffDays dataStart dataEnd + 1


rawStream : Int -> List Raw
rawStream count =
    let
        go i seed acc =
            if i >= count then
                acc

            else
                let
                    s1 =
                        next seed

                    s2 =
                        next s1

                    s3 =
                        next s2

                    s4 =
                        next s3

                    s5 =
                        next s4

                    s6 =
                        next s5

                    s7 =
                        next s6
                in
                go (i + 1)
                    s7
                    ({ dayOffset = modBy dayCount s1
                     , secs = modBy 86400 s2
                     , warehouse = Array.get (modBy (Array.length activeWarehouses) s3) activeWarehouses |> Maybe.withDefault 0
                     , zone = modBy 3 s4
                     , sku = modBy skuCount s5
                     , kind = kindOf s6
                     , amount = s7
                     }
                        :: acc
                    )
    in
    go 0 20261022 []


{-| The signed quantity a raw row asks for, before the balance caps issues.
-}
requestedDelta : Raw -> Int
requestedDelta raw =
    case raw.kind of
        Receipt ->
            20 + modBy 160 raw.amount

        Issue ->
            -(5 + modBy 140 raw.amount)

        Transfer ->
            if modBy 2 (raw.amount // 7) == 0 then
                5 + modBy 55 raw.amount

            else
                -(5 + modBy 55 raw.amount)

        Adjustment ->
            if modBy 2 (raw.amount // 11) == 0 then
                1 + modBy 15 raw.amount

            else
                -(1 + modBy 15 raw.amount)

        Return ->
            1 + modBy 10 raw.amount


movementTime : Raw -> Time.Posix
movementTime raw =
    Date.addDays raw.dayOffset dataStart
        |> Date.toPosix Time.utc
        |> Time.posixToMillis
        |> (\ms -> ms + raw.secs * 1000)
        |> Time.millisToPosix


{-| All 50 000 movements, oldest first. Issues are capped by the balance of their position,
so no position goes negative.
-}
movements : Array Movement
movements =
    let
        sorted =
            rawStream 50000
                |> List.sortBy (\r -> r.dayOffset * 86400 + r.secs)

        step raw ( number, balances, acc ) =
            let
                index =
                    positionIndex raw.warehouse raw.zone raw.sku

                balance =
                    Array.get index balances |> Maybe.withDefault openingBalance

                wanted =
                    requestedDelta raw

                ( kind, delta ) =
                    if wanted < 0 && balance + wanted < 0 then
                        if balance == 0 then
                            ( Receipt, 30 )

                        else
                            ( raw.kind, -balance )

                    else
                        ( raw.kind, wanted )

                sku =
                    Array.get raw.sku skus |> Maybe.withDefault emptySku

                wh =
                    Array.get raw.warehouse warehouseArray |> Maybe.withDefault emptyWarehouse

                zoneDef =
                    List.drop raw.zone zoneDefs |> List.head |> Maybe.withDefault ( "rec", "Receiving" )

                time =
                    movementTime raw
            in
            ( number + 1
            , Array.set index (balance + delta) balances
            , { number = number
              , id = "MV-" ++ String.padLeft 6 '0' (String.fromInt number)
              , at = time
              , day = Date.addDays raw.dayOffset dataStart
              , regionId = wh.regionId
              , warehouseId = wh.id
              , warehouse = wh.name
              , zoneId = wh.id ++ "-" ++ Tuple.first zoneDef
              , zone = Tuple.second zoneDef
              , sku = sku.code
              , item = sku.name
              , category = sku.category
              , kind = kind
              , quantity = delta
              , value = toFloat delta * sku.cost
              , balanceAfter = balance + delta
              , reference = referencePrefix kind ++ String.fromInt (4000 + modBy 5000 (number * 7))
              }
                :: acc
            )

        ( _, _, reversed ) =
            List.foldl step ( 1, Array.repeat positionCount openingBalance, [] ) sorted
    in
    Array.fromList (List.reverse reversed)


emptySku : Sku
emptySku =
    { code = "", name = "", category = "", cost = 0, reorder = 0 }


emptyWarehouse : Warehouse
emptyWarehouse =
    { id = "", name = "", regionId = "", active = False, movements = 0, zones = [] }


referencePrefix : Kind -> String
referencePrefix kind =
    case kind of
        Receipt ->
            "PO-"

        Issue ->
            "SO-"

        Transfer ->
            "TR-"

        Adjustment ->
            "ADJ-"

        Return ->
            "RMA-"


kindLabel : Kind -> String
kindLabel kind =
    case kind of
        Receipt ->
            "Receipt"

        Issue ->
            "Issue"

        Transfer ->
            "Transfer"

        Adjustment ->
            "Adjustment"

        Return ->
            "Return"


allKinds : List Kind
allKinds =
    [ Receipt, Issue, Transfer, Adjustment, Return ]


encodeMovement : Movement -> Encode.Value
encodeMovement m =
    Encode.object
        [ ( "id", Encode.string m.id )
        , ( "type", Encode.string (String.toLower (kindLabel m.kind)) )
        , ( "occurredAt", Encode.string (isoTime m.at) )
        , ( "location"
          , Encode.object
                [ ( "region", Encode.string m.regionId )
                , ( "warehouse", Encode.string m.warehouseId )
                , ( "zone", Encode.string m.zoneId )
                ]
          )
        , ( "item"
          , Encode.object
                [ ( "sku", Encode.string m.sku )
                , ( "name", Encode.string m.item )
                , ( "category", Encode.string m.category )
                ]
          )
        , ( "quantity", Encode.int m.quantity )
        , ( "value", Encode.float m.value )
        , ( "balanceAfter", Encode.int m.balanceAfter )
        , ( "source"
          , Encode.object
                [ ( "system", Encode.string "wms-simulator" )
                , ( "reference", Encode.string m.reference )
                ]
          )
        ]


isoTime : Time.Posix -> String
isoTime posix =
    let
        two n =
            String.padLeft 2 '0' (String.fromInt n)
    in
    Date.toIso (Date.fromPosix Time.utc posix)
        ++ "T"
        ++ two (Time.toHour Time.utc posix)
        ++ ":"
        ++ two (Time.toMinute Time.utc posix)
        ++ ":"
        ++ two (Time.toSecond Time.utc posix)
        ++ "Z"



-- THE TREE


movementCounts : Dict String Int
movementCounts =
    Array.foldl
        (\m counts ->
            counts
                |> Dict.update ("r:" ++ m.regionId) bump
                |> Dict.update ("w:" ++ m.warehouseId) bump
                |> Dict.update ("z:" ++ m.zoneId) bump
        )
        Dict.empty
        movements


bump : Maybe Int -> Maybe Int
bump count =
    Just (Maybe.withDefault 0 count + 1)


movementCountIn : Place -> Int
movementCountIn place =
    Dict.get (placeKey place) movementCounts |> Maybe.withDefault 0


regions : List Region
regions =
    List.map
        (\( id, name, _ ) ->
            { id = id
            , name = name
            , movements = movementCountIn (InRegion id)
            , warehouses =
                warehouseList
                    |> List.filter (\w -> w.regionId == id)
                    |> List.map
                        (\w ->
                            { w
                                | movements = movementCountIn (InWarehouse w.id)
                                , zones =
                                    zoneList
                                        |> List.filter (\z -> z.warehouseId == w.id)
                                        |> List.map (\z -> { z | movements = movementCountIn (InZone z.id) })
                            }
                        )
            }
        )
        regionDefs



-- QUERIES


inPeriod : Query -> Movement -> Bool
inPeriod query m =
    Date.compare m.day query.from /= LT && Date.compare m.day query.to /= GT


type alias Snapshot =
    { value : Float
    , units : Int
    , below : Int
    }


{-| The stock at the end of each of the given days (ascending), in one pass over the movements.
-}
snapshots : Maybe Place -> List Date -> List Snapshot
snapshots place days =
    let
        indexes =
            List.range 0 (positionCount - 1)
                |> List.filter (positionInPlace place)

        take balances =
            List.foldl
                (\index acc ->
                    let
                        balance =
                            Array.get index balances |> Maybe.withDefault openingBalance

                        sku =
                            case positionPlace index of
                                ( _, _, s ) ->
                                    Array.get s skus |> Maybe.withDefault emptySku
                    in
                    { value = acc.value + toFloat balance * sku.cost
                    , units = acc.units + balance
                    , below =
                        if balance < sku.reorder then
                            acc.below + 1

                        else
                            acc.below
                    }
                )
                { value = 0, units = 0, below = 0 }
                indexes

        positionOf m =
            let
                w =
                    warehouseIndex m.warehouseId

                z =
                    zoneIndex m.zoneId

                s =
                    skuIndex m.sku
            in
            positionIndex w z s

        go remaining balances cursor out =
            case remaining of
                [] ->
                    List.reverse out

                day :: rest ->
                    case Array.get cursor movements of
                        Just m ->
                            if Date.compare m.day day == GT then
                                go rest balances cursor (take balances :: out)

                            else
                                go remaining (Array.set (positionOf m) m.balanceAfter balances) (cursor + 1) out

                        Nothing ->
                            go rest balances cursor (take balances :: out)
    in
    go days (Array.repeat positionCount openingBalance) 0 []


warehouseIndex : String -> Int
warehouseIndex id =
    warehouseList |> List.indexedMap Tuple.pair |> List.filter (\( _, w ) -> w.id == id) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0


zoneIndex : String -> Int
zoneIndex zoneId =
    case List.head (List.drop 1 (String.split "-" zoneId)) of
        Just "bulk" ->
            1

        Just "pick" ->
            2

        _ ->
            0


skuIndex : String -> Int
skuIndex code =
    String.toInt (String.dropLeft 4 code) |> Maybe.map (\n -> n - 1001) |> Maybe.withDefault 0


periodDays : Query -> Int
periodDays query =
    Date.diffDays query.from query.to + 1


previousQuery : Query -> Query
previousQuery query =
    let
        length =
            periodDays query
    in
    { query | from = Date.addDays -length query.from, to = Date.addDays -length query.to }


openTransfersAt : Maybe Place -> Date -> Int
openTransfersAt place day =
    let
        endOfDay =
            Date.addDays 1 day |> Date.toPosix Time.utc |> Time.posixToMillis
    in
    transferArray
        |> Array.toList
        |> List.filter
            (\t ->
                transferTouches place t
                    && (Time.posixToMillis t.requestedAt < endOfDay)
                    && (case t.receivedAt of
                            Nothing ->
                                True

                            Just at ->
                                Time.posixToMillis at >= endOfDay
                       )
            )
        |> List.length


summary : Query -> Summary
summary query =
    let
        previous =
            previousQuery query

        samplePoints =
            let
                length =
                    periodDays query

                steps =
                    7
            in
            List.range 0 steps
                |> List.map (\k -> Date.addDays (k * (length - 1) // steps) query.from)

        days =
            [ Date.addDays -1 previous.from, previous.to, Date.addDays -1 query.from, query.to ]

        snaps =
            snapshots query.place (List.sortWith Date.compare (days ++ samplePoints))

        lookup day =
            let
                sorted =
                    List.sortWith Date.compare (days ++ samplePoints)
            in
            List.map2 Tuple.pair sorted snaps
                |> List.filter (\( d, _ ) -> Date.compare d day == EQ)
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault { value = 0, units = 0, below = 0 }

        issues q =
            Array.foldl
                (\m acc ->
                    if m.kind == Issue && placeMatches q.place m && inPeriod q m then
                        acc - m.value

                    else
                        acc
                )
                0
                movements

        turnoverOf q =
            let
                opening =
                    lookup (Date.addDays -1 q.from)

                closing =
                    lookup q.to

                average =
                    (opening.value + closing.value) / 2
            in
            if average <= 0 then
                0

            else
                toFloat (round (issues q / average * 100)) / 100
    in
    { hasData = placeHasData query.place
    , stockValue =
        { current = (lookup query.to).value
        , previous = (lookup previous.to).value
        , trend = List.map (\d -> (lookup d).value) samplePoints
        }
    , belowReorder =
        { current = toFloat (lookup query.to).below
        , previous = toFloat (lookup previous.to).below
        , trend = List.map (\d -> toFloat (lookup d).below) samplePoints
        }
    , openTransfers =
        { current = toFloat (openTransfersAt query.place query.to)
        , previous = toFloat (openTransfersAt query.place previous.to)
        , trend = List.map (\d -> toFloat (openTransfersAt query.place d)) samplePoints
        }
    , turnover =
        { current = turnoverOf query
        , previous = turnoverOf previous
        , trend = []
        }
    }


levels : Query -> Levels
levels query =
    let
        length =
            periodDays query

        bucket =
            max 1 (ceiling (toFloat length / 24))

        ends =
            List.range 0 ((length - 1) // bucket)
                |> List.map (\k -> Date.addDays (min (length - 1) (k * bucket + bucket - 1)) query.from)

        snaps =
            snapshots query.place ends

        reorderTotal =
            List.range 0 (positionCount - 1)
                |> List.filter (positionInPlace query.place)
                |> List.foldl
                    (\index acc ->
                        case positionPlace index of
                            ( _, _, s ) ->
                                acc + (Array.get s skus |> Maybe.map .reorder |> Maybe.withDefault 0)
                    )
                    0
                |> toFloat

        label day =
            String.padLeft 2 '0' (String.fromInt (Date.month day)) ++ "-" ++ String.padLeft 2 '0' (String.fromInt (Date.day day))
    in
    { labels = List.map label ends
    , onHand = List.map (\s -> toFloat s.units) snaps
    , reorder = List.map (\_ -> reorderTotal) ends
    }


categories : Query -> List Category
categories query =
    let
        counts : Dict ( String, Int ) Int
        counts =
            Array.foldl
                (\m acc ->
                    if placeMatches query.place m && inPeriod query m then
                        Dict.update ( m.category, kindRank m.kind ) bump acc

                    else
                        acc
                )
                Dict.empty
                movements
    in
    List.map
        (\name ->
            { name = name
            , counts =
                List.map
                    (\kind -> ( kind, Dict.get ( name, kindRank kind ) counts |> Maybe.withDefault 0 ))
                    allKinds
            }
        )
        categoryNames


kindRank : Kind -> Int
kindRank kind =
    case kind of
        Receipt ->
            0

        Issue ->
            1

        Transfer ->
            2

        Adjustment ->
            3

        Return ->
            4



-- TRANSFERS


transferArray : Array TransferOrder
transferArray =
    let
        make i =
            let
                s1 =
                    next (20261022 + i * 7919)

                s2 =
                    next s1

                s3 =
                    next s2

                s4 =
                    next s3

                s5 =
                    next s4

                s6 =
                    next s5

                active =
                    Array.length activeWarehouses

                fromPos =
                    modBy active s1

                toPos =
                    modBy active (fromPos + 1 + modBy (active - 1) s3)

                fromW =
                    Array.get fromPos activeWarehouses |> Maybe.andThen (\wi -> Array.get wi warehouseArray) |> Maybe.withDefault emptyWarehouse

                toW =
                    Array.get toPos activeWarehouses |> Maybe.andThen (\wi -> Array.get wi warehouseArray) |> Maybe.withDefault emptyWarehouse

                sku =
                    Array.get (modBy skuCount s4) skus |> Maybe.withDefault emptySku

                requestedDay =
                    Date.addDays (modBy dayCount s5) dataStart

                requestedMs =
                    Date.toPosix Time.utc requestedDay |> Time.posixToMillis |> (+) (modBy 86400 s6 * 1000)

                transitDays =
                    1 + modBy 9 s6

                receivedMs =
                    requestedMs + transitDays * 86400000

                endMs =
                    Date.addDays 1 dataEnd |> Date.toPosix Time.utc |> Time.posixToMillis
            in
            { id = "TR-" ++ String.padLeft 4 '0' (String.fromInt (i + 1))
            , fromId = fromW.id
            , from = fromW.name
            , toId = toW.id
            , to = toW.name
            , item = sku.name
            , quantity = 10 + modBy 190 s4
            , requestedAt = Time.millisToPosix requestedMs
            , receivedAt =
                if receivedMs < endMs then
                    Just (Time.millisToPosix receivedMs)

                else
                    Nothing
            , delayed = transitDays > 6
            }
    in
    List.range 0 299
        |> List.map make
        |> List.sortBy (\t -> -(Time.posixToMillis t.requestedAt))
        |> Array.fromList


transferStatus : Date -> TransferOrder -> TransferStatus
transferStatus day transfer =
    let
        endOfDay =
            Date.addDays 1 day |> Date.toPosix Time.utc |> Time.posixToMillis

        requested =
            Time.posixToMillis transfer.requestedAt

        received =
            transfer.receivedAt |> Maybe.map Time.posixToMillis
    in
    case received of
        Just at ->
            if at < endOfDay then
                Received

            else if transfer.delayed && endOfDay - requested > 6 * 86400000 then
                Delayed

            else
                InTransit

        Nothing ->
            if endOfDay - requested < 86400000 then
                Requested

            else if transfer.delayed || endOfDay - requested > 6 * 86400000 then
                Delayed

            else
                InTransit


{-| The latest transfers touching a place, newest first, up to the end of the period.
-}
transfersIn : Query -> Int -> { items : List TransferOrder, hasMore : Bool }
transfersIn query limit =
    let
        endMs =
            Date.addDays 1 query.to |> Date.toPosix Time.utc |> Time.posixToMillis

        matching =
            transferArray
                |> Array.toList
                |> List.filter (\t -> transferTouches query.place t && Time.posixToMillis t.requestedAt < endMs)
    in
    { items = List.take limit matching
    , hasMore = List.length matching > limit
    }
