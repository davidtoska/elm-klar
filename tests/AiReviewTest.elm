module AiReviewTest exposing (suite)

import Expect
import Html exposing (Html)
import Klar.AiReview as Review
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Remote)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S


type Msg
    = Inner Review.Msg
    | Save (List (Review.Decision String))
    | Retry


data : { id : String, revision : String, title : String, before : String, after : String, rationale : String, sources : List Review.Source }
data =
    { id = "delivery", revision = "v1", title = "Delivery", before = "Bergen", after = "Oslo", rationale = "Check the source", sources = [ Review.source { label = "Customer", url = "javascript:alert(1)", excerpt = "<script>no execution</script>" } ] }


remote : Remote (List (Review.Proposal String))
remote =
    Remote.Loaded [ Review.proposal data ]


widget : List (Review.Attribute String Msg) -> Remote (List (Review.Proposal String)) -> Review.State -> Html Msg
widget attrs proposals state =
    Review.view Inner ([ Review.onSubmit Save, Review.onRetry Retry ] ++ attrs) { label = "AI review", ids = Ids.string, proposals = proposals } state


local : Review.State -> Msg -> Result String Review.State
local state msg =
    case msg of
        Inner inner ->
            Ok (Tuple.first (Review.update inner state))

        _ ->
            Err "Expected local review interaction"


choose : Int -> Review.State -> Result String Review.State
choose index state =
    widget [] remote state |> Query.fromHtml |> Query.findAll [ S.tag "input" ] |> Query.index index |> Event.simulate (Event.check True) |> Event.toResult |> Result.andThen (local state)


note : String -> Review.State -> Result String Review.State
note text state =
    widget [] remote state |> Query.fromHtml |> Query.find [ S.tag "textarea" ] |> Event.simulate (Event.input text) |> Event.toResult |> Result.andThen (local state)


approvedState : Result String Review.State
approvedState =
    choose 0 (Review.init "review")


saveButton : Html Msg -> Query.Single Msg
saveButton html =
    html |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Save review decisions" ] ]


suite : Test
suite =
    describe "AI review contract"
        [ test "nothing is approved automatically" <|
            \_ ->
                Expect.equal Nothing (Review.decisions Ids.string remote (Review.init "review"))
        , test "explicit approval yields the reviewed server revision" <|
            \_ ->
                approvedState |> Result.map (Review.decisions Ids.string remote) |> Expect.equal (Ok (Just [ { id = "delivery", revision = "v1", approved = True, reason = "" } ]))
        , test "any displayed content change invalidates approval, even without a revision bump" <|
            \_ ->
                approvedState
                    |> Result.map
                        (\state ->
                            [ { data | revision = "v2" }, { data | title = "Updated title" }, { data | before = "Trondheim" }, { data | after = "Stavanger" }, { data | rationale = "Different reason" }, { data | sources = [] } ]
                                |> List.map (\p -> Review.decisions Ids.string (Remote.Loaded [ Review.proposal p ]) state)
                        )
                    |> Expect.equal (Ok (List.repeat 6 Nothing))
        , test "duplicate ids block the entire review" <|
            \_ ->
                approvedState |> Result.map (Review.decisions Ids.string (Remote.Loaded [ Review.proposal data, Review.proposal data ])) |> Expect.equal (Ok Nothing)
        , test "unavailable, empty, refreshing and old data cannot be submitted" <|
            \_ ->
                approvedState
                    |> Result.map
                        (\state -> [ Remote.NotAsked, Remote.Loading, Remote.Failed (Remote.problem Remote.network), Remote.Loaded [], Remote.refresh remote, Remote.settle remote (Err (Remote.problem Remote.network)) ] |> List.map (\r -> Review.decisions Ids.string r state))
                    |> Expect.equal (Ok (List.repeat 6 Nothing))
        , test "reset invalidates the previous case's decisions" <|
            \_ ->
                approvedState |> Result.map (Review.reset >> Review.decisions Ids.string remote) |> Expect.equal (Ok Nothing)
        , test "rejection requires a nonblank reason and preserves raw notes" <|
            \_ ->
                let
                    rejected =
                        choose 1 (Review.init "review")

                    readWithNote text =
                        rejected |> Result.andThen (note text) |> Result.map (Review.decisions Ids.string remote)
                in
                Expect.all
                    [ \_ -> Expect.equal (Ok Nothing) (rejected |> Result.map (Review.decisions Ids.string remote))
                    , \_ -> Expect.equal (Ok Nothing) (readWithNote "   ")
                    , \_ -> Expect.equal (Ok (Just [ { id = "delivery", revision = "v1", approved = False, reason = "  Missing evidence  " } ])) (readWithNote "  Missing evidence  ")
                    ]
                    ()
        , test "saving locks submission" <|
            \_ ->
                case approvedState of
                    Ok state ->
                        widget [ Review.saving True ] remote state |> saveButton |> Query.has [ S.disabled True ]

                    Err error ->
                        Expect.fail error
        , test "write errors leave decisions available for retry" <|
            \_ ->
                case approvedState of
                    Ok state ->
                        widget [ Review.errorMaybe (Just "Save failed") ] remote state |> saveButton |> Query.has [ S.disabled False ]

                    Err error ->
                        Expect.fail error
        , test "unsafe evidence markup is inert" <|
            \_ ->
                widget [] remote (Review.init "review") |> Query.fromHtml |> Query.hasNot [ S.tag "script" ]
        , test "unsafe evidence never becomes a link" <|
            \_ ->
                widget [] remote (Review.init "review") |> Query.fromHtml |> Query.hasNot [ S.tag "a" ]
        , test "Norwegian loading text remains inside the retry focus target" <|
            \_ ->
                widget [ Review.locale Locale.nb ] Remote.Loading (Review.init "review") |> Query.fromHtml |> Query.has [ S.id "review", S.containing [ S.text "Laster AI-forslag" ] ]
        ]
