module Page.Effect exposing
    ( Context
    , Effect(..)
    , Outbox
    , View
    , empty
    , notify
    , push
    , take
    )

{-| What the application pages share with `Main`.

A page never talks to the shell directly. It receives a `Context`, and leaves
`Effect`s ("show this toast", "go there") in its `Outbox`, which `Main` empties
after every update and carries out. A page view is split in two: the content, and
the overlays (dialogs, drawers) that must be rendered outside the shell's content
area so that the page behind them can be made inert.

-}

import Html exposing (Html)
import Klar.Date exposing (Date)
import Klar.Locale exposing (Locale)
import Klar.Overlay exposing (Overlay)
import Klar.Theme exposing (Tone)
import Route exposing (Route)


type alias Context =
    { locale : Locale
    , today : Date
    }


{-| `Go` adds the address to the browser's history. `Replace` takes the place of
the current address, for a redirect: an address that cannot be shown must not come
back with the back button.
-}
type Effect
    = Notify Tone String String
    | Go Route
    | Replace Route


{-| Effects waiting to be carried out, oldest first.
-}
type alias Outbox =
    List Effect


type alias View msg =
    { content : Html msg
    , overlays : List (Overlay msg)
    }


empty : Outbox
empty =
    []


{-| Adds an effect to an outbox.
-}
push : Effect -> Outbox -> Outbox
push effect outbox =
    outbox ++ [ effect ]


{-| A toast with a title and a message.
-}
notify : Tone -> String -> String -> Effect
notify =
    Notify


{-| Splits an outbox off a page model: the outbox and the same model with an empty
one.
-}
take : { a | effects : Outbox } -> ( { a | effects : Outbox }, Outbox )
take model =
    ( { model | effects = [] }, model.effects )
