module Feed exposing
    ( Feed
    , badge
    , failedWhileHolding
    , init
    , isBusy
    , receive
    , refresh
    , restart
    , staleError
    )

{-| A `Remote` that remembers the last good answer.

-- KLAR GAP: Klar.Remote has no stale state (R2S-002). The whole module is the gap:
`remote` is what Klar draws; `error` and `updatedAt` are what the application needs to
mark old data as old.

-}

import Backend.Api as Api
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Theme exposing (Tone(..))
import Time


type alias Feed a =
    { remote : Remote a
    , error : Maybe Remote.Problem
    , updatedAt : Maybe Time.Posix
    , refreshing : Bool
    }


init : Feed a
init =
    { remote = Loading, error = Nothing, updatedAt = Nothing, refreshing = False }


{-| A new question (another place, another period): the old answer no longer applies.
-}
restart : Feed a -> Feed a
restart _ =
    init


{-| The same question again: keep the rows, show that new ones are on their way.
-}
refresh : Feed a -> Feed a
refresh feed =
    if Remote.isLoaded feed.remote then
        { feed | refreshing = True }

    else
        { feed | remote = Loading, refreshing = False }


receive : Api.Response a -> Feed a -> Feed a
receive response feed =
    case response.result of
        Ok value ->
            { remote = Loaded value, error = Nothing, updatedAt = Just response.at, refreshing = False }

        Err problem ->
            if Remote.isLoaded feed.remote then
                { feed | error = Just problem, refreshing = False }

            else
                { feed | remote = Failed problem, refreshing = False }


isBusy : Feed a -> Bool
isBusy feed =
    feed.refreshing || Remote.isLoading feed.remote


{-| Old data on the screen because the last refresh failed.
-}
staleError : Feed a -> Maybe Remote.Problem
staleError feed =
    if Remote.isLoaded feed.remote then
        feed.error

    else
        Nothing


{-| Did this answer turn good data into old data?
-}
failedWhileHolding : Feed a -> Feed a -> Bool
failedWhileHolding before after =
    case ( staleError before, staleError after ) of
        ( Nothing, Just _ ) ->
            True

        _ ->
            False


{-| The marker for old data, for the header of a card.
-}
badge : Time.Zone -> Feed a -> List (Html msg)
badge zone feed =
    case ( staleError feed, feed.updatedAt ) of
        ( Just _, Just at ) ->
            [ Badge.view [ Badge.tone Warning, Badge.icon Icon.clock ] ("Old data from " ++ Format.time zone at) ]

        _ ->
            []
