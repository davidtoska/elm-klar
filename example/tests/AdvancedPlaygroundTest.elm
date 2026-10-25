module AdvancedPlaygroundTest exposing (suite)

import Expect
import Html
import Html.Attributes as Attr
import Json.Encode as Encode
import Showcase.Advanced as Advanced
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as S


response : String -> Int -> List ( String, Encode.Value ) -> Advanced.Msg
response action id fields =
    Advanced.Received (Encode.object ([ ( "action", Encode.string action ), ( "component", Encode.string "Button" ), ( "id", Encode.int id ) ] ++ fields))


ready : Advanced.Model
ready =
    Advanced.init
        |> Advanced.update (Advanced.Load "Button")
        |> Advanced.update
            (response "described"
                1
                [ ( "targets"
                  , Encode.list identity
                        [ Encode.object
                            [ ( "id", Encode.string "target" )
                            , ( "label", Encode.string "Button example" )
                            , ( "alias", Encode.string "Button" )
                            , ( "imports", Encode.list Encode.string [] )
                            , ( "constructors", Encode.list Encode.string [ "Clicked" ] )
                            , ( "options", Encode.list identity [ Encode.object [ ( "name", Encode.string "onClick" ), ( "sample", Encode.string "Button.onClick Clicked" ), ( "trace", Encode.string "Button.onClick (PlaygroundObserved \"onClick\" [])" ) ] ] )
                            ]
                        ]
                  )
                ]
            )


compiled : Int -> String -> Advanced.Msg
compiled id url =
    response "compiled" id [ ( "ok", Encode.bool True ), ( "url", Encode.string url ) ]


preview : Advanced.Model -> Query.Single msg
preview model =
    Advanced.preview "Button" False model (Html.text "Original preview") |> Query.fromHtml


building : Advanced.Model
building =
    ready |> Advanced.update (Advanced.Edit "Button" "onClick" "Button.onClick Clicked") |> Advanced.update (Advanced.Apply "Button")


suite : Test
suite =
    describe "Custom typed expressions"
        [ test "a successful compile replaces the live preview" <|
            \_ -> building |> Advanced.update (compiled 3 "/compiled-preview") |> preview |> Query.has [ S.tag "iframe", S.attribute (Attr.src "/compiled-preview") ]
        , test "editing while compiling invalidates the older result" <|
            \_ -> building |> Advanced.update (Advanced.Edit "Button" "onClick" "Button.onClick SaveClicked") |> Advanced.update (compiled 3 "/obsolete-preview") |> preview |> Query.has [ S.text "Original preview" ]
        , test "reset prevents a late compilation from restoring old code" <|
            \_ -> building |> Advanced.update (Advanced.Reset "Button") |> Advanced.update (compiled 3 "/obsolete-preview") |> preview |> Query.hasNot [ S.tag "iframe" ]
        , test "a type error preserves the last successfully compiled preview" <|
            \_ ->
                building
                    |> Advanced.update (compiled 3 "/last-good-preview")
                    |> Advanced.update (Advanced.Edit "Button" "loading" "Button.loading 7")
                    |> Advanced.update (Advanced.Apply "Button")
                    |> Advanced.update (response "compiled" 5 [ ( "ok", Encode.bool False ), ( "diagnostics", Encode.string "TYPE MISMATCH" ) ])
                    |> preview
                    |> Query.has [ S.tag "iframe", S.attribute (Attr.src "/last-good-preview") ]
        , test "compiler diagnostics appear as an accessible alert" <|
            \_ ->
                building
                    |> Advanced.update (response "compiled" 3 [ ( "ok", Encode.bool False ), ( "diagnostics", Encode.string "TYPE MISMATCH: expected Bool" ) ])
                    |> Advanced.toolbar identity "Button"
                    |> Query.fromHtml
                    |> Query.find [ S.attribute (Attr.attribute "role" "alert") ]
                    |> Query.has [ S.text "TYPE MISMATCH: expected Bool" ]
        , test "callback arguments are visible in the event log" <|
            \_ ->
                building
                    |> Advanced.update (compiled 3 "/preview")
                    |> Advanced.update (response "callback" 3 [ ( "payload", Encode.string "onInput: [42]" ) ])
                    |> Advanced.toolbar identity "Button"
                    |> Query.fromHtml
                    |> Query.has [ S.text "onInput: [42]" ]
        , test "custom expressions remain isolated to their component" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (Advanced.isEnabled "Button" "onClick" building)
                    , \_ -> Expect.equal False (Advanced.isEnabled "Badge" "onClick" building)
                    ]
                    ()
        , test "baseline mode temporarily bypasses the compiled iframe" <|
            \_ -> Advanced.preview "Button" True (Advanced.update (compiled 3 "/preview") building) (Html.text "Baseline") |> Query.fromHtml |> Query.has [ S.text "Baseline" ]
        ]
