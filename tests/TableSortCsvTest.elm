module TableSortCsvTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table exposing (Direction(..))
import Klar.Table.Csv as Csv
import Klar.Table.Sort as Sort exposing (Key(..), Level(..))
import Support.Orders as Orders exposing (expectRows, render)
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Url


suite : Test
suite =
    describe "Klar.Table.Sort and Klar.Table.Csv"
        [ collationTests
        , keyTests
        , sortTests
        , sortPropertyTests
        , csvFieldTests
        , csvFormulaTests
        , csvEncodeTests
        , csvRoundTripTests
        , dataUrlTests
        , unpairedSurrogateTests
        ]


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual



-- COLLATION


{-| Is the first text sorted before the second in this language?
-}
before : Locale -> String -> String -> Bool
before locale a b =
    Sort.collationKey locale a < Sort.collationKey locale b


isLoneSurrogate : Char -> Bool
isLoneSurrogate c =
    Char.toCode c >= 0xD800 && Char.toCode c <= 0xDFFF


collationTests : Test
collationTests =
    describe "collationKey"
        [ check "Norwegian puts æ, ø and å after z, in that order"
            True
            (List.all identity
                [ before Locale.nb "Zebra" "Ægir"
                , before Locale.nb "Ægir" "Østby"
                , before Locale.nb "Østby" "Ålesund"
                , before Locale.nb "zzz" "æ"
                ]
            )
        , check "the documented example: Ålesund after Zürich in Norwegian" True (Sort.collationKey Locale.nb "Ålesund" > Sort.collationKey Locale.nb "Zürich")
        , check "the documented example: Ålesund before Bergen in English" True (Sort.collationKey Locale.en "Ålesund" < Sort.collationKey Locale.en "Bergen")
        , check "in English æ, ø and å sort with a, o and a"
            True
            (List.all identity
                [ before Locale.en "Ægir" "Bergen"
                , before Locale.en "Ørsta" "Pavel"
                , before Locale.en "Ålesund" "Bergen"
                , Sort.collationKey Locale.en "æ" == Sort.collationKey Locale.en "a"
                , Sort.collationKey Locale.en "ø" == Sort.collationKey Locale.en "o"
                ]
            )
        , check "case is ignored" True (Sort.collationKey Locale.nb "ABC" == Sort.collationKey Locale.nb "abc")
        , check "case is ignored for the Norwegian letters too" True (Sort.collationKey Locale.nb "ÆØÅ" == Sort.collationKey Locale.nb "æøå")
        , check "accents sort with their letter (a)" "aaaaaa" (Sort.collationKey Locale.en "áàâãäå")
        , check "accents sort with their letter (the others)" "eeeeiiiinooooouuuuyc" (Sort.collationKey Locale.en "éèêëíìîïñóòôõöúùûüýç")
        , check "é is e in Norwegian too" True (Sort.collationKey Locale.nb "Éva" == Sort.collationKey Locale.nb "Eva")
        , check "ü is y in Norwegian" True (Sort.collationKey Locale.nb "Zürich" == Sort.collationKey Locale.nb "Zyrich")
        , check "ü is u in English" True (Sort.collationKey Locale.en "Zürich" == Sort.collationKey Locale.en "Zurich")
        , check "ä sorts with æ and ö with ø in Norwegian"
            True
            (Sort.collationKey Locale.nb "ä" == Sort.collationKey Locale.nb "æ" && Sort.collationKey Locale.nb "ö" == Sort.collationKey Locale.nb "ø")
        , check "ñ is n, ç is c and ß is s" "ncs" (Sort.collationKey Locale.en "ñçß")
        , check "plain text is only lowercased" "hello, world 42!" (Sort.collationKey Locale.en "Hello, World 42!")
        , check "plain text is only lowercased (Norwegian)" "hello, world 42!" (Sort.collationKey Locale.nb "Hello, World 42!")
        , check "the empty text" "" (Sort.collationKey Locale.nb "")
        , check "text from other alphabets is left alone" "日本語 привет" (Sort.collationKey Locale.nb "日本語 Привет")
        , check "digits sort as text: 10 comes before 9" True (before Locale.en "10" "9")
        , check "a short text sorts before a longer one it begins" True (before Locale.en "ab" "abc")
        , check "spaces count" True (before Locale.en "a b" "ab")
        , fuzz Fuzz.asciiString "ASCII text only gets its case folded, in both languages" <|
            \text ->
                Expect.equal ( String.toLower text, String.toLower text ) ( Sort.collationKey Locale.en text, Sort.collationKey Locale.nb text )
        , fuzz Fuzz.string "the key of a key is that key" <|
            \text ->
                let
                    clean =
                        String.filter (\c -> not (isLoneSurrogate c)) text
                in
                Expect.all
                    [ \t -> Expect.equal (Sort.collationKey Locale.en t) (Sort.collationKey Locale.en (Sort.collationKey Locale.en t))
                    , \t -> Expect.equal (Sort.collationKey Locale.nb t) (Sort.collationKey Locale.nb (Sort.collationKey Locale.nb t))
                    ]
                    clean
        ]



-- KEYS


keyTests : Test
keyTests =
    describe "textKey and numberKey"
        [ check "a text key is the collation key of the trimmed text" (Text "alesund") (Sort.textKey Locale.en " Ålesund ")
        , check "in Norwegian" (Text "}lesund") (Sort.textKey Locale.nb "Ålesund")
        , check "blank text is missing" Missing (Sort.textKey Locale.en "   ")
        , check "the empty text is missing" Missing (Sort.textKey Locale.nb "")
        , check "tabs and line breaks are blank too" Missing (Sort.textKey Locale.nb "\t\n ")
        , check "text is trimmed first" (Sort.textKey Locale.nb "abc") (Sort.textKey Locale.nb "  abc  ")
        , check "a text with spaces inside is not missing" (Text "a b") (Sort.textKey Locale.en "a b")
        , check "zero is a number" (Number 0) (Sort.numberKey (Just 0))
        , check "a negative number" (Number -4.5) (Sort.numberKey (Just -4.5))
        , check "no number is missing" Missing (Sort.numberKey Nothing)
        , check "NaN is missing" Missing (Sort.numberKey (Just (0 / 0)))
        , check "infinity is a number" (Number (1 / 0)) (Sort.numberKey (Just (1 / 0)))
        ]



-- SORTING


type alias Item =
    { name : String
    , score : Maybe Float
    , group : String
    }


items : List Item
items =
    [ { name = "a", score = Just 3, group = "x" }
    , { name = "b", score = Nothing, group = "y" }
    , { name = "c", score = Just 1, group = "x" }
    , { name = "d", score = Just 3, group = "y" }
    , { name = "e", score = Just 2, group = "x" }
    , { name = "f", score = Nothing, group = "x" }
    ]


names : List Item -> List String
names =
    List.map .name


byScore : Bool -> Level Item
byScore descending =
    ByKey descending (\item -> Sort.numberKey item.score)


byGroup : Bool -> Level Item
byGroup descending =
    ByKey descending (\item -> Sort.textKey Locale.en item.group)


{-| The rows of the group x are a, c, e, f and those of y are b, d. A comparator
that puts y before x.
-}
yBeforeX : Item -> Item -> Order
yBeforeX a b =
    compare (rankOf a) (rankOf b)


rankOf : Item -> Int
rankOf item =
    if item.group == "x" then
        1

    else
        0


sortTests : Test
sortTests =
    describe "sort"
        [ check "no levels: the list as it is" [ "a", "b", "c", "d", "e", "f" ] (names (Sort.sort [] items))
        , check "an empty list" [] (Sort.sort [ byScore False ] [])
        , check "one item" [ "a" ] (names (Sort.sort [ byScore False ] [ { name = "a", score = Nothing, group = "" } ]))
        , check "one level, ascending; missing values last; equal values keep their order" [ "c", "e", "a", "d", "b", "f" ] (names (Sort.sort [ byScore False ] items))
        , check "one level, descending; missing values still last; equal values still keep their order" [ "a", "d", "e", "c", "b", "f" ] (names (Sort.sort [ byScore True ] items))
        , check "two levels: the first decides, the second breaks ties" [ "c", "e", "a", "f", "d", "b" ] (names (Sort.sort [ byGroup False, byScore False ] items))
        , check "two levels, the second one descending" [ "a", "e", "c", "f", "d", "b" ] (names (Sort.sort [ byGroup False, byScore True ] items))
        , check "two levels, the first one descending" [ "d", "b", "a", "e", "c", "f" ] (names (Sort.sort [ byGroup True, byScore True ] items))
        , check "three levels, where the last one never tells them apart" [ "c", "e", "a", "f", "d", "b" ] (names (Sort.sort [ byGroup False, byScore False, ByKey False (\_ -> Missing) ] items))
        , check "a comparator" [ "f", "e", "d", "c", "b", "a" ] (names (Sort.sort [ ByComparator False (\a b -> compare b.name a.name) ] items))
        , check "a comparator, descending, is the opposite" [ "a", "b", "c", "d", "e", "f" ] (names (Sort.sort [ ByComparator True (\a b -> compare b.name a.name) ] items))
        , check "a comparator keeps the order of equal rows" [ "b", "d", "a", "c", "e", "f" ] (names (Sort.sort [ ByComparator False yBeforeX ] items))
        , check "and also when descending" [ "a", "c", "e", "f", "b", "d" ] (names (Sort.sort [ ByComparator True yBeforeX ] items))
        , check "a comparator and a key" [ "d", "b", "a", "e", "c", "f" ] (names (Sort.sort [ ByComparator False yBeforeX, byScore True ] items))
        , check "a key and a comparator" [ "c", "e", "a", "f", "d", "b" ] (names (Sort.sort [ byGroup False, ByComparator False (\a b -> compare (Maybe.withDefault 99 a.score) (Maybe.withDefault 99 b.score)) ] items))
        , check "the sort does not lose or add items" 6 (List.length (Sort.sort [ byGroup False, byScore True ] items))
        , check "text keys compare as the language does: æ ø å after z"
            [ "z", "Æ", "Ø", "Å" ]
            (Sort.sort [ ByKey False (Sort.textKey Locale.nb) ] [ "Å", "Ø", "z", "Æ" ])
        , check "text keys compare as the language does (English)"
            [ "Å", "Æ", "Ø", "z" ]
            (Sort.sort [ ByKey False (Sort.textKey Locale.en) ] [ "Å", "Ø", "z", "Æ" ])
        , check "blank text goes last, descending too"
            [ "b", "a", "", "  " ]
            (Sort.sort [ ByKey True (Sort.textKey Locale.en) ] [ "", "a", "  ", "b" ])
        , check "blank text goes last, ascending"
            [ "a", "b", "", "  " ]
            (Sort.sort [ ByKey False (Sort.textKey Locale.en) ] [ "", "b", "  ", "a" ])
        , check "numbers come before text when a column has both"
            [ "5", "x" ]
            (Sort.sort
                [ ByKey False
                    (\value ->
                        case String.toFloat value of
                            Just n ->
                                Number n

                            Nothing ->
                                Text value
                    )
                ]
                [ "x", "5" ]
            )
        , check "NaN counts as missing, so it goes last"
            [ 1, 2, -1 ]
            (Sort.sort [ ByKey False (\n -> Sort.numberKey (Just n)) ] [ 0 / 0, 2, 1 ]
                |> List.map
                    (\n ->
                        if isNaN n then
                            -1

                        else
                            n
                    )
            )
        , check "negative numbers and zero" [ -5, -0.5, 0, 3 ] (Sort.sort [ ByKey False (\n -> Sort.numberKey (Just n)) ] [ 3, 0, -5, -0.5 ])
        , check "infinities sort at the ends" [ -1 / 0, 0, 1 / 0 ] (Sort.sort [ ByKey False (\n -> Sort.numberKey (Just n)) ] [ 1 / 0, 0, -1 / 0 ])
        , check "ten thousand items in reverse come out in order"
            (List.range 1 10000)
            (Sort.sort [ ByKey False (\n -> Sort.numberKey (Just (toFloat n))) ] (List.reverse (List.range 1 10000)))
        , check "ten thousand equal items keep their order"
            (List.range 1 10000)
            (Sort.sort [ ByKey False (\_ -> Number 1), ByKey False (\_ -> Missing) ] (List.range 1 10000))
        ]


type alias Row =
    { index : Int
    , number : Maybe Int
    , group : Int
    }


rowsFuzzer : Fuzzer (List Row)
rowsFuzzer =
    Fuzz.listOfLengthBetween 0 40 (Fuzz.map2 Tuple.pair (Fuzz.maybe (Fuzz.intRange -5 5)) (Fuzz.intRange 0 3))
        |> Fuzz.map (List.indexedMap (\index ( number, group ) -> { index = index, number = number, group = group }))


numberKeyOf : Row -> Key
numberKeyOf row =
    Sort.numberKey (Maybe.map toFloat row.number)


groupKeyOf : Row -> Key
groupKeyOf row =
    Number (toFloat row.group)


{-| Does row `a` belong before row `b` when sorting by the number, in this
direction? Missing numbers go last and equal numbers keep the order of the rows.
-}
numberFirst : Bool -> Row -> Row -> Bool
numberFirst descending a b =
    case ( a.number, b.number ) of
        ( Just x, Just y ) ->
            (if descending then
                x > y

             else
                x < y
            )
                || (x == y && a.index < b.index)

        ( Just _, Nothing ) ->
            True

        ( Nothing, Just _ ) ->
            False

        ( Nothing, Nothing ) ->
            a.index < b.index


inOrder : (a -> a -> Bool) -> List a -> Bool
inOrder before_ list =
    List.map2 before_ list (List.drop 1 list) |> List.all identity


sortPropertyTests : Test
sortPropertyTests =
    describe "sort, for any list"
        [ fuzz rowsFuzzer "ascending: no row is lost, they come in order, missing numbers last, equal numbers in the order of the rows" <|
            \list ->
                let
                    result =
                        Sort.sort [ ByKey False numberKeyOf ] list
                in
                Expect.all
                    [ \r -> Expect.equal (List.sort (List.map .index list)) (List.sort (List.map .index r))
                    , \r -> Expect.equal True (inOrder (numberFirst False) r)
                    ]
                    result
        , fuzz rowsFuzzer "descending: in reverse order but missing numbers still last and equal numbers still in the order of the rows" <|
            \list ->
                Sort.sort [ ByKey True numberKeyOf ] list
                    |> inOrder (numberFirst True)
                    |> Expect.equal True
        , fuzz rowsFuzzer "two levels: the first decides, the second breaks ties" <|
            \list ->
                let
                    belongsBefore a b =
                        if a.group /= b.group then
                            a.group < b.group

                        else
                            numberFirst True a b
                in
                Sort.sort [ ByKey False groupKeyOf, ByKey True numberKeyOf ] list
                    |> inOrder belongsBefore
                    |> Expect.equal True
        , fuzz rowsFuzzer "sorting a sorted list changes nothing" <|
            \list ->
                let
                    once =
                        Sort.sort [ ByKey False numberKeyOf ] list
                in
                Expect.equal once (Sort.sort [ ByKey False numberKeyOf ] once)
        , fuzz rowsFuzzer "a comparator that agrees with the key gives the same order" <|
            \list ->
                let
                    compareNumbers a b =
                        case ( a.number, b.number ) of
                            ( Just x, Just y ) ->
                                compare x y

                            _ ->
                                EQ

                    withNumbers =
                        List.filter (\row -> row.number /= Nothing) list
                in
                Expect.equal
                    (List.map .index (Sort.sort [ ByKey False numberKeyOf ] withNumbers))
                    (List.map .index (Sort.sort [ ByComparator False compareNumbers ] withNumbers))
        , fuzz rowsFuzzer "sorting descending and ascending gives the same rows, in opposite order when the keys differ" <|
            \list ->
                let
                    present =
                        List.filter (\row -> row.number /= Nothing) list
                            |> List.indexedMap (\i row -> { row | number = Maybe.map (\n -> n * 100 + modBy 100 i) row.number })
                in
                Expect.equal
                    (List.map .index (Sort.sort [ ByKey False numberKeyOf ] present))
                    (List.map .index (List.reverse (Sort.sort [ ByKey True numberKeyOf ] present)))
        ]



-- CSV


csvFieldTests : Test
csvFieldTests =
    describe "Csv.field"
        [ check "plain text" "Oslo" (Csv.field ';' "Oslo")
        , check "the empty text" "" (Csv.field ';' "")
        , check "a field with the separator is quoted" "\"Oslo; Bergen\"" (Csv.field ';' "Oslo; Bergen")
        , check "a field with a comma is not quoted when the separator is a semicolon" "Oslo, Bergen" (Csv.field ';' "Oslo, Bergen")
        , check "but is quoted when the separator is a comma" "\"Oslo, Bergen\"" (Csv.field ',' "Oslo, Bergen")
        , check "a tab as separator" "\"a\tb\"" (Csv.field '\t' "a\tb")
        , check "a bar as separator" "\"a|b\"" (Csv.field '|' "a|b")
        , check "quotes are doubled, and the field is quoted" "\"Ola \"\"Olsen\"\"\"" (Csv.field ';' "Ola \"Olsen\"")
        , check "a lone quote" "\"\"\"\"" (Csv.field ';' "\"")
        , check "a line feed" "\"a\nb\"" (Csv.field ';' "a\nb")
        , check "a carriage return" "\"a\u{000D}b\"" (Csv.field ';' "a\u{000D}b")
        , check "a Windows line break" "\"a\u{000D}\nb\"" (Csv.field ';' "a\u{000D}\nb")
        , check "a space at the start is quoted" "\" a\"" (Csv.field ';' " a")
        , check "a space at the end is quoted" "\"a \"" (Csv.field ';' "a ")
        , check "a space in the middle is not" "a b" (Csv.field ';' "a b")
        , check "only spaces are quoted" "\"  \"" (Csv.field ';' "  ")
        , check "a tab inside is not quoted unless it is the separator" "a\tb" (Csv.field ';' "a\tb")
        , check "letters outside ASCII are left as they are" "Østby Ålesund Æble" (Csv.field ';' "Østby Ålesund Æble")
        , check "emoji are left as they are" "📦 sent" (Csv.field ';' "📦 sent")
        , check "a single quote inside is left alone" "O'Brien" (Csv.field ';' "O'Brien")
        ]


csvFormulaTests : Test
csvFormulaTests =
    let
        -- a separator that no text has, so that only the guard is seen
        field =
            Csv.field '\u{0001}'

        guarded text =
            check ("is guarded: " ++ visible text) ("'" ++ text) (field text)

        notGuarded text =
            check ("is left alone: " ++ visible text) text (field text)

        visible text =
            text |> String.replace "\t" "<tab>" |> String.replace "\u{000D}" "<cr>"
    in
    describe "Csv.field and formulas"
        [ guarded "=SUM(A1)"
        , guarded "=1+1"
        , guarded "+SUM(A1)"
        , guarded "-SUM(A1)"
        , guarded "@SUM(A1)"
        , guarded "\tcmd"
        , guarded "=cmd|' /C calc'!A0"
        , guarded "-x"
        , guarded "--5"
        , guarded "+47 22 33 44 55"
        , guarded "-1,234.5"
        , guarded "-1,2,3"
        , guarded "-Infinity"
        , guarded "=-5"
        , guarded "+x"
        , guarded "@x"
        , check "a carriage return at the start is guarded, and then the field needs quotes" "\"'\u{000D}cmd\"" (field "\u{000D}cmd")
        , notGuarded "-12,5"
        , notGuarded "+3"
        , notGuarded "-0.25"
        , notGuarded "-5"
        , notGuarded "-1e3"
        , notGuarded "+4722334455"
        , notGuarded "5-3"
        , notGuarded "a=b"
        , notGuarded "x+y"
        , notGuarded "'=SUM(A1)"
        , notGuarded "text @ the end"
        , notGuarded "="
        , notGuarded "-"
        , notGuarded "+"
        , notGuarded "@"
        , check "a guarded field that also needs quotes gets both" "\"'=A,B\"" (Csv.field ',' "=A,B")
        , check "a guarded field with a quote inside" "\"'=\"\"x\"\"\"" (Csv.field ',' "=\"x\"")
        , check "a negative number with a comma, when the comma is the separator, is quoted and not guarded" "\"-12,5\"" (Csv.field ',' "-12,5")
        ]


csvEncodeTests : Test
csvEncodeTests =
    describe "Csv.encode"
        [ check "no rows" "" (Csv.encode ',' [])
        , check "one row" "a,b,c" (Csv.encode ',' [ [ "a", "b", "c" ] ])
        , check "rows end with CRLF, the last one without" "a,b\u{000D}\nc,d" (Csv.encode ',' [ [ "a", "b" ], [ "c", "d" ] ])
        , check "a semicolon" "a;b\u{000D}\nc;\"d\"\"e\"" (Csv.encode ';' [ [ "a", "b" ], [ "c", "d\"e" ] ])
        , check "the documented example" "Navn;By\u{000D}\n\"Ola \"\"Olsen\"\" Nordmann\";Oslo" (Csv.encode ';' [ [ "Navn", "By" ], [ "Ola \"Olsen\" Nordmann", "Oslo" ] ])
        , check "an empty field" "a,,c" (Csv.encode ',' [ [ "a", "", "c" ] ])
        , check "a row of empty fields" ",," (Csv.encode ',' [ [ "", "", "" ] ])
        , check "a row without fields is an empty line" "a\u{000D}\n\u{000D}\nb" (Csv.encode ',' [ [ "a" ], [], [ "b" ] ])
        , check "rows may have different lengths" "a\u{000D}\nb,c" (Csv.encode ',' [ [ "a" ], [ "b", "c" ] ])
        , check "a line break inside a field stays inside the quotes" "\"a\nb\",c" (Csv.encode ',' [ [ "a\nb", "c" ] ])
        , check "every field of every row is guarded" "'=a,b\u{000D}\n'@c" (Csv.encode ',' [ [ "=a", "b" ], [ "@c" ] ])
        , check "a tab as separator" "a\tb\u{000D}\nc\td" (Csv.encode '\t' [ [ "a", "b" ], [ "c", "d" ] ])
        , check "the file does not end with a line break" False (String.endsWith "\n" (Csv.encode ',' [ [ "a" ], [ "b" ] ]))
        , check "a thousand rows have 999 line breaks" 999 (List.length (List.filter (\c -> c == '\n') (String.toList (Csv.encode ',' (List.repeat 1000 [ "a", "b" ])))))
        ]


{-| A reader for what `Csv.encode` writes (RFC 4180), to check that the quoting
holds up: the rows that come out are the rows that went in. An empty text is
one row with one empty field.
-}
parse : Char -> String -> List (List String)
parse separator text =
    let
        finishCell state =
            { state | cells = state.current :: state.cells, current = "", closed = False }

        finishRow state =
            let
                cells =
                    List.reverse (state.current :: state.cells)
            in
            { state | rows = cells :: state.rows, cells = [], current = "", closed = False }

        step c state =
            if state.quoted then
                if c == '"' then
                    { state | quoted = False, closed = True }

                else
                    { state | current = state.current ++ String.fromChar c }

            else if c == '"' && state.closed then
                -- two quotes in a row inside a quoted field are one quote
                { state | quoted = True, closed = False, current = state.current ++ "\"" }

            else if c == '"' then
                { state | quoted = True }

            else if c == separator then
                finishCell state

            else if c == '\u{000D}' then
                state

            else if c == '\n' then
                finishRow state

            else
                { state | current = state.current ++ String.fromChar c }

        final =
            String.foldl step { rows = [], cells = [], current = "", quoted = False, closed = False } text
    in
    List.reverse (finishRow final).rows


{-| A cell that does not start with a character that gets guarded, made of the
characters that make quoting hard.
-}
cellFuzzer : Fuzzer String
cellFuzzer =
    Fuzz.oneOf
        [ Fuzz.constant ""
        , Fuzz.listOfLengthBetween 0 8 (Fuzz.oneOfValues [ 'a', ' ', ',', ';', '"', '\n', '\u{000D}', '\'', 'é', 'ø', '\t', '|', '=' ])
            |> Fuzz.map (\characters -> "x" ++ String.fromList characters)
        ]


csvRoundTripTests : Test
csvRoundTripTests =
    describe "Csv.encode, read back"
        [ fuzz2 (Fuzz.oneOfValues [ ',', ';', '\t', '|' ]) (Fuzz.listOfLengthBetween 1 6 (Fuzz.listOfLengthBetween 1 5 cellFuzzer)) "the rows that come out are the rows that went in" <|
            \separator rows ->
                Csv.encode separator rows
                    |> parse separator
                    |> Expect.equal rows
        , check "the reader reads what the writer writes (a known case)"
            [ [ "a", "b;c", "d\"e" ], [ "", "x\ny" ] ]
            (parse ';' (Csv.encode ';' [ [ "a", "b;c", "d\"e" ], [ "", "x\ny" ] ]))
        ]


dataUrlTests : Test
dataUrlTests =
    let
        prefix =
            "data:text/csv;charset=utf-8,"
    in
    describe "Csv.dataUrl"
        [ check "starts as a data URL for CSV in UTF-8" True (String.startsWith prefix (Csv.dataUrl "a,b"))
        , check "the file starts with a byte order mark, so that Excel reads æ, ø and å" True (String.startsWith (prefix ++ "%EF%BB%BF") (Csv.dataUrl "a,b"))
        , check "the empty CSV is only the mark" (prefix ++ "%EF%BB%BF") (Csv.dataUrl "")
        , check "plain text follows the mark" (prefix ++ "%EF%BB%BFa%2Cb") (Csv.dataUrl "a,b")
        , check "line breaks are encoded" (prefix ++ "%EF%BB%BFa%0D%0Ab") (Csv.dataUrl "a\u{000D}\nb")
        , check "letters outside ASCII are encoded as UTF-8" (prefix ++ "%EF%BB%BF%C3%A6%C3%B8%C3%A5") (Csv.dataUrl "æøå")
        , check "a hash would cut the URL, so it is encoded" True (String.contains "%23" (Csv.dataUrl "a#b") && not (String.contains "#" (Csv.dataUrl "a#b")))
        , check "a percent sign is encoded" True (String.contains "%25" (Csv.dataUrl "100%"))
        , check "quotes and spaces are encoded" (prefix ++ "%EF%BB%BF%22a%20b%22") (Csv.dataUrl "\"a b\"")
        , check "emoji are encoded" (prefix ++ "%EF%BB%BF%F0%9F%93%A6") (Csv.dataUrl "📦")
        , fuzz Fuzz.string "decoding gives the mark and the text back" <|
            \csv ->
                Csv.dataUrl (String.filter (\c -> not (isLoneSurrogate c)) csv)
                    |> String.dropLeft (String.length prefix)
                    |> Url.percentDecode
                    |> Expect.equal (Just ("\u{FEFF}" ++ String.filter (\c -> not (isLoneSurrogate c)) csv))
        , fuzz Fuzz.string "nothing in the URL needs escaping in an attribute: no quote, space, angle bracket, hash or line break" <|
            \csv ->
                Csv.dataUrl (String.filter (\c -> not (isLoneSurrogate c)) csv)
                    |> String.dropLeft (String.length prefix)
                    |> String.any (\c -> List.member c [ '"', ' ', '<', '>', '#', '\n', '\u{000D}' ])
                    |> Expect.equal False
        ]



-- TEXT THAT IS NOT VALID UTF-16


{-| Text with half of a surrogate pair, such as an emoji that a backend cut in
the middle. The browser's `encodeURIComponent` throws on it, and
`Url.percentEncode` is that function.
-}
halfAnEmoji : String
halfAnEmoji =
    String.dropRight 1 "Order 📦"


oneOrder : String -> String -> Orders.Order
oneOrder customer number =
    { number = number, customer = customer, city = "Oslo", items = 1, total = 1, status = "Open", shipped = Nothing, express = False }


unpairedSurrogateTests : Test
unpairedSurrogateTests =
    describe "text with an unpaired surrogate (half an emoji) must not crash"
        [ test "the text that is used here is the six letters and one half of the emoji, which takes two" <|
            \_ ->
                Expect.equal ( 7, 8 ) ( String.length halfAnEmoji, String.length "Order 📦" )
        , -- Was a bug: collationKey asked the browser, through Url.percentEncode, whether the
          -- text has letters from U+00C0 to U+00FF. encodeURIComponent throws a URIError on an
          -- unpaired surrogate, so sorting a column that holds one such value threw.
          test "collationKey" <|
            \_ -> Expect.atLeast 1 (String.length (Sort.collationKey Locale.nb halfAnEmoji))
        , -- The same through textKey, which every text column sorts with.
          test "textKey" <|
            \_ -> Expect.notEqual Missing (Sort.textKey Locale.en halfAnEmoji)
        , -- The same through the table: sorting by a column with such a value.
          test "a table sorted by a column with such a value" <|
            \_ ->
                render
                    [ Table.rows (Success [ oneOrder halfAnEmoji "ORD-1", oneOrder "Acme" "ORD-2" ]) ]
                    (Table.setSort [ ( "customer", Ascending ) ] (Table.init "orders"))
                    |> expectRows [ "ORD-2", "ORD-1" ]
        , -- And through the search of a table (Table.fold used Url.percentEncode too).
          test "a table searched for a word, with such a value in a row" <|
            \_ ->
                render
                    [ Table.rows (Success [ oneOrder halfAnEmoji "ORD-1", oneOrder "Acme" "ORD-2" ]) ]
                    (Table.setSearch "acme" (Table.init "orders"))
                    |> expectRows [ "ORD-2" ]
        , -- And the CSV download, which the export menu builds when it is opened.
          test "dataUrl" <|
            \_ -> Expect.equal True (String.startsWith "data:text/csv" (Csv.dataUrl halfAnEmoji))
        ]
