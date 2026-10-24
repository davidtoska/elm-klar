module Support.Css exposing (rules)

{-| The stylesheet as the tests read it: `Klar.css` without comments and with the white
space taken out the way a minifier does (one space at most, none next to `{`, `}`, `;` and
`,`, no `;` before a `}`, a new line after each top-level block), so that a test can look
for a rule as `.klar-x{display: flex}` whatever the layout of the source.
-}

import Klar


rules : String
rules =
    minify Klar.css


type alias Acc =
    { out : List String
    , last : Char
    , space : Bool
    , depth : Int
    }


minify : String -> String
minify css =
    walk (String.toList css) { out = [], last = '\n', space = False, depth = 0 }
        |> .out
        |> List.reverse
        |> String.concat
        |> String.lines
        |> List.filter (\line -> line /= "")
        |> String.join "\n"


walk : List Char -> Acc -> Acc
walk chars acc =
    case chars of
        [] ->
            acc

        '/' :: '*' :: rest ->
            walk (dropComment rest) { acc | space = True }

        '"' :: rest ->
            let
                ( inside, after ) =
                    quoted '"' rest []
            in
            walk after (emit ("\"" ++ inside ++ "\"") acc)

        '\'' :: rest ->
            let
                ( inside, after ) =
                    quoted '\'' rest []
            in
            walk after (emit ("'" ++ inside ++ "'") acc)

        '}' :: rest ->
            let
                trimmed =
                    case acc.out of
                        ";" :: before ->
                            before

                        other ->
                            other

                depth =
                    acc.depth - 1
            in
            walk rest
                { out =
                    (if depth == 0 then
                        "}\n"

                     else
                        "}"
                    )
                        :: trimmed
                , last = '}'
                , space = False
                , depth = depth
                }

        c :: rest ->
            if c == ' ' || c == '\n' || c == '\t' || c == '\u{000D}' then
                walk rest { acc | space = True }

            else
                let
                    next =
                        emit (String.fromChar c) acc
                in
                walk rest
                    (if c == '{' then
                        { next | depth = next.depth + 1 }

                     else
                        next
                    )


emit : String -> Acc -> Acc
emit text acc =
    let
        first =
            String.uncons text |> Maybe.map Tuple.first |> Maybe.withDefault ' '

        separate =
            acc.space && not (List.member acc.last [ '{', '}', ';', ',', '\n' ]) && not (List.member first [ '{', '}', ';', ',' ])

        lastChar =
            String.right 1 text |> String.uncons |> Maybe.map Tuple.first |> Maybe.withDefault acc.last
    in
    { acc
        | out =
            if separate then
                text :: " " :: acc.out

            else
                text :: acc.out
        , last = lastChar
        , space = False
    }


dropComment : List Char -> List Char
dropComment chars =
    case chars of
        '*' :: '/' :: rest ->
            rest

        _ :: rest ->
            dropComment rest

        [] ->
            []


quoted : Char -> List Char -> List Char -> ( String, List Char )
quoted quote chars seen =
    case chars of
        [] ->
            ( String.fromList (List.reverse seen), [] )

        '\\' :: c :: rest ->
            quoted quote rest (c :: '\\' :: seen)

        c :: rest ->
            if c == quote then
                ( String.fromList (List.reverse seen), rest )

            else
                quoted quote rest (c :: seen)
