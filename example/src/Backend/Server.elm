module Backend.Server exposing
    ( changeStatus
    , createOrder
    , deleteOrder
    , findOrder
    , listProducts
    , lookups
    , queryOrders
    , summary
    , updateOrder
    )

{-| The dummy server: the logic a real backend would have, as plain synchronous
functions over `Database`.

Each function takes the database and answers with a result (and, for changes,
the new database). `Api` decides when the answer arrives and whether the
"network" lets it through.

-}

import Api.Types
    exposing
        ( Activity
        , ActivityKind(..)
        , ApiError(..)
        , CountryCode
        , FieldError
        , Lookups
        , Order
        , OrderId
        , OrderInput
        , OrderQuery
        , OrderStatus(..)
        , OwnerId
        , Page
        , Priority(..)
        , Product
        , Summary
        , WarehouseId
        , allowedNextStatuses
        , countryCode
        , countryCodeText
        , isEditable
        , orderId
        , orderIdText
        , orderStatusLabel
        , ownerIdText
        , warehouseIdText
        )
import Backend.Database exposing (Database)
import Backend.Generate as Generate
import Dict
import Klar.Date as Date
import Klar.Locale as Locale
import Klar.Search as Search
import Klar.Validate as Validate
import Time



-- READING


{-| One page of orders, searched, filtered by status and sorted. A page past the
end is the last page.
-}
queryOrders : OrderQuery -> Database -> Page Order
queryOrders query db =
    let
        pageSize =
            max 1 query.pageSize

        byStatus =
            if List.isEmpty query.statuses then
                db.orders

            else
                List.filter (\o -> List.member o.status query.statuses) db.orders

        searchText o =
            String.join " " [ orderIdText o.id, o.customer, o.city, o.email, Maybe.withDefault "" (Maybe.map ownerName o.owner), o.note ]

        searched =
            if String.isEmpty (String.trim query.search) then
                byStatus

            else
                Search.filter searchText query.search byStatus

        sorted =
            case query.sort of
                Just ( key, ascending ) ->
                    List.sortWith (compareOrders key ascending) searched

                Nothing ->
                    searched

        total =
            List.length sorted

        pageCount =
            max 1 ((total + pageSize - 1) // pageSize)

        page =
            clamp 1 pageCount query.page
    in
    { rows = sorted |> List.drop ((page - 1) * pageSize) |> List.take pageSize
    , total = total
    , page = page
    , pageSize = pageSize
    }


{-| The names of the reference data, looked up by the text of the id (an id is not
`comparable`, so it cannot be a key itself).
-}
countryNames : Dict.Dict String String
countryNames =
    Generate.countries |> List.map (\c -> ( countryCodeText c.code, c.name )) |> Dict.fromList


countryName : CountryCode -> String
countryName code =
    Dict.get (countryCodeText code) countryNames |> Maybe.withDefault (countryCodeText code)


warehouseNames : Dict.Dict String String
warehouseNames =
    Generate.warehouses |> List.map (\w -> ( warehouseIdText w.id, w.name )) |> Dict.fromList


warehouseName : WarehouseId -> String
warehouseName id =
    Dict.get (warehouseIdText id) warehouseNames |> Maybe.withDefault (warehouseIdText id)


ownerNames : Dict.Dict String String
ownerNames =
    Generate.owners |> List.map (\o -> ( ownerIdText o.id, o.name )) |> Dict.fromList


ownerName : OwnerId -> String
ownerName id =
    Dict.get (ownerIdText id) ownerNames |> Maybe.withDefault (ownerIdText id)


type SortKey
    = Text String
    | Number Float
    | Missing


sortKey : String -> Order -> SortKey
sortKey key o =
    case key of
        "id" ->
            Text (orderIdText o.id)

        "customer" ->
            Text (Search.normalize o.customer)

        "country" ->
            -- the table shows the name, so the name decides the order, not the code
            Text (Search.normalize (countryName o.country))

        "city" ->
            Text (Search.normalize o.city)

        "status" ->
            Number (toFloat (statusRank o.status))

        "priority" ->
            Number (toFloat (priorityRank o.priority))

        "owner" ->
            case o.owner of
                Just id ->
                    Text (Search.normalize (ownerName id))

                Nothing ->
                    Missing

        "created" ->
            Number (toFloat (Date.toEpochDay o.created))

        "due" ->
            Number (toFloat (Date.toEpochDay o.due))

        "lines" ->
            Number (toFloat o.lines)

        "total" ->
            Number o.total

        "warehouse" ->
            Text (Search.normalize (warehouseName o.warehouse))

        _ ->
            Text (orderIdText o.id)


{-| Sorting by a column. Orders without a value come last in both directions,
and ties are broken by the order id so the order is always the same.
-}
compareOrders : String -> Bool -> Order -> Order -> Basics.Order
compareOrders key ascending a b =
    case ( sortKey key a, sortKey key b ) of
        ( Missing, Missing ) ->
            compare (orderIdText a.id) (orderIdText b.id)

        ( Missing, _ ) ->
            GT

        ( _, Missing ) ->
            LT

        ( x, y ) ->
            let
                direction =
                    if ascending then
                        identity

                    else
                        flipOrder
            in
            case direction (compareKeys x y) of
                EQ ->
                    compare (orderIdText a.id) (orderIdText b.id)

                other ->
                    other


compareKeys : SortKey -> SortKey -> Basics.Order
compareKeys a b =
    case ( a, b ) of
        ( Text x, Text y ) ->
            compare x y

        ( Number x, Number y ) ->
            compare x y

        _ ->
            EQ


flipOrder : Basics.Order -> Basics.Order
flipOrder order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT


statusRank : OrderStatus -> Int
statusRank status =
    case status of
        Draft ->
            0

        Confirmed ->
            1

        Picking ->
            2

        Shipped ->
            3

        Delivered ->
            4

        Cancelled ->
            5


priorityRank : Priority -> Int
priorityRank priority =
    case priority of
        Low ->
            0

        Normal ->
            1

        High ->
            2

        Urgent ->
            3


findOrder : OrderId -> Database -> Result ApiError Order
findOrder id db =
    db.orders
        |> List.filter (\o -> o.id == id)
        |> List.head
        |> Result.fromMaybe NotFound


listProducts : Database -> List Product
listProducts db =
    db.products


lookups : Database -> Lookups
lookups db =
    { countries = Generate.countries
    , warehouses = Generate.warehouses
    , owners = Generate.owners
    , customers = Generate.customers
    }



-- CHANGING


createOrder : OrderInput -> Database -> ( Database, Result ApiError Order )
createOrder input db =
    case validate True input of
        [] ->
            case ( ( input.due, input.lines, input.total ), ( input.country, input.warehouse ) ) of
                ( ( Just due, Just lines, Just total ), ( Just country, Just warehouse ) ) ->
                    let
                        duplicate =
                            db.orders
                                |> List.filter (\o -> o.customer == String.trim input.customer && o.due == due && o.total == total)
                                |> List.head
                    in
                    case duplicate of
                        Just existing ->
                            ( db, Err (Conflict ("An identical order already exists: " ++ orderIdText existing.id ++ ".")) )

                        Nothing ->
                            let
                                created =
                                    { id = orderId ("ORD-" ++ String.fromInt db.nextNumber)
                                    , customer = String.trim input.customer
                                    , email = String.trim input.email
                                    , country = country
                                    , city = String.trim input.city
                                    , status = Draft
                                    , priority = input.priority
                                    , owner = input.owner
                                    , warehouse = warehouse
                                    , created = Generate.today
                                    , due = due
                                    , delivered = Nothing
                                    , lines = lines
                                    , total = total
                                    , note = String.trim input.note
                                    }
                            in
                            ( { db | orders = db.orders ++ [ created ], nextNumber = db.nextNumber + 1 }
                            , Ok created
                            )

                _ ->
                    ( db, Err (ValidationFailed [ { field = "order-customer", message = "Fill in the whole form." } ]) )

        errors ->
            ( db, Err (ValidationFailed errors) )


updateOrder : OrderId -> OrderInput -> Database -> ( Database, Result ApiError Order )
updateOrder id input db =
    case findOrder id db of
        Err error ->
            ( db, Err error )

        Ok existing ->
            if not (isEditable existing.status) then
                ( db, Err (Conflict ("An order that is " ++ String.toLower (statusText existing.status) ++ " can no longer be edited.")) )

            else
                case validate False input of
                    [] ->
                        case ( ( input.due, input.lines, input.total ), ( input.country, input.warehouse ) ) of
                            ( ( Just due, Just lines, Just total ), ( Just country, Just warehouse ) ) ->
                                let
                                    updated =
                                        { existing
                                            | customer = String.trim input.customer
                                            , email = String.trim input.email
                                            , country = country
                                            , city = String.trim input.city
                                            , priority = input.priority
                                            , owner = input.owner
                                            , warehouse = warehouse
                                            , due = due
                                            , lines = lines
                                            , total = total
                                            , note = String.trim input.note
                                        }
                                in
                                ( replace updated db, Ok updated )

                            _ ->
                                ( db, Err (ValidationFailed [ { field = "order-customer", message = "Fill in the whole form." } ]) )

                    errors ->
                        ( db, Err (ValidationFailed errors) )


{-| Moves an order along its life: Draft, Confirmed, Picking, Shipped,
Delivered. An order can be cancelled until it has shipped.
-}
changeStatus : OrderId -> OrderStatus -> Database -> ( Database, Result ApiError Order )
changeStatus id next db =
    case findOrder id db of
        Err error ->
            ( db, Err error )

        Ok existing ->
            if List.member next (allowedNextStatuses existing.status) then
                let
                    updated =
                        { existing
                            | status = next
                            , delivered =
                                if next == Delivered then
                                    Just Generate.today

                                else
                                    existing.delivered
                        }
                in
                ( replace updated db, Ok updated )

            else
                ( db
                , Err
                    (Conflict
                        ("An order that is "
                            ++ String.toLower (statusText existing.status)
                            ++ " cannot become "
                            ++ String.toLower (statusText next)
                            ++ "."
                        )
                    )
                )


{-| Only drafts and cancelled orders may be deleted.
-}
deleteOrder : OrderId -> Database -> ( Database, Result ApiError () )
deleteOrder id db =
    case findOrder id db of
        Err error ->
            ( db, Err error )

        Ok existing ->
            if existing.status == Draft || existing.status == Cancelled then
                ( { db | orders = List.filter (\o -> o.id /= id) db.orders }, Ok () )

            else
                ( db, Err (Conflict "Only drafts and cancelled orders can be deleted. Cancel the order first.") )


replace : Order -> Database -> Database
replace updated db =
    { db
        | orders =
            List.map
                (\o ->
                    if o.id == updated.id then
                        updated

                    else
                        o
                )
                db.orders
    }


statusText : OrderStatus -> String
statusText =
    orderStatusLabel



-- VALIDATION


{-| The checks a real server repeats even when the form has made them: the form
cannot be trusted. Field ids are the DOM ids of the form controls.
-}
validate : Bool -> OrderInput -> List FieldError
validate isNew input =
    let
        check field validators value =
            Validate.firstError Locale.default validators value
                |> Maybe.map (\message -> { field = field, message = message })

        textErrors =
            List.filterMap identity
                [ check "order-customer" [ Validate.required, Validate.minLength 2, Validate.maxLength 60 ] input.customer
                , check "order-email" [ Validate.required, Validate.email ] input.email
                , check "order-city" [ Validate.required ] input.city
                , check "order-note" [ Validate.maxLength 200 ] input.note
                ]

        countryError =
            if List.any (\c -> Just c.code == input.country) Generate.countries then
                []

            else
                [ { field = "order-country", message = "Choose a country." } ]

        warehouseError =
            if List.any (\w -> Just w.id == input.warehouse) Generate.warehouses then
                []

            else
                [ { field = "order-warehouse", message = "Choose a warehouse." } ]

        dueError =
            case input.due of
                Nothing ->
                    [ { field = "order-due", message = "Pick the due date." } ]

                Just due ->
                    if isNew && Date.compare due Generate.today == LT then
                        [ { field = "order-due", message = "The due date cannot be in the past." } ]

                    else
                        []

        linesError =
            case input.lines of
                Nothing ->
                    [ { field = "order-lines", message = "Enter the number of lines." } ]

                Just n ->
                    if n < 1 || n > 500 then
                        [ { field = "order-lines", message = "An order has between 1 and 500 lines." } ]

                    else
                        []

        totalError =
            case input.total of
                Nothing ->
                    [ { field = "order-total", message = "Enter the order total." } ]

                Just amount ->
                    if amount <= 0 then
                        [ { field = "order-total", message = "The total must be more than zero." } ]

                    else
                        []
    in
    textErrors ++ countryError ++ warehouseError ++ dueError ++ linesError ++ totalError



-- OVERVIEW


summary : Database -> Summary
summary db =
    let
        today =
            Generate.today

        isOpen o =
            o.status /= Delivered && o.status /= Cancelled

        open =
            List.filter isOpen db.orders

        overdue =
            List.filter (\o -> Date.compare o.due today == LT) open

        recent =
            List.filter (\o -> Date.diffDays o.created today < 30 && o.status /= Cancelled) db.orders

        delivered =
            List.filterMap (\o -> Maybe.map (\at -> ( o, at )) o.delivered) db.orders

        onTime =
            List.filter (\( o, at ) -> Date.compare at o.due /= GT) delivered

        countBy status =
            ( status, List.length (List.filter (\o -> o.status == status) db.orders) )

        perDay =
            let
                counts =
                    List.foldl
                        (\o acc ->
                            Dict.update (Date.toEpochDay o.created) (\n -> Just (Maybe.withDefault 0 n + 1)) acc
                        )
                        Dict.empty
                        db.orders
            in
            List.range -29 0
                |> List.map
                    (\offset ->
                        let
                            day =
                                Date.addDays offset today
                        in
                        ( day, Dict.get (Date.toEpochDay day) counts |> Maybe.withDefault 0 )
                    )

        revenueByCountry =
            let
                totals =
                    List.foldl
                        (\o acc ->
                            if o.status == Cancelled then
                                acc

                            else
                                Dict.update (countryCodeText o.country) (\sum -> Just (Maybe.withDefault 0 sum + o.total)) acc
                        )
                        Dict.empty
                        db.orders
            in
            Dict.toList totals
                |> List.sortBy (\( _, sum ) -> negate sum)
                |> List.take 6
                |> List.map (\( code, sum ) -> ( countryName (countryCode code), sum ))
    in
    { orders = List.length db.orders
    , open = List.length open
    , overdue = List.length overdue
    , revenue = List.sum (List.map .total recent)
    , onTimeRate =
        if List.isEmpty delivered then
            1

        else
            toFloat (List.length onTime) / toFloat (List.length delivered)
    , byStatus = List.map countBy [ Draft, Confirmed, Picking, Shipped, Delivered, Cancelled ]
    , perDay = perDay
    , revenueByCountry = revenueByCountry
    , attention =
        open
            |> List.filter (\o -> Date.compare o.due today == LT || o.priority == Urgent)
            |> List.sortWith (compareOrders "due" True)
            |> List.take 6
    , activity = activity db
    }


{-| The latest happenings, derived from the orders: each order contributes the
event that matches its status, on a plausible hour of the day it was created.
-}
activity : Database -> List Activity
activity db =
    db.orders
        |> List.sortWith (\a b -> Date.compare b.created a.created)
        |> List.take 14
        |> List.indexedMap
            (\index o ->
                let
                    kind =
                        case o.status of
                            Shipped ->
                                OrderShipped

                            Delivered ->
                                OrderDelivered

                            Cancelled ->
                                OrderCancelled

                            _ ->
                                OrderCreated

                    minutes =
                        (index * 97 + String.length o.customer * 13) |> modBy (24 * 60)
                in
                { at = Time.millisToPosix (Date.toEpochDay o.created * 86400000 + minutes * 60000)
                , kind = kind
                , orderId = o.id
                , customer = o.customer
                }
            )
        |> List.sortBy (\a -> negate (Time.posixToMillis a.at))
