module Klar.Markdown.Inline exposing (Inline(..), parse, plainText)

{-| The inline part of Markdown: emphasis, code spans, links, images, line breaks.

`parse` reads a paragraph (a heading, a table cell ...) in one pass over its
characters. It never fails and its cost is linear in the length of the text:

  - Emphasis and links are resolved with a small stack of open frames (never more
    than `maxFrames`; when a thirteenth would open, the oldest becomes plain text).
  - Everything that looks ahead (the end of a code span, the rest of a link, an
    autolink) draws on one budget that is proportional to the length of the text.
    When it is spent, the rest of the text is read without looking ahead, so
    `[[[[[[[[` or a thousand backticks of different lengths cost no more than
    ordinary text.
  - A pair of delimiters wraps its content at most three times, so `*****a*****`
    nests a bounded number of times.

When the paragraph is the last one of the text (`final`) and ends inside a
construct (an open `**bold`, an open code span, a link whose address has not
arrived yet), the construct is shown as if it were finished. A text that is still
being written then looks right at every moment.

-}

import Klar.Markdown.Url as Url


type Inline
    = Text String
    | Code String
    | Emphasis (List Inline)
    | Strong (List Inline)
    | Strikethrough (List Inline)
    | Link { destination : String, title : String } (List Inline)
    | Image { source : String, title : String, alt : String }
    | SoftBreak
    | HardBreak


{-| Most frames open at the same time.
-}
maxFrames : Int
maxFrames =
    12


{-| Most times one run of delimiters wraps content: `***a***` is two. Together with
`maxFrames` it bounds how deep the result can nest.
-}
maxWraps : Int
maxWraps =
    3



-- STATE


type alias Run =
    { char : Char
    , count : Int
    , original : Int
    , wraps : Int
    , canOpen : Bool
    , canClose : Bool
    }


type Kind
    = Root
    | Delimiter Run
    | Bracket { image : Bool, active : Bool }


type alias Frame =
    { kind : Kind
    , content : List Inline
    }


type alias State =
    { stack : List Frame
    , pending : List Char
    , previous : Char
    , budget : Int
    }


initial : Int -> State
initial length =
    { stack = [ { kind = Root, content = [] } ]
    , pending = []
    , previous = ' '
    , budget = 4 * length + 2048
    }


{-| The inline content of a text. The first argument says that nothing follows the
text, so a construct that is still open at its end is closed for the reader.
-}
parse : Bool -> String -> List Inline
parse final text =
    String.toList text
        |> (\chars -> scan final chars (initial (String.length text)))
        |> finish final
        |> mergeText


{-| The text of the inline content without any markup, line breaks as spaces.
-}
plainText : List Inline -> String
plainText inlines =
    String.concat (List.map plainOne inlines)


plainOne : Inline -> String
plainOne inline =
    case inline of
        Text text ->
            text

        Code text ->
            text

        Emphasis children ->
            plainText children

        Strong children ->
            plainText children

        Strikethrough children ->
            plainText children

        Link _ children ->
            plainText children

        Image image ->
            image.alt

        SoftBreak ->
            " "

        HardBreak ->
            " "



-- THE LOOP


scan : Bool -> List Char -> State -> State
scan final chars st =
    case chars of
        [] ->
            st

        c :: rest ->
            case c of
                '\\' ->
                    case rest of
                        '\n' :: after ->
                            scan final (skipSpaces after) (lineBreak HardBreak st)

                        next :: after ->
                            if isAsciiPunctuation next then
                                scan final after (literal next st)

                            else
                                scan final rest (literal '\\' st)

                        [] ->
                            scan final rest (literal '\\' st)

                '\n' ->
                    let
                        trailing =
                            countSpaces st.pending

                        node =
                            if trailing >= 2 then
                                HardBreak

                            else
                                SoftBreak
                    in
                    scan final (skipSpaces rest) (lineBreak node st)

                '`' ->
                    let
                        ( st1, after ) =
                            codeSpan final chars st
                    in
                    scan final after st1

                '*' ->
                    let
                        ( st1, after ) =
                            delimiter c chars st
                    in
                    scan final after st1

                '_' ->
                    let
                        ( st1, after ) =
                            delimiter c chars st
                    in
                    scan final after st1

                '~' ->
                    let
                        ( st1, after ) =
                            delimiter c chars st
                    in
                    scan final after st1

                '[' ->
                    scan final rest (setPrevious '[' (openBracket False st))

                '!' ->
                    case rest of
                        '[' :: after ->
                            scan final after (setPrevious '[' (openBracket True st))

                        _ ->
                            scan final rest (literal '!' st)

                ']' ->
                    let
                        ( st1, after ) =
                            closeBracket final rest st
                    in
                    scan final after st1

                '<' ->
                    if inBracket st then
                        scan final rest (literal '<' st)

                    else
                        case autolink rest st.budget of
                            Just found ->
                                scan final found.rest (setPrevious '>' (emit (Link { destination = found.destination, title = "" } [ Text found.shown ]) (spend found.spent st)))

                            Nothing ->
                                scan final rest (literal '<' st)

                _ ->
                    if (c == 'h' || c == 'H') && canStartUrl st.previous && not (inBracket st) then
                        case bareUrl chars st.budget of
                            Just found ->
                                scan final found.rest (setPrevious (lastChar found.url) (emit (Link { destination = found.url, title = "" } [ Text found.url ]) (spend found.spent st)))

                            Nothing ->
                                scan final rest (literal c st)

                    else
                        scan final rest (literal c st)


literal : Char -> State -> State
literal c st =
    { st | pending = c :: st.pending, previous = c }


literalString : String -> State -> State
literalString text st =
    String.foldl literal st text


setPrevious : Char -> State -> State
setPrevious c st =
    { st | previous = c }


spend : Int -> State -> State
spend steps st =
    { st | budget = st.budget - steps }


lastChar : String -> Char
lastChar text =
    String.right 1 text |> String.uncons |> Maybe.map Tuple.first |> Maybe.withDefault ' '


{-| Put pending text in a node on the top frame.
-}
flush : State -> State
flush st =
    case st.pending of
        [] ->
            st

        chars ->
            addNode (Text (String.fromList (List.reverse chars))) { st | pending = [] }


addNode : Inline -> State -> State
addNode node st =
    case st.stack of
        top :: below ->
            { st | stack = { top | content = node :: top.content } :: below }

        [] ->
            st


emit : Inline -> State -> State
emit node st =
    addNode node (flush st)


{-| A line break: the spaces before it are dropped.
-}
lineBreak : Inline -> State -> State
lineBreak node st =
    emit node { st | pending = dropSpaces st.pending, previous = '\n' }


countSpaces : List Char -> Int
countSpaces chars =
    countSpacesHelp chars 0


countSpacesHelp : List Char -> Int -> Int
countSpacesHelp chars total =
    case chars of
        ' ' :: rest ->
            countSpacesHelp rest (total + 1)

        _ ->
            total


dropSpaces : List Char -> List Char
dropSpaces chars =
    case chars of
        ' ' :: rest ->
            dropSpaces rest

        _ ->
            chars


skipSpaces : List Char -> List Char
skipSpaces chars =
    case chars of
        ' ' :: rest ->
            skipSpaces rest

        '\t' :: rest ->
            skipSpaces rest

        _ ->
            chars


inBracket : State -> Bool
inBracket st =
    List.any
        (\frame ->
            case frame.kind of
                Bracket _ ->
                    True

                _ ->
                    False
        )
        st.stack



-- CODE SPANS


type Closer
    = Closed (List Char) (List Char) Int
    | NotClosed Bool (List Char) Int


codeSpan : Bool -> List Char -> State -> ( State, List Char )
codeSpan final chars st =
    let
        ( ticks, after ) =
            takeRun '`' chars
    in
    case findCloser ticks after st.budget of
        Closed content afterClose spent ->
            ( setPrevious '`' (emit (Code (codeText content)) (spend spent st)), afterClose )

        NotClosed reachedEnd content spent ->
            if final && reachedEnd && opensCode after && String.trim (String.fromList content) /= "" then
                -- the text ends inside the code span: show it as one
                ( setPrevious '`' (emit (Code (codeText content)) (spend spent st)), [] )

            else
                ( literalString (String.repeat ticks "`") (spend spent st), after )


opensCode : List Char -> Bool
opensCode after =
    case after of
        c :: _ ->
            not (isWhitespace c)

        [] ->
            False


{-| Takes the run of the same character at the start: how many, and what follows.
-}
takeRun : Char -> List Char -> ( Int, List Char )
takeRun char chars =
    takeRunHelp char chars 0


takeRunHelp : Char -> List Char -> Int -> ( Int, List Char )
takeRunHelp char chars count =
    case chars of
        c :: rest ->
            if c == char then
                takeRunHelp char rest (count + 1)

            else
                ( count, chars )

        [] ->
            ( count, chars )


findCloser : Int -> List Char -> Int -> Closer
findCloser ticks chars limit =
    findCloserHelp ticks chars limit 0 []


findCloserHelp : Int -> List Char -> Int -> Int -> List Char -> Closer
findCloserHelp ticks chars limit spent acc =
    case chars of
        [] ->
            NotClosed True (List.reverse acc) spent

        c :: rest ->
            if spent >= limit then
                NotClosed False [] spent

            else if c == '`' then
                let
                    ( count, after ) =
                        takeRun '`' chars
                in
                if count == ticks then
                    Closed (List.reverse acc) after (spent + count)

                else
                    findCloserHelp ticks after limit (spent + count) (List.repeat count '`' ++ acc)

            else
                findCloserHelp ticks rest limit (spent + 1) (c :: acc)


{-| The text of a code span: line endings become spaces, and one space on each
side is dropped when both are there and the text is not only spaces.
-}
codeText : List Char -> String
codeText chars =
    let
        text =
            String.map
                (\c ->
                    if c == '\n' then
                        ' '

                    else
                        c
                )
                (String.fromList chars)
    in
    if String.length text >= 2 && String.startsWith " " text && String.endsWith " " text && String.trim text /= "" then
        String.slice 1 -1 text

    else
        text



-- DELIMITERS: EMPHASIS, STRONG, STRIKETHROUGH


delimiter : Char -> List Char -> State -> ( State, List Char )
delimiter char chars st =
    let
        ( count, after ) =
            takeRun char chars

        next =
            case after of
                n :: _ ->
                    n

                [] ->
                    ' '

        before =
            st.previous

        leftFlanking =
            not (isWhitespace next) && (not (isPunctuation next) || isWhitespace before || isPunctuation before)

        rightFlanking =
            not (isWhitespace before) && (not (isPunctuation before) || isWhitespace next || isPunctuation next)

        run =
            if char == '_' then
                { char = char
                , count = count
                , original = count
                , wraps = 0
                , canOpen = leftFlanking && (not rightFlanking || isPunctuation before)
                , canClose = rightFlanking && (not leftFlanking || isPunctuation next)
                }

            else
                { char = char
                , count = count
                , original = count
                , wraps = 0
                , canOpen = leftFlanking
                , canClose = rightFlanking
                }
    in
    if char == '~' && count /= 2 then
        ( setPrevious char (literalString (String.repeat count "~") st), after )

    else
        ( setPrevious char (handleRun run (flush st)), after )


handleRun : Run -> State -> State
handleRun run st =
    if run.canClose then
        matchLoop maxWraps run st

    else
        afterMatching run st


{-| What is left of a run that matched nothing (more): it opens, or it is text.
-}
afterMatching : Run -> State -> State
afterMatching run st =
    if run.count <= 0 then
        st

    else if run.canOpen then
        pushFrame { kind = Delimiter run, content = [] } st

    else
        literalString (String.repeat run.count (String.fromChar run.char)) st


matchLoop : Int -> Run -> State -> State
matchLoop budget run st =
    if run.count <= 0 then
        st

    else if budget <= 0 then
        afterMatching run st

    else
        case findOpener run st.stack [] of
            Nothing ->
                afterMatching run st

            Just found ->
                let
                    opener =
                        found.run

                    below =
                        found.below

                    inner =
                        List.reverse (absorb found.above found.frame.content)

                    used =
                        if opener.char == '~' || (opener.count >= 2 && run.count >= 2) then
                            2

                        else
                            1

                    node =
                        if opener.char == '~' then
                            Strikethrough inner

                        else if used == 2 then
                            Strong inner

                        else
                            Emphasis inner

                    openerLeft =
                        opener.count - used

                    stack =
                        if openerLeft > 0 then
                            { kind = Delimiter { opener | count = openerLeft, wraps = opener.wraps + 1 }, content = [ node ] } :: below

                        else
                            addToTop [ node ] below
                in
                matchLoop (budget - 1) { run | count = run.count - used } { st | stack = stack }


findOpener : Run -> List Frame -> List Frame -> Maybe { above : List Frame, frame : Frame, run : Run, below : List Frame }
findOpener run frames skipped =
    case frames of
        frame :: below ->
            case frame.kind of
                Delimiter opener ->
                    if pairs opener run then
                        Just { above = List.reverse skipped, frame = frame, run = opener, below = below }

                    else
                        findOpener run below (frame :: skipped)

                _ ->
                    Nothing

        [] ->
            Nothing


{-| Can this opener and this closer wrap something together? The rule of three:
a delimiter that can both open and close does not match when the lengths of the two
runs add up to a multiple of three (unless both are).
-}
pairs : Run -> Run -> Bool
pairs opener closer =
    if opener.char /= closer.char || opener.wraps >= maxWraps then
        False

    else if opener.char == '~' then
        opener.count == 2 && closer.count == 2

    else
        not
            ((opener.canClose || closer.canOpen)
                && modBy 3 (opener.original + closer.original)
                == 0
                && not (modBy 3 opener.original == 0 && modBy 3 closer.original == 0)
            )


{-| Frames that turn into text, merged (as reversed content) in front of `base`.
The frames are given top first.
-}
absorb : List Frame -> List Inline -> List Inline
absorb frames base =
    List.foldr (\frame content -> frame.content ++ (literalNode frame :: content)) base frames


literalNode : Frame -> Inline
literalNode frame =
    case frame.kind of
        Delimiter run ->
            Text (String.repeat run.count (String.fromChar run.char))

        Bracket { image } ->
            Text
                (if image then
                    "!["

                 else
                    "["
                )

        Root ->
            Text ""


{-| Add reversed content to the top frame of a stack.
-}
addToTop : List Inline -> List Frame -> List Frame
addToTop nodes stack =
    case stack of
        top :: below ->
            { top | content = nodes ++ top.content } :: below

        [] ->
            stack


pushFrame : Frame -> State -> State
pushFrame frame st0 =
    let
        st =
            flush st0

        stack =
            if List.length st.stack > maxFrames then
                dropOldest st.stack

            else
                st.stack
    in
    { st | stack = frame :: stack }


{-| The frame just above the root becomes text.
-}
dropOldest : List Frame -> List Frame
dropOldest stack =
    case List.reverse stack of
        root :: oldest :: newer ->
            List.reverse ({ root | content = absorb [ oldest ] root.content } :: newer)

        _ ->
            stack



-- LINKS AND IMAGES


openBracket : Bool -> State -> State
openBracket image st =
    pushFrame { kind = Bracket { image = image, active = True }, content = [] } st


type Tail
    = Complete { destination : String, title : String, rest : List Char, spent : Int }
    | Incomplete Int
    | Invalid Int


closeBracket : Bool -> List Char -> State -> ( State, List Char )
closeBracket final rest st0 =
    let
        st =
            flush st0
    in
    case findBracket st.stack [] of
        Nothing ->
            ( literal ']' st, rest )

        Just found ->
            let
                asText =
                    { st | stack = dropBracket found.above found.frame found.below }
            in
            if not found.info.active || st.budget <= 0 then
                ( literal ']' asText, rest )

            else
                case parseTail rest st.budget of
                    Complete tail ->
                        let
                            children =
                                List.reverse (absorb found.above found.frame.content)

                            node =
                                if found.info.image then
                                    Image { source = tail.destination, title = tail.title, alt = plainText children }

                                else
                                    Link { destination = tail.destination, title = tail.title } children

                            stack =
                                addToTop [ node ] found.below
                        in
                        ( setPrevious ')'
                            (spend tail.spent
                                { st
                                    | stack =
                                        if found.info.image then
                                            stack

                                        else
                                            deactivate stack
                                }
                            )
                        , tail.rest
                        )

                    Incomplete spent ->
                        if final then
                            -- the address has not arrived yet: the reader sees the text of the link
                            ( setPrevious ')' (spend spent { st | stack = addToTop (absorb found.above found.frame.content) found.below }), [] )

                        else
                            ( literal ']' (spend spent asText), rest )

                    Invalid spent ->
                        ( literal ']' (spend spent asText), rest )


findBracket : List Frame -> List Frame -> Maybe { above : List Frame, frame : Frame, info : { image : Bool, active : Bool }, below : List Frame }
findBracket frames skipped =
    case frames of
        frame :: below ->
            case frame.kind of
                Bracket info ->
                    Just { above = List.reverse skipped, frame = frame, info = info, below = below }

                Delimiter _ ->
                    findBracket below (frame :: skipped)

                Root ->
                    Nothing

        [] ->
            Nothing


{-| The bracket and the frames above it become text.
-}
dropBracket : List Frame -> Frame -> List Frame -> List Frame
dropBracket above bracketFrame below =
    case below of
        top :: rest ->
            { top | content = absorb (above ++ [ bracketFrame ]) top.content } :: rest

        [] ->
            []


{-| After a link, the earlier `[` cannot start a link any more: links do not
contain links.
-}
deactivate : List Frame -> List Frame
deactivate stack =
    List.map
        (\frame ->
            case frame.kind of
                Bracket info ->
                    if info.image then
                        frame

                    else
                        { frame | kind = Bracket { info | active = False } }

                _ ->
                    frame
        )
        stack


{-| The `(address "title")` after the closing bracket of a link. `budget` caps the
characters looked at.
-}
parseTail : List Char -> Int -> Tail
parseTail chars budget =
    case chars of
        '(' :: rest ->
            tailStart (skipBlank rest 1) budget

        _ ->
            Invalid 0


{-| Skips spaces, tabs and line endings.
-}
skipBlank : List Char -> Int -> ( List Char, Int )
skipBlank chars spent =
    case chars of
        ' ' :: rest ->
            skipBlank rest (spent + 1)

        '\t' :: rest ->
            skipBlank rest (spent + 1)

        '\n' :: rest ->
            skipBlank rest (spent + 1)

        _ ->
            ( chars, spent )


tailStart : ( List Char, Int ) -> Int -> Tail
tailStart ( chars, spent ) budget =
    case chars of
        [] ->
            Incomplete spent

        ')' :: rest ->
            Complete { destination = "", title = "", rest = rest, spent = spent + 1 }

        '<' :: rest ->
            angleDestination rest [] (spent + 1) budget

        _ ->
            rawDestination chars [] 0 spent budget


angleDestination : List Char -> List Char -> Int -> Int -> Tail
angleDestination chars acc spent budget =
    if spent > min budget Url.maxLength then
        Invalid spent

    else
        case chars of
            [] ->
                Incomplete spent

            '>' :: rest ->
                afterDestination (String.fromList (List.reverse acc)) (skipBlank rest (spent + 1)) (startsWithBlank rest) budget

            '\n' :: _ ->
                Invalid spent

            '<' :: _ ->
                Invalid spent

            '\\' :: next :: rest ->
                if isAsciiPunctuation next then
                    angleDestination rest (next :: acc) (spent + 2) budget

                else
                    angleDestination (next :: rest) ('\\' :: acc) (spent + 1) budget

            c :: rest ->
                angleDestination rest (c :: acc) (spent + 1) budget


rawDestination : List Char -> List Char -> Int -> Int -> Int -> Tail
rawDestination chars acc depth spent budget =
    if spent > min budget Url.maxLength then
        Invalid spent

    else
        case chars of
            [] ->
                Incomplete spent

            '\\' :: next :: rest ->
                if isAsciiPunctuation next then
                    rawDestination rest (next :: acc) depth (spent + 2) budget

                else
                    rawDestination (next :: rest) ('\\' :: acc) depth (spent + 1) budget

            '(' :: rest ->
                if depth >= 4 then
                    Invalid spent

                else
                    rawDestination rest ('(' :: acc) (depth + 1) (spent + 1) budget

            ')' :: rest ->
                if depth == 0 then
                    Complete { destination = String.fromList (List.reverse acc), title = "", rest = rest, spent = spent + 1 }

                else
                    rawDestination rest (')' :: acc) (depth - 1) (spent + 1) budget

            c :: rest ->
                if c == ' ' || c == '\t' || c == '\n' then
                    afterDestination (String.fromList (List.reverse acc)) (skipBlank chars spent) True budget

                else if Char.toCode c < 0x20 then
                    Invalid spent

                else
                    rawDestination rest (c :: acc) depth (spent + 1) budget


startsWithBlank : List Char -> Bool
startsWithBlank chars =
    case chars of
        c :: _ ->
            c == ' ' || c == '\t' || c == '\n'

        [] ->
            False


afterDestination : String -> ( List Char, Int ) -> Bool -> Int -> Tail
afterDestination destination ( chars, spent ) separated budget =
    case chars of
        [] ->
            Incomplete spent

        ')' :: rest ->
            Complete { destination = destination, title = "", rest = rest, spent = spent + 1 }

        '"' :: rest ->
            if separated then
                title destination '"' rest [] (spent + 1) budget

            else
                Invalid spent

        '\'' :: rest ->
            if separated then
                title destination '\'' rest [] (spent + 1) budget

            else
                Invalid spent

        '(' :: rest ->
            if separated then
                title destination ')' rest [] (spent + 1) budget

            else
                Invalid spent

        _ ->
            Invalid spent


title : String -> Char -> List Char -> List Char -> Int -> Int -> Tail
title destination close chars acc spent budget =
    if spent > min budget 1000 then
        Invalid spent

    else
        case chars of
            [] ->
                Incomplete spent

            '\\' :: next :: rest ->
                if isAsciiPunctuation next then
                    title destination close rest (next :: acc) (spent + 2) budget

                else
                    title destination close (next :: rest) ('\\' :: acc) (spent + 1) budget

            c :: rest ->
                if c == close then
                    afterTitle destination (String.fromList (List.reverse acc)) (skipBlank rest (spent + 1))

                else
                    title destination close rest (c :: acc) (spent + 1) budget


afterTitle : String -> String -> ( List Char, Int ) -> Tail
afterTitle destination text ( chars, spent ) =
    case chars of
        [] ->
            Incomplete spent

        ')' :: rest ->
            Complete { destination = destination, title = text, rest = rest, spent = spent + 1 }

        _ ->
            Invalid spent



-- AUTOLINKS: <https://example.com> AND https://example.com


autolink : List Char -> Int -> Maybe { destination : String, shown : String, rest : List Char, spent : Int }
autolink chars budget =
    case collectUntilGreater chars [] 0 (min budget Url.maxLength) of
        Just ( inside, rest, spent ) ->
            let
                text =
                    String.fromList inside
            in
            if isAbsoluteUri text then
                Just { destination = text, shown = text, rest = rest, spent = spent }

            else if isEmailAddress text then
                Just { destination = "mailto:" ++ text, shown = text, rest = rest, spent = spent }

            else
                Nothing

        Nothing ->
            Nothing


collectUntilGreater : List Char -> List Char -> Int -> Int -> Maybe ( List Char, List Char, Int )
collectUntilGreater chars acc spent limit =
    if spent > limit then
        Nothing

    else
        case chars of
            [] ->
                Nothing

            '>' :: rest ->
                Just ( List.reverse acc, rest, spent + 1 )

            c :: rest ->
                if c == '<' || isWhitespace c || Char.toCode c < 0x20 then
                    Nothing

                else
                    collectUntilGreater rest (c :: acc) (spent + 1) limit


{-| A scheme of 2 to 32 characters, a colon and anything but white space.
-}
isAbsoluteUri : String -> Bool
isAbsoluteUri text =
    case String.indexes ":" text of
        position :: _ ->
            let
                scheme =
                    String.left position text
            in
            position >= 2 && position <= 32 && validScheme scheme

        [] ->
            False


validScheme : String -> Bool
validScheme scheme =
    case String.uncons scheme of
        Just ( first, rest ) ->
            isAsciiLetter first && String.all (\c -> isAsciiLetter c || isDigit c || c == '+' || c == '-' || c == '.') rest

        Nothing ->
            False


isEmailAddress : String -> Bool
isEmailAddress text =
    case String.split "@" text of
        [ local, domain ] ->
            local
                /= ""
                && String.all (\c -> isAsciiLetter c || isDigit c || String.contains (String.fromChar c) ".!#$%&'*+/=?^_`{|}~-") local
                && domain
                /= ""
                && List.all
                    (\label -> label /= "" && String.all (\c -> isAsciiLetter c || isDigit c || c == '-') label)
                    (String.split "." domain)

        _ ->
            False


bareUrl : List Char -> Int -> Maybe { url : String, rest : List Char, spent : Int }
bareUrl chars budget =
    let
        start =
            String.toLower (String.fromList (List.take 8 chars))

        schemeLength =
            if String.startsWith "https://" start then
                8

            else if String.startsWith "http://" start then
                7

            else
                0
    in
    if schemeLength == 0 then
        Nothing

    else
        let
            ( body, after, spent ) =
                collectUrl (List.drop schemeLength chars) [] 0 (min budget Url.maxLength)

            ( trimmed, rest ) =
                trimUrl (occurrences '(' body) (occurrences ')' body) body after
        in
        case List.reverse trimmed of
            first :: _ ->
                if isAlphaNumeric first || Char.toCode first > 0x7F then
                    Just { url = String.fromList (List.take schemeLength chars) ++ String.fromList (List.reverse trimmed), rest = rest, spent = spent + schemeLength }

                else
                    Nothing

            [] ->
                Nothing


{-| The address up to white space or `<`: it comes back reversed, with what follows.
-}
collectUrl : List Char -> List Char -> Int -> Int -> ( List Char, List Char, Int )
collectUrl chars acc spent limit =
    case chars of
        c :: rest ->
            if spent >= limit || isWhitespace c || c == '<' || Char.toCode c < 0x20 then
                ( acc, chars, spent )

            else
                collectUrl rest (c :: acc) (spent + 1) limit

        [] ->
            ( acc, chars, spent )


{-| Takes trailing punctuation and an unmatched `)` off the (reversed) address and
gives it back to the text that follows. The first two numbers are the opening and
the closing parentheses that are left in the address.
-}
trimUrl : Int -> Int -> List Char -> List Char -> ( List Char, List Char )
trimUrl opening closing reversed after =
    case reversed of
        c :: before ->
            if String.contains (String.fromChar c) "?!.,:;'\"*_~" then
                trimUrl opening closing before (c :: after)

            else if c == ')' && closing > opening then
                trimUrl opening (closing - 1) before (c :: after)

            else
                ( reversed, after )

        [] ->
            ( reversed, after )


occurrences : Char -> List Char -> Int
occurrences char chars =
    List.foldl
        (\c total ->
            if c == char then
                total + 1

            else
                total
        )
        0
        chars



-- THE END OF THE TEXT


finish : Bool -> State -> List Inline
finish final st0 =
    let
        st =
            flush { st0 | pending = dropSpaces st0.pending }
    in
    closeAll final st.stack


closeAll : Bool -> List Frame -> List Inline
closeAll final stack =
    case stack of
        [] ->
            []

        [ root ] ->
            List.reverse root.content

        frame :: below :: rest ->
            closeAll final ({ below | content = closedFrame final frame ++ below.content } :: rest)


{-| What a frame that never closed becomes, as reversed content: text, or, when
the text is still being written, the construct shown as if it were closed.
-}
closedFrame : Bool -> Frame -> List Inline
closedFrame final frame =
    case frame.kind of
        Delimiter run ->
            if final && hasVisibleContent frame.content then
                let
                    inner =
                        List.reverse frame.content

                    wrapped =
                        if run.char == '~' then
                            if run.count == 2 then
                                Just ( Strikethrough inner, 0 )

                            else
                                Nothing

                        else if run.count == 1 then
                            Just ( Emphasis inner, 0 )

                        else if run.count == 2 then
                            Just ( Strong inner, 0 )

                        else
                            Just ( Emphasis [ Strong inner ], run.count - 3 )
                in
                case wrapped of
                    Just ( node, left ) ->
                        if left > 0 then
                            [ node, Text (String.repeat left (String.fromChar run.char)) ]

                        else
                            [ node ]

                    Nothing ->
                        frame.content ++ [ literalNode frame ]

            else
                frame.content ++ [ literalNode frame ]

        _ ->
            frame.content ++ [ literalNode frame ]


hasVisibleContent : List Inline -> Bool
hasVisibleContent nodes =
    List.any
        (\node ->
            case node of
                Text text ->
                    String.trim text /= ""

                _ ->
                    True
        )
        nodes


{-| Joins neighbouring pieces of text and drops empty ones, at every level.
-}
mergeText : List Inline -> List Inline
mergeText nodes =
    mergeHelp nodes []


mergeHelp : List Inline -> List Inline -> List Inline
mergeHelp nodes acc =
    case nodes of
        [] ->
            List.reverse acc

        node :: rest ->
            case node of
                Text "" ->
                    mergeHelp rest acc

                Text text ->
                    case acc of
                        (Text before) :: older ->
                            mergeHelp rest (Text (before ++ text) :: older)

                        _ ->
                            mergeHelp rest (node :: acc)

                Emphasis children ->
                    mergeHelp rest (Emphasis (mergeText children) :: acc)

                Strong children ->
                    mergeHelp rest (Strong (mergeText children) :: acc)

                Strikethrough children ->
                    mergeHelp rest (Strikethrough (mergeText children) :: acc)

                Link target children ->
                    mergeHelp rest (Link target (mergeText children) :: acc)

                _ ->
                    mergeHelp rest (node :: acc)



-- CHARACTER CLASSES


isWhitespace : Char -> Bool
isWhitespace c =
    let
        code =
            Char.toCode c
    in
    c == ' ' || c == '\t' || c == '\n' || c == '\u{000D}' || c == '\u{000C}' || code == 0xA0 || code == 0x1680 || (code >= 0x2000 && code <= 0x200A) || code == 0x202F || code == 0x205F || code == 0x3000


isAsciiPunctuation : Char -> Bool
isAsciiPunctuation c =
    let
        code =
            Char.toCode c
    in
    (code >= 33 && code <= 47) || (code >= 58 && code <= 64) || (code >= 91 && code <= 96) || (code >= 123 && code <= 126)


isPunctuation : Char -> Bool
isPunctuation c =
    let
        code =
            Char.toCode c
    in
    isAsciiPunctuation c
        || List.member code [ 0xA1, 0xA7, 0xAB, 0xB6, 0xB7, 0xBB, 0xBF ]
        || (code >= 0x2010 && code <= 0x2027)
        || (code >= 0x2030 && code <= 0x205E)
        || (code >= 0x3001 && code <= 0x3003)
        || (code >= 0x3008 && code <= 0x3011)
        || (code >= 0xFF01 && code <= 0xFF0F)


isAsciiLetter : Char -> Bool
isAsciiLetter c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')


isDigit : Char -> Bool
isDigit c =
    c >= '0' && c <= '9'


{-| A plain address starts after white space, after an opening parenthesis or quote,
and after the marks of emphasis, but not in the middle of a word or after `<`.
-}
canStartUrl : Char -> Bool
canStartUrl previous =
    isWhitespace previous || String.contains (String.fromChar previous) "(*_~\"'"



isAlphaNumeric : Char -> Bool
isAlphaNumeric c =
    isAsciiLetter c || isDigit c
