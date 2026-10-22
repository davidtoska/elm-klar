module Klar.Sortable.Machine exposing
    ( Landing
    , Msg(..)
    , Note(..)
    , Sample
    , State
    , handleDomId
    , helpDomId
    , init
    , itemDomId
    , update
    )

{-| What happens in `Klar.Sortable` when the user acts: a state, the messages that
change it and the commands that go with them. It is `Klar.Sortable` without the
drawing, in a module of its own so that the whole path of a drag (a press, the boxes
of the items arriving, the pointer moving, the drop) can be tested with the real
messages. The public module wraps the state and the message in types of its own that
nobody can take apart.
-}

import Browser.Dom as Dom
import Klar.Internal as Internal
import Klar.Sortable.Order as Order
import Klar.Sortable.Session as Session exposing (Device(..), Input(..), Layout, Point, Session)
import Task


type alias State =
    { domId : String
    , serial : Int
    , session : Maybe Session
    , drops : Int
    , last : Maybe Landing
    , note : Maybe Note
    }


{-| The move of the last drop: the key of the item and the index it was given.
-}
type alias Landing =
    { key : String
    , to : Int
    }


{-| What the live region says: the last thing that happened.
-}
type Note
    = PickedUp String Int Int
    | MovedTo Int Int
    | AtLimit Int Int
    | Dropped String Int Int
    | Cancelled String Int Int


init : String -> State
init domId =
    { domId = domId
    , serial = 0
    , session = Nothing
    , drops = 0
    , last = Nothing
    , note = Nothing
    }


type Msg
    = Lift Layout
    | Press Layout Device Point Point
    | Measured Int String (Result Dom.Error Order.Rect)
    | PointerMoved Sample
    | Drop (List String)
    | Step Int
    | Jump Bool
    | Cancel
    | Blurred String
    | Noop


type alias Sample =
    { page : Point
    , client : Point
    , buttons : Int
    }


update : Msg -> State -> ( State, Cmd Msg )
update msg s =
    case msg of
        Lift layout ->
            case Session.keyboard (s.serial + 1) layout of
                Just session ->
                    ( { s
                        | serial = session.serial
                        , session = Just session
                        , note = Just (PickedUp session.source (session.from + 1) (List.length session.order))
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( s, Cmd.none )

        Press layout device page client ->
            case Session.pointer (s.serial + 1) layout device page client of
                Just session ->
                    ( { s | serial = session.serial, session = Just session }
                    , measure s.domId session
                    )

                Nothing ->
                    ( s, Cmd.none )

        Measured serial key (Ok rect) ->
            case s.session of
                Just session ->
                    if session.serial == serial then
                        follow session (Session.measured key rect session) s

                    else
                        ( s, Cmd.none )

                Nothing ->
                    ( s, Cmd.none )

        Measured serial _ (Err _) ->
            -- an item is not on the page (the list has changed): nothing to follow
            case s.session of
                Just session ->
                    if session.serial == serial then
                        ( { s | session = Nothing }, Cmd.none )

                    else
                        ( s, Cmd.none )

                Nothing ->
                    ( s, Cmd.none )

        PointerMoved sample ->
            case s.session of
                Just session ->
                    case session.input of
                        Pointing pointing ->
                            if pointing.device == Mouse && sample.buttons == 0 then
                                -- the button was let go where nobody saw it
                                ( cancelled session s, Cmd.none )

                            else
                                follow session (Session.moved sample.page sample.client session) s

                        Keyboard ->
                            ( s, Cmd.none )

                Nothing ->
                    ( s, Cmd.none )

        Drop keys ->
            case s.session of
                Just session ->
                    drop keys session s

                Nothing ->
                    ( s, Cmd.none )

        Step delta ->
            keyboardMove (Session.step delta) s

        Jump toEnd ->
            keyboardMove (Session.jump toEnd) s

        Cancel ->
            case s.session of
                Just session ->
                    ( cancelled session s, Cmd.none )

                Nothing ->
                    ( s, Cmd.none )

        Blurred key ->
            case s.session of
                Just session ->
                    if session.source == key then
                        ( cancelled session s, Cmd.none )

                    else
                        ( s, Cmd.none )

                Nothing ->
                    ( s, Cmd.none )

        Noop ->
            ( s, Cmd.none )


{-| A pointer session changed (the boxes arrived, the pointer moved): keep the new
session, say what changed and, when the press has just become a drag, put the
focus on the handle so that `Escape` reaches it.
-}
follow : Session -> Session -> State -> ( State, Cmd Msg )
follow before after s =
    let
        total =
            List.length after.order

        note =
            if after.lifted && not before.lifted then
                Just (PickedUp after.source (after.from + 1) total)

            else if after.lifted && after.to /= before.to then
                Just (MovedTo (after.to + 1) total)

            else
                s.note

        cmd =
            if after.lifted && not before.lifted then
                Internal.focus (handleDomId s.domId after.source) Noop

            else
                Cmd.none
    in
    ( { s | session = Just after, note = note }, cmd )


keyboardMove : (Session -> Session) -> State -> ( State, Cmd Msg )
keyboardMove change s =
    case s.session of
        Just session ->
            case session.input of
                Keyboard ->
                    let
                        next =
                            change session

                        total =
                            List.length next.order

                        note =
                            if next.to == session.to then
                                AtLimit (next.to + 1) total

                            else
                                MovedTo (next.to + 1) total
                    in
                    ( { s | session = Just next, note = Just note }
                    , case List.head (List.drop next.to next.order) of
                        Just key ->
                            reveal (itemDomId s.domId key)

                        Nothing ->
                            Cmd.none
                    )

                Pointing _ ->
                    ( s, Cmd.none )

        Nothing ->
            ( s, Cmd.none )


drop : List String -> Session -> State -> ( State, Cmd Msg )
drop keys session s =
    let
        total =
            List.length session.order

        refocus =
            Internal.focus (handleDomId s.domId session.source) Noop
    in
    case Session.finish keys session of
        Session.Dropped target ->
            ( { s
                | session = Nothing
                , drops = s.drops + 1
                , last = Just { key = session.source, to = target }
                , note = Just (Dropped session.source (target + 1) total)
              }
            , refocus
            )

        Session.Kept ->
            ( { s | session = Nothing, note = Just (Dropped session.source (session.from + 1) total) }
            , refocus
            )

        Session.Pressed ->
            -- a click on the handle: it focuses, as a button does
            ( { s | session = Nothing }, refocus )

        Session.Stale ->
            ( cancelled session s, Cmd.none )


{-| Ends the session without moving anything. It says so when an item was held.
-}
cancelled : Session -> State -> State
cancelled session s =
    { s
        | session = Nothing
        , note =
            if session.lifted then
                Just (Cancelled session.source (session.from + 1) (List.length session.order))

            else
                s.note
    }


{-| Asks for the box of every item. The answers come one by one as `Measured`
messages (a `Task` is one frame long, and they all run in the same frame).
-}
measure : String -> Session -> Cmd Msg
measure domId session =
    session.order
        |> List.map
            (\key ->
                Dom.getElement (itemDomId domId key)
                    |> Task.map .element
                    |> Task.attempt (Measured session.serial key)
            )
        |> Cmd.batch


{-| Scrolls the window so that an item is on the screen: the target of a move with
the keys can be far from the item that is held.
-}
reveal : String -> Cmd Msg
reveal id =
    Dom.getViewport
        |> Task.andThen
            (\viewport ->
                Dom.getElement id
                    |> Task.andThen
                        (\found ->
                            let
                                top =
                                    found.element.y

                                bottom =
                                    top + found.element.height

                                window =
                                    viewport.viewport
                            in
                            if top < window.y + 8 then
                                Dom.setViewport window.x (max 0 (top - 8))

                            else if bottom > window.y + window.height - 8 then
                                Dom.setViewport window.x (bottom - window.height + 8)

                            else
                                Task.succeed ()
                        )
            )
        |> Task.attempt (\_ -> Noop)



-- DOM IDS


itemDomId : String -> String -> String
itemDomId domId key =
    domId ++ "-item-" ++ Internal.percentEncode key


handleDomId : String -> String -> String
handleDomId domId key =
    domId ++ "-handle-" ++ Internal.percentEncode key


helpDomId : String -> String
helpDomId domId =
    domId ++ "-help"
