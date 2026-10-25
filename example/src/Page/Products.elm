module Page.Products exposing (Model, Msg, init, subscriptions, takeEffects, update, view)

{-| Products: a tree of categories next to a table of 1,500 products.

All products arrive in one request and the table works on them in the browser
("client mode"): it searches, filters, sorts and pages by itself, and draws the
loading and failure states, so this page only describes what a product looks
like. The tree is built once from the category paths of the products (see
`Page.Products.Category`), and the category chosen in it narrows the table to
that branch.

Tree and table are two components with a state of their own. What joins them is
`category` in the model, and only `setCategory` changes it: choosing a node,
"Show all products" and the table's own reset buttons all end there, so the
tree, the table and the page header cannot disagree about what is chosen.

When the request fails (the developer tools can make it), the table shows the
failure with its retry button. When a refresh fails, the old rows stay on screen
and a toast says so.

-}

import Api exposing (Backend)
import Api.Problem as Problem
import Api.Types exposing (ApiError, Product)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Lazy
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.PageHeader as PageHeader
import Klar.Progress as Progress
import Klar.Remote as Remote exposing (Remote)
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme exposing (Size(..), Tone(..))
import Klar.Tree as Tree
import Page.Effect as Effect exposing (Context, Effect(..))
import Page.Products.Category as Category exposing (Branch(..), Category)
import Set
import Time



-- MODEL


type alias Model =
    { products : Remote (List Product)

    -- The hierarchy of the products, built once when they arrive.
    , categories : List Branch

    -- The branch the table is narrowed to. The tree shows the same choice.
    , category : Maybe Category
    , table : Table.State String
    , tree : Tree.State String

    -- Which request the page is waiting for (see `request`).
    , latest : Int

    -- True while new rows are on their way and the old ones are still shown.
    , effects : Effect.Outbox
    }


init : Context -> Backend -> ( Model, Backend, Cmd Msg )
init _ backend =
    request backend
        { products = Remote.Loading
        , categories = []
        , category = Nothing
        , table = Table.init "products-table"
        , tree = Tree.init "products-tree"
        , latest = 0
        , effects = Effect.empty
        }


{-| The effects the last update left for `Main` to carry out.
-}
takeEffects : Model -> ( Model, Effect.Outbox )
takeEffects =
    Effect.take


{-| Asks for the products. The answer carries a ticket, and only the answer to
the newest request is used: the page can ask again (retry, refresh), or be
started over by a new visit, while an older request is still on its way, and its
slower answer must not overwrite the newer one.

The backend counts every request it sends and never counts back, so that number
is a ticket nobody else holds: not even an earlier instance of this page (`Main`
makes a new one on every visit).

-}
request : Backend -> Model -> ( Model, Backend, Cmd Msg )
request backend model =
    let
        ticket =
            Api.requestCount backend

        ( backend1, cmd ) =
            Api.listProducts (Loaded ticket) backend
    in
    ( { model | latest = ticket }, backend1, cmd )



-- UPDATE


type Msg
    = Loaded Int (Result ApiError (List Product))
    | Reload
    | TableMsg Table.Msg
    | TreeMsg Tree.Msg
    | ClearCategory
    | FiltersReset
    | ReorderSelected


update : Context -> Msg -> Backend -> Model -> ( Model, Backend, Cmd Msg )
update context msg backend model =
    case msg of
        Loaded ticket result ->
            if ticket == model.latest then
                ( loaded context result model, backend, Cmd.none )

            else
                ( model, backend, Cmd.none )

        Reload ->
            -- The refresh button and the retry button of a failure.
            -- The rows stay, dimmed, until the new ones are here.
            request backend { model | products = Remote.refresh model.products }

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = table }, backend, Cmd.map TableMsg cmd )

        TreeMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.tree

                moved =
                    { model | tree = tree }

                -- The tree reports nothing: compare its state before and after.
                next =
                    if Tree.selectedId Ids.string tree /= Tree.selectedId Ids.string model.tree then
                        setCategory (Tree.selectedId Ids.string tree |> Maybe.andThen (\id -> Category.find id model.categories)) moved

                    else
                        moved
            in
            ( next, backend, Cmd.map TreeMsg cmd )

        ClearCategory ->
            ( setCategory Nothing model
            , backend
            , -- The button is gone now, so the keyboard goes back to the tree,
              -- where the next category is chosen.
              case Tree.focused Ids.string model.tree of
                Just id ->
                    Cmd.map TreeMsg (Tree.focusNode Ids.string id model.tree)

                Nothing ->
                    Cmd.none
            )

        FiltersReset ->
            -- The table sends this together with its own reset buttons. The
            -- category is a filter of ours, which it cannot clear by itself.
            ( setCategory Nothing model, backend, Cmd.none )

        ReorderSelected ->
            let
                chosen =
                    Set.fromList (Table.selectedIds Ids.string model.table)

                ( active, inactive ) =
                    model.products
                        |> Remote.withDefault []
                        |> List.filter (\product -> Set.member product.sku chosen)
                        |> List.partition .active
            in
            ( { model
                | table = Table.clearSelection model.table
                , effects = Effect.push (reorderToast context.locale (List.length active) (List.length inactive)) model.effects
              }
            , backend
            , -- The bar with the button is gone: keep the keyboard in the table.
              Cmd.map TableMsg (Table.focus model.table)
            )


{-| The answer to the newest request.
-}
loaded : Context -> Result ApiError (List Product) -> Model -> Model
loaded context result model =
    case result of
        Ok products ->
            let
                categories =
                    Category.fromProducts products
            in
            refreshCategory categories
                { model
                    | products = Remote.Loaded products
                    , categories = categories
                    , tree =
                        if Remote.isLoaded model.products then
                            -- A refresh: leave the tree as the user has it.
                            model.tree

                        else
                            Tree.setExpandedIds Ids.string (List.map (\(Branch category _) -> category.id) categories) model.tree
                }

        Err error ->
            let
                problem =
                    Problem.toProblem error
            in
            if Remote.isRefreshing model.products then
                -- The rows on screen are old, not wrong: keep them (the table marks
                -- them as old) and say so. This page has no clock, so the time
                -- given for a failed answer is never used.
                { model
                    | products = Remote.refreshWith model.products (Err problem) (Time.millisToPosix 0)
                    , effects = Effect.push (Notify Danger "Products not refreshed" (Maybe.withDefault (Remote.title context.locale problem) (Remote.detail context.locale problem))) model.effects
                }

            else
                { model | products = Remote.Failed problem }


{-| The one place that changes the chosen category. The tree shows it, the
table is narrowed to it (see `viewTable`), and the table starts again at its
first page: it cannot know that a filter of ours changed.
-}
setCategory : Maybe Category -> Model -> Model
setCategory category model =
    { model
        | category = category
        , tree =
            case category of
                Just chosen ->
                    Tree.select Ids.string chosen.id model.tree

                Nothing ->
                    Tree.setSelectedIds Ids.string [] model.tree
        , table = Table.setPage 1 model.table
    }


{-| New products came in: the chosen category is looked up in the new
hierarchy (its count may have changed), and dropped if it is gone.
-}
refreshCategory : List Branch -> Model -> Model
refreshCategory categories model =
    case model.category of
        Nothing ->
            model

        Just chosen ->
            case Category.find chosen.id categories of
                Just fresh ->
                    { model | category = Just fresh }

                Nothing ->
                    setCategory Nothing model


{-| Inactive products are left out of a reorder, and the toast says so.
-}
reorderToast : Locale -> Int -> Int -> Effect
reorderToast locale marked skipped =
    let
        number n =
            Format.int locale n

        skippedText =
            if skipped == 0 then
                ""

            else
                " " ++ number skipped ++ " inactive " ++ Format.plural locale skipped { one = "product was", other = "products were" } ++ " skipped."
    in
    if marked == 0 then
        Notify Warning "Nothing to reorder" "Only active products can be reordered."

    else
        Notify Success
            "Marked for reorder"
            (number marked ++ " " ++ Format.plural locale marked { one = "product was", other = "products were" } ++ " marked for reorder." ++ skippedText)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Context -> Model -> Effect.View Msg
view context model =
    { content =
        Layout.stack [ Layout.gap 5 ]
            [ viewHeader context model
            , Layout.row [ Layout.gap 4, Layout.alignStart, Layout.wrap ]
                [ -- A narrow column: that is what `container` with `alignStart` is.
                  Layout.container [ Layout.maxWidth 280, Layout.alignStart ]
                    [ viewCategories context model ]

                -- Not `Layout.grow`: it has no basis to wrap at, so on a narrow
                -- screen the table would be squeezed beside the tree instead of
                -- moving below it.
                , Html.div [ Attr.style "flex" "1 1 420px", Attr.style "min-width" "0" ]
                    [ -- Drawing the table sorts and filters 1,500 rows. `Html.Lazy`
                      -- skips that when its inputs are what they were the last time,
                      -- for instance while the user moves through the tree with the
                      -- arrow keys.
                      Html.Lazy.lazy4 viewTable context.locale model.category model.products model.table
                    ]
                ]
            ]
    , overlays = []
    }


viewHeader : Context -> Model -> Html Msg
viewHeader context model =
    PageHeader.view
        [ PageHeader.title "Products"
        , PageHeader.subtitle "Prices, stock levels and suppliers. Choose a category to narrow the table, open a row for its details."
        , PageHeader.meta (headerFacts context model)
        ]


headerFacts : Context -> Model -> List (Html Msg)
headerFacts context model =
    case Remote.toMaybe model.products of
        Just products ->
            let
                number =
                    Format.int context.locale

                inCategory =
                    case model.category of
                        Just category ->
                            List.filter (Category.includes category) products

                        Nothing ->
                            products

                shown =
                    List.length inCategory

                total =
                    List.length products
            in
            List.concat
                [ case model.category of
                    Just category ->
                        [ PageHeader.metaItem "Category" (Category.pathLabel category.path) ]

                    Nothing ->
                        []
                , [ PageHeader.metaItem "Products"
                        (if shown == total then
                            number total

                         else
                            number shown ++ " of " ++ number total
                        )
                  , PageHeader.metaItem "Low on stock" (number (List.length (List.filter belowReorderLevel inCategory)))
                  ]
                ]

        _ ->
            []



-- VIEW: THE CATEGORY TREE


viewCategories : Context -> Model -> Html Msg
viewCategories context model =
    Card.view
        [ Card.headingLevel 2
        , Card.title "Categories"
        , Card.subtitle "Choose one to narrow the table."
        , Card.actions
            (case model.category of
                Just _ ->
                    [ Button.iconOnly [ Button.ghost, Button.small, Button.onClick ClearCategory ] Icon.close "Show all products" ]

                Nothing ->
                    []
            )
        ]
        [ case model.products of
            Remote.Failed _ ->
                -- The table says what went wrong and offers the retry. A second
                -- error here (an alert for screen readers) would only repeat it.
                Text.paragraphWith [ Text.secondary "The categories appear when the products have loaded." ]

            _ ->
                Tree.viewRemote TreeMsg
                    [ Tree.ariaLabel "Product categories"
                    , Tree.allowEmptySelection
                    , Tree.locale context.locale
                    , Tree.settings context.settings
                    , Tree.compact
                    , Tree.filterBox
                    , Tree.filterPlaceholder "Find a category ..."
                    , Tree.emptyState [ EmptyState.title "No categories" ]
                    , Tree.maxHeight 520
                    ]
                    model.tree
                    (Remote.map (\_ -> List.map treeNode model.categories) model.products)
        ]


treeNode : Branch -> Tree.Node String
treeNode (Branch category below) =
    (case below of
        [] ->
            Tree.leaf Ids.string category.id category.name

        _ ->
            Tree.branch Ids.string category.id category.name (List.map treeNode below)
    )
        |> Tree.withCount category.count



-- VIEW: THE TABLE


{-| The table and everything it needs to be drawn, as arguments, so that
`Html.Lazy` can tell whether anything changed. Each of them has to come
unchanged out of the model: a `Maybe` or a `Remote` made in `view` would be a
new value every time.
-}
viewTable : Locale -> Maybe Category -> Remote (List Product) -> Table.State String -> Html Msg
viewTable locale category products table =
    Table.view TableMsg
        ([ Table.ariaLabel "Products"
         , Table.locale locale
         , Table.columns (columns locale)
         , Table.remote products
         , Table.rowId Ids.string .sku
         , Table.rowLabel (\product -> product.name ++ " (" ++ product.sku ++ ")")
         , Table.searchable
         , Table.multiSort
         , Table.expandedRow (details locale)
         , Table.rowTone stockAccent
         , Table.bulkActions
            [ Button.view [ Button.small, Button.icon Icon.flag, Button.onClick ReorderSelected ] "Mark for reorder" ]
         , Table.exportCsv "products.csv"
         , Table.columnChooser
         , Table.densityToggle
         , Table.onRefresh Reload
         , Table.onRetry Reload
         , Table.onResetFilters FiltersReset
         , Table.maxHeight 620
         ]
            ++ narrowedTo category
        )
        table


{-| The category is a filter from outside the table. `rowFilter` leaves out the
rows that are not in it, and `activeExternalFilters` makes the table count it:
"1 filter active" with a reset, and "No matches" instead of "No data" when it
leaves nothing.
-}
narrowedTo : Maybe Category -> List (Table.Attribute String Product Msg)
narrowedTo category =
    case category of
        Just branch ->
            [ Table.rowFilter (Category.includes branch), Table.activeExternalFilters 1 ]

        Nothing ->
            []


{-| The name takes the width that is left, the other columns have a width of
their own. Together they are wider than a small screen, and the table scrolls
sideways under the pinned SKU.
-}
columns : Locale -> List (Table.Column Product Msg)
columns locale =
    [ Table.text (Table.columnId "sku") "SKU" .sku [ Table.pinned, Table.width 116, Table.filterText ]
    , Table.text (Table.columnId "name") "Name" .name [ Table.minWidth 200, Table.filterText ]
    , Table.text (Table.columnId "category") "Category" leafOf [ Table.width 130, Table.filterSelect, Table.exportAs (.category >> Category.pathLabel) ]
    , Table.text (Table.columnId "supplier") "Supplier" .supplier [ Table.width 170, Table.filterSelect ]
    , Table.float (Table.columnId "price") "Price" 2 .price [ Table.filterRange, Table.cell (priceCell locale) ]
    , Table.int (Table.columnId "stock") "Stock" .stock [ Table.width 130, Table.filterRange, Table.cell (stockCell locale) ]
    , Table.int (Table.columnId "reorder") "Reorder level" .reorderLevel [ Table.filterRange ]

    -- "Yes" and "No" are the text of this column, and the search looks in the
    -- text: without `notSearchable`, "no" would find every inactive product and
    -- "yes" nearly all of them.
    , Table.bool (Table.columnId "active") "Active" .active [ Table.filterSelect, Table.notSearchable ]
    ]


{-| The last step of the path: "Bolts" for Hardware > Fasteners > Bolts. The
whole path is in the details of the row and in the CSV file.
-}
leafOf : Product -> String
leafOf product =
    product.category |> List.reverse |> List.head |> Maybe.withDefault ""


{-| A column made with `Table.float` shows a plain number; the cell makes it a
price. Sorting, the range filter and the CSV file still use the number.
-}
priceCell : Locale -> Product -> Html Msg
priceCell locale product =
    Html.text (Format.currency locale "$" 2 product.price)


{-| The row that is expanded: what does not fit in a row.
-}
details : Locale -> Product -> Html Msg
details locale product =
    DescriptionList.view
        [ DescriptionList.columns 2, DescriptionList.density Theme.Compact, DescriptionList.locale locale ]
        [ DescriptionList.text "Supplier" product.supplier
        , DescriptionList.text "Category" (Category.pathLabel product.category)
        , DescriptionList.text "Reorder level" (Format.int locale product.reorderLevel)
        , DescriptionList.html "Stock status" (stockStatus locale product)
        ]



-- STOCK


{-| Where the stock is against the reorder level.
-}
type StockLevel
    = InStock
    | LowStock
    | OutOfStock


belowReorderLevel : Product -> Bool
belowReorderLevel product =
    product.stock < product.reorderLevel


{-| Nothing in stock is the worst case of being below the reorder level.
-}
stockLevel : Product -> StockLevel
stockLevel product =
    if product.stock <= 0 then
        OutOfStock

    else if belowReorderLevel product then
        LowStock

    else
        InStock


stockTone : StockLevel -> Tone
stockTone level =
    case level of
        InStock ->
            Success

        LowStock ->
            Warning

        OutOfStock ->
            Danger


stockLabel : StockLevel -> String
stockLabel level =
    case level of
        InStock ->
            "In stock"

        LowStock ->
            "Low stock"

        OutOfStock ->
            "Out of stock"


{-| The accent at the start of a row that needs attention.
-}
stockAccent : Product -> Maybe Tone
stockAccent product =
    case stockLevel product of
        InStock ->
            Nothing

        level ->
            Just (stockTone level)


{-| The number, with a small badge when the stock is low. The badge goes in
front, so that the numbers stay lined up at the right edge of the column.
-}
stockCell : Locale -> Product -> Html Msg
stockCell locale product =
    let
        number =
            Html.text (Format.int locale product.stock)
    in
    Layout.row [ Layout.gap 2, Layout.justifyEnd ]
        (case stockLevel product of
            InStock ->
                [ number ]

            LowStock ->
                [ Badge.view [ Badge.tone Warning, Badge.size Small ] "Low", number ]

            OutOfStock ->
                [ Badge.view [ Badge.tone Danger, Badge.size Small ] "Out", number ]
        )


{-| The state in words, and how far the stock is from the reorder level (a full
bar: at or above it).
-}
stockStatus : Locale -> Product -> Html Msg
stockStatus locale product =
    let
        level =
            stockLevel product
    in
    Layout.stack [ Layout.gap 2 ]
        [ -- In a row, so that the badge keeps its own width instead of filling the stack.
          Layout.row [] [ Badge.view [ Badge.tone (stockTone level) ] (stockLabel level) ]
        , Progress.view
            [ Progress.label "Against the reorder level"
            , Progress.outOf product.stock product.reorderLevel
            , Progress.showValue
            , Progress.tone (stockTone level)
            , Progress.size Small
            , Progress.locale locale
            ]
        ]
