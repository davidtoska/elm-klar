module LeaveAddressTest exposing (suite)

{-| The part of Klar.LeaveGuard that answers the browser's Back and Forward buttons
(`Klar.Internal.Leave`), tested against a small model of the browser's history. The
real browser was measured in headless Chrome when the guard was built; this model has the same
rules (measured, see the top of `Klar.Internal.Leave`): the buttons report once with
the new address, `Push` and `Replace` report once, at once, with their address.
-}

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Internal.Leave as Leave exposing (Effect(..))
import Klar.LeaveGuard as LeaveGuard
import Test exposing (Test, describe, fuzz, test)
import Url


type alias State =
    Leave.State Int String


suite : Test
suite =
    describe "Klar.Internal.Leave (the address)"
        [ scenarioTests
        , unwatchedTests
        , historyTests
        ]


{-| What an address means to the application: its page, the first letter. "a" and
"a?sort" are two addresses of one page.
-}
pageOf : String -> String
pageOf address =
    String.left 1 address


{-| The address changed: `Leave.changed` with what the address and the address of the
page that is shown mean, as `LeaveGuard.onUrlChange` gives them.
-}
changed : String -> State -> ( State, List Effect, Bool )
changed address state =
    Leave.changed address (pageOf address) (Maybe.map pageOf state.shown) state


{-| A guard on this address, after the first change (it knows what the page means).
-}
watching : String -> State
watching address =
    let
        state =
            Leave.watch address Leave.init
    in
    { state | page = Just (pageOf address) }


dirtyAt : String -> State
dirtyAt address =
    Leave.setDirty 1 True (watching address)


scenarioTests : Test
scenarioTests =
    describe "one step at a time"
        [ test "clean: a new address is a page" <|
            \_ ->
                changed "b" (watching "a")
                    |> Expect.equal ( { dirty = [], held = Leave.Idle, shown = Just "b", away = Nothing, page = Just "b" }, [], True )
        , test "clean: the address of the page that is shown is ignored" <|
            \_ ->
                changed "a" (watching "a")
                    |> Expect.equal ( watching "a", [], False )
        , test "dirty: Back opens the question and leaves the page alone" <|
            \_ ->
                let
                    ( state, effects, entered ) =
                        changed "b" (dirtyAt "a")
                in
                Expect.equal
                    { shown = state.shown, away = state.away, held = state.held, effects = effects, entered = entered }
                    { shown = Just "a", away = Just "b", held = Leave.FromBrowser "b", effects = [ Open ], entered = False }
        , test "Stay pushes the address of the page that is shown" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( state, effects ) =
                        Leave.stay asked
                in
                Expect.equal { held = state.held, away = state.away, effects = effects, dirty = Leave.isDirty state } { held = Leave.Idle, away = Nothing, effects = [ Close, Push "a" ], dirty = True }
        , test "the report of that push is ignored" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( stayed, _ ) =
                        Leave.stay asked
                in
                changed "a" stayed
                    |> Expect.equal ( stayed, [], False )
        , test "Leave replaces the address with itself, gives the changes up and hands the target back, already there" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( left, effects, decision ) =
                        Leave.leave asked
                in
                Expect.equal ( Leave.isDirty left, effects, decision ) ( False, [ Close, Replace "b" ], Just ( "b", True ) )
        , test "the report of that replace enters the page" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( left, _, _ ) =
                        Leave.leave asked

                    ( entered, effects, isPage ) =
                        changed "b" left
                in
                Expect.equal ( entered.shown, effects, isPage ) ( Just "b", [], True )
        , test "a second Back while the question is open replaces the address asked for" <|
            \_ ->
                let
                    ( first, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( second, _, _ ) =
                        changed "c" first
                in
                Expect.equal ( second.held, second.away ) ( Leave.FromBrowser "c", Just "c" )
        , test "the same address twice does nothing the second time" <|
            \_ ->
                let
                    ( first, _, _ ) =
                        changed "b" (dirtyAt "a")
                in
                changed "b" first
                    |> Expect.equal ( first, [], False )
        , test "coming back to the shown page closes the question" <|
            \_ ->
                let
                    ( first, _, _ ) =
                        changed "b" (dirtyAt "a")
                in
                changed "a" first
                    |> Expect.equal ( { first | held = Leave.Idle, away = Nothing }, [ Close ], False )
        , test "a link asked while the browser question is open replaces it, and Stay still puts the address right" <|
            \_ ->
                let
                    ( first, _, _ ) =
                        changed "b" (dirtyAt "a")

                    asked =
                        Leave.request "c" first |> Maybe.withDefault first
                in
                Expect.equal ( Leave.held asked, Tuple.second (Leave.stay asked) ) ( Just "c", [ Close, Push "a" ] )
        , test "Leave on a link asked while the address was moved hands the link back" <|
            \_ ->
                let
                    ( first, _, _ ) =
                        changed "b" (dirtyAt "a")

                    asked =
                        Leave.request "c" first |> Maybe.withDefault first

                    ( _, effects, decision ) =
                        Leave.leave asked
                in
                Expect.equal ( effects, decision ) ( [ Close ], Just ( "c", False ) )
        , test "Save and leave puts the address right and hands the target back, the marks stay" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( saving, effects, decision ) =
                        Leave.save asked
                in
                Expect.equal ( effects, decision, Leave.isDirty saving ) ( [ Close, Push "a" ], Just "b", True )
        , test "dismiss forgets the question and leaves the address alone" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")
                in
                Leave.dismiss asked
                    |> Tuple.second
                    |> Expect.equal [ Close ]
        , test "the application cleaned up and went on by itself: the question is stale and closes" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    ( state, effects, isPage ) =
                        changed "c" (Leave.setDirty 1 False asked)
                in
                Expect.equal { held = state.held, shown = state.shown, effects = effects, isPage = isPage } { held = Leave.Idle, shown = Just "c", effects = [ Close ], isPage = True }
        , test "dirty: another address of the page that is shown asks nothing and keeps the page" <|
            \_ ->
                changed "a?sort" (dirtyAt "a")
                    |> Expect.equal ( { dirty = [ 1 ], held = Leave.Idle, shown = Just "a?sort", away = Nothing, page = Just "a" }, [], False )
        , test "clean: another address of the page that is shown enters it, as any address" <|
            \_ ->
                changed "a?sort" (watching "a")
                    |> (\( state, effects, entered ) -> Expect.equal ( state.shown, effects, entered ) ( Just "a?sort", [], True ))
        , test "a link to the page that is shown goes, even when something is dirty" <|
            \_ -> Leave.request "a" (dirtyAt "a?sort") |> Expect.equal Nothing
        , test "a link to another page still asks" <|
            \_ -> Leave.request "b" (dirtyAt "a") |> Maybe.map Leave.held |> Expect.equal (Just (Just "b"))
        , test "Back to another address of the page that is shown answers the open question" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")
                in
                changed "a?sort" asked
                    |> (\( state, effects, entered ) -> Expect.equal ( state.held, state.shown, ( effects, entered ) ) ( Leave.Idle, Just "a?sort", ( [ Close ], False ) ))
        , test "the page that is shown is learned from its address at the first change" <|
            \_ ->
                let
                    started =
                        Leave.watch "a" Leave.init |> Leave.setDirty 1 True

                    ( state, effects, entered ) =
                        changed "a?sort" started
                in
                Expect.equal ( state.page, effects, entered ) ( Just "a", [], False )
        , test "Leave to the page that is shown hands it back, so the work is reset" <|
            \_ ->
                let
                    ( asked, _, _ ) =
                        changed "b" (dirtyAt "a")

                    held =
                        Leave.request "c" asked |> Maybe.withDefault asked

                    ( _, _, decision ) =
                        Leave.leave held
                in
                Expect.equal decision (Just ( "c", False ))
        ]


unwatchedTests : Test
unwatchedTests =
    describe "a guard that does not know the address"
        [ test "every change is a page, even when dirty" <|
            \_ ->
                let
                    state =
                        Leave.setDirty 1 True Leave.init
                in
                changed "b" state
                    |> Expect.equal ( state, [], True )
        , test "the public onUrlChange on a guard made with init enters the page" <|
            \_ ->
                let
                    url =
                        Url.fromString "http://localhost/#/orders" |> Maybe.withDefault emptyUrl

                    ( _, _, entered ) =
                        LeaveGuard.init "leave"
                            |> LeaveGuard.setDirty 1 True
                            |> (\guard -> LeaveGuard.onUrlChange .path url guard)
                in
                Expect.equal (Just "/") entered
        ]


emptyUrl : Url.Url
emptyUrl =
    { protocol = Url.Http, host = "localhost", port_ = Nothing, path = "/", query = Nothing, fragment = Nothing }



-- A MODEL OF THE BROWSER


type alias Browser =
    { entries : List String
    , index : Int
    }


type alias World =
    { state : State
    , browser : Browser
    , reports : Int
    , undecided : Int
    }


type Event
    = Back
    | Forward
    | Click String
    | SetDirty Bool
    | Stay
    | LeaveButton
    | SaveButton


addresses : List String
addresses =
    [ "a", "b", "c", "d", "a?sort", "b?tab" ]


eventFuzzer : Fuzzer Event
eventFuzzer =
    let
        address =
            Fuzz.oneOfValues addresses
    in
    Fuzz.frequency
        [ ( 3, Fuzz.constant Back )
        , ( 2, Fuzz.constant Forward )
        , ( 3, Fuzz.map Click address )
        , ( 3, Fuzz.map SetDirty Fuzz.bool )
        , ( 2, Fuzz.constant Stay )
        , ( 2, Fuzz.constant LeaveButton )
        , ( 1, Fuzz.constant SaveButton )
        ]


start : World
start =
    { state = Leave.watch "a" Leave.init, browser = { entries = [ "a" ], index = 0 }, reports = 0, undecided = 0 }


current : Browser -> String
current browser =
    browser.entries |> List.drop browser.index |> List.head |> Maybe.withDefault ""


push : String -> Browser -> Browser
push address browser =
    { entries = List.take (browser.index + 1) browser.entries ++ [ address ], index = browser.index + 1 }


replace : String -> Browser -> Browser
replace address browser =
    { browser
        | entries =
            List.indexedMap
                (\i entry ->
                    if i == browser.index then
                        address

                    else
                        entry
                )
                browser.entries
    }


{-| The browser reports an address; the guard answers; its effects are carried out
(each of them reports again, at once, as in the real browser).
-}
report : World -> World
report world =
    let
        address =
            current world.browser

        ( state, effects, _ ) =
            changed address world.state
    in
    List.foldl run { world | state = state, reports = world.reports + 1 } effects


run : Effect -> World -> World
run effect world =
    case effect of
        Open ->
            world

        Close ->
            world

        Push address ->
            report { world | browser = push address world.browser }

        Replace address ->
            report { world | browser = replace address world.browser }


{-| The application: it pushes the address of a target it was handed back.
-}
goTo : String -> World -> World
goTo address world =
    report { world | browser = push address world.browser }


step : Event -> World -> World
step event world =
    let
        fresh =
            { world | reports = 0 }
    in
    case event of
        Back ->
            if fresh.browser.index > 0 then
                report { fresh | browser = { entries = fresh.browser.entries, index = fresh.browser.index - 1 } }

            else
                fresh

        Forward ->
            if fresh.browser.index < List.length fresh.browser.entries - 1 then
                report { fresh | browser = { entries = fresh.browser.entries, index = fresh.browser.index + 1 } }

            else
                fresh

        Click address ->
            case Leave.request (pageOf address) fresh.state of
                Nothing ->
                    goTo address fresh

                Just asked ->
                    { fresh | state = asked }

        SetDirty flag ->
            { fresh | state = Leave.setDirty 1 flag fresh.state }

        Stay ->
            let
                ( state, effects ) =
                    Leave.stay fresh.state
            in
            List.foldl run { fresh | state = state } effects

        LeaveButton ->
            let
                ( state, effects, decision ) =
                    Leave.leave fresh.state

                -- every Leave of an open question hands the target back
                undecided =
                    if Leave.isOpen fresh.state && decision == Nothing then
                        fresh.undecided + 1

                    else
                        fresh.undecided
            in
            List.foldl run { fresh | state = state, undecided = undecided } effects
                |> (\after ->
                        case decision of
                            Just ( target, False ) ->
                                goTo target after

                            _ ->
                                after
                   )

        SaveButton ->
            let
                ( state, effects, decision ) =
                    Leave.save fresh.state
            in
            List.foldl run { fresh | state = state } effects
                |> (\after ->
                        case decision of
                            Just address ->
                                -- the save succeeded: the marks go, then the application goes on
                                goTo address { after | state = Leave.setDirty 1 False after.state }

                            Nothing ->
                                after
                   )


showEvent : Event -> String
showEvent event =
    case event of
        Back ->
            "Back"

        Forward ->
            "Forward"

        Click address ->
            "Click " ++ address

        SetDirty flag ->
            "SetDirty "
                ++ (if flag then
                        "True"

                    else
                        "False"
                   )

        Stay ->
            "Stay"

        LeaveButton ->
            "Leave"

        SaveButton ->
            "Save"


{-| What must hold after every event.
-}
invariants : World -> List String
invariants world =
    let
        address =
            current world.browser

        shown =
            Maybe.withDefault "" world.state.shown
    in
    List.filterMap identity
        [ if world.undecided > 0 then
            Just "a Leave gave no decision, so the work given up cannot be reset"

          else
            Nothing
        , if world.reports > 4 then
            Just ("a loop: " ++ String.fromInt world.reports ++ " reports for one event")

          else
            Nothing
        , if world.state.held == Leave.Idle && address /= shown then
            Just ("no question is open, but the address bar (" ++ address ++ ") is not the page (" ++ shown ++ ")")

          else
            Nothing
        , case ( world.state.held, world.state.away ) of
            ( Leave.FromBrowser _, Just away ) ->
                if away /= address || away == shown then
                    Just "the question is about an address that the bar is not at"

                else
                    Nothing

            ( Leave.FromBrowser _, Nothing ) ->
                Just "a question about the browser buttons without an address"

            _ ->
                Nothing
        , if not (Leave.isDirty world.state) && world.state.held == Leave.Idle && address /= shown then
            Just "clean, but the page is not the address"

          else
            Nothing
        ]


historyTests : Test
historyTests =
    describe "against a model of the browser"
        [ fuzz (Fuzz.listOfLengthBetween 1 60 eventFuzzer) "no loop, and the address bar and the page agree whenever no question is open" <|
            \events ->
                let
                    ( _, problems ) =
                        List.foldl
                            (\event ( world, found ) ->
                                let
                                    next =
                                        step event world
                                in
                                ( next, found ++ List.map (\problem -> problem ++ " after " ++ showEvent event) (invariants next) )
                            )
                            ( start, [] )
                            events
                in
                Expect.equal [] problems
        ]
