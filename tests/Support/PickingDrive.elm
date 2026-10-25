module Support.PickingDrive exposing
    ( altKey
    , caretKey
    , count
    , fire
    , has
    , hasNot
    , key
    , keyWith
    , metaKey
    , scroll
    )

{-| Helpers to drive the picking components from tests with real events: a key
press with its modifiers (and the caret of the text box it happens in), the
message an element sends for an event, and counting what is drawn.
-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Json.Encode as Encode
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector exposing (Selector)
import Test.Runner


key : String -> ( String, Encode.Value )
key name =
    keyWith { ctrl = False, shift = False } name


keyWith : { ctrl : Bool, shift : Bool } -> String -> ( String, Encode.Value )
keyWith modifiers name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool modifiers.ctrl )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool modifiers.shift )
            ]
        )


{-| A key pressed with Cmd (the Meta key), as on a Mac.
-}
metaKey : { shift : Bool } -> String -> ( String, Encode.Value )
metaKey modifiers name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool True )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool modifiers.shift )
            ]
        )


{-| A key pressed with Alt (Option on a Mac).
-}
altKey : String -> ( String, Encode.Value )
altKey name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool True )
            , ( "shiftKey", Encode.bool False )
            ]
        )


{-| The list scrolled to this offset (the event the virtual lists listen to).
-}
scroll : Float -> ( String, Encode.Value )
scroll top =
    Event.custom "scroll" (Encode.object [ ( "target", Encode.object [ ( "scrollTop", Encode.float top ) ] ) ])


{-| A key pressed in a text box with this text and caret (start and end of the
selection).
-}
caretKey : String -> Int -> Int -> String -> ( String, Encode.Value )
caretKey text start end name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "target"
              , Encode.object
                    [ ( "value", Encode.string text )
                    , ( "selectionStart", Encode.int start )
                    , ( "selectionEnd", Encode.int end )
                    ]
              )
            ]
        )


{-| The message that the one element named by the selectors sends for an event,
or `Nothing` when it does not handle it (or is not there exactly once).
-}
fire : List Selector -> ( String, Encode.Value ) -> Html msg -> Maybe msg
fire selectors event html =
    html
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.toMaybe


passes : Expectation -> Bool
passes expectation =
    Test.Runner.getFailureReason expectation == Nothing


{-| How many elements match (up to 500).
-}
count : List Selector -> Html msg -> Int
count selectors html =
    let
        found =
            html |> Query.fromHtml |> Query.findAll selectors

        probe n =
            if n > 500 || passes (Query.count (Expect.equal n) found) then
                n

            else
                probe (n + 1)
    in
    probe 0


has : List Selector -> Html msg -> Bool
has selectors html =
    count selectors html > 0


hasNot : List Selector -> Html msg -> Bool
hasNot selectors html =
    count selectors html == 0
