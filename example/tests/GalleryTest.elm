module GalleryTest exposing (suite)

import Dict
import Expect
import Html
import Klar.Button as Button
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Settings as Settings
import Page.Gallery as Gallery
import Page.Gallery.Catalog as Catalog exposing (Section(..))
import Route
import Set
import Showcase.Config as Config
import Showcase.Options as Options
import Showcase.Playground as Playground
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as S
import Url


suite : Test
suite =
    describe "Component playground"
        [ test "every page has a unique, addressable component URL" <|
            \_ ->
                let
                    slugs =
                        List.map Catalog.slug Catalog.pages

                    roundTrip page =
                        Url.fromString ("https://demo.test/" ++ Route.path (Route.Components (Just (Catalog.slug page))))
                            |> Maybe.map Route.fromUrl
                in
                Expect.all
                    [ \_ -> Expect.equal (List.length slugs) (Set.size (Set.fromList slugs))
                    , \_ -> List.map roundTrip Catalog.pages |> Expect.equal (List.map (Catalog.slug >> Just >> Route.Components >> Just) Catalog.pages)
                    , \_ -> List.map (Catalog.slug >> Catalog.fromSlug) Catalog.pages |> Expect.equal (List.map Just Catalog.pages)
                    , \_ -> Expect.equal "form-layout" (Catalog.componentSlug "Form.Layout")
                    ]
                    ()
        , test "overrides survive navigation without leaking to another component" <|
            \_ ->
                let
                    model =
                        Playground.init |> Playground.select "Button" |> Playground.update (Playground.Set "Button" "loading" "True") |> Playground.select "Badge"
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Config.get (Playground.current model) "Badge" "loading")
                    , \_ -> Expect.equal (Just "True") (Config.get (Playground.config "Button" model) "Button" "loading")
                    ]
                    ()
        , test "baseline and individual reset preserve other overrides" <|
            \_ ->
                let
                    model =
                        Playground.init |> Playground.select "Button" |> Playground.update (Playground.Set "Button" "loading" "True") |> Playground.update (Playground.Set "Button" "size" "Large")
                in
                Expect.all
                    [ \_ -> model |> Playground.update (Playground.Baseline True) |> Playground.current |> .values |> Expect.equal Dict.empty
                    , \_ -> model |> Playground.update (Playground.Clear "Button" "loading") |> Playground.current |> .values |> Expect.equal (Dict.singleton "size" "Large")
                    , \_ -> model |> Playground.update (Playground.Reset "Button") |> Playground.current |> .values |> Expect.equal Dict.empty
                    ]
                    ()
        , test "typed controls change the real button and omit removes a flag" <|
            \_ ->
                let
                    config =
                        { component = "Button", values = Dict.fromList [ ( "size", "Large" ), ( "loading", "True" ), ( "primary", "omit" ), ( "content", "Configured label" ) ] }
                in
                Options.buttonView config (Options.klarButton config (Config.keep config "Button" "primary" Button.primary)) "Save"
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ S.class "klar-button--lg", S.class "klar-button--loading" ]
                        , Query.hasNot [ S.class "klar-button--primary" ]
                        , Query.has [ S.text "Configured label" ]
                        ]
        , test "refreshing and stale retain the example data" <|
            \_ ->
                let
                    apply value =
                        Config.remote { component = "Table", values = Dict.singleton "remote" value } "Table" "remote" (Remote.Loaded [ 1, 2 ])
                in
                Expect.all
                    [ \_ -> Expect.equal (Just [ 1, 2 ]) (Remote.toMaybe (apply "Refreshing"))
                    , \_ -> Expect.equal True (Remote.isRefreshing (apply "Refreshing"))
                    , \_ -> Expect.equal True (Remote.isStale (apply "Stale"))
                    ]
                    ()
        , describe "Every component has visible examples"
            (List.map
                (\page ->
                    test (Catalog.title page) <|
                        \_ ->
                            Gallery.init
                                |> Gallery.ensure page
                                |> Tuple.first
                                |> Gallery.view Settings.default Locale.en (Just page)
                                |> Query.fromHtml
                                |> Query.find [ S.class "playground-preview" ]
                                |> Query.findAll [ S.class (exampleClass (Catalog.title page)) ]
                                |> Query.count (Expect.greaterThan 0)
                )
                Catalog.pages
            )
        ]


{-| Some scenario pages render their components directly rather than in a
documentation stage. Check the actual component, not just a section heading.
-}
exampleClass : String -> String
exampleClass name =
    case name of
        "ServerList" ->
            "klar-table"

        "CardList" ->
            "klar-card-list"

        "WorkQueue" ->
            "klar-work-queue"

        "ConflictResolver" ->
            "klar-conflict-resolver"

        "AuditLog" ->
            "klar-audit-log"

        "NotificationCenter" ->
            "klar-notification-center"

        "Kanban" ->
            "klar-kanban"

        "CommentThread" ->
            "klar-comment-thread"

        "CodeBlock" ->
            "klar-source"

        "QuantityInput" ->
            "klar-quantity"

        "AiReview" ->
            "klar-ai-review"

        "AiChat" ->
            "klar-ai-chat"

        _ ->
            "showcase-doc__stage"
