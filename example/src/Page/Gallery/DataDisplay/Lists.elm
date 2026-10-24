module Page.Gallery.DataDisplay.Lists exposing (Model, Msg, init, update, view)

{-| The list item section: a master list with a selected row, a long scrolling
list, links with headings, long texts, a live queue that gets new rows while the
user is on it, and the loading, failed and empty states.
-}

import Api.Types as Types exposing (Order, Priority(..))
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Switch as Switch
import Klar.Text as Text
import Klar.Theme as Theme exposing (Tone(..))
import Page.Gallery.DataDisplay.Pretend as Pretend
import Process
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import Time
import View.Labels as Labels



-- MODEL


type alias Model =
    { selected : Maybe String
    , edited : Maybe String
    , retrying : Bool
    , queue : Remote (List Order)
    , arrived : Int
    , polling : Bool
    , poll : Int
    }


type Msg
    = Select String
    | Edit String
    | Retry
    | RetryDone
    | PollingToggled Bool
    | PollStarted Int
    | PollAnswered Int
    | NoOp


init : Model
init =
    { selected = ofPriority Normal 1 |> List.head |> Maybe.map (.id >> Types.orderIdText)
    , edited = Nothing
    , retrying = False
    , queue = Remote.Loaded (List.reverse (List.take 3 waiting))
    , arrived = 0
    , polling = False
    , poll = 0
    }


{-| The orders that arrive in the live queue, one by one: the first three are
there from the start.
-}
waiting : List Order
waiting =
    List.take 15 (List.drop 40 Sample.orders)


{-| How many orders can still arrive in the live queue.
-}
arrivals : Int
arrivals =
    List.length waiting - 3


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

        PollingToggled on ->
            -- a new number drops the timers of an earlier round
            ( { model | polling = on, poll = model.poll + 1 }
            , if on then
                after 1500 (PollStarted (model.poll + 1))

              else
                Cmd.none
            )

        PollStarted round ->
            if round == model.poll && model.polling then
                ( { model | queue = Remote.refresh model.queue }, after 1200 (PollAnswered round) )

            else
                ( model, Cmd.none )

        PollAnswered round ->
            if round == model.poll && model.polling then
                let
                    arrived =
                        model.arrived + 1

                    -- the newest order goes to the top, as in an inbox
                    orders =
                        List.reverse (List.take (3 + arrived) waiting)

                    done =
                        arrived >= arrivals
                in
                ( { model
                    | queue = Remote.refreshWith model.queue (Ok orders) Sample.now
                    , arrived = arrived
                    , polling = not done
                  }
                , if done then
                    Cmd.none

                  else
                    after 1500 (PollStarted round)
                )

            else
                ( model, Cmd.none )

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
            , code = Just """ListItem.list [ ListItem.ariaLabel "Orders", ListItem.bordered ]
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
                [ ListItem.list [ ListItem.ariaLabel "Orders", ListItem.bordered ]
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
            , code = Just "ListItem.list [ ListItem.maxHeight 300, ListItem.density Compact, ListItem.bordered ] rows"
            }
            (ListItem.list [ ListItem.maxHeight 300, ListItem.density Theme.Compact, ListItem.bordered, ListItem.ariaLabel "All orders" ]
                (List.map (plainRow locale model.selected) (List.take 300 Sample.orders))
            )
        , Doc.example
            { title = "Compact, comfortable, with headings and without dividers"
            , description = Just "Rows with an href are real links: these open the order page. Without density a list follows the density of the application; with it, the list keeps its own."
            , code = Just """ListItem.list [ ListItem.density Compact, ListItem.undivided ]
    [ ListItem.heading "Today"
    , ListItem.view [ ListItem.icon Icon.fileText, ListItem.href "#/orders/ORD-10001" ] "Delivery note.pdf"
    ]"""
            }
            (Layout.grid [ Layout.minColumn 300, Layout.gap 6 ]
                [ ListItem.list [ ListItem.density Theme.Compact, ListItem.bordered, ListItem.ariaLabel "Files" ]
                    [ ListItem.heading "Today"
                    , fileRow Icon.fileText "Delivery note ORD-10001.pdf" 142400
                    , fileRow Icon.image "Packing photo.png" 3100000
                    , ListItem.heading "Earlier"
                    , fileRow Icon.file "Purchase order.docx" 58300
                    , fileRow Icon.archive "Orders 2025.zip" 12400000
                    ]
                , ListItem.list [ ListItem.density Theme.Comfortable, ListItem.undivided, ListItem.ariaLabel "Comfortable, without dividers" ]
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
            (ListItem.list [ ListItem.bordered, ListItem.ariaLabel "Long texts" ]
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
            { title = "A live queue"
            , description = Just "Turn it on, then Tab into the list and stay on a row. Every few seconds the queue is refreshed and a new order arrives at the top, but the focus stays on the order you are on, and Enter opens that one: the rows are keyed by the id of their order, and a refresh draws them inside the same elements."
            , code = Just """ListItem.viewRemote [ ListItem.ariaLabel "Queue", ListItem.bordered ]
    (Remote.map (List.map (\\order -> ( order.id, viewOrder order ))) model.queue)"""
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Switch.view
                    [ Switch.label "Receive new orders"
                    , Switch.description
                        (String.fromInt (arrivals - model.arrived) ++ " more orders are waiting.")
                    , Switch.checked model.polling
                    , Switch.onToggle PollingToggled
                    , Switch.disabled (model.arrived >= arrivals)
                    ]
                , ListItem.viewRemote
                    [ ListItem.ariaLabel "Queue", ListItem.bordered, ListItem.locale locale ]
                    (Remote.map (List.map (keyed (plainRow locale model.selected))) model.queue)
                ]
            )
        , Doc.example
            { title = "Loading, failed and empty list"
            , description = Just "The failed list retries: the backend is down on purpose, so it loads for a moment and fails again."
            , code = Just """ListItem.viewRemote
    [ ListItem.bordered
    , ListItem.skeletonRows 3
    , ListItem.onRetry Reload
    , ListItem.emptyState [ EmptyState.title "No orders", EmptyState.icon Icon.search ]
    ]
    (Remote.map (List.map (\\order -> ( order.id, viewOrder order ))) model.orders)"""
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 4 ]
                [ ListItem.viewRemote [ ListItem.bordered, ListItem.ariaLabel "Orders", ListItem.skeletonRows 3, ListItem.locale locale ] Remote.Loading
                , ListItem.viewRemote
                    [ ListItem.bordered, ListItem.ariaLabel "Orders", ListItem.onRetry Retry, ListItem.locale locale ]
                    (Pretend.down locale model.retrying)
                , ListItem.viewRemote
                    [ ListItem.bordered
                    , ListItem.ariaLabel "Orders"
                    , ListItem.emptyState
                        [ EmptyState.title "No orders"
                        , EmptyState.description "No order matches the filter."
                        , EmptyState.icon Icon.search
                        ]
                    , ListItem.locale locale
                    ]
                    (Remote.Loaded [])
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
    , ListItem.secondary (Types.orderIdText order.id ++ " · " ++ order.city ++ " · " ++ Types.orderStatusLabel order.status)
    , ListItem.meta (Format.currency locale "$" 2 order.total)
    , ListItem.selected (selected == Just (Types.orderIdText order.id))
    , ListItem.onClick (Select (Types.orderIdText order.id))
    ]
        ++ accentOf order


orderRow : Locale -> Maybe String -> Order -> Html Msg
orderRow locale selected order =
    ListItem.view
        (ListItem.trailing
            [ Button.iconOnly [ Button.ghost, Button.small, Button.onClick (Edit (Types.orderIdText order.id)) ] Icon.edit ("Edit " ++ Types.orderIdText order.id) ]
            :: rowAttributes locale selected order
        )
        order.customer


plainRow : Locale -> Maybe String -> Order -> Html Msg
plainRow locale selected order =
    ListItem.view (rowAttributes locale selected order) order.customer


{-| A row with the id of its order as its key, for `ListItem.viewRemote`.
-}
keyed : (Order -> Html Msg) -> Order -> ( String, Html Msg )
keyed toRow order =
    ( Types.orderIdText order.id, toRow order )


after : Float -> Msg -> Cmd Msg
after ms msg =
    Process.sleep ms |> Task.perform (\_ -> msg)
