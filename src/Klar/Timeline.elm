module Klar.Timeline exposing
    ( view
    , Event, event, dayEvent, withDescription, withTone, withIcon, withAuthor, withAuthorImage, withDetails
    , Attribute, settings, now, compact, ungrouped, ariaLabel, maxHeight, locale
    , onLoadMore, loadingMore, moreFailed, hasMore
    , loading, failed, onRetry, remote, skeletonRows, emptyTitle, emptyDescription
    )

{-| A vertical history of events: an audit trail, an order log, an activity feed.

Use when: a history of events is shown newest first, grouped by day, such as an audit trail or an order log.
Do not use when: the events are rules and decisions of an approval process, use `Klar.ApprovalFlow`.

    import Klar.Icon as Icon
    import Klar.Settings as Settings
    import Klar.Text as Text
    import Klar.Theme exposing (Tone(..))
    import Klar.Timeline as Timeline

    Timeline.view
        [ Timeline.settings model.settings
        , Timeline.now model.now
        , Timeline.onLoadMore LoadMore
        , Timeline.loadingMore model.loadingMore
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
`shippedAt` and `delayedAt` are `Time.Posix` values. The clock times and the day an
event belongs to are those of the zone in the settings (UTC, with "UTC" after the
time, until the application has given it).

Events are shown in the order you give them (newest first is usual), and grouped
under a heading per calendar day: events that follow each other on the same day
share a heading, so give them sorted by time. The headings are `h3` elements.
Something that happened on a day, with no time of day (a delivery date, a
deadline), is a `dayEvent`: it sits under its day and draws no clock time. Give the
timeline `now` and the headings say "Today" and "Yesterday". A thin gray line connects the markers of a day; a marker is an icon
in the tone of the event, or a dot. The marker is decoration only (hidden from
screen readers), so the title of an event must say what its color means.

Details are folded away in a native `details` element, so they work with the
keyboard and need no state. The footer loads more: a button and a status text
next to it, shown when you set `onLoadMore`. The button stays in the page in
every state (it shows a spinner while the next page loads, turns into "Try
again" when that failed and dims when there is nothing more), so the keyboard
focus is never thrown away.

A loading skeleton, an empty state and a failure with retry are built in; use
`remote` to take them from a `Remote`. The built-in text is English unless you
set `locale`.


# Views

@docs view


# Events

@docs Event, event, dayEvent, withDescription, withTone, withIcon, withAuthor, withAuthorImage, withDetails


# Look and time

@docs Attribute, settings, now, compact, ungrouped, ariaLabel, maxHeight, locale


# Loading more

@docs onLoadMore, loadingMore, moreFailed, hasMore


# Loading, failure and empty

@docs loading, failed, onRetry, remote, skeletonRows, emptyTitle, emptyDescription

-}

import Html exposing (Html)
import Html.Attributes as Attr
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
    }


{-| An event with an id, the time it happened and a short title.

    Timeline.event "ev-1042" shippedAt "Order shipped"

The id must be unique among the events and stay the same for the same event
between renders (use the id from your database, not the position in the list).
It keeps the DOM stable when the list changes, for example when a page of older
events is added. The title is the headline of the event: a few words, in
sentence case.

-}
event : String -> Time.Posix -> String -> Event msg
event id time title =
    eventWhen id (At time) title


{-| An event that happened on a day, with no time of day: a delivery date, a
deadline, an invoice date. It sits under the heading of its day and no time is
written next to it (there is no "00:00"). Give the events sorted, and put the
day events of a day together with the timed events of that day.

    Timeline.dayEvent "ev-77" invoiceDate "Invoice dated"

-}
dayEvent : String -> Date -> String -> Event msg
dayEvent id day title =
    eventWhen id (OnDay day) title


eventWhen : String -> When -> String -> Event msg
eventWhen id when title =
    Event
        { id = id
        , when = when
        , title = title
        , description = Nothing
        , tone = Neutral
        , icon = Nothing
        , author = Nothing
        , authorImage = Nothing
        , details = Nothing
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
    , onLoadMore : Maybe msg
    , loadingMore : Bool
    , moreFailed : Maybe Problem
    , hasMore : Bool
    , emptyTitle : Maybe String
    , emptyDescription : Maybe String
    , skeletonRows : Int
    , maxHeight : Maybe Int
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
        , onLoadMore = Nothing
        , loadingMore = False
        , moreFailed = Nothing
        , hasMore = True
        , emptyTitle = Nothing
        , emptyDescription = Nothing
        , skeletonRows = 4
        , maxHeight = Nothing
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


{-| The current time. It lets the day headings say "Today" and "Yesterday" and
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


{-| While `True` a skeleton is shown instead of the events (see `skeletonRows`),
and screen readers hear "Loading events". Pass a field of your model. Default:
`False`.

`loading`, `failed` and `remote` only add up: the timeline is busy when any of
them says so, and shows a failure when any of them has one, whatever the order.

-}
loading : Bool -> Attribute msg
loading isLoading =
    Attribute (\config -> { config | busy = config.busy || isLoading })


{-| Shows the problem instead of the events, with a "Try again" button if
`onRetry` is set and the problem is worth retrying. Make a `Problem` with
`Klar.Remote.problem`, or use `remote`.
-}
failed : Problem -> Attribute msg
failed problem =
    Attribute (\config -> { config | failure = Just problem })


{-| Takes loading, failure, refreshing and old data from a `Remote`. The events
themselves are passed to `view` as usual. `NotAsked` and `Loading` show the
skeleton, `Failed` shows the problem and `Loaded` shows the events. Data that is
`Kept` stays on the screen: dimmed and busy while it is refreshed, and with
"Old data from 14:05" and a retry (`onRetry`) when the last refresh failed. The
time is in the zone of the settings.

    Timeline.view [ Timeline.remote model.history ]
        (List.map toEvent (Remote.withDefault [] model.history))

-}
remote : Remote a -> Attribute msg
remote data =
    Attribute
        (\config ->
            let
                ( settled, freshness ) =
                    Freshness.settle data
            in
            { config
                | busy = config.busy || Freshness.waiting settled
                , failure =
                    case settled of
                        Remote.Failed problem ->
                            Just problem

                        _ ->
                            config.failure
                , freshness = freshness
            }
        )


{-| The message sent by the "Try again" button in the failure state. The button
is only shown when the problem is worth retrying (see `Klar.Remote.isRetryable`
in [Klar.Remote](Klar-Remote)). A failed next page has its own retry button,
which sends the `onLoadMore` message.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Adds the footer under the events: a "Load more" button that sends this
message, and a status text next to it ("Showing 20 events"). Without
`onLoadMore` there is no footer, and `loadingMore`, `moreFailed` and `hasMore`
have no effect.
-}
onLoadMore : msg -> Attribute msg
onLoadMore msg =
    Attribute (\config -> { config | onLoadMore = Just msg })


{-| Say `True` while the next page is on its way: the button shows a spinner and
does nothing, and the status text says "Loading more events ...". Pass a field
of your model. Default: `False`.
-}
loadingMore : Bool -> Attribute msg
loadingMore value =
    Attribute (\config -> { config | loadingMore = value })


{-| The next page failed to load: the footer shows the title of the problem, and
the button turns into "Try again" and sends the `onLoadMore` message again. The
events already loaded stay. Pass it only while the failure applies;
`loadingMore` wins over it.
-}
moreFailed : Problem -> Attribute msg
moreFailed problem =
    Attribute (\config -> { config | moreFailed = Just problem })


{-| Say `False` when the last page has been loaded: the button dims (and keeps
its place in the tab order) and the status text says "No more events" instead of
how many are shown. Default: `True`.
-}
hasMore : Bool -> Attribute msg
hasMore value =
    Attribute (\config -> { config | hasMore = value })


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

A scroll area must be reachable with the keyboard. With `onLoadMore` the button
in the footer is a tab stop inside it; without, the timeline itself takes the
keyboard focus (`tabindex="0"`) and is a region named by `ariaLabel` ("Events" if
you gave none), so that the arrow keys scroll it.

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
    , retry : String
    , shown : Int -> String
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
    , retry = pick "Prøv igjen" "Try again"
    , shown =
        \n ->
            pick
                ("Viser " ++ Format.int loc n ++ " " ++ Format.plural loc n { one = "hendelse", other = "hendelser" })
                ("Showing " ++ Format.int loc n ++ " " ++ Format.plural loc n { one = "event", other = "events" })
    }



-- VIEW


{-| The timeline. Events are shown in the order given; events that follow each
other on the same day (in the zone of the settings) share a day heading, so
sort them by time first.

    Timeline.view [ Timeline.settings model.settings ] (List.map toEvent model.history)

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
            config.maxHeight /= Nothing && config.onLoadMore == Nothing

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
                    ]
                , Internal.attrMaybe (\pixels -> Internal.styleVars [ ( "max-height", Internal.px pixels ) ]) config.maxHeight
                , if scrollsWithoutButton then
                    Attr.attribute "aria-label" (Maybe.withDefault t.events config.label)

                  else
                    Internal.attrMaybe (Attr.attribute "aria-label") config.label
                , Internal.attrIf scrollsWithoutButton (Attr.tabindex 0)
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
    in
    case state of
        Busy ->
            wrap
                [ Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                    [ Html.text (Locale.pick config.locale { nb = "Laster hendelser", en = "Loading events" }) ]
                , viewSkeleton config
                ]

        Failed problem ->
            wrap [ failureView config problem ]

        Ready ->
            if List.isEmpty events then
                wrap
                    [ notice
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
                    [ notice
                    , if config.grouped then
                        Html.div [ Internal.cls [ "klar-timeline__days" ] ]
                            (List.map (viewDay config) (groupByDay config.settings events))

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
                    case Date.diffDays day (Settings.toDate config.settings current) of
                        0 ->
                            Just t.today

                        1 ->
                            Just t.yesterday

                        _ ->
                            Nothing

                Nothing ->
                    Nothing
    in
    Html.div [ Internal.cls [ "klar-timeline__day" ] ]
        [ Html.h3 [ Internal.cls [ "klar-timeline__day-title" ] ]
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
        [ Internal.cls [ "klar-timeline__item", "klar-timeline__item--" ++ Theme.toneSuffix data.tone ] ]
        (if config.compact then
            [ Html.span [ Internal.cls [ "klar-timeline__rail" ], Attr.attribute "aria-hidden" "true" ] [ marker ]
            , Html.div [ Internal.cls [ "klar-timeline__content" ] ]
                [ Html.div [ Internal.cls [ "klar-timeline__line" ] ]
                    [ Html.span [ Internal.cls [ "klar-timeline__title" ], Attr.title data.title ] [ Html.text data.title ]
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
                    [ Html.span [ Internal.cls [ "klar-timeline__title" ] ] [ Html.text data.title ]
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
    case config.onLoadMore of
        Nothing ->
            Html.text ""

        Just msg ->
            -- Always a button followed by a status text, in every state: the
            -- button that was pressed stays in the page (it only dims), so the
            -- keyboard focus is not thrown away while the next page loads or
            -- after the last one has arrived.
            let
                button =
                    if config.loadingMore then
                        Button.view [ Button.small, Button.loading True ] t.loadMore

                    else if config.moreFailed /= Nothing then
                        Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick msg ] t.retry

                    else if config.hasMore then
                        Button.view [ Button.small, Button.onClick msg ] t.loadMore

                    else
                        Button.view [ Button.small, Button.ariaDisabled True ] t.loadMore

                note =
                    if config.loadingMore then
                        Html.span [ Internal.cls [ "klar-timeline__footer-text" ], Attr.attribute "role" "status" ]
                            [ Html.text t.loadingMore ]

                    else
                        case config.moreFailed of
                            Just problem ->
                                Html.span
                                    [ Internal.cls [ "klar-timeline__footer-text", "klar-timeline__footer-text--error" ]
                                    , Attr.attribute "role" "status"
                                    ]
                                    [ Icon.view Icon.errorCircle
                                    , Html.span [ Attr.title (Maybe.withDefault (Remote.title config.locale problem) (Remote.detail config.locale problem)) ] [ Html.text (Remote.title config.locale problem) ]
                                    ]

                            Nothing ->
                                Html.span [ Internal.cls [ "klar-timeline__footer-text" ], Attr.attribute "role" "status" ]
                                    [ Html.text
                                        (if config.hasMore then
                                            t.shown count

                                         else
                                            t.noMore
                                        )
                                    ]
            in
            Html.div [ Internal.cls [ "klar-timeline__footer" ] ] [ button, note ]
