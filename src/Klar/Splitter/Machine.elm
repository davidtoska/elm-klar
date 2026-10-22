module Klar.Splitter.Machine exposing
    ( Device(..)
    , Drag
    , Layout
    , Msg(..)
    , Sample
    , State
    , effective
    , gutter
    , init
    , isFolded
    , limitsFor
    , paneDomId
    , separatorDomId
    , setSizes
    , update
    )

{-| What happens in `Klar.Splitter` when the user acts: a state with the sizes, the
messages that change it and the commands that go with them. It is `Klar.Splitter`
without the drawing, in a module of its own so that a whole drag (a press, the
container being measured, the pointer moving, the release) can be tested with the
real messages. The public module wraps the state and the message in types of its own
that nobody can take apart.

A pane that can be folded away and has no room at all is **folded**. That is all a
folded pane is: the sizes say it, so a layout that is saved and restored comes back
folded. Nothing else is kept about it, except how much room it had, so that the key
that opens it again can give that back.

-}

import Browser.Dom as Dom
import Dict exposing (Dict)
import Klar.Internal as Internal
import Klar.Splitter.Layout as Layout exposing (Limits, Request)
import Task


{-| The width in pixels of the strip between two panes. The stylesheet draws the
separator this wide (`--klar-split-gutter`); it is what the container has less room
for panes than its own width.
-}
gutter : Float
gutter =
    8


{-| The least room a pane that can be folded away keeps while it is open, as a
fraction, so that it can not be dragged shut by accident and left without a
separator to grab.
-}
sliver : Float
sliver =
    0.02


{-| What the view knows about the panes and does not change while the user acts:
what each asks for, which can fold away, and the direction.
-}
type alias Layout =
    { requests : List Request
    , collapsible : List Bool
    , stacked : Bool
    }


type Device
    = Mouse
    | Touch


type alias Drag =
    { serial : Int
    , separator : Int
    , layout : Layout
    , device : Device
    , start : Float
    , current : Float
    , moved : Bool
    , before : List Float
    }


type alias State =
    { domId : String
    , sizes : List Float
    , remembered : Dict Int Float
    , room : Maybe Float
    , drag : Maybe Drag
    , serial : Int
    }


init : String -> List Float -> State
init domId sizes =
    { domId = domId
    , sizes = Layout.normalise sizes
    , remembered = Dict.empty
    , room = Nothing
    , drag = Nothing
    , serial = 0
    }


setSizes : List Float -> State -> State
setSizes sizes state =
    { state | sizes = Layout.normalise sizes, remembered = Dict.empty }


type alias Sample =
    { x : Float
    , y : Float
    , buttons : Int
    }


type Msg
    = Press Layout Int Device Sample
    | Measured Int Layout (Result Dom.Error Dom.Element)
    | PointerMoved Sample
    | Release
    | Cancel
    | Nudge Layout Int Float
    | Edge Layout Int Bool
    | Toggle Layout Int
    | Focused Layout
    | Noop



-- WHAT IS DRAWN


{-| Is the pane at this place folded away: can it fold, and has it no room?
-}
isFolded : Layout -> List Float -> Int -> Bool
isFolded layout sizes index =
    (List.drop index layout.collapsible |> List.head |> Maybe.withDefault False)
        && (List.drop index sizes |> List.head |> Maybe.withDefault 1) <= 1.0e-9


{-| The limits of the panes in fractions of the room, for panes of these sizes. A
folded pane is exactly nothing; one that can fold keeps a sliver while it is open.
-}
limitsFor : Layout -> State -> List Float -> List Limits
limitsFor layout state sizes =
    List.indexedMap
        (\index request ->
            if isFolded layout sizes index then
                { min = 0, max = 0 }

            else if List.drop index layout.collapsible |> List.head |> Maybe.withDefault False then
                let
                    limits =
                        Layout.resolve state.room request
                in
                { min = Basics.min limits.max (Basics.max limits.min sliver), max = limits.max }

            else
                Layout.resolve state.room request
        )
        layout.requests


{-| The sizes the panes have: the ones in the state for this many panes, brought
inside the limits.
-}
effective : Layout -> State -> List Float
effective layout state =
    let
        raw =
            Layout.fit (List.length layout.requests) state.sizes
    in
    Layout.settle (limitsFor layout state raw) raw


paneDomId : String -> Int -> String
paneDomId domId index =
    domId ++ "-pane-" ++ String.fromInt index


separatorDomId : String -> Int -> String
separatorDomId domId index =
    domId ++ "-separator-" ++ String.fromInt index



-- UPDATE


update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        Press layout separator device sample ->
            if separator < 0 || separator >= List.length layout.requests - 1 then
                ( state, Cmd.none )

            else
                let
                    serial =
                        state.serial + 1

                    position =
                        axis layout sample
                in
                ( { state
                    | serial = serial
                    , drag =
                        Just
                            { serial = serial
                            , separator = separator
                            , layout = layout
                            , device = device
                            , start = position
                            , current = position
                            , moved = False
                            , before = effective layout state
                            }
                  }
                , Cmd.batch
                    [ measure serial layout state.domId
                    , Internal.focus (separatorDomId state.domId separator) Noop
                    ]
                )

        Measured serial layout (Ok found) ->
            let
                total =
                    if layout.stacked then
                        found.element.height

                    else
                        found.element.width

                room =
                    total - gutter * toFloat (Basics.max 0 (List.length layout.requests - 1))

                known =
                    { state | room = Just (Basics.max 0 room) }
            in
            ( case known.drag of
                Just drag ->
                    if drag.serial == serial then
                        follow drag known

                    else
                        known

                Nothing ->
                    known
            , Cmd.none
            )

        Measured serial _ (Err _) ->
            -- the container is not on the page: there is nothing to drag
            ( case state.drag of
                Just drag ->
                    if drag.serial == serial then
                        { state | drag = Nothing }

                    else
                        state

                Nothing ->
                    state
            , Cmd.none
            )

        PointerMoved sample ->
            case state.drag of
                Just drag ->
                    if drag.device == Mouse && sample.buttons == 0 then
                        -- the button was let go where nobody saw it: the drag ends here
                        ( { state | drag = Nothing }, Cmd.none )

                    else
                        ( follow { drag | current = axis drag.layout sample, moved = True } state, Cmd.none )

                Nothing ->
                    ( state, Cmd.none )

        Release ->
            ( { state | drag = Nothing }, Cmd.none )

        Cancel ->
            case state.drag of
                Just drag ->
                    ( { state | drag = Nothing, sizes = drag.before }, Cmd.none )

                Nothing ->
                    ( state, Cmd.none )

        Nudge layout separator step ->
            let
                sizes =
                    effective layout state
            in
            ( { state | sizes = Layout.drag separator step (limitsFor layout state sizes) sizes }
            , measure 0 layout state.domId
            )

        Edge layout separator toLargest ->
            let
                sizes =
                    effective layout state
            in
            ( { state | sizes = Layout.edge separator toLargest (limitsFor layout state sizes) sizes }
            , measure 0 layout state.domId
            )

        Toggle layout separator ->
            ( toggle layout separator state, measure 0 layout state.domId )

        Focused layout ->
            ( state, measure 0 layout state.domId )

        Noop ->
            ( state, Cmd.none )


{-| The position of the pointer along the line the panes lie on.
-}
axis : Layout -> Sample -> Float
axis layout sample =
    if layout.stacked then
        sample.y

    else
        sample.x


{-| The drag is at `current`: the sizes are those of the start, moved by the
distance, as a fraction of the room. Nothing moves while the room is unknown, or
when there is none.
-}
follow : Drag -> State -> State
follow drag state =
    case state.room of
        Just room ->
            if room > 0 then
                { state
                    | drag = Just drag
                    , sizes =
                        Layout.drag drag.separator
                            ((drag.current - drag.start) / room)
                            (limitsFor drag.layout state drag.before)
                            drag.before
                }

            else
                { state | drag = Just drag }

        Nothing ->
            { state | drag = Just drag }


{-| Measures the container, one frame later. `serial` says which drag asked for it
(0 for none).
-}
measure : Int -> Layout -> String -> Cmd Msg
measure serial layout domId =
    Dom.getElement domId
        |> Task.attempt (Measured serial layout)


{-| Folds a pane away, or opens it again: the pane before the separator if it is
folded or can fold, else the pane after it.
-}
toggle : Layout -> Int -> State -> State
toggle layout separator state =
    let
        sizes =
            effective layout state

        first =
            separator

        second =
            separator + 1

        canFold index =
            (List.drop index layout.collapsible |> List.head |> Maybe.withDefault False)
                && not (isFolded layout sizes index)
    in
    if separator < 0 || second >= List.length sizes then
        state

    else if isFolded layout sizes first then
        open layout first second sizes state

    else if isFolded layout sizes second then
        open layout second first sizes state

    else if canFold first then
        fold first second sizes state

    else if canFold second then
        fold second first sizes state

    else
        state


fold : Int -> Int -> List Float -> State -> State
fold index into sizes state =
    let
        ( folded, size ) =
            Layout.collapse index into sizes
    in
    { state | sizes = folded, remembered = Dict.insert index size state.remembered }


{-| Gives the folded pane its room back from its neighbour: what it had, or when
that is not known (the layout was restored folded) its smallest size, or a fifth.
-}
open : Layout -> Int -> Int -> List Float -> State -> State
open layout index from sizes state =
    let
        limits =
            List.map (Layout.resolve state.room) layout.requests

        own =
            List.drop index limits |> List.head |> Maybe.withDefault { min = 0, max = 1 }

        wanted =
            Dict.get index state.remembered
                |> Maybe.withDefault (Basics.max own.min 0.2)

        opened =
            Layout.expand index from wanted limits sizes
    in
    if opened == sizes then
        state

    else
        { state | sizes = opened, remembered = Dict.remove index state.remembered }
