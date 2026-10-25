module Page.Gallery.Tables.Large exposing (Model, Msg, init, update, view)

{-| Gallery section: 50 000 rows in a table and in a list, to see (and measure)
that a large collection is a normal case. The rows are made here, in the
example, by a small deterministic generator; the library knows nothing about them.
-}

import Array exposing (Array)
import Html exposing (Html)
import Klar.Button as Button
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Search as Search
import Klar.SearchInput as SearchInput
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.VirtualList as VirtualList
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
    , name = pick adjectives (a // 7) ++ " " ++ pick products (b // 7) ++ " " ++ String.fromInt (100 + modBy 9000 (e // 11))
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
    , useRows : Bool
    , paged : Table.State Int
    , scrolling : Table.State Int
    , texts : Array Search.Prepared
    , search : SearchInput.State
    , results : Array Item
    , picked : Maybe Int
    , listState : VirtualList.State
    }


init : Model
init =
    { items = Remote.NotAsked
    , list = Remote.NotAsked
    , useRows = True
    , paged = Table.init "large-paged"
    , scrolling = Table.init "large-scrolling"
    , texts = Array.empty
    , search = SearchInput.init "large-search"
    , results = Array.empty
    , picked = Nothing
    , listState = VirtualList.init "large-list"
    }


type Msg
    = Load Locale
    | PreparedToggled Bool
    | PagedMsg Table.Msg
    | ScrollingMsg Table.Msg
    | SearchMsg SearchInput.Msg
    | ListMsg VirtualList.Msg
    | ItemPicked Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Load locale ->
            let
                generated =
                    generate rowCount

                rows =
                    Table.prepareRows locale columns (Array.fromList generated)
            in
            ( { model
                | items = Remote.Loaded rows
                , list = Remote.Loaded generated
                , texts = Array.fromList (Search.prepareMany (List.map searchText generated))
                , results = Table.rowsArray rows
                , picked = Nothing
              }
            , Cmd.none
            )

        PreparedToggled value ->
            ( { model | useRows = value }, Cmd.none )

        PagedMsg inner ->
            Table.update inner model.paged
                |> Tuple.mapBoth (\table -> { model | paged = table }) (Cmd.map PagedMsg)

        ScrollingMsg inner ->
            Table.update inner model.scrolling
                |> Tuple.mapBoth (\table -> { model | scrolling = table }) (Cmd.map ScrollingMsg)

        SearchMsg inner ->
            let
                ( search, cmd ) =
                    SearchInput.update inner model.search

                changed =
                    SearchInput.committed search /= SearchInput.committed model.search
            in
            ( if changed then
                { model | search = search, results = find (SearchInput.committed search) model, picked = Nothing }

              else
                { model | search = search }
            , Cmd.map SearchMsg cmd
            )

        ListMsg inner ->
            VirtualList.update inner model.listState
                |> Tuple.mapBoth (\state -> { model | listState = state }) (Cmd.map ListMsg)

        ItemPicked index ->
            ( { model | picked = Just index }, Cmd.none )


{-| What the search looks in: the name, the category, the warehouse, the SKU and a
description of about twenty words, so that the texts are as long as the texts of
real products.
-}
searchText : Item -> String
searchText found =
    String.join " "
        ([ found.name, found.category, found.warehouse, found.sku ]
            ++ List.map (\k -> pick products (found.id * k + k)) (List.range 1 12)
            ++ List.map (\k -> pick adjectives (found.id * k + 3 * k)) (List.range 1 8)
        )


{-| The items whose name, category, warehouse or SKU match, best matches first.
-}
find : String -> Model -> Array Item
find text model =
    case model.items of
        Remote.Loaded rows ->
            if String.isEmpty (String.trim text) then
                Table.rowsArray rows

            else
                let
                    query =
                        Search.query text
                in
                List.map2 Tuple.pair (Array.toList model.texts) (Array.toList (Table.rowsArray rows))
                    |> List.filterMap
                        (\( prepared, found ) ->
                            Search.scorePrepared query prepared |> Maybe.map (\points -> ( points, found ))
                        )
                    |> List.sortBy Tuple.first
                    |> List.map Tuple.second
                    |> Array.fromList

        _ ->
            Array.empty



-- VIEW


itemIds : Ids Int
itemIds =
    Ids.int


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
    if model.useRows then
        Table.remotePrepared model.items

    else
        Table.remote model.list


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "50 000 rows"
        "A large collection is a normal case: a table and a list over 50 000 generated rows, in one page. Search, sort and page or scroll, and every step stays under a tenth of a second."
        [ Doc.example
            { title = "Load"
            , description = Just "The rows are made here, in the example, by a small generator. Prepared rows are made once, when the rows arrive; turn the switch off to give the table a plain list instead and feel the difference."
            , code = Just loadCode
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.onClick (Load locale) ] "Load 50 000 rows"
                , Switch.view
                    [ Switch.label "Prepared rows"
                    , Switch.checked model.useRows
                    , Switch.onCheck PreparedToggled
                    ]
                ]
            )
        , Doc.example
            { title = "Table, in pages"
            , description = Just "Pages of 25 rows: the way to read a table that people search, filter and sort to find a few rows."
            , code = Nothing
            }
            (Table.view PagedMsg
                [ Table.columns columns
                , rowsAttribute model
                , Table.rowId itemIds .id
                , Table.searchable
                , Table.ariaLabel "Items, in pages"
                , Table.locale locale
                ]
                model.paged
            )
        , Doc.example
            { title = "Table, scrolling"
            , description = Just "The same rows in one list that scrolls, with the header and the totals in view: the way to read a long table from the top. Only the rows in view are drawn. Click a row, then use the arrow keys, PageUp, PageDown, Home and End."
            , code = Just scrollingCode
            }
            (Table.view ScrollingMsg
                [ Table.columns columns
                , rowsAttribute model
                , Table.rowId itemIds .id
                , Table.virtual
                , Table.searchable
                , Table.selectable
                , Table.densityToggle
                , Table.ariaLabel "Items, scrolling"
                , Table.locale locale
                ]
                model.scrolling
            )
        , Doc.example
            { title = "List"
            , description = Just "A plain list of equal rows that people scan and pick from. The list makes its own rows, so it needs no height and no style, and it is one tab stop: ArrowDown, ArrowUp, Home, End, PageDown and PageUp move through the rows, Enter picks one."
            , code = Just listCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ SearchInput.view SearchMsg
                    [ SearchInput.placeholder "Search 50,000 items ..."
                    , SearchInput.ariaLabel "Search the items"
                    , SearchInput.locale locale
                    ]
                    model.search
                , Text.secondary
                    (Format.int locale (Array.length model.results)
                        ++ " of "
                        ++ Format.int locale (Array.length model.texts)
                        ++ " items"
                        ++ (case Maybe.andThen (\index -> Array.get index model.results) model.picked of
                                Just picked ->
                                    ". Picked: " ++ picked.name ++ ", " ++ picked.sku ++ "."

                                Nothing ->
                                    "."
                           )
                    )
                , VirtualList.list ListMsg
                    [ VirtualList.onSelect ItemPicked
                    , VirtualList.selected model.picked
                    , VirtualList.height 352
                    ]
                    { label = "Items", items = model.results, viewRow = viewItem }
                    model.listState
                ]
            )
        ]


viewItem : Item -> Html msg
viewItem found =
    ListItem.content
        [ ListItem.secondary (found.category ++ ", " ++ found.warehouse)
        , ListItem.meta (String.fromInt found.quantity ++ " in stock")
        ]
        found.name


loadCode : String
loadCode =
    """GotItems (Ok items) ->
    -- once, when the rows arrive: the table works out the search texts and the
    -- order of every sortable column, and keeps them with the rows
    ( { model | items = Loaded (Table.prepareRows locale columns (Array.fromList items)) }, Cmd.none )

-- view
Table.remotePrepared model.items"""


scrollingCode : String
scrollingCode =
    """Table.view TableMsg
    [ Table.columns columns
    , Table.remotePrepared model.items
    , Table.rowId itemIds .id
    , Table.virtual
    , Table.searchable
    ]
    model.table"""


listCode : String
listCode =
    """VirtualList.list ListMsg
    [ VirtualList.onSelect ItemPicked, VirtualList.selected model.picked ]
    { label = "Items", items = Table.rowsArray rows, viewRow = viewItem }
    model.listState

viewItem item =
    ListItem.content [ ListItem.secondary item.category, ListItem.meta item.stock ] item.name"""
