module MarkdownReviewTest exposing (suite)

{-| What an independent review of the Markdown view and the editor found: an address
that fooled the check of the host of an image, a link inside a link, a link without
a name, heading ids that clash with the ids of the page, half characters made by
cutting a text, lists that change when text arrives, and two places that cost more
than they should.
-}

import Expect
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Markdown as Markdown
import Klar.Markdown.Parse as Parse exposing (Block(..))
import Klar.Markdown.Url as Url
import Klar.Markdown.Utf16 as Utf16
import Klar.MarkdownEditor as Editor
import Klar.MarkdownEditor.Edit as Edit
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Markdown, after the review"
        [ schemeAndHost
        , imageHosts
        , anchors
        , headingIds
        , halves
        , loosening
        , costs
        , editorIds
        ]



-- THE ADDRESS THAT FOOLED THE HOST


{-| Addresses that a browser reads as an address on evil.example while a look for the
first `//` finds the allowed host later in the text.
-}
fooling : List String
fooling =
    [ "http:evil.example//cdn.example.com/a.png"
    , "https:evil.example//cdn.example.com/a.png"
    , "http:/evil.example//cdn.example.com/a.png"
    , "https:/evil.example//cdn.example.com/a.png"
    , "http:evil.example/?//cdn.example.com/a.png"
    , "https:evil.example/#//cdn.example.com/a.png"
    , "http:evil.example/x//cdn.example.com/a.png"
    , "HTTP:evil.example//cdn.example.com/a.png"
    , "https:evil.example"
    , "http:evil.example"
    ]


schemeAndHost : Test
schemeAndHost =
    describe "an http address needs // straight after the colon"
        [ describe "so the address is refused"
            (List.indexedMap (\index text -> test (String.fromInt index ++ " " ++ text) (\_ -> Url.classify text |> Expect.equal Nothing)) fooling)
        , describe "and is neither a link nor an image"
            (List.indexedMap
                (\index text ->
                    test (String.fromInt index ++ " " ++ text) <|
                        \_ ->
                            Expect.all
                                [ \_ -> Markdown.view [] ("[x](" ++ text ++ ")") |> Query.fromHtml |> Query.hasNot [ Selector.tag "a" ]
                                , \_ -> Markdown.view [ Markdown.images ] ("![x](" ++ text ++ ")") |> Query.fromHtml |> Query.hasNot [ Selector.tag "img" ]
                                , \_ -> Markdown.view [ Markdown.imagesFrom cdn ] ("![x](" ++ text ++ ")") |> Query.fromHtml |> Query.hasNot [ Selector.tag "img" ]
                                , \_ -> Markdown.view [ Markdown.imagesFrom cdn ] ("![x](" ++ text ++ ")") |> Query.fromHtml |> Query.hasNot [ Selector.tag "a" ]
                                ]
                                ()
                )
                fooling
            )
        , test "the host is read from the // after the scheme, and from nowhere else" <|
            \_ ->
                Expect.equal
                    [ Just "cdn.example.com", Just "cdn.example.com", Just "evil.example", Just "cdn.example.com", Nothing, Nothing ]
                    [ Url.host "https://cdn.example.com/a.png"
                    , Url.host "//cdn.example.com/a.png"
                    , Url.host "https://evil.example/x//cdn.example.com/a.png"
                    , Url.host "HTTPS://CDN.Example.com"
                    , Url.host "https:///cdn.example.com/a.png"
                    , Url.host "https://cdn.example.com./a.png"
                    ]
        , test "an address with a different port is not the host" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing ]
                    [ Url.host "https://cdn.example.com:6666/a.png"
                    , Url.host "https://cdn.example.com:443/a.png"
                    , Url.host "https://cdn.example.com:/a.png"
                    ]
        ]


cdn : List Markdown.ImageHost
cdn =
    List.filterMap Markdown.imageHost [ "cdn.example.com" ]


imageHosts : Test
imageHosts =
    describe "hosts for images are made by a function, and a mistake is a value"
        [ describe "what is a host"
            (List.map (\text -> test text (\_ -> Markdown.imageHost text |> Maybe.map (always ()) |> Expect.equal (Just ())))
                [ "cdn.example.com", "CDN.Example.COM", "localhost", "images-1.example.com", "127.0.0.1", "a.b.c.d.example.org" ]
            )
        , describe "what is not"
            (List.indexedMap (\index text -> test (String.fromInt index ++ " " ++ String.left 40 text) (\_ -> Markdown.imageHost text |> Maybe.map (always ()) |> Expect.equal Nothing))
                [ ""
                , " "
                , "https://cdn.example.com"
                , "//cdn.example.com"
                , "cdn.example.com:8443"
                , "cdn.example.com/"
                , "cdn.example.com/path"
                , "cdn.example.com."
                , ".example.com"
                , "*.example.com"
                , "user@cdn.example.com"
                , "cdn.example.com "
                , " cdn.example.com"
                , "cdn..example.com"
                , "-cdn.example.com"
                , "cdn-.example.com"
                , "cdn.exa mple.com"
                , "cdn.example.com%2eevil.example"
                , "[::1]"
                , "cdn.exämple.com"
                , String.repeat 64 "a" ++ ".com"
                ]
            )
        , test "an image from the listed host, in any case" <|
            \_ ->
                Markdown.view [ Markdown.imagesFrom cdn ] "![a](HTTPS://CDN.EXAMPLE.COM/a.png)"
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "img" ]
        , test "an image with a port is not from the listed host" <|
            \_ ->
                Markdown.view [ Markdown.imagesFrom cdn ] "![a](https://cdn.example.com:6666/a.png)"
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "img" ]
        ]



-- ANCHORS


anchors : Test
anchors =
    let
        anchorsInAnchors text attributes =
            Markdown.view attributes text
                |> Query.fromHtml
                |> Query.findAll [ Selector.tag "a", Selector.containing [ Selector.tag "a" ] ]
                |> Query.count (Expect.equal 0)

        links text attributes check =
            Markdown.view attributes text
                |> Query.fromHtml
                |> Query.findAll [ Selector.tag "a" ]
                |> Query.count check
    in
    describe "links and images"
        [ test "an image that is not loaded inside a link is not a link" <|
            \_ -> anchorsInAnchors "[![build](/badge.svg)](/ci)" []
        , test "the same with addresses of another site" <|
            \_ -> anchorsInAnchors "[![build](https://img.example/x.svg)](https://ci.example)" []
        , test "and the link is still one link, with the description of the image" <|
            \_ ->
                links "[![build](/badge.svg)](/ci)" [] (Expect.equal 1)
        , test "a loaded image in a link is fine" <|
            \_ -> anchorsInAnchors "[![build](/badge.svg)](/ci)" [ Markdown.images ]
        , test "an image that is not loaded keeps its description inside the link" <|
            \_ ->
                Markdown.view [] "[![build status](/badge.svg)](/ci)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.text "build status" ]
        , test "a link without words shows its address" <|
            \_ ->
                Markdown.view [] "[](https://example.com/page)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.text "https://example.com/page" ]
        , test "a link of white space only shows its address" <|
            \_ ->
                Markdown.view [] "[   ](/orders/17)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.text "/orders/17" ]
        , test "a link with words keeps them" <|
            \_ ->
                Markdown.view [] "[the orders](/orders/17)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "the orders" ]
                        , Query.hasNot [ Selector.text "/orders/17" ]
                        ]
        , test "a link that holds only a loaded image without description is named by its address" <|
            \_ ->
                Markdown.view [ Markdown.images ] "[![](/pic.png)](/orders/17)"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "/orders/17") ]
        , test "a link that is refused and has no words has nothing" <|
            \_ ->
                Markdown.view [] "x [](javascript:alert(1)) y"
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "a" ]
        ]



-- IDS


headingIds : Test
headingIds =
    describe "ids of headings"
        [ test "start with md- unless the application says otherwise" <|
            \_ ->
                Markdown.view [] "# Intro"
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "h1", Selector.id "md-intro" ]
        , test "an empty prefix is possible, for a page that wants plain ids" <|
            \_ ->
                Markdown.view [ Markdown.idPrefix "" ] "# Intro"
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "h1", Selector.id "intro" ]
        ]


editorIds : Test
editorIds =
    let
        editor text =
            Editor.setValue text (Editor.init "notes")

        rendered text attributes =
            Query.fromHtml (Editor.view identity attributes (editor text))
    in
    describe "the editor"
        [ test "a heading of the text cannot take the id of the hint that the text area names" <|
            \_ ->
                rendered "## notes-hint\n\n# Notes\n\n## notes" [ Editor.label "Notes", Editor.hint "Shown on the slip." ]
                    |> Expect.all
                        [ Query.findAll [ Selector.id "notes-hint" ] >> Query.count (Expect.equal 1)
                        , Query.findAll [ Selector.id "notes" ] >> Query.count (Expect.equal 1)
                        , Query.find [ Selector.tag "textarea" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "notes-hint") ]
                        , Query.has [ Selector.tag "h2", Selector.id "notes-md-notes-hint" ]
                        ]
        , test "the preview prefix can be changed by the application" <|
            \_ ->
                rendered "# Intro" [ Editor.preview [ Markdown.idPrefix "mine-" ] ]
                    |> Query.has [ Selector.tag "h1", Selector.id "mine-intro" ]
        ]



-- HALVES


halves : Test
halves =
    let
        letter =
            "𝒜"

        noHalf text =
            -- a half of a character is written as an escape by JSON, and a whole one is not
            String.contains "\\ud" (Encode.encode 0 (Encode.string text)) |> Expect.equal False
    in
    describe "cutting text"
        [ test "Utf16.left does not leave the first half of a character" <|
            \_ ->
                Expect.equal [ "ab", "ab", "ab" ++ letter, "" ] [ Utf16.left 2 ("ab" ++ letter), Utf16.left 3 ("ab" ++ letter), Utf16.left 4 ("ab" ++ letter), Utf16.left 1 letter ]
        , test "the id of a heading of 45 mathematical letters is whole" <|
            \_ ->
                Parse.parse ("# a" ++ String.repeat 45 letter)
                    |> .blocks
                    |> List.filterMap
                        (\block ->
                            case block of
                                HeadingBlock heading ->
                                    Just heading.id

                                _ ->
                                    Nothing
                        )
                    |> String.concat
                    |> noHalf
        , test "the name of the check box of an item that starts with a heading is whole" <|
            \_ ->
                Markdown.view [] ("- [ ] # " ++ String.repeat 45 letter)
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" (Utf16.left 80 (String.repeat 45 letter))) ]
        , test "a very long text of halves is cut before it is repaired" <|
            \_ ->
                let
                    parsed =
                        Parse.parse (String.repeat 400000 "\u{D83D}")
                in
                Maybe.map .shown parsed.truncated
                    |> Maybe.map (\shown -> shown >= Parse.maxChars - 3 && shown <= Parse.maxChars)
                    |> Expect.equal (Just True)
        ]



-- LISTS THAT GROW


{-| The items of the first list of the first `n` blocks.
-}
itemsOf : String -> List Parse.Item
itemsOf text =
    Parse.parse text
        |> .blocks
        |> List.filterMap
            (\block ->
                case block of
                    ListBlock list ->
                        Just list.items

                    _ ->
                        Nothing
            )
        |> List.head
        |> Maybe.withDefault []


looseOf : String -> Maybe Bool
looseOf text =
    Parse.parse text
        |> .blocks
        |> List.filterMap
            (\block ->
                case block of
                    ListBlock list ->
                        Just (not list.tight)

                    _ ->
                        Nothing
            )
        |> List.head


loosening : Test
loosening =
    describe "a list that goes on after a blank line"
        [ test "becomes loose, and that is all that changes" <|
            \_ ->
                Expect.all
                    [ \_ -> looseOf "- a\n- b\n" |> Expect.equal (Just False)
                    , \_ -> looseOf "- a\n- b\n\n- c" |> Expect.equal (Just True)
                    , \_ -> List.take 2 (itemsOf "- a\n- b\n\n- c") |> Expect.equal (itemsOf "- a\n- b\n")
                    ]
                    ()
        , test "the earlier items are the same items at every length of the text" <|
            \_ ->
                let
                    text =
                        "- one\n- two **bold**\n  - nested\n\n- three\n- four\n\n- five\n\n  more\n- six"

                    full =
                        itemsOf text

                    failing =
                        List.range 0 (String.length text)
                            |> List.filter
                                (\length ->
                                    let
                                        prefix =
                                            itemsOf (String.left length text)

                                        complete =
                                            List.length prefix - 1
                                    in
                                    List.take complete prefix /= List.take complete full
                                )
                in
                Expect.equal [] failing
        , test "and the HTML of a tight list and of the same list made loose differ only in a p around the words" <|
            \_ ->
                let
                    paragraphs text check =
                        Markdown.view [] text |> Query.fromHtml |> Query.findAll [ Selector.tag "p" ] |> Query.count check
                in
                Expect.all
                    [ \_ -> paragraphs "- a\n- b" (Expect.equal 0)
                    , \_ -> paragraphs "- a\n- b\n\n- c" (Expect.equal 3)
                    ]
                    ()
        ]



-- COSTS


costs : Test
costs =
    describe "what costs little"
        [ test "an address that cannot start is refused after eight characters" <|
            \_ ->
                -- a hundred thousand characters of `(http://` and `http://(`
                Expect.all
                    [ \_ -> Parse.parse (String.repeat 12500 "(http://") |> .blocks |> List.length |> Expect.equal 1
                    , \_ -> Parse.parse (String.repeat 12500 "http://(") |> .blocks |> List.length |> Expect.equal 1
                    , \_ -> Parse.parse (String.repeat 12500 "*http://") |> .blocks |> List.length |> Expect.equal 1
                    ]
                    ()
        , test "an address with a host is one link as far as it goes" <|
            \_ ->
                Markdown.plainText (Markdown.parse "See https://example.com/a(b)c now")
                    |> Expect.equal "See https://example.com/a(b)c now"
        , test "a list action over ten thousand blank lines does not take a quadratic time" <|
            \_ ->
                let
                    lines =
                        String.repeat 10000 "\n"
                in
                Expect.all
                    [ \_ ->
                        Edit.apply { linkText = "text" } Edit.BulletList { text = lines, selection = { start = 0, end = 10000 } }
                            |> .text
                            |> String.length
                            |> Expect.equal 30000
                    , \_ ->
                        Edit.apply { linkText = "text" } Edit.NumberedList { text = lines, selection = { start = 0, end = 10000 } }
                            |> .text
                            |> String.length
                            |> Expect.greaterThan 10000
                    , \_ ->
                        Edit.apply { linkText = "text" } Edit.Heading { text = lines, selection = { start = 0, end = 10000 } }
                            |> .text
                            |> String.length
                            |> Expect.greaterThan 10000
                    , \_ ->
                        Edit.apply { linkText = "text" } Edit.Quote { text = lines, selection = { start = 0, end = 10000 } }
                            |> .text
                            |> String.length
                            |> Expect.greaterThan 10000
                    ]
                    ()
        , test "text of ten thousand lines with words" <|
            \_ ->
                let
                    text =
                        String.repeat 10000 "word\n"
                in
                Edit.apply { linkText = "text" } Edit.TaskList { text = text, selection = { start = 0, end = String.length text } }
                    |> .text
                    |> String.length
                    |> Expect.equal (String.length text + 10000 * 6)
        ]
