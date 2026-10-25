module OverlayLayerTest exposing (suite)

{-| The overlay layer (`Klar.Overlay`): what the page learns from its list of
overlays, and what the dialogs and the toasts do about each other.

  - the page is inert exactly while some dialog in the list is open, and the shell
    finds that out by itself;
  - the page keeps its place in the DOM whatever the list holds, and `Overlay.map`
    keeps the watch of a closed dialog;
  - only the dialog on top watches the focus (the one that opened last), from the
    moment it opens;
  - `Escape` is layered: a key that something inside handled, or that ends an IME
    composition, does not close the dialog;
  - `Shift+Tab` past the first element lands at the end of the footer;
  - the toast stack closes the Tab loop of an open dialog, and the dialog does not
    close it a second time;
  - a dialog's header and footer are no landmarks, so two open dialogs make no
    duplicate banner or contentinfo;
  - `ConfirmDialog`: an alertdialog described by its message, `confirmDisabled` and
    `clearFailure`.

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
        , depthTests
        , topTests
        , escapeTests
        , tabTests
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
    | Wrapped Msg


open : String -> Modal.State
open id =
    Modal.init id |> Modal.open "" |> Tuple.first


page : List (Overlay Msg) -> Html Msg
page overlays =
    Overlay.host { attributes = [], page = [ Html.p [] [ Html.text "the page" ] ], overlays = overlays }


lowerView : Modal.State -> Overlay Msg
lowerView state =
    Modal.view Lower [ Modal.footer [ Html.text "actions" ] ] state "Lower" []


upperView : Modal.State -> Overlay Msg
upperView state =
    Modal.view Upper [ Modal.footer [ Html.text "actions" ] ] state "Upper" []


toastView : Overlay Msg
toastView =
    Toast.view Toasts [] (Toast.init "toasts")


inert : Selector.Selector
inert =
    Selector.attribute (Html.Attributes.attribute "inert" "")


expectCount : String -> Int -> Html Msg -> Expectation
expectCount class n html =
    html
        |> Query.fromHtml
        |> Query.findAll [ Selector.class class ]
        |> Query.count (Expect.equal n)


{-| What the dialog sends for this event on its dialog element, given to `update`.
-}
afterKey : List ( String, Encode.Value ) -> Modal.State -> Result String Modal.State
afterKey fields state =
    page [ lowerView state ]
        |> Query.fromHtml
        |> Query.find [ Selector.id "lower" ]
        |> Event.simulate (Event.custom "keydown" (Encode.object fields))
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Lower inner ->
                        Ok (Tuple.first (Modal.update inner state))

                    _ ->
                        Err "not a message of the dialog"
            )


escapeFields : List ( String, Encode.Value )
escapeFields =
    [ ( "key", Encode.string "Escape" )
    , ( "ctrlKey", Encode.bool False )
    , ( "metaKey", Encode.bool False )
    , ( "shiftKey", Encode.bool False )
    , ( "altKey", Encode.bool False )
    , ( "target", Encode.object [ ( "id", Encode.string "lower" ) ] )
    ]



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
                page [ Drawer.view Lower [] (open "drawer") "Order" [] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-overlay-host__page" ]
                    |> Query.has [ inert ]
        ]



-- THE PAGE KEEPS ITS PLACE


{-| The element this many levels below the root, always following the first child.
-}
descend : Int -> Query.Single msg -> Query.Single msg
descend levels single =
    List.foldl (\_ current -> current |> Query.children [] |> Query.first) single (List.range 1 levels)


depthTests : Test
depthTests =
    let
        pageAt overlays =
            Overlay.host { attributes = [], page = [ Html.text "the page" ], overlays = overlays }
                |> Query.fromHtml
                |> descend 13
                |> Query.has [ Selector.class "klar-overlay-host__page" ]
    in
    describe "the page keeps its place in the DOM, whatever the list holds"
        [ test "with no dialog" <|
            \_ -> pageAt []
        , test "with one closed dialog" <|
            \_ -> pageAt [ lowerView (Modal.init "lower") ]
        , test "with three dialogs, one of them open" <|
            \_ -> pageAt [ lowerView (Modal.init "lower"), upperView (open "upper"), Drawer.view Lower [] (Modal.init "drawer") "Order" [] ]
        , test "with more closed dialogs than listen" <|
            \_ -> pageAt (List.map (\n -> lowerView (Modal.init ("dialog-" ++ String.fromInt n))) (List.range 1 20))
        , test "a mapped closed dialog still hears where focus is on the page" <|
            \_ ->
                case
                    Overlay.host
                        { attributes = []
                        , page = [ Html.button [ Html.Attributes.id "row-7" ] [] ]
                        , overlays = [ Overlay.map Wrapped (lowerView (Modal.init "lower")) ]
                        }
                        |> Query.fromHtml
                        |> descend 12
                        |> Event.simulate (Event.custom "focusin" (Encode.object [ ( "target", Encode.object [ ( "id", Encode.string "row-7" ) ] ) ]))
                        |> Event.toResult
                of
                    Ok (Wrapped (Lower _)) ->
                        Expect.pass

                    Ok _ ->
                        Expect.fail "a message that is not the mapped message of the dialog"

                    Err problem ->
                        Expect.fail problem
        ]



-- ONLY THE TOP DIALOG WATCHES THE FOCUS


topTests : Test
topTests =
    let
        watching =
            expectCount "klar-modal__guard" 1
    in
    describe "the guard that notices lost focus"
        [ test "is there as soon as the dialog is open: focus that never arrives is lost too" <|
            \_ ->
                page [ lowerView (open "lower") ] |> watching
        , test "is not there while the dialog is closed" <|
            \_ ->
                page [ lowerView (Modal.init "lower") ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-modal__guard" ]
        , test "is a direct child of the dialog, where the stylesheet looks for it" <|
            \_ ->
                page [ lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "lower" ]
                    |> Query.children [ Selector.class "klar-modal__guard" ]
                    |> Query.count (Expect.equal 1)
        , test "with two dialogs open only the last one in the list has it" <|
            \_ ->
                page [ lowerView (open "lower"), upperView (open "upper") ] |> watching
        , test "and the message it sends is the upper dialog's" <|
            \_ ->
                case
                    page [ lowerView (open "lower"), upperView (open "upper") ]
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
                page [ lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-modal__guard" ]
                    |> Event.simulate (Event.custom "animationstart" (Encode.object [ ( "animationName", Encode.string "klar-fade-in" ) ]))
                    |> Event.toResult
                    |> Expect.err
        ]



-- ESCAPE IS LAYERED


escapeTests : Test
escapeTests =
    describe "Escape in a dialog"
        [ test "closes it" <|
            \_ ->
                afterKey escapeFields (open "lower")
                    |> Result.map Modal.isOpen
                    |> Expect.equal (Ok False)
        , test "that a control inside handled (it prevented the default) leaves it open" <|
            \_ ->
                afterKey (( "defaultPrevented", Encode.bool True ) :: escapeFields) (open "lower")
                    |> Expect.err
        , test "that ends an IME composition leaves it open" <|
            \_ ->
                afterKey (( "isComposing", Encode.bool True ) :: escapeFields) (open "lower")
                    |> Expect.err
        , test "with the keyCode of a composition (229) leaves it open" <|
            \_ ->
                afterKey (( "keyCode", Encode.int 229 ) :: escapeFields) (open "lower")
                    |> Expect.err
        , test "in a popup open inside the dialog leaves it open" <|
            \_ ->
                afterKey
                    (List.filter (\( name, _ ) -> name /= "target") escapeFields
                        ++ [ ( "target"
                             , Encode.object
                                [ ( "id", Encode.string "country-option-2" )
                                , ( "className", Encode.string "klar-select__option" )
                                , ( "parentElement"
                                  , Encode.object
                                        [ ( "className", Encode.string "klar-popup klar-select__popup" )
                                        , ( "parentElement", Encode.object [ ( "id", Encode.string "lower" ) ] )
                                        ]
                                  )
                                ]
                             )
                           ]
                    )
                    (open "lower")
                    |> Expect.err
        , test "of a static dialog nudges it and keeps it open" <|
            \_ ->
                page [ Modal.view Lower [ Modal.static ] (open "lower") "Lower" [] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "lower" ]
                    |> Event.simulate (Event.custom "keydown" (Encode.object escapeFields))
                    |> Event.toResult
                    |> Result.map
                        (\msg ->
                            case msg of
                                Lower inner ->
                                    Modal.update inner (open "lower") |> Tuple.first |> Modal.isOpen

                                _ ->
                                    False
                        )
                    |> Expect.equal (Ok True)
        , test "of a busy dialog does nothing" <|
            \_ ->
                page [ Modal.view Lower [ Modal.busy True ] (open "lower") "Lower" [] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "lower" ]
                    |> Event.simulate (Event.custom "keydown" (Encode.object escapeFields))
                    |> Event.toResult
                    |> Expect.err
        ]



-- SHIFT+TAB


tabTests : Test
tabTests =
    describe "the end of the dialog, where Shift+Tab past the first element lands"
        [ test "is inside the footer, after its buttons" <|
            \_ ->
                page [ lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-modal__footer" ]
                    |> Query.children []
                    |> Query.index -1
                    |> Query.has [ Selector.id "lower-end", Selector.attribute (Html.Attributes.tabindex -1) ]
        , test "is at the end of the body when there is no footer" <|
            \_ ->
                page [ Modal.view Lower [] (open "lower") "Lower" [ Html.text "body" ] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-modal__body" ]
                    |> Query.has [ Selector.id "lower-end" ]
        , test "the title names the dialog" <|
            \_ ->
                page [ lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.id "lower" ] >> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-labelledby" "lower-title") ]
                        , Query.find [ Selector.id "lower-title" ] >> Query.has [ Selector.text "Lower" ]
                        ]
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
                    |> Query.find [ Selector.class "klar-toasts__log" ]
                    |> Query.has [ Selector.attribute (Html.Attributes.attribute "role" "log") ]
        , test "without a dialog open the stack has no stop at all" <|
            \_ ->
                page [ toastView ] |> sentinels 0
        , test "the stack is drawn after the dialogs, wherever the application listed it" <|
            \_ ->
                page [ toastView, lowerView (open "lower") ]
                    |> Query.fromHtml
                    |> descend 12
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
                , overlays = [ ConfirmDialog.view Confirm (ConfirmDialog.onConfirm Confirmed :: attributes) state "Cancel order?" ]
                }
                |> Query.fromHtml

        opened =
            ConfirmDialog.init "confirm" |> ConfirmDialog.open "" |> Tuple.first

        failure =
            Remote.problem Remote.server

        confirmButton =
            Selector.id "confirm-confirm"

        describedBy value =
            Selector.attribute (Html.Attributes.attribute "aria-describedby" value)
    in
    describe "ConfirmDialog"
        [ test "is an alertdialog named by its question" <|
            \_ ->
                dialog [] opened
                    |> Expect.all
                        [ Query.find [ Selector.id "confirm" ] >> Query.has [ Selector.attribute (Html.Attributes.attribute "role" "alertdialog") ]
                        , Query.find [ Selector.id "confirm-title" ] >> Query.has [ Selector.text "Cancel order?" ]
                        ]
        , test "is described by its message and its consequences, not by the rich body" <|
            \_ ->
                dialog
                    [ ConfirmDialog.message "The customer is told."
                    , ConfirmDialog.consequences [ "The shipment stops" ]
                    , ConfirmDialog.body [ Html.select [ Html.Attributes.id "reason" ] [] ]
                    ]
                    opened
                    |> Expect.all
                        [ Query.find [ Selector.id "confirm" ] >> Query.has [ describedBy "confirm-message confirm-consequences" ]
                        , Query.find [ Selector.id "confirm-message" ] >> Query.has [ Selector.text "The customer is told." ]
                        , Query.find [ Selector.id "confirm-consequences" ] >> Query.has [ Selector.text "The shipment stops" ]
                        , Query.find [ Selector.id "confirm-message" ] >> Query.hasNot [ Selector.id "reason" ]
                        ]
        , test "names no description that does not exist" <|
            \_ ->
                dialog [ ConfirmDialog.consequences [ "The shipment stops" ] ] opened
                    |> Expect.all
                        [ Query.find [ Selector.id "confirm" ] >> Query.has [ describedBy "confirm-consequences" ]
                        , Query.findAll [ Selector.id "confirm-message" ] >> Query.count (Expect.equal 0)
                        ]
        , test "the confirm button is enabled by default" <|
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
        , test "the typed confirmation trims what was typed and can ignore the case" <|
            \_ ->
                let
                    typed =
                        dialog [ ConfirmDialog.typeToConfirm "DELETE", ConfirmDialog.ignoreCase ] opened
                            |> Query.find [ Selector.id "confirm-phrase" ]
                            |> Event.simulate (Event.input " delete ")
                            |> Event.toResult
                            |> Result.andThen
                                (\msg ->
                                    case msg of
                                        Confirm inner ->
                                            Ok (Tuple.first (ConfirmDialog.update inner opened))

                                        _ ->
                                            Err "not a message of the dialog"
                                )
                in
                case typed of
                    Ok state ->
                        dialog [ ConfirmDialog.typeToConfirm "DELETE", ConfirmDialog.ignoreCase ] state
                            |> Query.find [ confirmButton ]
                            |> Event.simulate Event.click
                            |> Event.expect Confirmed

                    Err problem ->
                        Expect.fail problem
        , test "until the phrase matches, the confirm button sends nothing" <|
            \_ ->
                dialog [ ConfirmDialog.typeToConfirm "DELETE" ] opened
                    |> Query.find [ confirmButton ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Expect.err
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
