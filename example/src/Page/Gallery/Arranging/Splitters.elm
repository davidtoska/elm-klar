module Page.Gallery.Arranging.Splitters exposing (Model, Msg, init, update, view)

{-| The splitter section: a master and its detail, three panes that hold another
splitter, and a pane that can be folded away.
-}

import Api.Types as Types exposing (Order)
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale exposing (Locale)
import Klar.Splitter as Splitter
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Showcase.Doc as Doc
import Showcase.Sample as Sample



-- MODEL


type alias Model =
    { masterDetail : Splitter.State
    , saved : Maybe (List Splitter.Size)
    , selected : Int
    , workspace : Splitter.State
    , center : Splitter.State
    , filters : Splitter.State
    }


type Msg
    = MasterDetailMsg Splitter.Msg
    | WorkspaceMsg Splitter.Msg
    | CenterMsg Splitter.Msg
    | FiltersMsg Splitter.Msg
    | Select Int
    | SaveLayout
    | RestoreLayout
    | FoldFilters
    | OpenFilters


init : Model
init =
    { masterDetail = Splitter.init "master-detail" [ Splitter.percent 40, Splitter.percent 60 ]
    , saved = Nothing
    , selected = 0
    , workspace = Splitter.init "workspace" [ Splitter.percent 18, Splitter.percent 47, Splitter.percent 35 ]
    , center = Splitter.init "workspace-center" [ Splitter.percent 60, Splitter.percent 40 ]
    , filters = Splitter.init "filters-split" [ Splitter.percent 28, Splitter.percent 72 ]
    }


orders : List Order
orders =
    List.take 24 Sample.orders



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MasterDetailMsg inner ->
            let
                ( split, cmd ) =
                    Splitter.update inner model.masterDetail
            in
            ( { model | masterDetail = split }, Cmd.map MasterDetailMsg cmd )

        WorkspaceMsg inner ->
            let
                ( split, cmd ) =
                    Splitter.update inner model.workspace
            in
            ( { model | workspace = split }, Cmd.map WorkspaceMsg cmd )

        CenterMsg inner ->
            let
                ( split, cmd ) =
                    Splitter.update inner model.center
            in
            ( { model | center = split }, Cmd.map CenterMsg cmd )

        FiltersMsg inner ->
            let
                ( split, cmd ) =
                    Splitter.update inner model.filters
            in
            ( { model | filters = split }, Cmd.map FiltersMsg cmd )

        Select index ->
            ( { model | selected = index }, Cmd.none )

        SaveLayout ->
            ( { model | saved = Just (Splitter.sizes model.masterDetail) }, Cmd.none )

        RestoreLayout ->
            case model.saved of
                Just sizes ->
                    ( { model | masterDetail = Splitter.setSizes sizes model.masterDetail }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        FoldFilters ->
            ( { model | filters = Splitter.setSizes [ Splitter.percent 0, Splitter.percent 100 ] model.filters }, Cmd.none )

        OpenFilters ->
            ( { model | filters = Splitter.setSizes [ Splitter.percent 28, Splitter.percent 72 ] model.filters }, Cmd.none )



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "Splitter"
        "Panes that the user makes larger and smaller by moving the separator between them. Drag a separator with the mouse or a finger, or tab to it and press the arrow keys (1 percent; with Shift 10 percent), Home and End (the smallest and the largest size of the pane before it), and Enter (fold a pane away, where it may be folded). The sizes are shares of the room, so they follow the window. The panes scroll inside themselves."
        [ masterDetailExample locale model
        , workspaceExample locale model
        , foldExample locale model
        ]


sizesText : Splitter.State -> String
sizesText state =
    Splitter.sizes state
        |> List.map (\size -> String.fromInt (round (Splitter.toPercent size)) ++ "%")
        |> String.join "  /  "


framed : Html msg -> Html msg
framed content =
    Card.view [ Card.flush ] [ content ]


masterDetailExample : Locale -> Model -> Html Msg
masterDetailExample locale model =
    let
        selected =
            orders |> List.drop model.selected |> List.head
    in
    Doc.example
        { title = "A master and its detail"
        , description = Just "The orders cannot be narrower than 220 pixels and the detail not narrower than 280. The sizes are kept in the state: save the layout, move the separator, and restore it, as an application would with the layout of a user. Resize the window and the panes keep their shares."
        , code = Just """Splitter.view MasterDetailMsg
    [ Splitter.height 360, Splitter.locale locale ]
    model.masterDetail
    [ Splitter.pane "Orders" (viewOrderList model)
        |> Splitter.minPixels 220
    , Splitter.pane "Details" (viewOrderDetail model)
        |> Splitter.minPixels 280
    ]

-- model: Splitter.init "master-detail" [ Splitter.percent 40, Splitter.percent 60 ]
-- save and restore the layout of the user
SaveLayout ->
    ( { model | saved = Just (Splitter.sizes model.masterDetail) }, Cmd.none )

RestoreLayout ->
    case model.saved of
        Just sizes ->
            ( { model | masterDetail = Splitter.setSizes sizes model.masterDetail }, Cmd.none )

        Nothing ->
            ( model, Cmd.none )"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ framed
                (Splitter.view MasterDetailMsg
                    [ Splitter.height 360, Splitter.locale locale ]
                    model.masterDetail
                    [ Splitter.pane "Orders" (orderList model.selected) |> Splitter.minPixels 220
                    , Splitter.pane "Details" (orderDetail locale selected) |> Splitter.minPixels 280
                    ]
                )
            , Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.small, Button.icon Icon.save, Button.onClick SaveLayout ] "Save the layout"
                , Button.view
                    [ Button.small
                    , Button.icon Icon.undo
                    , Button.onClick RestoreLayout
                    , Button.disabled (model.saved == Nothing)
                    ]
                    "Restore the saved layout"
                , Text.caption ("Now: " ++ sizesText model.masterDetail)
                , Text.caption
                    (case model.saved of
                        Just sizes ->
                            "Saved: " ++ sizesText (Splitter.init "saved" sizes)

                        Nothing ->
                            "Nothing saved."
                    )
                ]
            ]
        )


orderList : Int -> Html Msg
orderList selected =
    ListItem.list [ ListItem.listLabel "Orders" ]
        (List.indexedMap
            (\index order ->
                ListItem.view
                    [ ListItem.secondary order.customer
                    , ListItem.meta order.city
                    , ListItem.selected (index == selected)
                    , ListItem.onClick (Select index)
                    ]
                    (Types.orderIdText order.id)
            )
            orders
        )


orderDetail : Locale -> Maybe Order -> Html msg
orderDetail locale maybeOrder =
    case maybeOrder of
        Just order ->
            Layout.stack [ Layout.gap 3, Layout.padding 4 ]
                [ Text.subheading (Types.orderIdText order.id)
                , DescriptionList.view [ DescriptionList.columns 1, DescriptionList.locale locale ]
                    [ DescriptionList.text "Customer" order.customer
                    , DescriptionList.text "City" order.city
                    , DescriptionList.html "Status" (Badge.view [ Badge.tone Info ] (Types.orderStatusLabel order.status))
                    , DescriptionList.text "Lines" (String.fromInt order.lines)
                    , DescriptionList.text "Total" (Format.currency locale "EUR " 2 order.total)
                    , DescriptionList.text "Due" (Format.date locale order.due)
                    , DescriptionList.text "Note" order.note |> DescriptionList.fullWidth
                    ]
                ]

        Nothing ->
            Layout.stack [ Layout.padding 4 ] [ Text.caption "Select an order." ]


workspaceExample : Locale -> Model -> Html Msg
workspaceExample locale model =
    let
        selected =
            orders |> List.drop model.selected |> List.head
    in
    Doc.example
        { title = "Three panes, and a splitter inside a pane"
        , description = Just "The middle pane holds a second splitter whose panes lie one above the other (stacked), with horizontal separators: Up and Down move them. Each splitter has its own state and its own separators; the inner one has no height of its own, it fills its pane."
        , code = Just """Splitter.view WorkspaceMsg
    [ Splitter.height 420 ]
    model.workspace
    [ Splitter.pane "Warehouses" warehouseList
        |> Splitter.minPixels 140
    , Splitter.pane "Orders"
        (Splitter.view CenterMsg
            [ Splitter.stacked ]
            model.center
            [ Splitter.pane "Order list" orderList
                |> Splitter.minPixels 120
            , Splitter.pane "Preview" preview
                |> Splitter.minPixels 80
            ]
        )
    , Splitter.pane "Details" detail
        |> Splitter.minPixels 220
    ]"""
        }
        (framed
            (Splitter.view WorkspaceMsg
                [ Splitter.height 420, Splitter.locale locale ]
                model.workspace
                [ Splitter.pane "Warehouses" warehouseList |> Splitter.minPixels 140
                , Splitter.pane "Orders"
                    (Splitter.view CenterMsg
                        [ Splitter.stacked, Splitter.locale locale ]
                        model.center
                        [ Splitter.pane "Order list" (orderList model.selected) |> Splitter.minPixels 120
                        , Splitter.pane "Preview" (orderPreview selected) |> Splitter.minPixels 80
                        ]
                    )
                    |> Splitter.minPixels 220
                , Splitter.pane "Details" (orderDetail locale selected) |> Splitter.minPixels 220
                ]
            )
        )


warehouseList : Html msg
warehouseList =
    ListItem.list [ ListItem.listLabel "Warehouses" ]
        (List.map
            (\warehouse -> ListItem.view [ ListItem.icon Icon.warehouse ] warehouse.name)
            (List.take 8 Sample.warehouses)
        )


orderPreview : Maybe Order -> Html msg
orderPreview maybeOrder =
    Layout.stack [ Layout.gap 2, Layout.padding 4 ]
        (case maybeOrder of
            Just order ->
                [ Text.strong (Types.orderIdText order.id ++ ", " ++ order.customer)
                , Text.paragraph order.note
                ]

            Nothing ->
                [ Text.caption "Select an order." ]
        )


foldExample : Locale -> Model -> Html Msg
foldExample locale model =
    Doc.example
        { title = "A pane that folds away"
        , description = Just "Press Enter on the separator, or double-click it, to fold the filters away and to open them again. A folded pane has no room, and it is not there for the keyboard or for screen readers; its size is 0 in the saved sizes, so a layout that is saved folded comes back folded. The buttons do the same with setSizes."
        , code = Just """Splitter.view FiltersMsg
    []
    model.filters
    [ Splitter.pane "Filters" filters
        |> Splitter.minPixels 180
        |> Splitter.collapsible
    , Splitter.pane "Results" results
    ]

-- fold and open from a button
FoldFilters ->
    ( { model | filters = Splitter.setSizes [ Splitter.percent 0, Splitter.percent 100 ] model.filters }, Cmd.none )

OpenFilters ->
    ( { model | filters = Splitter.setSizes [ Splitter.percent 28, Splitter.percent 72 ] model.filters }, Cmd.none )"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.small, Button.icon Icon.chevronLeft, Button.onClick FoldFilters ] "Fold the filters away"
                , Button.view [ Button.small, Button.icon Icon.chevronRight, Button.onClick OpenFilters ] "Open the filters"
                , Text.caption ("Now: " ++ sizesText model.filters)
                ]
            , framed
                (Splitter.view FiltersMsg
                    [ Splitter.height 220, Splitter.locale locale ]
                    model.filters
                    [ Splitter.pane "Filters" filterPanel |> Splitter.minPixels 180 |> Splitter.collapsible
                    , Splitter.pane "Results" (resultList locale)
                    ]
                )
            ]
        )


filterPanel : Html msg
filterPanel =
    Layout.stack [ Layout.gap 2, Layout.padding 4 ]
        [ Text.strong "Filters"
        , Text.caption "Status: open"
        , Text.caption "Warehouse: Rotterdam"
        , Text.caption "Due: this week"
        ]


resultList : Locale -> Html msg
resultList locale =
    ListItem.list [ ListItem.listLabel "Results" ]
        (List.map
            (\order ->
                ListItem.view
                    [ ListItem.secondary order.customer
                    , ListItem.meta (Format.currency locale "EUR " 2 order.total)
                    ]
                    (Types.orderIdText order.id)
            )
            (List.take 12 orders)
        )
