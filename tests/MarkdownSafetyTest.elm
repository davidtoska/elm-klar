module MarkdownSafetyTest exposing (suite)

{-| Text from a person, or from a language model, is not trusted. These tests give
the Markdown view text that tries to run code, to load something from another
site, or to open a dangerous address, and check that what comes out is text.
-}

import Expect
import Html.Attributes as Attr
import Klar.Markdown as Markdown
import Klar.Markdown.Url as Url exposing (Kind(..))
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Markdown safety"
        [ addresses
        , html
        , links
        , imagesAreNotLoaded
        , imagesWhenAsked
        , hosts
        ]



-- ADDRESSES


addresses : Test
addresses =
    describe "which addresses may be linked"
        (List.indexedMap (\index ( text, kind ) -> test (String.fromInt index ++ " " ++ describe_ text) (\_ -> Url.classify text |> Expect.equal kind))
            [ ( "https://example.com/a?b=1#c", Just External )
            , ( "http://example.com", Just External )
            , ( "HTTPS://EXAMPLE.COM", Just External )
            , ( "//example.com/a", Just External )
            , ( "mailto:ada@example.com", Just Contact )
            , ( "MAILTO:ada@example.com", Just Contact )
            , ( "tel:+4712345678", Just Contact )
            , ( "#intro", Just Fragment )
            , ( "/orders/17", Just Relative )
            , ( "../orders", Just Relative )
            , ( "./a/b.html", Just Relative )
            , ( "orders?page=2", Just Relative )
            , ( "?page=2", Just Relative )
            , ( "a/b:c", Just Relative )
            , ( "/æøå/ü", Just Relative )
            , ( "", Nothing )
            , ( "javascript:alert(1)", Nothing )
            , ( "JavaScript:alert(1)", Nothing )
            , ( "JAVASCRIPT:alert(1)", Nothing )
            , ( " javascript:alert(1)", Nothing )
            , ( "javascript:alert(1) ", Nothing )
            , ( "java\tscript:alert(1)", Nothing )
            , ( "java\nscript:alert(1)", Nothing )
            , ( "java\u{000D}script:alert(1)", Nothing )
            , ( "\u{0001}javascript:alert(1)", Nothing )
            , ( "javascript\u{0000}:alert(1)", Nothing )
            , ( "\u{00A0}javascript:alert(1)", Nothing )
            , ( "\u{200B}javascript:alert(1)", Nothing )
            , ( "\u{2028}javascript:alert(1)", Nothing )
            , ( "\u{FEFF}javascript:alert(1)", Nothing )
            , ( "\u{202E}https://example.com", Nothing )
            , ( "javascript&colon;alert(1)", Nothing )
            , ( "&#106;avascript:alert(1)", Nothing )
            , ( "&#x6A;avascript:alert(1)", Nothing )
            , ( "javascript%3Aalert(1)", Nothing )
            , ( "javascript%3aalert(1)", Nothing )
            , ( "%6Aavascript:alert(1)", Nothing )
            , ( "java%0Ascript:alert(1)", Nothing )
            , ( "ｊａｖａｓｃｒｉｐｔ:alert(1)", Nothing )
            , ( "data:text/html,<script>alert(1)</script>", Nothing )
            , ( "data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==", Nothing )
            , ( "data:image/svg+xml,<svg onload=alert(1)>", Nothing )
            , ( "vbscript:msgbox(1)", Nothing )
            , ( "file:///etc/passwd", Nothing )
            , ( "blob:https://example.com/x", Nothing )
            , ( "about:blank", Nothing )
            , ( "ftp://example.com", Nothing )
            , ( "ws://example.com", Nothing )
            , ( "chrome://settings", Nothing )
            , ( "x:y", Nothing )
            , ( "\\\\evil.com", Nothing )
            , ( "/\\evil.com", Nothing )
            , ( "https://example.com/\"onmouseover=\"alert(1)", Nothing )
            , ( "https://example.com/<b>", Nothing )
            , ( "https://example.com/a b", Nothing )
            , ( "https://example.com/\u{0007}", Nothing )
            , ( "https://example.com/\u{D83D}", Nothing )
            , ( "1http://example.com", Nothing )
            , ( String.repeat 3000 "a", Nothing )
            ]
        )


describe_ : String -> String
describe_ text =
    "\"" ++ (text |> String.left 50 |> String.replace "\n" "\\n" |> String.replace "\t" "\\t" |> String.replace "\u{000D}" "\\r" |> String.map visible) ++ "\""


visible : Char -> Char
visible c =
    if Char.toCode c < 0x20 || Char.toCode c == 0x7F || (Char.toCode c >= 0x80 && Char.toCode c <= 0xA0) then
        '?'

    else
        c



-- HTML IS TEXT


tagsThatMustNeverAppear : List String
tagsThatMustNeverAppear =
    [ "script", "iframe", "style", "svg", "form", "object", "embed", "link", "meta", "base", "math", "details", "textarea", "button", "select", "video", "audio", "frame", "applet", "noscript", "template" ]


{-| Texts that try to put markup in the page.
-}
markup : List String
markup =
    [ "<script>alert(1)</script>"
    , "<img src=x onerror=alert(1)>"
    , "<IMG SRC=\"javascript:alert(1)\">"
    , "<a href=\"javascript:alert(1)\">x</a>"
    , "<iframe src=//evil.example></iframe>"
    , "<svg onload=alert(1)>"
    , "<style>*{display:none}</style>"
    , "<form action=//evil.example><input name=x><button>go</button></form>"
    , "<details open ontoggle=alert(1)>"
    , "<div onmouseover=alert(1)>x</div>"
    , "<object data=//evil.example></object><embed src=//evil.example>"
    , "<link rel=stylesheet href=//evil.example/x.css><meta http-equiv=refresh content=0;url=//evil.example><base href=//evil.example>"
    , "<math><mi xlink:href=\"data:x,<script>alert(1)</script>\">"
    , "<video src=x onerror=alert(1)></video><audio src=x onerror=alert(1)></audio>"
    , "<!-- comment --><![CDATA[x]]>"
    , "<textarea>x</textarea><select><option>x</select>"
    , "<noscript><p title=\"</noscript><img src=x onerror=alert(1)>\">"
    ]


{-| Where the text is put, and how many check boxes and images the result may
have: a task has a check box, and an image is an image when images are asked for.
-}
inContexts : String -> List { context : String, text : String, boxes : Int, images : Int }
inContexts evil =
    let
        plain context text =
            { context = context, text = text, boxes = 0, images = 0 }
    in
    [ plain "a paragraph" evil
    , plain "a heading" ("# " ++ evil)
    , plain "a quote" ("> " ++ evil)
    , plain "a list" ("- " ++ evil)
    , plain "a numbered list" ("1. " ++ evil)
    , { context = "a task", text = "- [ ] " ++ evil, boxes = 1, images = 0 }
    , plain "emphasis" ("**" ++ evil ++ "**")
    , plain "a code span" ("`" ++ evil ++ "`")
    , plain "a code block" ("```\n" ++ evil ++ "\n```")
    , plain "an indented code block" ("    " ++ evil)
    , plain "the info string of a fence" ("```" ++ evil ++ "\ncode\n```")
    , plain "the text of a link" ("[" ++ evil ++ "](/a)")
    , plain "the title of a link" ("[x](/a \"" ++ evil ++ "\")")
    , { context = "the description of an image", text = "![" ++ evil ++ "](/a.png)", boxes = 0, images = 1 }
    , plain "a table cell" ("| " ++ String.replace "|" "" evil ++ " |\n|---|\n| " ++ String.replace "|" "" evil ++ " |")
    ]


html : Test
html =
    describe "html is text"
        (markup
            |> List.concatMap
                (\evil ->
                    inContexts evil
                        |> List.map
                            (\place ->
                                test (String.left 40 evil ++ " in " ++ place.context) <|
                                    \_ ->
                                        let
                                            rendered =
                                                Query.fromHtml (Markdown.view [ Markdown.images ] place.text)
                                        in
                                        Expect.all
                                            (List.map (\tag -> \_ -> Query.hasNot [ Selector.tag tag ] rendered) tagsThatMustNeverAppear
                                                ++ [ \_ -> Query.findAll [ Selector.tag "input" ] rendered |> Query.count (Expect.equal place.boxes)
                                                   , \_ -> Query.findAll [ Selector.tag "img" ] rendered |> Query.count (Expect.equal place.images)
                                                   , \_ -> Query.findAll [ Selector.tag "input", Selector.attribute (Attr.type_ "checkbox"), Selector.disabled True ] rendered |> Query.count (Expect.equal place.boxes)
                                                   ]
                                            )
                                            ()
                            )
                )
        )



-- LINKS


linkCount : String -> Expect.Expectation
linkCount text =
    Markdown.view [] text
        |> Query.fromHtml
        |> Query.findAll [ Selector.tag "a" ]
        |> Query.count (Expect.equal 0)


refused : List String
refused =
    [ "[x](javascript:alert(1))"
    , "[x](JavaScript:alert(1))"
    , "[x]( javascript:alert(1) )"
    , "[x](<javascript:alert(1)>)"
    , "[x](<java script:alert(1)>)"
    , "[x](java\tscript:alert(1))"
    , "[x](java&#9;script:alert(1))"
    , "[x](&#106;avascript:alert(1))"
    , "[x](javascript&colon;alert(1))"
    , "[x](javascript%3Aalert(1))"
    , "[x](%6Aavascript:alert(1))"
    , "[x](\u{0001}javascript:alert(1))"
    , "[x](\u{200B}javascript:alert(1))"
    , "[x](\u{2028}javascript:alert(1))"
    , "[x](ｊａｖａｓｃｒｉｐｔ:alert(1))"
    , "[x](data:text/html,<script>alert(1)</script>)"
    , "[x](<data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==>)"
    , "[x](vbscript:msgbox(1))"
    , "[x](file:///etc/passwd)"
    , "[x](blob:https://example.com/x)"
    , "[x](about:blank)"
    , "[x](\\\\evil.example)"
    , "[x](/\\evil.example)"
    , "[x]()"
    , "[x](<>)"
    , "<javascript:alert(1)>"
    , "<vbscript:msgbox(1)>"
    , "<data:text/html,x>"
    , "<file:///etc/passwd>"
    , "[x][1]\n\n[1]: javascript:alert(1)"
    , "[x]: javascript:alert(1)\n\n[x]"
    , "[![x](javascript:alert(1))](javascript:alert(1))"
    , "javascript:alert(1)"
    , "www.example.com ftp://example.com"
    ]


allowed : List ( String, String )
allowed =
    [ ( "[x](https://example.com)", "https://example.com" )
    , ( "[x](HTTP://EXAMPLE.COM)", "HTTP://EXAMPLE.COM" )
    , ( "[x](mailto:ada@example.com)", "mailto:ada@example.com" )
    , ( "[x](tel:+4712345678)", "tel:+4712345678" )
    , ( "[x](/orders/17)", "/orders/17" )
    , ( "[x](../orders)", "../orders" )
    , ( "[x](#intro)", "#intro" )
    , ( "[x](//example.com/a)", "//example.com/a" )
    , ( "<https://example.com>", "https://example.com" )
    , ( "<ada@example.com>", "mailto:ada@example.com" )
    , ( "https://example.com/a", "https://example.com/a" )
    ]


links : Test
links =
    describe "links"
        [ describe "that are refused leave the words and no link"
            (List.indexedMap (\index text -> test (String.fromInt index ++ ": " ++ describe_ text) (\_ -> linkCount text)) refused)
        , test "the words of a refused link are still there" <|
            \_ ->
                Markdown.view [] "See [the docs](javascript:alert(1)) now."
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "the docs" ]
        , describe "that are allowed"
            (List.indexedMap
                (\index ( text, address ) ->
                    test (String.fromInt index ++ " " ++ address) <|
                        \_ ->
                            Markdown.view [] text
                                |> Query.fromHtml
                                |> Query.find [ Selector.tag "a" ]
                                |> Query.has [ Selector.attribute (Attr.href address) ]
                )
                allowed
            )
        , test "links to other sites do not give the other site the page" <|
            \_ ->
                Markdown.view [] "[x](https://example.com)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.attribute (Attr.rel "noopener noreferrer") ]
        , test "links to the same site do not need it" <|
            \_ ->
                Markdown.view [] "[x](/orders)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.hasNot [ Selector.attribute (Attr.rel "noopener noreferrer") ]
        , test "a link does not open a new window" <|
            \_ ->
                Markdown.view [] "[x](https://example.com)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.hasNot [ Selector.attribute (Attr.target "_blank") ]
        ]



-- IMAGES


imageTexts : List String
imageTexts =
    [ "![a chair](https://tracker.example/chair.png?secret=1)"
    , "![a chair](//tracker.example/chair.png)"
    , "![a chair](/chair.png)"
    , "![a chair](chair.png)"
    , "![](https://tracker.example/pixel.gif)"
    ]


imagesAreNotLoaded : Test
imagesAreNotLoaded =
    describe "images are not loaded by default"
        (List.map
            (\text ->
                test text <|
                    \_ ->
                        Markdown.view [] text
                            |> Query.fromHtml
                            |> Query.hasNot [ Selector.tag "img" ]
            )
            imageTexts
            ++ [ test "the description is shown, as a link to the image" <|
                    \_ ->
                        Markdown.view [] "![a chair](https://tracker.example/chair.png)"
                            |> Query.fromHtml
                            |> Query.find [ Selector.tag "a" ]
                            |> Query.has [ Selector.text "a chair", Selector.attribute (Attr.href "https://tracker.example/chair.png") ]
               , test "an image with an address that is refused is only its description" <|
                    \_ ->
                        Markdown.view [] "![a chair](javascript:alert(1))"
                            |> Query.fromHtml
                            |> Query.hasNot [ Selector.tag "a" ]
               , test "an image without a description is called image" <|
                    \_ ->
                        Markdown.view [] "![](/a.png)"
                            |> Query.fromHtml
                            |> Query.has [ Selector.text "Image" ]
               ]
        )


imageRefused : List String
imageRefused =
    [ "![x](javascript:alert(1))"
    , "![x](data:image/svg+xml,<svg onload=alert(1)>)"
    , "![x](<data:image/png;base64,AAAA>)"
    , "![x](file:///etc/passwd)"
    , "![x](mailto:ada@example.com)"
    , "![x](#fragment)"
    , "![x]()"
    ]


imagesWhenAsked : Test
imagesWhenAsked =
    describe "images when asked for"
        [ test "an image is an image" <|
            \_ ->
                Markdown.view [ Markdown.images ] "![a chair](https://example.com/chair.png \"A chair\")"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "img" ]
                    |> Query.has
                        [ Selector.attribute (Attr.src "https://example.com/chair.png")
                        , Selector.attribute (Attr.alt "a chair")
                        , Selector.attribute (Attr.title "A chair")
                        ]
        , test "the browser is told to send no referrer" <|
            \_ ->
                Markdown.view [ Markdown.images ] "![a](https://example.com/a.png)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "img" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "referrerpolicy" "no-referrer"), Selector.attribute (Attr.attribute "loading" "lazy") ]
        , test "a relative image" <|
            \_ ->
                Markdown.view [ Markdown.images ] "![a](/a.png)"
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "img" ]
        , describe "but never from an address that is refused"
            (List.map
                (\text ->
                    test text <|
                        \_ ->
                            Markdown.view [ Markdown.images ] text
                                |> Query.fromHtml
                                |> Query.hasNot [ Selector.tag "img" ]
                )
                imageRefused
            )
        ]


hosts : Test
hosts =
    let
        view_ text =
            Markdown.view [ Markdown.imagesFrom [ "cdn.example.com", " Images.Example.com " ] ] text
                |> Query.fromHtml

        shown text =
            test text (\_ -> view_ text |> Query.has [ Selector.tag "img" ])

        notShown text =
            test text (\_ -> view_ text |> Query.hasNot [ Selector.tag "img" ])
    in
    describe "images from some hosts only"
        [ shown "![a](https://cdn.example.com/a.png)"
        , shown "![a](HTTPS://CDN.EXAMPLE.COM/a.png)"
        , shown "![a](https://images.example.com/a.png)"
        , shown "![a](https://cdn.example.com:8443/a.png)"
        , shown "![a](//cdn.example.com/a.png)"
        , shown "![a](/local/a.png)"
        , shown "![a](a.png)"
        , notShown "![a](https://other.example.com/a.png)"
        , notShown "![a](https://cdn.example.com.evil.example/a.png)"
        , notShown "![a](https://evil.example/cdn.example.com/a.png)"
        , notShown "![a](https://evil.example/a.png?cdn.example.com)"
        , notShown "![a](https://cdn.example.com@evil.example/a.png)"
        , notShown "![a](https://evil.example@cdn.example.com/a.png)"
        , notShown "![a](https://cdn.example.com%2eevil.example/a.png)"
        , notShown "![a](https://sub.cdn.example.com/a.png)"
        , notShown "![a](https://example.com/a.png)"
        , notShown "![a](https://[::1]/a.png)"
        , notShown "![a](javascript:alert(1))"
        , test "an image from another host is a link with its description" <|
            \_ ->
                view_ "![a chair](https://other.example.com/a.png)"
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.text "a chair" ]
        , test "the host of an address" <|
            \_ ->
                Expect.equal
                    [ Just "example.com", Just "example.com", Just "example.com", Nothing, Nothing, Nothing ]
                    [ Url.host "https://example.com/a"
                    , Url.host "http://EXAMPLE.com:80/a?b"
                    , Url.host "//example.com"
                    , Url.host "https://user@example.com/a"
                    , Url.host "/a/b"
                    , Url.host "javascript:alert(1)"
                    ]
        ]
