module Klar.Select.Option exposing
    ( Option
    , option, withDescription, withGroup, withIcon, withKeywords, disabledOption
    , Entry, Index, index, rank, filter, score, isExactMatch
    , Word, prepare, labelMatches, normalize
    )

{-| The option model shared by [Klar.Select](Klar-Select),
[Klar.MultiSelect](Klar-MultiSelect) and [Klar.Autocomplete](Klar-Autocomplete),
and the search that matches a query against it.

Most applications do not import this module. `Klar.Select` re-exports `Option`,
`option`, the `with*` helpers and `filter`, and the other two components take
the same `Option` values. Import it when you build options in a module that has
no select of its own (a data module, a simulated backend), or when you want the
same matching for a list of your own.

    import Klar.Select.Option as Option

    suppliers : List (Option.Option String)
    suppliers =
        [ Option.option "acme" "Acme Supplies"
            |> Option.withDescription "Berlin"
            |> Option.withGroup "Preferred"
        , Option.option "globex" "Globex"
            |> Option.withKeywords [ "Globex Corporation" ]
        , Option.option "initech" "Initech"
            |> Option.disabledOption
        ]

    Option.filter "berlin" suppliers |> List.map .label --> [ "Acme Supplies" ]

A query is split into words and every word has to match. Case and diacritics
are ignored. A word scores 0 when the label is that word, 1 when the label
starts with it, 2 when a word of the label starts with it, 3 when it occurs
anywhere in the label, and 6 when its letters appear in order and close
together (only for words of three letters or more), so "splis" finds "Acme
Supplies". The description and the keywords are searched too, and count 3 points
worse than the same match in the label. The scores of the words add up; lower is
better, and equal matches keep their order.


# Options

@docs Option
@docs option, withDescription, withGroup, withIcon, withKeywords, disabledOption


# Matching

Filtering normalizes every label, description and keyword. When the same list
is searched again and again, do that once with `index` and ask the result with
`rank`; the select components keep their index in their state. `filter`, `score`
and `isExactMatch` answer one-off questions.

@docs Entry, Index, index, rank, filter, score, isExactMatch


# Query words

@docs Word, prepare, labelMatches, normalize

-}

import Klar.Icon exposing (Icon)
import Klar.Internal as Internal


{-| One choice in a list. It is plain data: make it with `option` and the
`with*` functions, or write the record yourself.

  - `value` is what the application stores: its own id type (a `CustomerId`, a code, an `Int`).
    Values are compared with `==`, so use data, not functions, and keep it unique within one list
  - `label` is what the user sees and searches
  - `description` is a short secondary text, shown dimmed after the label and searched too
  - `group` lists the option under a heading, together with the options of the same group
  - `disabled` shows the option dimmed and keeps it from being chosen
  - `icon` is drawn before the label
  - `keywords` are extra words that also match but are never shown (synonyms, codes, old names)

-}
type alias Option id =
    { value : id
    , label : String
    , description : Maybe String
    , group : Maybe String
    , disabled : Bool
    , icon : Maybe Icon
    , keywords : List String
    }


{-| An option with a value (what the application stores) and a label (what the
user sees and searches), and nothing else: no description, group or icon, not
disabled, no keywords. Add those with the `with*` functions.

    Option.option "de" "Germany"
        |> Option.withDescription "DE"
        |> Option.withGroup "Europe"

-}
option : id -> String -> Option id
option value label =
    { value = value
    , label = label
    , description = Nothing
    , group = Nothing
    , disabled = False
    , icon = Nothing
    , keywords = []
    }


{-| A short secondary text, shown dimmed after the label and in the tooltip of
the option. It is searched too, but a match in the description ranks below the
same match in the label.
-}
withDescription : String -> Option id -> Option id
withDescription text opt =
    { opt | description = Just text }


{-| Lists the option under a heading with this name. Options with the same
group are shown together, in the order the groups first appear, and options
without a group come first, under no heading. While the user searches, the
group with the best match comes first.
-}
withGroup : String -> Option id -> Option id
withGroup name opt =
    { opt | group = Just name }


{-| An icon drawn before the label of the option in the list. `Klar.Select` also
shows it in the closed field next to the chosen label.
-}
withIcon : Icon -> Option id -> Option id
withIcon icon opt =
    { opt | icon = Just icon }


{-| Extra words that also match the option, for example a synonym, an old name
or a code. They are searched but never shown. Calling it again adds to the
keywords.
-}
withKeywords : List String -> Option id -> Option id
withKeywords words opt =
    { opt | keywords = opt.keywords ++ words }


{-| Shows the option dimmed and keeps it from being chosen: it cannot be clicked,
highlighted or reached with the arrow keys. It is still searched and counted.
-}
disabledOption : Option id -> Option id
disabledOption opt =
    { opt | disabled = True }



-- MATCHING
--
-- Every query word is scored like `Klar.Search.score` does it (0 exact,
-- 1 prefix, 2 word prefix, 3 substring, 6 letters in order for words of 3+
-- letters), against the label and against the description and keywords
-- (those count 3 more); a word takes its better score and the scores of the
-- words are added. So "acme berlin" finds "Acme Supplies" with the description
-- "Berlin", and a word found in the description beats scattered letters in the
-- label.
--
-- It runs on text that is normalized once per option and uses only native
-- string operations. `Search.score` normalizes the text on every call and does
-- its fuzzy check `Char` by `Char`, which costs 200-300 ms for 3 000 options in
-- a development build; this takes a few milliseconds.


{-| An option with its text prepared for matching, made by `index`. `option` is
the original option, `label` its normalized label, and `extra` the normalized
description and keywords together ("" when there are none). The `labelWords` and
`extraWords` forms start with a space and have word separators such as `-` and
`/` turned into spaces, so "a word starts with" is a plain substring test.
-}
type alias Entry id =
    { option : Option id
    , label : String
    , labelWords : String
    , extra : String
    , extraWords : String
    }


{-| The options of one list, prepared for matching. Make one with `index` and
ask it with `rank`.
-}
type alias Index id =
    List (Entry id)


{-| Prepares options for matching. Build it once per list of options and keep
it (the select components cache it in their state).

All labels (and all extra texts) are joined into one string and normalized in
one go, which is much faster than normalizing thousands of short strings.

    Option.index suppliers
        |> Option.rank "berlin"
        |> List.map (.option >> .label)

-}
index : List (Option id) -> Index id
index options =
    let
        count =
            List.length options

        labels =
            normalize (String.join separator (List.map .label options))

        extras =
            normalize (String.join separator (List.map extraText options))

        split joined =
            String.split separator joined

        normalizedLabels =
            split labels

        normalizedExtras =
            split extras

        labelWordForms =
            split (separatorsToSpaces labels)

        extraWordForms =
            split (separatorsToSpaces extras)

        lengthsMatch =
            List.all (\parts -> List.length parts == count)
                [ normalizedLabels, normalizedExtras, labelWordForms, extraWordForms ]
    in
    if count > 0 && lengthsMatch then
        List.map5
            (\opt label labelWords extra extraWords ->
                { option = opt
                , label = label
                , labelWords = " " ++ labelWords
                , extra = extra
                , extraWords =
                    if extra == "" then
                        ""

                    else
                        " " ++ extraWords
                }
            )
            options
            normalizedLabels
            labelWordForms
            normalizedExtras
            extraWordForms

    else
        List.map entry options


{-| Joins the texts for bulk normalization; a control character that does not
occur in labels and is not changed by lowercasing.
-}
separator : String
separator =
    "\u{0001}"


extraText : Option id -> String
extraText opt =
    case ( opt.description, opt.keywords ) of
        ( Nothing, [] ) ->
            ""

        ( Just description, words ) ->
            String.join " " (description :: words)

        ( Nothing, words ) ->
            String.join " " words


entry : Option id -> Entry id
entry opt =
    let
        label =
            normalize opt.label

        extra =
            normalize (extraText opt)
    in
    { option = opt
    , label = label
    , labelWords = wordForm label
    , extra = extra
    , extraWords =
        if extra == "" then
            ""

        else
            wordForm extra
    }


{-| Lowercases a text and replaces letters with diacritics by their plain
letters, so "é" and "e", or "ü" and "u", compare equal. It is `Klar.Search.normalize`.

    Option.normalize "Crème" --> "creme"

-}
normalize : String -> String
normalize text =
    Internal.normalize text


wordForm : String -> String
wordForm text =
    " " ++ separatorsToSpaces text


{-| Word separators (as `Klar.Search` splits words) turned into spaces.
-}
separatorsToSpaces : String -> String
separatorsToSpaces text =
    List.foldl
        (\mark acc ->
            if String.contains mark acc then
                String.replace mark " " acc

            else
                acc
        )
        text
        [ "-", "/", "\t", "\n", "\u{000D}", "\u{00A0}" ]


{-| One word of a query, prepared once per query by `prepare`: `text` is the
normalized word, `spaced` the same with a space in front (to find the start of a
word), `letters` its letters one by one, and `fuzzy` says whether letters in
order may match it (words of three letters or more).
-}
type alias Word =
    { text : String
    , spaced : String
    , letters : List String
    , fuzzy : Bool
    }


{-| Splits a query into normalized words, ready for `labelMatches`. A blank
query gives no words.

    Option.prepare "  Acme  Supplies " |> List.map .text --> [ "acme", "supplies" ]

-}
prepare : String -> List Word
prepare query =
    normalize query
        |> String.words
        |> List.filter (\word -> word /= "")
        |> List.map
            (\word ->
                { text = word
                , spaced = " " ++ word
                , letters = String.split "" word
                , fuzzy = String.length word >= 3
                }
            )


scoreText : List Word -> String -> String -> Maybe Int
scoreText words haystack haystackWords =
    scoreWords words haystack haystackWords 0


scoreWords : List Word -> String -> String -> Int -> Maybe Int
scoreWords words haystack haystackWords total =
    case words of
        [] ->
            Just total

        word :: rest ->
            case scoreWord word haystack haystackWords of
                Just points ->
                    scoreWords rest haystack haystackWords (total + points)

                Nothing ->
                    Nothing


scoreWord : Word -> String -> String -> Maybe Int
scoreWord word haystack haystackWords =
    if haystack == word.text then
        Just 0

    else if String.startsWith word.text haystack then
        Just 1

    else if String.contains word.spaced haystackWords then
        Just 2

    else if String.contains word.text haystack then
        Just 3

    else if word.fuzzy && inOrder word.letters haystack then
        Just 6

    else
        Nothing


{-| Whether the letters appear in this order and reasonably close together
(within about twice their own length), like `Klar.Search`.
-}
inOrder : List String -> String -> Bool
inOrder letters haystack =
    case walk letters haystack 0 Nothing of
        Just ( first, last ) ->
            last - first + 1 <= 2 * List.length letters + 2

        Nothing ->
            False


walk : List String -> String -> Int -> Maybe Int -> Maybe ( Int, Int )
walk letters rest offset first =
    case letters of
        [] ->
            Maybe.map (\start -> ( start, offset - 1 )) first

        letter :: others ->
            case String.indexes letter rest of
                position :: _ ->
                    let
                        absolute =
                            offset + position

                        consumed =
                            position + String.length letter
                    in
                    walk others
                        (String.dropLeft consumed rest)
                        (offset + consumed)
                        (Just (Maybe.withDefault absolute first))

                [] ->
                    Nothing


{-| The sum over the query words of each word's best score in the label, or
in the description and keywords (3 more). `Nothing` when a word is in neither.
-}
scoreEntry : List Word -> Entry id -> Maybe Int
scoreEntry words e =
    scoreEntryWords words e 0


scoreEntryWords : List Word -> Entry id -> Int -> Maybe Int
scoreEntryWords words e total =
    case words of
        [] ->
            Just total

        word :: rest ->
            let
                inLabel =
                    scoreWord word e.label e.labelWords
            in
            case inLabel of
                Just points ->
                    if points <= 3 || e.extra == "" then
                        -- the description cannot do better than 3
                        scoreEntryWords rest e (total + points)

                    else
                        case scoreWord word e.extra e.extraWords of
                            Just extraPoints ->
                                scoreEntryWords rest e (total + min points (extraPoints + 3))

                            Nothing ->
                                scoreEntryWords rest e (total + points)

                Nothing ->
                    if e.extra == "" then
                        Nothing

                    else
                        case scoreWord word e.extra e.extraWords of
                            Just extraPoints ->
                                scoreEntryWords rest e (total + extraPoints + 3)

                            Nothing ->
                                Nothing


{-| The entries of an index that match a query, best first; equal matches keep
their order. An empty query keeps everything. Use `.option` on an entry to get
the option back.
-}
rank : String -> Index id -> List (Entry id)
rank query entries =
    case prepare query of
        [] ->
            entries

        words ->
            entries
                |> List.filterMap (\e -> scoreEntry words e |> Maybe.map (\points -> ( points, e )))
                |> List.sortBy Tuple.first
                |> List.map Tuple.second


{-| How well a query matches an option: `Nothing` when it does not, otherwise a
number where lower is better. The label counts most; the description and the
keywords also match, 3 points worse. An empty query matches everything with 0.
The scale is described at the top of this page.

    Option.score "acme" (Option.option "acme" "Acme Supplies") --> Just 1

    Option.score "xyz" (Option.option "acme" "Acme Supplies") --> Nothing

-}
score : String -> Option id -> Maybe Int
score query opt =
    scoreEntry (prepare query) (entry opt)


{-| Whether the label alone matches every word of the prepared query. The select
rows use it to decide what to highlight: when the label explains the match, the
description is left alone, because it is not why the option matched.
-}
labelMatches : List Word -> Option id -> Bool
labelMatches words opt =
    let
        label =
            normalize opt.label
    in
    scoreText words label (wordForm label) /= Nothing


{-| The options that match a query, best matches first; equal matches keep
their order. An empty query returns the list unchanged. This is exactly how the
select components filter, so it suits a simulated backend or a count shown
elsewhere.

It prepares the whole list on every call. To search one list many times, make an
`index` once and use `rank`.

-}
filter : String -> List (Option id) -> List (Option id)
filter query options =
    if String.isEmpty (String.trim query) then
        options

    else
        rank query (index options) |> List.map .option


{-| Whether the label is the query, ignoring case, diacritics and spaces around
either. The selects use it to decide whether to offer the "Create" row for a text
that is not an option yet (see `Select.creatable`), and `Klar.Autocomplete` uses
it to see whether the typed text is one of its suggestions.
-}
isExactMatch : String -> Option id -> Bool
isExactMatch query opt =
    normalize (String.trim opt.label) == normalize (String.trim query)
