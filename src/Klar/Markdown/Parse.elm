module Klar.Markdown.Parse exposing
    ( Align(..)
    , Block(..)
    , Document
    , Item
    , maxChars
    , maxDepth
    , parse
    , plainText
    , slug
    )

{-| The block structure of Markdown: headings, paragraphs, quotes, lists, code,
tables.

This is the parser behind [Klar.Markdown](Klar-Markdown). It is not exposed; the
tests read its result.

**What it guarantees.**

  - It is total: any text gives a `Document`, nothing throws, nothing loops.
  - It is linear: every line is looked at once per level of nesting, and the
    nesting is at most `maxDepth`; a deeper `>` or list marker is plain text. A text
    longer than `maxChars` is cut (the `Document` says so) before it is read.
  - It is tolerant: text that stops in the middle of a construct gives the
    construct as far as it goes. An open code fence runs to the end, a table row
    with too few cells is padded, a link whose address has not arrived shows its
    text (see [Klar.Markdown.Inline](Klar-Markdown-Inline)).
  - It is stable: the blocks that are complete in a text do not change when more
    text arrives. Only the last block can. (That is why reference links, which
    work backwards, and setext headings, which turn the paragraph above into a
    heading, are not supported.)

It reads a practical subset of CommonMark and of GFM: headings with `#`, block
quotes, bullet and numbered lists (nested, tight and loose, with task items),
fenced and indented code, thematic breaks, tables with alignment and paragraphs
with emphasis, strong text, strikethrough, code spans, links, images, autolinks
and hard line breaks. Raw HTML and entities are not interpreted: they are text.

-}

import Dict exposing (Dict)
import Klar.Markdown.Inline as Inline exposing (Inline)
import Klar.Markdown.Utf16 as Utf16
import Set exposing (Set)


type Align
    = AlignNone
    | AlignLeft
    | AlignCenter
    | AlignRight


type Block
    = Paragraph (List Inline)
    | HeadingBlock { level : Int, id : String, content : List Inline }
    | Quote (List Block)
    | CodeBlock { language : String, code : String }
    | ListBlock { start : Maybe Int, tight : Bool, items : List Item }
    | Rule
    | Table { aligns : List Align, header : List (List Inline), rows : List (List (List Inline)) }


type alias Item =
    { task : Maybe Bool
    , blocks : List Block
    }


type alias Document =
    { blocks : List Block
    , truncated : Maybe { shown : Int, total : Int }
    }


{-| The most characters that are read. A longer text is cut, and the document says
how much was left out.
-}
maxChars : Int
maxChars =
    100000


{-| The most levels of quotes and lists inside each other.
-}
maxDepth : Int
maxDepth =
    16


type alias Context =
    { depth : Int
    , final : Bool
    }


type alias Parsed =
    { blocks : List Block
    , separated : Bool
    }


{-| Reads a text.
-}
parse : String -> Document
parse input =
    let
        text =
            Utf16.repair input

        total =
            String.length text

        ( kept, truncated ) =
            if total > maxChars then
                let
                    shown =
                        cut maxChars text
                in
                ( shown, Just { shown = String.length shown, total = total } )

            else
                ( text, Nothing )

        lines =
            kept
                |> String.replace "\u{0000}" "�"
                |> String.lines
                |> dropLastEmpty

        final =
            truncated == Nothing && not (endsWithBlank lines)

        parsed =
            parseBlocks { depth = 0, final = final } lines
    in
    { blocks = numberHeadings parsed.blocks
    , truncated = truncated
    }


{-| The first `n` characters, not ending in the middle of a surrogate pair.
-}
cut : Int -> String -> String
cut n text =
    let
        head =
            String.left n text
    in
    if Utf16.isHighSurrogate (String.right 1 head) then
        String.dropRight 1 head

    else
        head


dropLastEmpty : List String -> List String
dropLastEmpty lines =
    case List.reverse lines of
        "" :: before ->
            List.reverse before

        _ ->
            lines


endsWithBlank : List String -> Bool
endsWithBlank lines =
    case List.reverse lines of
        last :: _ ->
            isBlank last

        [] ->
            True



-- LINES


isBlank : String -> Bool
isBlank line =
    String.all (\c -> c == ' ' || c == '\t') line


{-| The columns of white space at the start of a line (a tab goes to the next
multiple of four) and the rest of the line.
-}
leading : String -> ( Int, String )
leading line =
    leadingHelp 0 line


leadingHelp : Int -> String -> ( Int, String )
leadingHelp column text =
    case String.uncons text of
        Just ( ' ', rest ) ->
            leadingHelp (column + 1) rest

        Just ( '\t', rest ) ->
            leadingHelp (column + 4 - modBy 4 column) rest

        _ ->
            ( column, text )


{-| Removes up to `n` columns of white space from the start of a line.
-}
stripColumns : Int -> String -> String
stripColumns n line =
    stripHelp n 0 line


stripHelp : Int -> Int -> String -> String
stripHelp n column text =
    if column >= n then
        if column > n then
            String.repeat (column - n) " " ++ text

        else
            text

    else
        case String.uncons text of
            Just ( ' ', rest ) ->
                stripHelp n (column + 1) rest

            Just ( '\t', rest ) ->
                stripHelp n (column + 4 - modBy 4 column) rest

            _ ->
                text


indentOf : String -> Int
indentOf line =
    Tuple.first (leading line)


{-| How many times a character starts a text.
-}
prefixCount : Char -> String -> Int
prefixCount char text =
    prefixCountHelp char text 0


prefixCountHelp : Char -> String -> Int -> Int
prefixCountHelp char text count =
    case String.uncons text of
        Just ( c, rest ) ->
            if c == char then
                prefixCountHelp char rest (count + 1)

            else
                count

        Nothing ->
            count



-- BLOCK STARTS


type alias Fence =
    { char : Char
    , length : Int
    , indent : Int
    , info : String
    }


fenceOpen : String -> Maybe Fence
fenceOpen line =
    let
        ( indent, rest ) =
            leading line
    in
    if indent > 3 then
        Nothing

    else
        case String.uncons rest of
            Just ( c, _ ) ->
                if c == '`' || c == '~' then
                    let
                        length =
                            prefixCount c rest

                        info =
                            String.trim (String.dropLeft length rest)
                    in
                    if length >= 3 && not (c == '`' && String.contains "`" info) then
                        Just { char = c, length = length, indent = indent, info = info }

                    else
                        Nothing

                else
                    Nothing

            Nothing ->
                Nothing


closesFence : Fence -> String -> Bool
closesFence fence line =
    let
        ( indent, rest ) =
            leading line

        length =
            prefixCount fence.char rest
    in
    indent <= 3 && length >= fence.length && isBlank (String.dropLeft length rest)


{-| A heading written with `#`: its level and its text.
-}
atxHeading : String -> Maybe ( Int, String )
atxHeading line =
    let
        ( indent, rest ) =
            leading line

        level =
            prefixCount '#' rest

        after =
            String.dropLeft level rest
    in
    if indent > 3 || level < 1 || level > 6 then
        Nothing

    else if after == "" then
        Just ( level, "" )

    else if String.startsWith " " after || String.startsWith "\t" after then
        Just ( level, withoutClosingSequence (String.trim after) )

    else
        Nothing


{-| `## Title ##` is the title: a closing run of `#` after a space is not text.
-}
withoutClosingSequence : String -> String
withoutClosingSequence text =
    let
        closing =
            suffixCount '#' text

        before =
            String.dropRight closing text
    in
    if closing == 0 then
        text

    else if before == "" then
        ""

    else if String.endsWith " " before || String.endsWith "\t" before then
        String.trimRight before

    else
        text


suffixCount : Char -> String -> Int
suffixCount char text =
    suffixCountHelp char text 0


suffixCountHelp : Char -> String -> Int -> Int
suffixCountHelp char text count =
    if String.endsWith (String.fromChar char) text then
        suffixCountHelp char (String.dropRight 1 text) (count + 1)

    else
        count


isThematicBreak : String -> Bool
isThematicBreak line =
    let
        ( indent, rest ) =
            leading line
    in
    case String.uncons rest of
        Just ( c, _ ) ->
            indent
                <= 3
                && (c == '-' || c == '*' || c == '_')
                && String.all (\x -> x == c || x == ' ' || x == '\t') rest
                && String.length (String.filter (\x -> x == c) rest)
                >= 3

        Nothing ->
            False


{-| What follows the `>` of a quote line.
-}
quoteContent : String -> Maybe String
quoteContent line =
    let
        ( indent, rest ) =
            leading line
    in
    if indent <= 3 && String.startsWith ">" rest then
        let
            after =
                String.dropLeft 1 rest
        in
        if String.startsWith " " after then
            Just (String.dropLeft 1 after)

        else if String.startsWith "\t" after then
            Just ("   " ++ String.dropLeft 1 after)

        else
            Just after

    else
        Nothing


type MarkerKind
    = Bullet Char
    | Ordered Char


type alias Marker =
    { kind : MarkerKind
    , number : Int
    , indent : Int
    , width : Int
    , content : String
    }


listMarker : String -> Maybe Marker
listMarker line =
    let
        ( indent, rest ) =
            leading line
    in
    if indent > 3 then
        Nothing

    else
        case String.uncons rest of
            Just ( c, after ) ->
                if c == '-' || c == '+' || c == '*' then
                    markerTail (Bullet c) 0 indent 1 after

                else if isDigit c then
                    let
                        digits =
                            digitCount rest

                        delimiter =
                            String.slice digits (digits + 1) rest
                    in
                    if digits <= 9 && (delimiter == "." || delimiter == ")") then
                        markerTail
                            (Ordered (String.toList delimiter |> List.head |> Maybe.withDefault '.'))
                            (String.toInt (String.left digits rest) |> Maybe.withDefault 0)
                            indent
                            (digits + 1)
                            (String.dropLeft (digits + 1) rest)

                    else
                        Nothing

                else
                    Nothing

            Nothing ->
                Nothing


digitCount : String -> Int
digitCount text =
    digitCountHelp text 0


digitCountHelp : String -> Int -> Int
digitCountHelp text count =
    case String.uncons text of
        Just ( c, rest ) ->
            if isDigit c && count <= 9 then
                digitCountHelp rest (count + 1)

            else
                count

        Nothing ->
            count


markerTail : MarkerKind -> Int -> Int -> Int -> String -> Maybe Marker
markerTail kind number indent markerLength after =
    case String.uncons after of
        Nothing ->
            Just { kind = kind, number = number, indent = indent, width = indent + markerLength + 1, content = "" }

        Just ( c, _ ) ->
            if c == ' ' || c == '\t' then
                let
                    ( spaces, rest ) =
                        leading after
                in
                if rest == "" then
                    Just { kind = kind, number = number, indent = indent, width = indent + markerLength + 1, content = "" }

                else if spaces >= 5 then
                    -- the text after the marker is code inside the item
                    Just { kind = kind, number = number, indent = indent, width = indent + markerLength + 1, content = String.repeat (spaces - 1) " " ++ rest }

                else
                    Just { kind = kind, number = number, indent = indent, width = indent + markerLength + spaces, content = rest }

            else
                Nothing


sameKind : MarkerKind -> MarkerKind -> Bool
sameKind a b =
    a == b


{-| Does this line start a block that ends a paragraph above it? Containers
(quotes and lists) only when the nesting allows them.
-}
interruptsParagraph : Bool -> String -> Bool
interruptsParagraph containers line =
    isBlank line
        || atxHeading line
        /= Nothing
        || fenceOpen line
        /= Nothing
        || isThematicBreak line
        || (containers && (quoteContent line /= Nothing || listInterrupts line))


{-| A list can interrupt a paragraph when it has text in its first item and, when
numbered, starts at 1.
-}
listInterrupts : String -> Bool
listInterrupts line =
    case listMarker line of
        Just marker ->
            marker.content
                /= ""
                && (case marker.kind of
                        Ordered _ ->
                            marker.number == 1

                        Bullet _ ->
                            True
                   )

        Nothing ->
            False


{-| Does this line start a block of its own? It then cannot be a lazy
continuation of the paragraph in a quote or list item above it.
-}
startsBlock : Bool -> String -> Bool
startsBlock containers line =
    atxHeading line
        /= Nothing
        || fenceOpen line
        /= Nothing
        || isThematicBreak line
        || (containers && (quoteContent line /= Nothing || listMarker line /= Nothing))



-- WHAT IS OPEN AT THE END OF A RUN OF LINES


type Open
    = OpenParagraph
    | OpenFence Fence
    | Settled


{-| The state after one more line, as far as lazy continuation needs it: is a
paragraph open, so that a line without the marker can continue it?
-}
advance : Open -> String -> Open
advance open line =
    advanceWithin maxDepth open line


{-| `levels` is how many markers of quotes and lists inside each other are looked
into; a line with more is text (so that a line of `> > > > ...` costs no more than
a line of text).
-}
advanceWithin : Int -> Open -> String -> Open
advanceWithin levels open line =
    case open of
        OpenFence fence ->
            if closesFence fence line then
                Settled

            else
                open

        _ ->
            if isBlank line then
                Settled

            else
                case fenceOpen line of
                    Just fence ->
                        OpenFence fence

                    Nothing ->
                        if isThematicBreak line || atxHeading line /= Nothing then
                            Settled

                        else if levels <= 0 then
                            OpenParagraph

                        else
                            case quoteContent line of
                                Just inner ->
                                    advanceWithin (levels - 1) Settled inner

                                Nothing ->
                                    case listMarker line of
                                        Just marker ->
                                            if marker.content == "" then
                                                Settled

                                            else
                                                advanceWithin (levels - 1) Settled marker.content

                                        Nothing ->
                                            if indentOf line >= 4 && open /= OpenParagraph then
                                                Settled

                                            else
                                                OpenParagraph



-- BLOCKS


parseBlocks : Context -> List String -> Parsed
parseBlocks context lines =
    blocksHelp context lines [] False False


blocksHelp : Context -> List String -> List Block -> Bool -> Bool -> Parsed
blocksHelp context lines acc pending separated =
    case lines of
        [] ->
            { blocks = List.reverse acc, separated = separated }

        line :: rest ->
            if isBlank line then
                blocksHelp context rest acc (pending || not (List.isEmpty acc)) separated

            else
                case readBlock context line rest of
                    Skipped remaining ->
                        blocksHelp context remaining acc pending separated

                    Read block remaining ->
                        blocksHelp context remaining (block :: acc) False (separated || pending)


type Read
    = Read Block (List String)
    | Skipped (List String)


{-| The block that starts at a line, and the lines that follow it. (A loop that
calls itself runs in constant space in Elm; a loop that calls a function that calls
it does not, which is why this is a function of its own.)
-}
readBlock : Context -> String -> List String -> Read
readBlock context line rest =
    let
        containers =
            context.depth < maxDepth
    in
    if indentOf line >= 4 then
        let
            ( code, remaining ) =
                indentedCode (line :: rest)
        in
        Read (CodeBlock { language = "", code = code }) remaining

    else
        case fenceOpen line of
            Just fence ->
                let
                    ( code, remaining ) =
                        fencedCode fence rest
                in
                Read (CodeBlock { language = languageOf fence.info, code = code }) remaining

            Nothing ->
                case atxHeading line of
                    Just ( level, text ) ->
                        if text == "" then
                            Skipped rest

                        else
                            Read
                                (HeadingBlock
                                    { level = level
                                    , id = ""
                                    , content = Inline.parse (context.final && List.isEmpty rest) text
                                    }
                                )
                                rest

                    Nothing ->
                        if isThematicBreak line then
                            Read Rule rest

                        else
                            case ( containers, quoteContent line ) of
                                ( True, Just content ) ->
                                    let
                                        ( inner, remaining ) =
                                            quoteLines content rest
                                    in
                                    Read
                                        (Quote
                                            (parseBlocks
                                                { depth = context.depth + 1, final = context.final && List.isEmpty remaining }
                                                inner
                                            ).blocks
                                        )
                                        remaining

                                _ ->
                                    case ( containers, listMarker line ) of
                                        ( True, Just marker ) ->
                                            let
                                                ( block, remaining ) =
                                                    listBlock context marker (line :: rest)
                                            in
                                            Read block remaining

                                        _ ->
                                            case tableAt line rest of
                                                Just aligns ->
                                                    let
                                                        ( block, remaining ) =
                                                            tableBlock context aligns line (List.drop 1 rest)
                                                    in
                                                    Read block remaining

                                                Nothing ->
                                                    let
                                                        ( text, remaining ) =
                                                            paragraphText containers line rest
                                                    in
                                                    Read (Paragraph (Inline.parse (context.final && List.isEmpty remaining) text)) remaining


{-| An indented code block: the lines, and what follows (including the blank lines
that end the block).
-}
indentedCode : List String -> ( String, List String )
indentedCode lines =
    let
        ( taken, remaining ) =
            spanIndented lines []

        ( blanks, content ) =
            splitTrailingBlank taken []
    in
    ( content |> List.reverse |> List.map (stripColumns 4) |> String.join "\n"
    , blanks ++ remaining
    )


spanIndented : List String -> List String -> ( List String, List String )
spanIndented lines acc =
    case lines of
        line :: rest ->
            if isBlank line || indentOf line >= 4 then
                spanIndented rest (line :: acc)

            else
                ( acc, lines )

        [] ->
            ( acc, [] )


{-| `taken` is reversed. Gives the blank lines at its end and the rest (reversed).
-}
splitTrailingBlank : List String -> List String -> ( List String, List String )
splitTrailingBlank reversed blanks =
    case reversed of
        line :: before ->
            if isBlank line then
                splitTrailingBlank before (line :: blanks)

            else
                ( blanks, reversed )

        [] ->
            ( blanks, [] )


fencedCode : Fence -> List String -> ( String, List String )
fencedCode fence lines =
    fenceHelp fence lines []


fenceHelp : Fence -> List String -> List String -> ( String, List String )
fenceHelp fence lines acc =
    case lines of
        [] ->
            -- an open fence runs to the end; the blank lines at its end are not code
            let
                ( _, content ) =
                    splitTrailingBlank acc []
            in
            ( String.join "\n" (List.reverse content), [] )

        line :: rest ->
            if closesFence fence line then
                ( String.join "\n" (List.reverse acc), rest )

            else
                fenceHelp fence rest (stripColumns fence.indent line :: acc)


{-| The first word of an info string, with only the characters of a language
name.
-}
languageOf : String -> String
languageOf info =
    info
        |> String.words
        |> List.head
        |> Maybe.withDefault ""
        |> String.filter (\c -> isDigit c || isAsciiLetter c || c == '_' || c == '+' || c == '#' || c == '.' || c == '-')
        |> String.left 40


{-| The lines of a quote without their `>`, and what follows. A line without `>`
continues a paragraph of the quote.
-}
quoteLines : String -> List String -> ( List String, List String )
quoteLines first rest =
    quoteHelp rest [ first ] (advance Settled first)


quoteHelp : List String -> List String -> Open -> ( List String, List String )
quoteHelp lines acc open =
    case lines of
        [] ->
            ( List.reverse acc, [] )

        line :: more ->
            case quoteContent line of
                Just content ->
                    quoteHelp more (content :: acc) (advance open content)

                Nothing ->
                    if open == OpenParagraph && not (isBlank line) && not (startsBlock True line) then
                        quoteHelp more (line :: acc) OpenParagraph

                    else
                        ( List.reverse acc, lines )


{-| Lines of a paragraph, joined, and what follows. The paragraph ends at a blank
line, at a block that can interrupt it, and before the header row of a table.
-}
paragraphText : Bool -> String -> List String -> ( String, List String )
paragraphText containers first rest =
    paragraphHelp containers rest [ Tuple.second (leading first) ]


paragraphHelp : Bool -> List String -> List String -> ( String, List String )
paragraphHelp containers lines acc =
    case lines of
        [] ->
            ( String.join "\n" (List.reverse acc), [] )

        line :: more ->
            if interruptsParagraph containers line || tableAt line more /= Nothing then
                ( String.join "\n" (List.reverse acc), lines )

            else
                paragraphHelp containers more (Tuple.second (leading line) :: acc)



-- LISTS


listBlock : Context -> Marker -> List String -> ( Block, List String )
listBlock context first lines =
    let
        ( items, loose, remaining ) =
            itemsHelp context first.kind lines [] False
    in
    ( ListBlock
        { start =
            case first.kind of
                Ordered _ ->
                    Just first.number

                Bullet _ ->
                    Nothing
        , tight = not loose
        , items = items
        }
    , remaining
    )


itemsHelp : Context -> MarkerKind -> List String -> List Item -> Bool -> ( List Item, Bool, List String )
itemsHelp context kind lines acc loose =
    case lines of
        line :: rest ->
            case listMarker line of
                Just marker ->
                    let
                        ( itemLines, afterItem ) =
                            itemContinuation marker rest

                        ( blanks, afterBlanks ) =
                            spanBlank afterItem 0

                        hasSibling =
                            case afterBlanks of
                                next :: _ ->
                                    isSibling kind next

                                [] ->
                                    False

                        inner =
                            marker.content :: itemLines

                        parsed =
                            parseItem
                                { depth = context.depth + 1
                                , final = context.final && not hasSibling && List.isEmpty afterItem
                                }
                                inner
                    in
                    if hasSibling then
                        itemsHelp context kind afterBlanks (parsed.item :: acc) (loose || parsed.separated || blanks > 0)

                    else
                        ( List.reverse (parsed.item :: acc), loose || parsed.separated, afterItem )

                Nothing ->
                    ( List.reverse acc, loose, lines )

        [] ->
            ( List.reverse acc, loose, [] )


spanBlank : List String -> Int -> ( Int, List String )
spanBlank lines count =
    case lines of
        line :: rest ->
            if isBlank line then
                spanBlank rest (count + 1)

            else
                ( count, lines )

        [] ->
            ( count, [] )


{-| Is this line the start of another item of the same list?
-}
isSibling : MarkerKind -> String -> Bool
isSibling kind line =
    if isThematicBreak line then
        False

    else
        case listMarker line of
            Just marker ->
                sameKind kind marker.kind

            Nothing ->
                False


{-| The lines that belong to an item, without the indentation of its content, and
what follows the item. Blank lines belong to it only when a line that is
indented enough comes after them.
-}
itemContinuation : Marker -> List String -> ( List String, List String )
itemContinuation marker lines =
    continuationHelp marker.width (advance Settled marker.content) (marker.content == "") lines [] []


continuationHelp : Int -> Open -> Bool -> List String -> List String -> List String -> ( List String, List String )
continuationHelp width open emptyStart lines acc blanks =
    case lines of
        [] ->
            ( List.reverse acc, List.reverse blanks )

        line :: more ->
            if isBlank line then
                if emptyStart && List.isEmpty acc then
                    -- an item can start with one blank line, not two
                    ( [], lines )

                else
                    continuationHelp width Settled emptyStart more acc (line :: blanks)

            else if indentOf line >= width then
                let
                    stripped =
                        stripColumns width line
                in
                continuationHelp width (advance open stripped) False more (stripped :: (List.map (always "") blanks ++ acc)) []

            else if List.isEmpty blanks && open == OpenParagraph && not (startsBlock True line) then
                continuationHelp width OpenParagraph False more (line :: acc) []

            else
                ( List.reverse acc, List.reverse blanks ++ lines )


parseItem : Context -> List String -> { item : Item, separated : Bool }
parseItem context lines =
    case lines of
        first :: rest ->
            case taskPrefix first of
                Just ( checked, text ) ->
                    let
                        parsed =
                            parseBlocks context (text :: rest)
                    in
                    { item = { task = Just checked, blocks = parsed.blocks }, separated = parsed.separated }

                Nothing ->
                    let
                        parsed =
                            parseBlocks context lines
                    in
                    { item = { task = Nothing, blocks = parsed.blocks }, separated = parsed.separated }

        [] ->
            { item = { task = Nothing, blocks = [] }, separated = False }


{-| `[ ] text` and `[x] text` at the start of an item.
-}
taskPrefix : String -> Maybe ( Bool, String )
taskPrefix text =
    let
        box =
            String.left 3 text

        after =
            String.dropLeft 3 text
    in
    if (box == "[ ]" || box == "[x]" || box == "[X]") && (String.startsWith " " after || String.startsWith "\t" after) && not (isBlank after) then
        Just ( box /= "[ ]", Tuple.second (leading after) )

    else
        Nothing



-- TABLES


{-| The alignments of a table that starts at this line, when the next line is its
delimiter row.
-}
tableAt : String -> List String -> Maybe (List Align)
tableAt header following =
    case following of
        delimiter :: _ ->
            if hasPipe header && hasPipe delimiter && indentOf header < 4 then
                case delimiterRow delimiter of
                    Just aligns ->
                        if List.length aligns == List.length (splitCells header) then
                            Just aligns

                        else
                            Nothing

                    Nothing ->
                        Nothing

            else
                Nothing

        [] ->
            Nothing


delimiterRow : String -> Maybe (List Align)
delimiterRow line =
    if indentOf line >= 4 then
        Nothing

    else
        splitCells line
            |> List.foldr
                (\cell result ->
                    case ( result, delimiterCell cell ) of
                        ( Just aligns, Just align ) ->
                            Just (align :: aligns)

                        _ ->
                            Nothing
                )
                (Just [])


delimiterCell : String -> Maybe Align
delimiterCell cell =
    let
        left =
            String.startsWith ":" cell

        right =
            String.endsWith ":" cell

        dashes =
            cell
                |> (if left then
                        String.dropLeft 1

                    else
                        identity
                   )
                |> (if right then
                        String.dropRight 1

                    else
                        identity
                   )
    in
    if dashes /= "" && String.all (\c -> c == '-') dashes then
        Just
            (if left && right then
                AlignCenter

             else if left then
                AlignLeft

             else if right then
                AlignRight

             else
                AlignNone
            )

    else
        Nothing


{-| Is there a `|` that is not escaped?
-}
hasPipe : String -> Bool
hasPipe line =
    pipeHelp (String.toList line)


pipeHelp : List Char -> Bool
pipeHelp chars =
    case chars of
        '\\' :: _ :: rest ->
            pipeHelp rest

        '|' :: _ ->
            True

        _ :: rest ->
            pipeHelp rest

        [] ->
            False


{-| The cells of a row, trimmed. A leading and a trailing pipe are not cells; `\|`
is a pipe inside a cell.
-}
splitCells : String -> List String
splitCells line =
    let
        trimmed =
            String.trim line

        withoutLeading =
            if String.startsWith "|" trimmed then
                String.dropLeft 1 trimmed

            else
                trimmed

        body =
            if endsWithPipe withoutLeading then
                String.dropRight 1 withoutLeading

            else
                withoutLeading
    in
    cellsHelp (String.toList body) [] []


endsWithPipe : String -> Bool
endsWithPipe text =
    String.endsWith "|" text && modBy 2 (suffixCount '\\' (String.dropRight 1 text)) == 0


cellsHelp : List Char -> List Char -> List String -> List String
cellsHelp chars cell cells =
    case chars of
        [] ->
            List.reverse (cellText cell :: cells)

        '\\' :: '|' :: rest ->
            cellsHelp rest ('|' :: cell) cells

        '\\' :: next :: rest ->
            cellsHelp rest (next :: '\\' :: cell) cells

        '|' :: rest ->
            cellsHelp rest [] (cellText cell :: cells)

        c :: rest ->
            cellsHelp rest (c :: cell) cells


cellText : List Char -> String
cellText reversed =
    String.trim (String.fromList (List.reverse reversed))


tableBlock : Context -> List Align -> String -> List String -> ( Block, List String )
tableBlock context aligns header lines =
    let
        columns =
            List.length aligns

        ( rowLines, remaining ) =
            spanRows (context.depth < maxDepth) lines []

        final =
            context.final && List.isEmpty remaining

        lastIndex =
            List.length rowLines - 1

        rows =
            List.indexedMap
                (\index line ->
                    rowCells (final && index == lastIndex) columns line
                )
                rowLines
    in
    ( Table
        { aligns = aligns
        , header = rowCells False columns header
        , rows = rows
        }
    , remaining
    )


{-| The lines after the delimiter row that are rows: they have a pipe and do not
start another block.
-}
spanRows : Bool -> List String -> List String -> ( List String, List String )
spanRows containers lines acc =
    case lines of
        line :: rest ->
            if not (isBlank line) && hasPipe line && not (interruptsParagraph containers line) then
                spanRows containers rest (line :: acc)

            else
                ( List.reverse acc, lines )

        [] ->
            ( List.reverse acc, [] )


{-| The cells of a row as inline content: a row with too few cells is padded with
empty ones, extra cells are dropped. When the row is the last line of the text and
has no closing pipe, its last cell is still being written.
-}
rowCells : Bool -> Int -> String -> List (List Inline)
rowCells unfinished columns line =
    let
        cells =
            splitCells line

        present =
            List.length cells

        open =
            unfinished && not (endsWithPipe (String.trim line))
    in
    cells
        |> List.indexedMap (\index cell -> Inline.parse (open && index == present - 1) cell)
        |> List.take columns
        |> (\parsed -> parsed ++ List.repeat (columns - List.length parsed) [])



-- HEADINGS


type alias Numbering =
    { used : Set String
    , next : Dict String Int
    , previous : Maybe Int
    }


{-| Gives every heading its level (the first one as written, every later one at
most one deeper than the one before it, so the outline has no gaps) and an id
that is unique in the document: `intro`, `intro-1`, `intro-2`.
-}
numberHeadings : List Block -> List Block
numberHeadings blocks =
    numberBlocks blocks { used = Set.empty, next = Dict.empty, previous = Nothing }
        |> Tuple.first


numberBlocks : List Block -> Numbering -> ( List Block, Numbering )
numberBlocks blocks numbering =
    let
        ( reversed, final ) =
            List.foldl
                (\block ( acc, state ) ->
                    let
                        ( numbered, next ) =
                            numberBlock block state
                    in
                    ( numbered :: acc, next )
                )
                ( [], numbering )
                blocks
    in
    ( List.reverse reversed, final )


numberBlock : Block -> Numbering -> ( Block, Numbering )
numberBlock block numbering =
    case block of
        HeadingBlock heading ->
            let
                level =
                    case numbering.previous of
                        Just previous ->
                            min heading.level (previous + 1)

                        Nothing ->
                            heading.level

                ( id, next ) =
                    uniqueId (slug (Inline.plainText heading.content)) numbering
            in
            ( HeadingBlock { heading | level = level, id = id }, { next | previous = Just level } )

        Quote inner ->
            let
                ( numbered, next ) =
                    numberBlocks inner numbering
            in
            ( Quote numbered, next )

        ListBlock list ->
            let
                ( reversed, next ) =
                    List.foldl
                        (\item ( acc, state ) ->
                            let
                                ( numbered, after ) =
                                    numberBlocks item.blocks state
                            in
                            ( { item | blocks = numbered } :: acc, after )
                        )
                        ( [], numbering )
                        list.items
            in
            ( ListBlock { list | items = List.reverse reversed }, next )

        _ ->
            ( block, numbering )


uniqueId : String -> Numbering -> ( String, Numbering )
uniqueId base numbering =
    if Set.member base numbering.used then
        let
            start =
                Dict.get base numbering.next |> Maybe.withDefault 1

            ( candidate, following ) =
                freeId base start numbering.used
        in
        ( candidate
        , { numbering | used = Set.insert candidate numbering.used, next = Dict.insert base following numbering.next }
        )

    else
        ( base, { numbering | used = Set.insert base numbering.used } )


freeId : String -> Int -> Set String -> ( String, Int )
freeId base n used =
    let
        candidate =
            base ++ "-" ++ String.fromInt n
    in
    if Set.member candidate used then
        freeId base (n + 1) used

    else
        ( candidate, n + 1 )


{-| A heading's anchor: lower case, letters and digits, other runs of characters
become one `-`. A heading without any gives `section`.
-}
slug : String -> String
slug text =
    let
        cleaned =
            text
                |> String.toLower
                |> String.map
                    (\c ->
                        if isAnchorChar c then
                            c

                        else
                            '-'
                    )
                |> String.split "-"
                |> List.filter (\part -> part /= "")
                |> String.join "-"
                |> String.left 80
                |> String.split "-"
                |> List.filter (\part -> part /= "")
                |> String.join "-"
    in
    if cleaned == "" then
        "section"

    else
        cleaned


isAnchorChar : Char -> Bool
isAnchorChar c =
    let
        code =
            Char.toCode c
    in
    if code < 0x80 then
        isDigit c || (c >= 'a' && c <= 'z') || c == '_'

    else
        code
            >= 0xC0
            && code
            /= 0xD7
            && code
            /= 0xF7
            && not (code >= 0x2000 && code <= 0x2BFF)
            && not (code >= 0x3000 && code <= 0x303F)
            && not (code >= 0xD800 && code <= 0xDFFF)
            && not (code >= 0xFE00 && code <= 0xFE0F)
            && not (code >= 0xFF00 && code <= 0xFF0F)



-- PLAIN TEXT


{-| The text of a document without markup, one line for each paragraph, heading,
list item, row of a table or line of code.
-}
plainText : Document -> String
plainText document =
    document.blocks
        |> List.concatMap blockLines
        |> String.join "\n"


blockLines : Block -> List String
blockLines block =
    case block of
        Paragraph inlines ->
            [ Inline.plainText inlines ]

        HeadingBlock heading ->
            [ Inline.plainText heading.content ]

        Quote blocks ->
            List.concatMap blockLines blocks

        CodeBlock code ->
            String.lines code.code

        ListBlock list ->
            List.concatMap (\item -> List.concatMap blockLines item.blocks) list.items

        Rule ->
            []

        Table table ->
            (table.header :: table.rows)
                |> List.map (\row -> String.join " | " (List.map Inline.plainText row))


isDigit : Char -> Bool
isDigit c =
    c >= '0' && c <= '9'


isAsciiLetter : Char -> Bool
isAsciiLetter c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
