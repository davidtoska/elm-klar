# Klar.Timeline

A vertical history of events: an audit trail, an order log, an activity feed.

Import: `import Klar.Timeline as Timeline` | Group: Data display

Types: `Event`, `Attribute`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> List (Event msg) -> Html msg

-- Events
type Event msg  -- opaque: no constructors are exposed
event : String -> Time.Posix -> String -> Event msg
withDescription : String -> Event msg -> Event msg
withTone : Theme.Tone -> Event msg -> Event msg
withIcon : Icon.Icon -> Event msg -> Event msg
withAuthor : String -> Event msg -> Event msg
withAuthorImage : String -> Event msg -> Event msg
withDetails : Html msg -> Event msg -> Event msg

-- Look and time
type Attribute msg  -- opaque: no constructors are exposed
zone : Time.Zone -> Attribute msg
now : Time.Posix -> Attribute msg
compact : Attribute msg
ungrouped : Attribute msg
ariaLabel : String -> Attribute msg
maxHeight : Int -> Attribute msg
locale : Locale.Locale -> Attribute msg

-- Loading more
onLoadMore : msg -> Attribute msg
loadingMore : Bool -> Attribute msg
moreFailed : Remote.Problem -> Attribute msg
hasMore : Bool -> Attribute msg

-- Loading, failure and empty
loading : Bool -> Attribute msg
failed : Remote.Problem -> Attribute msg
onRetry : msg -> Attribute msg
remote : Remote.Remote a -> Attribute msg
skeletonRows : Int -> Attribute msg
emptyTitle : String -> Attribute msg
emptyDescription : String -> Attribute msg
```

## Documentation

A vertical history of events: an audit trail, an order log, an activity feed.

    import Klar.Icon as Icon
    import Klar.Text as Text
    import Klar.Theme exposing (Tone(..))
    import Klar.Timeline as Timeline

    Timeline.view
        [ Timeline.zone model.zone
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

Here `model.zone` is a `Time.Zone`, `model.now` and the times of the events
(`shippedAt`, `delayedAt`) are `Time.Posix` values.

Events are shown in the order you give them (newest first is usual), and grouped
under a heading per calendar day: events that follow each other on the same day
share a heading, so give them sorted by time. The headings are `h3` elements.
Times and days are shown in the `zone` you give the timeline, which is UTC unless
you set it. Give the timeline `now` and the headings say "Today" and
"Yesterday". A thin gray line connects the markers of a day; a marker is an icon
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

## Views

### `view`

```elm
view : List (Attribute msg) -> List (Event msg) -> Html msg
```

The timeline. Events are shown in the order given; events that follow each
other on the same day (in the `zone` of the timeline) share a day heading, so
sort them by time first.

    Timeline.view [ Timeline.zone model.zone ] (List.map toEvent model.history)

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

### `zone`

```elm
zone : Time.Zone -> Attribute msg
```

The time zone that decides the clock times and which day an event belongs
to. The default is UTC, so you will usually want the user's own zone: get it with
`Time.here` when the application starts and keep it in your model.

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

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text ("Show details", "Load more", "Today",
"Yesterday", the footer and so on) and of the dates. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

## Loading more

### `onLoadMore`

```elm
onLoadMore : msg -> Attribute msg
```

Adds the footer under the events: a "Load more" button that sends this
message, and a status text next to it ("Showing 20 events"). Without
`onLoadMore` there is no footer, and `loadingMore`, `moreFailed` and `hasMore`
have no effect.

### `loadingMore`

```elm
loadingMore : Bool -> Attribute msg
```

Say `True` while the next page is on its way: the button shows a spinner and
does nothing, and the status text says "Loading more events ...". Pass a field
of your model. Default: `False`.

### `moreFailed`

```elm
moreFailed : Remote.Problem -> Attribute msg
```

The next page failed to load: the footer shows the title of the problem, and
the button turns into "Try again" and sends the `onLoadMore` message again. The
events already loaded stay. Pass it only while the failure applies;
`loadingMore` wins over it.

### `hasMore`

```elm
hasMore : Bool -> Attribute msg
```

Say `False` when the last page has been loaded: the button dims (and keeps
its place in the tab order) and the status text says "No more events" instead of
how many are shown. Default: `True`.

## Loading, failure and empty

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` a skeleton is shown instead of the events (see `skeletonRows`),
and screen readers hear "Loading events". Pass a field of your model. Default:
`False`.

### `failed`

```elm
failed : Remote.Problem -> Attribute msg
```

Shows the problem instead of the events, with a "Try again" button if
`onRetry` is set and the problem is worth retrying. Make a `Problem` with
`Klar.Remote.problem`, or use `remote`.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by the "Try again" button in the failure state. The button
is only shown when the problem is worth retrying (see `Klar.Remote.isRetryable`
in [Klar.Remote](Klar.Remote.md)). A failed next page has its own retry button,
which sends the `onLoadMore` message.

### `remote`

```elm
remote : Remote.Remote a -> Attribute msg
```

Takes loading and failure from a `Remote`. The events themselves are passed
to `view` as usual. `NotAsked` and `Loading` show the skeleton, `Failed` shows
the problem and `Loaded` shows the events.

    Timeline.view [ Timeline.remote model.history ]
        (List.map toEvent (Remote.withDefault [] model.history))

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
