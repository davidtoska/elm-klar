module LeaveGuardTest exposing (suite)

{-| Klar.LeaveGuard: the state machine (a request is proceeded with when everything
is clean, held when anything is dirty, and only the user's answer releases it),
the dialog, and a long random sequence of everything checked against a plain model.
-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Locale as Locale
import Klar.Overlay as Overlay
import Support.FlowHtml as H
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


{-| The sources are form numbers, the targets are page numbers: two plain types.
-}
type alias Guard =
    LeaveGuard.Guard Int Int


suite : Test
suite =
    describe "Klar.LeaveGuard"
        [ dirtyTests
        , requestTests
        , answerTests
        , heldTests
        , dismissQuestionTests
        , dialogTests
        , dismissTests
        , textTests
        , sequenceTests
        ]


fresh : Guard
fresh =
    LeaveGuard.init "leave"


dirtyWith : List Int -> Guard
dirtyWith sources =
    List.foldl (\source guard -> LeaveGuard.setDirty source True guard) fresh sources


{-| The guard after a request, whatever the answer was.
-}
asked : Int -> Guard -> Guard
asked target guard =
    case LeaveGuard.request target guard of
        Proceed _ ->
            guard

        Hold next _ ->
            next


{-| The dialog as the application renders it. The messages stay what the guard makes
them, so the test can hand them to `update` as the application would.
-}
dialog : List (LeaveGuard.Attribute LeaveGuard.Msg) -> Guard -> Html LeaveGuard.Msg
dialog attributes guard =
    Overlay.host { attributes = [], page = [], overlays = [ LeaveGuard.view identity attributes guard ] }


{-| The message that a click on the element sends.
-}
clicked : List Selector -> Guard -> Result String LeaveGuard.Msg
clicked selectors guard =
    H.sends selectors Event.click (dialog [ LeaveGuard.saveAndLeave ] guard)


{-| Press a button of the dialog: the new guard and the decision, or the same guard
and no decision when there is no such button (the dialog is closed).
-}
press : String -> Guard -> ( Guard, Maybe ( Int, Bool ) )
press name guard =
    case clicked [ Selector.id ("leave-" ++ name) ] guard of
        Ok msg ->
            let
                ( next, _, decision ) =
                    LeaveGuard.update msg guard
            in
            ( next, decided decision )

        Err _ ->
            ( guard, Nothing )


{-| A decision as the two things one can ask it: where to go and whether to save
first.
-}
decided : Maybe (LeaveGuard.Decision Int) -> Maybe ( Int, Bool )
decided =
    Maybe.map (\decision -> ( LeaveGuard.destination decision, LeaveGuard.savesFirst decision ))



-- DIRTY SOURCES


dirtyTests : Test
dirtyTests =
    describe "dirty sources"
        [ test "a new guard is clean, closed and holds nothing" <|
            \_ ->
                Expect.all
                    [ \g -> Expect.equal False (LeaveGuard.isDirty g)
                    , \g -> Expect.equal [] (LeaveGuard.dirtySources g)
                    , \g -> Expect.equal False (LeaveGuard.isOpen g)
                    , \g -> Expect.equal Nothing (LeaveGuard.pending g)
                    ]
                    fresh
        , test "a source that was set dirty is dirty" <|
            \_ ->
                Expect.all
                    [ \g -> Expect.equal True (LeaveGuard.isDirty g)
                    , \g -> Expect.equal [ 3 ] (LeaveGuard.dirtySources g)
                    ]
                    (LeaveGuard.setDirty 3 True fresh)
        , test "saying it twice changes nothing" <|
            \_ -> Expect.equal [ 3 ] (LeaveGuard.dirtySources (LeaveGuard.setDirty 3 True (LeaveGuard.setDirty 3 True fresh)))
        , test "the sources are listed in the order they became dirty" <|
            \_ -> Expect.equal [ 2, 0, 1 ] (LeaveGuard.dirtySources (dirtyWith [ 2, 0, 1 ]))
        , test "a source that is clean again no longer counts" <|
            \_ -> Expect.equal False (LeaveGuard.isDirty (LeaveGuard.setDirty 3 False (LeaveGuard.setDirty 3 True fresh)))
        , test "a source that was never dirty can be set clean" <|
            \_ -> Expect.equal fresh (LeaveGuard.setDirty 7 False fresh)
        , test "the guard is clean only when every source is clean" <|
            \_ ->
                let
                    two =
                        dirtyWith [ 1, 2 ]
                in
                Expect.all
                    [ \g -> Expect.equal True (LeaveGuard.isDirty g)
                    , \g -> Expect.equal True (LeaveGuard.isDirty (LeaveGuard.setDirty 1 False g))
                    , \g -> Expect.equal [ 2 ] (LeaveGuard.dirtySources (LeaveGuard.setDirty 1 False g))
                    , \g -> Expect.equal False (LeaveGuard.isDirty (LeaveGuard.setDirty 2 False (LeaveGuard.setDirty 1 False g)))
                    ]
                    two
        , test "the sources can be any type without functions" <|
            \_ ->
                let
                    start_ : LeaveGuard.Guard { form : String, row : Int } ()
                    start_ =
                        LeaveGuard.init "x"

                    guard =
                        start_
                            |> LeaveGuard.setDirty { form = "order", row = 1 } True
                            |> LeaveGuard.setDirty { form = "order", row = 1 } True
                            |> LeaveGuard.setDirty { form = "order", row = 2 } True
                in
                Expect.equal 2 (List.length (LeaveGuard.dirtySources guard))
        ]



-- REQUESTS


requestTests : Test
requestTests =
    describe "requests"
        [ test "a clean guard lets the request through with the value it was given" <|
            \_ ->
                case LeaveGuard.request 5 fresh of
                    Proceed target ->
                        Expect.equal 5 target

                    Hold _ _ ->
                        Expect.fail "a clean guard held the request"
        , test "a clean guard stays as it was" <|
            \_ ->
                case LeaveGuard.request 5 fresh of
                    Proceed _ ->
                        Expect.pass

                    Hold next _ ->
                        Expect.equal fresh next
        , test "a dirty guard holds it and opens the dialog" <|
            \_ ->
                case LeaveGuard.request 5 (dirtyWith [ 1 ]) of
                    Proceed _ ->
                        Expect.fail "a dirty guard let the request through"

                    Hold next cmd ->
                        Expect.all
                            [ \_ -> Expect.equal (Just 5) (LeaveGuard.pending next)
                            , \_ -> Expect.equal True (LeaveGuard.isOpen next)
                            , \_ -> Expect.equal True (LeaveGuard.isDirty next)
                            , \_ -> Expect.notEqual Cmd.none cmd
                            ]
                            ()
        , test "the held value can be anything, here a record" <|
            \_ ->
                let
                    guard : LeaveGuard.Guard Int { path : String, id : Int }
                    guard =
                        LeaveGuard.init "x" |> LeaveGuard.setDirty 1 True
                in
                case LeaveGuard.request { path = "orders", id = 7 } guard of
                    Hold next _ ->
                        Expect.equal (Just { path = "orders", id = 7 }) (LeaveGuard.pending next)

                    Proceed _ ->
                        Expect.fail "held expected"
        , test "after the changes are saved the request goes through again" <|
            \_ ->
                case LeaveGuard.request 5 (LeaveGuard.setDirty 1 False (dirtyWith [ 1 ])) of
                    Proceed target ->
                        Expect.equal 5 target

                    Hold _ _ ->
                        Expect.fail "held although everything is clean"
        ]



-- THE ANSWERS


answerTests : Test
answerTests =
    let
        held =
            asked 5 (dirtyWith [ 1, 2 ])
    in
    describe "the answers"
        [ test "Leave hands the held value back and the guard forgets what was dirty" <|
            \_ ->
                press "leave" held
                    |> Expect.all
                        [ \( _, decision ) -> Expect.equal (Just ( 5, False )) decision
                        , \( next, _ ) -> Expect.equal False (LeaveGuard.isDirty next)
                        , \( next, _ ) -> Expect.equal False (LeaveGuard.isOpen next)
                        , \( next, _ ) -> Expect.equal Nothing (LeaveGuard.pending next)
                        ]
        , test "after Leave the next request goes through" <|
            \_ ->
                case LeaveGuard.request 9 (Tuple.first (press "leave" held)) of
                    Proceed target ->
                        Expect.equal 9 target

                    Hold _ _ ->
                        Expect.fail "held after leaving"
        , test "Stay releases nothing, closes the dialog and keeps the dirty marks" <|
            \_ ->
                press "stay" held
                    |> Expect.all
                        [ \( _, decision ) -> Expect.equal Nothing decision
                        , \( next, _ ) -> Expect.equal [ 1, 2 ] (LeaveGuard.dirtySources next)
                        , \( next, _ ) -> Expect.equal False (LeaveGuard.isOpen next)
                        , \( next, _ ) -> Expect.equal Nothing (LeaveGuard.pending next)
                        ]
        , test "after Stay the next request is held again" <|
            \_ ->
                case LeaveGuard.request 6 (Tuple.first (press "stay" held)) of
                    Hold next _ ->
                        Expect.equal (Just 6) (LeaveGuard.pending next)

                    Proceed _ ->
                        Expect.fail "let through although dirty"
        , test "Save and leave hands the value back, keeps the dirty marks and closes" <|
            \_ ->
                press "save" held
                    |> Expect.all
                        [ \( _, decision ) -> Expect.equal (Just ( 5, True )) decision
                        , \( next, _ ) -> Expect.equal [ 1, 2 ] (LeaveGuard.dirtySources next)
                        , \( next, _ ) -> Expect.equal False (LeaveGuard.isOpen next)
                        , \( next, _ ) -> Expect.equal Nothing (LeaveGuard.pending next)
                        ]
        , test "a button pressed twice answers once" <|
            \_ ->
                case clicked [ Selector.id "leave-leave" ] held of
                    Ok msg ->
                        let
                            ( once, _, first ) =
                                LeaveGuard.update msg held

                            ( twice, _, second ) =
                                LeaveGuard.update msg once
                        in
                        Expect.all
                            [ \_ -> Expect.equal (Just ( 5, False )) (decided first)
                            , \_ -> Expect.equal Nothing (decided second)
                            , \_ -> Expect.equal once twice
                            ]
                            ()

                    Err problem ->
                        Expect.fail problem
        , test "an answer after the question was answered by another button settles nothing" <|
            \_ ->
                case ( clicked [ Selector.id "leave-stay" ] held, clicked [ Selector.id "leave-leave" ] held ) of
                    ( Ok stay, Ok leave ) ->
                        let
                            ( afterStay, _, _ ) =
                                LeaveGuard.update stay held

                            ( _, _, decision ) =
                                LeaveGuard.update leave afterStay
                        in
                        Expect.equal Nothing (decided decision)

                    _ ->
                        Expect.fail "the buttons are missing"
        ]



-- A QUESTION THAT IS ALREADY OPEN


heldTests : Test
heldTests =
    describe "a request while the question is open"
        [ test "replaces the held value: the latest thing the user asked for is what Leave does" <|
            \_ ->
                let
                    twice =
                        dirtyWith [ 1 ] |> asked 5 |> asked 8
                in
                Expect.all
                    [ \g -> Expect.equal (Just 8) (LeaveGuard.pending g)
                    , \g -> Expect.equal (Just ( 8, False )) (Tuple.second (press "leave" g))
                    ]
                    twice
        , test "is held even when everything became clean in the meantime" <|
            \_ ->
                let
                    cleanNow =
                        dirtyWith [ 1 ] |> asked 5 |> LeaveGuard.setDirty 1 False
                in
                case LeaveGuard.request 8 cleanNow of
                    Hold next _ ->
                        Expect.equal (Just 8) (LeaveGuard.pending next)

                    Proceed _ ->
                        Expect.fail "released while a question was open"
        , test "the held value survives changes to the dirty marks" <|
            \_ ->
                let
                    g =
                        dirtyWith [ 1 ] |> asked 5 |> LeaveGuard.setDirty 2 True |> LeaveGuard.setDirty 1 False |> LeaveGuard.setDirty 2 False
                in
                Expect.all
                    [ \x -> Expect.equal (Just 5) (LeaveGuard.pending x)
                    , \x -> Expect.equal True (LeaveGuard.isOpen x)
                    ]
                    g
        , test "and Leave still hands it over after everything became clean" <|
            \_ ->
                press "leave" (dirtyWith [ 1 ] |> asked 5 |> LeaveGuard.setDirty 1 False)
                    |> Tuple.second
                    |> Expect.equal (Just ( 5, False ))
        ]



-- WITHDRAWING THE QUESTION


dismissQuestionTests : Test
dismissQuestionTests =
    let
        held =
            asked 5 (dirtyWith [ 1, 2 ])
    in
    describe "dismiss"
        [ test "closes the question, forgets the held value and keeps the dirty marks" <|
            \_ ->
                LeaveGuard.dismiss held
                    |> Tuple.first
                    |> Expect.all
                        [ \g -> Expect.equal False (LeaveGuard.isOpen g)
                        , \g -> Expect.equal Nothing (LeaveGuard.pending g)
                        , \g -> Expect.equal [ 1, 2 ] (LeaveGuard.dirtySources g)
                        ]
        , test "gives a command that moves focus back, like closing the dialog does" <|
            \_ -> Expect.notEqual Cmd.none (Tuple.second (LeaveGuard.dismiss held))
        , test "with no question open it changes nothing and has nothing to do" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal (dirtyWith [ 1 ]) (Tuple.first (LeaveGuard.dismiss (dirtyWith [ 1 ])))
                    , \_ -> Expect.equal Cmd.none (Tuple.second (LeaveGuard.dismiss fresh))
                    , \_ -> Expect.equal fresh (Tuple.first (LeaveGuard.dismiss fresh))
                    ]
                    ()
        , test "after it Leave and the other buttons are gone: there is nothing to answer" <|
            \_ ->
                Expect.all
                    [ \g -> Expect.equal ( g, Nothing ) (press "leave" g)
                    , \g -> Expect.equal ( g, Nothing ) (press "stay" g)
                    ]
                    (Tuple.first (LeaveGuard.dismiss held))
        , test "a button pressed after the question was withdrawn settles nothing" <|
            \_ ->
                case clicked [ Selector.id "leave-leave" ] held of
                    Ok leave ->
                        let
                            ( withdrawn, _ ) =
                                LeaveGuard.dismiss held

                            ( _, _, decision ) =
                                LeaveGuard.update leave withdrawn
                        in
                        Expect.equal Nothing (decided decision)

                    Err problem ->
                        Expect.fail problem
        , test "the stale question of a save that came back: the application went to A, a click on B was held" <|
            \_ ->
                let
                    -- "Save and leave" to page 1: the dialog closes, the save is on its way
                    saving =
                        press "save" (asked 1 (dirtyWith [ 1 ]))

                    -- the user clicks a link to page 2 while it saves
                    questioned =
                        asked 2 (Tuple.first saving)

                    -- the save returned: the application goes to page 1 and says so
                    afterSave =
                        questioned |> LeaveGuard.setDirty 1 False |> LeaveGuard.dismiss |> Tuple.first
                in
                Expect.all
                    [ \_ -> Expect.equal (Just ( 1, True )) (Tuple.second saving)
                    , \_ -> Expect.equal (Just 2) (LeaveGuard.pending questioned)
                    , \_ -> Expect.equal Nothing (LeaveGuard.pending afterSave)
                    , \_ -> Expect.equal False (LeaveGuard.isOpen afterSave)
                    , \_ -> Expect.equal ( afterSave, Nothing ) (press "leave" afterSave)
                    , \_ ->
                        case LeaveGuard.request 3 afterSave of
                            Proceed target ->
                                Expect.equal 3 target

                            Hold _ _ ->
                                Expect.fail "still asking after everything was saved and the question withdrawn"
                    ]
                    ()
        ]



-- THE DIALOG


dialogTests : Test
dialogTests =
    let
        open =
            asked 5 (dirtyWith [ 1 ])

        footerButtons attributes guard =
            dialog attributes guard
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-modal__footer-actions" ]
                |> Query.findAll [ Selector.tag "button" ]
    in
    describe "the dialog"
        [ test "draws nothing while no question is open" <|
            \_ -> dialog [] (dirtyWith [ 1 ]) |> H.none [ H.attr "role" "dialog" ]
        , test "is a modal dialog named by the question when it is open" <|
            \_ ->
                dialog [] open
                    |> Expect.all
                        [ H.inside [ H.attr "role" "dialog" ] [ H.attr "aria-modal" "true", Selector.id "leave", H.attr "aria-labelledby" "leave-title" ]
                        , H.inside [ Selector.id "leave-title" ] [ Selector.text "Leave without saving?" ]
                        ]
        , test "the sentence describes the dialog and the id it names exists" <|
            \_ ->
                dialog [] open
                    |> Expect.all
                        [ H.inside [ Selector.id "leave" ] [ H.attr "aria-describedby" "leave-message" ]
                        , H.inside [ Selector.id "leave-message" ] [ Selector.text "You have unsaved changes. If you leave now, they are lost." ]
                        ]
        , test "'Leave' first and 'Stay' last" <|
            \_ ->
                let
                    buttons =
                        footerButtons [] open
                in
                Expect.all
                    [ \_ -> buttons |> Query.count (Expect.equal 2)
                    , \_ -> buttons |> Query.index 0 |> Query.has [ Selector.id "leave-leave", Selector.text "Leave" ]
                    , \_ -> buttons |> Query.index 1 |> Query.has [ Selector.id "leave-stay", Selector.text "Stay" ]
                    ]
                    ()
        , test "'Stay' is the primary button and 'Leave' is the dangerous one" <|
            \_ ->
                dialog [] open
                    |> Expect.all
                        [ H.inside [ Selector.id "leave-stay" ] [ Selector.class "klar-button--primary" ]
                        , H.inside [ Selector.id "leave-leave" ] [ Selector.class "klar-button--tone-danger", Selector.class "klar-button--secondary" ]
                        ]
        , test "'Save and leave' is the third button and the primary one, when asked for" <|
            \_ ->
                let
                    buttons =
                        footerButtons [ LeaveGuard.saveAndLeave ] open
                in
                Expect.all
                    [ \_ -> buttons |> Query.count (Expect.equal 3)
                    , \_ -> buttons |> Query.index 2 |> Query.has [ Selector.id "leave-save", Selector.text "Save and leave", Selector.class "klar-button--primary" ]
                    , \_ -> dialog [ LeaveGuard.saveAndLeave ] open |> H.inside [ Selector.id "leave-stay" ] [ Selector.class "klar-button--secondary" ]
                    ]
                    ()
        , test "there is no 'Save and leave' unless it is asked for" <|
            \_ -> dialog [] open |> H.none [ Selector.id "leave-save" ]
        , test "the buttons are real buttons that do not submit a form" <|
            \_ ->
                dialog [ LeaveGuard.saveAndLeave ] open
                    |> Expect.all
                        [ H.inside [ Selector.id "leave-leave" ] [ Selector.attribute (Attr.type_ "button") ]
                        , H.inside [ Selector.id "leave-stay" ] [ Selector.attribute (Attr.type_ "button") ]
                        , H.inside [ Selector.id "leave-save" ] [ Selector.attribute (Attr.type_ "button") ]
                        ]
        , test "the title and the sentence can be replaced" <|
            \_ ->
                dialog [ LeaveGuard.title "Discard the order?", LeaveGuard.message "Order 1042 is not saved." ] open
                    |> Expect.all
                        [ H.inside [ Selector.id "leave-title" ] [ Selector.text "Discard the order?" ]
                        , H.inside [ Selector.id "leave-message" ] [ Selector.text "Order 1042 is not saved." ]
                        ]
        ]



-- DISMISSING


dismissTests : Test
dismissTests =
    let
        open =
            asked 5 (dirtyWith [ 1 ])

        keyDown targetId key =
            Event.custom "keydown"
                (Encode.object
                    [ ( "key", Encode.string key )
                    , ( "ctrlKey", Encode.bool False )
                    , ( "metaKey", Encode.bool False )
                    , ( "altKey", Encode.bool False )
                    , ( "shiftKey", Encode.bool False )
                    , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
                    ]
                )

        resolved selectors event =
            case H.sends selectors event (dialog [] open) of
                Ok msg ->
                    let
                        ( next, _, decision ) =
                            LeaveGuard.update msg open
                    in
                    Expect.all
                        [ \_ -> Expect.equal Nothing (decided decision)
                        , \_ -> Expect.equal False (LeaveGuard.isOpen next)
                        , \_ -> Expect.equal Nothing (LeaveGuard.pending next)
                        , \_ -> Expect.equal True (LeaveGuard.isDirty next)
                        ]
                        ()

                Err problem ->
                    Expect.fail problem
    in
    describe "closing the dialog without answering means 'Stay'"
        [ test "Escape" <|
            \_ -> resolved [ Selector.id "leave" ] (keyDown "leave" "Escape")
        , test "a click on the backdrop" <|
            \_ -> resolved [ Selector.class "klar-modal__backdrop" ] Event.click
        , test "the close button" <|
            \_ -> resolved [ Selector.id "leave-close" ] Event.click
        , test "'Stay'" <|
            \_ -> resolved [ Selector.id "leave-stay" ] Event.click
        ]



-- TEXT


textTests : Test
textTests =
    let
        open =
            asked 5 (dirtyWith [ 1 ])
    in
    describe "in Norwegian"
        [ test "the question and the sentence" <|
            \_ ->
                dialog [ LeaveGuard.locale Locale.nb ] open
                    |> Expect.all
                        [ H.inside [ Selector.id "leave-title" ] [ Selector.text "Forlate siden uten å lagre?" ]
                        , H.inside [ Selector.id "leave-message" ] [ Selector.text "Du har ulagrede endringer. Forlater du siden nå, går de tapt." ]
                        ]
        , test "the buttons" <|
            \_ ->
                dialog [ LeaveGuard.locale Locale.nb, LeaveGuard.saveAndLeave ] open
                    |> Expect.all
                        [ H.inside [ Selector.id "leave-leave" ] [ Selector.text "Forlat" ]
                        , H.inside [ Selector.id "leave-stay" ] [ Selector.text "Bli her" ]
                        , H.inside [ Selector.id "leave-save" ] [ Selector.text "Lagre og forlat" ]
                        ]
        , test "the close button" <|
            \_ -> dialog [ LeaveGuard.locale Locale.nb ] open |> H.inside [ Selector.id "leave-close" ] [ H.attr "aria-label" "Lukk" ]
        ]



-- RANDOM SEQUENCES
--
-- A plain model of the guard (a list of dirty sources and the held value) is run
-- next to the real one through a long random sequence of everything a user and an
-- application can do. After every step the two must agree, and no request may
-- ever get past the guard while something was dirty.


type Op
    = SetDirty Int Bool
    | Request Int
    | PressLeave
    | PressStay
    | PressSave
    | Dismiss


opFuzzer : Fuzzer Op
opFuzzer =
    Fuzz.oneOf
        [ Fuzz.map2 SetDirty (Fuzz.intRange 0 2) Fuzz.bool
        , Fuzz.map Request (Fuzz.intRange 0 5)
        , Fuzz.constant PressLeave
        , Fuzz.constant PressStay
        , Fuzz.constant PressSave
        , Fuzz.constant Dismiss
        ]


type alias Model =
    { dirty : List Int
    , held : Maybe Int
    }


{-| What a sequence is checked on: the model and the guard side by side, and the first
disagreement.
-}
type alias Run =
    { model : Model
    , guard : Guard
    , problem : Maybe String
    }


start : Run
start =
    { model = { dirty = [], held = Nothing }, guard = fresh, problem = Nothing }


step : Op -> Run -> Run
step op run =
    case run.problem of
        Just _ ->
            run

        Nothing ->
            let
                model =
                    run.model

                afterwards =
                    case op of
                        SetDirty source flag ->
                            { run
                                | guard = LeaveGuard.setDirty source flag run.guard
                                , model =
                                    { model
                                        | dirty =
                                            if flag then
                                                if List.member source model.dirty then
                                                    model.dirty

                                                else
                                                    model.dirty ++ [ source ]

                                            else
                                                List.filter (\other -> other /= source) model.dirty
                                    }
                            }

                        Request target ->
                            case LeaveGuard.request target run.guard of
                                Proceed value ->
                                    if not (List.isEmpty model.dirty) || model.held /= Nothing then
                                        { run | problem = Just "a request went through while something was dirty or a question was open" }

                                    else if value /= target then
                                        { run | problem = Just "the request came back as another value" }

                                    else
                                        run

                                Hold next _ ->
                                    if List.isEmpty model.dirty && model.held == Nothing then
                                        { run | problem = Just "a clean guard held a request" }

                                    else
                                        { run | guard = next, model = { model | held = Just target } }

                        PressLeave ->
                            let
                                ( next, decision ) =
                                    press "leave" run.guard
                            in
                            case ( model.held, decision ) of
                                ( Just target, Just ( back, False ) ) ->
                                    if back == target then
                                        { run | guard = next, model = { dirty = [], held = Nothing } }

                                    else
                                        { run | problem = Just "Leave handed back another value than the one held" }

                                ( Nothing, Nothing ) ->
                                    run

                                _ ->
                                    { run | problem = Just "Leave and the model disagree" }

                        Dismiss ->
                            { run
                                | guard = Tuple.first (LeaveGuard.dismiss run.guard)
                                , model = { model | held = Nothing }
                            }

                        PressStay ->
                            let
                                ( next, decision ) =
                                    press "stay" run.guard
                            in
                            case ( model.held, decision ) of
                                ( _, Nothing ) ->
                                    { run | guard = next, model = { model | held = Nothing } }

                                _ ->
                                    { run | problem = Just "Stay decided something" }

                        PressSave ->
                            let
                                ( next, decision ) =
                                    press "save" run.guard
                            in
                            case ( model.held, decision ) of
                                ( Just target, Just ( back, True ) ) ->
                                    if back == target then
                                        { run | guard = next, model = { model | held = Nothing } }

                                    else
                                        { run | problem = Just "Save and leave handed back another value than the one held" }

                                ( Nothing, Nothing ) ->
                                    run

                                _ ->
                                    { run | problem = Just "Save and leave and the model disagree" }
            in
            case afterwards.problem of
                Just _ ->
                    afterwards

                Nothing ->
                    { afterwards | problem = disagreement afterwards.model afterwards.guard }


disagreement : Model -> Guard -> Maybe String
disagreement model guard =
    if LeaveGuard.pending guard /= model.held then
        Just "the held value differs"

    else if LeaveGuard.isOpen guard /= (model.held /= Nothing) then
        Just "the dialog is open when nothing is held, or closed when something is"

    else if LeaveGuard.dirtySources guard /= model.dirty then
        Just "the dirty sources differ"

    else if LeaveGuard.isDirty guard /= not (List.isEmpty model.dirty) then
        Just "isDirty differs"

    else
        Nothing


sequenceTests : Test
sequenceTests =
    describe "random sequences"
        [ fuzz (Fuzz.list opFuzzer) "the guard always agrees with the plain model, loses no held request and lets none through while dirty" <|
            \ops ->
                case (List.foldl step start ops).problem of
                    Nothing ->
                        Expect.pass

                    Just problem ->
                        Expect.fail problem
        , fuzz (Fuzz.list opFuzzer) "whatever happened, answering the question and cleaning every source frees the guard" <|
            \ops ->
                let
                    freed =
                        List.foldl step start ops
                            |> .guard
                            |> (\guard -> Tuple.first (press "stay" guard))
                            |> (\guard -> List.foldl (\source -> LeaveGuard.setDirty source False) guard [ 0, 1, 2 ])
                in
                case LeaveGuard.request 99 freed of
                    Proceed target ->
                        Expect.equal 99 target

                    Hold _ _ ->
                        Expect.fail "the guard is stuck"
        ]
