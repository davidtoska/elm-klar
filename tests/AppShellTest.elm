module AppShellTest exposing (suite)

{-| The address rules of `Klar.AppShell` (how a link is followed, what counts as a new
page) and the rendered frame: `state` wins wherever it stands, a framed shell is a
named region without the page-start id, Escape that a control inside used is left alone.
-}

import Browser
import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.AppShell as AppShell
import Klar.AppShell.Address as Address exposing (Effect(..), Follow(..), Landing(..))
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
        , describe "where focus goes"
            [ test "a link the shell followed to a new page sends focus to the content" <|
                \_ ->
                    nav "https://acme.test/#/orders"
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/customers"))
                        |> Tuple.first
                        |> Address.arrive (url "https://acme.test/#/customers")
                        |> Tuple.second
                        |> Expect.equal [ ResetScroll, FocusContent ]
            , test "an address the application pushed itself keeps focus where it is (route tabs, a row)" <|
                \_ ->
                    nav "https://acme.test/#/orders/10482"
                        |> Address.arrive (url "https://acme.test/#/orders/10482/items")
                        |> Tuple.second
                        |> Expect.equal [ ResetScroll ]
            , test "Enter on a link of the side menu keeps focus on that link" <|
                \_ ->
                    (nav "https://acme.test/#/orders" |> withEnterOn "https://acme.test/#/customers")
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/customers"))
                        |> Tuple.first
                        |> Address.arrive (url "https://acme.test/#/customers")
                        |> Tuple.second
                        |> Expect.equal [ ResetScroll ]
            , test "Enter on another link counts for that link only" <|
                \_ ->
                    (nav "https://acme.test/#/orders" |> withEnterOn "https://acme.test/#/reports")
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/customers"))
                        |> Tuple.first
                        |> Address.arrive (url "https://acme.test/#/customers")
                        |> Tuple.second
                        |> Expect.equal [ ResetScroll, FocusContent ]
            , test "a link in the open drawer closes it and sends focus to the content at once" <|
                \_ ->
                    (nav "https://acme.test/#/orders" |> withDrawerOpen)
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/orders?status=open"))
                        |> Expect.all
                            [ Tuple.first >> .drawerOpen >> Expect.equal False
                            , Tuple.second >> Expect.equal [ PushUrl "https://acme.test/#/orders?status=open", FocusContent ]
                            ]
            , test "a new query on the same page changes nothing" <|
                \_ ->
                    nav "https://acme.test/#/orders"
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/orders?status=open"))
                        |> Tuple.first
                        |> Address.arrive (url "https://acme.test/#/orders?status=open")
                        |> Tuple.second
                        |> Expect.equal []
            , test "the Back button to another page with the drawer open closes it and sends focus to the content" <|
                \_ ->
                    (nav "https://acme.test/#/orders" |> withDrawerOpen)
                        |> Address.arrive (url "https://acme.test/#/customers")
                        |> Expect.all
                            [ Tuple.first >> .drawerOpen >> Expect.equal False
                            , Tuple.second >> Expect.equal [ ResetScroll, FocusContent ]
                            ]
            , test "a link to an element of the page shows that element and waits for no address" <|
                \_ ->
                    nav "https://acme.test/#/orders"
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#totals"))
                        |> Expect.all
                            [ Tuple.first >> .landing >> Expect.equal Stay
                            , Tuple.second >> Expect.equal [ ShowElement "totals" ]
                            ]
            , test "the current page entered again is replaced and waits for no new page" <|
                \_ ->
                    nav "https://acme.test/#/orders"
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/orders"))
                        |> Expect.all
                            [ Tuple.first >> .landing >> Expect.equal Stay
                            , Tuple.second >> Expect.equal [ ReplaceUrl "https://acme.test/#/orders" ]
                            ]
            , test "a link elsewhere is loaded" <|
                \_ ->
                    nav "https://acme.test/#/orders"
                        |> Address.followLink (Browser.External "https://example.com/help")
                        |> Tuple.second
                        |> Expect.equal [ Load "https://example.com/help" ]
            , test "a followed link that is still on its way is forgotten once an address arrives" <|
                \_ ->
                    nav "https://acme.test/#/orders"
                        |> Address.followLink (Browser.Internal (url "https://acme.test/#/customers"))
                        |> Tuple.first
                        |> Address.arrive (url "https://acme.test/#/customers")
                        |> Tuple.first
                        |> Address.arrive (url "https://acme.test/#/reports")
                        |> Tuple.second
                        |> Expect.equal [ ResetScroll ]
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
            , test "the title of the page is in a polite live region" <|
                \_ ->
                    shell [ AppShell.pageTitle "Orders" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "aria-live" "polite"), Selector.class "klar-sr-only" ]
                        |> Query.has [ Selector.text "Orders", Selector.attribute (Attr.attribute "aria-atomic" "true") ]
            , test "the live region is there before any title, so the first title is a change" <|
                \_ ->
                    shell []
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.attribute (Attr.attribute "aria-live" "polite"), Selector.class "klar-sr-only" ]
                        |> Query.count (Expect.equal 1)
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
            , test "an Escape inside an open popup (a menu of the top bar) is the popup's, not the drawer's" <|
                \_ ->
                    shell [ AppShell.drawerOpen True, AppShell.onCloseDrawer "close" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-app-shell__chrome" ]
                        |> Event.simulate
                            (Event.custom "keydown"
                                (Encode.object
                                    [ ( "key", Encode.string "Escape" )
                                    , ( "defaultPrevented", Encode.bool False )
                                    , ( "isComposing", Encode.bool False )
                                    , ( "keyCode", Encode.int 27 )
                                    , ( "target"
                                      , element "klar-menu__item"
                                            (element "klar-popup klar-menu__popup"
                                                (element "klar-layer" (element "klar-anchor" Encode.null))
                                            )
                                      )
                                    ]
                                )
                            )
                        |> Event.toResult
                        |> Expect.err
            , test "an Escape on a control outside any popup closes the drawer" <|
                \_ ->
                    shell [ AppShell.drawerOpen True, AppShell.onCloseDrawer "close" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-app-shell__chrome" ]
                        |> Event.simulate
                            (Event.custom "keydown"
                                (Encode.object
                                    [ ( "key", Encode.string "Escape" )
                                    , ( "defaultPrevented", Encode.bool False )
                                    , ( "isComposing", Encode.bool False )
                                    , ( "keyCode", Encode.int 27 )
                                    , ( "target", element "klar-side-nav__link" (element "klar-app-shell__sidebar" Encode.null) )
                                    ]
                                )
                            )
                        |> Event.expect "close"
            , test "the live region of the title is outside the chrome, which turns inert under a dialog" <|
                \_ ->
                    shell [ AppShell.pageTitle "Orders" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-app-shell__chrome" ]
                        |> Query.findAll [ Selector.attribute (Attr.attribute "aria-live" "polite"), Selector.text "Orders" ]
                        |> Query.count (Expect.equal 0)
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


{-| An element of an event's `target` chain: its class and its parent.
-}
element : String -> Encode.Value -> Encode.Value
element className parent =
    Encode.object [ ( "className", Encode.string className ), ( "parentElement", parent ) ]


nav : String -> Address.Nav
nav address =
    { url = url address, drawerOpen = False, enterOn = Nothing, landing = Stay }


withEnterOn : String -> Address.Nav -> Address.Nav
withEnterOn address state =
    { state | enterOn = Just (url address) }


withDrawerOpen : Address.Nav -> Address.Nav
withDrawerOpen state =
    { state | drawerOpen = True }


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
