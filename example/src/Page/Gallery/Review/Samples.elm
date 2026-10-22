module Page.Gallery.Review.Samples exposing
    ( AuditEntry
    , Product
    , ProductId
    , auditEntries
    , bigAfter
    , bigBefore
    , manyAfter
    , manyBefore
    , orderAfter
    , orderBefore
    , policyAfter
    , policyBefore
    , productIdText
    , products
    , stockAfter
    , stockBefore
    )

{-| The two versions of everything the review page compares: a shipping policy, a
CSV of stock levels, an order as JSON, the fields of an order in an audit log, texts
too large to compare, and three products.
-}

import Json.Encode as Encode exposing (Value)



-- A SHIPPING POLICY


policyBefore : String
policyBefore =
    String.join "\n"
        [ "Shipping policy"
        , ""
        , "Orders over $50 ship free within Norway."
        , "Orders are packed within two business days."
        , "We ship with Nordic Freight and Postal Express."
        , "Delivery takes 2 to 5 business days."
        , ""
        , "Tracking"
        , "Every parcel has a tracking number."
        , "The number is sent by email when the parcel leaves the warehouse."
        , "You can follow the parcel on the tracking page."
        , "If the tracking page shows no movement for 3 days, write to us."
        , ""
        , "Returns"
        , "Items can be returned within 30 days of delivery."
        , "The item must be unused and in its original packaging."
        , "Refunds are paid to the original payment method within 5 business days."
        , "Customers pay return shipping, except for damaged goods."
        , ""
        , "Damaged goods"
        , "Report damage within 7 days of delivery."
        , "Send us a photo of the parcel and of the item."
        , "We send a replacement or refund the full price."
        , ""
        , "Contact"
        , "Questions about an order? Write to support@example.com."
        , "Our support team answers within one business day."
        , ""
        ]


{-| The new version: a lower limit for free shipping, a faster dispatch, a third
carrier, longer returns, a rewritten line about return shipping, a new section at
the end, and two edits that only touch white space (trailing spaces, a double
space), which "Ignore white space" leaves out.
-}
policyAfter : String
policyAfter =
    String.join "\n"
        [ "Shipping policy"
        , ""
        , "Orders over $75 ship free within Norway."
        , "Orders are packed within one business day."
        , "We ship with Nordic Freight, Postal Express and Harbour Courier."
        , "Delivery takes 2 to 5 business days."
        , ""
        , "Tracking"
        , "Every parcel has a tracking number."
        , "The number is sent by email when the parcel leaves the warehouse."
        , "You can follow the parcel  on the tracking page."
        , "If the tracking page shows no movement for 2 days, write to us."
        , ""
        , "Returns"
        , "Items can be returned within 60 days of delivery."
        , "The item must be unused and in its original packaging.   "
        , "Refunds are paid to the original payment method within 3 business days."
        , "Return shipping is free for damaged goods. Otherwise the customer pays."
        , ""
        , "Damaged goods"
        , "Report damage within 14 days of delivery."
        , "Send us a photo of the parcel and of the item."
        , "We send a replacement or refund the full price."
        , ""
        , "Contact"
        , "Questions about an order? Write to support@example.com."
        , "Our support team answers within one business day."
        , ""
        , "Holidays"
        , "Around public holidays delivery can take one extra business day."
        , ""
        ]



-- A CSV OF STOCK LEVELS


stockBefore : String
stockBefore =
    String.join "\n"
        [ "warehouse,sku,product,on_hand,reserved,reorder_level"
        , "BER,A-1001,Bolt M8x40,1240,35,500"
        , "BER,A-1002,Bolt M8x60,980,12,500"
        , "BER,A-1003,Bolt M10x40,610,0,400"
        , "BER,A-1004,Nut M8,3200,150,1000"
        , "BER,A-1005,Nut M10,2870,90,1000"
        , "BER,A-1006,Washer 8 mm,5120,240,2000"
        , "BER,B-2040,Cable tie 200 mm,9400,0,3000"
        , "BER,B-2041,Cable tie 300 mm,7350,410,3000"
        , "OSL,A-1001,Bolt M8x40,860,60,500"
        , "OSL,A-1002,Bolt M8x60,45,20,500"
        , "OSL,A-1004,Nut M8,1500,0,1000"
        , "OSL,B-2040,Cable tie 200 mm,2210,300,3000"
        , "OSL,C-3100,Safety gloves L,320,18,150"
        , "OSL,C-3101,Safety gloves XL,95,6,150"
        , "TRD,A-1001,Bolt M8x40,430,10,300"
        , "TRD,A-1003,Bolt M10x40,260,0,200"
        , "TRD,A-1005,Nut M10,1290,30,600"
        , "TRD,B-2041,Cable tie 300 mm,2800,120,1500"
        , "TRD,C-3100,Safety gloves L,140,4,100"
        , "TRD,C-3102,Safety gloves M,205,0,100"
        , ""
        ]


{-| New counts for some rows, a product renamed, one row removed and one added,
and a change of the reorder level.
-}
stockAfter : String
stockAfter =
    String.join "\n"
        [ "warehouse,sku,product,on_hand,reserved,reorder_level"
        , "BER,A-1001,Bolt M8x40,1285,35,500"
        , "BER,A-1002,Bolt M8x60,980,12,500"
        , "BER,A-1003,Bolt M10x40,610,0,400"
        , "BER,A-1004,Nut M8,3200,150,1000"
        , "BER,A-1005,Nut M10,2870,90,1000"
        , "BER,A-1006,Washer 8 mm,5120,240,2000"
        , "BER,B-2040,Cable tie 200 mm,9400,0,3000"
        , "BER,B-2041,Cable tie 300 mm,7350,410,3000"
        , "OSL,A-1001,Bolt M8x40,860,60,500"
        , "OSL,A-1002,Bolt M8x60,545,20,500"
        , "OSL,A-1004,Nut M8,1500,0,1000"
        , "OSL,B-2040,Cable tie 200 mm,2210,300,3000"
        , "OSL,C-3100,Safety gloves L,320,18,150"
        , "OSL,C-3101,Safety gloves XL,95,6,150"
        , "TRD,A-1001,Bolt M8x40,430,10,300"
        , "TRD,A-1003,Bolt M10x40,260,0,200"
        , "TRD,A-1005,Nut M10,1290,30,600"
        , "TRD,B-2041,Cable tie 300 mm,2800,120,1500"
        , "TRD,C-3100,Safety gloves L,140,4,100"
        , "TRD,C-3102,Safety gloves M,205,0,100"
        , "TRD,C-3103,Safety gloves S,60,0,50"
        , ""
        ]



-- AN ORDER AS JSON


orderBefore : Value
orderBefore =
    Encode.object
        [ ( "id", Encode.string "ORD-10482" )
        , ( "status", Encode.string "open" )
        , ( "customer"
          , Encode.object
                [ ( "id", Encode.string "C-204" )
                , ( "name", Encode.string "Northwind Traders" )
                , ( "city", Encode.string "Bergen" )
                ]
          )
        , ( "lines"
          , Encode.list identity
                [ line "A-1001" 10 12.5
                , line "B-2040" 4 99
                , line "C-3100" 1 249.9
                ]
          )
        , ( "coupon", Encode.string "SPRING10" )
        , ( "tags", Encode.list Encode.string [ "wholesale", "priority" ] )
        , ( "note", Encode.string "Deliver to the loading dock at the back of the building." )
        , ( "discount", Encode.float (0.1 + 0.2) )
        , ( "totals", Encode.object [ ( "net", Encode.float 1243.9 ), ( "tax", Encode.float 310.98 ) ] )
        ]


{-| The same order after an edit. The lines come in another order, one was removed
and one added: compared by position this is a mess, compared by `sku` it is three
changes.
-}
orderAfter : Value
orderAfter =
    Encode.object
        [ ( "id", Encode.string "ORD-10482" )
        , ( "status", Encode.string "shipped" )
        , ( "customer"
          , Encode.object
                [ ( "id", Encode.string "C-204" )
                , ( "name", Encode.string "Northwind Traders" )
                , ( "city", Encode.string "Oslo" )
                ]
          )
        , ( "lines"
          , Encode.list identity
                [ line "C-3100" 1 229.9
                , line "A-1001" 12 12.5
                , line "D-4410" 2 18
                ]
          )
        , ( "tags", Encode.list Encode.string [ "wholesale", "express" ] )
        , ( "note", Encode.string "Deliver to the loading dock at the front of the building, before 10:00." )
        , ( "discount", Encode.float 0.3 )
        , ( "totals", Encode.object [ ( "net", Encode.float 1314.4 ), ( "tax", Encode.float 328.6 ) ] )
        ]


line : String -> Int -> Float -> Value
line sku quantity price =
    Encode.object
        [ ( "sku", Encode.string sku )
        , ( "qty", Encode.int quantity )
        , ( "price", Encode.float price )
        ]



-- THE AUDIT LOG


type alias AuditEntry =
    { who : String
    , when : String
    , fields : List { label : String, before : Maybe String, after : Maybe String }
    }


auditEntries : List AuditEntry
auditEntries =
    [ { who = "Ada Lovelace"
      , when = "12 Oct 2026, 09:14"
      , fields =
            [ { label = "Status", before = Just "Open", after = Just "Shipped" }
            , { label = "Carrier", before = Nothing, after = Just "Nordic Freight" }
            , { label = "Delivery date", before = Just "14 Oct 2026", after = Just "16 Oct 2026" }
            , { label = "Customer", before = Just "Northwind Traders", after = Just "Northwind Traders" }
            , { label = "Note", before = Just "Call before delivery.", after = Just "Call the day before delivery." }
            ]
      }
    , { who = "Charles Babbage"
      , when = "11 Oct 2026, 16:40"
      , fields =
            [ { label = "Priority", before = Just "Normal", after = Just "High" }
            , { label = "Coupon", before = Just "SPRING10", after = Nothing }
            , { label = "Customer", before = Just "Northwind Traders", after = Just "Northwind Traders" }
            ]
      }
    , { who = "Ada Lovelace"
      , when = "10 Oct 2026, 08:02"
      , fields =
            [ { label = "Customer", before = Nothing, after = Just "Northwind Traders" }
            , { label = "Status", before = Nothing, after = Just "Open" }
            , { label = "Warehouse", before = Nothing, after = Just "Bergen" }
            ]
      }
    ]



-- TEXTS THAT ARE TOO LARGE, AND TEXTS WITH MANY CHANGES


{-| Two exports of 3 000 lines that have nothing in common: finding the shortest set
of changes would take far longer than the viewer allows.
-}
bigBefore : String
bigBefore =
    exportOf "BER" 3000


bigAfter : String
bigAfter =
    exportOf "OSL" 3000


exportOf : String -> Int -> String
exportOf warehouse count =
    List.range 1 count
        |> List.map (\i -> warehouse ++ "-" ++ String.fromInt (100000 + i * 7) ++ "," ++ String.fromInt (modBy 97 (i * 31)) ++ "," ++ String.fromInt (modBy 1000 (i * 17)))
        |> String.join "\n"


{-| 1 200 lines.
-}
manyBefore : String
manyBefore =
    List.range 1 1200
        |> List.map (\i -> "Line " ++ String.fromInt i ++ ": pick " ++ String.fromInt (modBy 90 (i * 13) + 10) ++ " units from bay " ++ String.fromInt (modBy 24 i + 1))
        |> String.join "\n"


{-| The same with every third line picking another number of units: 400 changes.
-}
manyAfter : String
manyAfter =
    List.range 1 1200
        |> List.map
            (\i ->
                "Line "
                    ++ String.fromInt i
                    ++ ": pick "
                    ++ String.fromInt
                        (if modBy 3 i == 0 then
                            modBy 90 (i * 29) + 10

                         else
                            modBy 90 (i * 13) + 10
                        )
                    ++ " units from bay "
                    ++ String.fromInt (modBy 24 i + 1)
            )
        |> String.join "\n"



-- PRODUCTS TO COMPARE


{-| The id of a product, a type of its own so that it cannot be mixed up with a SKU
or an order number.
-}
type ProductId
    = ProductId Int


productIdText : ProductId -> String
productIdText (ProductId n) =
    String.fromInt n


type alias Product =
    { id : ProductId
    , sku : String
    , name : String
    , status : String
    , price : Float
    , stock : Int
    , warehouse : String
    , discount : Maybe Int
    , dimensions : String
    , summary : String
    }


products : List Product
products =
    [ { id = ProductId 1
      , sku = "A-1001"
      , name = "Bolt M8x40"
      , status = "Active"
      , price = 12.5
      , stock = 1240
      , warehouse = "Bergen"
      , discount = Nothing
      , dimensions = "8 x 40 mm"
      , summary = "Zinc plated steel bolt for general use indoors. Sold in boxes of 100."
      }
    , { id = ProductId 2
      , sku = "A-1002"
      , name = "Bolt M8x60"
      , status = "Active"
      , price = 14.9
      , stock = 45
      , warehouse = "Bergen"
      , discount = Just 10
      , dimensions = "8 x 60 mm"
      , summary = "Zinc plated steel bolt for general use indoors and outdoors. Sold in boxes of 100."
      }
    , { id = ProductId 3
      , sku = "A-1003"
      , name = "Bolt M10x40"
      , status = "Discontinued"
      , price = 12.5
      , stock = 610
      , warehouse = "Bergen"
      , discount = Nothing
      , dimensions = "10 x 40 mm"
      , summary = "Zinc plated steel bolt for general use indoors. Sold in boxes of 50."
      }
    ]
