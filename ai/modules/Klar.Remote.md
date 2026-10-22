# Klar.Remote

The state of data that comes from a backend: not asked for yet, loading, failed, or here.

Import: `import Klar.Remote as Remote` | Group: Data and utilities

Types: `Kind`, `Remote`, `Problem`

## Signatures

```elm
-- Remote data
type Remote a = NotAsked | Loading | Loaded a | Failed Problem
fromResult : Result Problem a -> Remote a
map : (a -> b) -> Remote a -> Remote b
toMaybe : Remote a -> Maybe a
withDefault : a -> Remote a -> a
isLoading : Remote a -> Bool
isLoaded : Remote a -> Bool
isFailed : Remote a -> Bool

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
unknown : Kind
```

## Documentation

The state of data that comes from a backend: not asked for yet, loading,
failed, or here.

    import Klar.Remote as Remote exposing (Remote(..))

    type alias Model =
        { orders : Remote (List Order) }

    -- NotAsked -> Loading -> Loaded orders | Failed problem

Components that show remote data (`Klar.Table`, `Klar.Select`, `Klar.ListItem` ...)
take a `Remote` and render the loading skeleton, the failure with a retry button
and the empty state themselves, so a screen is correct in every state without
you writing the four cases each time.

    Table.rows model.orders

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

            _ ->
                Remote.problem Remote.unknown

## Remote data

### `Remote`

```elm
type Remote a = NotAsked | Loading | Loaded a | Failed Problem
```

Data you ask for. Start in `NotAsked` (or `Loading` if the request is sent
in `init`), then move to `Loaded` or `Failed`. Refreshing data that is already
there is up to you: keep the `Loaded` value and show your own indicator, or go
back to `Loading` to show the skeleton again.

### `fromResult`

```elm
fromResult : Result Problem a -> Remote a
```

Turns the `Result` of a request into a `Remote`. Convert your error to a
`Problem` first, with `Result.mapError`.

    Result.mapError toProblem result
        |> Remote.fromResult

### `map`

```elm
map : (a -> b) -> Remote a -> Remote b
```

Transforms the data when it is there.

    Remote.map List.length model.orders -- Remote Int

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

Whether the request is on its way.

### `isLoaded`

```elm
isLoaded : Remote a -> Bool
```

Whether the data is there.

### `isFailed`

```elm
isFailed : Remote a -> Bool
```

Whether the request failed.

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

Whether trying again could help: network trouble, timeouts, server errors
and unknown errors are worth retrying; the rest will fail the same way again.
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
the kind in the given language.

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
  - `conflict`: the data changed in the meantime (409)
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

The data changed in the meantime (409).

### `unknown`

```elm
unknown : Kind
```

Anything else.
