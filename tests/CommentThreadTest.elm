module CommentThreadTest exposing (suite)

import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.CommentThread as Thread
import Klar.CommentThread.Structure as Structure
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.Remote as Remote
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S
import Time


type CommentId
    = CommentId Int


ids : Ids.Ids CommentId
ids =
    Ids.make { toKey = \(CommentId id) -> String.fromInt id, fromKey = String.toInt >> Maybe.map CommentId }


type Msg
    = ThreadMsg Thread.Msg
    | Post (Thread.Submission CommentId)
    | Resolve CommentId Bool
    | Retry
    | More


comments : List (Thread.Comment CommentId)
comments =
    [ Thread.comment { id = CommentId 1, author = "Ada", body = "Please check **the address**.", at = Time.millisToPosix 0 }
    , Thread.comment { id = CommentId 2, author = "Grace", body = "Confirmed in Oslo.", at = Time.millisToPosix 1000 } |> Thread.replyTo (CommentId 1)
    ]


widget : List (Thread.Attribute CommentId Msg) -> Remote.Remote (List (Thread.Comment CommentId)) -> Thread.State -> Html Msg
widget attributes remote state =
    Thread.view ThreadMsg
        ([ Thread.onSubmit Post, Thread.onRetry Retry ] ++ attributes)
        { label = "Discussion", ids = ids, comments = remote }
        state


withDraft : String -> Thread.State
withDraft text =
    Thread.init "discussion" |> Thread.setDraft text


postButton : Html Msg -> Query.Single Msg
postButton html =
    html |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Post comment" ] ]


posted : Thread.State -> Result String ( String, Maybe CommentId )
posted state =
    widget [] (Remote.Loaded comments) state
        |> postButton
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Post sent ->
                        Ok ( Thread.submissionBody sent, Thread.submissionParent sent )

                    _ ->
                        Err "Unexpected message"
            )


suite : Test
suite =
    describe "Klar.CommentThread"
        [ describe "Draft acknowledgements"
            [ test "successful exact draft is cleared" <|
                \_ ->
                    let
                        state =
                            withDraft "First comment"
                    in
                    Thread.submission ids state |> Maybe.map (\sent -> Thread.acknowledge sent state |> Thread.draft) |> Expect.equal (Just "")
            , test "a late success never clears newer text" <|
                \_ ->
                    let
                        state =
                            withDraft "First comment"
                    in
                    Thread.submission ids state |> Maybe.map (\sent -> Thread.setDraft "Second comment" state |> Thread.acknowledge sent |> Thread.draft) |> Expect.equal (Just "Second comment")
            , test "editing and returning to the old text still invalidates an acknowledgement" <|
                \_ ->
                    let
                        state =
                            withDraft "Original"
                    in
                    Thread.submission ids state |> Maybe.map (\sent -> state |> Thread.setDraft "Changed" |> Thread.setDraft "Original" |> Thread.acknowledge sent |> Thread.draft) |> Expect.equal (Just "Original")
            , test "changing reply target invalidates acknowledgement" <|
                \_ ->
                    let
                        state =
                            withDraft "Original"
                    in
                    Thread.submission ids state |> Maybe.map (\sent -> state |> Thread.setReplyTo ids (Just (CommentId 1)) |> Thread.acknowledge sent |> Thread.draft) |> Expect.equal (Just "Original")
            , test "reset invalidates acknowledgements even with identical new text" <|
                \_ ->
                    let
                        state =
                            withDraft "Original"
                    in
                    Thread.submission ids state |> Maybe.map (\sent -> state |> Thread.reset |> Thread.setDraft "Original" |> Thread.acknowledge sent |> Thread.draft) |> Expect.equal (Just "Original")
            , test "another instance cannot clear this draft" <|
                \_ ->
                    Thread.submission ids (withDraft "Original") |> Maybe.map (\sent -> Thread.init "other-thread" |> Thread.setDraft "Original" |> Thread.acknowledge sent |> Thread.draft) |> Expect.equal (Just "Original")
            , test "whitespace is rejected as blank but remains in state" <|
                \_ ->
                    let
                        state =
                            withDraft " \n\t "
                    in
                    Expect.equal ( " \n\t ", Nothing ) ( Thread.draft state, Thread.submission ids state )
            , test "the submission preserves whitespace and typed parent id" <|
                \_ ->
                    posted (withDraft "  Exact body\n" |> Thread.setReplyTo ids (Just (CommentId 1))) |> Expect.equal (Ok ( "  Exact body\n", Just (CommentId 1) ))
            ]
        , describe "Posting and editing"
            [ test "over-limit text stays intact and cannot be posted" <|
                \_ ->
                    widget [ Thread.maxLength 3 ] (Remote.Loaded comments) (withDraft "12345")
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ S.tag "textarea", S.attribute (Attr.value "12345") ]
                            , \html -> html |> Query.find [ S.tag "button", S.containing [ S.text "Post comment" ] ] |> Query.has [ S.disabled True ]
                            , Query.has [ S.text "Comment exceeds the character limit" ]
                            ]
            , test "a user can keep typing while sending" <|
                \_ ->
                    widget [ Thread.sending True ] (Remote.Loaded comments) (withDraft "Original") |> Query.fromHtml |> Query.find [ S.tag "textarea" ] |> Query.hasNot [ S.disabled True ]
            , test "sending disables only another post" <|
                \_ ->
                    widget [ Thread.sending True ] (Remote.Loaded comments) (withDraft "Original") |> postButton |> Query.has [ S.disabled True ]
            , test "a removed reply target never becomes a top-level post silently" <|
                \_ ->
                    widget [] (Remote.Loaded []) (withDraft "Reply" |> Thread.setReplyTo ids (Just (CommentId 9))) |> postButton |> Query.has [ S.disabled True ]
            , test "post failure preserves input and exposes an alert" <|
                \_ ->
                    widget [ Thread.errorMaybe (Just "Please retry") ] (Remote.Loaded comments) (withDraft "Original")
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ S.attribute (Attr.attribute "role" "alert"), S.containing [ S.text "Please retry" ] ]
                            , Query.has [ S.tag "textarea", S.attribute (Attr.value "Original") ]
                            ]
            , test "no composer is drawn for a read-only thread" <|
                \_ ->
                    Thread.view ThreadMsg [] { label = "Read only", ids = ids, comments = Remote.Loaded comments } (Thread.init "readonly") |> Query.fromHtml |> Query.findAll [ S.tag "textarea" ] |> Query.count (Expect.equal 0)
            , test "reply controls focus the composer and preserve the draft" <|
                \_ ->
                    let
                        state =
                            withDraft "Existing draft"
                    in
                    widget [] (Remote.Loaded comments) state
                        |> Query.fromHtml
                        |> Query.findAll [ S.tag "button", S.containing [ S.text "Reply" ] ]
                        |> Query.first
                        |> Event.simulate Event.click
                        |> Event.toResult
                        |> Result.andThen
                            (\msg ->
                                case msg of
                                    ThreadMsg inner ->
                                        let
                                            ( next, _ ) =
                                                Thread.update inner state
                                        in
                                        posted next

                                    _ ->
                                        Err "Unexpected message"
                            )
                        |> Expect.equal (Ok ( "Existing draft", Just (CommentId 1) ))
            , test "Norwegian built-in labels" <|
                \_ ->
                    widget [ Thread.locale Locale.nb ] (Remote.Loaded comments) (withDraft "Tekst") |> Query.fromHtml |> Expect.all [ Query.has [ S.text "Publiser kommentar" ], Query.has [ S.text "Forhåndsvis" ] ]
            ]
        , describe "Every remote state"
            [ test "resolve actions cannot mutate stale history" <|
                \_ ->
                    widget [ Thread.onResolve Resolve ] (Remote.refreshWith (Remote.Loaded comments) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)) (Thread.init "discussion") |> Query.fromHtml |> Query.findAll [ S.tag "button", S.containing [ S.text "Resolve" ], S.disabled True ] |> Query.count (Expect.equal 2)
            , test "resolve callback carries the application id and requested state" <|
                \_ ->
                    widget [ Thread.onResolve Resolve ] (Remote.Loaded comments) (Thread.init "discussion") |> Query.fromHtml |> Query.findAll [ S.tag "button", S.containing [ S.text "Resolve" ] ] |> Query.first |> Event.simulate Event.click |> Event.expect (Resolve (CommentId 1) True)
            , test "draft survives loading and history remains busy" <|
                \_ ->
                    widget [] Remote.Loading (withDraft "Draft") |> Query.fromHtml |> Expect.all [ Query.has [ S.tag "textarea", S.attribute (Attr.value "Draft") ], Query.has [ S.attribute (Attr.attribute "aria-busy" "true") ] ]
            , test "empty history still offers the composer and load more" <|
                \_ ->
                    widget [ Thread.onLoadMore More ] (Remote.Loaded []) (Thread.init "discussion") |> Query.fromHtml |> Expect.all [ Query.has [ S.text "No comments yet" ], Query.has [ S.tag "textarea" ], Query.has [ S.tag "button", S.containing [ S.text "Load more" ] ] ]
            , test "initial failure can retry while draft remains" <|
                \_ ->
                    widget [] (Remote.Failed (Remote.problem Remote.network)) (withDraft "Draft") |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Try again" ] ] |> Event.simulate Event.click |> Event.expect Retry
            , test "refresh retains comments and disables posting" <|
                \_ ->
                    widget [] (Remote.refresh (Remote.Loaded comments)) (withDraft "Draft") |> Query.fromHtml |> Expect.all [ Query.has [ S.text "Ada" ], \html -> html |> Query.find [ S.tag "button", S.containing [ S.text "Post comment" ] ] |> Query.has [ S.disabled True ] ]
            , test "failed refresh retains comments, marks them old and blocks posting" <|
                \_ ->
                    widget [] (Remote.refreshWith (Remote.Loaded comments) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)) (withDraft "Draft") |> Query.fromHtml |> Expect.all [ Query.has [ S.text "Old data" ], Query.has [ S.text "Ada" ], \html -> html |> Query.find [ S.tag "button", S.containing [ S.text "Post comment" ] ] |> Query.has [ S.disabled True ] ]
            ]
        , describe "Comment content"
            [ test "removed bodies are never rendered but replies remain" <|
                \_ ->
                    let
                        removed =
                            Thread.comment { id = CommentId 1, author = "Ada", body = "Secret removed text", at = Time.millisToPosix 0 } |> Thread.removed
                    in
                    widget [] (Remote.Loaded (removed :: List.drop 1 comments)) (Thread.init "t") |> Query.fromHtml |> Expect.all [ Query.hasNot [ S.text "Secret removed text" ], Query.has [ S.text "This comment was removed" ], Query.has [ S.text "Confirmed in Oslo." ] ]
            , test "untrusted Markdown cannot create script tags" <|
                \_ ->
                    widget [] (Remote.Loaded [ Thread.comment { id = CommentId 1, author = "Ada", body = "<script>alert(1)</script>", at = Time.millisToPosix 0 } ]) (Thread.init "t") |> Query.fromHtml |> Query.findAll [ S.tag "script" ] |> Query.count (Expect.equal 0)
            , test "reply articles have stable scoped ids" <|
                \_ ->
                    widget [] (Remote.Loaded comments) (Thread.init "order-17") |> Query.fromHtml |> Expect.all [ Query.has [ S.id "order-17-comment-1" ], Query.has [ S.id "order-17-comment-2" ], Query.has [ S.id "order-17-draft" ] ]
            ]
        , structureTests
        ]


structureTests : Test
structureTests =
    describe "Flat reply graph arrangement"
        [ test "replies are grouped and siblings retain source order" <|
            \_ ->
                Structure.arrange [ { key = "root", parent = Nothing, value = 1 }, { key = "other", parent = Nothing, value = 2 }, { key = "a", parent = Just "root", value = 3 }, { key = "b", parent = Just "root", value = 4 } ] |> List.map .value |> Expect.equal [ 1, 3, 4, 2 ]
        , test "orphans remain visible with an explicit missing-parent mark" <|
            \_ ->
                Structure.arrange [ { key = "a", parent = Just "missing", value = 1 } ] |> List.map .link |> Expect.equal [ Structure.Missing ]
        , test "cycles terminate and preserve every comment" <|
            \_ ->
                Structure.arrange [ { key = "a", parent = Just "b", value = 1 }, { key = "b", parent = Just "a", value = 2 } ] |> List.map .value |> List.sort |> Expect.equal [ 1, 2 ]
        , test "self reference is visibly marked" <|
            \_ ->
                Structure.arrange [ { key = "a", parent = Just "a", value = 1 } ] |> List.map .link |> Expect.equal [ Structure.Cycle ]
        , test "duplicate records are retained and marked" <|
            \_ ->
                Structure.arrange [ { key = "a", parent = Nothing, value = 1 }, { key = "a", parent = Nothing, value = 2 } ] |> List.map (\row -> ( row.value, row.link )) |> Expect.equal [ ( 1, Structure.Root ), ( 2, Structure.Duplicate ) ]
        , fuzz (Fuzz.list (Fuzz.intRange 0 20)) "no malformed graph loses or invents records" <|
            \parents ->
                parents
                    |> List.indexedMap
                        (\index parent ->
                            { key = String.fromInt (modBy 10 index)
                            , parent =
                                if parent == 0 then
                                    Nothing

                                else
                                    Just (String.fromInt parent)
                            , value = index
                            }
                        )
                    |> Structure.arrange
                    |> List.map .value
                    |> List.sort
                    |> Expect.equal (List.range 0 (List.length parents - 1))
        , test "a long chain is handled iteratively" <|
            \_ ->
                List.range 1 2000
                    |> List.map
                        (\n ->
                            { key = String.fromInt n
                            , parent =
                                if n == 1 then
                                    Nothing

                                else
                                    Just (String.fromInt (n - 1))
                            , value = n
                            }
                        )
                    |> Structure.arrange
                    |> List.length
                    |> Expect.equal 2000
        ]
