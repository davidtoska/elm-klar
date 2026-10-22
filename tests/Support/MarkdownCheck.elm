module Support.MarkdownCheck exposing (check, ends, ok, visible)

{-| One line of a table of texts and the HTML they must become.

`ok` is for text that is complete: it is followed by another paragraph, so
nothing in it is "still being written". `ends` is for text that stops where it
stops, as the text of a model does while it is arriving. The notation of the
expected values is that of the CommonMark examples, without white space between
elements (see `Support.MarkdownHtml`).

-}

import Expect
import Support.MarkdownHtml as H
import Test exposing (Test, test)


ok : String -> String -> String -> Test
ok name input expected =
    check name input (input ++ "\n\n.") (expected ++ "<p>.</p>")


ends : String -> String -> String -> Test
ends name input expected =
    check name input input expected


check : String -> String -> String -> String -> Test
check name shown input expected =
    test name <|
        \_ ->
            let
                actual =
                    H.render input
            in
            if actual == expected then
                Expect.pass

            else
                Expect.fail ("input:    " ++ visible shown ++ "\nexpected: " ++ expected ++ "\nactual:   " ++ actual)


visible : String -> String
visible text =
    text |> String.replace "\n" "\\n" |> String.replace "\t" "\\t"
