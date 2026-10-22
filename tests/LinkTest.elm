module LinkTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html
import Html.Attributes as Attr
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Icon as Icon
import Klar.Link as Link
import Klar.Link.Address as Address
import Klar.Link.Click as Click
import Klar.Locale as Locale
import Support.ActionsQuery as ActionsQuery
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Link"
        [ externalTests
        , pathTests
        , clickTests
        , renderTests
        , attributeTests
        , eventTests
        ]



-- ADDRESSES OUTSIDE THE APPLICATION


{-| The address as a name for the test, with the control characters made visible.
-}
named : String -> String
named text =
    "[" ++ String.map visible text ++ "]"


visible : Char -> Char
visible c =
    if Char.toCode c < 0x20 then
        '¤'

    else
        c


accepted : String -> Test
accepted text =
    test ("accepts " ++ named text) <|
        \_ ->
            case Address.external text of
                Just _ ->
                    Expect.pass

                Nothing ->
                    Expect.fail "should have been accepted"


refused : String -> Test
refused text =
    test ("refuses " ++ named text) <|
        \_ ->
            Address.external text
                |> Expect.equal Nothing


externalTests : Test
externalTests =
    describe "external"
        [ describe "the four schemes that may be a link"
            [ accepted "https://example.com"
            , accepted "http://example.com/orders?page=2#top"
            , accepted "HTTPS://EXAMPLE.COM/Orders"
            , accepted "  https://example.com/orders  "
            , accepted "https://user@example.com:8080/x"
            , accepted "http://[::1]:3000/"
            , accepted "mailto:ada@example.com"
            , accepted "mailto:ada@example.com?subject=Order%2010001"
            , accepted "MAILTO:ada@example.com,grace@example.com"
            , accepted "tel:+4722000000"
            , accepted "TEL:22000000;ext=5"
            ]
        , describe "everything else is refused"
            [ refused "javascript:alert(1)"
            , refused "JavaScript:alert(1)"
            , refused "  javascript:alert(1)"
            , refused "javascript://example.com/%0Aalert(1)"
            , refused "data:text/html,<script>alert(1)</script>"
            , refused "vbscript:msgbox(1)"
            , refused "file:///etc/passwd"
            , refused "blob:https://example.com/1234"
            , refused "ftp://example.com/file"
            , refused "ws://example.com"
            , refused "sms:+4722000000"
            , refused "about:blank"
            , refused "x-custom:run"
            ]
        , describe "a browser deletes tabs and line breaks from an address, so they are refused"
            [ refused "java\tscript:alert(1)"
            , refused "java\u{000D}\nscript:alert(1)"
            , refused "\u{0001}javascript:alert(1)"
            , refused "jav&#x09;ascript:alert(1)"
            , refused "https://example.com/\u{0000}"
            , refused "https://exa\tmple.com"
            , refused "https://example.com/a b"
            , refused "https://example.com\\evil.com"
            ]
        , describe "an address that is not complete"
            [ refused ""
            , refused "   "
            , refused "https:"
            , refused "https://"
            , refused "https:///orders"
            , refused "https://:8080/"
            , refused "https://user@/x"
            , refused "http:/example.com"
            , refused "http:example.com"
            , refused "https:\\\\example.com"
            , refused "//example.com"
            , refused "/orders/12"
            , refused "example.com"
            , refused "mailto:"
            , refused "mailto:nobody"
            , refused "mailto:@example.com"
            , refused "mailto:?subject=hello"
            , refused "tel:"
            , refused "tel:call-me"
            ]
        , fuzz anyAddress "whatever the text, a link that was made has one of the four schemes" <|
            \text ->
                case Address.external text of
                    Just checked ->
                        Expect.all
                            [ \_ -> startsWithAllowedScheme checked.href |> Expect.equal True
                            , \_ -> String.any (\c -> Char.toCode c <= 0x20 || Char.toCode c == 0x7F || c == '\\') checked.href |> Expect.equal False
                            ]
                            ()

                    Nothing ->
                        Expect.pass
        , test "the kind says what the address is" <|
            \_ ->
                Expect.all
                    [ \_ -> Address.external "https://example.com" |> Maybe.map .kind |> Expect.equal (Just Address.Web)
                    , \_ -> Address.external "mailto:ada@example.com" |> Maybe.map .kind |> Expect.equal (Just Address.Email)
                    , \_ -> Address.external "tel:+4722000000" |> Maybe.map .kind |> Expect.equal (Just Address.Phone)
                    ]
                    ()
        ]


startsWithAllowedScheme : String -> Bool
startsWithAllowedScheme address =
    let
        lower =
            String.toLower address
    in
    List.any (\scheme -> String.startsWith scheme lower) [ "http://", "https://", "mailto:", "tel:" ]


{-| Text that is hard on the check: a scheme (the allowed ones, the dangerous ones, the
ones disguised with a space or a line break) followed by anything.
-}
anyAddress : Fuzzer String
anyAddress =
    Fuzz.oneOf
        [ Fuzz.string
        , Fuzz.map2 (\scheme rest -> scheme ++ rest)
            (Fuzz.oneOf (List.map Fuzz.constant [ "http://", "https://", "mailto:", "tel:", "javascript:", "data:", "jav\tascript:", " javascript:", "//", "HTTP:", "\nhttps://", "https:\\\\" ]))
            Fuzz.string
        ]



-- ADDRESSES INSIDE THE APPLICATION


pathTests : Test
pathTests =
    describe "internal"
        [ test "a path, a route in the fragment and a query stay as they are" <|
            \_ ->
                Expect.all
                    [ \_ -> Address.path "/orders/12" |> Expect.equal "/orders/12"
                    , \_ -> Address.path "#/orders/12" |> Expect.equal "#/orders/12"
                    , \_ -> Address.path "?page=2&sort=date" |> Expect.equal "?page=2&sort=date"
                    , \_ -> Address.path "/" |> Expect.equal "/"
                    , \_ -> Address.path "/orders?x=1#top" |> Expect.equal "/orders?x=1#top"
                    ]
                    ()
        , test "a text that is not a path of the application becomes one" <|
            \_ ->
                Expect.all
                    [ \_ -> Address.path "orders/12" |> Expect.equal "/orders/12"
                    , \_ -> Address.path "" |> Expect.equal "/"
                    , \_ -> Address.path "javascript:alert(1)" |> Expect.equal "/javascript:alert(1)"
                    , \_ -> Address.path "https://evil.example/x" |> Expect.equal "/https://evil.example/x"
                    ]
                    ()
        , test "several slashes become one, so the address cannot be another site" <|
            \_ ->
                Expect.all
                    [ \_ -> Address.path "//evil.example/x" |> Expect.equal "/evil.example/x"
                    , \_ -> Address.path "///evil.example" |> Expect.equal "/evil.example"
                    , \_ -> Address.path "/\\evil.example" |> Expect.equal "/evil.example"
                    , \_ -> Address.path "\\\\evil.example" |> Expect.equal "/evil.example"
                    ]
                    ()
        , test "control characters, which a browser deletes before it reads the address, are removed first" <|
            \_ ->
                Expect.all
                    [ \_ -> Address.path "/\t/evil.example" |> Expect.equal "/evil.example"
                    , \_ -> Address.path "/\n/evil.example" |> Expect.equal "/evil.example"
                    , \_ -> Address.path "java\tscript:alert(1)" |> Expect.equal "/javascript:alert(1)"
                    , \_ -> Address.path "\u{0000}/orders" |> Expect.equal "/orders"
                    ]
                    ()
        , fuzz anyPath "the result is a path, a fragment or a query, never another site" <|
            \text ->
                let
                    result =
                        Address.path text
                in
                Expect.all
                    [ \_ -> insideApplication result |> Expect.equal True
                    , \_ -> Address.path result |> Expect.equal result
                    ]
                    ()
        ]


insideApplication : String -> Bool
insideApplication result =
    case String.toList result of
        '#' :: _ ->
            noControls result

        '?' :: _ ->
            noControls result

        [ '/' ] ->
            True

        '/' :: second :: _ ->
            second /= '/' && second /= '\\' && noControls result

        _ ->
            False


noControls : String -> Bool
noControls text =
    not (String.any (\c -> Char.toCode c < 0x20 || (Char.toCode c >= 0x7F && Char.toCode c <= 0x9F)) text)


anyPath : Fuzzer String
anyPath =
    Fuzz.oneOf
        [ Fuzz.string
        , Fuzz.map2 (\start rest -> start ++ rest)
            (Fuzz.oneOf (List.map Fuzz.constant [ "//", "\\\\", "/\\", "/\t/", "\t//", "javascript:", " //", "/", "#", "?", "\u{0000}/", "///\n" ]))
            Fuzz.string
        ]



-- WHICH CLICKS THE APPLICATION MAY TAKE OVER


click : List ( String, Encode.Value ) -> Encode.Value
click fields =
    Encode.object fields


clickTests : Test
clickTests =
    describe "which clicks are plain"
        [ test "the main button with no modifier key" <|
            \_ ->
                decides (click [ ( "button", Encode.int 0 ), ( "ctrlKey", Encode.bool False ), ( "metaKey", Encode.bool False ), ( "shiftKey", Encode.bool False ), ( "altKey", Encode.bool False ) ])
                    |> Expect.equal True
        , test "an event without the fields counts as plain (a click made by a test)" <|
            \_ ->
                decides (click []) |> Expect.equal True
        , test "Ctrl, Cmd, Shift and Alt each make it a click for the browser" <|
            \_ ->
                Expect.all
                    [ \_ -> decides (click [ ( "ctrlKey", Encode.bool True ) ]) |> Expect.equal False
                    , \_ -> decides (click [ ( "metaKey", Encode.bool True ) ]) |> Expect.equal False
                    , \_ -> decides (click [ ( "shiftKey", Encode.bool True ) ]) |> Expect.equal False
                    , \_ -> decides (click [ ( "altKey", Encode.bool True ) ]) |> Expect.equal False
                    ]
                    ()
        , test "the middle and the right button" <|
            \_ ->
                Expect.all
                    [ \_ -> decides (click [ ( "button", Encode.int 1 ) ]) |> Expect.equal False
                    , \_ -> decides (click [ ( "button", Encode.int 2 ) ]) |> Expect.equal False
                    ]
                    ()
        ]


decides : Encode.Value -> Bool
decides event =
    Decode.decodeValue Click.plain event
        |> Result.map (\_ -> True)
        |> Result.withDefault False



-- WHAT IS DRAWN


ordersLink : Link.Target
ordersLink =
    Link.internal "/orders"


website : Link.Target
website =
    Link.external "https://example.com/docs"
        |> Maybe.withDefault ordersLink


emailLink : Link.Target
emailLink =
    Link.external "mailto:ada@example.com"
        |> Maybe.withDefault ordersLink


phoneLink : Link.Target
phoneLink =
    Link.external "tel:+4722000000"
        |> Maybe.withDefault ordersLink


link : List (Link.Attribute msg) -> Link.Target -> Html.Html msg
link attributes target =
    Link.view attributes target "Orders"


href : String -> Selector
href url =
    Selector.attribute (Attr.href url)


attribute : String -> String -> Selector
attribute name value =
    Selector.attribute (Attr.attribute name value)


hasNoTarget : Html.Html msg -> Expectation
hasNoTarget html =
    html
        |> Query.fromHtml
        |> Expect.all
            [ Query.hasNot [ attribute "target" "_blank" ]
            , Query.hasNot [ Selector.attribute (Attr.rel "noopener noreferrer") ]
            , ActionsQuery.absent [ Selector.class "klar-link__external" ]
            , ActionsQuery.absent [ Selector.class "klar-sr-only" ]
            ]


renderTests : Test
renderTests =
    describe "view"
        [ test "a page of the application is a plain anchor" <|
            \_ ->
                link [] ordersLink
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "a", href "/orders", Selector.text "Orders" ]
                        , Query.hasNot [ attribute "target" "_blank" ]
                        ]
        , test "it is not marked as leaving the application" <|
            \_ ->
                hasNoTarget (link [] ordersLink)
        , test "a page on the web opens in a new tab, safely" <|
            \_ ->
                link [] website
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ href "https://example.com/docs" ]
                        , Query.has [ attribute "target" "_blank" ]
                        , Query.has [ Selector.attribute (Attr.rel "noopener noreferrer") ]
                        ]
        , test "and says so: an icon, and a text for screen readers" <|
            \_ ->
                link [] website
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-link__external" ]
                        , Query.find [ Selector.class "klar-link__external" ] >> Query.has [ Selector.class "klar-icon--external-link" ]
                        , Query.find [ Selector.class "klar-sr-only" ] >> Query.has [ Selector.exactText " (opens in a new tab)" ]
                        , Query.find [ Selector.class "klar-link__external" ] >> Query.has [ attribute "aria-hidden" "true" ]
                        ]
        , test "the text for screen readers follows the locale" <|
            \_ ->
                link [ Link.locale Locale.nb ] website
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-sr-only" ]
                    |> Query.has [ Selector.exactText " (åpnes i en ny fane)" ]
        , test "the text of the link comes before the text for screen readers, in one element" <|
            \_ ->
                link [] website
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-link__text" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Orders" ]
                        , Query.has [ Selector.class "klar-sr-only" ]
                        ]
        , test "an email address and a telephone number open in the same tab, unmarked" <|
            \_ ->
                Expect.all
                    [ \_ -> hasNoTarget (link [] emailLink)
                    , \_ -> hasNoTarget (link [] phoneLink)
                    , \_ -> link [] emailLink |> Query.fromHtml |> Query.has [ href "mailto:ada@example.com" ]
                    , \_ -> link [] phoneLink |> Query.fromHtml |> Query.has [ href "tel:+4722000000" ]
                    ]
                    ()
        , test "a link that cannot be built from a dangerous address leaves the choice to the application" <|
            \_ ->
                Link.external "javascript:alert(1)"
                    |> Expect.equal Nothing
        , test "a text of the application that looks like a script is a path of the application" <|
            \_ ->
                link [] (Link.internal "javascript:alert(1)")
                    |> Query.fromHtml
                    |> Query.has [ href "/javascript:alert(1)" ]
        ]


attributeTests : Test
attributeTests =
    describe "attributes"
        [ test "current: aria-current page, and only then" <|
            \_ ->
                Expect.all
                    [ \_ -> link [ Link.current True ] ordersLink |> Query.fromHtml |> Query.has [ attribute "aria-current" "page", Selector.class "klar-link--current" ]
                    , \_ -> link [ Link.current False ] ordersLink |> Query.fromHtml |> Query.hasNot [ attribute "aria-current" "page" ]
                    , \_ -> link [] ordersLink |> Query.fromHtml |> Query.hasNot [ attribute "aria-current" "page" ]
                    , \_ -> link [ Link.current True, Link.current False ] ordersLink |> Query.fromHtml |> Query.hasNot [ attribute "aria-current" "page" ]
                    ]
                    ()
        , describe "disabled"
            [ test "has no address, is not a tab stop, and says it is unavailable" <|
                \_ ->
                    link [ Link.disabled True ] ordersLink
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ Selector.tag "a", attribute "role" "link", attribute "aria-disabled" "true", Selector.class "klar-link--disabled" ]
                            , Query.hasNot [ href "/orders" ]
                            , Query.hasNot [ Selector.attribute (Attr.tabindex 0) ]
                            ]
            , test "a disabled link to another site is not marked as opening a tab" <|
                \_ ->
                    link [ Link.disabled True ] website
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.hasNot [ attribute "target" "_blank" ]
                            , ActionsQuery.absent [ Selector.class "klar-link__external" ]
                            , ActionsQuery.absent [ Selector.class "klar-sr-only" ]
                            ]
            , test "disabled False is an ordinary link again" <|
                \_ ->
                    link [ Link.disabled True, Link.disabled False ] ordersLink
                        |> Query.fromHtml
                        |> Query.has [ href "/orders" ]
            ]
        , test "inline is the default, and standalone replaces it, the later one winning" <|
            \_ ->
                Expect.all
                    [ \_ -> link [] ordersLink |> Query.fromHtml |> Query.has [ Selector.class "klar-link--inline" ]
                    , \_ -> link [ Link.standalone ] ordersLink |> Query.fromHtml |> Query.has [ Selector.class "klar-link--standalone" ]
                    , \_ -> link [ Link.standalone ] ordersLink |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-link--inline" ]
                    , \_ -> link [ Link.standalone, Link.inline ] ordersLink |> Query.fromHtml |> Query.has [ Selector.class "klar-link--inline" ]
                    ]
                    ()
        , test "truncate adds the whole text as the tooltip" <|
            \_ ->
                Link.view [ Link.truncate ] ordersLink "Order 10001 for a customer with a very long name"
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-link--truncate", Selector.attribute (Attr.title "Order 10001 for a customer with a very long name") ]
        , test "an icon before the text is decoration" <|
            \_ ->
                link [ Link.icon Icon.fileText ] ordersLink
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-link__icon" ]
                    |> Query.has [ Selector.class "klar-icon--file-text", attribute "aria-hidden" "true" ]
        , test "id" <|
            \_ ->
                link [ Link.id "orders-link" ] ordersLink
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "orders-link" ]
        ]



-- A CLICK THAT THE APPLICATION TAKES OVER


type Msg
    = Opened


plainClick : ( String, Encode.Value )
plainClick =
    Event.click


withModifier : String -> ( String, Encode.Value )
withModifier name =
    Event.custom "click" (Encode.object [ ( name, Encode.bool True ) ])


middleButton : ( String, Encode.Value )
middleButton =
    Event.custom "click" (Encode.object [ ( "button", Encode.int 1 ) ])


eventTests : Test
eventTests =
    describe "onClick"
        [ test "a plain click sends the message and keeps the browser from following the link" <|
            \_ ->
                link [ Link.onClick Opened ] ordersLink
                    |> Query.fromHtml
                    |> Event.simulate plainClick
                    |> Expect.all
                        [ Event.expect Opened
                        , Event.expectPreventDefault
                        ]
        , test "a click with Ctrl, Cmd, Shift or Alt is left to the browser: nothing is sent" <|
            \_ ->
                Expect.all
                    [ \_ -> leftAlone (withModifier "ctrlKey")
                    , \_ -> leftAlone (withModifier "metaKey")
                    , \_ -> leftAlone (withModifier "shiftKey")
                    , \_ -> leftAlone (withModifier "altKey")
                    , \_ -> leftAlone middleButton
                    ]
                    ()
        , test "a disabled link sends nothing" <|
            \_ ->
                link [ Link.onClick Opened, Link.disabled True ] ordersLink
                    |> Query.fromHtml
                    |> Event.simulate plainClick
                    |> Event.toResult
                    |> Expect.err
        , test "a link without onClick has no handler" <|
            \_ ->
                link [] ordersLink
                    |> Query.fromHtml
                    |> Event.simulate plainClick
                    |> Event.toResult
                    |> Expect.err
        ]


leftAlone : ( String, Encode.Value ) -> Expectation
leftAlone event =
    link [ Link.onClick Opened ] ordersLink
        |> Query.fromHtml
        |> Event.simulate event
        |> Event.toResult
        |> Expect.err
