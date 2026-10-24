# Klar.Timeline

A vertical history of events: an audit trail, an order log, an activity feed.

Import: `import Klar.Timeline as Timeline` | Group: Data display

Types: `Event`, `Attribute`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> List (Event msg) -> Html msg
viewRemote : List (Attribute msg) -> Remote.Remote (List (Event msg)) -> Html msg

-- Events
type Event msg  -- opaque: no constructors are exposed
event : String -> Time.Posix -> String -> Event msg
dayEvent : String -> Date.Date -> String -> Event msg
withDescription : String -> Event msg -> Event msg
withTone : Theme.Tone -> Event msg -> Event msg
withIcon : Icon.Icon -> Event msg -> Event msg
withAuthor : String -> Event msg -> Event msg
withAuthorImage : String -> Event msg -> Event msg
withDetails : Html msg -> Event msg -> Event msg

-- Look and time
type Attribute msg  -- opaque: no constructors are exposed
settings : Settings.Settings -> Attribute msg
now : Time.Posix -> Attribute msg
compact : Attribute msg
ungrouped : Attribute msg
ariaLabel : String -> Attribute msg
maxHeight : Int -> Attribute msg
headingLevel : Int -> Attribute msg
id : String -> Attribute msg
locale : Locale.Locale -> Attribute msg

-- Loading more
loadMore : msg -> Remote.Remote Bool -> Attribute msg
total : Int -> Attribute msg

-- Failure and empty
onRetry : msg -> Attribute msg
skeletonRows : Int -> Attribute msg
emptyTitle : String -> Attribute msg
emptyDescription : String -> Attribute msg
```

## Documentation

A vertical history of events: an audit trail, an order log, an activity feed.

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
        ( { model | morePages = Remote.Failed problem }, Cmd.none ) The clock times and the day an

event belongs to are those of the zone in the settings (UTC, with "UTC" after the
time, until the application has given it).

Events are shown in the order you give them (newest first is usual), and grouped
under a heading per calendar day: events that follow each other on the same day
share a heading, so give them sorted by time. The headings are `h3` elements: under a
page title with no heading in between, say `headingLevel 2`.
Something that happened on a day, with no time of day (a delivery date, a
deadline), is a `dayEvent`: it sits under its day and draws no clock time. Give the
timeline `now` and the headings say "Today" and "Yesterday". A thin gray line connects the markers of a day; a marker is an icon
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

## Views

### `view`

```elm
view : List (Attribute msg) -> List (Event msg) -> Html msg
```

The timeline. Events are shown in the order given; events that follow each
other on the same day (in the zone of the settings) share a day heading, so
sort them by time first.

    Timeline.view [ Timeline.settings model.settings ] (List.map toEvent model.history)

For events from the backend, use `viewRemote`.

### `viewRemote`

```elm
viewRemote : List (Attribute msg) -> Remote.Remote (List (Event msg)) -> Html msg
```

The timeline from a `Remote`: a skeleton while it loads (see `skeletonRows`),
the problem with "Try again" (`onRetry`) when it failed, the empty state, the
events, the events dimmed and busy while they are refreshed, and "Old data from
14:05" with a retry when the last refresh failed (the time is in the zone of the
`settings`). Shape the data with `Remote.map`.

    Timeline.viewRemote [ Timeline.settings model.settings, Timeline.onRetry ReloadHistory ]
        (Remote.map (List.map toEvent) model.history)

The timeline is the same element around the same events whether they are fresh,
refreshing or old, so focus on a link in the details or on "Load more" survives a
refresh.

## Events

### `Event`

```elm
type Event msg  -- opaque: no constructors are exposed
```

One entry in the history. Make it with `event`, add the rest with the
`with...` functions and pass a list of them to `view`.

### `event`

```elm
event : String -> Time.Posix -> String -> Event msg
```

An event with an id, the time it happened and a short title.

    Timeline.event "ev-1042" shippedAt "Order shipped"

The id must be unique among the events and stay the same for the same event
between renders (use the id from your database, not the position in the list).
It keeps the DOM stable when the list changes, for example when a page of older
events is added. The title is the headline of the event: a few words, in
sentence case.

### `dayEvent`

```elm
dayEvent : String -> Date.Date -> String -> Event msg
```

An event that happened on a day, with no time of day: a delivery date, a
deadline, an invoice date. It sits under the heading of its day and no time is
written next to it (there is no "00:00"). Give the events sorted, and put the
day events of a day together with the timed events of that day.

    Timeline.dayEvent "ev-77" invoiceDate "Invoice dated"

### `withDescription`

```elm
withDescription : String -> Event msg -> Event msg
```

A sentence or two under the title. In a `compact` timeline it follows the
title on the same line and is cut with an ellipsis (the full text is the
tooltip).

### `withTone`

```elm
withTone : Theme.Tone -> Event msg -> Event msg
```

Colors the marker by meaning: `Success` (green), `Warning` (amber), `Danger`
(red) or `Primary` and `Info` (blue). `Neutral` (gray) is the default. The color
is not announced to screen readers, so let the title say what happened. The
`Tone` type is in [Klar.Theme](Klar.Theme.md).

### `withIcon`

```elm
withIcon : Icon.Icon -> Event msg -> Event msg
```

An icon in the marker. Without one the marker is a dot, and in a `compact`
timeline the marker is always a dot.

### `withAuthor`

```elm
withAuthor : String -> Event msg -> Event msg
```

Who did it: a small avatar with the initials of the name, followed by the
name next to the title. A blank name is ignored.

### `withAuthorImage`

```elm
withAuthorImage : String -> Event msg -> Event msg
```

The URL of a picture for the author's avatar. Without one the avatar shows
the initials. It only has an effect together with `withAuthor`.

### `withDetails`

```elm
withDetails : Html msg -> Event msg -> Event msg
```

Content that is folded away behind a "Show details" link, for the long part
of an event: a comment, a list of changed fields. The link turns into "Hide
details" while it is open. It is a native `details` element, so it works with
the keyboard and whether it is open is not part of your model.

    Timeline.event "ev-7" changedAt "Address changed"
        |> Timeline.withDetails (Text.paragraph "From 1 Main Street to 5 Park Lane.")

## Look and time

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a timeline. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the clock
times and of the day an event belongs to, and of "Old data from 14:05". Without it
the times are written in UTC and end in "UTC".

    Timeline.settings model.settings

### `now`

```elm
now : Time.Posix -> Attribute msg
```

The current time. It lets the day headings say "Today" and "Yesterday" and
the tooltip of each time add how long ago it was ("3 hours ago"). Without it the
headings always show the full date. The timeline does not read the clock itself:
keep the value in your model and update it, for example with `Time.every`.

### `compact`

```elm
compact : Attribute msg
```

Less space: a dot as the marker, one line per event with the description
after the title, and the time at the right. Good for side panels. Details still
fold out below the line.

### `ungrouped`

```elm
ungrouped : Attribute msg
```

One list, with no day headings. The time of an event is still shown, but its
date is only in the tooltip.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the timeline, for example "Order history". It makes
the timeline a labelled region, so give each timeline on a page its own name.

### `maxHeight`

```elm
maxHeight : Int -> Attribute msg
```

Makes the timeline, footer included, scroll inside itself when it is taller
than this many pixels: for a log in a side panel. Default: no limit.

A scroll area must be reachable with the keyboard. With `onLoadMore` the button
in the footer is a tab stop inside it; without, the timeline itself takes the
keyboard focus (`tabindex="0"`) and is a region named by `ariaLabel` ("Events" if
you gave none), so that the arrow keys scroll it.

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

The level, 1 to 6, of the heading of each day (`h3` by default; other numbers
are moved into that range). The headings must follow the ones of the page: a
timeline directly under the `h1` of a page takes 2, one in a card with an `h2`
title keeps 3.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the timeline, which then takes focus from a command in every state
(loading, failed, loaded). The "Try again" button of a failure is replaced when the
request starts again, and focus would fall back to the page; call
[`Klar.focus`](Klar.md#focus) with this id in the same `update`
branch. The id must be unique on the page.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text ("Show details", "Load more", "Today",
"Yesterday", the footer and so on) and of the dates. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

## Loading more

### `loadMore`

```elm
loadMore : msg -> Remote.Remote Bool -> Attribute msg
```

Adds the footer under the events: a "Load more" button that sends the message,
and a status text next to it. The `Remote Bool` is the request for the next page,
and its `Bool` says whether there is more after the events shown:

  - `Loaded True` or `NotAsked`: "Load more" and "Showing 20 events".

  - `Loading`, or data that is being refreshed (`Remote.refresh`): the button
    shows a spinner and does nothing, and the status says "Loading more events ...".

  - `Failed`, or data whose refresh failed: the title of the problem, and the
    button turns into "Try again" and sends the message again. The events already
    loaded stay.

  - `Loaded False`: that was all. The button stays, dimmed and unavailable, so
    that the keyboard focus on it is not thrown away, and the status says "No more
    events".

    Timeline.loadMore LoadMoreHistory model.morePages

The button is one element in every state. Without `loadMore` there is no footer.

### `total`

```elm
total : Int -> Attribute msg
```

How many events there are in all, when the backend says so: the footer then
says "Showing 20 of 340 events". Without it the footer counts only the events
shown.

## Failure and empty

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by the "Try again" button of a timeline from a `Remote`
(`viewRemote`) that failed, and by the marker of old data. The button is only shown
when the problem is worth retrying (see `Klar.Remote.isRetryable` in
[Klar.Remote](Klar.Remote.md)). A failed next page has its own retry button, which sends
the message of `loadMore`.

### `skeletonRows`

```elm
skeletonRows : Int -> Attribute msg
```

How many placeholder events to show while loading. The default is 4; the
value is kept between 1 and 20.

### `emptyTitle`

```elm
emptyTitle : String -> Attribute msg
```

The title of the empty state, shown when there are no events. The default is
"No events".

### `emptyDescription`

```elm
emptyDescription : String -> Attribute msg
```

A line of explanation under the title of the empty state, such as what
creates the first event. Default: none.
