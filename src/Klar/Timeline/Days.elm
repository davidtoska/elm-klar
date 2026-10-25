module Klar.Timeline.Days exposing (dayKeys)

{-| The keys of the day groups of `Klar.Timeline`, apart so that they can be tested.

@docs dayKeys

-}

import Klar.Date as Date exposing (Date)


{-| A key per day group: its date, with a count after it for a day that comes
back later in the list (events that were not sorted), so that keys never repeat.
A day keeps its key when a new day is added above it, so its elements (an open
`details`, the focus inside it) are kept.
-}
dayKeys : List ( Date, a ) -> List ( String, ( Date, a ) )
dayKeys groups =
    groups
        |> List.foldl
            (\(( day, _ ) as group) ( seen, done ) ->
                let
                    iso =
                        Date.toIso day

                    count =
                        List.length (List.filter (\earlier -> earlier == iso) seen)

                    key =
                        if count == 0 then
                            iso

                        else
                            iso ++ "#" ++ String.fromInt (count + 1)
                in
                ( iso :: seen, ( key, group ) :: done )
            )
            ( [], [] )
        |> Tuple.second
        |> List.reverse
