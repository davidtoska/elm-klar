module Klar.CodeBlock.Lexer exposing (Kind(..), Language(..), Token, highlight)

{-| Bounded lexical highlighting, deliberately not syntax validation. Every token
keeps the exact characters it consumed, including unfinished strings/comments.
-}


type Language
    = Plain
    | Json
    | Elm


type Kind
    = Text
    | Keyword
    | Quoted
    | Number
    | Comment


type alias Token =
    { kind : Kind, text : String }


highlight : Language -> String -> List Token
highlight language source =
    if language == Plain || String.length source > 30000 then
        [ { kind = Text, text = source } ]

    else
        scan language (String.toList source) [] |> List.reverse


scan : Language -> List Char -> List Token -> List Token
scan language chars tokens =
    case chars of
        [] ->
            tokens

        _ ->
            let
                ( kind, consumed, remaining ) =
                    next language chars
            in
            scan language remaining ({ kind = kind, text = String.fromList consumed } :: tokens)


next : Language -> List Char -> ( Kind, List Char, List Char )
next language chars =
    let
        add kind consumed remaining =
            ( kind, consumed, remaining )

        quoted =
            case chars of
                '"' :: rest ->
                    let
                        ( consumed, remaining ) =
                            quotedUntil '"' rest False []
                    in
                    add Quoted ('"' :: consumed) remaining

                _ ->
                    ( Text, [], [] )
    in
    case chars of
        [] ->
            ( Text, [], [] )

        '"' :: '"' :: '"' :: rest ->
            if language == Elm then
                let
                    ( consumed, remaining ) =
                        multiline rest []
                in
                add Quoted ('"' :: '"' :: '"' :: consumed) remaining

            else
                quoted

        '"' :: _ ->
            quoted

        '\'' :: rest ->
            if language == Elm then
                let
                    ( consumed, remaining ) =
                        quotedUntil '\'' rest False []
                in
                add Quoted ('\'' :: consumed) remaining

            else
                add Text [ '\'' ] rest

        '-' :: '-' :: rest ->
            if language == Elm then
                let
                    ( consumed, remaining ) =
                        takeWhile ((/=) '\n') rest []
                in
                add Comment ('-' :: '-' :: consumed) remaining

            else
                add Text [ '-' ] ('-' :: rest)

        '{' :: '-' :: rest ->
            if language == Elm then
                let
                    ( consumed, remaining ) =
                        blockComment 1 rest []
                in
                add Comment ('{' :: '-' :: consumed) remaining

            else
                add Text [ '{' ] ('-' :: rest)

        first :: rest ->
            if Char.isDigit first then
                let
                    ( consumed, remaining ) =
                        takeWhile (\c -> Char.isDigit c || List.member c [ '.', 'e', 'E', '_' ]) rest []
                in
                add Number (first :: consumed) remaining

            else if Char.isAlpha first || first == '_' then
                let
                    ( consumed, remaining ) =
                        takeWhile (\c -> Char.isAlphaNum c || c == '_' || (language == Elm && c == '\'')) rest []

                    word =
                        String.fromList (first :: consumed)

                    keyword =
                        if language == Json then
                            List.member word [ "true", "false", "null" ]

                        else
                            List.member word [ "module", "exposing", "import", "as", "type", "alias", "if", "then", "else", "case", "of", "let", "in", "port", "infix", "left", "right", "non" ]
                in
                add
                    (if keyword then
                        Keyword

                     else
                        Text
                    )
                    (first :: consumed)
                    remaining

            else
                let
                    ( consumed, remaining ) =
                        takeWhile (\c -> not (Char.isAlphaNum c) && not (List.member c [ '"', '\'', '-', '{', '_' ])) rest []
                in
                add Text (first :: consumed) remaining


quotedUntil : Char -> List Char -> Bool -> List Char -> ( List Char, List Char )
quotedUntil delimiter chars escaped reversed =
    case chars of
        [] ->
            ( List.reverse reversed, [] )

        first :: rest ->
            if escaped then
                quotedUntil delimiter rest False (first :: reversed)

            else if first == delimiter then
                ( List.reverse (first :: reversed), rest )

            else
                quotedUntil delimiter rest (first == '\\') (first :: reversed)


multiline : List Char -> List Char -> ( List Char, List Char )
multiline chars reversed =
    case chars of
        [] ->
            ( List.reverse reversed, [] )

        '"' :: '"' :: '"' :: rest ->
            ( List.reverse ('"' :: '"' :: '"' :: reversed), rest )

        '\\' :: following :: rest ->
            multiline rest (following :: '\\' :: reversed)

        first :: rest ->
            multiline rest (first :: reversed)


blockComment : Int -> List Char -> List Char -> ( List Char, List Char )
blockComment depth chars reversed =
    case chars of
        [] ->
            ( List.reverse reversed, [] )

        '{' :: '-' :: rest ->
            blockComment (depth + 1) rest ('-' :: '{' :: reversed)

        '-' :: '}' :: rest ->
            if depth == 1 then
                ( List.reverse ('}' :: '-' :: reversed), rest )

            else
                blockComment (depth - 1) rest ('}' :: '-' :: reversed)

        first :: rest ->
            blockComment depth rest (first :: reversed)


takeWhile : (Char -> Bool) -> List Char -> List Char -> ( List Char, List Char )
takeWhile accepts chars reversed =
    case chars of
        [] ->
            ( List.reverse reversed, [] )

        first :: rest ->
            if accepts first then
                takeWhile accepts rest (first :: reversed)

            else
                ( List.reverse reversed, chars )
