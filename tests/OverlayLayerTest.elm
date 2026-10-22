module OverlayLayerTest exposing (suite)

{-| The overlay layer (`Klar.Overlay`): what the page learns from its list of
overlays, and what the dialogs and the toasts do about each other.

  - the page is inert exactly while some dialog in the list is open, and the shell
    finds that out by itself;
  - only the dialog on top watches the focus (the one that opened last);
  - the toast stack closes the Tab loop of an open dialog, and the dialog does not
    close it a second time;
  - a dialog's header and footer are no landmarks, so two open dialogs make no
    duplicate banner or contentinfo;
  - `ConfirmDialog.confirmDisabled` and `clearFailure`.

What a command does (moving focus) cannot be looked into; the tests that need it
are in the browser (see CHANGELOG).

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes
import Json.Encode as Encode
import Klar.AppShell as AppShell
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Drawer as Drawer
import Klar.Modal as Modal
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Remote as Remote
import Klar.Toast as Toast
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "The overlay layer"
        [ inertTests
        , topTests
        , toastTests
        , landmarkTests
        , confirmTests
        ]


type Msg
    = Lower Modal.Msg
    | Upper Modal.Msg
    | Toasts Toast.Msg
    | Confirm ConfirmDialog.Msg
    | Confirmed


open : String -> Modal.State
open id =
    Modal.init id |> Modal.open "" |> Tuple.first


{-| The dialog after focus came into it: from then on it keeps watch.
-}
arrived : (Modal.Msg -> Msg) -> String -> Modal.State -> Modal.State
arrived toMsg id state =
    page [ Modal.view toMsg [ Modal.title id ] state [] ]
        |> Query.fromHtml
        |> Query.find [ Selector.id id ]
        |> Event.simulate (Event.custom "focusin" (Encode.object []))
        |> Event.toResult
        |> Result.map (\msg -> settleModal msg state)
        |> Result.withDefault state


settleModal : Msg -> Modal.State -> Modal.State
settleModal msg state =
    case msg of
        Lower inner ->
            Tuple.first (Modal.update inner state)

        Upper inner ->
            Tuple.first (Modal.update inner state)

        _ ->
            state


page : List (Overlay Msg) -> Html Msg
page overlays =
    Overlay.host { attributes = [], page = [ Html.p [] [ Html.text "the page" ] ], overlays = overlays }


lowerView : Modal.State -> Overlay Msg
lowerView =
    \state -> Modal.view Lower [ Modal.title "Lower", Modal.footer [ Html.text "actions" ] ] state []


upperView : Modal.State -> Overlay Msg
upperView =
    \state -> Modal.view Upper [ Modal.title "Upper", Modal.footer [ Html.text "actions" ] ] state []


toastView : Overlay Msg
toastView =
    Toast.view Toasts [] Toast.init


inert : Selector.Selector
inert =
    Selector.attribute (Html.Attributes.attribute "inert" "")


expectCount : String -> Int -> Html Msg -> Expectation
expectCount class n html =
    html
        |> Query.fromHtml
        |> Query.findAll [ Selector.class class ]
        |> Query.count (Expect.equal n)



-- THE PAGE IS INERT WHILE A DIALOG IS OPEN


inertTests : Test
inertTests =
    describe "the page behind the overlays"
        [ test "is not inert while every overlay is closed" <|
            \_ ->
                page [ lowerView (Modal.init "lower"), upperView (Modal.init "upper"), toastView ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-overlay-host__page" ]
                    |> Query.hasNot [ inert ]
        , test "is inert as soon as one dialog of the list is open" <|
            \_ ->
                page [ lowerView (Modal.init "lower"), upperView (open "upper"), toastView ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-overlay-host__page" ]
                    |> Query.has [ inert ]
        , test "toasts alone do not make it inert" <|
            \_ ->
                page [ toastView ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-overlay-host__page" ]
                    |> Query.hasNot [ inert ]
        , test "the shell derives the same from its overlays: no flag" <|
            \_ ->
                let
                    shell dialog =
                        AppShell.view [ AppShell.overlays [ lowerView dialog, toastView ] ] [ Html.text "content" ]
                            |> Query.fromHtml
                in
                Expect.all
                    [ \_ -> shell (Modal.init "lower") |> Query.find [ Selector.class "klar-app-shell__chrome" ] |> Query.hasNot [ inert ]
                    , \_ -> shell (open "lower") |> Query.find [ Selector.class "klar-app-shell__chrome" ] |> Query.has [ inert ]
                    , \_ -> shell (open "lower") |> Query.has [ Selector.class "klar-app-shell--modal-open" ]
                    ]
                    ()
        , test "a drawer counts like a dialog" <|
            \_ ->
                page [ Drawer.view Lower [ Drawer.title "Order" ] (open "drawer") [] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-overlay-host__page" ]
                    |> Query.has [ inert ]
        ]



-- ONLY THE TOP DIALOG WATCHES THE FOCUS


topTests : Test
topTests =
    let
        lower =
            arrived Lower "lower" (open "lower")

        upper =
            arrived Upper "upper" (open "upper")

        watching =
            expectCount "klar-modal__guard" 1
    in
    describe "the guard that notices lost focus"
        [ test "is not there before focus came into the dialog" <|
            \_ ->
                page [ lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-modal__guard" ]
        , test "is there once focus came in" <|
            \_ ->
                page [ lowerView lower ] |> watching
        , test "with two dialogs open only the last one in the list has it" <|
            \_ ->
                page [ lowerView lower, upperView upper ] |> watching
        , test "and the message it sends is the upper dialog's" <|
            \_ ->
                case
                    page [ lowerView lower, upperView upper ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-modal__guard" ]
                        |> Event.simulate (Event.custom "animationstart" (Encode.object [ ( "animationName", Encode.string "klar-focus-lost" ) ]))
                        |> Event.toResult
                of
                    Ok (Upper _) ->
                        Expect.pass

                    _ ->
                        Expect.fail "the guard of the upper dialog sent no message of the upper dialog"
        , test "another animation is not a lost focus" <|
            \_ ->
                page [ lowerView lower ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-modal__guard" ]
                    |> Event.simulate (Event.custom "animationstart" (Encode.object [ ( "animationName", Encode.string "klar-fade-in" ) ]))
                    |> Event.toResult
                    |> Expect.err
        ]



-- TOASTS AND THE TAB LOOP


toastTests : Test
toastTests =
    let
        sentinels =
            expectCount "klar-modal__sentinel"
    in
    describe "the toasts and the Tab loop of a dialog"
        [ test "a dialog without a toast stack closes the loop itself: two stops around it" <|
            \_ ->
                page [ lowerView (open "lower") ] |> sentinels 2
        , test "with a toast stack the stack closes it: still two stops, one of them after the toasts" <|
            \_ ->
                page [ lowerView (open "lower"), toastView ] |> sentinels 2
        , test "the stack is a log, not a landmark" <|
            \_ ->
                page [ toastView ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-toasts" ]
                    |> Query.has [ Selector.attribute (Html.Attributes.attribute "role" "log") ]
        , test "without a dialog open the stack has no stop at all" <|
            \_ ->
                page [ toastView ] |> sentinels 0
        , test "the stack is drawn after the dialogs, wherever the application listed it" <|
            \_ ->
                page [ toastView, lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> Query.children []
                    |> Query.index 0
                    |> Query.children []
                    |> Query.index -1
                    |> Query.has [ Selector.class "klar-toasts" ]
        ]



-- LANDMARKS


landmarkTests : Test
landmarkTests =
    describe "landmarks"
        [ test "an open dialog has no header or footer element (two would be two banners)" <|
            \_ ->
                page [ lowerView (open "lower"), upperView (open "upper") ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "header" ]
                        , Query.hasNot [ Selector.tag "footer" ]
                        , Query.has [ Selector.class "klar-modal__header" ]
                        , Query.has [ Selector.class "klar-modal__footer" ]
                        ]
        ]



-- CONFIRM DIALOG


confirmTests : Test
confirmTests =
    let
        dialog attributes state =
            Overlay.host
                { attributes = []
                , page = []
                , overlays = [ ConfirmDialog.view Confirm (ConfirmDialog.title "Cancel order?" :: ConfirmDialog.onConfirm Confirmed :: attributes) state ]
                }
                |> Query.fromHtml

        opened =
            ConfirmDialog.init "confirm" |> ConfirmDialog.open "" |> Tuple.first

        failure =
            Remote.problem Remote.server

        confirmButton =
            Selector.id "confirm-confirm"
    in
    describe "ConfirmDialog"
        [ test "the confirm button is enabled by default" <|
            \_ ->
                dialog [] opened
                    |> Query.find [ confirmButton ]
                    |> Query.hasNot [ Selector.disabled True ]
        , test "confirmDisabled True disables the confirm button" <|
            \_ ->
                dialog [ ConfirmDialog.confirmDisabled True ] opened
                    |> Query.find [ confirmButton ]
                    |> Query.has [ Selector.disabled True ]
        , test "and it sends nothing, so Enter cannot confirm either" <|
            \_ ->
                dialog [ ConfirmDialog.confirmDisabled True ] opened
                    |> Query.find [ confirmButton ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Expect.err
        , test "confirmDisabled False enables it again" <|
            \_ ->
                dialog [ ConfirmDialog.confirmDisabled True, ConfirmDialog.confirmDisabled False ] opened
                    |> Query.find [ confirmButton ]
                    |> Event.simulate Event.click
                    |> Event.expect Confirmed
        , test "clearFailure takes a shown failure away and keeps the dialog open" <|
            \_ ->
                ConfirmDialog.setFailed failure opened
                    |> ConfirmDialog.clearFailure
                    |> Expect.all
                        [ ConfirmDialog.problem >> Expect.equal Nothing
                        , ConfirmDialog.isOpen >> Expect.equal True
                        ]
        , test "clearFailure does not stop a request that is running" <|
            \_ ->
                ConfirmDialog.setBusy opened
                    |> ConfirmDialog.clearFailure
                    |> ConfirmDialog.isBusy
                    |> Expect.equal True
        , test "the retry button is gone with the failure" <|
            \_ ->
                dialog [] (ConfirmDialog.setFailed failure opened |> ConfirmDialog.clearFailure)
                    |> Query.hasNot [ Selector.class "klar-alert" ]
        ]
