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
import Klar.Switch as Switch
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
    , list : Remote (List Item)
    , prepared : Bool
    , paged : Table.State Int
    , scrolling : Table.State Int
    }


init : Model
init =
    { items = Remote.NotAsked
    , list = Remote.NotAsked
    , prepared = True
    , paged = Table.init "large-paged"
    , scrolling = Table.init "large-scrolling"
    }


type Msg
    = Load Locale
    | PreparedToggled Bool
    | PagedMsg Table.Msg
    | ScrollingMsg Table.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Load locale ->
            let
                generated =
                    generate rowCount
            in
            ( { model
                | items = Remote.Loaded (Table.prepareRows locale columns (Array.fromList generated))
                , list = Remote.Loaded generated
              }
            , Cmd.none
            )

        PreparedToggled value ->
            ( { model | prepared = value }, Cmd.none )

        PagedMsg inner ->
            Table.update inner model.paged
                |> Tuple.mapBoth (\table -> { model | paged = table }) (Cmd.map PagedMsg)

        ScrollingMsg inner ->
            Table.update inner model.scrolling
                |> Tuple.mapBoth (\table -> { model | scrolling = table }) (Cmd.map ScrollingMsg)



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


rowsAttribute : Model -> Table.Attribute Int Item msg
rowsAttribute model =
    if model.prepared then
        Table.preparedRows model.items

    else
        Table.rows model.list


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "50 000 rows"
        "A table over 50 000 generated rows. The rows are prepared once, when they are loaded, and sorting, searching and paging then work on what is prepared."
        [ Doc.example
            { title = "Load"
            , description = Just "The rows are made here, in the example, by a small generator. Turn the switch off to hand the table a plain list instead, and feel the difference."
            , code = Nothing
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.onClick (Load locale) ] "Load 50 000 rows"
                , Switch.view
                    [ Switch.label "Prepared rows"
                    , Switch.checked model.prepared
                    , Switch.onToggle PreparedToggled
                    ]
                ]
            )
        , Doc.example
            { title = "Paged"
            , description = Just "Pages of 25 rows: the way to read a table that people search and sort."
            , code = Nothing
            }
            (Table.view PagedMsg
                [ Table.columns columns
                , rowsAttribute model
                , Table.rowId itemIds .id
                , Table.searchable
                , Table.label "Items, in pages"
                , Table.locale locale
                ]
                model.paged
            )
        , Doc.example
            { title = "Scrolling"
            , description = Just "The same rows in one list that scrolls, with the header and the totals in view. Only the rows in view are drawn. Click a row, then use the arrow keys, PageUp, PageDown, Home and End."
            , code = Nothing
            }
            (Table.view ScrollingMsg
                [ Table.columns columns
                , rowsAttribute model
                , Table.rowId itemIds .id
                , Table.virtual
                , Table.searchable
                , Table.selectable
                , Table.densityToggle
                , Table.label "Items, scrolling"
                , Table.locale locale
                ]
                model.scrolling
            )
        ]
