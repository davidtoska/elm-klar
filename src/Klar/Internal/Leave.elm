module Klar.Internal.Leave exposing
    ( Effect(..)
    , Held(..)
    , State
    , changed
    , dirtySources
    , dismiss
    , held
    , init
    , isDirty
    , isOpen
    , leave
    , request
    , save
    , setDirty
    , stay
    , watch
    )

{-| The pure state machine of `Klar.LeaveGuard`: which sources are dirty, which
request waits for an answer, and where the address bar is compared to the page
that is shown. It knows no `Cmd`, no dialog and no key: every transition returns
the effects the guard has to carry out, as data, so that all of it can be tested.

What the browser really does (Elm 0.19.3, measured in headless Chrome):

  - The Back and Forward buttons call `onUrlChange` once, with the new address.
  - `Nav.pushUrl` and `Nav.replaceUrl` call it once, at once, with the new address.
  - `Nav.back` and `Nav.forward` call it twice: at once with the address being
    LEFT (the move has not happened), and later, from the browser, with the new one.

So an application cannot take the page back to the address it showed by moving in
the history (it cannot tell Back from Forward, and the report of the move itself
looks like a new request: that was the endless loop). This machine never moves in
the history. When the browser buttons moved the address while something is dirty,
the page stays as it is and the address is `away`; the question is asked with the
address bar already at the place the user wanted. "Leave" then only has to tell the
application that this address is now the page (`Replace`: the same address, no new
entry). "Stay" pushes the address of the page that is shown (`Push`), which is the
one move that does not need to know the direction.

-}


type alias State source target =
    { dirty : List source
    , held : Held target
    , shown : Maybe String
    , away : Maybe String
    }


{-| What waits for an answer: nothing, a request from the application (a link, a
call), or an address the browser buttons moved to.
-}
type Held target
    = Idle
    | Requested target
    | FromBrowser target


{-| What the guard has to do on behalf of the machine.
-}
type Effect
    = Open
    | Close
    | Push String
    | Replace String


init : State source target
init =
    { dirty = [], held = Idle, shown = Nothing, away = Nothing }


{-| The address the page shows right now.
-}
watch : String -> State source target -> State source target
watch address state =
    { state | shown = Just address }


setDirty : source -> Bool -> State source target -> State source target
setDirty source dirty state =
    { state
        | dirty =
            if dirty then
                if List.member source state.dirty then
                    state.dirty

                else
                    state.dirty ++ [ source ]

            else
                List.filter (\other -> other /= source) state.dirty
    }


isDirty : State source target -> Bool
isDirty state =
    not (List.isEmpty state.dirty)


dirtySources : State source target -> List source
dirtySources state =
    state.dirty


held : State source target -> Maybe target
held state =
    case state.held of
        Idle ->
            Nothing

        Requested target ->
            Just target

        FromBrowser target ->
            Just target


isOpen : State source target -> Bool
isOpen state =
    state.held /= Idle


{-| Asks. `Nothing` means: nothing is dirty and no question is open, go. Otherwise
the new state, and the question is open.
-}
request : target -> State source target -> Maybe (State source target)
request target state =
    if List.isEmpty state.dirty && state.held == Idle then
        Nothing

    else
        Just { state | held = Requested target }


{-| The question is stale: forget it and close the dialog. The address is not
touched, the application is going somewhere by itself.
-}
dismiss : State source target -> ( State source target, List Effect )
dismiss state =
    if state.held == Idle then
        ( state, [] )

    else
        ( { state | held = Idle, away = Nothing }, [ Close ] )


{-| The address changed (`onUrlChange`). The result says whether the page may
enter this address (`True`), and what the guard has to do. `target` is what the
address means to the application; it is only used when the question is asked.
-}
changed : String -> target -> State source target -> ( State source target, List Effect, Bool )
changed address target state =
    if state.shown == Nothing then
        -- Not watching the address: nothing to compare with, every change is a page.
        ( state, [], True )

    else if state.shown == Just address then
        -- The page the user is on. Either a report of our own move (Push, Replace),
        -- or the user came back to it with the buttons while the question was open.
        case ( state.away, state.held ) of
            ( Just _, FromBrowser _ ) ->
                ( { state | held = Idle, away = Nothing }, [ Close ], False )

            ( Just _, _ ) ->
                ( { state | away = Nothing }, [], False )

            ( Nothing, _ ) ->
                ( state, [], False )

    else if List.isEmpty state.dirty then
        ( { state | shown = Just address, away = Nothing, held = Idle }
        , if state.held == Idle then
            []

          else
            [ Close ]
        , True
        )

    else if state.away == Just address && isFromBrowser state.held then
        -- The same report twice.
        ( state, [], False )

    else
        ( { state | away = Just address, held = FromBrowser target }, [ Open ], False )


isFromBrowser : Held target -> Bool
isFromBrowser held_ =
    case held_ of
        FromBrowser _ ->
            True

        _ ->
            False


{-| "Stay": forget the question. If the browser buttons moved the address, push
the address of the page that is shown.
-}
stay : State source target -> ( State source target, List Effect )
stay state =
    if state.held == Idle then
        ( state, [] )

    else
        ( { state | held = Idle, away = Nothing }, Close :: restore state )


restore : State source target -> List Effect
restore state =
    case ( state.away, state.shown ) of
        ( Just _, Just address ) ->
            [ Push address ]

        _ ->
            []


{-| "Leave": the changes are given up. A request is handed back to the
application (`Just target`). An address the browser moved to needs nothing from
it: the machine replaces the address with itself, which makes the application's
`onUrlChange` see the new page.
-}
leave : State source target -> ( State source target, List Effect, Maybe target )
leave state =
    let
        clean =
            { state | held = Idle, dirty = [] }
    in
    case ( state.held, state.away ) of
        ( Requested target, _ ) ->
            ( { clean | away = Nothing }, [ Close ], Just target )

        ( FromBrowser _, Just address ) ->
            ( { clean | away = Nothing }, [ Close, Replace address ], Nothing )

        ( FromBrowser target, Nothing ) ->
            ( clean, [ Close ], Just target )

        ( Idle, _ ) ->
            ( state, [], Nothing )


{-| "Save and leave": the dirty marks stay. The application saves, then goes to the
target. If the address was moved, it is put back first, so that the page and the
address agree while the save is on its way.
-}
save : State source target -> ( State source target, List Effect, Maybe target )
save state =
    case state.held of
        Idle ->
            ( state, [], Nothing )

        Requested target ->
            ( { state | held = Idle, away = Nothing }, Close :: restore state, Just target )

        FromBrowser target ->
            ( { state | held = Idle, away = Nothing }, Close :: restore state, Just target )
