module MarkdownInlineTest exposing (suite)

{-| The inline part of Markdown: emphasis, code spans, escapes, links, images,
autolinks and line breaks. Most of the texts are examples of the CommonMark
specification; the expected value is what that specification says (in the notation
of `Support.MarkdownHtml`), unless the test says why this package differs.
-}

import Support.MarkdownCheck exposing (ends, ok)
import Test exposing (Test, describe)


suite : Test
suite =
    describe "Markdown inline"
        [ emphasis
        , strong
        , mixed
        , strikethrough
        , codeSpans
        , escapes
        , links
        , images
        , autolinks
        , plainAddresses
        , breaks
        , plainText
        ]


p : String -> String
p inner =
    "<p>" ++ inner ++ "</p>"


emphasis : Test
emphasis =
    describe "emphasis"
        [ ok "stars" "*foo bar*" (p "<em>foo bar</em>")
        , ok "a star followed by a space does not open" "a * foo bar*" (p "a * foo bar*")
        , ok "a star followed by punctuation after a letter does not open" "a*\"foo\"*" (p "a*&quot;foo&quot;*")
        , ok "inside a word" "foo*bar*" (p "foo<em>bar</em>")
        , ok "inside a word, digits" "5*6*78" (p "5<em>6</em>78")
        , ok "underscores" "_foo bar_" (p "<em>foo bar</em>")
        , ok "an underscore followed by a space does not open" "_ foo bar_" (p "_ foo bar_")
        , ok "an underscore after a letter does not open" "a_\"foo\"_" (p "a_&quot;foo&quot;_")
        , ok "not inside a word" "foo_bar_" (p "foo_bar_")
        , ok "not inside a word, digits" "5_6_78" (p "5_6_78")
        , ok "not inside a word, cyrillic" "пристаням_стремятся_" (p "пристаням_стремятся_")
        , ok "not inside a word, quotes" "aa_\"bb\"_cc" (p "aa_&quot;bb&quot;_cc")
        , ok "an underscore after punctuation opens" "foo-_(bar)_" (p "foo-<em>(bar)</em>")
        , ok "different delimiters do not match" "_foo*" (p "_foo*")
        , ok "a closing star after a space does not close" "*foo bar *" (p "*foo bar *")
        , ok "nor after a line break" "*foo bar\n*" (p "*foo bar\n*")
        , ok "a star between punctuation" "*(*foo)" (p "*(*foo)")
        , ok "a nested pair" "*(*foo*)*" (p "<em>(<em>foo</em>)</em>")
        , ok "closes before a letter" "*foo*bar" (p "<em>foo</em>bar")
        , ok "an underscore does not close inside a word" "_foo bar _" (p "_foo bar _")
        , ok "an underscore between punctuation" "_(_foo)" (p "_(_foo)")
        , ok "an underscore nested" "_(_foo_)_" (p "<em>(<em>foo</em>)</em>")
        , ok "an underscore before a letter does not close" "_foo_bar" (p "_foo_bar")
        , ok "cyrillic, followed by a letter" "_пристаням_стремятся" (p "_пристаням_стремятся")
        , ok "an underscore, then a nested pair" "_foo_bar_baz_" (p "<em>foo_bar_baz</em>")
        , ok "an underscore at the end of a pair" "_(bar)_." (p "<em>(bar)</em>.")
        , ok "a link inside" "*foo [bar](/url)*" (p "<em>foo <a href=\"/url\">bar</a></em>")
        , ok "a line break inside" "*foo\nbar*" (p "<em>foo\nbar</em>")
        , ok "underscores, nested" "_foo __bar__ baz_" (p "<em>foo <strong>bar</strong> baz</em>")
        , ok "underscores, a pair inside a pair" "_foo _bar_ baz_" (p "<em>foo <em>bar</em> baz</em>")
        , ok "a pair that ends with its first character" "__foo_ bar_" (p "<em><em>foo</em> bar</em>")
        , ok "stars, nested" "*foo *bar**" (p "<em>foo <em>bar</em></em>")
        , ok "stars, strong inside" "*foo **bar** baz*" (p "<em>foo <strong>bar</strong> baz</em>")
        , ok "stars, strong in the middle of a word" "*foo**bar**baz*" (p "<em>foo<strong>bar</strong>baz</em>")
        , ok "the rule of three" "*foo**bar*" (p "<em>foo**bar</em>")
        , ok "strong at the start" "***foo** bar*" (p "<em><strong>foo</strong> bar</em>")
        , ok "strong at the end" "*foo **bar***" (p "<em>foo <strong>bar</strong></em>")
        , ok "strong in the middle, at the end" "*foo**bar***" (p "<em>foo<strong>bar</strong></em>")
        , ok "three stars on both sides" "foo***bar***baz" (p "foo<em><strong>bar</strong></em>baz")
        , ok "deep" "*foo **bar *baz* bim** bop*" (p "<em>foo <strong>bar <em>baz</em> bim</strong> bop</em>")
        , ok "emphasis around a link with emphasis" "*foo [*bar*](/url)*" (p "<em>foo <a href=\"/url\"><em>bar</em></a></em>")
        , ok "empty emphasis is text" "** is not an empty emphasis" (p "** is not an empty emphasis")
        , ok "empty strong is text" "**** is not an empty strong emphasis" (p "**** is not an empty strong emphasis")
        , ok "a star pair that is nothing" "__ is not an empty emphasis" (p "__ is not an empty emphasis")
        , ok "an extra opening star" "**foo*" (p "*<em>foo</em>")
        , ok "an extra closing star" "*foo**" (p "<em>foo</em>*")
        , ok "an extra opening star, strong" "***foo**" (p "*<strong>foo</strong>")
        , ok "an extra opening star, four" "****foo*" (p "***<em>foo</em>")
        , ok "an extra closing star, strong" "**foo***" (p "<strong>foo</strong>*")
        , ok "an extra closing star, four" "*foo****" (p "<em>foo</em>***")
        , ok "a pair around an escaped star" "*foo \\* bar*" (p "<em>foo * bar</em>")
        , ok "a space before a closing underscore" "_foo _" (p "_foo _")
        ]


strong : Test
strong =
    describe "strong text"
        [ ok "stars" "**foo bar**" (p "<strong>foo bar</strong>")
        , ok "a space after the opening does not open" "** foo bar**" (p "** foo bar**")
        , ok "after a letter, before punctuation" "a**\"foo\"**" (p "a**&quot;foo&quot;**")
        , ok "inside a word" "foo**bar**" (p "foo<strong>bar</strong>")
        , ok "underscores" "__foo bar__" (p "<strong>foo bar</strong>")
        , ok "an underscore pair followed by a space" "__ foo bar__" (p "__ foo bar__")
        , ok "an underscore pair after a line break" "__\nfoo bar__" (p "__\nfoo bar__")
        , ok "an underscore pair after a letter" "a__\"foo\"__" (p "a__&quot;foo&quot;__")
        , ok "not inside a word" "foo__bar__" (p "foo__bar__")
        , ok "not inside a word, digits" "5__6__78" (p "5__6__78")
        , ok "after punctuation" "foo-__(bar)__" (p "foo-<strong>(bar)</strong>")
        , ok "a space before the closing pair" "**foo bar **" (p "**foo bar **")
        , ok "between punctuation" "**(**foo)" (p "**(**foo)")
        , ok "nested in emphasis" "*(**foo**)*" (p "<em>(<strong>foo</strong>)</em>")
        , ok "a long example" "**Gomphocarpus (*Gomphocarpus physocarpus*, syn.\n*Asclepias physocarpa*)**" (p "<strong>Gomphocarpus (<em>Gomphocarpus physocarpus</em>, syn.\n<em>Asclepias physocarpa</em>)</strong>")
        , ok "quotes inside" "**foo \"*bar*\" foo**" (p "<strong>foo &quot;<em>bar</em>&quot; foo</strong>")
        , ok "closes before a letter" "**foo**bar" (p "<strong>foo</strong>bar")
        , ok "an underscore pair, a space before the closing" "__foo bar __" (p "__foo bar __")
        , ok "an underscore pair between punctuation" "__(__foo)" (p "__(__foo)")
        , ok "an underscore pair, nested in emphasis" "_(__foo__)_" (p "<em>(<strong>foo</strong>)</em>")
        , ok "an underscore pair before a letter does not close" "__foo__bar" (p "__foo__bar")
        , ok "an underscore pair, in the middle" "__foo__bar__baz__" (p "<strong>foo__bar__baz</strong>")
        , ok "a link inside" "**foo [bar](/url)**" (p "<strong>foo <a href=\"/url\">bar</a></strong>")
        , ok "a line break inside" "**foo\nbar**" (p "<strong>foo\nbar</strong>")
        , ok "emphasis inside" "__foo _bar_ baz__" (p "<strong>foo <em>bar</em> baz</strong>")
        , ok "strong inside strong" "__foo __bar__ baz__" (p "<strong>foo <strong>bar</strong> baz</strong>")
        , ok "strong ends with the first characters of the pair" "____foo__ bar__" (p "<strong><strong>foo</strong> bar</strong>")
        , ok "a pair at the end of a pair" "**foo **bar****" (p "<strong>foo <strong>bar</strong></strong>")
        , ok "emphasis in the middle" "**foo *bar* baz**" (p "<strong>foo <em>bar</em> baz</strong>")
        , ok "emphasis inside a word" "**foo*bar*baz**" (p "<strong>foo<em>bar</em>baz</strong>")
        , ok "emphasis at the start" "***foo* bar**" (p "<strong><em>foo</em> bar</strong>")
        , ok "emphasis at the end" "**foo *bar***" (p "<strong>foo <em>bar</em></strong>")
        , ok "spanning lines" "**foo *bar **baz**\nbim* bop**" (p "<strong>foo <em>bar <strong>baz</strong>\nbim</em> bop</strong>")
        , ok "a link with emphasis inside" "**foo [*bar*](/url)**" (p "<strong>foo <a href=\"/url\"><em>bar</em></a></strong>")
        ]


mixed : Test
mixed =
    describe "other combinations"
        [ ok "bold and italic with stars" "***both***" (p "<em><strong>both</strong></em>")
        , ok "emphasis and a code span" "*a `b` c*" (p "<em>a <code>b</code> c</em>")
        , ok "delimiters in a code span are text" "*a `*` b*" (p "<em>a <code>*</code> b</em>")
        , ok "an unmatched star before a code span" "*foo`*`" (p "*foo<code>*</code>")
        , ok "emphasis is not carried over a blank line" "*a\n\nb*" (p "*a" ++ p "b*")
        ]


strikethrough : Test
strikethrough =
    describe "strikethrough"
        [ ok "two tildes" "~~foo~~" (p "<del>foo</del>")
        , ok "with spaces inside" "~~foo bar~~" (p "<del>foo bar</del>")
        , ok "in a sentence" "a ~~b~~ c" (p "a <del>b</del> c")
        , ok "inside a word" "foo~~bar~~baz" (p "foo<del>bar</del>baz")
        , ok "one tilde is text" "~foo~" (p "~foo~")
        , ok "three tildes are text" "x ~~~foo~~~ y" (p "x ~~~foo~~~ y")
        , ok "a space after the opening does not open" "~~ foo~~" (p "~~ foo~~")
        , ok "unclosed is text when finished" "~~foo" (p "~~foo")
        , ok "with emphasis inside" "~~*foo*~~" (p "<del><em>foo</em></del>")
        , ok "around emphasis" "*~~foo~~*" (p "<em><del>foo</del></em>")
        , ok "an approximate number is text" "It takes ~5 minutes, or ~10 on a slow day." (p "It takes ~5 minutes, or ~10 on a slow day.")
        ]


codeSpans : Test
codeSpans =
    describe "code spans"
        [ ok "simple" "`foo`" (p "<code>foo</code>")
        , ok "a longer fence" "`` foo ` bar ``" (p "<code>foo ` bar</code>")
        , ok "a space inside" "` `` `" (p "<code>``</code>")
        , ok "only one space is removed" "`  ``  `" (p "<code> `` </code>")
        , ok "only if on both sides" "` a`" (p "<code> a</code>")
        , ok "one space on each side is removed" "` b `" (p "<code>b</code>")
        , ok "spaces only" "` `\n`  `" (p "<code> </code>\n<code>  </code>")
        , ok "line endings become spaces" "``\nfoo\nbar  \nbaz\n``" (p "<code>foo bar   baz</code>")
        , ok "a line ending at the end" "``\nfoo \n``" (p "<code>foo </code>")
        , ok "inner spaces are kept" "`foo   bar \nbaz`" (p "<code>foo   bar  baz</code>")
        , ok "a backslash is not an escape" "`foo\\`bar`" (p "<code>foo\\</code>bar`")
        , ok "a longer fence with a backtick inside" "``foo`bar``" (p "<code>foo`bar</code>")
        , ok "spaces around a backtick" "` foo `` bar `" (p "<code>foo `` bar</code>")
        , ok "stars are text" "*foo`*`" (p "*foo<code>*</code>")
        , ok "brackets are text" "[not a `link](/foo`)" (p "[not a <code>link](/foo</code>)")
        , ok "html is text" "`<a href=\"`\">`" (p "<code>&lt;a href=&quot;</code>&quot;&gt;`")
        , ok "an autolink starts first" "<http://foo.bar.`baz>`" (p "<a href=\"http://foo.bar.`baz\">http://foo.bar.`baz</a>`")
        , ok "a code span starts first" "`<http://foo.bar.`baz>`" (p "<code>&lt;http://foo.bar.</code>baz&gt;`")
        , ok "no matching fence is text" "```foo``" (p "```foo``")
        , ok "an open fence is text" "`foo" (p "`foo")
        , ok "a shorter fence inside" "`foo``bar``" (p "`foo<code>bar</code>")
        , ok "html in a code span is only text" "`<script>alert(1)</script>`" (p "<code>&lt;script&gt;alert(1)&lt;/script&gt;</code>")
        , ok "a pipe" "`a | b`" (p "<code>a | b</code>")
        ]


escapes : Test
escapes =
    describe "backslash escapes"
        [ ok "every punctuation character"
            "\\!\\\"\\#\\$\\%\\&\\'\\(\\)\\*\\+\\,\\-\\.\\/\\:\\;\\<\\=\\>\\?\\@\\[\\\\\\]\\^\\_\\`\\{\\|\\}\\~"
            (p "!&quot;#$%&amp;'()*+,-./:;&lt;=&gt;?@[\\]^_`{|}~")
        , ok "other characters keep the backslash" "\\\t\\A\\a\\ \\3\\φ\\«" (p "\\\t\\A\\a\\ \\3\\φ\\«")
        , ok "escaped characters are not special"
            "\\*not emphasized*\n\\<br/> not a tag\n\\[not a link](/foo)\n\\`not code`\n1\\. not a list\n\\* not a list\n\\# not a heading"
            (p "*not emphasized*\n&lt;br/&gt; not a tag\n[not a link](/foo)\n`not code`\n1. not a list\n* not a list\n# not a heading")
        , ok "an escaped backslash" "\\\\*emphasis*" (p "\\<em>emphasis</em>")
        , ok "a backslash at the end of a line is a line break" "foo\\\nbar" (p "foo<br>bar")
        , ok "in a code span" "`` \\[\\` ``" (p "<code>\\[\\`</code>")
        , ok "in a code block" "    \\[\\]" "<pre><code>\\[\\]</code></pre>"
        , ok "in a fence" "~~~\n\\[\\]\n~~~" "<pre><code>\\[\\]</code></pre>"
        , ok "a backslash at the end is text" "foo\\" (p "foo\\")
        , ok "an escaped bracket" "\\[foo\\]" (p "[foo]")
        ]


links : Test
links =
    describe "links"
        [ ok "with a title" "[link](/uri \"title\")" (p "<a href=\"/uri\" title=\"title\">link</a>")
        , ok "without a title" "[link](/uri)" (p "<a href=\"/uri\">link</a>")
        , ok "an empty address" "[link]()" (p "<a href=\"\">link</a>")
        , ok "an empty address in angle brackets" "[link](<>)" (p "<a href=\"\">link</a>")
        , ok "a space in the address" "[link](/my uri)" (p "[link](/my uri)")
        , ok "a space in an address in angle brackets" "[link](</my uri>)" (p "<a href=\"/my uri\">link</a>")
        , ok "a line ending in the address" "[link](foo\nbar)" (p "[link](foo\nbar)")
        , ok "a parenthesis in angle brackets" "[a](<b)c>)" (p "<a href=\"b)c\">a</a>")
        , ok "an escaped parenthesis" "[link](\\(foo\\))" (p "<a href=\"(foo)\">link</a>")
        , ok "balanced parentheses" "[link](foo(and(bar)))" (p "<a href=\"foo(and(bar))\">link</a>")
        , ok "escaped parentheses" "[link](foo\\(and\\(bar\\))" (p "<a href=\"foo(and(bar)\">link</a>")
        , ok "a fragment" "[link](#fragment)" (p "<a href=\"#fragment\">link</a>")
        , ok "an address with a fragment" "[link](http://example.com#fragment)" (p "<a href=\"http://example.com#fragment\">link</a>")
        , ok "an address with a query and a fragment" "[link](http://example.com?foo=3#frag)" (p "<a href=\"http://example.com?foo=3#frag\">link</a>")
        , ok "a backslash that is not an escape" "[link](foo\\bar)" (p "<a href=\"foo\\bar\">link</a>")
        , ok "a title in single quotes" "[link](/url 'title')" (p "<a href=\"/url\" title=\"title\">link</a>")
        , ok "a title in parentheses" "[link](/url (title))" (p "<a href=\"/url\" title=\"title\">link</a>")
        , ok "an escaped quote in a title" "[link](/url \"ti\\\"tle\")" (p "<a href=\"/url\" title=\"ti&quot;tle\">link</a>")
        , ok "more than one title" "[link](/url \"title\" \"and\" \"again\")" (p "[link](/url &quot;title&quot; &quot;and&quot; &quot;again&quot;)")
        , ok "quotes in a title" "[link](/url 'title \"and\" title')" (p "<a href=\"/url\" title=\"title &quot;and&quot; title\">link</a>")
        , ok "spaces around the address and the title" "[link](   /uri\n  \"title\"  )" (p "<a href=\"/uri\" title=\"title\">link</a>")
        , ok "no space between the text and the address" "[link] (/uri)" (p "[link] (/uri)")
        , ok "brackets in the text" "[link [foo [bar]]](/uri)" (p "<a href=\"/uri\">link [foo [bar]]</a>")
        , ok "an unbalanced bracket" "[link] bar](/uri)" (p "[link] bar](/uri)")
        , ok "a link after an open bracket" "[link [bar](/uri)" (p "[link <a href=\"/uri\">bar</a>")
        , ok "an escaped bracket in the text" "[link \\[bar](/uri)" (p "<a href=\"/uri\">link [bar</a>")
        , ok "inline content in the text" "[link *foo **bar** `#`*](/uri)" (p "<a href=\"/uri\">link <em>foo <strong>bar</strong> <code>#</code></em></a>")
        , ok "an image in the text" "[![moon](moon.jpg)](/uri)" (p "<a href=\"/uri\"><img src=\"moon.jpg\" alt=\"moon\"></a>")
        , ok "links do not contain links" "[foo [bar](/uri)](/uri)" (p "[foo <a href=\"/uri\">bar</a>](/uri)")
        , ok "emphasis cannot span the end of a link" "*[foo*](/uri)" (p "*<a href=\"/uri\">foo*</a>")
        , ok "emphasis in the text, address with a star" "[foo *bar](baz*)" (p "<a href=\"baz*\">foo *bar</a>")
        , ok "a link in a heading" "# [foo](/url)" "<h1 id=\"foo\"><a href=\"/url\">foo</a></h1>"
        , ok "a bracket that is not a link" "[foo]" (p "[foo]")
        , ok "brackets that are not a link" "[foo] [bar]" (p "[foo] [bar]")
        , ok "a link whose address has parentheses of its own" "[a](b(c)d)" (p "<a href=\"b(c)d\">a</a>")
        , ok "too many nested parentheses are text" "[a](((((((x)))))))" (p "[a](((((((x)))))))")
        , ok "a javascript address is kept in the tree and refused when shown" "[x](javascript:alert(1))" (p "<a href=\"javascript:alert(1)\">x</a>")
        , ok "an address in angle brackets with a title" "[a](<b c> \"t\")" (p "<a href=\"b c\" title=\"t\">a</a>")
        , ok "a closing parenthesis without an opening one" "[a](b))" (p "<a href=\"b\">a</a>)")
        , ok "a link in a list" "- [a](b)" "<ul><li><a href=\"b\">a</a></li></ul>"
        ]


images : Test
images =
    describe "images"
        [ ok "with a title" "![foo](/url \"title\")" (p "<img src=\"/url\" alt=\"foo\" title=\"title\">")
        , ok "the description is the text of the content" "![foo *bar*](train.jpg)" (p "<img src=\"train.jpg\" alt=\"foo bar\">")
        , ok "an image in an image" "![foo ![bar](/url)](/url2)" (p "<img src=\"/url2\" alt=\"foo bar\">")
        , ok "a link in an image" "![foo [bar](/url)](/url2)" (p "<img src=\"/url2\" alt=\"foo bar\">")
        , ok "without a description" "![](/url)" (p "<img src=\"/url\" alt=\"\">")
        , ok "an address in angle brackets" "![foo](<url>)" (p "<img src=\"url\" alt=\"foo\">")
        , ok "an exclamation mark that is not an image" "!foo ![bar" (p "!foo ![bar")
        , ok "an exclamation mark before a link" "!\\[foo](/url)" (p "![foo](/url)")
        , ok "an image without an address is text" "![foo]" (p "![foo]")
        , ok "a link around an image keeps both" "[![a](b.png)](c)" (p "<a href=\"c\"><img src=\"b.png\" alt=\"a\"></a>")
        ]


autolinks : Test
autolinks =
    describe "autolinks"
        [ ok "a web address" "<http://foo.bar.baz>" (p "<a href=\"http://foo.bar.baz\">http://foo.bar.baz</a>")
        , ok "with a query" "<http://foo.bar.baz/test?q=hello&id=22&boolean>" (p "<a href=\"http://foo.bar.baz/test?q=hello&amp;id=22&amp;boolean\">http://foo.bar.baz/test?q=hello&amp;id=22&amp;boolean</a>")
        , ok "another scheme" "<irc://foo.bar:2233/baz>" (p "<a href=\"irc://foo.bar:2233/baz\">irc://foo.bar:2233/baz</a>")
        , ok "capitals" "<MAILTO:FOO@BAR.BAZ>" (p "<a href=\"MAILTO:FOO@BAR.BAZ\">MAILTO:FOO@BAR.BAZ</a>")
        , ok "a scheme with a plus" "<a+b+c:d>" (p "<a href=\"a+b+c:d\">a+b+c:d</a>")
        , ok "a made up scheme" "<made-up-scheme://foo,bar>" (p "<a href=\"made-up-scheme://foo,bar\">made-up-scheme://foo,bar</a>")
        , ok "a short address" "<http://../>" (p "<a href=\"http://../\">http://../</a>")
        , ok "a host and a port" "<localhost:5001/foo>" (p "<a href=\"localhost:5001/foo\">localhost:5001/foo</a>")
        , ok "a space inside" "<http://foo.bar/baz bim>" (p "&lt;http://foo.bar/baz bim&gt;")
        , ok "an email address" "<foo@bar.example.com>" (p "<a href=\"mailto:foo@bar.example.com\">foo@bar.example.com</a>")
        , ok "an email address with symbols" "<foo+special@Bar.baz-bar0.com>" (p "<a href=\"mailto:foo+special@Bar.baz-bar0.com\">foo+special@Bar.baz-bar0.com</a>")
        , ok "a backslash in an email address" "<foo\\+@bar.example.com>" (p "&lt;foo+@bar.example.com&gt;")
        , ok "nothing" "<>" (p "&lt;&gt;")
        , ok "spaces around" "< http://foo.bar >" (p "&lt; <a href=\"http://foo.bar\">http://foo.bar</a> &gt;")
        , ok "a scheme of one letter" "<m:abc>" (p "&lt;m:abc&gt;")
        , ok "no scheme" "<foo.bar.baz>" (p "&lt;foo.bar.baz&gt;")
        , ok "a tag is text" "<b>bold</b>" (p "&lt;b&gt;bold&lt;/b&gt;")
        , ok "not inside the text of a link" "[<http://a.com>](/b)" (p "<a href=\"/b\">&lt;http://a.com&gt;</a>")
        ]


plainAddresses : Test
plainAddresses =
    describe "plain web addresses"
        [ ok "an address in a sentence" "See http://example.com/a for details" (p "See <a href=\"http://example.com/a\">http://example.com/a</a> for details")
        , ok "https" "https://example.com" (p "<a href=\"https://example.com\">https://example.com</a>")
        , ok "capitals" "HTTPS://EXAMPLE.COM/X" (p "<a href=\"HTTPS://EXAMPLE.COM/X\">HTTPS://EXAMPLE.COM/X</a>")
        , ok "a full stop at the end is text" "Go to https://example.com." (p "Go to <a href=\"https://example.com\">https://example.com</a>.")
        , ok "a comma, a question mark" "https://example.com, https://example.org?" (p "<a href=\"https://example.com\">https://example.com</a>, <a href=\"https://example.org\">https://example.org</a>?")
        , ok "a query is part of it" "https://example.com/a?b=1&c=2" (p "<a href=\"https://example.com/a?b=1&amp;c=2\">https://example.com/a?b=1&amp;c=2</a>")
        , ok "parentheses that match" "(see https://example.com/a_(b))" (p "(see <a href=\"https://example.com/a_(b)\">https://example.com/a_(b)</a>)")
        , ok "a parenthesis that does not" "(see https://example.com/a)" (p "(see <a href=\"https://example.com/a\">https://example.com/a</a>)")
        , ok "not in the middle of a word" "xhttps://example.com" (p "xhttps://example.com")
        , ok "an address needs a host" "https:// is not one" (p "https:// is not one")
        , ok "not in code" "`https://example.com`" (p "<code>https://example.com</code>")
        , ok "not in the text of a link" "[https://example.com](/x)" (p "<a href=\"/x\">https://example.com</a>")
        , ok "in emphasis" "*https://example.com*" (p "<em><a href=\"https://example.com\">https://example.com</a></em>")
        , ok "after a quote" "\"https://example.com\"" (p "&quot;<a href=\"https://example.com\">https://example.com</a>&quot;")
        , ok "ftp is not linked" "ftp://example.com" (p "ftp://example.com")
        , ok "www is not linked" "www.example.com" (p "www.example.com")
        , ok "stops at a tag" "https://a.com<b>" (p "<a href=\"https://a.com\">https://a.com</a>&lt;b&gt;")
        ]


breaks : Test
breaks =
    describe "line breaks"
        [ ok "two spaces" "foo  \nbaz" (p "foo<br>baz")
        , ok "a backslash" "foo\\\nbaz" (p "foo<br>baz")
        , ok "more than two spaces" "foo       \nbaz" (p "foo<br>baz")
        , ok "spaces at the start of the next line" "foo  \n     bar" (p "foo<br>bar")
        , ok "a backslash, then spaces" "foo\\\n     bar" (p "foo<br>bar")
        , ok "inside emphasis" "*foo  \nbar*" (p "<em>foo<br>bar</em>")
        , ok "inside emphasis, with a backslash" "*foo\\\nbar*" (p "<em>foo<br>bar</em>")
        , ok "not in a code span" "`code  \nspan`" (p "<code>code   span</code>")
        , ok "not in a code span, with a backslash" "`code\\\nspan`" (p "<code>code\\ span</code>")
        , ok "a soft break" "foo\nbaz" (p "foo\nbaz")
        , ok "a soft break strips spaces" "foo \n baz" (p "foo\nbaz")
        , ok "one space is no break" "foo \nbar" (p "foo\nbar")
        , ok "at the end of a paragraph" "foo  " (p "foo")
        , ok "at the end of a heading" "### foo  " "<h3 id=\"foo\">foo</h3>"
        , ok "a backslash at the end of a heading" "### foo\\" "<h3 id=\"foo\">foo\\</h3>"
        , ok "in a list item" "- a  \n  b" "<ul><li>a<br>b</li></ul>"
        ]


plainText : Test
plainText =
    describe "plain text"
        [ ok "special characters" "hello $.;'there" (p "hello $.;'there")
        , ok "letters" "Foo χρῆν" (p "Foo χρῆν")
        , ok "spaces inside are kept" "Multiple     spaces" (p "Multiple     spaces")
        , ok "a quote and an ampersand are escaped for the page" "a & b < c > d \"e\"" (p "a &amp; b &lt; c &gt; d &quot;e&quot;")
        , ok "emoji" "Shipped 📦 today" (p "Shipped 📦 today")
        , ok "right to left text" "مرحبا **بالعالم**" (p "مرحبا <strong>بالعالم</strong>")
        , ok "the second half of a character at the start" "\u{DE00}x" (p "�x")
        , ok "the second half of a character alone" "\u{DE00}" (p "�")
        , ok "half of a character in the middle" "a\u{D83D}b\u{DE00}c" (p "a�b�c")
        , ok "halves in the wrong order" "\u{DE00}\u{D83D}" (p "��")
        , ok "a whole character stays whole" "a😀b" (p "a😀b")
        , ok "a backslash before the text of a half" "\\ud83d" (p "\\ud83d")
        , ends "the first half of a character at the end is taken away" "Shipped \u{D83D}" (p "Shipped")
        , ends "a text that is cut in the middle of a character" "**Shipped** \u{D83D}" (p "<strong>Shipped</strong>")
        ]
