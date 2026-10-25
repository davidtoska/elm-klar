module BreadcrumbsTest exposing (suite)

{-| `Klar.Breadcrumbs`: how a trail folds, the current crumb, the "more" button and its
list, the keys of the list, button crumbs and a list that closes itself when the trail
changes under it.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Breadcrumbs as Breadcrumbs
import Klar.Locale as Locale
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = CrumbsMsg Breadcrumbs.Msg
    | DrillUp Int


{-| A trail of `n` crumbs: links to levels 1 .. n-1 and the current page last.
-}
trail : Int -> List (Breadcrumbs.Crumb Msg)
trail n =
    List.map (\level -> Breadcrumbs.link { label = "Level " ++ String.fromInt level, href = "#/level/" ++ String.fromInt level }) (List.range 1 (n - 1))
        ++ [ Breadcrumbs.text "Current page" ]


crumbs : List (Breadcrumbs.Attribute Msg) -> Breadcrumbs.State -> Html Msg
crumbs attributes state =
    Breadcrumbs.view CrumbsMsg attributes state


start : Breadcrumbs.State
start =
    Breadcrumbs.init "trail"


{-| The state after the message the element sends for the event.
-}
after : List Selector.Selector -> ( String, Encode.Value ) -> Breadcrumbs.State -> Html Msg -> Breadcrumbs.State
after selectors event state html =
    case html |> Query.fromHtml |> Query.find selectors |> Event.simulate event |> Event.toResult of
        Ok (CrumbsMsg m) ->
            Tuple.first (Breadcrumbs.update m state)

        _ ->
            state


opened : List (Breadcrumbs.Attribute Msg) -> Breadcrumbs.State
opened attributes =
    after [ Selector.id "trail-more" ] Event.click start (crumbs attributes start)


key : String -> ( String, Encode.Value )
key name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "isComposing", Encode.bool False )
            , ( "keyCode", Encode.int 0 )
            ]
        )


suite : Test
suite =
    describe "Klar.Breadcrumbs"
        [ describe "folding"
            [ test "a trail of maxItems crumbs shows them all" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 4) ] start
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ Selector.class "klar-breadcrumbs__item" ] >> Query.count (Expect.equal 4)
                            , Query.findAll [ Selector.id "trail-more" ] >> Query.count (Expect.equal 0)
                            ]
            , test "one crumb more is shown whole: a button for one crumb saves no room" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 5) ] start
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ Selector.class "klar-breadcrumbs__item" ] >> Query.count (Expect.equal 5)
                            , Query.findAll [ Selector.id "trail-more" ] >> Query.count (Expect.equal 0)
                            ]
            , test "two crumbs more fold into the more button, after the first crumb" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6) ] start
                        |> Query.fromHtml
                        |> Expect.all
                            [ -- first, more, and the last three
                              Query.findAll [ Selector.class "klar-breadcrumbs__item" ] >> Query.count (Expect.equal 5)
                            , Query.find [ Selector.id "trail-more" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Show 2 hidden levels") ]
                            , Query.has [ Selector.text "Level 1" ]
                            , Query.hasNot [ Selector.text "Level 2" ]
                            , Query.hasNot [ Selector.text "Level 3" ]
                            , Query.has [ Selector.text "Level 4" ]
                            ]
            , test "maxItems below 2 counts as 2" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6), Breadcrumbs.maxItems 0 ] start
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "trail-more" ]
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Show 4 hidden levels") ]
            , test "the more button speaks Norwegian" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 7), Breadcrumbs.locale Locale.nb ] start
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "trail-more" ]
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Vis 3 skjulte nivåer") ]
            , test "viewStatic never folds" <|
                \_ ->
                    Breadcrumbs.viewStatic [ Breadcrumbs.items (trail 9) ]
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "klar-breadcrumbs__item" ]
                        |> Query.count (Expect.equal 9)
            ]
        , describe "the current page"
            [ test "the last crumb is the current page, as text, even when it is a link" <|
                \_ ->
                    Breadcrumbs.viewStatic
                        [ Breadcrumbs.items
                            [ Breadcrumbs.link { label = "Orders", href = "#/orders" }
                            , Breadcrumbs.link { label = "Order 10482", href = "#/orders/10482" }
                            ]
                        ]
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.attribute (Attr.attribute "aria-current" "page") ] >> Query.has [ Selector.tag "span", Selector.text "Order 10482" ]
                            , Query.findAll [ Selector.tag "a" ] >> Query.count (Expect.equal 1)
                            ]
            , test "the trail is a named nav landmark with an ordered list" <|
                \_ ->
                    Breadcrumbs.viewStatic [ Breadcrumbs.items (trail 3) ]
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ Selector.tag "nav", Selector.attribute (Attr.attribute "aria-label" "Breadcrumb") ]
                            , Query.findAll [ Selector.tag "ol" ] >> Query.count (Expect.equal 1)
                            ]
            ]
        , describe "button crumbs"
            [ test "a button crumb sends its message" <|
                \_ ->
                    Breadcrumbs.viewStatic [ Breadcrumbs.items [ Breadcrumbs.button "2026" (DrillUp 2026), Breadcrumbs.text "March" ] ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Event.simulate Event.click
                        |> Event.expect (DrillUp 2026)
            , test "a button crumb as the last crumb is the current level, as text" <|
                \_ ->
                    Breadcrumbs.viewStatic [ Breadcrumbs.items [ Breadcrumbs.text "All years", Breadcrumbs.button "2026" (DrillUp 2026) ] ]
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 0)
                            , Query.find [ Selector.attribute (Attr.attribute "aria-current" "page") ] >> Query.has [ Selector.text "2026" ]
                            ]
            ]
        , describe "the list of hidden levels"
            [ test "it is closed at first, and the button names no list" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6) ] start
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "trail-more" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-expanded" "false") ]
                            , Query.findAll [ Selector.id "trail-hidden" ] >> Query.count (Expect.equal 0)
                            ]
            , test "a click opens it, and the button names the list that is there" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6) ] (opened [ Breadcrumbs.items (trail 6) ])
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "trail-more" ]
                                >> Query.has [ Selector.attribute (Attr.attribute "aria-expanded" "true"), Selector.attribute (Attr.attribute "aria-controls" "trail-hidden") ]
                            , Query.find [ Selector.id "trail-hidden" ] >> Query.has [ Selector.text "Level 2", Selector.text "Level 3" ]
                            ]
            , test "Escape closes it and is used up, so a drawer around it leaves the press alone" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6) ] (opened [ Breadcrumbs.items (trail 6) ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-layer" ]
                        |> Event.simulate (key "Escape")
                        |> Event.toResult
                        |> Result.map
                            (\msg ->
                                case msg of
                                    CrumbsMsg m ->
                                        Breadcrumbs.isOpen (Tuple.first (Breadcrumbs.update m (opened [ Breadcrumbs.items (trail 6) ])))

                                    _ ->
                                        True
                            )
                        |> Expect.equal (Ok False)
            , test "Tab closes it too" <|
                \_ ->
                    let
                        open =
                            opened [ Breadcrumbs.items (trail 6) ]
                    in
                    crumbs [ Breadcrumbs.items (trail 6) ] open
                        |> after [ Selector.class "klar-layer" ] (key "Tab") open
                        |> Breadcrumbs.isOpen
                        |> Expect.equal False
            , test "ArrowDown on the button opens it" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6) ] start
                        |> after [ Selector.id "trail-more" ] (key "ArrowDown") start
                        |> Breadcrumbs.isOpen
                        |> Expect.equal True
            , test "the arrow keys move between the hidden links" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 6) ] (opened [ Breadcrumbs.items (trail 6) ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "trail-hidden-0" ]
                        |> Event.simulate (key "ArrowDown")
                        |> Event.toResult
                        |> Result.map (\_ -> ())
                        |> Expect.equal (Ok ())
            , test "a list opened for another trail is not drawn" <|
                \_ ->
                    crumbs [ Breadcrumbs.items (trail 7) ] (opened [ Breadcrumbs.items (trail 6) ])
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ Selector.id "trail-hidden" ] >> Query.count (Expect.equal 0)
                            , Query.find [ Selector.id "trail-more" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-expanded" "false") ]
                            ]
            , test "close from the application closes it" <|
                \_ ->
                    opened [ Breadcrumbs.items (trail 6) ]
                        |> Breadcrumbs.close
                        |> Tuple.first
                        |> Breadcrumbs.isOpen
                        |> Expect.equal False
            ]
        ]
