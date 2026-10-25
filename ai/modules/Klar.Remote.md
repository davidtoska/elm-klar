# Klar.Remote

The state of data that comes from a backend: not asked for yet, loading, failed, here, or kept (old data while it is refreshed, or after a refresh failed).

Import: `import Klar.Remote as Remote` | Group: Data and utilities

Types: `Kept`, `Kind`, `Remote`, `Problem`

## Signatures

```elm
-- Remote data
type Remote a = NotAsked | Loading | Loaded a | Failed Problem | Kept (Kept a)
fromResult : Result Problem a -> Remote a
map : (a -> b) -> Remote a -> Remote b
map2 : (a -> b -> c) -> Remote a -> Remote b -> Remote c
toMaybe : Remote a -> Maybe a
withDefault : a -> Remote a -> a
isLoading : Remote a -> Bool
isLoaded : Remote a -> Bool
isFailed : Remote a -> Bool

-- Refreshing and old data
type Kept a  -- opaque: no constructors are exposed
refresh : Remote a -> Remote a
settle : Remote a -> Result Problem a -> Remote a
refreshWith : Remote a -> Result Problem a -> Time.Posix -> Remote a
isRefreshing : Remote a -> Bool
isStale : Remote a -> Bool
staleProblem : Remote a -> Maybe Problem
loadedAt : Remote a -> Maybe Time.Posix
staleIn : String -> Remote a -> List String

-- Problems
type Problem  -- opaque: no constructors are exposed
problem : Kind -> Problem
withTitle : String -> Problem -> Problem
withDetail : String -> Problem -> Problem
withCode : String -> Problem -> Problem
isRetryable : Problem -> Bool

-- Reading a problem
title : Locale.Locale -> Problem -> String
detail : Locale.Locale -> Problem -> Maybe String
code : Problem -> Maybe String
kind : Problem -> Kind

-- Kinds of problems
type Kind  -- opaque: no constructors are exposed
network : Kind
timeout : Kind
server : Kind
notFound : Kind
forbidden : Kind
unauthorized : Kind
validation : Kind
conflict : Kind
tooManyRequests : Kind
unknown : Kind
```

## Documentation

The state of data that comes from a backend: not asked for yet, loading,
failed, here, or kept (old data while it is refreshed, or after a refresh failed).

Use when: a screen shows data that comes from a backend and can be loading, failed or old.
Do not use when: the data is always there, as a plain value in the model.
Quick path: `refresh` when the request leaves, `settle` when the answer comes, then give the `Remote` to a component.

    import Klar.Remote as Remote exposing (Remote(..))

    type alias Model =
        { orders : Remote (List Order) }

    -- NotAsked -> Loading -> Loaded orders | Failed problem
    -- with data on the screen, a refresh or a failed refresh is Kept (the data stays)

Components that show remote data (`Klar.Table`, `Klar.Select`, `Klar.ListItem`,
`Klar.RemoteView` ...) take a `Remote` and render the loading skeleton, the failure
with a retry button and the empty state themselves, so a screen is correct in every
state without you writing the cases each time.

    Table.rows model.orders

**The two lines of every request.** After the first load most of what a screen shows
is data you already have: it is refreshed, or the refresh failed and what is on the
screen is old. Two functions carry that, and every component draws it (the data
stays, dimmed and busy while it is refreshed; "Old data" with a retry when the
refresh failed):

    -- the request leaves (the first time too: anything without data becomes Loading)
    Reload ->
        ( { model | orders = Remote.refresh model.orders }, fetchOrders )

    -- the answer comes back, good or bad
    GotOrders result ->
        ( { model | orders = Remote.settle model.orders (Result.mapError toProblem result) }
        , Cmd.none
        )

    -- one notice for the whole page
    Alert.stale [] Reload (Remote.staleIn "orders" model.orders)

`refreshWith` is `settle` with the time of the answer, for requests that carry it, so
that old data says "Old data from 14:05"; its fresh data is `Kept`, which holds that
time, where `settle` gives `Loaded`. For a new question (another customer,
another period) the old answer does not apply: set `Loading` instead of `refresh`.
When the user can ask again before the answer comes (a search, a drawer that opens
another order), put the question in the message (`GotCustomer id result`) and settle
only the answer to the question that is shown, so that a late answer to an old
question is dropped.

Read the data with `toMaybe`, `withDefault` or `map`, which see refreshed data too,
and combine two with `map2`. A `case` of your own on a `Remote` needs a branch for
`Kept` (or `toMaybe`): a `case` that only knows `Loaded` shows a skeleton while the
data is refreshed.

A `Problem` says what went wrong in terms that decide what to tell the user: a
`Kind` (whether trying again could help), an optional title, explanation and
code. Turn your own error type into one with `problem` and a `Kind`, and
override the title and the explanation where your backend says something more
useful. The texts are not written until a component draws the problem, in the
language of that component, so a language switch changes a failure that is
already on the screen:

    toProblem : Http.Error -> Remote.Problem
    toProblem error =
        case error of
            Http.Timeout ->
                Remote.problem Remote.timeout

            Http.NetworkError ->
                Remote.problem Remote.network

            Http.BadStatus 404 ->
                Remote.problem Remote.notFound

            Http.BadStatus 429 ->
                Remote.problem Remote.tooManyRequests

            _ ->
                Remote.problem Remote.unknown

## Remote data

### `Remote`

```elm
type Remote a = NotAsked | Loading | Loaded a | Failed Problem | Kept (Kept a)
```

Data you ask for. Start in `NotAsked` (or `Loading` if the request is sent
in `init`); `refresh` when a request leaves and `settle` when its answer comes move
it to `Loaded`, `Failed` or `Kept`.

`Kept` is data you still show while it is refreshed, or after a refresh failed:
it carries the data, when it was loaded, and why the last refresh failed. You
never build it by hand. `refresh`, `settle` and `refreshWith` move between the states, and
every component that takes a `Remote` draws it: the old data stays, with a calm
"Old data from 14:05" and a retry when the refresh failed, and dimmed with a busy
state while it is refreshing.

To read the data, use `toMaybe`, `withDefault` or `map`: they work for `Loaded`
and `Kept` alike. When you `case` on a `Remote` yourself, give `Kept` its own
branch (or take the data with `toMaybe`), so that a refreshed value is not
mistaken for "no data".

### `fromResult`

```elm
fromResult : Result Problem a -> Remote a
```

Turns the `Result` of a request into a `Remote`, for an answer to a new
question, where nothing old is on the screen to keep: a value for one key of a
`Dict`, search hits that belong to the latest query. It is `settle Loading`. For the
answer to a request that refreshes what is shown, use `settle`, which keeps the data
when the refresh fails. Convert your error to a `Problem` first, with
`Result.mapError`.

    Result.mapError toProblem result
        |> Remote.fromResult

### `map`

```elm
map : (a -> b) -> Remote a -> Remote b
```

Transforms the data when it is there.

    Remote.map List.length model.orders -- Remote Int

### `map2`

```elm
map2 : (a -> b -> c) -> Remote a -> Remote b -> Remote c
```

Combines two remotes, for a view that needs both: an order and its customer in one
`RemoteView`. The data is there when both are there. Otherwise the state that says
the most wins: a failure (the first one), then loading, then not asked. When either
side is refreshed or old, so is the combination: refreshing while either is, old with
the problem of the first old side, and loaded at the earlier of the two times.

    Remote.map2 (\order customer -> { order = order, customer = customer })
        model.order
        model.customer

### `toMaybe`

```elm
toMaybe : Remote a -> Maybe a
```

The data, if it is there.

### `withDefault`

```elm
withDefault : a -> Remote a -> a
```

The data, or a fallback while it is not there.

    Remote.withDefault [] model.orders

### `isLoading`

```elm
isLoading : Remote a -> Bool
```

Whether the first request is on its way and there is nothing to show yet.
Data that is being refreshed is not loading: see `isRefreshing`.

### `isLoaded`

```elm
isLoaded : Remote a -> Bool
```

Whether the data is there, fresh or old.

### `isFailed`

```elm
isFailed : Remote a -> Bool
```

Whether the request failed and there is no data to show. When a refresh failed
and the old data is still there, the data is stale: see `isStale`.

## Refreshing and old data

### `Kept`

```elm
type Kept a  -- opaque: no constructors are exposed
```

Data that is kept on the screen across a refresh: the data, when it was
loaded (if known), whether a refresh is on its way, and why the last refresh
failed (if it did). The type is opaque; read it with `toMaybe`, `loadedAt`,
`isRefreshing`, `isStale` and `staleProblem`.

### `refresh`

```elm
refresh : Remote a -> Remote a
```

Starts a refresh: call it when you send the request again. Data that is there
stays (`Loaded` becomes `Kept`, marked as refreshing; old data stays old until the
answer comes), and anything else goes to `Loading`. Components dim the data and
set it busy.

    ( { model | orders = Remote.refresh model.orders }, fetchOrders )

For a new question (another customer, another period) the old answer does not
apply: set `Loading` instead.

### `settle`

```elm
settle : Remote a -> Result Problem a -> Remote a
```

Takes the answer of a request into the state, in one line, for the first load
and for every refresh. `Ok` gives fresh `Loaded` data. `Err` while there is data to
show keeps the data and makes it old, with the problem (components then draw "Old
data" and a retry); `Err` when there is nothing to show is a plain `Failed`. A failed
refresh never writes over good data.

    GotOrders result ->
        ( { model | orders = Remote.settle model.orders (Result.mapError toProblem result) }
        , Cmd.none
        )

The answer of an `Http` request comes as it is, with no time: this is the line for it.
When you do have the time of the answer, `refreshWith` remembers it, so that old data
says when it was loaded ("Old data from 14:05"). The two differ in one thing: an `Ok`
of `settle` is `Loaded`, an `Ok` of `refreshWith` is `Kept` (fresh, with the time).
Components and `toMaybe` read both the same way.

### `refreshWith`

```elm
refreshWith : Remote a -> Result Problem a -> Time.Posix -> Remote a
```

`settle`, for an answer whose time you have: `Ok` gives fresh data that
remembers when it was loaded, so that old data says when ("Old data from 14:05"
instead of "Old data"). `Err` is the same as for `settle`.

Fresh data with a time is `Kept`, not `Loaded` (it is not refreshing and not old:
`isRefreshing` and `isStale` are `False`). A `case` of your own on the result
needs the `Kept` branch, or reads it with `toMaybe`: a `case` that only knows
`Loaded` would show a skeleton for good.

    GotOrders result at ->
        ( { model | orders = Remote.refreshWith model.orders result at }, Cmd.none )

The time comes with the answer when the request is a `Task` that ends with
`Time.now` (as `ServerList` requests do); for a request that is a `Cmd`, use `settle`.

### `isRefreshing`

```elm
isRefreshing : Remote a -> Bool
```

Whether a refresh is on its way while the data is shown.

### `isStale`

```elm
isStale : Remote a -> Bool
```

Whether the data on the screen is old because the last refresh failed. Use it
for a notice on the page; the components mark old data themselves.

### `staleProblem`

```elm
staleProblem : Remote a -> Maybe Problem
```

Why the last refresh failed, while the old data is still shown.

### `loadedAt`

```elm
loadedAt : Remote a -> Maybe Time.Posix
```

When the data was loaded: the time given to `refreshWith` for the answer that
brought it. `Nothing` when it is not known.

### `staleIn`

```elm
staleIn : String -> Remote a -> List String
```

A name for each stale `Remote`, for the notice of the whole page
(`Klar.Alert.stale`): the name when the data is stale, nothing otherwise.

    List.concat
        [ Remote.staleIn "orders" model.orders
        , Remote.staleIn "figures" model.summary
        ]

## Problems

### `Problem`

```elm
type Problem  -- opaque: no constructors are exposed
```

A failure, described for the user: a `Kind`, and optionally a title, an
explanation and a technical code of your own. The type is opaque, so that fields
can be added in a later version. Make one with `problem`, adjust it with
`withTitle`, `withDetail` and `withCode`, and read it with `title`, `detail`,
`code` and `kind`.

### `problem`

```elm
problem : Kind -> Problem
```

A problem of a kind. Its title and explanation are the ready-made texts for
the kind, in the language of the component that draws it.

    Remote.problem Remote.timeout

### `withTitle`

```elm
withTitle : String -> Problem -> Problem
```

Replaces the title of a problem.

    Remote.problem Remote.notFound
        |> Remote.withTitle "Order not found"

### `withDetail`

```elm
withDetail : String -> Problem -> Problem
```

Replaces the explanation of a problem.

### `withCode`

```elm
withCode : String -> Problem -> Problem
```

Adds a technical code to show next to the problem, like `503`.

### `isRetryable`

```elm
isRetryable : Problem -> Bool
```

Whether trying again could help: network trouble, timeouts, server errors,
too many requests and unknown errors are worth retrying; the rest will fail the same
way again.
Components show the retry button only for retryable problems.

## Reading a problem

### `title`

```elm
title : Locale.Locale -> Problem -> String
```

The title: the one set with `withTitle`, or the ready-made text for the kind
in the given language. An empty title (`withTitle ""`) hides the title.

### `detail`

```elm
detail : Locale.Locale -> Problem -> Maybe String
```

The explanation: the one set with `withDetail`, or the ready-made text for
the kind in the given language. A blank explanation (`withDetail ""`) hides it:
the result is then `Nothing`, and components draw no empty paragraph.

### `code`

```elm
code : Problem -> Maybe String
```

The technical code set with `withCode`, such as `503`.

### `kind`

```elm
kind : Problem -> Kind
```

What kind of problem it is.

## Kinds of problems

### `Kind`

```elm
type Kind  -- opaque: no constructors are exposed
```

What went wrong, in terms that decide what to tell the user. The type is
opaque, so that kinds can be added in a later version; choose one of the values
below.

  - `network`: no contact with the server
  - `timeout`: the server did not answer in time
  - `server`: the server failed (5xx)
  - `notFound`: the thing does not exist (404)
  - `forbidden`: the user may not do this (403)
  - `unauthorized`: the user must sign in again (401)
  - `validation`: the server rejected what was sent (400 or 422)
  - `conflict`: the request clashes with the data as it is now (409): it changed in
    the meantime, or what was sent is already there (a number or a name that is taken,
    an order that has already shipped)
  - `tooManyRequests`: the server asks to wait before the next request (429)
  - `unknown`: anything else

### `network`

```elm
network : Kind
```

No contact with the server.

### `timeout`

```elm
timeout : Kind
```

The server did not answer in time.

### `server`

```elm
server : Kind
```

The server failed (5xx).

### `notFound`

```elm
notFound : Kind
```

The thing does not exist (404).

### `forbidden`

```elm
forbidden : Kind
```

The user may not do this (403).

### `unauthorized`

```elm
unauthorized : Kind
```

The user must sign in again (401).

### `validation`

```elm
validation : Kind
```

The server rejected what was sent (400 or 422).

### `conflict`

```elm
conflict : Kind
```

The request clashes with the data as it is now (409): the data changed in the
meantime, or what was sent clashes with what is already there (a number that is
taken, an order that has already shipped). Trying the same again does not help, so
components offer no "Try again".

### `tooManyRequests`

```elm
tooManyRequests : Kind
```

The server is busy with this user's requests and asks to wait (429). Trying again
in a moment can help, so components offer "Try again".

### `unknown`

```elm
unknown : Kind
```

Anything else.
