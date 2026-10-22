module Backend exposing
    ( BulkOutcome
    , Db
    , Target(..)
    , addNote
    , assign
    , changeStatus
    , detail
    , empty
    , exportCsv
    , generate
    , list
    , pack
    , saveViews
    , savedViews
    , searchOrders
    , totalOrders
    , withViews
    )

{-| The dummy server: synchronous functions over an in-memory database. `Api` puts a delay and
failures in front of them. Nothing here knows about the browser.
-}

import Dict exposing (Dict)
import Domain
    exposing
        ( Detail
        , HistoryEntry
        , Line
        , Note
        , OrderId(..)
        , Page
        , Request
        , Status(..)
        , Summary
        )
import Klar.Date as Date exposing (Date)
import Klar.Remote as Remote
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews exposing (SavedView)
import Klar.Search as Search
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Time


type alias Db =
    { orders : Dict Int Detail
    , views : List SavedView
    , nextNoteId : Int
    }


{-| The orders a bulk action applies to: these ids, or every order that matches a request,
except these ids (the "select all N matching" of the table).
-}
type Target
    = Ids (List OrderId)
    | AllMatching Request (List OrderId)


type alias BulkOutcome =
    { changed : Int
    , skipped : Int
    }


totalOrders : Db -> Int
totalOrders db =
    Dict.size db.orders



-- GENERATING THE DATA


generate : Date -> Db
generate today =
    { orders =
        List.range 1 1200
            |> List.map (\n -> ( n, makeOrder today n ))
            |> Dict.fromList
    , views = []
    , nextNoteId = 1000
    }


customerNames : List String
customerNames =
    [ "Aurora Logistics", "Fjord Foods", "Birch Hardware", "Cedar Supplies", "Delta Freight", "Evergreen Market" ]
        ++ [ "Granite Works", "Harbor Trading", "Iris Pharmacy", "Juniper Textiles", "Kestrel Outdoor", "Lantern Books" ]
        ++ [ "Maple Bakery", "Nordic Tools", "Orchard Fresh", "Pine Furniture", "Quartz Electronics", "Rowan Garden" ]
        ++ [ "Summit Sports", "Tidewater Marine", "Umber Paints", "Violet Florist", "Willow Pets", "Yarrow Health" ]


catalog : List ( String, String, Int )
catalog =
    [ ( "PW-500", "Pallet wrap, 500 mm", 1890 )
    , ( "EP-120", "Euro pallet", 2450 )
    , ( "LR-040", "Label printer ribbon", 990 )
    , ( "CT-300", "Cable ties, 300 mm", 450 )
    , ( "SG-009", "Safety gloves, size 9", 1290 )
    , ( "TB-210", "Tape dispenser", 3290 )
    , ( "BX-445", "Carton 400x400x300", 780 )
    , ( "FM-018", "Foam insert, 18 mm", 540 )
    , ( "SC-770", "Barcode scanner", 41900 )
    , ( "RL-310", "Roll cage trolley", 118000 )
    , ( "HV-002", "High-vis vest", 1590 )
    , ( "ST-050", "Strapping band, 50 m", 2190 )
    ]


pick : List a -> Int -> Maybe a
pick items n =
    items |> List.drop (modBy (max 1 (List.length items)) n) |> List.head


makeOrder : Date -> Int -> Detail
makeOrder today n =
    let
        age =
            modBy 100 (n * 53 + 7)

        created =
            Date.addDays -age today

        due =
            Date.addDays (3 + modBy 12 (n * 7)) created

        status =
            if age > 60 then
                case modBy 9 n of
                    0 ->
                        Cancelled

                    1 ->
                        Shipped

                    _ ->
                        Delivered

            else if age > 30 then
                case modBy 6 n of
                    0 ->
                        Cancelled

                    1 ->
                        Packed

                    2 ->
                        Delivered

                    _ ->
                        Shipped

            else if age > 12 then
                case modBy 5 n of
                    0 ->
                        Picking

                    1 ->
                        Packed

                    2 ->
                        Shipped

                    3 ->
                        Received

                    _ ->
                        Picking

            else
                case modBy 4 n of
                    0 ->
                        Packed

                    1 ->
                        Picking

                    _ ->
                        Received

        assignee =
            if status == Received && modBy 3 n /= 0 then
                Nothing

            else
                pick Domain.assignees (n * 3 + age)

        lines =
            List.range 0 (modBy 4 (n * 5))
                |> List.filterMap
                    (\k ->
                        pick catalog (n * 7 + k * 5)
                            |> Maybe.map
                                (\( sku, name, unit ) ->
                                    { sku = sku
                                    , name = name
                                    , quantity = 1 + modBy 9 (n + k * 3)
                                    , unitMinor = unit
                                    }
                                )
                    )

        total =
            List.sum (List.map (\l -> l.quantity * l.unitMinor) lines)

        -- some orders are big, so that "High value" has something to find
        totalMinor =
            if modBy 11 n == 0 then
                total * 12

            else
                total

        scaledLines =
            if modBy 11 n == 0 then
                List.map (\l -> { l | quantity = l.quantity * 12 }) lines

            else
                lines

        start =
            Date.toPosix Time.utc created |> Time.posixToMillis |> (+) (8 * 3600000)

        stamp hours =
            Time.millisToPosix (start + hours * 3600000)

        steps =
            pathTo status

        history =
            steps
                |> List.indexedMap
                    (\k s ->
                        { id = "h" ++ String.fromInt n ++ "-" ++ String.fromInt k
                        , at = stamp (k * 20)
                        , by =
                            if k == 0 then
                                "Web shop"

                            else
                                pick Domain.assignees (n + k) |> Maybe.withDefault "System"
                        , text =
                            if k == 0 then
                                "Order received"

                            else
                                "Status changed to " ++ Domain.statusLabel s
                        , tone = Domain.statusTone s
                        }
                    )
                |> List.reverse

        notes =
            if modBy 4 n == 0 then
                [ { id = n * 2
                  , at = stamp 3
                  , by = pick Domain.assignees (n + 2) |> Maybe.withDefault "System"
                  , text = "Customer asked for delivery before noon."
                  }
                ]

            else
                []
    in
    { summary =
        { id = OrderId n
        , number = Domain.orderNumber (OrderId n)
        , customer = pick customerNames (n * 5 + age) |> Maybe.withDefault "Unknown"
        , status = status
        , created = created
        , due = due
        , totalMinor = totalMinor
        , assignee = assignee
        }
    , lines = scaledLines
    , history = history
    , notes = notes
    }


{-| The statuses an order has been through on its way to the given one.
-}
pathTo : Status -> List Status
pathTo status =
    case status of
        Received ->
            [ Received ]

        Picking ->
            [ Received, Picking ]

        Packed ->
            [ Received, Picking, Packed ]

        Shipped ->
            [ Received, Picking, Packed, Shipped ]

        Delivered ->
            [ Received, Picking, Packed, Shipped, Delivered ]

        Cancelled ->
            [ Received, Cancelled ]



-- READING


{-| One page of the orders that match the rule and the search, in the order asked for.
-}
list : Date -> Db -> Request -> Result Remote.Problem Page
list today db request =
    if String.toLower request.query.search == "fail" then
        Err (Remote.problem Remote.server |> Remote.withDetail "The search service did not answer.")

    else
        let
            words =
                String.words request.query.search

            matching =
                db.orders
                    |> Dict.values
                    |> List.map .summary
                    |> List.filter (Rule.matches today Domain.fields request.rule)
                    |> List.filter (matchesWords words)
                    |> sortBy request.query.sort
        in
        Ok
            { rows =
                matching
                    |> List.drop ((request.query.page - 1) * request.query.pageSize)
                    |> List.take request.query.pageSize
            , total = List.length matching
            }


matchesWords : List String -> Summary -> Bool
matchesWords words order =
    let
        text =
            String.join " " [ order.number, order.customer, Domain.statusLabel order.status, Maybe.withDefault "" order.assignee ]
    in
    List.all (\word -> Search.matches word text) words


sortBy : List ( Table.ColumnId, Table.Direction ) -> List Summary -> List Summary
sortBy levels orders =
    -- the primary level is first and List.sortWith is stable, so sort by the last level first
    -- the order number is the last resort, so that pages never overlap
    List.foldr
        (\( column, direction ) rows -> List.sortWith (compareOn column direction) rows)
        orders
        (levels ++ [ ( Table.columnId "number", Table.Ascending ) ])


compareOn : Table.ColumnId -> Table.Direction -> Summary -> Summary -> Basics.Order
compareOn column direction a b =
    let
        idNumber (OrderId n) =
            n

        order =
            case Table.columnName column of
                "customer" ->
                    compare a.customer b.customer

                "status" ->
                    compare (statusRank a.status) (statusRank b.status)

                "assignee" ->
                    compare (Maybe.withDefault "~" a.assignee) (Maybe.withDefault "~" b.assignee)

                "created" ->
                    Date.compare a.created b.created

                "due" ->
                    Date.compare a.due b.due

                "total" ->
                    compare a.totalMinor b.totalMinor

                _ ->
                    compare (idNumber a.id) (idNumber b.id)
    in
    case direction of
        Table.Ascending ->
            order

        Table.Descending ->
            case order of
                LT ->
                    GT

                GT ->
                    LT

                EQ ->
                    EQ


statusRank : Status -> Int
statusRank status =
    Domain.allStatuses
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, s ) -> s == status)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


detail : Db -> OrderId -> Result Remote.Problem Detail
detail db (OrderId n) =
    Dict.get n db.orders
        |> Result.fromMaybe (Remote.problem Remote.notFound |> Remote.withDetail ("There is no order " ++ Domain.orderNumber (OrderId n) ++ "."))


{-| For the command palette: a few orders by number or customer.
-}
searchOrders : Db -> String -> Result Remote.Problem (List Summary)
searchOrders db query =
    if String.toLower (String.trim query) == "fail" then
        Err (Remote.problem Remote.timeout)

    else
        Ok
            (db.orders
                |> Dict.values
                |> List.map .summary
                |> List.filter (matchesWords (String.words query))
                |> List.take 8
            )


savedViews : Db -> List SavedView
savedViews db =
    db.views


saveViews : List SavedView -> Db -> ( Db, Result Remote.Problem () )
saveViews views db =
    ( { db | views = views }, Ok () )



-- CHANGING


changeStatus : Time.Posix -> OrderId -> Status -> Db -> ( Db, Result Remote.Problem Detail )
changeStatus now id to db =
    case detail db id of
        Err problem ->
            ( db, Err problem )

        Ok current ->
            if List.member to (Domain.nextSteps current.summary.status) then
                let
                    next =
                        moveTo now to current
                in
                ( putDetail next db, Ok next )

            else
                ( db
                , Err
                    (Remote.problem Remote.conflict
                        |> Remote.withTitle "Not an allowed step"
                        |> Remote.withDetail
                            (Domain.orderNumber id
                                ++ " is "
                                ++ Domain.statusLabel current.summary.status
                                ++ " and cannot become "
                                ++ Domain.statusLabel to
                                ++ "."
                            )
                    )
                )


moveTo : Time.Posix -> Status -> Detail -> Detail
moveTo now to current =
    let
        summary =
            current.summary

        entry =
            { id = "h" ++ String.fromInt (Time.posixToMillis now) ++ Domain.statusLabel to
            , at = now
            , by = Domain.currentUser
            , text = "Status changed to " ++ Domain.statusLabel to
            , tone = Domain.statusTone to
            }
    in
    { current
        | summary = { summary | status = to }
        , history = entry :: current.history
    }


putDetail : Detail -> Db -> Db
putDetail next db =
    let
        (OrderId n) =
            next.summary.id
    in
    { db | orders = Dict.insert n next db.orders }


addNote : Time.Posix -> OrderId -> String -> Db -> ( Db, Result Remote.Problem Detail )
addNote now id text db =
    case detail db id of
        Err problem ->
            ( db, Err problem )

        Ok current ->
            if String.length (String.trim text) < 3 then
                ( db, Err (Remote.problem Remote.validation |> Remote.withDetail "A note needs at least three characters.") )

            else
                let
                    note =
                        { id = db.nextNoteId, at = now, by = Domain.currentUser, text = String.trim text }

                    next =
                        { current | notes = note :: current.notes }
                in
                ( putDetail next { db | nextNoteId = db.nextNoteId + 1 }, Ok next )


resolve : Date -> Db -> Target -> List OrderId
resolve today db target =
    case target of
        Ids ids ->
            ids

        AllMatching request except ->
            db.orders
                |> Dict.values
                |> List.map .summary
                |> List.filter (Rule.matches today Domain.fields request.rule)
                |> List.filter (matchesWords (String.words request.query.search))
                |> List.map .id
                |> List.filter (\id -> not (List.member id except))


{-| Packing moves orders that are in Picking to Packed; the others are skipped.
-}
pack : Date -> Time.Posix -> Target -> Db -> ( Db, Result Remote.Problem BulkOutcome )
pack today now target db =
    applyEach today now target db <|
        \order ->
            if order.summary.status == Picking then
                Just (moveTo now Packed order)

            else
                Nothing


assign : Date -> Time.Posix -> Target -> String -> Db -> ( Db, Result Remote.Problem BulkOutcome )
assign today now target person db =
    applyEach today now target db <|
        \order ->
            if List.member order.summary.status [ Delivered, Cancelled ] || order.summary.assignee == Just person then
                Nothing

            else
                let
                    summary =
                        order.summary

                    entry =
                        { id = "a" ++ String.fromInt (Time.posixToMillis now) ++ String.fromInt (idOf order)
                        , at = now
                        , by = Domain.currentUser
                        , text = "Assigned to " ++ person
                        , tone = Neutral
                        }
                in
                Just { order | summary = { summary | assignee = Just person }, history = entry :: order.history }


idOf : Detail -> Int
idOf order =
    let
        (OrderId n) =
            order.summary.id
    in
    n


applyEach : Date -> Time.Posix -> Target -> Db -> (Detail -> Maybe Detail) -> ( Db, Result Remote.Problem BulkOutcome )
applyEach today _ target db change =
    let
        ids =
            resolve today db target

        step (OrderId n) ( store, outcome ) =
            case Dict.get n store of
                Nothing ->
                    ( store, { outcome | skipped = outcome.skipped + 1 } )

                Just order ->
                    case change order of
                        Just next ->
                            ( Dict.insert n next store, { outcome | changed = outcome.changed + 1 } )

                        Nothing ->
                            ( store, { outcome | skipped = outcome.skipped + 1 } )

        ( orders, result ) =
            List.foldl step ( db.orders, { changed = 0, skipped = 0 } ) ids
    in
    ( { db | orders = orders }, Ok result )


empty : Db
empty =
    { orders = Dict.empty, views = [], nextNoteId = 1000 }


withViews : List SavedView -> Db -> Db
withViews views db =
    { db | views = views }


{-| The selected orders as CSV text: how many and the file content.
-}
exportCsv : Date -> Target -> Db -> Result Remote.Problem ( Int, String )
exportCsv day target db =
    let
        orders =
            resolve day db target
                |> List.filterMap (\(OrderId n) -> Dict.get n db.orders)
                |> List.map .summary

        cell text =
            "\"" ++ String.replace "\"" "\"\"" text ++ "\""

        line order =
            [ order.number
            , order.customer
            , Domain.statusLabel order.status
            , Maybe.withDefault "" order.assignee
            , Date.toIso order.created
            , Date.toIso order.due
            , String.fromFloat (toFloat order.totalMinor / 100)
            ]
                |> List.map cell
                |> String.join ","
    in
    Ok
        ( List.length orders
        , String.join "\n" (String.join "," [ "Order", "Customer", "Status", "Assigned to", "Created", "Due", "Total" ] :: List.map line orders) ++ "\n"
        )
