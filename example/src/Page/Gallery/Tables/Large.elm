module Page.Gallery.Tables.Large exposing (Model, Msg, init, update, view)

{-| Gallery section: 50 000 rows in a table and in a list, to see (and measure)
that a large collection is a normal case. The rows are made here, in the
example, by a small deterministic generator; the library knows nothing about them.
-}

import Array
import Html exposing (Html)
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Table as Table
import Showcase.Doc as Doc



-- ROWS


type alias Item =
    { id : Int
    , sku : String
    , name : String
    , category : String
    , warehouse : String
    , quantity : Int
    , price : Float
    }


rowCount : Int
rowCount =
    50000


generate : Int -> List Item
generate count =
    List.range 1 count |> List.map item


{-| A linear congruential step, so the same row always has the same values.
-}
next : Int -> Int
next seed =
    modBy 2147483647 (seed * 48271)


pick : List String -> Int -> String
pick choices seed =
    List.drop (modBy (List.length choices) seed) choices |> List.head |> Maybe.withDefault ""


item : Int -> Item
item n =
    let
        a =
            next (n * 7919 + 13)

        b =
            next a

        c =
            next b

        d =
            next c

        e =
            next d
    in
    { id = n
    , sku = "SKU-" ++ String.padLeft 6 '0' (String.fromInt (modBy 1000000 (n * 7 + modBy 97 a)))
    , name = pick adjectives (a // 7) ++ " " ++ pick products (b // 7)
    , category = pick categories (c // 7)
    , warehouse = pick warehouses (d // 7)
    , quantity = modBy 5000 (e // 7)
    , price = toFloat (modBy 900000 (a // 3)) / 100 + 1
    }


adjectives : List String
adjectives =
    [ "Heavy", "Light", "Compact", "Rapid", "Steel", "Cast", "Folding", "Wireless", "Industrial", "Precision", "Pick", "Magnetic" ]


products : List String
products =
    [ "hammer", "drill", "saw", "chisel", "clamp", "level", "pliers", "wrench", "spanner", "ladder", "cart", "bracket", "anchor", "hinge", "valve", "gasket", "bearing", "sprocket", "filter", "gauge" ]


categories : List String
categories =
    [ "Hand tools", "Power tools", "Fasteners", "Plumbing", "Electrical", "Storage", "Safety" ]


warehouses : List String
warehouses =
    [ "Rotterdam", "Oslo", "Gdansk", "Hamburg", "Antwerp" ]



-- MODEL


type alias Model =
    { items : Remote (Table.Rows Item)
    , prepared : Bool
    , table : Table.State Int
    }


init : Model
init =
    { items = Remote.NotAsked
    , prepared = True
    , table = Table.init "large-items"
    }


type Msg
    = Load Locale
    | TableMsg Table.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Load locale ->
            ( { model | items = Remote.Loaded (Table.prepareRows locale columns (Array.fromList (generate rowCount))) }, Cmd.none )

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )



-- VIEW


itemIds : Table.RowIds Int
itemIds =
    Table.intIds


columns : List (Table.Column Item msg)
columns =
    [ Table.int (Table.columnId "id") "No." .id [ Table.width 80 ]
    , Table.text (Table.columnId "sku") "SKU" .sku [ Table.width 120 ]
    , Table.text (Table.columnId "name") "Name" .name []
    , Table.text (Table.columnId "category") "Category" .category [ Table.filterSelect ]
    , Table.text (Table.columnId "warehouse") "Warehouse" .warehouse []
    , Table.int (Table.columnId "quantity") "Quantity" .quantity [ Table.footerSum ]
    , Table.float (Table.columnId "price") "Price" 2 .price [ Table.footerSum ]
    ]


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "50 000 rows"
        "A table over 50 000 generated rows."
        [ Doc.example
            { title = "Table, client mode", description = Nothing, code = Nothing }
            (Layout.stack [ Layout.gap 3 ]
                [ Button.view [ Button.onClick (Load locale) ] "Load 50 000 rows"
                , Table.view TableMsg
                    [ Table.columns columns
                    , Table.preparedRows model.items
                    , Table.rowId itemIds .id
                    , Table.searchable
                    , Table.label "Items"
                    , Table.locale locale
                    ]
                    model.table
                ]
            )
        ]
