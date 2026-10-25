module AiChatTest exposing (suite)

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.AiChat as Chat
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Remote)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S


type Msg
    = Inner Chat.Msg
    | Send Chat.Submission
    | Stop
    | Retry


messages : List (Chat.Message Int)
messages =
    [ Chat.message { id = 1, role = Chat.Assistant, author = "Assistant", body = "Partial **answer\n\n<script>no</script> ![no](https://example.com/track)" } ]


widget : List (Chat.Attribute Int Msg) -> Remote (List (Chat.Message Int)) -> Chat.Status -> Chat.State -> Html Msg
widget attrs remote status state =
    Chat.view Inner ([ Chat.onSend Send, Chat.onStop Stop, Chat.onRetry Retry ] ++ attrs) { label = "AI chat", ids = Ids.int, messages = remote, status = status } state


sendButton : Html Msg -> Query.Single Msg
sendButton html =
    html |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Send message" ] ]


capture : Chat.State -> Result String Chat.Submission
capture state =
    widget [] (Remote.Loaded messages) Chat.Idle state
        |> sendButton
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Send sent ->
                        Ok sent

                    _ ->
                        Err "Expected submission"
            )


suite : Test
suite =
    describe "AI conversation contract"
        [ test "accepted prompt clears only its exact draft" <|
            \_ ->
                let
                    state =
                        Chat.init "chat" |> Chat.setDraft "  Exact prompt\n"
                in
                capture state |> Result.map (\sent -> ( Chat.submissionText sent, Chat.draft (Chat.acknowledge sent state) )) |> Expect.equal (Ok ( "  Exact prompt\n", "" ))
        , test "late acceptance preserves a newer draft" <|
            \_ ->
                let
                    state =
                        Chat.init "chat" |> Chat.setDraft "Original"
                in
                capture state |> Result.map (\sent -> state |> Chat.setDraft "New work" |> Chat.acknowledge sent |> Chat.draft) |> Expect.equal (Ok "New work")
        , test "editing away and back invalidates a captured prompt" <|
            \_ ->
                let
                    state =
                        Chat.init "chat" |> Chat.setDraft "Original"
                in
                capture state |> Result.map (\sent -> state |> Chat.setDraft "Other" |> Chat.setDraft "Original" |> Chat.acknowledge sent |> Chat.draft) |> Expect.equal (Ok "Original")
        , test "reset prevents acknowledgements crossing conversations" <|
            \_ ->
                let
                    state =
                        Chat.init "chat" |> Chat.setDraft "Same"
                in
                capture state |> Result.map (\sent -> state |> Chat.reset |> Chat.setDraft "Same" |> Chat.acknowledge sent |> Chat.draft) |> Expect.equal (Ok "Same")
        , test "unavailable and old histories block sending" <|
            \_ ->
                let
                    remote =
                        Remote.Loaded messages

                    state =
                        Chat.init "chat" |> Chat.setDraft "Hello"

                    check r =
                        widget [] r Chat.Idle state |> sendButton |> Query.has [ S.disabled True ]
                in
                Expect.all (List.map (\r _ -> check r) [ Remote.NotAsked, Remote.Loading, Remote.Failed (Remote.problem Remote.network), Remote.refresh remote, Remote.settle remote (Err (Remote.problem Remote.network)) ]) ()
        , test "blank and over-limit prompts stay visible but cannot be sent" <|
            \_ ->
                Expect.all
                    [ \_ -> widget [] (Remote.Loaded []) Chat.Idle (Chat.init "chat" |> Chat.setDraft " \n ") |> sendButton |> Query.has [ S.disabled True ]
                    , \_ -> widget [ Chat.maxLength 3 ] (Remote.Loaded []) Chat.Idle (Chat.init "chat" |> Chat.setDraft "12345") |> Query.fromHtml |> Query.find [ S.tag "textarea" ] |> Query.has [ S.attribute (Attr.value "12345") ]
                    , \_ -> widget [ Chat.maxLength 3 ] (Remote.Loaded []) Chat.Idle (Chat.init "chat" |> Chat.setDraft "12345") |> sendButton |> Query.has [ S.disabled True ]
                    ]
                    ()
        , test "generation blocks send and offers explicit stop" <|
            \_ ->
                let
                    html =
                        widget [] (Remote.Loaded messages) Chat.Generating (Chat.init "chat" |> Chat.setDraft "Next prompt")
                in
                Expect.all
                    [ \_ -> html |> sendButton |> Query.has [ S.disabled True ]
                    , \_ -> html |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Stop generating" ] ] |> Event.simulate Event.click |> Event.expect Stop
                    , \_ -> html |> Query.fromHtml |> Query.find [ S.tag "textarea" ] |> Query.has [ S.disabled False ]
                    ]
                    ()
        , test "interrupted response keeps partial text and offers retry" <|
            \_ ->
                widget [] (Remote.Loaded messages) Chat.Interrupted (Chat.init "chat") |> Query.fromHtml |> Query.has [ S.text "Partial " ]
        , test "failure retains the transcript and draft" <|
            \_ ->
                widget [] (Remote.Loaded messages) (Chat.Failed "Network") (Chat.init "chat" |> Chat.setDraft "Keep me") |> Query.fromHtml |> Query.has [ S.text "Generation failed: Network" ]
        , test "streamed markup cannot execute scripts or load images" <|
            \_ ->
                widget [] (Remote.Loaded messages) Chat.Generating (Chat.init "chat") |> Query.fromHtml |> Query.hasNot [ S.tag "img" ]
        , test "duplicate message identities disable sending" <|
            \_ ->
                widget [] (Remote.Loaded (messages ++ messages)) Chat.Idle (Chat.init "chat" |> Chat.setDraft "Hello") |> sendButton |> Query.has [ S.disabled True ]
        , test "Norwegian status is announced" <|
            \_ ->
                widget [ Chat.locale Locale.nb ] (Remote.Loaded messages) Chat.Generating (Chat.init "chat") |> Query.fromHtml |> Query.has [ S.text "AI genererer et svar" ]
        ]
