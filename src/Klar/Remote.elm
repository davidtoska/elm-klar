module Klar.Remote exposing
    ( Remote(..), fromResult, map, toMaybe, withDefault, isLoading, isSuccess, isFailure
    , Problem, problem, withTitle, withDetail, withCode, isRetryable
    , title, detail, code, kind
    , Kind, network, timeout, server, notFound, forbidden, unauthorized, validation, conflict, unknown
    )

{-| The state of data that comes from a backend: not asked for yet, loading,
failed, or here.

    import Klar.Remote as Remote exposing (Remote(..))

    type alias Model =
        { orders : Remote (List Order) }

    -- NotAsked -> Loading -> Success orders | Failure problem

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


# Remote data

@docs Remote, fromResult, map, toMaybe, withDefault, isLoading, isSuccess, isFailure


# Problems

@docs Problem, problem, withTitle, withDetail, withCode, isRetryable


# Reading a problem

@docs title, detail, code, kind


# Kinds of problems

@docs Kind, network, timeout, server, notFound, forbidden, unauthorized, validation, conflict, unknown

-}

import Klar.Locale as Locale exposing (Locale)


{-| Data you ask for. Start in `NotAsked` (or `Loading` if the request is sent
in `init`), then move to `Success` or `Failure`. Refreshing data that is already
there is up to you: keep the `Success` value and show your own indicator, or go
back to `Loading` to show the skeleton again.
-}
type Remote a
    = NotAsked
    | Loading
    | Failure Problem
    | Success a


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
the kind in the given language.
-}
detail : Locale -> Problem -> Maybe String
detail locale (Problem value) =
    case value.detail of
        Just own ->
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
            ( pick "Skjemaet inneholder feil" "The form has errors"
            , pick "Rett opp feltene som er markert og prøv igjen." "Fix the highlighted fields and try again."
            )

        Conflict ->
            ( pick "Handlingen kan ikke gjennomføres" "The action can't be completed"
            , pick "Dataene har endret seg eller er i konflikt med andre data." "The data changed or conflicts with other data."
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

        Failure p ->
            Failure p

        Success a ->
            Success (change a)


{-| The data, if it is there.
-}
toMaybe : Remote a -> Maybe a
toMaybe remote =
    case remote of
        Success a ->
            Just a

        _ ->
            Nothing


{-| The data, or a fallback while it is not there.

    Remote.withDefault [] model.orders

-}
withDefault : a -> Remote a -> a
withDefault fallback remote =
    case remote of
        Success a ->
            a

        _ ->
            fallback


{-| Turns the `Result` of a request into a `Remote`. Convert your error to a
`Problem` first, with `Result.mapError`.

    Result.mapError toProblem result
        |> Remote.fromResult

-}
fromResult : Result Problem a -> Remote a
fromResult result =
    case result of
        Ok a ->
            Success a

        Err p ->
            Failure p


{-| Whether the request is on its way.
-}
isLoading : Remote a -> Bool
isLoading remote =
    case remote of
        Loading ->
            True

        _ ->
            False


{-| Whether the data is there.
-}
isSuccess : Remote a -> Bool
isSuccess remote =
    case remote of
        Success _ ->
            True

        _ ->
            False


{-| Whether the request failed.
-}
isFailure : Remote a -> Bool
isFailure remote =
    case remote of
        Failure _ ->
            True

        _ ->
            False
