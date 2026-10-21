module Page.Gallery.DataDisplay.Lists exposing (Model, Msg, init, update, view)

{-| The list item section: a master list with a selected row, a long scrolling
list, links with headings, long texts, and the loading, failed and empty states.
-}

import Api.Types as Types exposing (Order, Priority(..))
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Time
import View.Labels as Labels



-- MODEL


type alias Model =
    { selected : Maybe String
    , edited : Maybe String
    , retrying : Bool
    }


type Msg
    = Select String
    | Edit String
    | Retry
    | RetryDone
    | NoOp


init : Model
init =
    { selected = ofPriority Normal 1 |> List.head |> Maybe.map .id
    , edited = Nothing
    , retrying = False
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Select id ->
            ( { model | selected = Just id, edited = Nothing }, Cmd.none )

        Edit id ->
            ( { model | edited = Just id }, Cmd.none )

        Retry ->
            ( { model | retrying = True }, Pretend.later RetryDone )

        RetryDone ->
            ( { model | retrying = False }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    let
        row =
            orderRow locale model.selected

        fileRow icon name bytes =
            -- A real link: the order the file belongs to.
            ListItem.view
                [ ListItem.icon icon
                , ListItem.meta (Format.bytes locale bytes)
                , ListItem.href "#/orders/ORD-10001"
                ]
                name
    in
    Doc.section "List items"
        "Dense rows for records, as a menu of things to open or as the main list next to a detail view. The whole row is one click target (a button, or a link with href), and the actions on the right are buttons of their own that do not trigger the row. Tab moves between the rows, Enter or Space opens a row."
        [ Doc.example
            { title = "List with a selected row"
            , description = Just "The selected row is tinted and has a bar on the left. The bar on the left of the other rows shows the priority: amber for High, red for Urgent. A disabled row is visible but cannot be selected."
            , code = Just """ListItem.list [ ListItem.listLabel "Orders", ListItem.bordered ]
    [ ListItem.view
        [ ListItem.avatar "Aurora Logistics Ltd"
        , ListItem.secondary "ORD-10042 · Rotterdam · Shipped"
        , ListItem.meta "$1,284.00"
        , ListItem.accent Warning
        , ListItem.selected True
        , ListItem.onClick (Select "ORD-10042")
        ]
        "Aurora Logistics Ltd"
    ]"""
            }
            (Layout.stack [ Layout.gap 2 ]
                [ ListItem.list [ ListItem.listLabel "Orders", ListItem.bordered ]
                    (List.map row listOrders
                        ++ [ ListItem.view
                                [ ListItem.avatar "Cedar Print Ltd"
                                , ListItem.secondary "On credit hold, cannot be opened"
                                , ListItem.disabled True
                                , ListItem.onClick NoOp
                                ]
                                "Cedar Print Ltd"
                           ]
                    )
                , Text.caption
                    (case ( model.selected, model.edited ) of
                        ( _, Just id ) ->
                            "The edit button of " ++ id ++ " was pressed. It did not select the row."

                        ( Just id, Nothing ) ->
                            "Selected row: " ++ id

                        ( Nothing, Nothing ) ->
                            "No row selected."
                    )
                ]
            )
        , Doc.example
            { title = "Many rows in a scrolling list"
            , description = Just "300 rows in a list of at most 300 pixels. The list scrolls on its own, and Tab moves between the rows. The rows have no buttons of their own: 300 rows with an edit button each would be 600 stops for the Tab key."
            , code = Just "ListItem.list [ ListItem.maxHeight 300, ListItem.compact, ListItem.bordered ] rows"
            }
            (ListItem.list [ ListItem.maxHeight 300, ListItem.compact, ListItem.bordered, ListItem.listLabel "All orders" ]
                (List.map (plainRow locale model.selected) (List.take 300 Sample.orders))
            )
        , Doc.example
            { title = "Compact, with headings and without dividers"
            , description = Just "Rows with an href are real links: these open the order page."
            , code = Just """ListItem.list [ ListItem.compact, ListItem.undivided ]
    [ ListItem.heading "Today"
    , ListItem.view [ ListItem.icon Icon.fileText, ListItem.href "#/orders/ORD-10001" ] "Delivery note.pdf"
    ]"""
            }
            (Layout.grid [ Layout.minColumn 300, Layout.gap 6 ]
                [ ListItem.list [ ListItem.compact, ListItem.bordered, ListItem.listLabel "Files" ]
                    [ ListItem.heading "Today"
                    , fileRow Icon.fileText "Delivery note ORD-10001.pdf" 142400
                    , fileRow Icon.image "Packing photo.png" 3100000
                    , ListItem.heading "Earlier"
                    , fileRow Icon.file "Purchase order.docx" 58300
                    , fileRow Icon.archive "Orders 2025.zip" 12400000
                    ]
                , ListItem.list [ ListItem.compact, ListItem.undivided, ListItem.listLabel "Without dividers" ]
                    (List.map
                        (\order -> ListItem.view [ ListItem.secondary order.city, ListItem.meta (Types.orderStatusLabel order.status) ] order.customer)
                        (List.take 5 Sample.orders)
                    )
                ]
            )
        , Doc.example
            { title = "Long text"
            , description = Just "The title and the secondary line are cut with “...”, and the whole text is in the tooltip. The meta text and the actions keep their place."
            , code = Nothing
            }
            (ListItem.list [ ListItem.bordered, ListItem.listLabel "Long texts" ]
                [ ListItem.view
                    [ ListItem.icon Icon.fileText
                    , ListItem.secondary "This is a very long secondary line that describes the contents in detail and that will never fit on one line in a narrow column"
                    , ListItem.meta (Format.dateTime locale Time.utc Sample.now)
                    , ListItem.trailing [ Badge.view [ Badge.tone Warning ] "Needs approval" ]
                    ]
                    "Summary of the cross-department meeting on delivery planning, customs clearance, pallet packaging and payment terms for the customer"
                ]
            )
        , Doc.example
            { title = "Loading, failed and empty list"
            , description = Just "The failed list retries: the backend is down on purpose, so it loads for a moment and fails again."
            , code = Just """ListItem.remote
    [ ListItem.bordered
    , ListItem.skeletonRows 3
    , ListItem.onRetry Reload
    , ListItem.emptyTitle "No orders"
    , ListItem.emptyIcon Icon.search
    ]
    viewRow
    model.orders"""
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 4 ]
                [ ListItem.remote [ ListItem.bordered, ListItem.listLabel "Orders", ListItem.skeletonRows 3, ListItem.locale locale ] row Remote.Loading
                , ListItem.remote
                    [ ListItem.bordered, ListItem.listLabel "Orders", ListItem.onRetry Retry, ListItem.locale locale ]
                    row
                    (Pretend.down locale model.retrying)
                , ListItem.remote
                    [ ListItem.bordered
                    , ListItem.listLabel "Orders"
                    , ListItem.emptyTitle "No orders"
                    , ListItem.emptyDescription "No order matches the filter."
                    , ListItem.emptyIcon Icon.search
                    , ListItem.locale locale
                    ]
                    row
                    (Remote.Success [])
                ]
            )
        ]



-- ROWS


{-| The first orders of a priority in the sample data.
-}
ofPriority : Priority -> Int -> List Order
ofPriority priority count =
    Sample.orders |> List.filter (\order -> order.priority == priority) |> List.take count


{-| Five orders with different priorities, so the bars on the left differ.
-}
listOrders : List Order
listOrders =
    ofPriority Urgent 1 ++ ofPriority High 1 ++ ofPriority Normal 2 ++ ofPriority Low 1


accentOf : Order -> List (ListItem.Attribute msg)
accentOf order =
    if order.priority == High || order.priority == Urgent then
        [ ListItem.accent (Labels.priorityTone order.priority) ]

    else
        []


{-| What every row of an order has. The rows with an edit button of their own add
it; the long list does without: 300 rows with a button each would be 600 stops
for the Tab key.
-}
rowAttributes : Locale -> Maybe String -> Order -> List (ListItem.Attribute Msg)
rowAttributes locale selected order =
    [ ListItem.avatar order.customer
    , ListItem.secondary (order.id ++ " · " ++ order.city ++ " · " ++ Types.orderStatusLabel order.status)
    , ListItem.meta (Format.currency locale "$" 2 order.total)
    , ListItem.selected (selected == Just order.id)
    , ListItem.onClick (Select order.id)
    ]
        ++ accentOf order


orderRow : Locale -> Maybe String -> Order -> Html Msg
orderRow locale selected order =
    ListItem.view
        (ListItem.trailing
            [ Button.iconOnly [ Button.ghost, Button.small, Button.onClick (Edit order.id) ] Icon.edit ("Edit " ++ order.id) ]
            :: rowAttributes locale selected order
        )
        order.customer


plainRow : Locale -> Maybe String -> Order -> Html Msg
plainRow locale selected order =
    ListItem.view (rowAttributes locale selected order) order.customer
