module Backend exposing
    ( Db
    , Packing
    , Page
    , Request
    , Target(..)
    , addNote
    , assign
    , changeStatus
    , get
    , init
    , pack
    , people
    , search
    , setViews
    )

{-| The dummy backend: plain synchronous functions over an in-memory database.
`Api` puts the delay and the failures in front of them.
-}

import Domain exposing (..)
import Klar.Date as Date exposing (Date)
import Klar.Rule as Rule exposing (Rule)
import Klar.SavedViews as SavedViews exposing (SavedView)
import Klar.Theme exposing (Tone(..))
import Time


type alias Db =
    { today : Date
    , now : Time.Posix
    , orders : List Detail
    , views : List SavedView
    , nextNoteId : Int
    }


type alias Request =
    { rule : Rule
    , search : String
    , sort : List ( String, Bool )
    , page : Int
    , pageSize : Int
    }


type alias Page =
    { rows : List Summary
    , total : Int
    }


{-| What a bulk action applies to: the listed orders, or everything that matches a
request except some.
-}
type Target
    = Ids (List OrderId)
    | AllMatching Request (List OrderId)


type alias Packing =
    { changed : Int
    , skipped : Int
    }


people : List Person
people =
    [ { id = PersonId 1, name = "Ada Lovelace" }
    , { id = PersonId 2, name = "Grace Hopper" }
    , { id = PersonId 3, name = "Alan Turing" }
    , { id = PersonId 4, name = "Katherine Johnson" }
    , { id = PersonId 5, name = "Edsger Dijkstra" }
    ]


customers : List String
customers =
    [ "Northwind Traders"
    , "Contoso Retail"
    , "Fabrikam Supply"
    , "Tailspin Goods"
    , "Wingtip Wholesale"
    , "Adventure Works"
    , "Litware Outdoor"
    , "Proseware Home"
    , "Lucerne Foods"
    , "Margie's Travel"
    , "Alpine Ski House"
    , "Blue Yonder Freight"
    , "Coho Winery"
    , "Fourth Coffee"
    , "Graphic Design Institute"
    , "Humongous Insurance"
    , "Nod Publishers"
    , "Southridge Video"
    , "Trey Research"
    , "Wide World Importers"
    , "Woodgrove Market"
    , "Relecloud Tools"
    , "VanArsdel Paper"
    , "Bellows College"
    , "Consolidated Messenger"
    ]


products : List ( String, String, Float )
products =
    [ ( "BX-100", "Shipping box, small", 1.9 )
    , ( "BX-200", "Shipping box, large", 3.4 )
    , ( "TP-010", "Packing tape, 50 m", 4.25 )
    , ( "LB-310", "Label roll, 500 pcs", 12.0 )
    , ( "PL-021", "Pallet wrap, 20 kg", 38.5 )
    , ( "GL-500", "Work gloves, pair", 6.8 )
    , ( "SH-440", "Steel shelf, 180 cm", 119.0 )
    , ( "TR-900", "Hand trolley", 149.0 )
    , ( "SC-120", "Barcode scanner", 289.0 )
    , ( "PR-330", "Thermal printer", 435.0 )
    , ( "CR-050", "Cable ties, 100 pcs", 3.1 )
    , ( "BG-070", "Padded envelope, 50 pcs", 22.0 )
    ]


init : Date -> Time.Posix -> Db
init today now =
    { today = today
    , now = now
    , orders = generate today now 1200
    , views =
        [ SavedViews.savedView "My open orders" myOpen
            |> SavedViews.withNote "Assigned to me and not yet shipped"
            |> SavedViews.asDefault
        , SavedViews.savedView "Late" late
            |> SavedViews.withNote "Past the due date and not shipped"
        , SavedViews.savedView "High value" highValue
            |> SavedViews.withNote "Total of 1,000 or more"
        ]
    , nextNoteId = 1000
    }


myOpen : Rule
myOpen =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children =
            [ Rule.ConditionRule { id = 1, field = "assignee", operator = Rule.Is, values = [ personIdToString me ] }
            , Rule.ConditionRule { id = 2, field = "status", operator = Rule.IsAnyOf, values = [ "new", "picking", "packed" ] }
            ]
        }


late : Rule
late =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children = [ Rule.ConditionRule { id = 1, field = "late", operator = Rule.IsTrue, values = [] } ]
        }


highValue : Rule
highValue =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children = [ Rule.ConditionRule { id = 1, field = "total", operator = Rule.GreaterOrEqual, values = [ "1000" ] } ]
        }



-- GENERATING DATA


next : Int -> Int
next seed =
    modBy 2147483647 (seed * 48271)


pick : List a -> Int -> Maybe a
pick list n =
    list |> List.drop (modBy (List.length list) n) |> List.head



-- KLAR GAP: Klar.Date has no way back to a Time.Posix (only fromPosix), so the dummy backend counts days itself


at : Date -> Int -> Time.Posix
at date hours =
    Time.millisToPosix ((Date.toEpochDay date * 24 + hours) * 3600000)


generate : Date -> Time.Posix -> Int -> List Detail
generate today now count =
    List.range 0 (count - 1)
        |> List.foldl
            (\i ( seed, acc ) ->
                let
                    ( detail, seed1 ) =
                        generateOne today now i seed
                in
                ( seed1, detail :: acc )
            )
            ( 4242, [] )
        |> Tuple.second


generateOne : Date -> Time.Posix -> Int -> Int -> ( Detail, Int )
generateOne today _ i seed0 =
    let
        s1 =
            next seed0

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

        age =
            1 + (count - 1 - i) * 55 // count + modBy 3 s1

        count =
            1200

        created =
            Date.addDays -age today

        due =
            Date.addDays (3 + modBy 8 s2) created

        roll =
            modBy 100 s3

        status =
            if age > 30 then
                if roll < 70 then
                    Delivered

                else if roll < 90 then
                    Shipped

                else
                    Cancelled

            else if age > 12 then
                if roll < 30 then
                    Delivered

                else if roll < 70 then
                    Shipped

                else if roll < 85 then
                    Packed

                else if roll < 95 then
                    Picking

                else
                    Cancelled

            else if roll < 35 then
                New

            else if roll < 65 then
                Picking

            else if roll < 85 then
                Packed

            else if roll < 95 then
                Shipped

            else
                Cancelled

        lineCount =
            1 + modBy 5 s4

        lines =
            List.range 0 (lineCount - 1)
                |> List.filterMap
                    (\k ->
                        pick products (s5 + k * 7)
                            |> Maybe.map
                                (\( sku, name, price ) ->
                                    { sku = sku, name = name, quantity = 1 + modBy 12 (s6 + k * 13), unitPrice = price }
                                )
                    )
                |> dedupe

        total =
            lines |> List.map (\l -> toFloat l.quantity * l.unitPrice) |> List.sum |> (\t -> toFloat (round (t * 100)) / 100)

        assignee =
            if status == New && modBy 100 s6 < 45 then
                Nothing

            else
                pick people s6 |> Maybe.map .id

        customer =
            pick customers s2 |> Maybe.withDefault "Unknown"

        id =
            OrderId (10001 + i)

        path =
            case status of
                Cancelled ->
                    [ New, Cancelled ]

                New ->
                    [ New ]

                Picking ->
                    [ New, Picking ]

                Packed ->
                    [ New, Picking, Packed ]

                Shipped ->
                    [ New, Picking, Packed, Shipped ]

                Delivered ->
                    [ New, Picking, Packed, Shipped, Delivered ]

        history =
            path
                |> List.indexedMap
                    (\k st ->
                        { id = "h-" ++ String.fromInt (10001 + i) ++ "-" ++ String.fromInt k
                        , at = at created (9 + k * 20 + modBy 5 (s3 + k))
                        , by =
                            if k == 0 then
                                customer

                            else
                                pick people (s6 + k) |> Maybe.map .name |> Maybe.withDefault "System"
                        , text =
                            if k == 0 then
                                "Order placed"

                            else
                                "Status changed to " ++ statusLabel st
                        , tone = statusTone st
                        }
                    )
                |> List.reverse

        notes =
            if modBy 4 s5 == 0 then
                [ { id = 1 + i
                  , at = at created 11
                  , by = "Grace Hopper"
                  , text = "Customer asked for delivery before noon."
                  }
                ]

            else
                []
    in
    ( { summary =
            { id = id
            , customer = customer
            , status = status
            , created = created
            , due = due
            , total = total
            , assignee = assignee
            , lineCount = List.length lines
            }
      , lines = lines
      , history = history
      , notes = notes
      }
    , s6
    )


dedupe : List Line -> List Line
dedupe lines =
    List.foldl
        (\l acc ->
            if List.any (\x -> x.sku == l.sku) acc then
                acc

            else
                acc ++ [ l ]
        )
        []
        lines



-- QUERIES


search : Db -> Request -> Page
search db request =
    let
        fieldList =
            fields db.today people

        words =
            request.search |> String.toLower |> String.words

        matchesSearch s =
            let
                haystack =
                    String.toLower (orderIdToString s.id ++ " " ++ s.customer ++ " " ++ statusLabel s.status ++ " " ++ assigneeName people s.assignee)
            in
            List.all (\w -> String.contains w haystack) words

        sorted =
            db.orders
                |> List.map .summary
                |> List.filter (Rule.matches db.today fieldList request.rule)
                |> List.filter matchesSearch
                |> sortRows request.sort

        start =
            (request.page - 1) * request.pageSize
    in
    { rows = sorted |> List.drop start |> List.take request.pageSize
    , total = List.length sorted
    }


sortRows : List ( String, Bool ) -> List Summary -> List Summary
sortRows sort rows =
    let
        levels =
            if List.isEmpty sort then
                [ ( "created", False ) ]

            else
                sort

        compareLevel ( column, ascending ) a b =
            let
                order =
                    compareColumn column a b
            in
            if ascending then
                order

            else
                flip order

        compareAll a b =
            List.foldl
                (\level acc ->
                    if acc == EQ then
                        compareLevel level a b

                    else
                        acc
                )
                EQ
                levels
                |> (\o ->
                        if o == EQ then
                            compare (orderIdToString b.id) (orderIdToString a.id)

                        else
                            o
                   )
    in
    List.sortWith compareAll rows


flip : Order -> Order
flip order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT


compareColumn : String -> Summary -> Summary -> Order
compareColumn column a b =
    case column of
        "number" ->
            case ( a.id, b.id ) of
                ( OrderId x, OrderId y ) ->
                    compare x y

        "customer" ->
            compare (String.toLower a.customer) (String.toLower b.customer)

        "status" ->
            compare (statusIndex a.status) (statusIndex b.status)

        "created" ->
            Date.compare a.created b.created

        "due" ->
            Date.compare a.due b.due

        "total" ->
            compare a.total b.total

        "assignee" ->
            compare (assigneeName people a.assignee) (assigneeName people b.assignee)

        _ ->
            EQ


statusIndex : Status -> Int
statusIndex status =
    allStatuses |> List.indexedMap Tuple.pair |> List.filter (\( _, s ) -> s == status) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0


get : Db -> OrderId -> Maybe Detail
get db id =
    db.orders |> List.filter (\d -> d.summary.id == id) |> List.head



-- CHANGES


update : OrderId -> (Detail -> Detail) -> Db -> Db
update id change db =
    { db
        | orders =
            List.map
                (\d ->
                    if d.summary.id == id then
                        change d

                    else
                        d
                )
                db.orders
    }


changeStatus : Db -> OrderId -> Status -> Result String Db
changeStatus db id to =
    case get db id of
        Nothing ->
            Err "The order does not exist."

        Just detail ->
            if List.member to (allowedNext detail.summary.status) then
                Ok (update id (withStatus db to) db)

            else
                Err ("An order that is " ++ String.toLower (statusLabel detail.summary.status) ++ " cannot become " ++ String.toLower (statusLabel to) ++ ".")


withStatus : Db -> Status -> Detail -> Detail
withStatus db to detail =
    let
        summary =
            detail.summary

        entry =
            { id = "h-" ++ orderIdToString summary.id ++ "-" ++ String.fromInt (List.length detail.history)
            , at = db.now
            , by = "Ada Lovelace"
            , text = "Status changed to " ++ statusLabel to
            , tone = statusTone to
            }
    in
    { detail | summary = { summary | status = to }, history = entry :: detail.history }


targetIds : Db -> Target -> List OrderId
targetIds db target =
    case target of
        Ids ids ->
            ids

        AllMatching request except ->
            search db { request | page = 1, pageSize = 1000000 }
                |> .rows
                |> List.map .id
                |> List.filter (\id -> not (List.member id except))


assign : Db -> Target -> PersonId -> Db
assign db target person =
    List.foldl
        (\id acc ->
            update id
                (\d ->
                    let
                        summary =
                            d.summary

                        entry =
                            { id = "h-" ++ orderIdToString id ++ "-" ++ String.fromInt (List.length d.history)
                            , at = db.now
                            , by = "Ada Lovelace"
                            , text = "Assigned to " ++ assigneeName people (Just person)
                            , tone = Neutral
                            }
                    in
                    { d | summary = { summary | assignee = Just person }, history = entry :: d.history }
                )
                acc
        )
        db
        (targetIds db target)


pack : Db -> Target -> ( Db, Packing )
pack db target =
    List.foldl
        (\id ( acc, counts ) ->
            case changeStatus acc id Packed of
                Ok changed ->
                    ( changed, { counts | changed = counts.changed + 1 } )

                Err _ ->
                    ( acc, { counts | skipped = counts.skipped + 1 } )
        )
        ( db, { changed = 0, skipped = 0 } )
        (targetIds db target)


addNote : Db -> OrderId -> String -> Result String Db
addNote db id text =
    if String.isEmpty (String.trim text) then
        Err "A note cannot be empty."

    else
        case get db id of
            Nothing ->
                Err "The order does not exist."

            Just _ ->
                let
                    note =
                        { id = db.nextNoteId, at = db.now, by = "Ada Lovelace", text = String.trim text }
                in
                Ok
                    (update id (\d -> { d | notes = note :: d.notes }) { db | nextNoteId = db.nextNoteId + 1 })


setViews : Db -> List SavedView -> Db
setViews db views =
    { db | views = views }
