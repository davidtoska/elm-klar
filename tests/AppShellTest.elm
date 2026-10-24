module AppShellTest exposing (suite)

{-| The address rules of `Klar.AppShell` (how a link is followed, what counts as a new
page) and the rendered frame: `state` wins wherever it stands, a framed shell is a
named region without the page-start id, Escape that a control inside used is left alone.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.AppShell as AppShell
import Klar.AppShell.Address as Address exposing (Follow(..))
import Klar.Locale as Locale
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Url exposing (Url)


url : String -> Url
url text =
    Url.fromString text
        |> Maybe.withDefault { protocol = Url.Https, host = "not-a-url", port_ = Nothing, path = text, query = Nothing, fragment = Nothing }


suite : Test
suite =
    describe "Klar.AppShell"
        [ describe "following a link"
            [ test "another route is pushed" <|
                \_ ->
                    Address.follow (url "https://acme.test/#/orders") (url "https://acme.test/#/customers")
                        |> Expect.equal (Push "https://acme.test/#/customers")
            , test "the address the user is on is replaced, not pushed again" <|
                \_ ->
                    Address.follow (url "https://acme.test/#/orders") (url "https://acme.test/#/orders")
                        |> Expect.equal (Replace "https://acme.test/#/orders")
            , test "a fragment that is not a route is an element of the page" <|
                \_ ->
                    Address.follow (url "https://acme.test/#/orders") (url "https://acme.test/#order-form-email")
                        |> Expect.equal (Anchor "order-form-email")
            , test "an anchor on a page with path routing is an element too" <|
                \_ ->
                    Address.follow (url "https://acme.test/orders?page=2") (url "https://acme.test/orders?page=2#totals")
                        |> Expect.equal (Anchor "totals")
            , test "an anchor on another path is a navigation" <|
                \_ ->
                    Address.follow (url "https://acme.test/orders") (url "https://acme.test/customers#totals")
                        |> Expect.equal (Push "https://acme.test/customers#totals")
            , test "a new query on the same page is pushed" <|
                \_ ->
                    Address.follow (url "https://acme.test/#/orders") (url "https://acme.test/#/orders?status=open")
                        |> Expect.equal (Push "https://acme.test/#/orders?status=open")
            , test "an empty fragment is the start page, not an anchor" <|
                \_ ->
                    Address.follow (url "https://acme.test/#/orders") (url "https://acme.test/#")
                        |> Expect.equal (Push "https://acme.test/#")
            , test "the id of an anchor is percent-decoded" <|
                \_ ->
                    Address.targetId (url "https://acme.test/#/orders") (url "https://acme.test/#line%20one")
                        |> Expect.equal (Just "line one")
            ]
        , describe "a new page or the same page"
            [ test "another query on a hash route is the same page" <|
                \_ ->
                    Address.samePage (url "https://acme.test/#/orders?status=open") (url "https://acme.test/#/orders?status=done")
                        |> Expect.equal True
            , test "another query on a path is the same page" <|
                \_ ->
                    Address.samePage (url "https://acme.test/orders?page=1") (url "https://acme.test/orders?page=2")
                        |> Expect.equal True
            , test "another hash route is a new page" <|
                \_ ->
                    Address.samePage (url "https://acme.test/#/orders") (url "https://acme.test/#/orders/10482")
                        |> Expect.equal False
            , test "another path is a new page" <|
                \_ ->
                    Address.samePage (url "https://acme.test/orders") (url "https://acme.test/customers")
                        |> Expect.equal False
            , test "the same address is the same page" <|
                \_ ->
                    Address.samePage (url "https://acme.test/#/orders") (url "https://acme.test/#/orders")
                        |> Expect.equal True
            ]
        , describe "the frame"
            [ test "a hand-wired id after the others is used" <|
                \_ ->
                    shell [ AppShell.id "first", AppShell.id "ops" ]
                        |> Query.fromHtml
                        |> Query.has [ Selector.id "ops" ]
            , test "a framed shell is a named region, not the main landmark" <|
                \_ ->
                    shell [ AppShell.height 400 ]
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ Selector.tag "main" ] >> Query.count (Expect.equal 0)
                            , Query.find [ Selector.id "ops-content" ]
                                >> Query.has [ Selector.attribute (Attr.attribute "role" "region") ]
                            , Query.findAll [ Selector.id "klar-page-start" ] >> Query.count (Expect.equal 0)
                            ]
            , test "a full shell has the main landmark and the start of the page" <|
                \_ ->
                    shell []
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ Selector.tag "main" ] >> Query.count (Expect.equal 1)
                            , Query.findAll [ Selector.id "klar-page-start" ] >> Query.count (Expect.equal 1)
                            ]
            , test "the region of a framed shell is named in the language of the shell" <|
                \_ ->
                    shell [ AppShell.height 400, AppShell.locale Locale.nb ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "ops-content" ]
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Innhold") ]
            , test "Escape in the open drawer closes it" <|
                \_ ->
                    shell [ AppShell.drawerOpen True, AppShell.onCloseDrawer "close" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-app-shell__chrome" ]
                        |> Event.simulate (Event.custom "keydown" (escape False))
                        |> Event.expect "close"
            , test "an Escape that a control inside used already is left alone" <|
                \_ ->
                    shell [ AppShell.drawerOpen True, AppShell.onCloseDrawer "close" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-app-shell__chrome" ]
                        |> Event.simulate (Event.custom "keydown" (escape True))
                        |> Event.toResult
                        |> Expect.err
            , test "the Escape that ends a composition is left alone" <|
                \_ ->
                    shell [ AppShell.drawerOpen True, AppShell.onCloseDrawer "close" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-app-shell__chrome" ]
                        |> Event.simulate
                            (Event.custom "keydown"
                                (Encode.object
                                    [ ( "key", Encode.string "Escape" )
                                    , ( "defaultPrevented", Encode.bool False )
                                    , ( "isComposing", Encode.bool True )
                                    , ( "keyCode", Encode.int 229 )
                                    ]
                                )
                            )
                        |> Event.toResult
                        |> Expect.err
            ]
        ]


escape : Bool -> Encode.Value
escape prevented =
    Encode.object
        [ ( "key", Encode.string "Escape" )
        , ( "defaultPrevented", Encode.bool prevented )
        , ( "isComposing", Encode.bool False )
        , ( "keyCode", Encode.int 27 )
        ]


shell : List (AppShell.Attribute String) -> Html String
shell attributes =
    AppShell.view
        ([ AppShell.id "ops"
         , AppShell.sidebar (Html.text "menu")
         , AppShell.onToggleSidebar "toggle"
         ]
            ++ attributes
        )
        [ Html.text "page" ]
