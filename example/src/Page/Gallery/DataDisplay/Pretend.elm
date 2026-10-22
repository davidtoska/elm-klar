module Page.Gallery.DataDisplay.Pretend exposing (down, later, respond)

{-| A pretend backend for the examples of the data display page: it answers after
a moment, or fails when it is asked to.
-}

import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Process
import Task


{-| Answers after a moment with `answer`, or with a server problem when `failing`
is set. Map the command into a message with `Cmd.map`.
-}
respond : Bool -> a -> Cmd (Result Problem a)
respond failing answer =
    Process.sleep 900
        |> Task.map
            (\_ ->
                if failing then
                    Err (Remote.problem Remote.server)

                else
                    Ok answer
            )
        |> Task.perform identity


{-| Sends the message after a moment.
-}
later : msg -> Cmd msg
later msg =
    Process.sleep 900 |> Task.perform (\_ -> msg)


{-| What an example shows whose backend is down on purpose: the failure, or the
loading state for a moment after "Try again", and then the failure again.
-}
down : Locale -> Bool -> Remote a
down locale retrying =
    if retrying then
        Remote.Loading

    else
        Remote.Failed (Remote.problem Remote.network)
