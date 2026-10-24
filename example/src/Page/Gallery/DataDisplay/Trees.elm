module Page.Gallery.DataDisplay.Trees exposing (Model, Msg, init, update, view)

{-| The tree section: filter and lazy loading, the selection modes, a tree with
thousands of nodes, and the loading, failed and empty states.
-}

import Api.Types exposing (orderIdText)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Lazy
import Klar.Button as Button
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.Tree as Tree
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Doc as Doc
import Showcase.Sample as Sample



-- MODEL


type alias Model =
    { company : Tree.State String
    , branches : Dict String (Remote (List Entry))
    , activated : Maybe String
    , categories : Tree.State String
    , permissions : Tree.State String
    , orders : Tree.State String
    , failedTree : Tree.State String
    , retrying : Bool
    }


type Msg
    = CompanyMsg Tree.Msg
    | CategoriesMsg Tree.Msg
    | PermissionsMsg Tree.Msg
    | OrdersMsg Tree.Msg
    | StateMsg Tree.Msg
    | FailedTreeMsg Tree.Msg
    | ExpandAll
    | CollapseAll
    | LoadBranch String
    | BranchLoaded String (Result Problem (List Entry))
    | Activated String
    | Retry
    | RetryDone


init : Model
init =
    { company =
        Tree.init "company-tree"
            |> Tree.setExpandedIds Ids.string [ "acme", "rtm", "rtm-a" ]
            |> Tree.select Ids.string "rtm-a2"
    , branches = Dict.empty
    , activated = Nothing
    , categories = Tree.init "category-tree" |> Tree.setExpandedIds Ids.string [ "Hardware", "Hardware/Fasteners", "Hardware/Tools" ]
    , permissions =
        Tree.init "permission-tree"
            |> Tree.setExpandedIds Ids.string [ "orders", "admin" ]
            |> Tree.setCheckedIds Ids.string [ "orders-read", "orders-create", "products-read" ]
    , orders = Tree.init "order-tree"
    , failedTree = Tree.init "tree-failed"
    , retrying = False
    }



-- UPDATE


update : Bool -> Msg -> Model -> ( Model, Cmd Msg )
update failing msg model =
    case msg of
        CompanyMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.company

                -- The new state says which lazy nodes asked for their children.
                ( loading, loadCmd ) =
                    startLoading failing (Tree.loadRequests Ids.string tree) { model | company = tree }
            in
            ( loading, Cmd.batch [ Cmd.map CompanyMsg cmd, loadCmd ] )

        CategoriesMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.categories
            in
            ( { model | categories = tree }, Cmd.map CategoriesMsg cmd )

        PermissionsMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.permissions
            in
            ( { model | permissions = tree }, Cmd.map PermissionsMsg cmd )

        OrdersMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.orders
            in
            ( { model | orders = tree }, Cmd.map OrdersMsg cmd )

        StateMsg _ ->
            ( model, Cmd.none )

        FailedTreeMsg inner ->
            -- The tree moves the focus off "Try again" before it goes away.
            let
                ( tree, cmd ) =
                    Tree.update inner model.failedTree
            in
            ( { model | failedTree = tree }, Cmd.map FailedTreeMsg cmd )

        ExpandAll ->
            -- The ids of the nodes do not depend on the language.
            ( { model | company = Tree.expandAll (companyNodes Locale.default model.branches) model.company }
            , Cmd.none
            )

        CollapseAll ->
            ( { model | company = Tree.collapseAll model.company }, Cmd.none )

        LoadBranch id ->
            -- "Try again" is replaced by the loading row; the tree has already
            -- put the focus back on the node.
            startLoading failing [ id ] model

        BranchLoaded id result ->
            ( { model | branches = Dict.insert id (Remote.fromResult result) model.branches }, Cmd.none )

        Activated id ->
            ( { model | activated = Just id }, Cmd.none )

        Retry ->
            ( { model | retrying = True }, Pretend.later RetryDone )

        RetryDone ->
            ( { model | retrying = False }, Cmd.none )


startLoading : Bool -> List String -> Model -> ( Model, Cmd Msg )
startLoading failing ids model =
    ( { model | branches = List.foldl (\id -> Dict.insert id Remote.Loading) model.branches ids }
    , Cmd.batch
        (List.map
            (\id -> Cmd.map (BranchLoaded id) (Pretend.respond failing (childrenOf id)))
            ids
        )
    )



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "Tree"
        "Hierarchical data: warehouses, product categories, code lists. The tree follows the WAI-ARIA tree pattern, with one tab stop for the whole tree. The arrow keys move, Right opens a node and moves into it, Left closes it and moves out, Home and End jump to the first and last row, Space selects, Enter opens the item, * opens all nodes on the same level, and letters jump to the next node that starts with them. In the filter box, Down moves into the tree and Escape clears the filter."
        [ companyExample locale model
        , categoriesExample locale model
        , permissionsExample locale model
        , ordersExample locale model
        , statesExample locale model
        ]


names : List String -> String
names ids =
    if List.isEmpty ids then
        "none"

    else
        String.join ", " ids


lastName : String -> String
lastName id =
    String.split "/" id |> List.reverse |> List.head |> Maybe.withDefault id


companyExample : Locale -> Model -> Html Msg
companyExample locale model =
    let
        selectedText =
            case Tree.selectedId Ids.string model.company of
                Just id ->
                    "Selected: " ++ id

                Nothing ->
                    "Nothing selected"

        activatedText =
            case model.activated of
                Just id ->
                    "Opened (Enter or double-click): " ++ id

                Nothing ->
                    "Enter or double-click opens an item."
    in
    Doc.example
        { title = "Company structure with filter and lazy loading"
        , description = Just "The filter keeps the ancestors of the matches and marks the matching text. “Suppliers” and “Product catalog” are fetched the first time they are opened: a spinner while it happens, and a short message with “Try again” when it fails (switch on “Simulate failures” at the top). The categories inside “Product catalog” are lazy nodes inside a lazy node. “Expand all” opens the lazy branches too, and they ask for their children at once. The filter searches the labels, the descriptions and the keywords of the nodes that are loaded: “NL” finds Rotterdam by a keyword."
        , code = Just """Tree.view CompanyMsg
    [ Tree.ariaLabel "Company structure"
    , Tree.filterBox
    , Tree.onActivate Activated
    , Tree.onRetryChildren LoadBranch
    , Tree.maxHeight 440
    ]
    model.tree
    [ (Tree.branch Ids.string) "rtm" "Rotterdam Hub"
        [ (Tree.leaf Ids.string) "rtm-a1" "Bay A1" |> Tree.withCount 28 ]
        |> Tree.withIcon Icon.building
        |> Tree.withKeywords [ "NL", "Netherlands" ]
    , (Tree.lazy Ids.string) "suppliers" "Suppliers" (lookup "suppliers" model.branches)
    ]

-- update: the new state says which lazy nodes asked for their children.
-- lookup, markLoading and fetch are yours: they read and write model.branches
-- and send the request.
CompanyMsg m ->
    let
        ( tree, cmd ) =
            Tree.update m model.tree

        requests =
            (Tree.loadRequests Ids.string) tree
    in
    ( { model | tree = tree, branches = markLoading requests model.branches }
    , Cmd.batch (Cmd.map CompanyMsg cmd :: List.map fetch requests)
    )

-- "Try again": the tree puts the focus back on the node by itself
LoadBranch id ->
    ( { model | branches = markLoading [ id ] model.branches }, fetch id )"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                [ Button.view [ Button.small, Button.icon Icon.maximize, Button.onClick ExpandAll ] "Expand all"
                , Button.view [ Button.small, Button.icon Icon.minimize, Button.onClick CollapseAll ] "Collapse all"
                , Layout.spacer
                , Text.caption selectedText
                ]
            , Tree.view CompanyMsg
                [ Tree.ariaLabel "Company structure"
                , Tree.filterBox
                , Tree.onActivate Activated
                , Tree.onRetryChildren LoadBranch
                , Tree.maxHeight 440
                , Tree.locale locale
                ]
                model.company
                (companyNodes locale model.branches)
            , Text.caption activatedText
            ]
        )


categoriesExample : Locale -> Model -> Html Msg
categoriesExample locale model =
    Doc.example
        { title = "Multiple selection"
        , description = Just "Click selects one, Ctrl+click adds or removes, Shift+click selects a range. From the keyboard: Space toggles, Shift+arrows extend. Disabled nodes cannot be selected."
        , code = Just """Tree.view CategoriesMsg [ Tree.multiSelect, Tree.ariaLabel "Categories" ] model.tree nodes

(Tree.selectedIds Ids.string) model.tree -- [ "Hardware/Fasteners/Bolts", "Hardware/Fasteners/Nuts" ]"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Tree.view CategoriesMsg
                [ Tree.multiSelect, Tree.ariaLabel "Categories", Tree.locale locale ]
                model.categories
                categoryNodes
            , Text.caption ("Selected: " ++ names (List.map lastName (Tree.selectedIds Ids.string model.categories)))
            ]
        )


permissionsExample : Locale -> Model -> Html Msg
permissionsExample locale model =
    Doc.example
        { title = "Checkboxes with three states"
        , description = Just "Checking a parent checks everything below it; a parent with some of its children checked shows a dash. Space toggles the check. The application reads the checked leaves with Tree.checkedIds."
        , code = Just """Tree.view PermissionsMsg [ Tree.checkboxes, Tree.ariaLabel "Permissions" ] model.tree permissions

(Tree.checkedIds Ids.string) model.tree -- [ "orders-read", "products-read" ]"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Tree.view PermissionsMsg
                [ Tree.checkboxes, Tree.ariaLabel "Permissions", Tree.locale locale ]
                model.permissions
                permissions
            , Text.caption ("Checked: " ++ names (Tree.checkedIds Ids.string model.permissions))
            ]
        )


ordersExample : Locale -> Model -> Html Msg
ordersExample locale model =
    Doc.example
        { title = "Large tree"
        , description = Just "About four thousand nodes. Only open branches are drawn, and a branch with more than 300 children (the default) shows the first ones and “Show 300 more”. Open “All orders” and try the filter (“logistics”, “rotterdam”)."
        , code = Just """Tree.view OrdersMsg [ Tree.compact, Tree.maxHeight 360, Tree.filterBox, Tree.maxChildren 300 ] model.tree nodes

-- ids are unique in the whole tree: an order that is listed under its city and
-- under "All orders" has two ids, "city-Oslo/ORD-10042" and "all/ORD-10042"
(Tree.leaf Ids.string) ("all/" ++ order.id) order.customer |> Tree.withDescription order.id"""
        }
        (Html.Lazy.lazy2 orderTree locale model.orders)


{-| The big tree on its own, so that it can be left alone while something else
on the page changes.
-}
orderTree : Locale -> Tree.State String -> Html Msg
orderTree locale state =
    Tree.view OrdersMsg
        [ Tree.compact
        , Tree.maxHeight 360
        , Tree.filterBox
        , Tree.maxChildren 300
        , Tree.ariaLabel "Orders"
        , Tree.locale locale
        ]
        state
        orderNodes


statesExample : Locale -> Model -> Html Msg
statesExample locale model =
    Doc.example
        { title = "Loading, failed and empty tree"
        , description = Just "While loading, the tree shows a skeleton. A failure shows the problem with “Try again”: here the backend is down on purpose, so the tree loads for a moment and fails again. Pressing it keeps the keyboard focus in the tree, which stays the same element in every state. An empty list shows the empty state you give it."
        , code = Just "Tree.viewRemote TreeMsg [ Tree.onRetry Reload, Tree.emptyState [ EmptyState.title \"No warehouses\" ] ] model.tree model.nodes"
        }
        (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
            [ Tree.viewRemote StateMsg [ Tree.locale locale ] (Tree.init "tree-loading") Remote.Loading
            , Tree.viewRemote FailedTreeMsg
                [ Tree.onRetry Retry, Tree.locale locale ]
                model.failedTree
                (Pretend.down locale model.retrying)
            , Tree.viewRemote StateMsg
                [ Tree.emptyState [ EmptyState.title "No warehouses registered" ], Tree.locale locale ]
                (Tree.init "tree-empty")
                (Remote.Loaded [])
            ]
        )



-- NODES


{-| What the pretend backend sends for a branch. It is plain data and the nodes
are built from it on every render, so that a lazy node inside a fetched branch
finds its own state in the model.
-}
type Entry
    = Item String String Int
    | Folder String String (List Entry)
    | Deferred String String


{-| Turns entries into nodes. `lookup` gives the children of a lazy node, and
`decorate` adds badges and the like to a leaf, by its id.
-}
nodesOf : (String -> Remote (List Entry)) -> (String -> Tree.Node String -> Tree.Node String) -> List Entry -> List (Tree.Node String)
nodesOf lookup decorate entries =
    List.map
        (\entry ->
            case entry of
                Item id label count ->
                    Tree.leaf Ids.string id label |> Tree.withCount count |> decorate id

                Folder id label children ->
                    Tree.branch Ids.string id label (nodesOf lookup decorate children) |> Tree.withIcon Icon.folder

                Deferred id label ->
                    Tree.lazy Ids.string id label (Remote.map (nodesOf lookup decorate) (lookup id)) |> Tree.withIcon Icon.folder
        )
        entries


companyNodes : Locale -> Dict String (Remote (List Entry)) -> List (Tree.Node String)
companyNodes locale branches =
    let
        lookup id =
            Dict.get id branches |> Maybe.withDefault Remote.NotAsked

        lazyBranch id label icon =
            Tree.lazy Ids.string id label (Remote.map (nodesOf lookup (\_ node -> node)) (lookup id))
                |> Tree.withIcon icon
    in
    [ Tree.branch Ids.string
        "acme"
        "Acme Trading"
        (warehouses
            ++ [ lazyBranch "suppliers" "Suppliers" Icon.globe
               , lazyBranch "catalog" "Product catalog" Icon.layers
               ]
        )
        |> Tree.withIcon Icon.home
    ]


warehouses : List (Tree.Node String)
warehouses =
    [ Tree.branch Ids.string
        "rtm"
        "Rotterdam Hub"
        [ Tree.branch Ids.string
            "rtm-a"
            "Hall A, inbound"
            [ Tree.leaf Ids.string "rtm-a1" "Bay A1, pallets" |> Tree.withCount 28
            , Tree.leaf Ids.string "rtm-a2" "Bay A2, parcels" |> Tree.withCount 24
            , Tree.leaf Ids.string "rtm-a3" "Bay A3, cold chain" |> Tree.withCount 19 |> Tree.withBadge Warning "Nearly full"
            ]
            |> Tree.withIcon Icon.folder
        , Tree.branch Ids.string
            "rtm-b"
            "Hall B, outbound"
            [ Tree.leaf Ids.string "rtm-b1" "Bay B1, express" |> Tree.withCount 31
            , Tree.leaf Ids.string "rtm-b2" "Bay B2, freight" |> Tree.withCount 22
            , Tree.leaf Ids.string "rtm-b3" "Bay B3, returns" |> Tree.withBadge Danger "Closed" |> Tree.disabled
            ]
            |> Tree.withIcon Icon.folder
        , Tree.leaf Ids.string "rtm-desk" "Returns desk" |> Tree.withIcon Icon.refresh |> Tree.withDescription "24 hours"
        ]
        |> Tree.withIcon Icon.building
        |> Tree.withKeywords [ "NL", "Netherlands" ]
    , Tree.branch Ids.string
        "ham"
        "Hamburg Central"
        [ Tree.branch Ids.string
            "ham-a"
            "Hall A, inbound"
            [ Tree.leaf Ids.string "ham-a1" "Bay A1, small parts" |> Tree.withCount 26
            , Tree.leaf Ids.string "ham-a2" "Bay A2, bulk goods" |> Tree.withCount 18
            ]
            |> Tree.withIcon Icon.folder
        , Tree.leaf Ids.string "ham-customs" "Customs office" |> Tree.withIcon Icon.briefcase
        , Tree.leaf Ids.string
            "ham-special"
            "Special handling area for oversized, hazardous and temperature-controlled goods, including quarantine and returns inspection, north wing"
            |> Tree.withCount 14
            |> Tree.withBadge Success "Open"
        ]
        |> Tree.withIcon Icon.building
    ]


{-| What the lazily loaded branches contain once the backend has answered.
-}
childrenOf : String -> List Entry
childrenOf id =
    if id == "suppliers" then
        suppliers

    else if id == "catalog" then
        List.map (\name -> Deferred ("cat:" ++ name) name) (namesBelow [])

    else if String.startsWith "cat:" id then
        categoryEntries "cat:" [ String.dropLeft 4 id ]

    else
        []


suppliers : List Entry
suppliers =
    Sample.products
        |> List.foldl (\product -> Dict.update product.supplier (\n -> Just (Maybe.withDefault 0 n + 1))) Dict.empty
        |> Dict.toList
        |> List.map (\( name, count ) -> Item ("supplier:" ++ name) name count)


{-| The product categories of the sample data as a tree. Ids are the paths, so
they are unique in the whole tree.
-}
categoryNodes : List (Tree.Node String)
categoryNodes =
    nodesOf (\_ -> Remote.NotAsked) decorateCategory (categoryEntries "" [])


categoryEntries : String -> List String -> List Entry
categoryEntries prefix path =
    List.map
        (\name ->
            let
                child =
                    path ++ [ name ]

                id =
                    prefix ++ String.join "/" child
            in
            if List.isEmpty (namesBelow child) then
                Item id name (productCount child)

            else
                Folder id name (categoryEntries prefix child)
        )
        (namesBelow path)


{-| The names one level below a path: the next part of every category path that
starts with it.
-}
namesBelow : List String -> List String
namesBelow path =
    let
        depth =
            List.length path
    in
    Sample.categoryPaths
        |> List.filter (\other -> List.take depth other == path)
        |> List.filterMap (\other -> List.drop depth other |> List.head)
        |> withoutRepeats


withoutRepeats : List String -> List String
withoutRepeats items =
    List.foldr
        (\item kept ->
            case kept of
                next :: _ ->
                    if next == item then
                        kept

                    else
                        item :: kept

                [] ->
                    [ item ]
        )
        []
        items


productCount : List String -> Int
productCount path =
    List.length (List.filter (\product -> product.category == path) Sample.products)


lowStockCount : List String -> Int
lowStockCount path =
    List.length (List.filter (\product -> product.category == path && product.stock < product.reorderLevel) Sample.products)


decorateCategory : String -> Tree.Node String -> Tree.Node String
decorateCategory id node =
    let
        path =
            String.split "/" id
    in
    if id == "Hardware/Tools/Power tools" then
        node |> Tree.withBadge Danger "Discontinued" |> Tree.disabled

    else if id == "Packaging/Protection/Foam" then
        node |> Tree.withBadge Success "New"

    else if lowStockCount path * 100 >= productCount path * 15 then
        node |> Tree.withBadge Warning "Low stock"

    else
        node


permissions : List (Tree.Node String)
permissions =
    [ Tree.branch Ids.string
        "orders"
        "Orders"
        [ Tree.leaf Ids.string "orders-read" "View orders"
        , Tree.leaf Ids.string "orders-create" "Create orders"
        , Tree.leaf Ids.string "orders-approve" "Approve orders"
        ]
        |> Tree.withIcon Icon.clipboard
    , Tree.branch Ids.string
        "products"
        "Products"
        [ Tree.leaf Ids.string "products-read" "View products"
        , Tree.leaf Ids.string "products-prices" "Change prices"
        ]
        |> Tree.withIcon Icon.tag
    , Tree.branch Ids.string
        "admin"
        "Administration"
        [ Tree.leaf Ids.string "admin-users" "Users"
        , Tree.leaf Ids.string "admin-roles" "Roles"
        , Tree.branch Ids.string
            "admin-audit"
            "Audit"
            [ Tree.leaf Ids.string "audit-read" "View the audit log"
            , Tree.leaf Ids.string "audit-export" "Export the audit log"
            ]
        , Tree.leaf Ids.string "admin-system" "System settings" |> Tree.disabled
        ]
        |> Tree.withIcon Icon.settings
    ]


{-| About four thousand nodes: twelve cities with their orders, and one node
with all three thousand orders. The same order is a node in two places, so the
ids start with the branch they are in.
-}
orderNodes : List (Tree.Node String)
orderNodes =
    let
        orderLeaf prefix order =
            Tree.leaf Ids.string (prefix ++ orderIdText order.id) order.customer |> Tree.withDescription (orderIdText order.id)

        city name =
            let
                inCity =
                    List.filter (\order -> order.city == name) Sample.orders
            in
            Tree.branch Ids.string ("city-" ++ name) name (List.map (orderLeaf ("city-" ++ name ++ "/")) inCity)
                |> Tree.withIcon Icon.mapPin
                |> Tree.withCount (List.length inCity)
    in
    List.map city (List.take 12 Sample.cities)
        ++ [ Tree.branch Ids.string "all-orders" "All orders" (List.map (orderLeaf "all/") Sample.orders)
                |> Tree.withIcon Icon.list
                |> Tree.withCount (List.length Sample.orders)
           ]
