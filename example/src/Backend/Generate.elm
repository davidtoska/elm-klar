module Backend.Generate exposing
    ( cities
    , countries
    , customers
    , now
    , orders
    , owners
    , products
    , today
    , warehouses
    )

{-| Deterministic demo data: thousands of orders and products, generated from the
row number so they are identical on every load.

Nothing here is random in the usual sense. `rand` turns a row number and a
"salt" (which field) into a stable pseudo-random number, so a given order always
has the same customer, status and total.

-}

import Api.Types exposing (Country, Order, OrderStatus(..), Priority(..), Product, Warehouse)
import Bitwise
import Klar.Date as Date exposing (Date)
import Time



-- TIME


{-| The showcase pretends it is this day, so "overdue" and "last 30 days" mean the
same thing on every load.
-}
today : Date
today =
    Date.fromEpochDay 20746



-- 2026-10-20


now : Time.Posix
now =
    Time.millisToPosix (Date.toEpochDay today * 86400000 + 10 * 3600000)



-- ORDERS


{-| The first `count` orders, newest id last.
-}
orders : Int -> List Order
orders count =
    List.range 1 count |> List.map order


order : Int -> Order
order i =
    let
        customer =
            pick customers (rand i 1)

        ( city, country ) =
            pickPair places (rand i 2)

        statusRoll =
            modBy 100 (rand i 3)

        -- How far the order has come, as a share of its lead time. Orders older than
        -- their lead time are nearly all delivered, a few are late and still open.
        progress =
            age * 100 // leadTime

        status =
            if statusRoll >= 96 then
                Cancelled

            else if progress > 100 then
                if statusRoll < 5 then
                    Shipped

                else if statusRoll < 7 then
                    Picking

                else
                    Delivered

            else if progress > 65 then
                if statusRoll < 10 then
                    Picking

                else if statusRoll < 55 then
                    Shipped

                else
                    Delivered

            else if progress > 30 then
                if statusRoll < 25 then
                    Confirmed

                else if statusRoll < 70 then
                    Picking

                else
                    Shipped

            else if statusRoll < 25 then
                Draft

            else if statusRoll < 80 then
                Confirmed

            else
                Picking

        priorityRoll =
            modBy 100 (rand i 4)

        priority =
            if priorityRoll < 20 then
                Low

            else if priorityRoll < 75 then
                Normal

            else if priorityRoll < 95 then
                High

            else
                Urgent

        ownerRoll =
            modBy 100 (rand i 5)

        owner =
            if ownerRoll < 8 then
                Nothing

            else
                Just (pick owners (rand i 6))

        age =
            modBy 150 (rand i 7)

        created =
            Date.addDays (negate age) today

        -- Most orders are due within a month; one in five is a long-running order.
        leadTime =
            if modBy 100 (rand i 14) < 20 then
                30 + modBy 61 (rand i 8)

            else
                3 + modBy 25 (rand i 8)

        due =
            Date.addDays leadTime created

        -- Most deliveries arrive a few days early or on the day; some are a day late.
        -- Nothing is delivered in the future or before it was created.
        delivered =
            if status == Delivered then
                Just (clampDate created today (Date.addDays (modBy 8 (rand i 13) - 6) due))

            else
                Nothing

        lines =
            1 + modBy 24 (rand i 9)

        unitPrice =
            15 + toFloat (modBy 46500 (rand i 10)) / 100

        total =
            toFloat (round (toFloat lines * unitPrice * 100)) / 100
    in
    { id = "ORD-" ++ String.fromInt (10000 + i)
    , customer = customer
    , email = "orders@" ++ slug customer ++ ".example"
    , country = country
    , city = city
    , status = status
    , priority = priority
    , owner = owner
    , warehouse = .id (pickWarehouse (rand i 11))
    , created = created
    , due = due
    , delivered = delivered
    , lines = lines
    , total = total
    , note = pick notes (rand i 12)
    }


clampDate : Date -> Date -> Date -> Date
clampDate earliest latest date =
    if Date.compare date earliest == LT then
        earliest

    else if Date.compare date latest == GT then
        latest

    else
        date


notes : List String
notes =
    [ "Leave at reception."
    , "Fragile, handle with care."
    , "Call before delivery."
    , "Customer asked for a single delivery."
    , "Pallet height must stay below 1.8 m."
    , "Invoice goes to the head office."
    , "Awaiting confirmation of the delivery address."
    , "Repeat order, same as last quarter."
    , "Needs a signature on delivery."
    , ""
    ]



-- CUSTOMERS


{-| 420 company names, all different.
-}
customers : List String
customers =
    List.range 0 419 |> List.map customerName


customerName : Int -> String
customerName k =
    pick namePrefixes k
        ++ " "
        ++ pick nameSectors (k // List.length namePrefixes)
        ++ " "
        ++ pick nameSuffixes (rand k 31)


namePrefixes : List String
namePrefixes =
    [ "Aurora", "Beacon", "Cobalt", "Delta", "Ember", "Fjord", "Granite", "Harbor", "Ivory", "Juniper", "Keystone", "Lumen", "Meridian", "Nimbus", "Orchid", "Pinnacle", "Quartz", "Redwood", "Summit", "Tundra", "Umber", "Vertex", "Willow", "Xenon", "Yarrow", "Zenith", "Atlas", "Borealis", "Cedar", "Dune" ]


nameSectors : List String
nameSectors =
    [ "Logistics", "Foods", "Textiles", "Electronics", "Hardware", "Furniture", "Chemicals", "Packaging", "Marine", "Energy", "Print", "Toys", "Tools", "Outdoor" ]


nameSuffixes : List String
nameSuffixes =
    [ "Ltd", "GmbH", "Inc", "AB", "AS", "BV", "SA" ]


slug : String -> String
slug name =
    name
        |> String.toLower
        |> String.map
            (\c ->
                if Char.isAlphaNum c then
                    c

                else
                    '-'
            )


owners : List String
owners =
    [ "Maya Patel", "Liam Chen", "Sofia Rossi", "Noah Berg", "Amara Okafor", "Lucas Meyer" ]



-- PLACES


places : List ( String, String )
places =
    [ ( "Rotterdam", "NL" ), ( "Hamburg", "DE" ), ( "Gothenburg", "SE" ), ( "Chicago", "US" ), ( "Singapore", "SG" ), ( "Sydney", "AU" ), ( "London", "GB" ), ( "Paris", "FR" ), ( "Madrid", "ES" ), ( "Milan", "IT" ), ( "Oslo", "NO" ), ( "Copenhagen", "DK" ), ( "Helsinki", "FI" ), ( "Warsaw", "PL" ), ( "Vienna", "AT" ), ( "Zurich", "CH" ), ( "Dublin", "IE" ), ( "Lisbon", "PT" ), ( "Prague", "CZ" ), ( "Brussels", "BE" ), ( "Toronto", "CA" ), ( "New York", "US" ), ( "Houston", "US" ), ( "Seattle", "US" ), ( "Mexico City", "MX" ), ( "Sao Paulo", "BR" ), ( "Buenos Aires", "AR" ), ( "Santiago", "CL" ), ( "Tokyo", "JP" ), ( "Seoul", "KR" ), ( "Shanghai", "CN" ), ( "Mumbai", "IN" ), ( "Dubai", "AE" ), ( "Istanbul", "TR" ), ( "Cape Town", "ZA" ), ( "Nairobi", "KE" ), ( "Lagos", "NG" ), ( "Melbourne", "AU" ), ( "Auckland", "NZ" ), ( "Bangkok", "TH" ) ]


{-| The city names, for selects that need a list.
-}
cities : List String
cities =
    List.map Tuple.first places


warehouses : List Warehouse
warehouses =
    [ { id = "RTM", name = "Rotterdam Hub", city = "Rotterdam", country = "NL" }
    , { id = "HAM", name = "Hamburg Central", city = "Hamburg", country = "DE" }
    , { id = "GOT", name = "Gothenburg Port", city = "Gothenburg", country = "SE" }
    , { id = "CHI", name = "Chicago North", city = "Chicago", country = "US" }
    , { id = "SIN", name = "Singapore East", city = "Singapore", country = "SG" }
    , { id = "SYD", name = "Sydney South", city = "Sydney", country = "AU" }
    ]


pickWarehouse : Int -> Warehouse
pickWarehouse n =
    warehouses
        |> List.drop (modBy (List.length warehouses) n)
        |> List.head
        |> Maybe.withDefault { id = "RTM", name = "Rotterdam Hub", city = "Rotterdam", country = "NL" }



-- COUNTRIES


countries : List Country
countries =
    [ ( "AF", "Afghanistan", "Asia" ), ( "AL", "Albania", "Europe" ), ( "DZ", "Algeria", "Africa" ), ( "AD", "Andorra", "Europe" ), ( "AO", "Angola", "Africa" ), ( "AR", "Argentina", "South America" ), ( "AM", "Armenia", "Asia" ), ( "AU", "Australia", "Oceania" ), ( "AT", "Austria", "Europe" ), ( "AZ", "Azerbaijan", "Asia" ), ( "BH", "Bahrain", "Asia" ), ( "BD", "Bangladesh", "Asia" ), ( "BY", "Belarus", "Europe" ), ( "BE", "Belgium", "Europe" ), ( "BO", "Bolivia", "South America" ), ( "BA", "Bosnia and Herzegovina", "Europe" ), ( "BR", "Brazil", "South America" ), ( "BG", "Bulgaria", "Europe" ), ( "KH", "Cambodia", "Asia" ), ( "CM", "Cameroon", "Africa" ), ( "CA", "Canada", "North America" ), ( "CL", "Chile", "South America" ), ( "CN", "China", "Asia" ), ( "CO", "Colombia", "South America" ), ( "CD", "DR Congo", "Africa" ), ( "CR", "Costa Rica", "North America" ), ( "HR", "Croatia", "Europe" ), ( "CU", "Cuba", "North America" ), ( "CY", "Cyprus", "Europe" ), ( "CZ", "Czechia", "Europe" ), ( "DK", "Denmark", "Europe" ), ( "DO", "Dominican Republic", "North America" ), ( "EC", "Ecuador", "South America" ), ( "EG", "Egypt", "Africa" ), ( "ER", "Eritrea", "Africa" ), ( "EE", "Estonia", "Europe" ), ( "ET", "Ethiopia", "Africa" ), ( "FI", "Finland", "Europe" ), ( "FR", "France", "Europe" ), ( "GE", "Georgia", "Asia" ), ( "DE", "Germany", "Europe" ), ( "GH", "Ghana", "Africa" ), ( "GR", "Greece", "Europe" ), ( "GT", "Guatemala", "North America" ), ( "HN", "Honduras", "North America" ), ( "HU", "Hungary", "Europe" ), ( "IS", "Iceland", "Europe" ), ( "IN", "India", "Asia" ), ( "ID", "Indonesia", "Asia" ), ( "IR", "Iran", "Asia" ), ( "IQ", "Iraq", "Asia" ), ( "IE", "Ireland", "Europe" ), ( "IL", "Israel", "Asia" ), ( "IT", "Italy", "Europe" ), ( "JM", "Jamaica", "North America" ), ( "JP", "Japan", "Asia" ), ( "JO", "Jordan", "Asia" ), ( "KZ", "Kazakhstan", "Asia" ), ( "KE", "Kenya", "Africa" ), ( "KW", "Kuwait", "Asia" ), ( "LV", "Latvia", "Europe" ), ( "LB", "Lebanon", "Asia" ), ( "LY", "Libya", "Africa" ), ( "LT", "Lithuania", "Europe" ), ( "LU", "Luxembourg", "Europe" ), ( "MY", "Malaysia", "Asia" ), ( "MT", "Malta", "Europe" ), ( "MX", "Mexico", "North America" ), ( "MD", "Moldova", "Europe" ), ( "MA", "Morocco", "Africa" ), ( "NP", "Nepal", "Asia" ), ( "NL", "Netherlands", "Europe" ), ( "NZ", "New Zealand", "Oceania" ), ( "NG", "Nigeria", "Africa" ), ( "MK", "North Macedonia", "Europe" ), ( "NO", "Norway", "Europe" ), ( "PK", "Pakistan", "Asia" ), ( "PA", "Panama", "North America" ), ( "PY", "Paraguay", "South America" ), ( "PE", "Peru", "South America" ), ( "PH", "Philippines", "Asia" ), ( "PL", "Poland", "Europe" ), ( "PT", "Portugal", "Europe" ), ( "QA", "Qatar", "Asia" ), ( "RO", "Romania", "Europe" ), ( "RU", "Russia", "Europe" ), ( "SA", "Saudi Arabia", "Asia" ), ( "SN", "Senegal", "Africa" ), ( "RS", "Serbia", "Europe" ), ( "SG", "Singapore", "Asia" ), ( "SK", "Slovakia", "Europe" ), ( "SI", "Slovenia", "Europe" ), ( "SO", "Somalia", "Africa" ), ( "ZA", "South Africa", "Africa" ), ( "KR", "South Korea", "Asia" ), ( "SS", "South Sudan", "Africa" ), ( "ES", "Spain", "Europe" ), ( "LK", "Sri Lanka", "Asia" ), ( "SD", "Sudan", "Africa" ), ( "SE", "Sweden", "Europe" ), ( "CH", "Switzerland", "Europe" ), ( "SY", "Syria", "Asia" ), ( "TW", "Taiwan", "Asia" ), ( "TZ", "Tanzania", "Africa" ), ( "TH", "Thailand", "Asia" ), ( "TN", "Tunisia", "Africa" ), ( "TR", "Turkey", "Asia" ), ( "UG", "Uganda", "Africa" ), ( "UA", "Ukraine", "Europe" ), ( "AE", "United Arab Emirates", "Asia" ), ( "GB", "United Kingdom", "Europe" ), ( "US", "United States", "North America" ), ( "UY", "Uruguay", "South America" ), ( "UZ", "Uzbekistan", "Asia" ), ( "VE", "Venezuela", "South America" ), ( "VN", "Vietnam", "Asia" ), ( "YE", "Yemen", "Asia" ), ( "ZM", "Zambia", "Africa" ), ( "ZW", "Zimbabwe", "Africa" ) ]
        |> List.map (\( code, name, region ) -> { code = code, name = name, region = region })
        |> List.sortBy .name



-- PRODUCTS


{-| The first `count` products.
-}
products : Int -> List Product
products count =
    List.range 1 count |> List.map product


product : Int -> Product
product i =
    let
        itemCount =
            List.length productItems

        ( category, baseName, basePrice ) =
            productItems
                |> List.drop (modBy itemCount (i - 1))
                |> List.head
                |> Maybe.withDefault ( [ "Other" ], "Item", 10 )

        variantIndex =
            (i - 1) // itemCount

        variant =
            pick productVariants variantIndex

        price =
            toFloat (round (basePrice * (1 + toFloat (modBy 7 variantIndex) * 0.18) * 100)) / 100

        reorderLevel =
            20 + modBy 61 (rand i 41)
    in
    { sku = "SKU-" ++ String.padLeft 5 '0' (String.fromInt i)
    , name = baseName ++ " " ++ variant
    , category = category
    , price = price
    , stock = modBy 600 (rand i 42)
    , reorderLevel = reorderLevel
    , supplier = pick suppliers (rand i 43)
    , active = modBy 100 (rand i 44) < 93
    }


productItems : List ( List String, String, Float )
productItems =
    [ ( [ "Hardware", "Fasteners", "Bolts" ], "Hex bolt", 0.42 )
    , ( [ "Hardware", "Fasteners", "Bolts" ], "Carriage bolt", 0.55 )
    , ( [ "Hardware", "Fasteners", "Nuts" ], "Lock nut", 0.18 )
    , ( [ "Hardware", "Fasteners", "Screws" ], "Wood screw", 0.12 )
    , ( [ "Hardware", "Fasteners", "Screws" ], "Machine screw", 0.15 )
    , ( [ "Hardware", "Tools", "Hand tools" ], "Claw hammer", 14.9 )
    , ( [ "Hardware", "Tools", "Hand tools" ], "Adjustable wrench", 18.5 )
    , ( [ "Hardware", "Tools", "Power tools" ], "Cordless drill", 89 )
    , ( [ "Hardware", "Tools", "Power tools" ], "Angle grinder", 64 )
    , ( [ "Hardware", "Plumbing", "Pipes" ], "Copper pipe", 6.4 )
    , ( [ "Hardware", "Plumbing", "Valves" ], "Ball valve", 11.2 )
    , ( [ "Electronics", "Cables", "USB" ], "USB cable", 3.9 )
    , ( [ "Electronics", "Cables", "HDMI" ], "HDMI cable", 7.5 )
    , ( [ "Electronics", "Cables", "Power" ], "Extension lead", 12.4 )
    , ( [ "Electronics", "Components", "Resistors" ], "Resistor pack", 2.2 )
    , ( [ "Electronics", "Components", "Capacitors" ], "Capacitor pack", 3.1 )
    , ( [ "Electronics", "Components", "Sensors" ], "Temperature sensor", 8.8 )
    , ( [ "Packaging", "Boxes", "Cartons" ], "Shipping carton", 1.35 )
    , ( [ "Packaging", "Boxes", "Mailers" ], "Padded mailer", 0.9 )
    , ( [ "Packaging", "Protection", "Foam" ], "Foam insert", 1.8 )
    , ( [ "Packaging", "Protection", "Bubble wrap" ], "Bubble wrap roll", 9.6 )
    , ( [ "Packaging", "Protection", "Tape" ], "Packing tape", 2.4 )
    , ( [ "Office", "Paper", "Copy paper" ], "Copy paper ream", 4.7 )
    , ( [ "Office", "Paper", "Labels" ], "Address labels", 5.2 )
    , ( [ "Office", "Writing", "Pens" ], "Ballpoint pens", 3.3 )
    , ( [ "Office", "Writing", "Markers" ], "Permanent markers", 4.1 )
    , ( [ "Furniture", "Chairs", "Office chairs" ], "Office chair", 129 )
    , ( [ "Furniture", "Chairs", "Stools" ], "Workshop stool", 38 )
    , ( [ "Furniture", "Storage", "Shelving" ], "Steel shelf unit", 74 )
    , ( [ "Furniture", "Storage", "Cabinets" ], "Locker cabinet", 156 )
    ]


productVariants : List String
productVariants =
    [ "S", "M", "L", "XL", "Zinc", "Steel", "Black", "Grey", "Pack of 10", "Pack of 50", "Heavy duty", "Compact", "Pro", "Basic" ]


suppliers : List String
suppliers =
    [ "Harborline Supply", "Brightwell Trading", "Kestrel Industrial", "Northgate Wholesale", "Pelican Distribution", "Ridgeway Components", "Silverleaf Imports", "Tidewater Goods", "Upland Materials", "Vantage Parts", "Westbrook Direct", "Yellowfin Traders" ]



-- RANDOM


{-| A pseudo-random non-negative integer from a row number and a salt. Pure and
stable: the same input always gives the same output.
-}
rand : Int -> Int -> Int
rand i salt =
    (i * 40503 + salt * 99991 + 12345)
        |> xorshift
        |> xorshift
        |> xorshift
        |> Bitwise.and 0x7FFFFFFF


{-| One round of xorshift32: shifts and xors only, so different salts give
independent-looking values (a plain multiply-and-add generator does not).
-}
xorshift : Int -> Int
xorshift n =
    let
        a =
            Bitwise.xor n (Bitwise.shiftLeftBy 13 n)

        b =
            Bitwise.xor a (Bitwise.shiftRightZfBy 17 a)
    in
    Bitwise.xor b (Bitwise.shiftLeftBy 5 b)


pick : List String -> Int -> String
pick items n =
    case items of
        [] ->
            ""

        _ ->
            items
                |> List.drop (modBy (List.length items) n)
                |> List.head
                |> Maybe.withDefault ""


pickPair : List ( String, String ) -> Int -> ( String, String )
pickPair items n =
    items
        |> List.drop (modBy (List.length items) n)
        |> List.head
        |> Maybe.withDefault ( "", "" )
