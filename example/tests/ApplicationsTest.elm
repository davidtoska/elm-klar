module ApplicationsTest exposing (suite)

import Dict
import Expect
import Html
import Html.Attributes as Attr
import Klar.PasswordInput as Password
import Page.Applications as Applications
import Page.Applications.Auth as Auth
import Page.Applications.Catalog as Catalog
import Page.Applications.Classification as Classification
import Page.Applications.Connections as Connections
import Page.Applications.Providers as Providers
import Route
import Set
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as S
import Url


auth : Auth.Model
auth =
    let
        initial =
            Auth.init
    in
    { initial | email = "alex@example.test", password = Password.setValue "demo-passphrase" initial.password }


provider : Providers.Model
provider =
    let
        initial =
            Providers.init
    in
    { initial | secret = Password.setValue "demo-example-key" initial.secret }


connection : String -> Connections.Model -> Maybe Connections.Connection
connection id model =
    Dict.get id model.connections


docStatus : Int -> Classification.Model -> Maybe Classification.Status
docStatus id model =
    List.filter (\doc -> doc.id == id) model.documents |> List.head |> Maybe.map .status


finishBatch : Classification.Model -> Classification.Model
finishBatch model =
    List.foldl finishDocument model [ 1, 2, 3, 4 ]


finishDocument : Int -> Classification.Model -> Classification.Model
finishDocument id model =
    model
        |> Classification.update (Classification.ContentClassified model.ticket id model.scenario)
        |> Tuple.first
        |> Classification.update (Classification.Completed model.ticket id model.scenario)
        |> Tuple.first


suite : Test
suite =
    describe "Connected application patterns"
        [ describe "Navigation and composition"
            [ test "the calendar page embeds the working application" <|
                \_ ->
                    Applications.view Catalog.Calendar Applications.init
                        |> Query.fromHtml
                        |> Query.find [ S.tag "iframe" ]
                        |> Query.has
                            [ S.attribute (Attr.src "/calendar-app/")
                            , S.attribute (Attr.title "Google Calendar-style application")
                            ]
            , test "every registered page round trips through its deep link" <|
                \_ ->
                    Catalog.all
                        |> List.map (\page -> Url.fromString ("https://demo.test/" ++ Route.path (Route.Application page)) |> Maybe.map Route.fromUrl)
                        |> Expect.equal (List.map (Route.Application >> Just) Catalog.all)
            , test "unknown application pages are not routed to an unrelated screen" <|
                \_ ->
                    Url.fromString "https://demo.test/#/applications/unknown"
                        |> Maybe.map Route.fromUrl
                        |> Expect.equal (Just Route.NotFound)
            , test "all application slugs are unique" <|
                \_ -> Expect.equal (List.length Catalog.all) (List.map Catalog.slug Catalog.all |> Set.fromList |> Set.size)
            , test "every page renders one main heading" <|
                \_ ->
                    Html.div [] (List.map (\page -> Applications.view page Applications.init) Catalog.all)
                        |> Query.fromHtml
                        |> Query.findAll [ S.tag "h1" ]
                        |> Query.count (Expect.equal (List.length Catalog.all))
            ]
        , describe "Account lifecycle"
            [ test "invalid credentials do not start a request" <|
                \_ -> Auth.update (Auth.Submit Catalog.SignIn) Auth.init |> Tuple.first |> .phase |> Expect.equal Auth.Idle
            , test "signup requires accepting the terms" <|
                \_ -> Auth.update (Auth.Submit Catalog.SignUp) { auth | name = "Alex" } |> Tuple.first |> .phase |> Expect.equal Auth.Idle
            , test "reset requires matching passwords" <|
                \_ -> Auth.update (Auth.Submit Catalog.ResetPassword) auth |> Tuple.first |> .phase |> Expect.equal Auth.Idle
            , test "recovery accepts an email without a password" <|
                \_ -> Auth.update (Auth.Submit Catalog.ForgotPassword) { auth | password = Password.clear auth.password } |> Tuple.first |> .phase |> Expect.equal Auth.Working
            , test "social sign-in does not require email form fields" <|
                \_ -> Auth.update (Auth.Social Catalog.SignIn "Microsoft") Auth.init |> Tuple.first |> .phase |> Expect.equal Auth.Working
            , test "leaving clears both secret fields and ignores a pending callback" <|
                \_ ->
                    let
                        pending =
                            Auth.update (Auth.Submit Catalog.SignIn) auth |> Tuple.first

                        left =
                            Auth.leave pending

                        late =
                            Auth.update (Auth.Finished pending.ticket Catalog.SignIn "Email") left |> Tuple.first
                    in
                    Expect.equal ( "", "", Auth.Idle ) ( Password.value late.password, Password.value late.confirmation, late.phase )
            , test "successful recovery uses an account-neutral confirmation" <|
                \_ ->
                    let
                        pending =
                            Auth.update (Auth.Submit Catalog.ForgotPassword) auth |> Tuple.first
                    in
                    Auth.update (Auth.Finished pending.ticket Catalog.ForgotPassword "Email") pending |> Tuple.first |> .message |> String.startsWith "If an account exists" |> Expect.equal True
            ]
        , describe "Connection authorization"
            [ test "authorization cannot skip the review step" <|
                \_ -> Connections.update (Connections.Authorize "github") Connections.init |> Tuple.first |> connection "github" |> Maybe.map .phase |> Expect.equal (Just Connections.Disconnected)
            , test "an empty repository selection cannot authorize" <|
                \_ ->
                    let
                        pending =
                            Connections.update (Connections.Connect "github") Connections.init |> Tuple.first
                    in
                    Connections.update (Connections.Authorize "github") { pending | repositories = Set.empty } |> Tuple.first |> connection "github" |> Maybe.map .phase |> Expect.equal (Just Connections.Reviewing)
            , test "cancelling consent ignores the provider callback" <|
                \_ ->
                    let
                        pending =
                            Connections.init |> Connections.update (Connections.Connect "github") |> Tuple.first |> Connections.update (Connections.Authorize "github") |> Tuple.first

                        ticket =
                            connection "github" pending |> Maybe.map .ticket |> Maybe.withDefault 0

                        cancelled =
                            Connections.update (Connections.Cancel "github") pending |> Tuple.first
                    in
                    Connections.update (Connections.Finished "github" ticket False "success") cancelled |> Tuple.first |> connection "github" |> Maybe.map .phase |> Expect.equal (Just Connections.Disconnected)
            , test "revoked access blocks imports" <|
                \_ -> Connections.init |> Connections.update (Connections.Expire "drive") |> Tuple.first |> Connections.update (Connections.Import "drive") |> Tuple.first |> connection "drive" |> Maybe.map .phase |> Expect.equal (Just Connections.Expired)
            , test "disconnecting invalidates a late import response" <|
                \_ ->
                    let
                        connected =
                            Connections.init |> Connections.update (Connections.Connect "drive") |> Tuple.first |> Connections.update (Connections.Authorize "drive") |> Tuple.first |> Connections.update (Connections.Finished "drive" 1 False "success") |> Tuple.first

                        importing =
                            Connections.update (Connections.Import "drive") connected |> Tuple.first

                        ticket =
                            connection "drive" importing |> Maybe.map .ticket |> Maybe.withDefault 0

                        removed =
                            importing |> Connections.update (Connections.RequestDisconnect "drive") |> Tuple.first |> Connections.update Connections.ConfirmDisconnect |> Tuple.first
                    in
                    Connections.update (Connections.Finished "drive" ticket True "success") removed |> Tuple.first |> connection "drive" |> Maybe.map .phase |> Expect.equal (Just Connections.Disconnected)
            ]
        , describe "Credential handling"
            [ test "verification clears the key before any delayed response" <|
                \_ -> Providers.update Providers.Verify provider |> Tuple.first |> .secret |> Password.value |> Expect.equal ""
            , test "the demo refuses production-looking credentials" <|
                \_ -> Providers.update Providers.Verify { provider | secret = Password.setValue "sk-real-looking-secret" provider.secret } |> Tuple.first |> .phase |> Expect.equal Providers.Failed
            , test "only verified connections can be made default" <|
                \_ -> Providers.update (Providers.MakeDefault "OpenRouter") Providers.init |> Tuple.first |> .defaultProvider |> Expect.equal Nothing
            , test "leaving invalidates a credential check" <|
                \_ ->
                    let
                        pending =
                            Providers.update Providers.Verify provider |> Tuple.first
                    in
                    Providers.leave pending |> Providers.update (Providers.Verified pending.ticket "OpenAI" "success") |> Tuple.first |> .credentials |> Dict.isEmpty |> Expect.equal True
            , test "a failed rotation keeps the previous verified connection" <|
                \_ ->
                    let
                        pending =
                            Providers.update Providers.Verify provider |> Tuple.first

                        saved =
                            Providers.update (Providers.Verified pending.ticket "OpenAI" "success") pending |> Tuple.first

                        rotating =
                            Providers.update Providers.Verify { saved | secret = Password.setValue "demo-replacement-key" saved.secret } |> Tuple.first
                    in
                    Providers.update (Providers.Verified rotating.ticket "OpenAI" "invalid") rotating |> Tuple.first |> .credentials |> Dict.member "OpenAI" |> Expect.equal True
            , test "removing the default leaves no dangling provider reference" <|
                \_ ->
                    let
                        pending =
                            Providers.update Providers.Verify provider |> Tuple.first

                        saved =
                            Providers.update (Providers.Verified pending.ticket "OpenAI" "success") pending |> Tuple.first
                    in
                    Providers.update Providers.ConfirmRemove saved |> Tuple.first |> .defaultProvider |> Expect.equal Nothing
            ]
        , describe "JEV queue and human review"
            [ test "mixed results include classified, uncertain and failed documents" <|
                \_ ->
                    let
                        completed =
                            Classification.update Classification.Start Classification.init |> Tuple.first |> finishBatch
                    in
                    Expect.equal [ Just (Classification.Classified "Invoice" 98), Just (Classification.Classified "Contract" 89), Just (Classification.NeedsReview "Support" 62), Just Classification.Failed ] (List.map (\id -> docStatus id completed) [ 1, 2, 3, 4 ])
            , test "a stricter threshold routes the contract to human review" <|
                \_ ->
                    let
                        initial =
                            Classification.init
                    in
                    Classification.update Classification.Start { initial | threshold = 95 } |> Tuple.first |> finishBatch |> docStatus 2 |> Expect.equal (Just (Classification.NeedsReview "Contract" 89))
            , test "human correction is preserved in the approved result" <|
                \_ -> Classification.update Classification.Start Classification.init |> Tuple.first |> finishBatch |> Classification.update (Classification.Category 3 "Invoice") |> Tuple.first |> Classification.update (Classification.Approve 3) |> Tuple.first |> docStatus 3 |> Expect.equal (Just (Classification.Approved "Invoice"))
            , test "queued documents cannot be approved without classification" <|
                \_ -> Classification.update (Classification.Approve 1) Classification.init |> Tuple.first |> docStatus 1 |> Expect.equal (Just Classification.Queued)
            , test "stopped batches ignore late results and restore the queue" <|
                \_ ->
                    let
                        pending =
                            Classification.update Classification.Start Classification.init |> Tuple.first
                    in
                    Classification.update Classification.Cancel pending |> Tuple.first |> Classification.update (Classification.Completed pending.ticket 1 "mixed") |> Tuple.first |> docStatus 1 |> Expect.equal (Just Classification.Queued)
            , test "duplicate completions cannot advance the queue twice" <|
                \_ ->
                    let
                        pending =
                            Classification.update Classification.Start Classification.init |> Tuple.first

                        completed =
                            finishDocument 1 pending
                    in
                    Classification.update (Classification.Completed pending.ticket 1 "mixed") completed |> Tuple.first |> Expect.equal completed
            , test "failed documents can be retried without losing completed results" <|
                \_ ->
                    let
                        completed =
                            Classification.update Classification.Start Classification.init |> Tuple.first |> finishBatch

                        retrying =
                            Classification.update (Classification.Retry 4) completed |> Tuple.first

                        retried =
                            finishDocument 4 retrying
                    in
                    Expect.equal ( Just (Classification.Classified "Invoice" 98), Just (Classification.NeedsReview "Other" 62), False ) ( docStatus 1 retried, docStatus 4 retried, retried.running )
            ]
        ]
