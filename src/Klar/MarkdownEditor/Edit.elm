module Klar.MarkdownEditor.Edit exposing
    ( Action(..)
    , Edit
    , Placeholders
    , Selection
    , apply
    , clampSelection
    , lineCount
    )

{-| The changes the buttons of the Markdown editor make to a text, as functions on
the text and the selection.

Positions count UTF-16 code units, like the `selectionStart` and `selectionEnd` of
a text area and like `String.length` and `String.slice` in Elm. A selection that
would end between the two halves of a character made of two (an emoji) is widened to
cover both. Text is never lost: an action adds or removes only the marks it is about
(`**`, `*`, `` ` ``, `[`...`](`...`)`, `#`, `>`, a list marker), and nothing else in
the text is touched.

Every action is a toggle where that makes sense: apply it twice and the text is as
it was (for a heading, four times: it goes through the levels 2, 3 and 4 and then
has none).

-}

import Dict exposing (Dict)
import Klar.Markdown.Utf16 as Utf16


{-| The part of the text that is selected: where it starts and where it ends, in code
units. `start` is not after `end`; they are equal when only a caret is shown.
-}
type alias Selection =
    { start : Int
    , end : Int
    }


{-| A text and its selection.
-}
type alias Edit =
    { text : String
    , selection : Selection
    }


type Action
    = Bold
    | Italic
    | Code
    | Link
    | Heading
    | Quote
    | BulletList
    | NumberedList
    | TaskList


{-| Text that an action puts in the text when there is none to use: the words of a
new link.
-}
type alias Placeholders =
    { linkText : String
    }


{-| Makes the change for a button or a shortcut.
-}
apply : Placeholders -> Action -> Edit -> Edit
apply placeholders action edit0 =
    let
        edit =
            { edit0 | selection = clampSelection edit0.text edit0.selection }
    in
    case action of
        Bold ->
            inline strongMarker edit

        Italic ->
            inline emphasisMarker edit

        Code ->
            inline codeMarker edit

        Link ->
            link placeholders edit

        Heading ->
            applyLines headingPlan edit

        Quote ->
            applyLines quotePlan edit

        BulletList ->
            applyLines (listPlan BulletKind) edit

        NumberedList ->
            applyLines (listPlan OrderedKind) edit

        TaskList ->
            applyLines (listPlan TaskKind) edit


{-| The selection with both ends inside the text, in order, and not between the two
halves of a character that takes two code units.
-}
clampSelection : String -> Selection -> Selection
clampSelection text selection =
    let
        length =
            String.length text

        a =
            clamp 0 length selection.start

        b =
            clamp 0 length selection.end

        ( low, high ) =
            if a <= b then
                ( a, b )

            else
                ( b, a )
    in
    if low == high then
        -- a caret between the halves of a character goes in front of it
        if insidePair text low then
            { start = low - 1, end = low - 1 }

        else
            { start = low, end = low }

    else
        { start =
            if insidePair text low then
                low - 1

            else
                low
        , end =
            if insidePair text high then
                high + 1

            else
                high
        }


{-| Is this position between the two halves of one character? The two code units
around it then read as one character.
-}
insidePair : String -> Int -> Bool
insidePair text position =
    position
        > 0
        && position
        < String.length text
        && Utf16.isHighSurrogate (String.slice (position - 1) position text)
        && Utf16.isLowSurrogate (String.slice position (position + 1) text)


{-| The number of lines of a text: one more than its line breaks.
-}
lineCount : String -> Int
lineCount text =
    List.length (String.indexes "\n" text) + 1



-- INLINE MARKS: BOLD, ITALIC, CODE


type alias Marker =
    { {- is the text a run of this mark with something inside? -} wrappedBy : String -> Bool

    -- the text without one layer of the mark
    , unwrap : String -> String

    -- what to write before and after the text to mark it
    , surround : String -> ( String, String )

    -- is the text around a caret an empty pair of this mark?
    , emptyAround : String -> String -> Maybe Int

    -- is the text around a selection the mark of the selection (so the selection is inside it)?
    , outside : String -> String -> Maybe Int

    -- the marks that go in an empty place
    , empty : String
    }


strongMarker : Marker
strongMarker =
    starMarker 2


emphasisMarker : Marker
emphasisMarker =
    starMarker 1


{-| Marks made of stars. A run of stars at each end of the text is a mark: `**` is
bold, `*` is italic, `***` is both, and `****` is bold twice. Taking the mark off
removes one layer of it. That a run of 3 is both makes `Bold` on `***a***` leave
`*a*` and `Italic` leave `**a**`.
-}
starMarker : Int -> Marker
starMarker width =
    let
        isOn run =
            if width == 2 then
                run >= 2

            else
                modBy 2 run == 1

        mark =
            String.repeat width "*"
    in
    { wrappedBy =
        \core ->
            let
                run =
                    min (leadingRun '*' core) (trailingRun '*' core)
            in
            run < String.length core && isOn run
    , unwrap = \core -> String.slice width (String.length core - width) core
    , surround = \_ -> ( mark, mark )
    , emptyAround =
        \before after ->
            let
                run =
                    min (trailingRun '*' before) (leadingRun '*' after)
            in
            if isOn run then
                Just width

            else
                Nothing
    , outside =
        \before after ->
            let
                run =
                    min (trailingRun '*' before) (leadingRun '*' after)
            in
            if isOn run then
                Just width

            else
                Nothing
    , empty = mark ++ mark
    }


codeMarker : Marker
codeMarker =
    { wrappedBy =
        \core ->
            let
                run =
                    leadingRun '`' core
            in
            run >= 1 && run == trailingRun '`' core && run < String.length core
    , unwrap =
        \core ->
            let
                run =
                    leadingRun '`' core

                inner =
                    String.slice run (String.length core - run) core
            in
            -- the space that keeps a backtick at the end of the text apart from the mark
            if String.startsWith " " inner && String.endsWith " " inner && String.trim inner /= "" then
                String.slice 1 -1 inner

            else
                inner
    , surround =
        \core ->
            let
                fence =
                    String.repeat (longestRun '`' core + 1) "`"

                pad =
                    if String.startsWith "`" core || String.endsWith "`" core then
                        " "

                    else
                        ""
            in
            ( fence ++ pad, pad ++ fence )
    , emptyAround =
        \before after ->
            let
                run =
                    trailingRun '`' before
            in
            if run >= 1 && run == leadingRun '`' after then
                Just run

            else
                Nothing
    , outside =
        \before after ->
            let
                run =
                    trailingRun '`' before
            in
            if run >= 1 && run == leadingRun '`' after then
                Just run

            else
                Nothing
    , empty = "``"
    }


{-| The runs below look at single code units with `String.slice`, never at
characters: `String.toList` and `String.foldl` fail on text with half of an emoji.
-}
leadingRun : Char -> String -> Int
leadingRun char text =
    runFrom (String.fromChar char) text 0 1 0


trailingRun : Char -> String -> Int
trailingRun char text =
    runFrom (String.fromChar char) text (String.length text - 1) -1 0


runFrom : String -> String -> Int -> Int -> Int -> Int
runFrom unit text index step count =
    if index >= 0 && index < String.length text && String.slice index (index + 1) text == unit then
        runFrom unit text (index + step) step (count + 1)

    else
        count


longestRun : Char -> String -> Int
longestRun char text =
    longestFrom (String.fromChar char) text 0 0 0


longestFrom : String -> String -> Int -> Int -> Int -> Int
longestFrom unit text index current longest =
    if index >= String.length text then
        longest

    else if String.slice index (index + 1) text == unit then
        longestFrom unit text (index + 1) (current + 1) (max longest (current + 1))

    else
        longestFrom unit text (index + 1) 0 longest


inline : Marker -> Edit -> Edit
inline marker edit =
    let
        { start, end } =
            edit.selection
    in
    if start == end then
        caret marker edit

    else
        let
            selected =
                String.slice start end edit.text
        in
        if String.contains "\n" selected then
            manyLines marker edit

        else
            oneLine marker edit


{-| A caret and no selection: the mark goes in as an empty pair with the caret
inside, or an empty pair around the caret is taken out.
-}
caret : Marker -> Edit -> Edit
caret marker edit =
    let
        position =
            edit.selection.start

        before =
            String.left position edit.text

        after =
            String.dropLeft position edit.text
    in
    case marker.emptyAround before after of
        Just width ->
            { text = String.dropRight width before ++ String.dropLeft width after
            , selection = { start = position - width, end = position - width }
            }

        Nothing ->
            let
                half =
                    String.length marker.empty // 2
            in
            { text = before ++ marker.empty ++ after
            , selection = { start = position + half, end = position + half }
            }


{-| The text of a selection that has white space at its ends: the white space stays
outside the mark.
-}
trimmed : String -> ( String, String, String )
trimmed selected =
    let
        core =
            String.trim selected

        lead =
            String.length selected - String.length (String.trimLeft selected)
    in
    ( String.left lead selected, core, String.dropLeft (lead + String.length core) selected )


oneLine : Marker -> Edit -> Edit
oneLine marker edit =
    let
        { start, end } =
            edit.selection

        selected =
            String.slice start end edit.text

        ( lead, core, tail ) =
            trimmed selected

        before =
            String.left start edit.text

        after =
            String.dropLeft end edit.text
    in
    if core == "" then
        edit

    else if marker.wrappedBy core then
        -- the marks are in the selection: take them out, keep the text selected
        let
            bare =
                marker.unwrap core
        in
        { text = before ++ lead ++ bare ++ tail ++ after
        , selection = { start = start + String.length lead, end = start + String.length lead + String.length bare }
        }

    else
        case marker.outside (before ++ lead) (tail ++ after) of
            Just width ->
                -- the marks are around the selection: take them out
                { text = String.dropRight width (before ++ lead) ++ core ++ String.dropLeft width (tail ++ after)
                , selection = { start = start + String.length lead - width, end = start + String.length lead - width + String.length core }
                }

            Nothing ->
                let
                    ( open, close ) =
                        marker.surround core
                in
                { text = before ++ lead ++ open ++ core ++ close ++ tail ++ after
                , selection =
                    { start = start + String.length lead + String.length open
                    , end = start + String.length lead + String.length open + String.length core
                    }
                }


{-| A selection over several lines: each line is marked on its own (a mark cannot
cross a blank line), and the lines that are blank are left alone. When every line
is marked already, the marks come off.
-}
manyLines : Marker -> Edit -> Edit
manyLines marker edit =
    let
        { start, end } =
            edit.selection

        selected =
            String.slice start end edit.text

        pieces =
            List.map trimmed (String.split "\n" selected)

        cores =
            List.filter (\( _, core, _ ) -> core /= "") pieces

        allMarked =
            not (List.isEmpty cores) && List.all (\( _, core, _ ) -> marker.wrappedBy core) cores

        change ( lead, core, tail ) =
            if core == "" then
                lead ++ tail

            else if allMarked then
                lead ++ marker.unwrap core ++ tail

            else if marker.wrappedBy core then
                lead ++ core ++ tail

            else
                let
                    ( open, close ) =
                        marker.surround core
                in
                lead ++ open ++ core ++ close ++ tail

        changed =
            String.join "\n" (List.map change pieces)

        first =
            String.length changed - String.length (String.trimLeft changed)

        last =
            String.length (String.trimRight changed)
    in
    if List.isEmpty cores then
        edit

    else
        { text = String.left start edit.text ++ changed ++ String.dropLeft end edit.text
        , selection = { start = start + first, end = start + last }
        }



-- LINKS


link : Placeholders -> Edit -> Edit
link placeholders edit =
    let
        { start, end } =
            edit.selection

        selected =
            String.slice start end edit.text

        before =
            String.left start edit.text

        after =
            String.dropLeft end edit.text

        address =
            "https://"
    in
    if start == end then
        let
            written =
                "[" ++ placeholders.linkText ++ "](" ++ address ++ ")"
        in
        { text = before ++ written ++ after
        , selection = { start = start + 1, end = start + 1 + String.length placeholders.linkText }
        }

    else
        case asLink selected of
            Just words ->
                -- a link that is selected becomes its words
                { text = before ++ words ++ after
                , selection = { start = start, end = start + String.length words }
                }

            Nothing ->
                if looksLikeAddress selected then
                    -- an address that is selected becomes the address of a link
                    { text = before ++ "[" ++ placeholders.linkText ++ "](" ++ selected ++ ")" ++ after
                    , selection = { start = start + 1, end = start + 1 + String.length placeholders.linkText }
                    }

                else
                    { text = before ++ "[" ++ selected ++ "](" ++ address ++ ")" ++ after
                    , selection =
                        { start = start + String.length selected + 3
                        , end = start + String.length selected + 3 + String.length address
                        }
                    }


{-| The words of `[words](address)`, when the text is exactly that.
-}
asLink : String -> Maybe String
asLink text =
    if String.startsWith "[" text && String.endsWith ")" text then
        case List.reverse (String.indexes "](" text) of
            position :: _ ->
                let
                    address =
                        String.slice (position + 2) -1 text
                in
                if not (String.contains "\n" address) && not (String.contains ")" address) then
                    Just (String.slice 1 position text)

                else
                    Nothing

            [] ->
                Nothing

    else
        Nothing


looksLikeAddress : String -> Bool
looksLikeAddress text =
    (String.startsWith "http://" text || String.startsWith "https://" text || String.startsWith "mailto:" text)
        && not (String.contains " " text || String.contains "\n" text || String.contains "\t" text)



-- LINES: HEADING, QUOTE, LISTS


type alias Line =
    { start : Int
    , text : String
    }


{-| A change at the start of a line: at that column, take `removed` characters out
and put `inserted` in.
-}
type alias LineEdit =
    { at : Int
    , removed : Int
    , inserted : String
    }


splitLines : String -> List Line
splitLines text =
    String.split "\n" text
        |> List.foldl
            (\line ( position, acc ) ->
                ( position + String.length line + 1, { start = position, text = line } :: acc )
            )
            ( 0, [] )
        |> Tuple.second
        |> List.reverse


isBlankLine : Line -> Bool
isBlankLine line =
    String.trim line.text == ""


lineIndexAt : List Line -> Int -> Int
lineIndexAt lines position =
    List.foldl
        (\line ( index, found ) ->
            if line.start <= position then
                ( index + 1, index )

            else
                ( index + 1, found )
        )
        ( 0, 0 )
        lines
        |> Tuple.second


{-| Changes the lines the selection touches. The plan says, for those lines, what to
change in each. The selection moves with the text it was on.
-}
applyLines : (List Line -> List (Maybe LineEdit)) -> Edit -> Edit
applyLines plan edit =
    let
        lines =
            splitLines edit.text

        { start, end } =
            edit.selection

        first =
            lineIndexAt lines start

        lastPosition =
            if end > start && String.slice (end - 1) end edit.text == "\n" then
                end - 1

            else
                end

        last =
            lineIndexAt lines lastPosition

        touched =
            lines |> List.drop first |> List.take (last - first + 1)

        edits : Dict Int LineEdit
        edits =
            List.map2 Tuple.pair (List.range first last) (plan touched)
                |> List.filterMap (\( index, maybe ) -> Maybe.map (Tuple.pair index) maybe)
                |> Dict.fromList

        newLine index line =
            case Dict.get index edits of
                Just change ->
                    String.left change.at line.text ++ change.inserted ++ String.dropLeft (change.at + change.removed) line.text

                Nothing ->
                    line.text

        collapsed =
            start == end

        move isStart position =
            let
                index =
                    lineIndexAt lines position

                before =
                    List.foldl
                        (\( i, change ) total ->
                            if i < index then
                                total + String.length change.inserted - change.removed

                            else
                                total
                        )
                        0
                        (Dict.toList edits)

                inLine =
                    case ( Dict.get index edits, List.head (List.drop index lines) ) of
                        ( Just change, Just line ) ->
                            let
                                column =
                                    position - line.start
                            in
                            if column < change.at then
                                0

                            else if column == change.at && change.removed == 0 && (isStart || collapsed) then
                                -- text is put in at this place: the position stays on the text it was on
                                String.length change.inserted

                            else if column <= change.at then
                                0

                            else if column >= change.at + change.removed then
                                String.length change.inserted - change.removed

                            else
                                -- inside what was taken out: after what was put in
                                change.at + String.length change.inserted - column

                        _ ->
                            0
            in
            position + before + inLine
    in
    if Dict.isEmpty edits then
        edit

    else
        { text = String.join "\n" (List.indexedMap newLine lines)
        , selection = { start = move True start, end = move False end }
        }


{-| The lines a list or heading action is about: those with text; when all of them
are blank, all of them.
-}
targets : List Line -> List Line
targets lines =
    case List.filter (\line -> not (isBlankLine line)) lines of
        [] ->
            lines

        some ->
            some


isTarget : List Line -> Line -> Bool
isTarget lines line =
    if List.all isBlankLine lines then
        True

    else
        not (isBlankLine line)


indentOf : String -> Int
indentOf text =
    String.length text - String.length (String.trimLeft text)


{-| A heading goes from none to level 2, 3 and 4, and then to none; level 1 goes to

1.  The first line decides, and all lines get the same level.

-}
headingPlan : List Line -> List (Maybe LineEdit)
headingPlan lines =
    let
        current =
            case targets lines of
                line :: _ ->
                    headingLevel line.text

                [] ->
                    0

        next =
            if current == 0 then
                2

            else if current <= 3 then
                current + 1

            else
                0
    in
    List.map
        (\line ->
            if isTarget lines line then
                let
                    indent =
                        indentOf line.text

                    level =
                        headingLevel line.text

                    rest =
                        String.dropLeft (indent + level) line.text

                    removed =
                        if level == 0 then
                            0

                        else if String.startsWith " " rest then
                            level + 1

                        else
                            level
                in
                Just
                    { at = indent
                    , removed = removed
                    , inserted =
                        if next == 0 then
                            ""

                        else
                            String.repeat next "#" ++ " "
                    }

            else
                Nothing
        )
        lines


{-| The level of a heading written with `#`, or 0.
-}
headingLevel : String -> Int
headingLevel text =
    let
        indent =
            indentOf text

        rest =
            String.dropLeft indent text

        hashes =
            leadingRun '#' rest

        after =
            String.dropLeft hashes rest
    in
    if hashes >= 1 && hashes <= 6 && (after == "" || String.startsWith " " after || String.startsWith "\t" after) then
        hashes

    else
        0


isQuoted : String -> Bool
isQuoted text =
    String.startsWith ">" (String.trimLeft text)


{-| `>` in front of every line that has text, `>` in front of the empty lines
between them. When every line is a quote already, the marks come off.
-}
quotePlan : List Line -> List (Maybe LineEdit)
quotePlan lines =
    let
        withText =
            List.filter (\line -> not (isBlankLine line)) lines

        allQuoted =
            not (List.isEmpty withText) && List.all (\line -> isQuoted line.text) withText
    in
    if List.isEmpty withText then
        -- only blank lines: a caret on an empty line, which becomes a line of a quote
        List.map (\_ -> Just { at = 0, removed = 0, inserted = "> " }) lines

    else
        List.map (quoteChange allQuoted) lines


quoteChange : Bool -> Line -> Maybe LineEdit
quoteChange allQuoted line =
    if allQuoted then
        if isQuoted line.text then
            let
                indent =
                    indentOf line.text
            in
            Just
                { at = indent
                , removed =
                    if String.startsWith " " (String.dropLeft (indent + 1) line.text) then
                        2

                    else
                        1
                , inserted = ""
                }

        else
            Nothing

    else if line.text == "" then
        Just { at = 0, removed = 0, inserted = ">" }

    else if isBlankLine line || isQuoted line.text then
        Nothing

    else
        Just { at = 0, removed = 0, inserted = "> " }


type ListKind
    = BulletKind
    | OrderedKind
    | TaskKind


{-| The list marker at the start of a line: where it starts, how long it is
(with the space after it), and what kind it is.
-}
listMarker : String -> Maybe { indent : Int, length : Int, kind : ListKind }
listMarker text =
    let
        indent =
            indentOf text

        rest =
            String.dropLeft indent text

        startsAfter n =
            let
                after =
                    String.dropLeft n rest
            in
            after == "" || String.startsWith " " after || String.startsWith "\t" after

        withSpace n =
            if String.dropLeft n rest == "" then
                n

            else
                n + 1

        digits =
            leadingDigits rest
    in
    case String.uncons rest of
        Just ( c, _ ) ->
            if (c == '-' || c == '*' || c == '+') && startsAfter 1 then
                let
                    afterMarker =
                        String.dropLeft (withSpace 1) rest

                    box =
                        String.left 3 afterMarker

                    isTask =
                        (box == "[ ]" || box == "[x]" || box == "[X]") && (String.dropLeft 3 afterMarker == "" || String.startsWith " " (String.dropLeft 3 afterMarker))
                in
                if isTask then
                    Just { indent = indent, length = withSpace 1 + boxLength afterMarker, kind = TaskKind }

                else
                    Just { indent = indent, length = withSpace 1, kind = BulletKind }

            else if digits >= 1 && digits <= 9 && (String.slice digits (digits + 1) rest == "." || String.slice digits (digits + 1) rest == ")") && startsAfter (digits + 1) then
                Just { indent = indent, length = withSpace (digits + 1), kind = OrderedKind }

            else
                Nothing

        Nothing ->
            Nothing


{-| `[ ]` and the space after it, when it is there.
-}
boxLength : String -> Int
boxLength afterMarker =
    if String.dropLeft 3 afterMarker == "" then
        3

    else
        4


leadingDigits : String -> Int
leadingDigits text =
    digitsFrom text 0


digitsFrom : String -> Int -> Int
digitsFrom text index =
    case String.toInt (String.slice index (index + 1) text) of
        Just _ ->
            digitsFrom text (index + 1)

        Nothing ->
            index


{-| A list marker in front of every line that has text, in place of the one it has;
or, when every line has this kind of marker already, none.
-}
listPlan : ListKind -> List Line -> List (Maybe LineEdit)
listPlan kind lines =
    let
        chosen =
            List.filter (isTarget lines) lines

        markers =
            List.map (\line -> listMarker line.text) chosen

        allOfKind =
            not (List.isEmpty chosen)
                && List.all
                    (\marker ->
                        case marker of
                            Just found ->
                                found.kind == kind

                            Nothing ->
                                False
                    )
                    markers

        markerFor number =
            case kind of
                BulletKind ->
                    "- "

                TaskKind ->
                    "- [ ] "

                OrderedKind ->
                    String.fromInt number ++ ". "
    in
    lines
        |> List.foldl
            (\line ( number, acc ) ->
                if isTarget lines line then
                    let
                        existing =
                            listMarker line.text

                        indent =
                            indentOf line.text

                        removed =
                            case existing of
                                Just found ->
                                    found.length

                                Nothing ->
                                    0
                    in
                    ( number + 1
                    , Just
                        { at = indent
                        , removed = removed
                        , inserted =
                            if allOfKind then
                                ""

                            else
                                markerFor number
                        }
                        :: acc
                    )

                else
                    ( number, Nothing :: acc )
            )
            ( 1, [] )
        |> Tuple.second
        |> List.reverse
