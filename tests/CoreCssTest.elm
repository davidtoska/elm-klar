module CoreCssTest exposing (suite)

{-| The shared rules of the stylesheet that every component leans on: one list for
reduced motion, the row height that Elm's arithmetic assumes, print, forced colors.
-}

import Expect
import Support.Css as Css
import Test exposing (Test, describe, test)


{-| The rules of the stylesheet, one level deep: the plain rules, and the rules of the
`@media` blocks with the condition of their block. `@supports` and `@keyframes` blocks are
left out (the scroll-driven shadows of a table follow the scroll, not the clock).
-}
type alias Rule =
    { media : String, selector : String, declarations : List String }


rules : List Rule
rules =
    String.lines Css.rules
        |> List.concatMap
            (\line ->
                if String.startsWith "@media" line then
                    case String.indexes "{" line of
                        open :: _ ->
                            let
                                inner =
                                    String.slice (open + 1) (String.length line - 1) line
                            in
                            List.filterMap (rule (String.left open line)) (String.split "}" inner)

                        [] ->
                            []

                else if String.startsWith "@" line then
                    []

                else
                    List.filterMap (rule "") (String.split "}" line)
            )


rule : String -> String -> Maybe Rule
rule media text =
    case String.split "{" text of
        [ selector, body ] ->
            Just { media = media, selector = String.trim selector, declarations = String.split ";" body }

        _ ->
            Nothing


{-| The selectors of a rule: its selector list split at the commas that are not inside
parentheses (`:has(a, b)` is one selector).
-}
selectors : Rule -> List String
selectors r =
    String.foldl
        (\char ( depth, current, done ) ->
            if char == ',' && depth == 0 then
                ( depth, "", String.trim current :: done )

            else if char == '(' then
                ( depth + 1, current ++ String.fromChar char, done )

            else if char == ')' then
                ( depth - 1, current ++ String.fromChar char, done )

            else
                ( depth, current ++ String.fromChar char, done )
        )
        ( 0, "", [] )
        r.selector
        |> (\( _, current, done ) -> List.reverse (String.trim current :: done))


{-| The compound that a selector picks its elements by: the part after the last
combinator (`.klar-modal .klar-modal__dialog--nudge-a` picks `.klar-modal__dialog--nudge-a`).
-}
subject : String -> String
subject selector =
    String.words selector |> List.reverse |> List.head |> Maybe.withDefault selector


{-| A rule under reduced motion reaches the elements of a selector when it names the same
selector, or the compound that the selector picks its elements by (with `!important`,
specificity does not matter).
-}
covered : List String -> String -> Bool
covered list selector =
    List.member selector list || List.member (subject selector) list


{-| An animation that runs on its own clock: not on a duration token (those are 0ms
under reduced motion) and not `none`.
-}
ownDuration : Rule -> Bool
ownDuration r =
    List.any
        (\declaration ->
            (String.startsWith "animation:" declaration || String.startsWith "animation-duration:" declaration)
                && not (String.contains "var(--klar-dur" declaration)
                && not (String.contains ": none" declaration)
        )
        r.declarations


reducedMotion : List String
reducedMotion =
    rules
        |> List.filter (\r -> String.contains "prefers-reduced-motion: reduce" r.media)
        |> List.concatMap selectors


suite : Test
suite =
    describe "the shared rules of the stylesheet"
        [ test "every animation with a duration of its own has a rule under reduced motion" <|
            \_ ->
                rules
                    |> List.filter (\r -> r.media == "" && ownDuration r)
                    |> List.concatMap selectors
                    -- the focus guard of a dialog is not motion: its start is a message
                    |> List.filter (\selector -> not (String.contains "klar-modal__guard" selector))
                    |> List.filter (\selector -> not (covered reducedMotion selector))
                    |> Expect.equal []
        , test "the reduced-motion list wins over the rules of every component" <|
            \_ ->
                rules
                    |> List.filter (\r -> String.contains "prefers-reduced-motion: reduce" r.media && List.member ".klar-modal__dialog--nudge-a" (selectors r))
                    |> List.concatMap .declarations
                    |> Expect.equal [ "animation: none !important" ]
        , test "reduced motion is one list (Base): no component has a block of its own" <|
            \_ ->
                String.lines Css.rules
                    |> List.filter (\line -> String.startsWith "@media" line && String.contains "prefers-reduced-motion" line)
                    -- the duration tokens of Tokens, which are 0ms under reduced motion
                    |> List.filter (\line -> not (String.contains "{:root{" line))
                    |> List.length
                    |> Expect.equal 1
        , test "every rule of the reduced-motion list is !important" <|
            \_ ->
                rules
                    |> List.filter (\r -> String.contains "prefers-reduced-motion: reduce" r.media && r.selector /= ":root")
                    |> List.concatMap .declarations
                    |> List.filter (\declaration -> String.trim declaration /= "" && not (String.contains "!important" declaration))
                    |> Expect.equal []
        , test "the row of a list in a popup is 32px at every density, as Elm's arithmetic assumes" <|
            \_ ->
                rules
                    |> List.concatMap .declarations
                    |> List.filter (String.startsWith "--klar-option-h:")
                    |> Expect.equal [ "--klar-option-h: 32px" ]
        , test "print keeps the colors that icons, dots and chart lines are drawn with" <|
            \_ ->
                rules
                    |> List.filter (\r -> String.contains "print" r.media && r.selector == "[class*=\"klar-\"]")
                    |> List.concatMap .declarations
                    |> List.member "print-color-adjust: exact"
                    |> Expect.equal True
        , test "print leaves out the layers, popups, toasts and tips" <|
            \_ ->
                rules
                    |> List.filter (\r -> String.contains "print" r.media && List.member "display: none !important" r.declarations)
                    |> List.concatMap selectors
                    |> (\hidden -> List.filter (\name -> not (List.member name hidden)) [ ".klar-layer", ".klar-popup", ".klar-toasts", ".klar-tip-bubble" ])
                    |> Expect.equal []
        , test "forced colors give every focused element an outline, whatever its own rules say" <|
            \_ ->
                rules
                    |> List.filter (\r -> String.contains "forced-colors: active" r.media && r.selector == ":focus-visible")
                    |> List.concatMap .declarations
                    |> Expect.equal [ "outline: 2px solid Highlight !important" ]
        , test "a search highlight is a highlight, not the shape of a color dot" <|
            \_ ->
                rules
                    |> List.filter (\r -> r.media == "" && r.selector == "mark.klar-mark")
                    |> List.concatMap .declarations
                    |> (\declarations -> List.filter (\d -> not (List.member d declarations)) [ "background: var(--klar-highlight)", "width: auto", "height: auto", "display: inline", "box-shadow: none" ])
                    |> Expect.equal []
        , test "a search highlight has the system colors of a mark under forced colors" <|
            \_ ->
                rules
                    |> List.filter (\r -> String.contains "forced-colors: active" r.media && r.selector == "mark.klar-mark")
                    |> List.concatMap .declarations
                    |> List.member "background: Mark"
                    |> Expect.equal True
        ]
