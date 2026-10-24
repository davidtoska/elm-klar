module Klar.Remote exposing
    ( Remote(..), fromResult, map, map2, toMaybe, withDefault, isLoading, isLoaded, isFailed
    , Kept, refresh, settle, refreshWith, isRefreshing, isStale, staleProblem, loadedAt, staleIn
    , Problem, problem, withTitle, withDetail, withCode, isRetryable
    , title, detail, code, kind
    , Kind, network, timeout, server, notFound, forbidden, unauthorized, validation, conflict, unknown
    )

{-| The state of data that comes from a backend: not asked for yet, loading,
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
that old data says "Old data from 14:05". For a new question (another customer,
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

            _ ->
                Remote.problem Remote.unknown


# Remote data

@docs Remote, fromResult, map, map2, toMaybe, withDefault, isLoading, isLoaded, isFailed


# Refreshing and old data

@docs Kept, refresh, settle, refreshWith, isRefreshing, isStale, staleProblem, loadedAt, staleIn


# Problems

@docs Problem, problem, withTitle, withDetail, withCode, isRetryable


# Reading a problem

@docs title, detail, code, kind


# Kinds of problems

@docs Kind, network, timeout, server, notFound, forbidden, unauthorized, validation, conflict, unknown

-}

import Klar.Locale as Locale exposing (Locale)
import Time


{-| Data you ask for. Start in `NotAsked` (or `Loading` if the request is sent
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

-}
type Remote a
    = NotAsked
    | Loading
    | Loaded a
    | Failed Problem
    | Kept (Kept a)


{-| Data that is kept on the screen across a refresh: the data, when it was
loaded (if known), whether a refresh is on its way, and why the last refresh
failed (if it did). The type is opaque; read it with `toMaybe`, `loadedAt`,
`isRefreshing`, `isStale` and `staleProblem`.
-}
type Kept a
    = KeptData
        { data : a
        , at : Maybe Time.Posix
        , refreshing : Bool
        , failure : Maybe Problem
        }


{-| What went wrong, in terms that decide what to tell the user. The type is
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

-}
type Kind
    = Network
    | Timeout
    | Server
    | NotFound
    | Forbidden
    | Unauthorized
    | Validation
    | Conflict
    | Unknown


{-| No contact with the server.
-}
network : Kind
network =
    Network


{-| The server did not answer in time.
-}
timeout : Kind
timeout =
    Timeout


{-| The server failed (5xx).
-}
server : Kind
server =
    Server


{-| The thing does not exist (404).
-}
notFound : Kind
notFound =
    NotFound


{-| The user may not do this (403).
-}
forbidden : Kind
forbidden =
    Forbidden


{-| The user must sign in again (401).
-}
unauthorized : Kind
unauthorized =
    Unauthorized


{-| The server rejected what was sent (400 or 422).
-}
validation : Kind
validation =
    Validation


{-| The data changed in the meantime (409).
-}
conflict : Kind
conflict =
    Conflict


{-| Anything else.
-}
unknown : Kind
unknown =
    Unknown


{-| A failure, described for the user: a `Kind`, and optionally a title, an
explanation and a technical code of your own. The type is opaque, so that fields
can be added in a later version. Make one with `problem`, adjust it with
`withTitle`, `withDetail` and `withCode`, and read it with `title`, `detail`,
`code` and `kind`.
-}
type Problem
    = Problem
        { kind : Kind
        , title : Maybe String
        , detail : Maybe String
        , code : Maybe String
        }


{-| A problem of a kind. Its title and explanation are the ready-made texts for
the kind, in the language of the component that draws it.

    Remote.problem Remote.timeout

-}
problem : Kind -> Problem
problem k =
    Problem { kind = k, title = Nothing, detail = Nothing, code = Nothing }


{-| What kind of problem it is.
-}
kind : Problem -> Kind
kind (Problem value) =
    value.kind


{-| The title: the one set with `withTitle`, or the ready-made text for the kind
in the given language. An empty title (`withTitle ""`) hides the title.
-}
title : Locale -> Problem -> String
title locale (Problem value) =
    case value.title of
        Just own ->
            own

        Nothing ->
            Tuple.first (texts locale value.kind)


{-| The explanation: the one set with `withDetail`, or the ready-made text for
the kind in the given language. A blank explanation (`withDetail ""`) hides it:
the result is then `Nothing`, and components draw no empty paragraph.
-}
detail : Locale -> Problem -> Maybe String
detail locale (Problem value) =
    case value.detail of
        Just own ->
            if String.isEmpty (String.trim own) then
                Nothing

            else
                Just own

        Nothing ->
            Just (Tuple.second (texts locale value.kind))


{-| The technical code set with `withCode`, such as `503`.
-}
code : Problem -> Maybe String
code (Problem value) =
    value.code


texts : Locale -> Kind -> ( String, String )
texts locale k =
    let
        pick nb en =
            Locale.pick locale { nb = nb, en = en }
    in
    case k of
        Network ->
            ( pick "Ingen kontakt med tjenesten" "Can't reach the service"
            , pick "Kunne ikke nå serveren. Sjekk nettverksforbindelsen og prøv igjen." "The server could not be reached. Check your connection and try again."
            )

        Timeout ->
            ( pick "Tjenesten svarte ikke i tide" "The service took too long to respond"
            , pick "Forespørselen tok for lang tid. Prøv igjen om litt." "The request timed out. Try again in a moment."
            )

        Server ->
            ( pick "Noe gikk galt hos oss" "Something went wrong on our side"
            , pick "Serveren fikk en intern feil. Prøv igjen, og si fra hvis feilen vedvarer." "The server hit an internal error. Try again, and report it if it keeps happening."
            )

        NotFound ->
            ( pick "Fant ikke det du lette etter" "We couldn't find that"
            , pick "Det kan være slettet eller flyttet." "It may have been deleted or moved."
            )

        Forbidden ->
            ( pick "Ingen tilgang" "No access"
            , pick "Du har ikke tilgang til dette. Kontakt en administrator hvis du mener det er feil." "You don't have access to this. Contact an administrator if you think this is wrong."
            )

        Unauthorized ->
            ( pick "Du må logge inn på nytt" "Please sign in again"
            , pick "Økten din har utløpt." "Your session has expired."
            )

        Validation ->
            ( pick "Forespørselen ble avvist" "The request was rejected"
            , pick "Tjenesten godtok ikke det som ble sendt. Sjekk det du skrev inn eller valgte, og prøv igjen." "The service did not accept what was sent. Check what you entered or chose, and try again."
            )

        Conflict ->
            ( pick "Dataene er endret i mellomtiden" "The data changed in the meantime"
            , pick "Noen andre har endret dette siden du hentet det. Last inn på nytt for å se siste versjon." "Someone else changed this after you loaded it. Reload to see the latest version."
            )

        Unknown ->
            ( pick "Uventet feil" "Unexpected error"
            , pick "Noe uventet skjedde. Prøv igjen." "Something unexpected happened. Try again."
            )


{-| Replaces the title of a problem.

    Remote.problem Remote.notFound
        |> Remote.withTitle "Order not found"

-}
withTitle : String -> Problem -> Problem
withTitle own (Problem value) =
    Problem { value | title = Just own }


{-| Replaces the explanation of a problem.
-}
withDetail : String -> Problem -> Problem
withDetail own (Problem value) =
    Problem { value | detail = Just own }


{-| Adds a technical code to show next to the problem, like `503`.
-}
withCode : String -> Problem -> Problem
withCode own (Problem value) =
    Problem { value | code = Just own }


{-| Whether trying again could help: network trouble, timeouts, server errors
and unknown errors are worth retrying; the rest will fail the same way again.
Components show the retry button only for retryable problems.
-}
isRetryable : Problem -> Bool
isRetryable (Problem value) =
    case value.kind of
        Network ->
            True

        Timeout ->
            True

        Server ->
            True

        Unknown ->
            True

        _ ->
            False


{-| Transforms the data when it is there.

    Remote.map List.length model.orders -- Remote Int

-}
map : (a -> b) -> Remote a -> Remote b
map change remote =
    case remote of
        NotAsked ->
            NotAsked

        Loading ->
            Loading

        Failed p ->
            Failed p

        Loaded a ->
            Loaded (change a)

        Kept (KeptData value) ->
            Kept (KeptData { data = change value.data, at = value.at, refreshing = value.refreshing, failure = value.failure })


{-| Combines two remotes, for a view that needs both: an order and its customer in one
`RemoteView`. The data is there when both are there. Otherwise the state that says
the most wins: a failure (the first one), then loading, then not asked. When either
side is refreshed or old, so is the combination: refreshing while either is, old with
the problem of the first old side, and loaded at the earlier of the two times.

    Remote.map2 (\order customer -> { order = order, customer = customer })
        model.order
        model.customer

-}
map2 : (a -> b -> c) -> Remote a -> Remote b -> Remote c
map2 combine left right =
    case ( facts left, facts right ) of
        ( Just l, Just r ) ->
            if l.fresh && r.fresh then
                Loaded (combine l.data r.data)

            else
                Kept
                    (KeptData
                        { data = combine l.data r.data
                        , at = earlier l.at r.at
                        , refreshing = l.refreshing || r.refreshing
                        , failure =
                            case l.failure of
                                Just _ ->
                                    l.failure

                                Nothing ->
                                    r.failure
                        }
                    )

        _ ->
            -- one side has no data: the side that says the most
            case ( left, right ) of
                ( Failed p, _ ) ->
                    Failed p

                ( _, Failed p ) ->
                    Failed p

                ( Loading, _ ) ->
                    Loading

                ( _, Loading ) ->
                    Loading

                _ ->
                    NotAsked


{-| The data and how fresh it is, when there is data. `fresh` is plain `Loaded`.
-}
facts : Remote a -> Maybe { data : a, at : Maybe Time.Posix, refreshing : Bool, failure : Maybe Problem, fresh : Bool }
facts remote =
    case remote of
        Loaded a ->
            Just { data = a, at = Nothing, refreshing = False, failure = Nothing, fresh = True }

        Kept (KeptData value) ->
            Just { data = value.data, at = value.at, refreshing = value.refreshing, failure = value.failure, fresh = False }

        _ ->
            Nothing


earlier : Maybe Time.Posix -> Maybe Time.Posix -> Maybe Time.Posix
earlier a b =
    case ( a, b ) of
        ( Just x, Just y ) ->
            if Time.posixToMillis x <= Time.posixToMillis y then
                a

            else
                b

        ( Just _, Nothing ) ->
            a

        ( Nothing, _ ) ->
            b


{-| The data, if it is there.
-}
toMaybe : Remote a -> Maybe a
toMaybe remote =
    case remote of
        Loaded a ->
            Just a

        Kept (KeptData value) ->
            Just value.data

        _ ->
            Nothing


{-| The data, or a fallback while it is not there.

    Remote.withDefault [] model.orders

-}
withDefault : a -> Remote a -> a
withDefault fallback remote =
    case remote of
        Loaded a ->
            a

        Kept (KeptData value) ->
            value.data

        _ ->
            fallback


{-| Turns the `Result` of a request into a `Remote`, for an answer to a new
question, where nothing old is on the screen to keep: a value for one key of a
`Dict`, search hits that belong to the latest query. It is `settle Loading`. For the
answer to a request that refreshes what is shown, use `settle`, which keeps the data
when the refresh fails. Convert your error to a `Problem` first, with
`Result.mapError`.

    Result.mapError toProblem result
        |> Remote.fromResult

-}
fromResult : Result Problem a -> Remote a
fromResult result =
    case result of
        Ok a ->
            Loaded a

        Err p ->
            Failed p


{-| Whether the first request is on its way and there is nothing to show yet.
Data that is being refreshed is not loading: see `isRefreshing`.
-}
isLoading : Remote a -> Bool
isLoading remote =
    case remote of
        Loading ->
            True

        _ ->
            False


{-| Whether the data is there, fresh or old.
-}
isLoaded : Remote a -> Bool
isLoaded remote =
    case remote of
        Loaded _ ->
            True

        Kept _ ->
            True

        _ ->
            False


{-| Whether the request failed and there is no data to show. When a refresh failed
and the old data is still there, the data is stale: see `isStale`.
-}
isFailed : Remote a -> Bool
isFailed remote =
    case remote of
        Failed _ ->
            True

        _ ->
            False


{-| Starts a refresh: call it when you send the request again. Data that is there
stays (`Loaded` becomes `Kept`, marked as refreshing; old data stays old until the
answer comes), and anything else goes to `Loading`. Components dim the data and
set it busy.

    ( { model | orders = Remote.refresh model.orders }, fetchOrders )

For a new question (another customer, another period) the old answer does not
apply: set `Loading` instead.

-}
refresh : Remote a -> Remote a
refresh remote =
    case remote of
        Loaded a ->
            Kept (KeptData { data = a, at = Nothing, refreshing = True, failure = Nothing })

        Kept (KeptData value) ->
            Kept (KeptData { value | refreshing = True })

        _ ->
            Loading


{-| Takes the answer of a request into the state, in one line, for the first load
and for every refresh. `Ok` gives fresh `Loaded` data. `Err` while there is data to
show keeps the data and makes it old, with the problem (components then draw "Old
data" and a retry); `Err` when there is nothing to show is a plain `Failed`. A failed
refresh never writes over good data.

    GotOrders result ->
        ( { model | orders = Remote.settle model.orders (Result.mapError toProblem result) }
        , Cmd.none
        )

The answer of an `Http` request comes as it is, with no time: this is the line for it.
When you do have the time of the answer, `refreshWith` does the same and remembers it,
so that old data says when it was loaded ("Old data from 14:05").

-}
settle : Remote a -> Result Problem a -> Remote a
settle before result =
    case result of
        Ok a ->
            Loaded a

        Err problem_ ->
            keepAfter problem_ before


{-| `settle`, for an answer whose time you have: `Ok` gives fresh data that
remembers when it was loaded, so that old data says when ("Old data from 14:05"
instead of "Old data"). `Err` is the same as for `settle`.

    GotOrders result at ->
        ( { model | orders = Remote.refreshWith model.orders result at }, Cmd.none )

The time comes with the answer when the request is a `Task` that ends with
`Time.now` (as `ServerList` requests do); for a request that is a `Cmd`, use `settle`.

-}
refreshWith : Remote a -> Result Problem a -> Time.Posix -> Remote a
refreshWith before result at =
    case result of
        Ok a ->
            Kept (KeptData { data = a, at = Just at, refreshing = False, failure = Nothing })

        Err problem_ ->
            keepAfter problem_ before


{-| A failed request: the data that is there stays, old, with the problem; with no
data the request simply failed.
-}
keepAfter : Problem -> Remote a -> Remote a
keepAfter problem_ before =
    case before of
        Loaded a ->
            Kept (KeptData { data = a, at = Nothing, refreshing = False, failure = Just problem_ })

        Kept (KeptData value) ->
            Kept (KeptData { value | refreshing = False, failure = Just problem_ })

        _ ->
            Failed problem_


{-| Whether a refresh is on its way while the data is shown.
-}
isRefreshing : Remote a -> Bool
isRefreshing remote =
    case remote of
        Kept (KeptData value) ->
            value.refreshing

        _ ->
            False


{-| Whether the data on the screen is old because the last refresh failed. Use it
for a notice on the page; the components mark old data themselves.
-}
isStale : Remote a -> Bool
isStale remote =
    staleProblem remote /= Nothing


{-| Why the last refresh failed, while the old data is still shown.
-}
staleProblem : Remote a -> Maybe Problem
staleProblem remote =
    case remote of
        Kept (KeptData value) ->
            value.failure

        _ ->
            Nothing


{-| When the data was loaded: the time given to `refreshWith` for the answer that
brought it. `Nothing` when it is not known.
-}
loadedAt : Remote a -> Maybe Time.Posix
loadedAt remote =
    case remote of
        Kept (KeptData value) ->
            value.at

        _ ->
            Nothing


{-| A name for each stale `Remote`, for the notice of the whole page
(`Klar.Alert.stale`): the name when the data is stale, nothing otherwise.

    List.concat
        [ Remote.staleIn "orders" model.orders
        , Remote.staleIn "figures" model.summary
        ]

-}
staleIn : String -> Remote a -> List String
staleIn name remote =
    if isStale remote then
        [ name ]

    else
        []
