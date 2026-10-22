module Klar.Sortable.Session exposing
    ( Device(..)
    , Drag
    , Finish(..)
    , Input(..)
    , Layout
    , Point
    , Session
    , allMeasured
    , finish
    , jump
    , keyboard
    , measured
    , moved
    , pointer
    , step
    , threshold
    )

{-| The drag session of `Klar.Sortable`, as plain data and pure functions: which
element is held, the list it came from, where it would be dropped now. The session
keeps the order the list had when it began (its keys and which of them are fixed),
so the same type serves a list that is rearranged on its own and, later, moves
between several lists.

No `Cmd`, no `Task`, nothing from the DOM: the pointer positions and the boxes of
the elements come in as values, so every transition can be tested.

-}

import Dict exposing (Dict)
import Klar.Sortable.Order as Order exposing (Rect)


type alias Point =
    { x : Float
    , y : Float
    }


{-| What the pointer is: a mouse, or a finger or pen on a screen.
-}
type Device
    = Mouse
    | Touch


{-| The list as the view drew it when the session began: the keys in order, which
of them are fixed, and whether the list runs sideways.
-}
type alias Layout =
    { source : String
    , order : List String
    , fixed : List Bool
    , horizontal : Bool
    }


type alias Drag =
    { device : Device
    , start : Point
    , page : Point
    , client : Point
    , rects : Dict String Rect
    }


type Input
    = Keyboard
    | Pointing Drag


type alias Session =
    { serial : Int
    , source : String
    , from : Int
    , to : Int
    , order : List String
    , fixed : List Bool
    , horizontal : Bool
    , lifted : Bool
    , input : Input
    }


{-| How far (in pixels) a pointer must travel before a press becomes a drag, so
that a plain click on a handle does nothing.
-}
threshold : Float
threshold =
    4


begin : Int -> Layout -> Input -> Bool -> Maybe Session
begin serial layout input lifted =
    case Order.indexOf layout.source layout.order of
        Just from ->
            if isFixedAt from layout.fixed then
                Nothing

            else
                Just
                    { serial = serial
                    , source = layout.source
                    , from = from
                    , to = from
                    , order = layout.order
                    , fixed = layout.fixed
                    , horizontal = layout.horizontal
                    , lifted = lifted
                    , input = input
                    }

        Nothing ->
            Nothing


isFixedAt : Int -> List Bool -> Bool
isFixedAt index flags =
    flags |> List.drop index |> List.head |> Maybe.withDefault False


{-| A session that begins on the keyboard: the element is lifted at once. Nothing
when the element is not in the list or is fixed.
-}
keyboard : Int -> Layout -> Maybe Session
keyboard serial layout =
    begin serial layout Keyboard True


{-| A session that begins with a press of the pointer, at a point on the page and a
point in the window. It is not a drag until the pointer has moved `threshold`
pixels.
-}
pointer : Int -> Layout -> Device -> Point -> Point -> Maybe Session
pointer serial layout device page client =
    begin serial
        layout
        (Pointing
            { device = device
            , start = page
            , page = page
            , client = client
            , rects = Dict.empty
            }
        )
        False


{-| Remembers the box of one element of the list.
-}
measured : String -> Rect -> Session -> Session
measured key rect session =
    case session.input of
        Pointing pointing ->
            retarget { session | input = Pointing { pointing | rects = Dict.insert key rect pointing.rects } }

        Keyboard ->
            session


{-| Are the boxes of all the elements known? The pointer is not followed before.
-}
allMeasured : Session -> Bool
allMeasured session =
    case session.input of
        Pointing pointing ->
            Dict.size pointing.rects == List.length session.order

        Keyboard ->
            True


{-| The pointer has moved to a point on the page and a point in the window. The
press becomes a drag when it has travelled far enough; a drag looks for the gap
under the pointer.
-}
moved : Point -> Point -> Session -> Session
moved page client session =
    case session.input of
        Pointing pointing ->
            let
                travelled =
                    sqrt ((page.x - pointing.start.x) ^ 2 + (page.y - pointing.start.y) ^ 2)
            in
            retarget
                { session
                    | input = Pointing { pointing | page = page, client = client }
                    , lifted = session.lifted || travelled >= threshold
                }

        Keyboard ->
            session


{-| Looks for the gap under the pointer once the session is a drag and the boxes
are known; the target stays inside the limits the fixed elements set.
-}
retarget : Session -> Session
retarget session =
    case session.input of
        Pointing pointing ->
            if session.lifted && allMeasured session then
                let
                    rects =
                        List.filterMap (\key -> Dict.get key pointing.rects) session.order

                    gap =
                        Order.gapAt session.horizontal rects pointing.page.x pointing.page.y
                in
                { session | to = Order.clampTarget session.fixed session.from (Order.finalIndex session.from gap) }

            else
                session

        Keyboard ->
            session


{-| Moves the target by this many places, never beyond the limits of the fixed
elements.
-}
step : Int -> Session -> Session
step delta session =
    { session | to = Order.clampTarget session.fixed session.from (session.to + delta) }


{-| Jumps to the first place the element may have (`False`) or the last one
(`True`).
-}
jump : Bool -> Session -> Session
jump toEnd session =
    let
        ( low, high ) =
            Order.bounds session.fixed session.from
    in
    { session
        | to =
            if toEnd then
                high

            else
                low
    }


{-| How a session ends when the element is let go.
-}
type Finish
    = Dropped Int
    | Kept
    | Pressed
    | Stale


{-| Ends the session, given the keys of the list as it is drawn now:

  - `Dropped target`: the element was lifted and goes to a new place.
  - `Kept`: it was lifted and let go where it was.
  - `Pressed`: it was never lifted (a click on the handle).
  - `Stale`: the list has changed since the session began; nothing is moved.

-}
finish : List String -> Session -> Finish
finish current session =
    if not session.lifted then
        Pressed

    else if current /= session.order then
        Stale

    else if session.to == session.from then
        Kept

    else
        Dropped session.to
