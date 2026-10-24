module Page.Gallery.DataDisplay.Timelines exposing (Model, Msg, init, update, view)

{-| The timeline section: an order log that loads more events on demand, the
compact and ungrouped looks, and the loading, empty and failed states.
-}

import Api.Types exposing (orderIdText)
import Html exposing (Html)
import Klar
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.RemoteView as RemoteView
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.Timeline as Timeline
import Page.Gallery.DataDisplay.Avatars exposing (portrait)
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Time



-- MODEL


type alias Model =
    { shown : Int
    , morePages : Remote Bool
    , retrying : Bool
    }


type Msg
    = LoadMore
    | MoreLoaded (Result Problem ())
    | Retry
    | RetryDone
    | Focused


init : Model
init =
    { shown = 12
    , morePages = Remote.Loaded True
    , retrying = False
    }


update : Bool -> Msg -> Model -> ( Model, Cmd Msg )
update failing msg model =
    case msg of
        LoadMore ->
            ( { model | morePages = Remote.refresh model.morePages }
            , Cmd.map MoreLoaded (Pretend.respond failing ())
            )

        MoreLoaded (Ok _) ->
            let
                shown =
                    model.shown + 8
            in
            ( { model | shown = shown, morePages = Remote.Loaded (shown < List.length orderEvents) }, Cmd.none )

        MoreLoaded (Err problem) ->
            ( { model | morePages = Remote.Failed problem }, Cmd.none )

        Retry ->
            -- "Try again" is replaced by the skeleton: focus goes to the timeline (its id).
            ( { model | retrying = True }
            , Cmd.batch [ Pretend.later RetryDone, Klar.focus "history-timeline" Focused ]
            )

        Focused ->
            ( model, Cmd.none )

        RetryDone ->
            ( { model | retrying = False }, Cmd.none )



-- VIEW


view : Settings -> Locale -> Model -> Html Msg
view settings locale model =
    let
        common =
            [ Timeline.locale locale, Timeline.settings settings, Timeline.now Sample.now ]
    in
    Doc.section "Timeline"
        "An order log and audit trail. Events are grouped by day, and the color of the marker says what kind of event it is. Details unfold with the mouse, or with Tab to “Show details” and Enter or Space."
        [ Doc.example
            { title = "Order log with “Load more”"
            , description = Just "“Load more” fetches eight more events; the footer counts them against the total. The request for the next page is a Remote Bool (True: there is more). With “Simulate failures” a short message appears at the bottom, the button turns into “Try again”, and the events that are already loaded stay. After the last page the button stays, dimmed, so the keyboard focus on it is kept."
            , code = Just """Timeline.view
    [ Timeline.now model.now
    , Timeline.loadMore LoadMore model.morePages
    , Timeline.total 40
    ]
    [ Timeline.event "e1" confirmedAt "Order ORD-10042 confirmed"
        |> Timeline.withAuthor "Maya Patel"
        |> Timeline.withIcon Icon.clipboardCheck
        |> Timeline.withDescription "Stock is reserved for all lines."
    , Timeline.event "e2" changedAt "Due date changed"
        |> Timeline.withTone Warning
        |> Timeline.withDetails (Text.mono "due: 2026-10-12 -> 2026-10-19")
    ]

-- in update
LoadMore ->
    ( { model | morePages = Remote.refresh model.morePages }, fetchPage )

GotPage (Ok page) ->
    ( { model | morePages = Remote.Loaded page.hasMore, ... }, Cmd.none )

-- a failed page: the events stay, the footer shows the problem
GotPage (Err problem) ->
    ( { model | morePages = Remote.Failed problem }, Cmd.none )"""
            }
            (Timeline.view
                (common
                    ++ [ Timeline.ariaLabel "Order log"
                       , Timeline.loadMore LoadMore model.morePages
                       , Timeline.total (List.length orderEvents)
                       ]
                )
                (List.take model.shown orderEvents)
            )
        , Doc.example
            { title = "Compact"
            , description = Just "A dot as the marker, one line per event and the time on the right. Here in a scrolling box (Timeline.maxHeight)."
            , code = Just "Timeline.view [ Timeline.compact, Timeline.maxHeight 230, Timeline.now model.now ] events"
            }
            (Timeline.view
                (Timeline.compact :: Timeline.maxHeight 230 :: Timeline.ariaLabel "Order log, compact" :: common)
                (List.take 14 orderEvents)
            )
        , Doc.example
            { title = "Without day headings"
            , description = Just "One list. The time of an event is still shown, and its date is in the tooltip. The first author has a picture."
            , code = Just """Timeline.view [ Timeline.ungrouped ] events

Timeline.event "e1" confirmedAt "Order ORD-10042 confirmed"
    |> Timeline.withAuthor "Maya Patel"
    |> Timeline.withAuthorImage url"""
            }
            (Timeline.view
                (Timeline.ungrouped :: Timeline.ariaLabel "Order log, ungrouped" :: common)
                (List.take 5 orderEvents
                    |> List.indexedMap
                        (\i event ->
                            if i == 0 then
                                Timeline.withAuthorImage portrait event

                            else
                                event
                        )
                )
            )
        , Doc.example
            { title = "Events of a day"
            , description = Just "A delivery date or a deadline has a day and no time of day: it sits under its day and draws no clock time, and no \"00:00\". The others keep their time, in the zone chosen in the top bar."
            , code = Just """Timeline.view [ Timeline.settings model.settings ]
    [ Timeline.dayEvent "d1" deliveryDate "Delivery date"
    , Timeline.event "e1" confirmedAt "Order ORD-10042 confirmed"
    ]"""
            }
            (Timeline.view
                (Timeline.ariaLabel "Order log with a day event" :: common)
                (Timeline.dayEvent "day-1" Sample.today "Planned delivery"
                    :: List.take 2 orderEvents
                )
            )
        , Doc.example
            { title = "Loading, empty and failed"
            , description = Just "The failed timeline retries: the backend is down on purpose, so it loads for a moment and fails again."
            , code = Just """Timeline.viewRemote [] Remote.Loading

Timeline.view [ Timeline.emptyTitle "No events in this period" ] []

Timeline.viewRemote [ Timeline.onRetry Reload, Timeline.id "history" ]
    (Remote.map (List.map toEvent) model.history)"""
            }
            (Layout.grid [ Layout.minColumn 300, Layout.gap 6 ]
                [ Timeline.viewRemote common Remote.Loading
                , Timeline.view
                    (Timeline.emptyTitle "No events in this period"
                        :: Timeline.emptyDescription "Orders that change will show up here."
                        :: common
                    )
                    []
                , Timeline.viewRemote
                    (Timeline.id "history-timeline"
                        :: Timeline.onRetry Retry
                        :: common
                    )
                    (Pretend.down locale model.retrying)
                ]
            )
        ]



-- EVENTS


{-| Forty events, about an hour and a half apart, going back from the moment the
sample data pretends it is. One of every kind, and one with very long texts.
-}
orderEvents : List (Timeline.Event msg)
orderEvents =
    List.range 0 39 |> List.map orderEvent


orderEvent : Int -> Timeline.Event msg
orderEvent i =
    let
        order =
            Sample.orders |> List.drop (i * 7 + 3) |> List.head

        customer =
            order |> Maybe.map .customer |> Maybe.withDefault "Unknown customer"

        orderId =
            order |> Maybe.map (.id >> orderIdText) |> Maybe.withDefault "ORD-00000"

        owner =
            Sample.owners |> List.drop (modBy 6 (i * 5)) |> List.head |> Maybe.withDefault "System"

        minutesAgo =
            i * 83 + modBy 17 (i * 13)

        time =
            Time.millisToPosix (Time.posixToMillis Sample.now - minutesAgo * 60000)

        id =
            "event-" ++ String.fromInt i
    in
    if i == 9 then
        Timeline.event id time "Summary of the cross-department meeting on delivery planning, customs clearance, pallet packaging and payment terms for the customer, with an assessment of the next steps"
            |> Timeline.withAuthor "Aleksandra Wiśniewska-Kowalczyk"
            |> Timeline.withIcon Icon.clipboardCheck
            |> Timeline.withDescription "This is a very long description that shows how the timeline wraps lines instead of scrolling sideways, even when the text contains long unbroken words such as ORD_10042_CONSOLIDATED_REPLENISHMENT_TRANSFER_AUTHORISATION_REFERENCE_2026_10_20."

    else
        orderEventOfKind (modBy 6 i) id time { customer = customer, orderId = orderId, owner = owner }


orderEventOfKind : Int -> String -> Time.Posix -> { customer : String, orderId : String, owner : String } -> Timeline.Event msg
orderEventOfKind kind id time who =
    case kind of
        0 ->
            Timeline.event id time ("Order " ++ who.orderId ++ " confirmed")
                |> Timeline.withAuthor who.owner
                |> Timeline.withIcon Icon.clipboardCheck
                |> Timeline.withDescription ("Confirmed by " ++ who.customer ++ ". Stock is reserved for all lines.")

        1 ->
            Timeline.event id time ("Due date of " ++ who.orderId ++ " changed")
                |> Timeline.withAuthor who.owner
                |> Timeline.withTone Warning
                |> Timeline.withIcon Icon.calendar
                |> Timeline.withDetails
                    (Layout.stack [ Layout.gap 1 ]
                        [ Text.mono "due: 2026-10-12 -> 2026-10-19"
                        , Text.mono "reason: Supplier delay"
                        , Text.mono ("changed_by: " ++ who.owner)
                        ]
                    )

        2 ->
            Timeline.event id time "Payment declined"
                |> Timeline.withTone Danger
                |> Timeline.withIcon Icon.lock
                |> Timeline.withDescription "Three failed attempts with the same card. The order was put on hold for 15 minutes."

        3 ->
            Timeline.event id time ("Invoice issued to " ++ who.customer)
                |> Timeline.withAuthor who.owner
                |> Timeline.withTone Success
                |> Timeline.withIcon Icon.fileText

        4 ->
            Timeline.event id time ("Warehouse access granted to " ++ who.owner)
                |> Timeline.withIcon Icon.key
                |> Timeline.withDescription "Read access to Rotterdam Hub, expires in 30 days."

        _ ->
            Timeline.event id time ("Order " ++ who.orderId ++ " moved to another warehouse")
                |> Timeline.withAuthor who.owner
                |> Timeline.withTone Primary
                |> Timeline.withIcon Icon.arrowRight
                |> Timeline.withDetails
                    (Layout.stack [ Layout.gap 1 ]
                        [ Text.mono "from: Rotterdam Hub"
                        , Text.mono "to: Hamburg Central"
                        , Text.mono "date: 2026-10-20"
                        ]
                    )
