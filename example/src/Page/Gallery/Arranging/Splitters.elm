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
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Showcase.Sample as Sample



-- MODEL


type alias Model =
    { masterDetail : Splitter.State
    , saved : Maybe (List Splitter.Share)
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
    | FiltersToggled


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

        FiltersToggled ->
            ( { model
                | filters =
                    if Splitter.isFolded 0 model.filters then
                        Splitter.unfold 0 model.filters

                    else
                        Splitter.fold 0 model.filters
              }
            , Cmd.none
            )



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredSection playground
        []
        "Splitter"
        "Panes that the user makes larger and smaller by moving the separator between them. Drag a separator with the mouse or a finger, or tab to it and press the arrow keys (1 percent; with Shift 10 percent), Home and End (the smallest and the largest size of the pane before it), and Enter (fold a pane away, where it may be folded). The sizes are shares of the room, so they follow the window. The panes scroll inside themselves."
        [ masterDetailExample playground locale model
        , workspaceExample playground locale model
        , foldExample playground locale model
        ]


sizesText : Splitter.State -> String
sizesText state =
    Splitter.sizes state
        |> List.map (\size -> String.fromInt (round (Splitter.toPercent size)) ++ "%")
        |> String.join "  /  "


framed : Config.Config -> Html msg -> Html msg
framed playground content =
    Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "flush" Card.flush ])) [ content ]


masterDetailExample : Config.Config -> Locale -> Model -> Html Msg
masterDetailExample playground locale model =
    let
        selected =
            orders |> List.drop model.selected |> List.head
    in
    Doc.configuredExample playground
        [ "Card", "Splitter", "ListItem", "DescriptionList", "Badge" ]
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
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ framed playground
                (Splitter.view MasterDetailMsg
                    (Options.klarSplitter playground (List.concat [ Config.keep playground "Splitter" "height" (Splitter.height 360), Config.keep playground "Splitter" "locale" (Splitter.locale locale) ]))
                    model.masterDetail
                    [ Splitter.pane "Orders" (orderList playground model.selected) |> Splitter.minPixels 220
                    , Splitter.pane "Details" (orderDetail playground locale selected) |> Splitter.minPixels 280
                    ]
                )
            , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.save), Config.keep playground "Button" "onClick" (Button.onClick SaveLayout) ])) "Save the layout"
                , Options.buttonView playground
                    (Options.klarButton playground
                        (List.concat
                            [ Config.keep playground "Button" "small" Button.small
                            , Config.keep playground "Button" "icon" (Button.icon Icon.undo)
                            , Config.keep playground "Button" "onClick" (Button.onClick RestoreLayout)
                            , Config.keep playground "Button" "disabled" (Button.disabled (model.saved == Nothing))
                            ]
                        )
                    )
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


orderList : Config.Config -> Int -> Html Msg
orderList playground selected =
    ListItem.list [ ListItem.ariaLabel "Orders" ]
        (List.indexedMap
            (\index order ->
                ListItem.view
                    (Options.klarListItem playground
                        (List.concat
                            [ Config.keep playground "ListItem" "secondary" (ListItem.secondary order.customer)
                            , Config.keep playground "ListItem" "meta" (ListItem.meta order.city)
                            , Config.keep playground "ListItem" "selected" (ListItem.selected (index == selected))
                            , Config.keep playground "ListItem" "onClick" (ListItem.onClick (Select index))
                            ]
                        )
                    )
                    (Types.orderIdText order.id)
            )
            orders
        )


orderDetail : Config.Config -> Locale -> Maybe Order -> Html msg
orderDetail playground locale maybeOrder =
    case maybeOrder of
        Just order ->
            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "padding" (Layout.padding 4) ]))
                [ Text.subheading (Types.orderIdText order.id)
                , DescriptionList.view (Options.klarDescriptionList playground (List.concat [ Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 1), Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale) ]))
                    [ DescriptionList.text "Customer" order.customer
                    , DescriptionList.text "City" order.city
                    , DescriptionList.html "Status" (Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Info) ])) (Types.orderStatusLabel order.status))
                    , DescriptionList.text "Lines" (String.fromInt order.lines)
                    , DescriptionList.text "Total" (Format.currency locale "EUR " 2 order.total)
                    , DescriptionList.text "Due" (Format.date locale order.due)
                    , DescriptionList.text "Note" order.note |> DescriptionList.fullWidth
                    ]
                ]

        Nothing ->
            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "padding" (Layout.padding 4) ])) [ Text.caption "Select an order." ]


workspaceExample : Config.Config -> Locale -> Model -> Html Msg
workspaceExample playground locale model =
    let
        selected =
            orders |> List.drop model.selected |> List.head
    in
    Doc.configuredExample playground
        [ "Card", "Splitter", "ListItem", "DescriptionList", "Badge" ]
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
        (framed playground
            (Splitter.view WorkspaceMsg
                (Options.klarSplitter playground (List.concat [ Config.keep playground "Splitter" "height" (Splitter.height 420), Config.keep playground "Splitter" "locale" (Splitter.locale locale) ]))
                model.workspace
                [ Splitter.pane "Warehouses" (warehouseList playground) |> Splitter.minPixels 140
                , Splitter.pane "Orders"
                    (Splitter.view CenterMsg
                        (Options.klarSplitter playground (List.concat [ Config.keep playground "Splitter" "stacked" Splitter.stacked, Config.keep playground "Splitter" "locale" (Splitter.locale locale) ]))
                        model.center
                        [ Splitter.pane "Order list" (orderList playground model.selected) |> Splitter.minPixels 120
                        , Splitter.pane "Preview" (orderPreview playground selected) |> Splitter.minPixels 80
                        ]
                    )
                    |> Splitter.minPixels 220
                , Splitter.pane "Details" (orderDetail playground locale selected) |> Splitter.minPixels 220
                ]
            )
        )


warehouseList : Config.Config -> Html msg
warehouseList playground =
    ListItem.list [ ListItem.ariaLabel "Warehouses" ]
        (List.map
            (\warehouse -> ListItem.view (Options.klarListItem playground (List.concat [ Config.keep playground "ListItem" "icon" (ListItem.icon Icon.warehouse) ])) warehouse.name)
            (List.take 8 Sample.warehouses)
        )


orderPreview : Config.Config -> Maybe Order -> Html msg
orderPreview playground maybeOrder =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "padding" (Layout.padding 4) ]))
        (case maybeOrder of
            Just order ->
                [ Text.strong (Types.orderIdText order.id ++ ", " ++ order.customer)
                , Text.paragraph order.note
                ]

            Nothing ->
                [ Text.caption "Select an order." ]
        )


foldExample : Config.Config -> Locale -> Model -> Html Msg
foldExample playground locale model =
    Doc.configuredExample playground
        [ "Splitter", "Card", "ListItem" ]
        { title = "A pane that folds away"
        , description = Just "Press Enter on the separator, or double-click it, to fold the filters away and to open them again. A folded pane has no room, and it is not there for the keyboard or for screen readers; its size is 0 in the saved sizes, so a layout that is saved folded comes back folded. The button does the same with fold and unfold: drag the separator, fold the filters with the button, and unfold gives back the width you had."
        , code = Just """Splitter.view FiltersMsg
    []
    model.filters
    [ Splitter.pane "Filters" filters
        |> Splitter.minPixels 180
        |> Splitter.collapsible
    , Splitter.pane "Results" results
    ]

-- fold and unfold from a button
FiltersToggled ->
    ( { model
        | filters =
            if Splitter.isFolded 0 model.filters then
                Splitter.unfold 0 model.filters

            else
                Splitter.fold 0 model.filters
      }
    , Cmd.none
    )"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ if Splitter.isFolded 0 model.filters then
                    Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.chevronRight), Config.keep playground "Button" "onClick" (Button.onClick FiltersToggled) ])) "Show the filters"

                  else
                    Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.chevronLeft), Config.keep playground "Button" "onClick" (Button.onClick FiltersToggled) ])) "Hide the filters"
                , Text.caption ("Now: " ++ sizesText model.filters)
                ]
            , framed playground
                (Splitter.view FiltersMsg
                    (Options.klarSplitter playground (List.concat [ Config.keep playground "Splitter" "height" (Splitter.height 220), Config.keep playground "Splitter" "locale" (Splitter.locale locale) ]))
                    model.filters
                    [ Splitter.pane "Filters" (filterPanel playground) |> Splitter.minPixels 180 |> Splitter.collapsible
                    , Splitter.pane "Results" (resultList playground locale)
                    ]
                )
            ]
        )


filterPanel : Config.Config -> Html msg
filterPanel playground =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "padding" (Layout.padding 4) ]))
        [ Text.strong "Filters"
        , Text.caption "Status: open"
        , Text.caption "Warehouse: Rotterdam"
        , Text.caption "Due: this week"
        ]


resultList : Config.Config -> Locale -> Html msg
resultList playground locale =
    ListItem.list [ ListItem.ariaLabel "Results" ]
        (List.map
            (\order ->
                ListItem.view
                    (Options.klarListItem playground
                        (List.concat
                            [ Config.keep playground "ListItem" "secondary" (ListItem.secondary order.customer)
                            , Config.keep playground "ListItem" "meta" (ListItem.meta (Format.currency locale "EUR " 2 order.total))
                            ]
                        )
                    )
                    (Types.orderIdText order.id)
            )
            (List.take 12 orders)
        )
