module InlineEditDetailTest exposing (suite)

{-| A failed save shows the detail the application gave the problem (the server's
message for the field), and nothing extra for the ready-made detail of a kind.
-}

import Expect
import Json.Encode as Encode
import Klar.InlineEdit as InlineEdit
import Klar.Locale as Locale
import Klar.Remote as Remote
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = Edit InlineEdit.Msg


{-| A save of a changed text that failed: the user clicked the text, typed and
pressed Enter, and the backend answered with the problem.
-}
failedWith : Remote.Problem -> InlineEdit.State
failedWith problem =
    let
        step selectors event state =
            InlineEdit.view Edit [] state
                |> Query.fromHtml
                |> Query.find selectors
                |> Event.simulate event
                |> Event.toResult
                |> Result.map (\(Edit inner) -> Tuple.first (InlineEdit.update inner state))
                |> Result.withDefault state

        enter =
            Event.custom "keydown"
                (Encode.object
                    [ ( "key", Encode.string "Enter" )
                    , ( "ctrlKey", Encode.bool False )
                    , ( "metaKey", Encode.bool False )
                    , ( "shiftKey", Encode.bool False )
                    , ( "altKey", Encode.bool False )
                    ]
                )
    in
    InlineEdit.init "website" "https://acme.example"
        |> step [ Selector.class "klar-inline-edit__display" ] Event.click
        |> step [ Selector.tag "input" ] (Event.input "https://acme.blocked")
        |> step [ Selector.tag "input" ] enter
        |> InlineEdit.failed problem


failureText : List (InlineEdit.Attribute Msg) -> InlineEdit.State -> Query.Single Msg
failureText attributes state =
    InlineEdit.view Edit attributes state
        |> Query.fromHtml
        |> Query.find [ Selector.class "klar-inline-edit__failure-text" ]


suite : Test
suite =
    describe "InlineEdit.failed"
        [ test "shows the title and the detail the application gave" <|
            \_ ->
                failedWith (Remote.problem Remote.validation |> Remote.withDetail "This domain is blocked.")
                    |> failureText []
                    |> Query.has [ Selector.text "Could not save. The form has errors: This domain is blocked." ]
        , test "shows only the title when the detail is the ready-made one" <|
            \_ ->
                failedWith (Remote.problem Remote.validation)
                    |> failureText []
                    |> Query.has [ Selector.text "Could not save. The form has errors" ]
        , test "a title of its own and a detail of its own both show" <|
            \_ ->
                failedWith (Remote.problem Remote.validation |> Remote.withTitle "Blocked" |> Remote.withDetail "Not this domain.")
                    |> failureText []
                    |> Query.has [ Selector.text "Could not save. Blocked: Not this domain." ]
        , test "the detail follows the language when it is not set" <|
            \_ ->
                failedWith (Remote.problem Remote.validation)
                    |> failureText [ InlineEdit.locale Locale.nb ]
                    |> Query.hasNot [ Selector.text ":" ]
        ]
