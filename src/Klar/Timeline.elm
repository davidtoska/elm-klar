module Klar.Timeline exposing
    ( view, viewRemote
    , Event, event, dayEvent, withDescription, withTone, withIcon, withAuthor, withAuthorImage, withDetails, withHref, withOnClick
    , Attribute, settings, now, compact, ungrouped, ariaLabel, maxHeight, headingLevel, id, locale
    , loadMore, total
    , onRetry, skeletonRows, emptyTitle, emptyDescription
    )

{-| A vertical history of events: an audit trail, an order log, an activity feed.

Use when: a history of events is shown newest first, grouped by day, such as an audit trail or an order log.
Do not use when: the events are rules and decisions of an approval process, use `Klar.ApprovalFlow`; or the rows are records to sort and filter, use `Klar.Table`.
Quick path: `viewRemote` with `Remote.map (List.map toEvent) model.history`, `onRetry`, `settings`; add `loadMore` for paging.

    import Klar.Icon as Icon
    import Klar.Settings as Settings
    import Klar.Text as Text
    import Klar.Theme exposing (Tone(..))
    import Klar.Timeline as Timeline

    Timeline.view
        [ Timeline.settings model.settings
        , Timeline.now model.now
        ]
        [ Timeline.event "e2" delayedAt "Status changed to Delayed"
            |> Timeline.withTone Warning
            |> Timeline.withDetails (Text.paragraph "From In transit to Delayed. Reason: customs inspection.")
        , Timeline.event "e1" shippedAt "Order shipped"
            |> Timeline.withAuthor "Ada Lovelace"
            |> Timeline.withIcon Icon.send
            |> Timeline.withDescription "Parcel handed to the carrier at warehouse B."
        ]

Here `model.settings` is the `Klar.Settings` of the application, and `model.now`,
`shippedAt` and `delayedAt` are `Time.Posix` values.

From the backend, page by page: `model.history` is a `Remote (List Change)` and
`model.morePages` the `Remote Bool` of the request for the next page (`True`:
there is more after what is shown).

    Timeline.viewRemote
        [ Timeline.settings model.settings
        , Timeline.onRetry ReloadHistory
        , Timeline.loadMore LoadMoreHistory model.morePages
        , Timeline.id "history"
        ]
        (Remote.map (List.map toEvent) model.history)

    -- in update
    LoadMoreHistory ->
        ( { model | morePages = Remote.refresh model.morePages }, fetchPage model.cursor )

    GotPage (Ok page) ->
        ( { model
            | history = Remote.map (\old -> old ++ page.changes) model.history
            , morePages = Remote.Loaded page.hasMore
          }
        , Cmd.none
        )

    GotPage (Err problem) ->
        ( { model | morePages = Remote.Failed problem }, Cmd.none )

The clock times and the day an event belongs to are those of the zone in the
settings (UTC, with "UTC" after the time, until the application has given it).

Events are shown in the order you give them (newest first is usual), and grouped
under a heading per calendar day: events that follow each other on the same day
share a heading, so give them sorted by time. The headings are `h3` elements: under a
page title with no heading in between, say `headingLevel 2`.
Something that happened on a day, with no time of day (a delivery date, a
deadline), is a `dayEvent`: it sits under its day and draws no clock time. Give the
timeline `now` and the headings say "Today", "Yesterday" and "Tomorrow". A thin gray line connects the markers of a day; a marker is an icon
in the tone of the event, or a dot. The marker is decoration only (hidden from
screen readers), so the title of an event must say what its color means.

Details are folded away in a native `details` element, so they work with the
keyboard and need no state. The footer loads more: a button and a status text
next to it, shown when you set `loadMore`. The button is the same element in every
state, so the keyboard focus is never thrown away: it shows a spinner while the next
page loads, turns into "Try again" when that failed, and stays, dimmed and
unavailable (`aria-disabled`), when there is nothing more ("No more events").

`viewRemote` draws a loading skeleton, a failure with retry, an empty state, the
events, a refresh (dimmed) and old data ("Old data from 14:05"). The "Try again"
button of a failure is replaced when the request starts again: give the timeline an
`id` and move focus there with `Klar.focus` in that update branch. The built-in
text is English unless you set `locale`.


# Views

@docs view, viewRemote


# Events

@docs Event, event, dayEvent, withDescription, withTone, withIcon, withAuthor, withAuthorImage, withDetails, withHref, withOnClick


# Look and time

@docs Attribute, settings, now, compact, ungrouped, ariaLabel, maxHeight, headingLevel, id, locale


# Loading more

@docs loadMore, total


# Failure and empty

@docs onRetry, skeletonRows, emptyTitle, emptyDescription

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Avatar as Avatar
import Klar.Button as Button
import Klar.Date as Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Theme as Theme exposing (Size(..), Tone(..))
import Klar.Timeline.Days exposing (dayKeys)
import Time



-- EVENT


{-| One entry in the history. Make it with `event`, add the rest with the
`with...` functions and pass a list of them to `view`.
-}
type Event msg
    = Event (EventData msg)


type When
    = At Time.Posix
    | OnDay Date


type alias EventData msg =
    { id : String
    , when : When
    , title : String
    , description : Maybe String
    , tone : Tone
    , icon : Maybe Icon
    , author : Maybe String
    , authorImage : Maybe String
    , details : Maybe (Html msg)
    , action : Maybe (Action msg)
    }


{-| Where the title of an event leads: a page, or a message.
-}
type Action msg
    = GoTo String
    | Send msg


{-| An event with an id, the time it happened and a short title.

    Timeline.event "ev-1042" shippedAt "Order shipped"

The id must be unique among the events and stay the same for the same event
between renders (use the id from your database, not the position in the list).
It keeps the DOM stable when the list changes, for example when a page of older
events is added. The title is the headline of the event: a few words, in
sentence case.

-}
event : String -> Time.Posix -> String -> Event msg
event key time title =
    eventWhen key (At time) title


{-| An event that happened on a day, with no time of day: a delivery date, a
deadline, an invoice date. It sits under the heading of its day and no time is
written next to it (there is no "00:00"). Give the events sorted, and put the
day events of a day together with the timed events of that day.

    Timeline.dayEvent "ev-77" invoiceDate "Invoice dated"

-}
dayEvent : String -> Date -> String -> Event msg
dayEvent key day title =
    eventWhen key (OnDay day) title


eventWhen : String -> When -> String -> Event msg
eventWhen key when title =
    Event
        { id = key
        , when = when
        , title = title
        , description = Nothing
        , tone = Neutral
        , icon = Nothing
        , author = Nothing
        , authorImage = Nothing
        , details = Nothing
        , action = Nothing
        }


{-| A sentence or two under the title. In a `compact` timeline it follows the
title on the same line and is cut with an ellipsis (the full text is the
tooltip).
-}
withDescription : String -> Event msg -> Event msg
withDescription text (Event data) =
    Event { data | description = Just text }


{-| Colors the marker by meaning: `Success` (green), `Warning` (amber), `Danger`
(red) or `Primary` and `Info` (blue). `Neutral` (gray) is the default. The color
is not announced to screen readers, so let the title say what happened. The
`Tone` type is in [Klar.Theme](Klar-Theme).
-}
withTone : Tone -> Event msg -> Event msg
withTone tone (Event data) =
    Event { data | tone = tone }


{-| An icon in the marker. Without one the marker is a dot, and in a `compact`
timeline the marker is always a dot.
-}
withIcon : Icon -> Event msg -> Event msg
withIcon glyph (Event data) =
    Event { data | icon = Just glyph }


{-| Who did it: a small avatar with the initials of the name, followed by the
name next to the title. A blank name is ignored.
-}
withAuthor : String -> Event msg -> Event msg
withAuthor name (Event data) =
    Event { data | author = Just name }


{-| The URL of a picture for the author's avatar. Without one the avatar shows
the initials. It only has an effect together with `withAuthor`.
-}
withAuthorImage : String -> Event msg -> Event msg
withAuthorImage url (Event data) =
    Event { data | authorImage = Just url }


{-| Content that is folded away behind a "Show details" link, for the long part
of an event: a comment, a list of changed fields. The link turns into "Hide
details" while it is open. It is a native `details` element, so it works with
the keyboard and whether it is open is not part of your model.

    Timeline.event "ev-7" changedAt "Address changed"
        |> Timeline.withDetails (Text.paragraph "From 1 Main Street to 5 Park Lane.")

-}
withDetails : Html msg -> Event msg -> Event msg
withDetails html (Event data) =
    Event { data | details = Just html }


{-| Makes the title a link to this URL: the record the event is about ("Order
1042 shipped" opens the order). It is a real `<a href>`, so it can be opened in a
new tab, and in a `Browser.application` a click is a `UrlRequest`. `withHref` and
`withOnClick` replace each other.

    Timeline.event "ev-1042" shippedAt "Order 1042 shipped"
        |> Timeline.withHref "/orders/1042"

-}
withHref : String -> Event msg -> Event msg
withHref url (Event data) =
    Event { data | action = Just (GoTo url) }


{-| Makes the title a button that sends this message, for an action that is not
a page: opening the record in a drawer. Use `withHref` when it is a page.
`withHref` and `withOnClick` replace each other.

    Timeline.event "ev-1042" shippedAt "Order 1042 shipped"
        |> Timeline.withOnClick (OpenOrder orderId)

-}
withOnClick : msg -> Event msg -> Event msg
withOnClick msg (Event data) =
    Event { data | action = Just (Send msg) }


{-| The title of an event: plain text, a link or a button.
-}
viewTitle : EventData msg -> List (Html.Attribute msg) -> Html msg
viewTitle data extra =
    case data.action of
        Just (GoTo url) ->
            Html.a (Internal.cls [ "klar-timeline__title", "klar-timeline__title--link" ] :: Attr.href url :: extra) [ Html.text data.title ]

        Just (Send msg) ->
            Html.button
                (Internal.cls [ "klar-timeline__title", "klar-timeline__title--link" ]
                    :: Attr.type_ "button"
                    :: Events.onClick msg
                    :: extra
                )
                [ Html.text data.title ]

        Nothing ->
            Html.span (Internal.cls [ "klar-timeline__title" ] :: extra) [ Html.text data.title ]



-- ATTRIBUTES


{-| A setting of a timeline. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type State
    = Ready
    | Busy
    | Failed Problem


type alias Config msg =
    { locale : Locale
    , settings : Settings
    , now : Maybe Time.Posix
    , compact : Bool
    , grouped : Bool
    , label : Maybe String
    , busy : Bool
    , failure : Maybe Problem
    , freshness : Freshness
    , onRetry : Maybe msg
    , loadMore : Maybe { onLoadMore : msg, next : Remote Bool }
    , total : Maybe Int
    , emptyTitle : Maybe String
    , emptyDescription : Maybe String
    , skeletonRows : Int
    , maxHeight : Maybe Int
    , headingLevel : Int
    , id : Maybe String
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { locale = Locale.default
        , settings = Settings.default
        , now = Nothing
        , compact = False
        , grouped = True
        , label = Nothing
        , busy = False
        , failure = Nothing
        , freshness = Freshness.Fresh
        , onRetry = Nothing
        , loadMore = Nothing
        , total = Nothing
        , emptyTitle = Nothing
        , emptyDescription = Nothing
        , skeletonRows = 4
        , maxHeight = Nothing
        , headingLevel = 3
        , id = Nothing
        }
        attributes


{-| The settings of the application (`Klar.Settings`): the time zone of the clock
times and of the day an event belongs to, and of "Old data from 14:05". Without it
the times are written in UTC and end in "UTC".

    Timeline.settings model.settings

-}
settings : Settings -> Attribute msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text ("Show details", "Load more", "Today",
"Yesterday", the footer and so on) and of the dates. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The current time. It lets the day headings say "Today", "Yesterday" and "Tomorrow" and
the tooltip of each time add how long ago it was ("3 hours ago"). Without it the
headings always show the full date. The timeline does not read the clock itself:
keep the value in your model and update it, for example with `Time.every`.
-}
now : Time.Posix -> Attribute msg
now value =
    Attribute (\config -> { config | now = Just value })


{-| Less space: a dot as the marker, one line per event with the description
after the title, and the time at the right. Good for side panels. Details still
fold out below the line.
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| One list, with no day headings. The time of an event is still shown, but its
date is only in the tooltip.
-}
ungrouped : Attribute msg
ungrouped =
    Attribute (\config -> { config | grouped = False })


{-| The accessible name of the timeline, for example "Order history". It makes
the timeline a labelled region, so give each timeline on a page its own name.
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| The level, 1 to 6, of the heading of each day (`h3` by default; other numbers
are moved into that range). The headings must follow the ones of the page: a
timeline directly under the `h1` of a page takes 2, one in a card with an `h2`
title keeps 3.
-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = clamp 1 6 level })


{-| The DOM id of the timeline, which then takes focus from a command in every state
(loading, failed, loaded). The "Try again" button of a failure is replaced when the
request starts again, and focus would fall back to the page; call
[`Klar.focus`](Klar#focus) with this id in the same `update`
branch. The id must be unique on the page.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The message sent by the "Try again" button of a timeline from a `Remote`
(`viewRemote`) that failed, and by the marker of old data. The button is only shown
when the problem is worth retrying (see `Klar.Remote.isRetryable` in
[Klar.Remote](Klar-Remote)). A failed next page has its own retry button, which sends
the message of `loadMore`.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Adds the footer under the events: a "Load more" button that sends the message,
and a status text next to it. The `Remote Bool` is the request for the next page,
and its `Bool` says whether there is more after the events shown:

  - `Loaded True` or `NotAsked`: "Load more" and "Showing 20 events".

  - `Loading`, or data that is being refreshed (`Remote.refresh`): the button
    shows a spinner and does nothing, and the status says "Loading more events ...".

  - `Failed`, or data whose refresh failed: the title of the problem, and the
    button turns into "Try again" and sends the message again, when the problem
    is worth retrying (`Klar.Remote.isRetryable`). For any other problem (no
    access, a refused request) the button stays, unavailable, so the keyboard
    focus is kept. The events already loaded stay.

  - `Loaded False`: that was all. The button stays, dimmed and unavailable, so
    that the keyboard focus on it is not thrown away, and the status says "No more
    events".

    Timeline.loadMore LoadMoreHistory model.morePages

The button is one element in every state. Without `loadMore` there is no footer.

-}
loadMore : msg -> Remote Bool -> Attribute msg
loadMore msg next =
    Attribute (\config -> { config | loadMore = Just { onLoadMore = msg, next = next } })


{-| How many events there are in all, when the backend says so: the footer then
says "Showing 20 of 340 events". Without it the footer counts only the events
shown.
-}
total : Int -> Attribute msg
total count =
    Attribute (\config -> { config | total = Just (max 0 count) })


{-| The title of the empty state, shown when there are no events. The default is
"No events".
-}
emptyTitle : String -> Attribute msg
emptyTitle text =
    Attribute (\config -> { config | emptyTitle = Just text })


{-| A line of explanation under the title of the empty state, such as what
creates the first event. Default: none.
-}
emptyDescription : String -> Attribute msg
emptyDescription text =
    Attribute (\config -> { config | emptyDescription = Just text })


{-| Makes the timeline, footer included, scroll inside itself when it is taller
than this many pixels: for a log in a side panel. Default: no limit.

A scroll area must be reachable with the keyboard. With `loadMore` the button in
the footer is a tab stop inside it, in every state: after the last page it stays,
unavailable (`aria-disabled`) but still focusable, so the scroll area can still be
reached. Without `loadMore`, the timeline itself takes the keyboard focus
(`tabindex="0"`) and is a region named by `ariaLabel` ("Events" if you gave none),
so that the arrow keys scroll it.

-}
maxHeight : Int -> Attribute msg
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| How many placeholder events to show while loading. The default is 4; the
value is kept between 1 and 20.
-}
skeletonRows : Int -> Attribute msg
skeletonRows n =
    Attribute (\config -> { config | skeletonRows = clamp 1 20 n })



-- TEXT


type alias Texts =
    { showDetails : String
    , hideDetails : String
    , loadMore : String
    , loadingMore : String
    , noMore : String
    , empty : String
    , events : String
    , today : String
    , yesterday : String
    , tomorrow : String
    , retry : String
    , shown : Int -> String
    , shownOf : Int -> Int -> String
    , loadingEvents : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }
    in
    { showDetails = pick "Vis detaljer" "Show details"
    , hideDetails = pick "Skjul detaljer" "Hide details"
    , loadMore = pick "Last flere" "Load more"
    , loadingMore = pick "Henter flere hendelser ..." "Loading more events ..."
    , noMore = pick "Ingen flere hendelser" "No more events"
    , empty = pick "Ingen hendelser" "No events"
    , events = pick "Hendelser" "Events"
    , today = pick "I dag" "Today"
    , yesterday = pick "I går" "Yesterday"
    , tomorrow = pick "I morgen" "Tomorrow"
    , retry = pick "Prøv igjen" "Try again"
    , shown =
        \n ->
            pick
                ("Viser " ++ Format.int loc n ++ " " ++ Format.plural loc n { one = "hendelse", other = "hendelser" })
                ("Showing " ++ Format.int loc n ++ " " ++ Format.plural loc n { one = "event", other = "events" })
    , shownOf =
        \n all ->
            pick
                ("Viser " ++ Format.int loc n ++ " av " ++ Format.int loc all ++ " " ++ Format.plural loc all { one = "hendelse", other = "hendelser" })
                ("Showing " ++ Format.int loc n ++ " of " ++ Format.int loc all ++ " " ++ Format.plural loc all { one = "event", other = "events" })
    , loadingEvents = pick "Laster hendelser" "Loading events"
    }



-- VIEW


{-| The timeline from a `Remote`: a skeleton while it loads (see `skeletonRows`),
the problem with "Try again" (`onRetry`) when it failed, the empty state, the
events, the events dimmed and busy while they are refreshed, and "Old data from
14:05" with a retry when the last refresh failed (the time is in the zone of the
`settings`). Shape the data with `Remote.map`.

    Timeline.viewRemote [ Timeline.settings model.settings, Timeline.onRetry ReloadHistory ]
        (Remote.map (List.map toEvent) model.history)

The timeline is the same element around the same events whether they are fresh,
refreshing or old, so focus on a link in the details or on "Load more" survives a
refresh.

-}
viewRemote : List (Attribute msg) -> Remote (List (Event msg)) -> Html msg
viewRemote attributes data =
    let
        ( settled, freshness ) =
            Freshness.settle data

        state =
            Attribute
                (\config ->
                    { config
                        | busy = Freshness.waiting settled
                        , failure =
                            case settled of
                                Remote.Failed problem ->
                                    Just problem

                                _ ->
                                    Nothing
                        , freshness = freshness
                    }
                )
    in
    view (attributes ++ [ state ])
        (case settled of
            Remote.Loaded events ->
                events

            _ ->
                []
        )


{-| The timeline. Events are shown in the order given; events that follow each
other on the same day (in the zone of the settings) share a day heading, so
sort them by time first.

    Timeline.view [ Timeline.settings model.settings ] (List.map toEvent model.history)

For events from the backend, use `viewRemote`.

-}
view : List (Attribute msg) -> List (Event msg) -> Html msg
view attributes events =
    let
        config =
            configure attributes

        t =
            texts config.locale

        -- A scroll area with nothing focusable in it cannot be scrolled from the keyboard.
        scrollsWithoutButton =
            config.maxHeight /= Nothing && config.loadMore == Nothing

        wrap children =
            Html.section
                [ Internal.cls
                    [ "klar-timeline"
                    , Freshness.className config.freshness
                    , if config.compact then
                        "klar-timeline--compact"

                      else
                        ""
                    , if config.maxHeight /= Nothing then
                        "klar-timeline--scroll"

                      else
                        ""

                    -- Until the zone is known every time ends in UTC: a wider column.
                    , if String.endsWith "UTC" (Settings.time config.settings (Time.millisToPosix 0)) then
                        "klar-timeline--utc"

                      else
                        ""
                    ]
                , Internal.attrMaybe (\pixels -> Internal.styleVars [ ( "max-height", Internal.px pixels ) ]) config.maxHeight
                , if scrollsWithoutButton then
                    Attr.attribute "aria-label" (Maybe.withDefault t.events config.label)

                  else
                    Internal.attrMaybe (Attr.attribute "aria-label") config.label
                , Internal.attrMaybe Attr.id config.id
                , if scrollsWithoutButton then
                    Attr.tabindex 0

                  else
                    Internal.attrIf (config.id /= Nothing) (Attr.tabindex -1)
                , Internal.attrIf scrollsWithoutButton (Attr.attribute "role" "region")
                , Internal.attrIf (state == Busy) (Attr.attribute "aria-busy" "true")
                , Freshness.busyAttr config.freshness
                ]
                children

        state =
            case config.failure of
                Just problem ->
                    Failed problem

                Nothing ->
                    if config.busy then
                        Busy

                    else
                        Ready

        notice =
            Freshness.notice
                { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                config.freshness

        -- One status node in every state, first in the timeline: a live region
        -- that is already there announces the change of its text.
        status text =
            Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text text ]
    in
    case state of
        Busy ->
            wrap
                [ status t.loadingEvents
                , viewSkeleton config
                ]

        Failed problem ->
            wrap [ status "", failureView config problem ]

        Ready ->
            if List.isEmpty events then
                wrap
                    [ status ""
                    , notice
                    , EmptyState.view
                        (List.filterMap identity
                            [ Just EmptyState.compact
                            , Just (EmptyState.icon Icon.history)
                            , Just (EmptyState.title (Maybe.withDefault t.empty config.emptyTitle))
                            , Maybe.map EmptyState.description config.emptyDescription
                            ]
                        )
                    ]

            else
                -- The days sit in one element of their own, so the footer is
                -- always the next child: it keeps its place (and the focus of
                -- the button in it) when a page of events is added above it.
                wrap
                    [ status ""
                    , notice
                    , if config.grouped then
                        -- Keyed by day: a new day at the top does not reuse the
                        -- elements of the days below it, so open details and the
                        -- focus inside them survive.
                        Keyed.node "div"
                            [ Internal.cls [ "klar-timeline__days" ] ]
                            (dayKeys (groupByDay config.settings events)
                                |> List.map (\( key, group ) -> ( key, viewDay config group ))
                            )

                      else
                        viewList config events
                    , viewFooter config (List.length events)
                    ]


failureView : Config msg -> Problem -> Html msg
failureView config problem =
    ErrorState.view
        (List.filterMap identity
            [ Just ErrorState.compact
            , Just (ErrorState.locale config.locale)
            , Maybe.map ErrorState.onRetry config.onRetry
            ]
        )
        problem



-- DAYS


groupByDay : Settings -> List (Event msg) -> List ( Date, List (Event msg) )
groupByDay given events =
    List.foldr
        (\((Event data) as current) groups ->
            let
                day =
                    case data.when of
                        At moment ->
                            Settings.toDate given moment

                        OnDay value ->
                            value
            in
            case groups of
                ( groupDay, items ) :: rest ->
                    if groupDay == day then
                        ( groupDay, current :: items ) :: rest

                    else
                        ( day, [ current ] ) :: groups

                [] ->
                    [ ( day, [ current ] ) ]
        )
        []
        events


viewDay : Config msg -> ( Date, List (Event msg) ) -> Html msg
viewDay config ( day, events ) =
    let
        t =
            texts config.locale

        longDate =
            Locale.weekdayLong config.locale (Date.weekday day) ++ " " ++ Format.dateLong config.locale day

        relativeName =
            case config.now of
                Just current ->
                    let
                        daysAgo =
                            Date.diffDays day (Settings.toDate config.settings current)
                    in
                    if daysAgo == 0 then
                        Just t.today

                    else if daysAgo == 1 then
                        Just t.yesterday

                    else if daysAgo == -1 then
                        Just t.tomorrow

                    else
                        Nothing

                Nothing ->
                    Nothing
    in
    Html.div [ Internal.cls [ "klar-timeline__day" ] ]
        [ Internal.heading config.headingLevel
            [ Internal.cls [ "klar-timeline__day-title" ] ]
            (case relativeName of
                Just name ->
                    [ Html.span [ Internal.cls [ "klar-timeline__day-name" ] ] [ Html.text name ]
                    , Html.span [ Internal.cls [ "klar-timeline__day-date" ] ] [ Html.text longDate ]
                    ]

                Nothing ->
                    [ Html.span [ Internal.cls [ "klar-timeline__day-name" ] ] [ Html.text longDate ] ]
            )
        , viewList config events
        ]


viewList : Config msg -> List (Event msg) -> Html msg
viewList config events =
    Keyed.ol [ Internal.cls [ "klar-timeline__list" ], Attr.attribute "role" "list" ]
        (List.map (\((Event data) as current) -> ( data.id, viewEvent config current )) events)



-- EVENT ROW


viewEvent : Config msg -> Event msg -> Html msg
viewEvent config (Event data) =
    let
        t =
            texts config.locale

        timeElement className =
            case data.when of
                At moment ->
                    Html.time
                        [ Internal.cls [ className, "klar-tabular" ]
                        , Attr.attribute "datetime" (isoTime moment)
                        , Attr.title
                            (Settings.dateTime config.locale config.settings moment
                                ++ (case config.now of
                                        Just current ->
                                            "  ·  " ++ Format.relative config.locale current moment

                                        Nothing ->
                                            ""
                                   )
                            )
                        ]
                        [ Html.text (Settings.time config.settings moment) ]

                OnDay day ->
                    -- A day has no clock: the cell stays, so the columns line up.
                    Html.span
                        [ Internal.cls [ className ]
                        , Attr.attribute "aria-hidden" "true"
                        , Attr.title (Format.date config.locale day)
                        ]
                        []

        marker =
            Html.span
                [ Internal.cls
                    [ "klar-timeline__marker"
                    , if data.icon == Nothing || config.compact then
                        "klar-timeline__marker--dot"

                      else
                        ""
                    ]
                ]
                [ case ( data.icon, config.compact ) of
                    ( Just glyph, False ) ->
                        Icon.sized Icon.Small glyph

                    _ ->
                        Html.text ""
                ]

        byline =
            case data.author of
                Just name ->
                    if String.isEmpty (String.trim name) then
                        Html.text ""

                    else
                        Html.span [ Internal.cls [ "klar-timeline__author" ] ]
                            [ Avatar.view (Avatar.extraSmall :: Avatar.decorative :: List.filterMap identity [ Maybe.map Avatar.image data.authorImage ]) name
                            , Html.span [ Internal.cls [ "klar-timeline__author-name" ], Attr.title name ] [ Html.text name ]
                            ]

                Nothing ->
                    Html.text ""

        details =
            case data.details of
                Just html ->
                    Html.details [ Internal.cls [ "klar-timeline__details" ] ]
                        [ Html.summary [ Internal.cls [ "klar-timeline__summary" ] ]
                            [ Icon.sized Icon.ExtraSmall Icon.chevronRight
                            , Html.span [ Internal.cls [ "klar-timeline__summary-show" ] ] [ Html.text t.showDetails ]
                            , Html.span [ Internal.cls [ "klar-timeline__summary-hide" ] ] [ Html.text t.hideDetails ]
                            ]
                        , Html.div [ Internal.cls [ "klar-timeline__details-body" ] ] [ html ]
                        ]

                Nothing ->
                    Html.text ""
    in
    Html.li
        [ Internal.cls [ "klar-timeline__item", "klar-timeline__item--" ++ Internal.toneSuffix data.tone ] ]
        (if config.compact then
            [ Html.span [ Internal.cls [ "klar-timeline__rail" ], Attr.attribute "aria-hidden" "true" ] [ marker ]
            , Html.div [ Internal.cls [ "klar-timeline__content" ] ]
                [ Html.div [ Internal.cls [ "klar-timeline__line" ] ]
                    [ viewTitle data [ Attr.title data.title ]
                    , byline
                    , Internal.viewMaybe
                        (\text -> Html.span [ Internal.cls [ "klar-timeline__description", "klar-truncate" ], Attr.title text ] [ Html.text text ])
                        data.description
                    , timeElement "klar-timeline__time"
                    ]
                , details
                ]
            ]

         else
            [ timeElement "klar-timeline__time"
            , Html.span [ Internal.cls [ "klar-timeline__rail" ], Attr.attribute "aria-hidden" "true" ] [ marker ]
            , Html.div [ Internal.cls [ "klar-timeline__content" ] ]
                [ Html.div [ Internal.cls [ "klar-timeline__headline" ] ]
                    [ viewTitle data []
                    , byline
                    ]
                , Internal.viewMaybe (\text -> Html.p [ Internal.cls [ "klar-timeline__description" ] ] [ Html.text text ]) data.description
                , details
                ]
            ]
        )


isoTime : Time.Posix -> String
isoTime posix =
    let
        pad2 n =
            String.padLeft 2 '0' (String.fromInt n)

        day =
            Date.fromPosix Time.utc posix
    in
    Date.toIso day
        ++ "T"
        ++ pad2 (Time.toHour Time.utc posix)
        ++ ":"
        ++ pad2 (Time.toMinute Time.utc posix)
        ++ ":"
        ++ pad2 (Time.toSecond Time.utc posix)
        ++ "Z"



-- SKELETON AND FOOTER


viewSkeleton : Config msg -> Html msg
viewSkeleton config =
    Html.ol [ Internal.cls [ "klar-timeline__list", "klar-timeline__list--skeleton" ], Attr.attribute "aria-hidden" "true" ]
        (List.range 1 config.skeletonRows
            |> List.map
                (\i ->
                    Html.li [ Internal.cls [ "klar-timeline__item" ] ]
                        ((if config.compact then
                            []

                          else
                            [ Html.span [ Internal.cls [ "klar-timeline__time" ] ] [ Skeleton.line 80 ] ]
                         )
                            ++ [ Html.span [ Internal.cls [ "klar-timeline__rail" ] ]
                                    [ Skeleton.circle
                                        (if config.compact then
                                            9

                                         else
                                            20
                                        )
                                    ]
                               , Html.div [ Internal.cls [ "klar-timeline__content" ] ]
                                    [ Skeleton.line (38 + modBy 30 (i * 19))
                                    , Skeleton.line (60 + modBy 30 (i * 13))
                                    ]
                               ]
                        )
                )
        )


viewFooter : Config msg -> Int -> Html msg
viewFooter config count =
    let
        t =
            texts config.locale
    in
    case config.loadMore of
        Nothing ->
            Html.text ""

        Just paging ->
            -- Always a button followed by a status text, in every state: the
            -- button that was pressed stays in the page (it only changes), so
            -- the keyboard focus is not thrown away while the next page loads,
            -- after it failed, or after the last one has arrived.
            let
                ( settled, freshness ) =
                    Freshness.settle paging.next

                phase =
                    case ( settled, freshness ) of
                        ( Remote.Loading, _ ) ->
                            MoreLoading

                        ( Remote.Failed problem, _ ) ->
                            MoreFailed problem

                        ( _, Freshness.Refreshing ) ->
                            MoreLoading

                        ( _, Freshness.Stale old ) ->
                            if old.refreshing then
                                MoreLoading

                            else
                                MoreFailed old.problem

                        ( Remote.Loaded False, _ ) ->
                            NoMore

                        _ ->
                            MoreAvailable

                shownText =
                    case config.total of
                        Just all ->
                            t.shownOf count (max all count)

                        Nothing ->
                            t.shown count

                button =
                    case phase of
                        MoreLoading ->
                            Button.view [ Button.small, Button.loading True ] t.loadMore

                        MoreFailed problem ->
                            if Remote.isRetryable problem then
                                Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick paging.onLoadMore ] t.retry

                            else
                                -- Trying the same request again would fail the
                                -- same way (no access, a refused cursor): the
                                -- button stays, unavailable, so focus is kept.
                                Button.view [ Button.small, Button.ariaDisabled True ] t.loadMore

                        MoreAvailable ->
                            Button.view [ Button.small, Button.onClick paging.onLoadMore ] t.loadMore

                        NoMore ->
                            Button.view [ Button.small, Button.ariaDisabled True ] t.loadMore

                note =
                    case phase of
                        MoreLoading ->
                            Html.span [ Internal.cls [ "klar-timeline__footer-text" ], Attr.attribute "role" "status" ]
                                [ Html.text t.loadingMore ]

                        MoreFailed problem ->
                            Html.span
                                [ Internal.cls [ "klar-timeline__footer-text", "klar-timeline__footer-text--error" ]
                                , Attr.attribute "role" "status"
                                ]
                                [ Icon.view Icon.errorCircle
                                , Html.span [ Attr.title (Maybe.withDefault (Remote.title config.locale problem) (Remote.detail config.locale problem)) ] [ Html.text (Remote.title config.locale problem) ]
                                ]

                        MoreAvailable ->
                            Html.span [ Internal.cls [ "klar-timeline__footer-text" ], Attr.attribute "role" "status" ]
                                [ Html.text shownText ]

                        NoMore ->
                            Html.span [ Internal.cls [ "klar-timeline__footer-text" ], Attr.attribute "role" "status" ]
                                [ Html.text t.noMore ]
            in
            Html.div [ Internal.cls [ "klar-timeline__footer" ] ] [ button, note ]


{-| Where the next page stands, read from the `Remote` of `loadMore`.
-}
type MorePhase
    = MoreAvailable
    | MoreLoading
    | MoreFailed Problem
    | NoMore
