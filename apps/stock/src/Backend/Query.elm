module Backend.Query exposing (movementRows, overview, transfers, tree)

{-| The "server": pure functions from the database and a scope to what a page
asks for. Nothing here knows about HTTP or about Klar components.
-}

import Array exposing (Array)
import Backend.Db as Db exposing (Db, Move)
import Dict exposing (Dict)
import Domain
    exposing
        ( FlowByCategory
        , LevelPoint
        , MovementKind(..)
        , MovementRow
        , Overview
        , Period
        , RegionId(..)
        , Scope(..)
        , Transfer
        , TransferStatus
        , TreeRegion
        , WarehouseId(..)
        , WarehouseStatus(..)
        , ZoneId(..)
        )
import Klar.Date as Date
import Klar.Locale as Locale
import Set exposing (Set)
import Time


dayMs : Int
dayMs =
    86400000



-- SCOPE


warehouseRegion : Db -> Int -> Int
warehouseRegion db warehouse =
    Array.get warehouse db.warehouses |> Maybe.map .region |> Maybe.withDefault -1


warehouseActive : Db -> Int -> Bool
warehouseActive db warehouse =
    (Array.get warehouse db.warehouses |> Maybe.map .status) == Just Active


{-| The zones of the scope that can hold stock (a warehouse that is not open yet
has none).
-}
scopeZones : Db -> Scope -> Set Int
scopeZones db scope =
    let
        inScope zone =
            case scope of
                Everything ->
                    True

                InRegion (RegionId r) ->
                    warehouseRegion db zone.warehouse == r

                InWarehouse (WarehouseId w) ->
                    zone.warehouse == w

                InZone (ZoneId z) ->
                    zone.id == z
    in
    db.zones
        |> Array.filter (\zone -> inScope zone && warehouseActive db zone.warehouse)
        |> Array.map .id
        |> Array.toList
        |> Set.fromList


scopedMoves : Db -> Set Int -> Array Move
scopedMoves db zones =
    Array.filter (\m -> Set.member m.zone zones) db.movements


pairs : Db -> Set Int -> List ( Int, Int )
pairs db zones =
    let
        skuIds =
            List.range 0 (Array.length db.skus - 1)
    in
    Set.toList zones |> List.concatMap (\z -> List.map (\s -> ( z, s )) skuIds)


unitCost : Db -> Int -> Float
unitCost db sku =
    Array.get sku db.skus |> Maybe.map .unitCost |> Maybe.withDefault 0


reorderLevel : Db -> Int -> Int
reorderLevel db sku =
    Array.get sku db.skus |> Maybe.map .reorderLevel |> Maybe.withDefault 0



-- LEVELS


type alias Level =
    { units : Int, value : Float }


levelAt : Db -> Set Int -> Array Move -> Int -> Level
levelAt db zones moves day =
    let
        base =
            pairs db zones
                |> List.foldl
                    (\( z, s ) acc ->
                        { units = acc.units + Db.baseLevel z s
                        , value = acc.value + toFloat (Db.baseLevel z s) * unitCost db s
                        }
                    )
                    { units = 0, value = 0 }
    in
    Array.foldl
        (\m acc ->
            if m.day <= day then
                { units = acc.units + m.qty
                , value = acc.value + toFloat m.qty * unitCost db m.sku
                }

            else
                acc
        )
        base
        moves


belowReorderAt : Db -> Set Int -> Array Move -> Int -> Int
belowReorderAt db zones moves day =
    let
        key z s =
            z * 100 + s

        deltas : Dict Int Int
        deltas =
            Array.foldl
                (\m d ->
                    if m.day <= day then
                        Dict.update (key m.zone m.sku)
                            (\v -> Just (Maybe.withDefault 0 v + m.qty))
                            d

                    else
                        d
                )
                Dict.empty
                moves
    in
    pairs db zones
        |> List.filter
            (\( z, s ) ->
                Db.baseLevel z s + (Dict.get (key z s) deltas |> Maybe.withDefault 0) < reorderLevel db s
            )
        |> List.length


reorderTotal : Db -> Set Int -> Float
reorderTotal db zones =
    pairs db zones |> List.foldl (\( _, s ) acc -> acc + toFloat (reorderLevel db s)) 0



-- OVERVIEW


overview : Db -> Scope -> Period -> Overview
overview db scope period =
    let
        zones =
            scopeZones db scope

        moves =
            scopedMoves db zones

        startDay =
            Date.toEpochDay period.from

        endDay =
            Date.toEpochDay period.to

        length =
            endDay - startDay + 1

        previousEnd =
            startDay - 1

        previousStart =
            previousEnd - length + 1

        figuresFor first last =
            let
                atStart =
                    levelAt db zones moves (first - 1)

                atEnd =
                    levelAt db zones moves last

                shipped =
                    Array.foldl
                        (\m acc ->
                            if m.day >= first && m.day <= last && (m.kind == Pick || m.kind == TransferOut) then
                                acc + toFloat (abs m.qty)

                            else
                                acc
                        )
                        0
                        moves

                average =
                    (toFloat atStart.units + toFloat atEnd.units) / 2

                span =
                    toFloat (last - first + 1)
            in
            { stockValue = atEnd.value
            , belowReorder = belowReorderAt db zones moves last
            , openTransfers = openTransfersIn db zones first last
            , turnover =
                if average > 0 then
                    shipped / average * (365 / span)

                else
                    0
            }

        steps =
            12

        stepDays =
            max 1 (length // steps)

        bucketEnds =
            List.range 1 steps
                |> List.map (\k -> min endDay (startDay + k * stepDays - 1))
                |> List.foldr
                    (\d acc ->
                        if List.member d acc then
                            acc

                        else
                            d :: acc
                    )
                    []
                |> (\days ->
                        if List.member endDay days then
                            days

                        else
                            days ++ [ endDay ]
                   )

        reorder =
            reorderTotal db zones
    in
    if Array.isEmpty moves then
        { hasData = False
        , figures = { stockValue = 0, belowReorder = 0, openTransfers = 0, turnover = 0 }
        , previous = { stockValue = 0, belowReorder = 0, openTransfers = 0, turnover = 0 }
        , levels = []
        , flows = []
        }

    else
        { hasData = True
        , figures = figuresFor startDay endDay
        , previous = figuresFor previousStart previousEnd
        , levels =
            List.map
                (\day ->
                    { label = dayLabel day
                    , units = toFloat (levelAt db zones moves day).units
                    , reorder = reorder
                    }
                )
                bucketEnds
        , flows = flowsByCategory db moves startDay endDay
        }


dayLabel : Int -> String
dayLabel epochDay =
    let
        date =
            Date.fromEpochDay epochDay
    in
    String.fromInt (Date.day date) ++ " " ++ Locale.monthShort Locale.en (Date.month date)


flowsByCategory : Db -> Array Move -> Int -> Int -> List FlowByCategory
flowsByCategory db moves first last =
    let
        totals : Dict Int ( Float, Float )
        totals =
            Array.foldl
                (\m acc ->
                    if m.day >= first && m.day <= last then
                        let
                            category =
                                Array.get m.sku db.skus |> Maybe.map (.category >> categoryIndex) |> Maybe.withDefault 0
                        in
                        Dict.update category
                            (\v ->
                                let
                                    ( received, shipped ) =
                                        Maybe.withDefault ( 0, 0 ) v
                                in
                                if m.qty >= 0 then
                                    Just ( received + toFloat m.qty, shipped )

                                else
                                    Just ( received, shipped + toFloat (abs m.qty) )
                            )
                            acc

                    else
                        acc
                )
                Dict.empty
                moves
    in
    Domain.allCategories
        |> List.indexedMap
            (\i category ->
                let
                    ( received, shipped ) =
                        Dict.get i totals |> Maybe.withDefault ( 0, 0 )
                in
                { category = category, received = received, shipped = shipped }
            )


categoryIndex : Domain.Category -> Int
categoryIndex category =
    Domain.allCategories
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, c ) -> c == category)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


openTransfersIn : Db -> Set Int -> Int -> Int -> Int
openTransfersIn db zones first last =
    db.transfers
        |> Array.filter
            (\t ->
                t.day >= first
                    && t.day <= last
                    && Domain.transferIsOpen t.status
                    && (Set.member t.from zones || Set.member t.to zones)
            )
        |> Array.length



-- TRANSFERS


transfers : Db -> Scope -> List Transfer
transfers db scope =
    let
        zones =
            scopeZones db scope

        label zoneId =
            Array.get zoneId db.zones
                |> Maybe.map (\z -> z.code ++ " " ++ z.name)
                |> Maybe.withDefault "?"
    in
    db.transfers
        |> Array.filter (\t -> Set.member t.from zones || Set.member t.to zones)
        |> Array.toList
        |> List.reverse
        |> List.take 40
        |> List.map
            (\t ->
                { id = t.id
                , reference = "TR-" ++ String.padLeft 4 '0' (String.fromInt t.id)
                , at = Time.millisToPosix t.atMs
                , from = label t.from
                , to = label t.to
                , status = t.status
                , units = t.units
                }
            )



-- MOVEMENTS


movementRows : Db -> Scope -> Array MovementRow
movementRows db scope =
    let
        zones =
            scopeZones db scope

        regionName warehouse =
            Array.get (warehouseRegion db warehouse) Db.regionNames |> Maybe.withDefault "?"
    in
    scopedMoves db zones
        |> Array.toList
        |> List.reverse
        |> Array.fromList
        |> Array.map
            (\m ->
                let
                    zone =
                        Array.get m.zone db.zones

                    warehouseId =
                        zone |> Maybe.map .warehouse |> Maybe.withDefault 0

                    sku =
                        Array.get m.sku db.skus
                in
                { id = m.id
                , reference = "MV-" ++ String.padLeft 6 '0' (String.fromInt m.id)
                , at = Time.millisToPosix m.atMs
                , kind = m.kind
                , skuCode = sku |> Maybe.map .code |> Maybe.withDefault "?"
                , skuName = sku |> Maybe.map .name |> Maybe.withDefault "?"
                , category = sku |> Maybe.map .category |> Maybe.withDefault Domain.Electronics
                , region = regionName warehouseId
                , warehouse = Array.get warehouseId db.warehouses |> Maybe.map .name |> Maybe.withDefault "?"
                , zone = zone |> Maybe.map .name |> Maybe.withDefault "?"
                , quantity = m.qty
                , actor = Array.get m.actor db.actors |> Maybe.withDefault "?"
                }
            )



-- TREE


tree : Db -> List TreeRegion
tree db =
    let
        counts : Dict Int Int
        counts =
            Array.foldl
                (\m acc ->
                    let
                        warehouse =
                            Array.get m.zone db.zones |> Maybe.map .warehouse |> Maybe.withDefault 0
                    in
                    Dict.update warehouse (\v -> Just (Maybe.withDefault 0 v + 1)) acc
                )
                Dict.empty
                db.movements
    in
    Array.toList db.warehouses
        |> List.foldr
            (\w acc ->
                let
                    entry =
                        { id = WarehouseId w.id
                        , name = w.name
                        , status = w.status
                        , movementCount = Dict.get w.id counts |> Maybe.withDefault 0
                        , zones =
                            Array.toList db.zones
                                |> List.filter (\z -> z.warehouse == w.id)
                                |> List.map (\z -> { id = ZoneId z.id, name = z.name, code = z.code })
                        }
                in
                Dict.update w.region (\v -> Just (entry :: Maybe.withDefault [] v)) acc
            )
            Dict.empty
        |> Dict.toList
        |> List.map
            (\( regionId, warehouses ) ->
                { id = RegionId regionId
                , name = Array.get regionId Db.regionNames |> Maybe.withDefault "?"
                , warehouses = warehouses
                }
            )
