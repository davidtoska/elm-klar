module ToastTest exposing (suite)

{-| The toast stack for screen readers and the keyboard:

  - two live regions: `Danger` toasts are announced at once, the others politely,
    and neither region announces a toast that goes away;
  - every toast and its buttons have ids that start with the id of the stack;
  - when the toast that has focus goes away (closed, its action ran, dismissed by
    the application), a guard brings focus back if it fell to the page, and only
    then;
  - `Toast.focus` takes the keyboard to the newest toast;
  - which toasts start a timer.

-}

import Expect exposing (Expectation)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Overlay as Overlay
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = ToastMsg Toast.Msg
    | Undo


type alias Stack =
    Toast.State Msg


suite : Test
suite =
    describe "Klar.Toast"
        [ regionTests
        , idTests
        , recoverTests
        , focusTests
        , timerTests
        ]


pushed : List (Toast.Attribute Msg) -> Stack -> Stack
pushed attributes stack =
    Toast.push attributes stack |> Tuple.first


drawn : Stack -> Query.Single Msg
drawn stack =
    Overlay.host { attributes = [], page = [], overlays = [ Toast.view ToastMsg [] stack ] }
        |> Query.fromHtml


attribute : String -> String -> Selector.Selector
attribute name value =
    Selector.attribute (Attr.attribute name value)


{-| Hand a message of the stack to `update`.
-}
settle : Stack -> Result String Msg -> Result String ( Stack, Cmd Toast.Msg )
settle stack result =
    result
        |> Result.andThen
            (\msg ->
                case msg of
                    ToastMsg inner ->
                        Ok (Toast.update inner stack)

                    Undo ->
                        Err "the action of the application, not a message of the stack"
            )


mixed : Stack
mixed =
    Toast.init "toasts"
        |> pushed [ Toast.message "Order saved." ]
        |> pushed [ Toast.tone Danger, Toast.message "Could not send the invoice." ]


regionTests : Test
regionTests =
    describe "two live regions"
        [ test "a Danger toast is in the region that is announced at once" <|
            \_ ->
                drawn mixed
                    |> Query.find [ Selector.class "klar-toasts__alerts" ]
                    |> Expect.all
                        [ Query.has [ attribute "aria-live" "assertive", attribute "aria-relevant" "additions" ]
                        , Query.has [ Selector.text "Could not send the invoice." ]
                        , Query.findAll [ Selector.class "klar-toast" ] >> Query.count (Expect.equal 1)
                        ]
        , test "the other toasts are in the polite log" <|
            \_ ->
                drawn mixed
                    |> Query.find [ Selector.class "klar-toasts__log" ]
                    |> Expect.all
                        [ Query.has [ attribute "role" "log", attribute "aria-live" "polite", attribute "aria-relevant" "additions" ]
                        , Query.has [ Selector.text "Order saved." ]
                        , Query.findAll [ Selector.class "klar-toast" ] >> Query.count (Expect.equal 1)
                        ]
        , test "no toast is a live region of its own (it would be announced twice)" <|
            \_ ->
                drawn mixed
                    |> Query.findAll [ attribute "role" "alert" ]
                    |> Query.count (Expect.equal 0)
        , test "both regions are there while there are no toasts, so that the first one is heard" <|
            \_ ->
                drawn (Toast.init "toasts")
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-toasts__alerts" ]
                        , Query.has [ Selector.class "klar-toasts__log" ]
                        ]
        ]


idTests : Test
idTests =
    describe "ids"
        [ test "the stack, its toasts and their buttons have ids that start with the id of the stack" <|
            \_ ->
                Toast.init "toasts"
                    |> pushed [ Toast.message "Order deleted.", Toast.action "Undo" Undo ]
                    |> drawn
                    |> Expect.all
                        [ Query.has [ Selector.id "toasts" ]
                        , Query.has [ Selector.id "toasts-1" ]
                        , Query.has [ Selector.id "toasts-1-close" ]
                        , Query.has [ Selector.id "toasts-1-action" ]
                        ]
        , test "two stacks with their own ids share none" <|
            \_ ->
                Overlay.host
                    { attributes = []
                    , page = []
                    , overlays =
                        [ Toast.view ToastMsg [] (pushed [ Toast.message "a" ] (Toast.init "app-toasts"))
                        , Toast.view ToastMsg [] (pushed [ Toast.message "b" ] (Toast.init "page-toasts"))
                        ]
                    }
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.id "app-toasts-1-close" ] >> Query.count (Expect.equal 1)
                        , Query.findAll [ Selector.id "page-toasts-1-close" ] >> Query.count (Expect.equal 1)
                        ]
        ]


{-| The first toast of the stack, after focus came into it.
-}
focusedFirst : Stack -> Stack
focusedFirst stack =
    drawn stack
        |> Query.find [ Selector.id "toasts-1" ]
        |> Event.simulate (Event.custom "focusin" (Encode.object []))
        |> Event.toResult
        |> settle stack
        |> Result.map Tuple.first
        |> Result.withDefault stack


two : Stack
two =
    Toast.init "toasts"
        |> pushed [ Toast.key "first", Toast.message "first" ]
        |> pushed [ Toast.message "second" ]


guarded : Stack -> Expectation
guarded stack =
    drawn stack
        |> Query.find [ Selector.class "klar-toasts" ]
        |> Expect.all
            [ Query.has [ Selector.class "klar-toasts--recover" ]
            , Query.children [ Selector.class "klar-modal__guard" ] >> Query.count (Expect.equal 1)
            ]


lostFocus : String -> ( String, Encode.Value )
lostFocus active =
    Event.custom "animationstart"
        (Encode.object
            [ ( "animationName", Encode.string "klar-focus-lost" )
            , ( "target"
              , Encode.object
                    [ ( "ownerDocument"
                      , Encode.object [ ( "activeElement", Encode.object [ ( "tagName", Encode.string active ) ] ) ]
                      )
                    ]
              )
            ]
        )


recoverTests : Test
recoverTests =
    let
        closedWithFocus =
            drawn (focusedFirst two)
                |> Query.find [ Selector.id "toasts-1-close" ]
                |> Event.simulate Event.click
                |> Event.toResult
                |> settle (focusedFirst two)
                |> Result.map Tuple.first
    in
    describe "the toast with focus goes away"
        [ test "closed with its button: the stack keeps watch" <|
            \_ ->
                case closedWithFocus of
                    Ok stack ->
                        guarded stack

                    Err problem ->
                        Expect.fail problem
        , test "dismissed by the application: the stack keeps watch as well" <|
            \_ ->
                guarded (Toast.dismiss "first" (focusedFirst two))
        , test "all dismissed by the application: the stack keeps watch as well" <|
            \_ ->
                guarded (Toast.dismissAll (focusedFirst two))
        , test "a toast without focus goes away: nothing to watch" <|
            \_ ->
                Toast.dismiss "first" two
                    |> drawn
                    |> Query.findAll [ Selector.class "klar-modal__guard" ]
                    |> Query.count (Expect.equal 0)
        , test "focus fell to the page: the guard moves it, and stops watching" <|
            \_ ->
                case closedWithFocus of
                    Ok stack ->
                        drawn stack
                            |> Query.find [ Selector.class "klar-modal__guard" ]
                            |> Event.simulate (lostFocus "BODY")
                            |> Event.toResult
                            |> settle stack
                            |> (\after ->
                                    case after of
                                        Ok ( recovered, cmd ) ->
                                            Expect.all
                                                [ \_ -> Expect.notEqual Cmd.none cmd
                                                , \_ ->
                                                    drawn recovered
                                                        |> Query.findAll [ Selector.class "klar-modal__guard" ]
                                                        |> Query.count (Expect.equal 0)
                                                ]
                                                ()

                                        Err problem ->
                                            Expect.fail problem
                               )

                    Err problem ->
                        Expect.fail problem
        , test "focus is on something on the page: the guard leaves it there" <|
            \_ ->
                drawn (Toast.dismiss "first" (focusedFirst two))
                    |> Query.find [ Selector.class "klar-modal__guard" ]
                    |> Event.simulate (lostFocus "INPUT")
                    |> Event.toResult
                    |> Expect.err
        , test "focus that comes into a toast again ends the watch" <|
            \_ ->
                let
                    dismissed =
                        Toast.dismiss "first" (focusedFirst two)
                in
                drawn dismissed
                    |> Query.find [ Selector.id "toasts-2" ]
                    |> Event.simulate (Event.custom "focusin" (Encode.object []))
                    |> Event.toResult
                    |> settle dismissed
                    |> Result.map (Tuple.first >> drawn >> Query.findAll [ Selector.class "klar-modal__guard" ] >> Query.count (Expect.equal 0))
                    |> Result.withDefault (Expect.fail "no message")
        ]


focusTests : Test
focusTests =
    describe "the way in for the keyboard"
        [ test "Toast.focus does nothing without toasts" <|
            \_ ->
                Toast.focus (Toast.init "toasts")
                    |> Expect.equal Cmd.none
        , test "Toast.focus moves focus when there is a toast" <|
            \_ ->
                Toast.focus two
                    |> Expect.notEqual Cmd.none
        , test "the stack remembers where focus came from" <|
            \_ ->
                drawn two
                    |> Query.find [ Selector.id "toasts" ]
                    |> Event.simulate
                        (Event.custom "focusin"
                            (Encode.object [ ( "relatedTarget", Encode.object [ ( "id", Encode.string "save-button" ) ] ) ])
                        )
                    |> Event.toResult
                    |> Expect.ok
        , test "a move inside the stack is not where focus came from" <|
            \_ ->
                drawn two
                    |> Query.find [ Selector.id "toasts" ]
                    |> Event.simulate
                        (Event.custom "focusin"
                            (Encode.object
                                [ ( "relatedTarget"
                                  , Encode.object
                                        [ ( "id", Encode.string "toasts-1-close" )
                                        , ( "parentElement", Encode.object [ ( "id", Encode.string "toasts" ) ] )
                                        ]
                                  )
                                ]
                            )
                        )
                    |> Event.toResult
                    |> Expect.err
        ]


timerTests : Test
timerTests =
    let
        timer attributes =
            Toast.push attributes (Toast.init "toasts") |> Tuple.second
    in
    describe "the timers"
        [ test "an Info toast starts a timer" <|
            \_ -> timer [ Toast.message "a" ] |> Expect.notEqual Cmd.none
        , test "a Danger toast stays until it is closed" <|
            \_ -> timer [ Toast.tone Danger ] |> Expect.equal Cmd.none
        , test "a Danger toast with a duration goes away after it" <|
            \_ -> timer [ Toast.tone Danger, Toast.duration 3000 ] |> Expect.notEqual Cmd.none
        , test "a sticky toast stays, whatever the tone" <|
            \_ -> timer [ Toast.tone Success, Toast.sticky ] |> Expect.equal Cmd.none
        ]
