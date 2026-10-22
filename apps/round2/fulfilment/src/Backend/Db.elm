module Backend.Db exposing
    ( Db
    , addNote
    , assign
    , detail
    , init
    , lookup
    , pack
    , search
    , setShared
    , setStatus
    , setViews
    , today
    , undoPack
    )

{-| The dummy backend: an in-memory database of about 1 200 orders, made
the same way every time. Every function is synchronous; the `Api` module puts
the delay and the failures around them.
-}

import Dict exposing (Dict)
import Domain exposing (..)
import Klar.Date as Date exposing (Date)
import Klar.Remote as Remote exposing (Problem)
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews exposing (SavedView)
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Time


type alias Db =
    { orders : List OrderSummary
    , notes : Dict Int (List Note)
    , events : Dict Int (List Event)
    , views : List SavedView
    , shared : List String
    }


{-| The day the data was made for.
-}
today : Date
today =
    Date.fromParts 2026 10 22 |> Maybe.withDefault (Date.fromEpochDay 0)


init : Db
init =
    { orders = List.map makeOrder (List.range 10001 11200)
    , notes = Dict.empty
    , events = Dict.empty
    , views = seedViews
    , shared = [ "Needs picking" ]
    }



-- SEED


hash : Int -> Int -> Int
hash salt n =
    let
        a =
            modBy 2147483629 (n * 1103515 + salt * 12345 + 99991)
    in
    modBy 2147483629 (modBy 2147483629 (a * 48271) + a * 7 + salt)


rnd : Int -> Int -> Int -> Int
rnd salt n bound =
    modBy bound (hash salt n)


pick : Int -> List ( Int, a ) -> a -> a
pick r weighted fallback =
    case weighted of
        [] ->
            fallback

        ( w, value ) :: rest ->
            if r < w then
                value

            else
                pick (r - w) rest fallback


customers : List String
customers =
    List.concatMap
        (\prefix ->
            List.map (\suffix -> prefix ++ " " ++ suffix)
                [ "Logistics", "Foods", "Retail", "Supply", "Trading", "Textiles", "Hardware" ]
        )
        [ "Aurora", "Fjord", "Nordic", "Summit", "Harbor", "Cedar", "Atlas", "Orion", "Lumen", "Birch" ]


products : List ( String, Float )
products =
    [ ( "Pallet jack", 429 )
    , ( "Shelf bracket, steel", 12.5 )
    , ( "Cable ties, 100 pack", 6.9 )
    , ( "Storage crate, 40 l", 18.75 )
    , ( "Packing tape, 6 rolls", 14.2 )
    , ( "Label printer", 289 )
    , ( "Thermal labels, 1 000", 24 )
    , ( "Safety gloves, pair", 5.4 )
    , ( "Hand truck", 159 )
    , ( "Stretch film, 4 rolls", 52.3 )
    , ( "Barcode scanner", 349 )
    , ( "Work bench, 180 cm", 612 )
    , ( "LED work light", 39.9 )
    , ( "Floor marking tape", 9.75 )
    , ( "Cardboard box, 20 pack", 31 )
    , ( "Scale, 150 kg", 274 )
    ]


cities : List String
cities =
    [ "Oslo", "Bergen", "Trondheim", "Stavanger", "Tromsø", "Kristiansand" ]


linesOf : Int -> List Line
linesOf id =
    List.range 0 (rnd 1 id 5)
        |> List.map
            (\i ->
                let
                    index =
                        rnd (10 + i) id (List.length products)

                    ( name, price ) =
                        products |> List.drop index |> List.head |> Maybe.withDefault ( "Item", 1 )
                in
                { sku = "SKU-" ++ String.fromInt (1000 + index)
                , product = name
                , quantity = 1 + rnd (20 + i) id 12
                , unitPrice = price
                }
            )


makeOrder : Int -> OrderSummary
makeOrder n =
    let
        age =
            rnd 1 n 120

        created =
            Date.addDays -age today

        due =
            Date.addDays (3 + rnd 2 n 18) created

        r =
            rnd 3 n 100

        status =
            if age > 40 then
                pick r [ ( 70, Delivered ), ( 10, Cancelled ), ( 10, Shipped ) ] Picking

            else if age > 14 then
                pick r [ ( 30, Delivered ), ( 25, Shipped ), ( 15, Packed ), ( 15, Picking ), ( 8, Confirmed ) ] Cancelled

            else
                pick r [ ( 25, New ), ( 25, Confirmed ), ( 20, Picking ), ( 12, Packed ), ( 8, Shipped ), ( 4, Delivered ) ] Cancelled

        lines =
            linesOf n
    in
    { id = OrderId n
    , customer = customers |> List.drop (rnd 4 n (List.length customers)) |> List.head |> Maybe.withDefault "Unknown"
    , status = status
    , created = created
    , due = due
    , total = lines |> List.map (\l -> toFloat l.quantity * l.unitPrice) |> List.sum
    , items = lines |> List.map .quantity |> List.sum
    , assignee =
        if status == New || rnd 5 n 4 == 0 then
            Nothing

        else
            people |> List.drop (rnd 6 n (List.length people)) |> List.head
    , late = isLate due status
    }


isLate : Date -> Status -> Bool
isLate due status =
    Date.compare due today == LT && List.member status [ New, Confirmed, Picking, Packed ]


seedViews : List SavedView
seedViews =
    [ SavedViews.savedView "My open orders"
        (allOf
            [ condition "assignee" Rule.Is [ currentUser ]
            , condition "status" Rule.IsNoneOf [ "delivered", "cancelled", "shipped" ]
            ]
        )
        |> SavedViews.asDefault
    , SavedViews.savedView "Late" (allOf [ condition "late" Rule.IsTrue [] ])
    , SavedViews.savedView "High value" (allOf [ condition "total" Rule.GreaterOrEqual [ "2000" ] ])
    , SavedViews.savedView "Needs picking" (allOf [ condition "status" Rule.IsAnyOf [ "confirmed", "picking" ] ])
        |> SavedViews.withNote "Shared by Grace Hopper"
    ]


condition : String -> Rule.Operator -> List String -> Rule.Rule
condition field operator values =
    Rule.ConditionRule { id = 0, field = field, operator = operator, values = values }


allOf : List Rule.Rule -> Rule.Rule
allOf children =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children = children |> List.indexedMap (\i rule -> renumber (i + 1) rule)
        }


renumber : Int -> Rule.Rule -> Rule.Rule
renumber id rule =
    case rule of
        Rule.ConditionRule c ->
            Rule.ConditionRule { c | id = id }

        Rule.GroupRule g ->
            Rule.GroupRule { g | id = id }



-- READING


haystack : OrderSummary -> String
haystack order =
    [ orderIdToString order.id, order.customer, order.assignee |> Maybe.withDefault "", statusLabel order.status ]
        |> String.join " "
        |> String.toLower


matchesText : String -> OrderSummary -> Bool
matchesText text order =
    let
        words =
            text |> String.toLower |> String.words
    in
    List.all (\word -> String.contains word (haystack order)) words


idNumber : OrderSummary -> Int
idNumber order =
    case order.id of
        OrderId n ->
            n


compareKey : String -> OrderSummary -> OrderSummary -> Basics.Order
compareKey key a b =
    case key of
        "customer" ->
            compare a.customer b.customer

        "status" ->
            compare (statusKey a.status) (statusKey b.status)

        "created" ->
            Date.compare a.created b.created

        "due" ->
            Date.compare a.due b.due

        "total" ->
            compare a.total b.total

        "items" ->
            compare a.items b.items

        "assignee" ->
            compare (a.assignee |> Maybe.withDefault "") (b.assignee |> Maybe.withDefault "")

        _ ->
            compare (idNumber a) (idNumber b)


search : Date -> Query -> Db -> { total : Int, rows : List OrderSummary }
search day query db =
    let
        compareAll a b =
            compareLevels query.sort a b

        matching =
            db.orders
                |> List.filter (Rule.matches day fields query.rule)
                |> List.filter (matchesText query.search)
                |> List.sortWith compareAll
    in
    { total = List.length matching
    , rows =
        matching
            |> List.drop ((query.page - 1) * query.pageSize)
            |> List.take query.pageSize
    }


compareLevels : List ( String, Table.Direction ) -> OrderSummary -> OrderSummary -> Basics.Order
compareLevels levels a b =
    case levels of
        [] ->
            compare (idNumber a) (idNumber b)

        ( key, direction ) :: rest ->
            case compareKey key a b of
                EQ ->
                    compareLevels rest a b

                other ->
                    if direction == Table.Descending then
                        flip other

                    else
                        other


flip : Basics.Order -> Basics.Order
flip order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT


{-| Orders for the command palette: the first few that contain every word.
-}
lookup : String -> Db -> List OrderSummary
lookup text db =
    db.orders
        |> List.filter (matchesText text)
        |> List.take 8


detail : Int -> Db -> Maybe Detail
detail n db =
    db.orders
        |> List.filter (\o -> idNumber o == n)
        |> List.head
        |> Maybe.map
            (\order ->
                { order = order
                , email = "orders@" ++ slug order.customer ++ ".example"
                , shipTo =
                    String.fromInt (1 + rnd 7 n 98)
                        ++ " Harbour Road, "
                        ++ (cities |> List.drop (rnd 8 n (List.length cities)) |> List.head |> Maybe.withDefault "Oslo")
                , lines = linesOf n
                , history =
                    (baseHistory order ++ (Dict.get n db.events |> Maybe.withDefault []))
                        |> List.sortBy (\e -> Time.posixToMillis e.at)
                        |> List.reverse
                , notes = Dict.get n db.notes |> Maybe.withDefault []
                }
            )


slug : String -> String
slug text =
    text |> String.toLower |> String.filter Char.isAlphaNum


baseHistory : OrderSummary -> List Event
baseHistory order =
    let
        start =
            Date.toPosix Time.utc order.created |> Time.posixToMillis

        path =
            case order.status of
                Cancelled ->
                    [ New, Confirmed, Cancelled ]

                other ->
                    allStatuses
                        |> List.filter (\s -> s /= Cancelled)
                        |> takeUntil other

        n =
            idNumber order
    in
    path
        |> List.indexedMap
            (\i status ->
                { id = "e-" ++ String.fromInt n ++ "-" ++ String.fromInt i
                , at = Time.millisToPosix (start + i * (7 * 3600000 + rnd (30 + i) n 5 * 3600000) + 8 * 3600000)
                , title =
                    if status == New then
                        "Order placed"

                    else
                        "Status changed to " ++ String.toLower (statusLabel status)
                , by =
                    if status == New then
                        order.customer

                    else
                        people |> List.drop (rnd (40 + i) n (List.length people)) |> List.head |> Maybe.withDefault "System"
                , tone = statusTone status
                }
            )


takeUntil : a -> List a -> List a
takeUntil target list =
    case list of
        [] ->
            []

        x :: rest ->
            if x == target then
                [ x ]

            else
                x :: takeUntil target rest



-- WRITING


updateOrders : (OrderSummary -> Maybe OrderSummary) -> Db -> Db
updateOrders change db =
    { db | orders = List.map (\o -> change o |> Maybe.withDefault o) db.orders }


addEvent : Time.Posix -> OrderSummary -> String -> Tone -> Db -> Db
addEvent now order title tone db =
    let
        n =
            idNumber order

        existing =
            Dict.get n db.events |> Maybe.withDefault []

        event =
            { id = "x-" ++ String.fromInt n ++ "-" ++ String.fromInt (List.length existing)
            , at = now
            , title = title
            , by = currentUser
            , tone = tone
            }
    in
    { db | events = Dict.insert n (event :: existing) db.events }


findOrder : OrderId -> Db -> Maybe OrderSummary
findOrder id db =
    db.orders |> List.filter (\o -> o.id == id) |> List.head


setStatus : Time.Posix -> OrderId -> Status -> Db -> Result Problem Db
setStatus now id target db =
    case findOrder id db of
        Nothing ->
            Err (Remote.problem Remote.notFound |> Remote.withTitle "Order not found")

        Just order ->
            if List.member target (nextSteps order.status) then
                Ok
                    (db
                        |> updateOrders
                            (\o ->
                                if o.id == id then
                                    Just { o | status = target, late = isLate o.due target }

                                else
                                    Nothing
                            )
                        |> addEvent now order ("Status changed to " ++ String.toLower (statusLabel target)) (statusTone target)
                    )

            else
                Err
                    (Remote.problem Remote.conflict
                        |> Remote.withDetail ("The order is " ++ String.toLower (statusLabel order.status) ++ " now; it cannot move to " ++ String.toLower (statusLabel target) ++ ".")
                    )


{-| Marks the orders that are being picked as packed. Returns the ids that
changed and how many were skipped.
-}
pack : Time.Posix -> List OrderId -> Db -> ( Db, { packed : List OrderId, skipped : Int } )
pack now ids db =
    let
        packable =
            ids
                |> List.filterMap (\id -> findOrder id db)
                |> List.filter (\o -> o.status == Picking)
    in
    ( List.foldl
        (\order acc ->
            acc
                |> updateOrders
                    (\o ->
                        if o.id == order.id then
                            Just { o | status = Packed }

                        else
                            Nothing
                    )
                |> (\d -> addEvent now order "Status changed to packed" (statusTone Packed) d)
        )
        db
        packable
    , { packed = List.map .id packable, skipped = List.length ids - List.length packable }
    )


undoPack : Time.Posix -> List OrderId -> Db -> Db
undoPack now ids db =
    ids
        |> List.filterMap (\id -> findOrder id db)
        |> List.filter (\o -> o.status == Packed)
        |> List.foldl
            (\order acc ->
                acc
                    |> updateOrders
                        (\o ->
                            if o.id == order.id then
                                Just { o | status = Picking }

                            else
                                Nothing
                        )
                    |> addEvent now order "Packing undone" Warning
            )
            db


assign : Time.Posix -> String -> List OrderId -> Db -> Db
assign now person ids db =
    ids
        |> List.filterMap (\id -> findOrder id db)
        |> List.foldl
            (\order acc ->
                acc
                    |> updateOrders
                        (\o ->
                            if o.id == order.id then
                                Just { o | assignee = Just person }

                            else
                                Nothing
                        )
                    |> addEvent now order ("Assigned to " ++ person) Info
            )
            db


addNote : Time.Posix -> OrderId -> String -> Db -> Result Problem Db
addNote now id text db =
    if String.isEmpty (String.trim text) then
        Err (Remote.problem Remote.validation |> Remote.withDetail "A note cannot be empty.")

    else
        case id of
            OrderId n ->
                Ok
                    { db
                        | notes =
                            Dict.insert n
                                ({ at = now, by = currentUser, text = String.trim text }
                                    :: (Dict.get n db.notes |> Maybe.withDefault [])
                                )
                                db.notes
                    }


setViews : List SavedView -> Db -> Db
setViews views db =
    { db | views = views }


setShared : String -> Db -> Db
setShared name db =
    if List.member name db.shared then
        db

    else
        { db | shared = name :: db.shared }
