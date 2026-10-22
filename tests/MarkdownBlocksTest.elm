module MarkdownBlocksTest exposing (suite)

{-| The block structure of Markdown, as a list of texts and the HTML they must
become. The notation of the expected values is that of the CommonMark examples,
without white space between elements (see `Support.MarkdownHtml`).

`ok` is for text that is complete: it is followed by another paragraph, so
nothing in it is "still being written". `ends` is for text that stops where it
stops, as the text of a model does while it is arriving.

-}

import Support.MarkdownCheck exposing (ends, ok)
import Test exposing (Test, describe)


suite : Test
suite =
    describe "Markdown blocks"
        [ headings
        , thematicBreaks
        , paragraphs
        , indentedCode
        , fencedCode
        , quotes
        , lists
        , taskLists
        , tables
        , unfinished
        , deviations
        ]


headings : Test
headings =
    describe "headings"
        [ ok "level 1" "# foo" "<h1 id=\"foo\">foo</h1>"
        , ok "level 2 to 6"
            "## foo\n### foo\n#### foo\n##### foo\n###### foo"
            "<h2 id=\"foo\">foo</h2><h3 id=\"foo-1\">foo</h3><h4 id=\"foo-2\">foo</h4><h5 id=\"foo-3\">foo</h5><h6 id=\"foo-4\">foo</h6>"
        , ok "seven are not a heading" "####### foo" "<p>####### foo</p>"
        , ok "a space is needed" "#5 bolt\n\n#hashtag" "<p>#5 bolt</p><p>#hashtag</p>"
        , ok "an escaped # is text" "\\## foo" "<p>## foo</p>"
        , ok "inline content" "# foo *bar* \\*baz\\*" "<h1 id=\"foo-bar-baz\">foo <em>bar</em> *baz*</h1>"
        , ok "spaces around the content" "#                  foo                     " "<h1 id=\"foo\">foo</h1>"
        , ok "up to three spaces of indentation" " ### foo\n  ## foo\n   # foo" "<h3 id=\"foo\">foo</h3><h2 id=\"foo-1\">foo</h2><h1 id=\"foo-2\">foo</h1>"
        , ok "four spaces are code" "    # foo" "<pre><code># foo</code></pre>"
        , ok "an indented # continues a paragraph" "foo\n    # bar" "<p>foo\n# bar</p>"
        , ok "a closing sequence" "## foo ##\n  ###   bar    ###" "<h2 id=\"foo\">foo</h2><h3 id=\"bar\">bar</h3>"
        , ok "a longer closing sequence" "# foo ##################################\n##### foo ##" "<h1 id=\"foo\">foo</h1><h2 id=\"foo-1\">foo</h2>"
        , ok "spaces after the closing sequence" "### foo ###     " "<h3 id=\"foo\">foo</h3>"
        , ok "a closing sequence must follow a space" "### foo ### b\n\n# foo#" "<h3 id=\"foo-b\">foo ### b</h3><h1 id=\"foo\">foo#</h1>"
        , ok "an escaped closing sequence is text" "### foo \\###\n## foo #\\##\n# foo \\#" "<h3 id=\"foo\">foo ###</h3><h2 id=\"foo-1\">foo ###</h2><h1 id=\"foo-2\">foo #</h1>"
        , ok "headings interrupt a paragraph" "Foo bar\n# baz\nBar foo" "<p>Foo bar</p><h1 id=\"baz\">baz</h1><p>Bar foo</p>"
        , ok "an empty heading is not shown" "## \n#\n### ###" ""
        , ok "ids are unique" "# Intro\n\n## Intro\n\n## Intro\n\n## Intro 1" "<h1 id=\"intro\">Intro</h1><h2 id=\"intro-1\">Intro</h2><h2 id=\"intro-2\">Intro</h2><h2 id=\"intro-1-1\">Intro 1</h2>"
        , ok "ids from words and letters" "# Ordre og Æble: 12 % av Åse!" "<h1 id=\"ordre-og-æble-12-av-åse\">Ordre og Æble: 12 % av Åse!</h1>"
        , ok "a heading of symbols has an id" "# !!!" "<h1 id=\"section\">!!!</h1>"
        , ok "levels never skip a level" "# A\n\n### B\n\n##### C\n\n## D" "<h1 id=\"a\">A</h1><h2 id=\"b\">B</h2><h3 id=\"c\">C</h3><h2 id=\"d\">D</h2>"
        , ok "the first heading keeps its level" "### A\n\n#### B\n\n# C" "<h3 id=\"a\">A</h3><h4 id=\"b\">B</h4><h1 id=\"c\">C</h1>"
        , ok "headings in quotes and lists are numbered too" "# A\n\n> ## A\n\n- ### A" "<h1 id=\"a\">A</h1><blockquote><h2 id=\"a-1\">A</h2></blockquote><ul><li><h3 id=\"a-2\">A</h3></li></ul>"
        ]


thematicBreaks : Test
thematicBreaks =
    describe "thematic breaks"
        [ ok "three characters" "***\n---\n___" "<hr><hr><hr>"
        , ok "a plus is not one" "+++" "<p>+++</p>"
        , ok "equals is not one" "===" "<p>===</p>"
        , ok "two are not enough" "--\n**\n__" "<p>--\n**\n__</p>"
        , ok "indented by up to three spaces" " ***\n  ***\n   ***" "<hr><hr><hr>"
        , ok "four spaces are code" "    ***" "<pre><code>***</code></pre>"
        , ok "an indented rule continues a paragraph" "Foo\n    ***" "<p>Foo\n***</p>"
        , ok "more characters" "_____________________________________" "<hr>"
        , ok "spaces between" " - - -\n **  * ** * ** * **\n-     -      -      -" "<hr><hr><hr>"
        , ok "spaces after" "- - - -    " "<hr>"
        , ok "no other characters" "_ _ _ _ a\n\na------\n\n---a---" "<p>_ _ _ _ a</p><p>a------</p><p>---a---</p>"
        , ok "the same character" " *-*" "<p><em>-</em></p>"
        , ok "between lists" "- foo\n***\n- bar" "<ul><li>foo</li></ul><hr><ul><li>bar</li></ul>"
        , ok "interrupts a paragraph" "Foo\n***\nbar" "<p>Foo</p><hr><p>bar</p>"
        , ok "a rule is not a list item" "* Foo\n* * *\n* Bar" "<ul><li>Foo</li></ul><hr><ul><li>Bar</li></ul>"
        , ok "in a list item" "- Foo\n- * * *" "<ul><li>Foo</li><li><hr></li></ul>"
        ]


paragraphs : Test
paragraphs =
    describe "paragraphs"
        [ ok "two" "aaa\n\nbbb" "<p>aaa</p><p>bbb</p>"
        , ok "lines" "aaa\nbbb\n\nccc\nddd" "<p>aaa\nbbb</p><p>ccc\nddd</p>"
        , ok "several blank lines" "aaa\n\n\nbbb" "<p>aaa</p><p>bbb</p>"
        , ok "leading spaces" "  aaa\n bbb" "<p>aaa\nbbb</p>"
        , ok "deep indentation in a paragraph" "aaa\n             bbb\n                                       ccc" "<p>aaa\nbbb\nccc</p>"
        , ok "up to three spaces" "   aaa\nbbb" "<p>aaa\nbbb</p>"
        , ok "four spaces start code" "    aaa\nbbb" "<pre><code>aaa</code></pre><p>bbb</p>"
        , ok "trailing spaces" "aaa     \nbbb     " "<p>aaa<br>bbb</p>"
        , ok "blank lines with spaces" "aaa\n   \nbbb" "<p>aaa</p><p>bbb</p>"
        , ok "tabs" "\taaa\n\nbbb" "<pre><code>aaa</code></pre><p>bbb</p>"
        , ok "a null character becomes the replacement character" "a\u{0000}b" "<p>a\u{FFFD}b</p>"
        ]


indentedCode : Test
indentedCode =
    describe "indented code"
        [ ok "simple" "    a simple\n      indented code block" "<pre><code>a simple\n  indented code block</code></pre>"
        , ok "a list item with a paragraph" "  - foo\n\n    bar" "<ul><li><p>foo</p><p>bar</p></li></ul>"
        , ok "an item with a nested list" "1.  foo\n\n    - bar" "<ol><li><p>foo</p><ul><li>bar</li></ul></li></ol>"
        , ok "no interpretation inside" "    <a/>\n    *hi*\n\n    - one" "<pre><code>&lt;a/&gt;\n*hi*\n\n- one</code></pre>"
        , ok "blank lines inside" "    chunk1\n\n    chunk2\n  \n \n \n    chunk3" "<pre><code>chunk1\n\nchunk2\n\n\n\nchunk3</code></pre>"
        , ok "extra spaces on a blank line are kept" "    chunk1\n      \n      chunk2" "<pre><code>chunk1\n  \n  chunk2</code></pre>"
        , ok "cannot interrupt a paragraph" "Foo\n    bar" "<p>Foo\nbar</p>"
        , ok "a paragraph after it" "    foo\nbar" "<pre><code>foo</code></pre><p>bar</p>"
        , ok "between headings" "# Heading\n    foo\nHeading\n------\n    foo\n----" "<h1 id=\"heading\">Heading</h1><pre><code>foo</code></pre><p>Heading</p><hr><pre><code>foo</code></pre><hr>"
        , ok "more indentation is kept" "        foo\n    bar" "<pre><code>    foo\nbar</code></pre>"
        , ok "blank lines around are not part of it" "\n    \n    foo\n    \n\n" "<pre><code>foo</code></pre>"
        , ok "trailing spaces are kept" "    foo  " "<pre><code>foo  </code></pre>"
        ]


fencedCode : Test
fencedCode =
    describe "fenced code"
        [ ok "backticks" "```\n<\n >\n```" "<pre><code>&lt;\n &gt;</code></pre>"
        , ok "tildes" "~~~\n<\n >\n~~~" "<pre><code>&lt;\n &gt;</code></pre>"
        , ok "two backticks are a code span" "``\nfoo\n``" "<p><code>foo</code></p>"
        , ok "the closing fence is the same character" "```\naaa\n~~~\n```" "<pre><code>aaa\n~~~</code></pre>"
        , ok "tildes, closed by tildes" "~~~\naaa\n```\n~~~" "<pre><code>aaa\n```</code></pre>"
        , ok "a longer fence" "````\naaa\n```\n``````" "<pre><code>aaa\n```</code></pre>"
        , ok "a longer tilde fence" "~~~~\naaa\n~~~\n~~~~" "<pre><code>aaa\n~~~</code></pre>"
        , ends "an open fence runs to the end" "```" "<pre><code></code></pre>"
        , ends "an open fence with content" "`````\n\n```\naaa" "<pre><code>\n```\naaa</code></pre>"
        , ends "blank lines at the end of an open fence are dropped" "```\ncode\n\n\n" "<pre><code>code</code></pre>"
        , ok "in a quote" "> ```\n> aaa\n\nbbb" "<blockquote><pre><code>aaa</code></pre></blockquote><p>bbb</p>"
        , ok "blank lines inside" "```\n\n  \n```" "<pre><code>\n  </code></pre>"
        , ok "empty" "```\n```" "<pre><code></code></pre>"
        , ok "indented fence removes that much from the lines" " ```\n aaa\naaa\n```" "<pre><code>aaa\naaa</code></pre>"
        , ok "two spaces" "  ```\naaa\n  aaa\naaa\n  ```" "<pre><code>aaa\naaa\naaa</code></pre>"
        , ok "three spaces" "   ```\n   aaa\n    aaa\n  aaa\n   ```" "<pre><code>aaa\n aaa\naaa</code></pre>"
        , ok "four spaces are code" "    ```\n    aaa\n    ```" "<pre><code>```\naaa\n```</code></pre>"
        , ok "the closing fence may be indented" "```\naaa\n  ```\n\n   ```\naaa\n  ```" "<pre><code>aaa</code></pre><pre><code>aaa</code></pre>"
        , ends "four spaces do not close it" "```\naaa\n    ```" "<pre><code>aaa\n    ```</code></pre>"
        , ok "backticks cannot be in the info string" "``` ```\naaa" "<p><code> </code>\naaa</p>"
        , ends "text after the closing fence does not close" "~~~~~~\naaa\n~~~ ~~" "<pre><code>aaa\n~~~ ~~</code></pre>"
        , ok "fences interrupt a paragraph" "foo\n```\nbar\n```\nbaz" "<p>foo</p><pre><code>bar</code></pre><p>baz</p>"
        , ok "the language" "```ruby\ndef foo(x)\n  return 3\nend\n```" "<pre><code class=\"language-ruby\">def foo(x)\n  return 3\nend</code></pre>"
        , ok "the first word is the language" "~~~~    ruby startline=3 $%@#$\ndef foo(x)\n  return 3\nend\n~~~~~~~" "<pre><code class=\"language-ruby\">def foo(x)\n  return 3\nend</code></pre>"
        , ok "a language with symbols" "```c++\nint x;\n```\n\n```f#\nlet x = 1\n```" "<pre><code class=\"language-c++\">int x;</code></pre><pre><code class=\"language-f#\">let x = 1</code></pre>"
        , ok "only the characters of a language name are kept" "```py<script>\nx\n```" "<pre><code class=\"language-pyscript\">x</code></pre>"
        , ok "a closing fence has no info string" "```\n``` aaa\n```" "<pre><code>``` aaa</code></pre>"
        , ok "tabs inside are kept" "```\n\tindented\n```" "<pre><code>\tindented</code></pre>"
        , ok "html in code is only text" "```html\n<script>alert(1)</script>\n```" "<pre><code class=\"language-html\">&lt;script&gt;alert(1)&lt;/script&gt;</code></pre>"
        ]


quotes : Test
quotes =
    describe "block quotes"
        [ ok "simple" "> # Foo\n> bar\n> baz" "<blockquote><h1 id=\"foo\">Foo</h1><p>bar\nbaz</p></blockquote>"
        , ok "no space after the marker" "># Foo\n>bar\n> baz" "<blockquote><h1 id=\"foo\">Foo</h1><p>bar\nbaz</p></blockquote>"
        , ok "indented by up to three spaces" "   > # Foo\n   > bar\n > baz" "<blockquote><h1 id=\"foo\">Foo</h1><p>bar\nbaz</p></blockquote>"
        , ok "four spaces are code" "    > # Foo\n    > bar\n    > baz" "<pre><code>&gt; # Foo\n&gt; bar\n&gt; baz</code></pre>"
        , ok "lazy continuation" "> # Foo\n> bar\nbaz" "<blockquote><h1 id=\"foo\">Foo</h1><p>bar\nbaz</p></blockquote>"
        , ok "lazy and marked lines mix" "> bar\nbaz\n> foo" "<blockquote><p>bar\nbaz\nfoo</p></blockquote>"
        , ok "a rule ends a lazy paragraph" "> foo\n---" "<blockquote><p>foo</p></blockquote><hr>"
        , ok "a list ends it" "> - foo\n- bar" "<blockquote><ul><li>foo</li></ul></blockquote><ul><li>bar</li></ul>"
        , ok "code is not continued lazily" ">     foo\n    bar" "<blockquote><pre><code>foo</code></pre></blockquote><pre><code>bar</code></pre>"
        , ends "a fence is not continued lazily" "> ```\nfoo\n```" "<blockquote><pre><code></code></pre></blockquote><p>foo</p><pre><code></code></pre>"
        , ok "an indented list marker is text" "> foo\n    - bar" "<blockquote><p>foo\n- bar</p></blockquote>"
        , ok "empty" ">" "<blockquote></blockquote>"
        , ok "empty lines" ">\n>  \n> " "<blockquote></blockquote>"
        , ok "empty lines around" ">\n> foo\n>  " "<blockquote><p>foo</p></blockquote>"
        , ok "a blank line separates quotes" "> foo\n\n> bar" "<blockquote><p>foo</p></blockquote><blockquote><p>bar</p></blockquote>"
        , ok "a blank line inside" "> foo\n>\n> bar" "<blockquote><p>foo</p><p>bar</p></blockquote>"
        , ok "interrupts a paragraph" "foo\n> bar" "<p>foo</p><blockquote><p>bar</p></blockquote>"
        , ok "needs no blank lines" "> aaa\n***\n> bbb" "<blockquote><p>aaa</p></blockquote><hr><blockquote><p>bbb</p></blockquote>"
        , ok "a blank line ends the lazy paragraph" "> bar\n\nbaz" "<blockquote><p>bar</p></blockquote><p>baz</p>"
        , ok "nested, lazy" "> > > foo\nbar" "<blockquote><blockquote><blockquote><p>foo\nbar</p></blockquote></blockquote></blockquote>"
        , ok "nested, mixed markers" ">>> foo\n> bar\n>>baz" "<blockquote><blockquote><blockquote><p>foo\nbar\nbaz</p></blockquote></blockquote></blockquote>"
        , ok "code inside, indented" ">     code\n\n>    not code" "<blockquote><pre><code>code</code></pre></blockquote><blockquote><p>not code</p></blockquote>"
        , ok "a quote in a list item in a quote, lazy" "> 1. > Blockquote\ncontinued here." "<blockquote><ol><li><blockquote><p>Blockquote\ncontinued here.</p></blockquote></li></ol></blockquote>"
        , ok "the same with markers" "> 1. > Blockquote\n> continued here." "<blockquote><ol><li><blockquote><p>Blockquote\ncontinued here.</p></blockquote></li></ol></blockquote>"
        , ok "a quote with a table" "> | a | b |\n> |---|---|\n> | 1 | 2 |" "<blockquote><table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table></blockquote>"
        ]


lists : Test
lists =
    describe "lists"
        [ ok "a change of bullet starts a new list" "- foo\n- bar\n+ baz" "<ul><li>foo</li><li>bar</li></ul><ul><li>baz</li></ul>"
        , ok "a change of delimiter starts a new list" "1. foo\n2. bar\n3) baz" "<ol><li>foo</li><li>bar</li></ol><ol start=\"3\"><li>baz</li></ol>"
        , ok "a list interrupts a paragraph" "Foo\n- bar\n- baz" "<p>Foo</p><ul><li>bar</li><li>baz</li></ul>"
        , ok "a number other than 1 does not" "The number of windows in my house is\n14.  The number of doors is 6." "<p>The number of windows in my house is\n14.  The number of doors is 6.</p>"
        , ok "1 does" "The number of windows in my house is\n1.  The number of doors is 6." "<p>The number of windows in my house is</p><ol><li>The number of doors is 6.</li></ol>"
        , ok "an empty item does not" "foo\n*\n\nfoo\n1." "<p>foo\n*</p><p>foo\n1.</p>"
        , ok "loose when items are separated" "- foo\n\n- bar\n\n\n- baz" "<ul><li><p>foo</p></li><li><p>bar</p></li><li><p>baz</p></li></ul>"
        , ok "loose when one pair is separated" "- a\n- b\n\n- c" "<ul><li><p>a</p></li><li><p>b</p></li><li><p>c</p></li></ul>"
        , ok "an empty item in a loose list" "* a\n*\n\n* c" "<ul><li><p>a</p></li><li></li><li><p>c</p></li></ul>"
        , ok "loose when an item has two blocks" "- a\n- b\n\n  c\n- d" "<ul><li><p>a</p></li><li><p>b</p><p>c</p></li><li><p>d</p></li></ul>"
        , ok "tight with code that has blank lines" "- a\n- ```\n  b\n\n\n  ```\n- c" "<ul><li>a</li><li><pre><code>b\n\n</code></pre></li><li>c</li></ul>"
        , ok "tight, the blank line is in the sublist" "- a\n  - b\n\n    c\n- d" "<ul><li>a<ul><li><p>b</p><p>c</p></li></ul></li><li>d</li></ul>"
        , ok "tight with a quote" "* a\n  > b\n  >\n* c" "<ul><li>a<blockquote><p>b</p></blockquote></li><li>c</li></ul>"
        , ok "tight with a quote and code" "- a\n  > b\n  ```\n  c\n  ```\n- d" "<ul><li>a<blockquote><p>b</p></blockquote><pre><code>c</code></pre></li><li>d</li></ul>"
        , ok "a single item" "- a" "<ul><li>a</li></ul>"
        , ok "nested" "- a\n  - b" "<ul><li>a<ul><li>b</li></ul></li></ul>"
        , ok "four levels" "- foo\n  - bar\n    - baz\n      - boo" "<ul><li>foo<ul><li>bar<ul><li>baz<ul><li>boo</li></ul></li></ul></li></ul></li></ul>"
        , ok "indentation of up to three spaces is a sibling" "- foo\n - bar\n  - baz\n   - boo" "<ul><li>foo</li><li>bar</li><li>baz</li><li>boo</li></ul>"
        , ok "siblings at different indentation" "- a\n - b\n  - c\n   - d\n  - e\n - f\n- g" "<ul><li>a</li><li>b</li><li>c</li><li>d</li><li>e</li><li>f</li><li>g</li></ul>"
        , ok "numbered siblings" "1. a\n\n  2. b\n\n   3. c" "<ol><li><p>a</p></li><li><p>b</p></li><li><p>c</p></li></ol>"
        , ok "a nested list needs the indentation of the content" "10) foo\n    - bar" "<ol start=\"10\"><li>foo<ul><li>bar</li></ul></li></ol>"
        , ok "one space too few" "10) foo\n   - bar" "<ol start=\"10\"><li>foo</li></ol><ul><li>bar</li></ul>"
        , ok "the start number is kept" "3. a\n4. b" "<ol start=\"3\"><li>a</li><li>b</li></ol>"
        , ok "start at 0" "0. ok" "<ol start=\"0\"><li>ok</li></ol>"
        , ok "leading zeros" "003. ok" "<ol start=\"3\"><li>ok</li></ol>"
        , ok "nine digits" "123456789. ok" "<ol start=\"123456789\"><li>ok</li></ol>"
        , ok "ten digits are text" "1234567890. not ok" "<p>1234567890. not ok</p>"
        , ok "a negative number is text" "-1. not ok" "<p>-1. not ok</p>"
        , ok "a letter is no number" "A. a" "<p>A. a</p>"
        , ok "a paragraph in an item" "- foo\n\n  bar" "<ul><li><p>foo</p><p>bar</p></li></ul>"
        , ok "code in an item" "- foo\n\n      bar" "<ul><li><p>foo</p><pre><code>bar</code></pre></li></ul>"
        , ok "code after the number" "  10.  foo\n\n           bar" "<ol start=\"10\"><li><p>foo</p><pre><code>bar</code></pre></li></ol>"
        , ok "code at the start of an item" "1.     indented code\n\n   paragraph\n\n       more code" "<ol><li><pre><code>indented code</code></pre><p>paragraph</p><pre><code>more code</code></pre></li></ol>"
        , ok "four spaces after the marker" "-    foo\n\n  bar" "<ul><li>foo</li></ul><p>bar</p>"
        , ok "an item that starts on the next line" "-\n  foo\n-\n  ```\n  bar\n  ```\n-\n      baz" "<ul><li>foo</li><li><pre><code>bar</code></pre></li><li><pre><code>baz</code></pre></li></ul>"
        , ok "spaces after a marker, then the content" "-   \n  foo" "<ul><li>foo</li></ul>"
        , ok "an empty item stays empty" "-\n\n  foo" "<ul><li></li></ul><p>foo</p>"
        , ok "empty items" "- foo\n-\n- bar" "<ul><li>foo</li><li></li><li>bar</li></ul>"
        , ok "empty numbered items" "1. foo\n2.\n3. bar" "<ol><li>foo</li><li></li><li>bar</li></ol>"
        , ok "a lone marker" "*" "<ul><li></li></ul>"
        , ok "several blocks in an item" " 1.  A paragraph\n     with two lines.\n\n         indented code\n\n     > A block quote." "<ol><li><p>A paragraph\nwith two lines.</p><pre><code>indented code</code></pre><blockquote><p>A block quote.</p></blockquote></li></ol>"
        , ok "lazy continuation of an item" "  1.  A paragraph\nwith two lines." "<ol><li>A paragraph\nwith two lines.</li></ol>"
        , ok "a code block, a paragraph and a quote in an item" "1.  foo\n\n    ```\n    bar\n    ```\n\n    baz\n\n    > bam" "<ol><li><p>foo</p><pre><code>bar</code></pre><p>baz</p><blockquote><p>bam</p></blockquote></li></ol>"
        , ok "code with blank lines in an item" "- Foo\n\n      bar\n\n\n      baz" "<ul><li><p>Foo</p><pre><code>bar\n\n\nbaz</code></pre></li></ul>"
        , ok "a fence first in a numbered item" "1. ```\n   foo\n   ```\n\n   bar" "<ol><li><pre><code>foo</code></pre><p>bar</p></li></ol>"
        , ok "a nested list and a paragraph make the outer list loose" "* foo\n  * bar\n\n  baz" "<ul><li><p>foo</p><ul><li>bar</li></ul><p>baz</p></li></ul>"
        , ok "an item is not lazy when the line starts a list" "1. a\n2. b" "<ol><li>a</li><li>b</li></ol>"
        , ok "an ordinary line continues the item" "- a\nb\n- c" "<ul><li>a\nb</li><li>c</li></ul>"
        , ok "a heading ends the item" "- a\n# b" "<ul><li>a</li></ul><h1 id=\"b\">b</h1>"
        , ok "a quote in a list item" "- a\n  > b" "<ul><li>a<blockquote><p>b</p></blockquote></li></ul>"
        , ok "two spaces after a marker" "-  a\n   b" "<ul><li>a\nb</li></ul>"
        , ok "a tab after the marker" "-\ta" "<ul><li>a</li></ul>"
        , ok "no space after the marker" "-a\n+b\n1.c" "<p>-a\n+b\n1.c</p>"
        , ok "emphasis is not a list" "*a*\n**b**" "<p><em>a</em>\n<strong>b</strong></p>"
        , ok "two lists with a different marker and a blank line" "- a\n\n+ b" "<ul><li>a</li></ul><ul><li>b</li></ul>"
        , ok "an item with a heading" "- # Foo\n- Bar\n  baz" "<ul><li><h1 id=\"foo\">Foo</h1></li><li>Bar\nbaz</li></ul>"
        , ok "a very indented marker is code" "- a\n\n    - b" "<ul><li><p>a</p><ul><li>b</li></ul></li></ul>"
        ]


taskLists : Test
taskLists =
    describe "task lists"
        [ ok "open and done" "- [ ] a\n- [x] b\n- [X] c" "<ul><li>[ ] a</li><li>[x] b</li><li>[x] c</li></ul>"
        , ok "numbered" "1. [ ] one\n2. [x] two" "<ol><li>[ ] one</li><li>[x] two</li></ol>"
        , ok "star" "* [ ] a" "<ul><li>[ ] a</li></ul>"
        , ok "a space is needed after the box" "- [x]no\n- [ ]no" "<ul><li>[x]no</li><li>[ ]no</li></ul>"
        , ok "text is needed" "- [x]\n- [ ] " "<ul><li>[x]</li><li>[ ]</li></ul>"
        , ok "other letters are no box" "- [y] a\n- [] a\n- [  ] a" "<ul><li>[y] a</li><li>[] a</li><li>[  ] a</li></ul>"
        , ok "not at the start of the item" "- a [ ] b" "<ul><li>a [ ] b</li></ul>"
        , ok "not outside a list" "[ ] a\n\n[x] b" "<p>[ ] a</p><p>[x] b</p>"
        , ok "nested" "- [ ] a\n  - [x] b\n  - c" "<ul><li>[ ] a<ul><li>[x] b</li><li>c</li></ul></li></ul>"
        , ok "loose" "- [ ] a\n\n- [x] b" "<ul><li>[ ] <p>a</p></li><li>[x] <p>b</p></li></ul>"
        , ok "formatting in the text" "- [ ] **a** `b`" "<ul><li>[ ] <strong>a</strong> <code>b</code></li></ul>"
        , ok "mixed with ordinary items" "- [x] a\n- b\n- [ ] c" "<ul><li>[x] a</li><li>b</li><li>[ ] c</li></ul>"
        ]


tables : Test
tables =
    describe "tables"
        [ ok "simple" "| a | b |\n| - | - |\n| 1 | 2 |" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>"
        , ok "without outer pipes" "a | b\n--|--\n1 | 2" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>"
        , ok "alignment" "| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |" "<table><thead><tr><th align=\"left\">a</th><th align=\"center\">b</th><th align=\"right\">c</th><th>d</th></tr></thead><tbody><tr><td align=\"left\">1</td><td align=\"center\">2</td><td align=\"right\">3</td><td>4</td></tr></tbody></table>"
        , ok "a header and no rows" "| a | b |\n|---|---|" "<table><thead><tr><th>a</th><th>b</th></tr></thead></table>"
        , ok "an escaped pipe" "| a | b |\n|---|---|\n| x \\| y | 2 |" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>x | y</td><td>2</td></tr></tbody></table>"
        , ok "a row with too few cells is padded" "| a | b | c |\n|---|---|---|\n| 1 |" "<table><thead><tr><th>a</th><th>b</th><th>c</th></tr></thead><tbody><tr><td>1</td><td></td><td></td></tr></tbody></table>"
        , ok "extra cells are dropped" "| a |\n|---|\n| 1 | 2 | 3 |" "<table><thead><tr><th>a</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>"
        , ok "the number of columns must match" "| a | b |\n|---|\n| 1 | 2 |" "<p>| a | b |\n|---|\n| 1 | 2 |</p>"
        , ok "a table interrupts a paragraph" "Some text\n| a | b |\n|---|---|\n| 1 | 2 |" "<p>Some text</p><table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>"
        , ok "a blank line ends it" "| a |\n|---|\n| 1 |\n\n| 2 |" "<table><thead><tr><th>a</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table><p>| 2 |</p>"
        , ok "a line without a pipe ends it" "| a |\n|---|\n| 1 |\nText" "<table><thead><tr><th>a</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table><p>Text</p>"
        , ok "another block ends it" "| a |\n|---|\n| 1 |\n> quote | x" "<table><thead><tr><th>a</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table><blockquote><p>quote | x</p></blockquote>"
        , ok "inline content in cells" "| *a* | `b` |\n|---|---|\n| **c** | [d](/e) |" "<table><thead><tr><th><em>a</em></th><th><code>b</code></th></tr></thead><tbody><tr><td><strong>c</strong></td><td><a href=\"/e\">d</a></td></tr></tbody></table>"
        , ok "html in cells is text" "| <b>a</b> |\n|---|\n| <script> |" "<table><thead><tr><th>&lt;b&gt;a&lt;/b&gt;</th></tr></thead><tbody><tr><td>&lt;script&gt;</td></tr></tbody></table>"
        , ok "one column" "| a |\n|---|\n| 1 |\n| 2 |" "<table><thead><tr><th>a</th></tr></thead><tbody><tr><td>1</td></tr><tr><td>2</td></tr></tbody></table>"
        , ok "spaces in the delimiter row" "| a | b |\n| :--- | ---: |\n| 1 | 2 |" "<table><thead><tr><th align=\"left\">a</th><th align=\"right\">b</th></tr></thead><tbody><tr><td align=\"left\">1</td><td align=\"right\">2</td></tr></tbody></table>"
        , ok "the delimiter row needs a pipe" "a\n---" "<p>a</p><hr>"
        , ok "the header needs a pipe" "a\n|---|" "<p>a\n|---|</p>"
        , ok "in a list item" "- | a |\n  |---|\n  | 1 |" "<ul><li><table><thead><tr><th>a</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table></li></ul>"
        , ok "indented four spaces is code" "    | a |\n    |---|" "<pre><code>| a |\n|---|</code></pre>"
        , ok "empty cells" "| a | b |\n|---|---|\n|  | x |\n| y |  |" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td></td><td>x</td></tr><tr><td>y</td><td></td></tr></tbody></table>"
        , ok "a delimiter cell of colons only is not one" "| a |\n|:|" "<p>| a |\n|:|</p>"
        , ok "a table after a table" "| a |\n|---|\n\n| b |\n|---|" "<table><thead><tr><th>a</th></tr></thead></table><table><thead><tr><th>b</th></tr></thead></table>"
        ]


unfinished : Test
unfinished =
    describe "text that is still being written"
        [ ends "an open bold" "Hello **wor" "<p>Hello <strong>wor</strong></p>"
        , ends "an open emphasis" "Hello *wor" "<p>Hello <em>wor</em></p>"
        , ends "an open underscore" "Hello _wor" "<p>Hello <em>wor</em></p>"
        , ends "an open bold and emphasis" "***wor" "<p><em><strong>wor</strong></em></p>"
        , ends "an open strikethrough" "Hello ~~wor" "<p>Hello <del>wor</del></p>"
        , ends "an open emphasis inside bold" "**bold *it" "<p><strong>bold <em>it</em></strong></p>"
        , ends "a lone star stays" "Hello **" "<p>Hello **</p>"
        , ends "a lone star in a sum stays" "2 * 3" "<p>2 * 3</p>"
        , ends "an open code span" "Run `npm inst" "<p>Run <code>npm inst</code></p>"
        , ends "a lone backtick stays" "Run ` now" "<p>Run ` now</p>"
        , ends "a link whose address has not arrived" "See [the docs](htt" "<p>See the docs</p>"
        , ends "a link with an open paren" "See [the docs](" "<p>See the docs</p>"
        , ends "a link with a title that is not closed" "See [the docs](/a \"tit" "<p>See the docs</p>"
        , ends "a link with a finished address" "See [the docs](/docs)" "<p>See <a href=\"/docs\">the docs</a></p>"
        , ends "an open link text stays" "See [the docs" "<p>See [the docs</p>"
        , ends "a closed link text stays" "See [the docs]" "<p>See [the docs]</p>"
        , ends "an open image" "![a cat](htt" "<p>a cat</p>"
        , ends "emphasis in the text of an open link" "[a *b*](htt" "<p>a <em>b</em></p>"
        , ends "an open autolink is text" "See <https://exa" "<p>See &lt;https://exa</p>"
        , ends "a half finished address is a link" "See https://exa" "<p>See <a href=\"https://exa\">https://exa</a></p>"
        , ends "an open table row" "| a | b |\n|---|---|\n| 1 | **tw" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td><strong>tw</strong></td></tr></tbody></table>"
        , ends "a table row with a closing pipe is finished" "| a | b |\n|---|---|\n| 1 | **tw |" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td>**tw</td></tr></tbody></table>"
        , ends "a half row" "| a | b |\n|---|---|\n| 1" "<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td></td></tr></tbody></table>"
        , ends "a half list item" "- one\n- tw" "<ul><li>one</li><li>tw</li></ul>"
        , ends "a list marker alone" "- one\n-" "<ul><li>one</li><li></li></ul>"
        , ends "an open bold in a list item" "- one **tw" "<ul><li>one <strong>tw</strong></li></ul>"
        , ends "an open bold in a quote" "> one **tw" "<blockquote><p>one <strong>tw</strong></p></blockquote>"
        , ends "an open bold in a heading" "## One **tw" "<h2 id=\"one-tw\">One <strong>tw</strong></h2>"
        , ends "a heading marker alone is not shown" "#" ""
        , ends "a fence marker that is not finished" "``" "<p>``</p>"
        , ends "an open fence and its language" "```pyth" "<pre><code class=\"language-pyth\"></code></pre>"
        , ends "a newline at the end changes nothing" "Hello **wor\n" "<p>Hello <strong>wor</strong></p>"
        , ok "a finished paragraph is not closed for the reader" "Hello **wor" "<p>Hello **wor</p>"
        , ok "a finished code span is not closed for the reader" "Run `npm inst" "<p>Run `npm inst</p>"
        , ok "a link that was never finished stays text" "See [the docs](htt" "<p>See [the docs](htt</p>"
        , ends "only the last paragraph is closed" "a **b\n\nc **d" "<p>a **b</p><p>c <strong>d</strong></p>"
        , ends "a blank line at the end finishes the paragraph" "c **d\n\n" "<p>c **d</p>"
        , ends "only the last list item is closed" "- a **b\n- c **d" "<ul><li>a **b</li><li>c <strong>d</strong></li></ul>"
        ]


deviations : Test
deviations =
    describe "what is deliberately not Markdown of CommonMark"
        [ ok "no setext headings" "Foo\n===" "<p>Foo\n===</p>"
        , ok "a dash line is a rule" "Foo\n---\nbar" "<p>Foo</p><hr><p>bar</p>"
        , ok "html is text" "<div>\nhi\n</div>" "<p>&lt;div&gt;\nhi\n&lt;/div&gt;</p>"
        , ok "a comment is text" "<!-- a -->" "<p>&lt;!-- a --&gt;</p>"
        , ok "entities are text" "&amp; &copy; &#35;" "<p>&amp;amp; &amp;copy; &amp;#35;</p>"
        , ok "reference links are text" "[foo]\n\n[foo]: /url" "<p>[foo]</p><p>[foo]: /url</p>"
        , ok "a single tilde is text" "about ~5 minutes to ~10" "<p>about ~5 minutes to ~10</p>"
        , ends "three tildes are a fence" "~~~a~~~" "<pre><code class=\"language-a\"></code></pre>"
        ]
