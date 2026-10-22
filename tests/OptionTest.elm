module OptionTest exposing (suite)

{-| Tests of the option model of the select family and of the matching behind
it (`Klar.Select.Option`), and of the pure machinery of `Klar.Select.Popup`:
rows, groups, the "create" row, keyboard navigation, the key bindings and the
texts.

The expected scores and orders were worked out with a second, independent
calculation (a few lines of Python following the scale in the documentation)
and are written down here as plain values.

-}

import Array
import Expect
import Fuzz exposing (Fuzzer)
import Html
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Icon as Icon
import Klar.Locale as Locale exposing (Locale)
import Klar.Search as Search
import Klar.Select as Select
import Klar.Select.Match as Match
import Klar.Select.Option as Option exposing (Option)
import Klar.Select.Popup as Popup exposing (Move(..), Outcome(..), Row(..))
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.Select.Option and the machinery of the select family"
        [ buildingTests
        , normalizeTests
        , prepareTests
        , scoreTests
        , labelMatchesTests
        , exactMatchTests
        , rankingTests
        , indexTests
        , matchingProperties
        , searchAgreementTests
        , groupTests
        , rowTests
        , cacheTests
        , rowProperties
        , navigationTests
        , navigationProperties
        , actTests
        , keydownTests
        , triggerKeyTests
        , windowKeyTests
        , textTests
        , statusTests
        , geometryTests
        , viewRowTests
        ]



-- DATA


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual


{-| The suppliers of the documentation of `Klar.Select.Option`, and a few more.
-}
acme : Option String
acme =
    Option.option "acme" "Acme Supplies"
        |> Option.withDescription "Berlin"
        |> Option.withGroup "Preferred"


globex : Option String
globex =
    Option.option "globex" "Globex"
        |> Option.withKeywords [ "Globex Corporation" ]


initech : Option String
initech =
    Option.option "initech" "Initech"
        |> Option.disabledOption


umbrella : Option String
umbrella =
    Option.option "umbrella" "Umbrella Trading"
        |> Option.withDescription "Hamburg"
        |> Option.withGroup "Preferred"


hooli : Option String
hooli =
    Option.option "hooli" "Hooli"
        |> Option.withGroup "Other"


soylent : Option String
soylent =
    Option.option "soylent" "Soylent Foods"
        |> Option.withDescription "Berlin"
        |> Option.withKeywords [ "vegan", "snacks" ]


suppliers : List (Option String)
suppliers =
    [ acme, globex, initech, umbrella, hooli, soylent ]


values : List (Option String) -> List String
values =
    List.map .value


{-| An option that is only a label.
-}
labelled : String -> Option String
labelled label =
    Option.option "v" label



-- BUILDING OPTIONS


buildingTests : Test
buildingTests =
    let
        plain =
            Option.option "acme" "Acme Supplies"
    in
    describe "building options"
        [ check "an option has a value and a label and nothing else"
            { value = "acme", label = "Acme Supplies", description = Nothing, group = Nothing, disabled = False, icon = Nothing, tone = Nothing, color = Nothing, keywords = [] }
            plain
        , check "withDescription" { plain | description = Just "Berlin" } (Option.withDescription "Berlin" plain)
        , check "a second description replaces the first" (Just "Hamburg") (plain |> Option.withDescription "Berlin" |> Option.withDescription "Hamburg" |> .description)
        , check "withGroup" { plain | group = Just "Preferred" } (Option.withGroup "Preferred" plain)
        , check "a second group replaces the first" (Just "Other") (plain |> Option.withGroup "Preferred" |> Option.withGroup "Other" |> .group)
        , check "withIcon" { plain | icon = Just Icon.tag } (Option.withIcon Icon.tag plain)
        , check "withKeywords" { plain | keywords = [ "acme corp", "ac" ] } (Option.withKeywords [ "acme corp", "ac" ] plain)
        , check "calling withKeywords again adds to the keywords" [ "a", "b", "c" ] (plain |> Option.withKeywords [ "a" ] |> Option.withKeywords [ "b", "c" ] |> .keywords)
        , check "no keywords change nothing" plain (Option.withKeywords [] plain)
        , check "disabledOption" { plain | disabled = True } (Option.disabledOption plain)
        , check "disabling twice is disabling" True (plain |> Option.disabledOption |> Option.disabledOption |> .disabled)
        , check "the value is not changed by any of them"
            "acme"
            (plain
                |> Option.withDescription "d"
                |> Option.withGroup "g"
                |> Option.withIcon Icon.tag
                |> Option.withKeywords [ "k" ]
                |> Option.disabledOption
                |> .value
            )
        , check "all together" { value = "acme", label = "Acme Supplies", description = Just "Berlin", group = Just "Preferred", disabled = False, icon = Nothing, tone = Nothing, color = Nothing, keywords = [] } acme
        , check "the order of the with functions does not matter"
            (plain |> Option.withDescription "d" |> Option.withGroup "g" |> Option.withKeywords [ "k" ] |> Option.disabledOption)
            (plain |> Option.disabledOption |> Option.withKeywords [ "k" ] |> Option.withGroup "g" |> Option.withDescription "d")
        , check "Select re-exports the same functions"
            (Option.option "x" "X" |> Option.withGroup "g")
            (Select.option "x" "X" |> Select.withGroup "g")
        ]



-- NORMALIZING


{-| The letters that are folded, with the letter they come to.
-}
folded : List ( String, String )
folded =
    [ ( "å", "a" )
    , ( "ä", "a" )
    , ( "á", "a" )
    , ( "à", "a" )
    , ( "â", "a" )
    , ( "ã", "a" )
    , ( "æ", "a" )
    , ( "ø", "o" )
    , ( "ö", "o" )
    , ( "ó", "o" )
    , ( "ò", "o" )
    , ( "ô", "o" )
    , ( "õ", "o" )
    , ( "é", "e" )
    , ( "è", "e" )
    , ( "ê", "e" )
    , ( "ë", "e" )
    , ( "í", "i" )
    , ( "ì", "i" )
    , ( "î", "i" )
    , ( "ï", "i" )
    , ( "ú", "u" )
    , ( "ù", "u" )
    , ( "û", "u" )
    , ( "ü", "u" )
    , ( "ç", "c" )
    , ( "ñ", "n" )
    , ( "ý", "y" )
    , ( "ß", "s" )
    ]


normalizeTests : Test
normalizeTests =
    describe "normalize"
        [ check "lowercases" "acme supplies" (Match.normalize "ACME Supplies")
        , check "the documented example" "creme" (Match.normalize "Crème")
        , check "the empty text" "" (Match.normalize "")
        , check "Norwegian letters" "aro ase ostfold" (Match.normalize "Ærø Åse Østfold")
        , check "German letters" "zurich muller" (Match.normalize "Zürich Müller")
        , check "French letters" "cafe creme brulee" (Match.normalize "Café Crème Brûlée")
        , check "digits, punctuation and spaces stay" "12 - 34/56 (x), y." (Match.normalize "12 - 34/56 (X), Y.")
        , check "other scripts are lowercased and otherwise kept"
            "αβγ привет 日本"
            (Match.normalize "ΑΒΓ Привет 日本")
        , check "the capital sharp s" "s" (Match.normalize "ẞ")
        , describe "folds every letter of the table"
            (List.map (\( from, to ) -> check (from ++ " comes to " ++ to) to (Match.normalize from)) folded)
        , describe "and the capital of it"
            (folded
                |> List.filter (\( from, _ ) -> from /= "ß")
                |> List.map (\( from, to ) -> check (String.toUpper from ++ " comes to " ++ to) to (Match.normalize (String.toUpper from)))
            )
        , -- Was a bug: the documentation says letters with diacritics are replaced by their plain
          -- letters ("Matching ignores case and diacritics"), but the table has only 29 letters
          -- of Latin-1: the letters of Polish, Czech, Slovak, Croatian, Turkish and other names
          -- stay as they are, so "skoda" does not find "Škoda" and "lodz" not "Łódź".
          -- Fixed in `Klar.Internal.normalize`, the one function that Search and Option share.
          check "letters with diacritics outside Latin-1 are folded too"
            "skoda zilina capek dvorak lodz"
            (Match.normalize "Škoda Žilina Čapek Dvořák Łódź")
        , fuzz Fuzz.string "normalizing twice is normalizing once" <|
            \text -> Match.normalize (Match.normalize text) |> Expect.equal (Match.normalize text)
        , fuzz asciiFuzzer "ASCII text is only lowercased" <|
            \text -> Match.normalize text |> Expect.equal (String.toLower text)
        , fuzz Fuzz.string "Search.normalize does the same" <|
            \text -> Match.normalize text |> Expect.equal (Search.normalize text)
        ]


asciiFuzzer : Fuzzer String
asciiFuzzer =
    Fuzz.listOfLengthBetween 0 20 (Fuzz.intRange 32 126)
        |> Fuzz.map (List.map Char.fromCode >> String.fromList)



-- QUERY WORDS


prepareTests : Test
prepareTests =
    describe "prepare"
        [ check "splits a query into normalized words" [ "acme", "supplies" ] (Match.prepare "  Acme  Supplies " |> List.map .text)
        , check "a blank query has no words" [] (Match.prepare "   " |> List.map .text)
        , check "the empty query has none either" [] (Match.prepare "" |> List.map .text)
        , check "tabs, line breaks and no-break spaces separate words" [ "a", "b", "c", "d" ] (Match.prepare "a\u{00A0}b\tc\nd" |> List.map .text)
        , check "the letters of a word are folded" [ "orsted", "zurich" ] (Match.prepare "Ørsted ZÜRICH" |> List.map .text)
        , check "spaced is the word with a space in front" [ " acme", " sup" ] (Match.prepare "acme sup" |> List.map .spaced)
        , check "letters are the letters one by one" [ [ "a", "c", "m", "e" ] ] (Match.prepare "ACME" |> List.map .letters)
        , check "only words of three letters or more may match by their letters"
            [ False, False, True, True ]
            (Match.prepare "a ab abc abcd" |> List.map .fuzzy)
        , check "a word that is an exact option" [ "acme supplies" ] (Match.prepare "acme supplies" |> List.map .text |> String.join " " |> List.singleton)
        ]



-- SCORES


scores : String -> Option String -> Maybe Int -> Test
scores query opt expected =
    check
        ("\""
            ++ query
            ++ "\" "
            ++ (case expected of
                    Just points ->
                        "scores " ++ String.fromInt points

                    Nothing ->
                        "does not match"
               )
        )
        expected
        (Match.score query opt)


scoreTests : Test
scoreTests =
    let
        withDescription text =
            Option.option "v" "Acme Supplies" |> Option.withDescription text
    in
    describe "score"
        [ describe "the label \"Acme Supplies\""
            [ scores "acme" (labelled "Acme Supplies") (Just 1)
            , scores "xyz" (labelled "Acme Supplies") Nothing
            , scores "" (labelled "Acme Supplies") (Just 0)
            , scores "   " (labelled "Acme Supplies") (Just 0)
            , scores "a" (labelled "Acme Supplies") (Just 1)
            , scores "ac" (labelled "Acme Supplies") (Just 1)
            , scores "sup" (labelled "Acme Supplies") (Just 2)
            , scores "supplies" (labelled "Acme Supplies") (Just 2)
            , scores "m" (labelled "Acme Supplies") (Just 3)
            , scores "e" (labelled "Acme Supplies") (Just 3)
            , scores "upp" (labelled "Acme Supplies") (Just 3)
            , scores "ppl" (labelled "Acme Supplies") (Just 3)
            , scores "lies" (labelled "Acme Supplies") (Just 3)
            , scores "splis" (labelled "Acme Supplies") (Just 6)
            , scores "sps" (labelled "Acme Supplies") (Just 6)
            , scores "sp" (labelled "Acme Supplies") Nothing
            , scores "ACME" (labelled "Acme Supplies") (Just 1)
            , scores "Åcme" (labelled "Acme Supplies") (Just 1)
            , scores "Acme Supplies" (labelled "Acme Supplies") (Just 3)
            , scores "supplies acme" (labelled "Acme Supplies") (Just 3)
            , scores "acme  supplies" (labelled "Acme Supplies") (Just 3)
            , scores "acme acme" (labelled "Acme Supplies") (Just 2)
            , scores "acme berlin" (labelled "Acme Supplies") Nothing
            ]
        , describe "a label that is one word"
            [ scores "initech" (labelled "Initech") (Just 0)
            , scores "INITECH" (labelled "Initech") (Just 0)
            , scores "tech" (labelled "Initech") (Just 3)
            , scores "init" (labelled "Initech") (Just 1)
            , scores "itch" (labelled "Initech") (Just 6)
            , scores "tich" (labelled "Initech") Nothing
            , scores "intch" (labelled "Initech") (Just 6)
            , scores "intech" (labelled "Initech") (Just 6)
            ]
        , describe "letters outside ASCII in the label and in the query"
            [ scores "zurich" (labelled "Zürich Flughafen") (Just 1)
            , scores "ZÜRICH" (labelled "Zürich Flughafen") (Just 1)
            , scores "zürich" (labelled "Zürich Flughafen") (Just 1)
            , scores "flug" (labelled "Zürich Flughafen") (Just 2)
            , scores "uri" (labelled "Zürich Flughafen") (Just 3)
            , scores "flughafen zurich" (labelled "Zürich Flughafen") (Just 3)
            , scores "orsted" (labelled "Ørsted") (Just 0)
            , scores "ørsted" (labelled "Ørsted") (Just 0)
            , scores "ØRSTED" (labelled "Ørsted") (Just 0)
            , scores "sted" (labelled "Ørsted") (Just 3)
            ]
        , describe "separators between the words of a label"
            [ scores "co-op" (labelled "Co-op/Market Hall") (Just 1)
            , scores "op" (labelled "Co-op/Market Hall") (Just 2)
            , scores "market" (labelled "Co-op/Market Hall") (Just 2)
            , scores "hall" (labelled "Co-op/Market Hall") (Just 2)
            , scores "/market" (labelled "Co-op/Market Hall") (Just 3)
            , scores "coop" (labelled "Co-op/Market Hall") (Just 6)
            , scores "hall market" (labelled "Co-op/Market Hall") (Just 4)
            , scores "hansen" (labelled "Dr.\u{00A0}Hansen") (Just 2)
            , scores "dr. hansen" (labelled "Dr.\u{00A0}Hansen") (Just 3)
            , check "a tab separates words" (Just 2) (Match.score "b" (labelled "A\tB"))
            , check "and so does a line break" (Just 2) (Match.score "b" (labelled "A\nB"))
            ]
        , describe "the description counts three points worse than the label"
            [ scores "berlin" (withDescription "Berlin") (Just 3)
            , scores "ber" (withDescription "Berlin") (Just 4)
            , scores "erl" (withDescription "Berlin") (Just 6)
            , scores "lin" (withDescription "Berlin") (Just 6)
            , scores "acme berlin" (withDescription "Berlin") (Just 4)
            , scores "berlin acme" (withDescription "Berlin") (Just 4)
            , scores "berlin xyz" (withDescription "Berlin") Nothing
            , scores "acme" (withDescription "Berlin") (Just 1)
            , scores "zurich" (Option.option "v" "Hooli" |> Option.withDescription "Zürich") (Just 3)
            , scores "berlin" (withDescription "") Nothing
            , check "an empty description changes nothing" (Just 1) (Match.score "acme" (withDescription ""))
            ]
        , describe "a better match in the description beats scattered letters in the label"
            [ scores "splis" (withDescription "splis") (Just 3)
            , scores "spl" (withDescription "splis") (Just 4)
            , scores "pp" (withDescription "pp") (Just 3)
            ]
        , describe "keywords are searched like a description"
            [ scores "corp" globex (Just 5)
            , scores "corporation" globex (Just 5)
            , scores "globex" globex (Just 0)
            , scores "globex corp" globex (Just 5)
            , scores "glob corp" globex (Just 6)
            , scores "orp" globex (Just 6)
            , scores "gam" (Option.option "v" "Hooli" |> Option.withKeywords [ "gamma" ]) (Just 4)
            , scores "gamma" (Option.option "v" "Hooli" |> Option.withKeywords [ "gamma" ]) (Just 3)
            , scores "alpha" (Option.option "v" "Hooli" |> Option.withKeywords [ "alpha", "beta" ]) (Just 4)
            , scores "beta" (Option.option "v" "Hooli" |> Option.withKeywords [ "alpha", "beta" ]) (Just 5)
            , scores "alpha beta" (Option.option "v" "Hooli" |> Option.withKeywords [ "alpha", "beta" ]) (Just 9)
            , scores "vegan" soylent (Just 5)
            , scores "snacks" soylent (Just 5)
            , scores "berlin" soylent (Just 4)
            , scores "food" soylent (Just 2)
            , scores "vegan snacks" soylent (Just 10)
            , scores "berlin vegan" soylent (Just 9)
            ]
        , describe "what is not searched"
            [ scores "secret" (Option.option "secret-code" "Acme") Nothing
            , scores "preferred" acme Nothing
            , scores "tag" (Option.option "v" "Acme" |> Option.withIcon Icon.tag) Nothing
            ]
        , describe "an option that is disabled is scored like any other"
            [ scores "init" initech (Just 1)
            , scores "ech" initech (Just 3)
            ]
        , describe "the letters of a word may be spread within twice their number plus two"
            [ scores "abc" (labelled "a123b45c") (Just 6)
            , scores "abc" (labelled "a123b456c") Nothing
            , scores "ab" (labelled "a1b") Nothing
            , scores "abc" (labelled "xabc") (Just 3)
            ]
        ]


labelMatchesTests : Test
labelMatchesTests =
    describe "labelMatches"
        [ check "the label has the word" True (Match.labelMatches (Match.prepare "acme") acme)
        , check "the label has all the words" True (Match.labelMatches (Match.prepare "supplies acme") acme)
        , check "the description is not the label" False (Match.labelMatches (Match.prepare "berlin") acme)
        , check "all the words have to be in the label" False (Match.labelMatches (Match.prepare "acme berlin") acme)
        , check "no words are matched by every label" True (Match.labelMatches (Match.prepare "") acme)
        , check "letters in order count" True (Match.labelMatches (Match.prepare "splis") acme)
        , check "keywords are not the label" False (Match.labelMatches (Match.prepare "corp") globex)
        , check "case and diacritics are ignored" True (Match.labelMatches (Match.prepare "ÅCME") acme)
        ]


exactMatchTests : Test
exactMatchTests =
    describe "isExactMatch"
        [ check "the same text" True (Match.isExactMatch "Acme Supplies" acme)
        , check "another case" True (Match.isExactMatch "acme supplies" acme)
        , check "spaces around the query" True (Match.isExactMatch "  Acme Supplies  " acme)
        , check "spaces around the label" True (Match.isExactMatch "Acme" (labelled " Acme "))
        , check "diacritics are ignored" True (Match.isExactMatch "zurich" (labelled "Zürich"))
        , check "and in the query" True (Match.isExactMatch "ZÜRICH" (labelled "Zurich"))
        , check "the start of a label is not the label" False (Match.isExactMatch "Acme" acme)
        , check "spaces inside count" False (Match.isExactMatch "Acme  Supplies" acme)
        , check "the description is not the label" False (Match.isExactMatch "Berlin" acme)
        , check "the value is not the label" False (Match.isExactMatch "acme" acme)
        , check "an empty query is the empty label" True (Match.isExactMatch "  " (labelled ""))
        , check "an empty query is not another label" False (Match.isExactMatch "" acme)
        ]



-- RANKING


ranked : String -> List (Option String) -> List String
ranked query options =
    Match.filter query options |> values


rankingTests : Test
rankingTests =
    let
        rankSuppliers query expected =
            check ("\"" ++ query ++ "\"") expected (ranked query suppliers)
    in
    describe "filter and rank over the suppliers"
        [ describe "the documented example"
            [ check "berlin finds Acme Supplies"
                [ "Acme Supplies" ]
                (Match.filter "berlin" [ Option.option "acme" "Acme Supplies" |> Option.withDescription "Berlin" |> Option.withGroup "Preferred", Option.option "globex" "Globex" |> Option.withKeywords [ "Globex Corporation" ], Option.option "initech" "Initech" |> Option.disabledOption ]
                    |> List.map .label
                )
            ]
        , describe "the best match first"
            [ rankSuppliers "berlin" [ "acme", "soylent" ]
            , rankSuppliers "a" [ "acme", "umbrella", "globex", "soylent" ]
            , rankSuppliers "acme" [ "acme" ]
            , rankSuppliers "ho" [ "hooli" ]
            , rankSuppliers "glo" [ "globex" ]
            , rankSuppliers "corp" [ "globex" ]
            , rankSuppliers "corporation" [ "globex" ]
            , rankSuppliers "trading" [ "umbrella" ]
            , rankSuppliers "hamburg" [ "umbrella" ]
            , rankSuppliers "vegan" [ "soylent" ]
            , rankSuppliers "food" [ "soylent" ]
            , rankSuppliers "sup" [ "acme" ]
            , rankSuppliers "bella" [ "umbrella" ]
            , rankSuppliers "uml" [ "umbrella" ]
            , rankSuppliers "ham" [ "umbrella" ]
            , rankSuppliers "um tr" [ "umbrella" ]
            , rankSuppliers "initech" [ "initech" ]
            , rankSuppliers "HOOLI" [ "hooli" ]
            ]
        , describe "equal matches keep their order"
            [ rankSuppliers "o" [ "globex", "hooli", "soylent" ]
            , rankSuppliers "e" [ "acme", "globex", "initech", "umbrella", "soylent" ]
            , rankSuppliers "l" [ "acme", "globex", "umbrella", "hooli", "soylent" ]
            , rankSuppliers "o o" [ "globex", "hooli", "soylent" ]
            ]
        , describe "every word has to match"
            [ rankSuppliers "acme berlin" [ "acme" ]
            , rankSuppliers "berlin acme" [ "acme" ]
            , rankSuppliers "soylent berlin" [ "soylent" ]
            , rankSuppliers "acme soylent" []
            , rankSuppliers "xyz" []
            , rankSuppliers "go" []
            , rankSuppliers "ubt" []
            ]
        , describe "a disabled option is found like any other"
            [ rankSuppliers "ech" [ "initech" ]
            , rankSuppliers "tech" [ "initech" ]
            ]
        , describe "a blank query keeps everything, in the order of the list"
            [ rankSuppliers "" (values suppliers)
            , rankSuppliers "   " (values suppliers)
            , rankSuppliers "\t" (values suppliers)
            ]
        , check "no options" [] (ranked "acme" [])
        , check "a group does not change the ranking of the matches" [ "umbrella", "acme" ] (ranked "u" [ acme, umbrella ])
        , check "nor does it matter whether an option is disabled" [ "initech", "globex" ] (ranked "e" [ initech, globex ])
        , describe "rank gives the entries"
            [ check "the options of the entries"
                [ "acme", "soylent" ]
                (Match.index suppliers |> Match.rank "berlin" |> List.map (.option >> .value))
            , check "an empty query keeps all the entries" 6 (Match.index suppliers |> Match.rank "" |> List.length)
            , check "a query of spaces too" 6 (Match.index suppliers |> Match.rank "   " |> List.length)
            , check "an empty index has no entries" 0 (Match.index [] |> Match.rank "acme" |> List.length)
            ]
        ]


indexTests : Test
indexTests =
    describe "index"
        [ check "no options" [] (Match.index [])
        , check "the entry of an option"
            [ { option = labelled "Åre-Bo/Ski"
              , label = "are-bo/ski"
              , labelWords = " are bo ski"
              , extra = ""
              , extraWords = ""
              }
            ]
            (Match.index [ labelled "Åre-Bo/Ski" ])
        , check "the description and the keywords make the extra text"
            [ { option = soylent
              , label = "soylent foods"
              , labelWords = " soylent foods"
              , extra = "berlin vegan snacks"
              , extraWords = " berlin vegan snacks"
              }
            ]
            (Match.index [ soylent ])
        , check "only keywords"
            [ { option = globex
              , label = "globex"
              , labelWords = " globex"
              , extra = "globex corporation"
              , extraWords = " globex corporation"
              }
            ]
            (Match.index [ globex ])
        , check "separators in the extra text become spaces in the word form"
            " co op hall"
            (Match.index [ Option.option "v" "x" |> Option.withDescription "Co-op/Hall" ] |> List.map .extraWords |> String.join "|")
        , check "an empty description is no extra text"
            ( "", "" )
            (Match.index [ Option.option "v" "x" |> Option.withDescription "" ] |> List.map (\e -> ( e.extra, e.extraWords )) |> List.head |> Maybe.withDefault ( "?", "?" ))
        , check "the entries are in the order of the options" (values suppliers) (Match.index suppliers |> List.map (.option >> .value))
        , check "the options are the ones that were given" suppliers (Match.index suppliers |> List.map .option)
        , check "a label with the control character that joins the texts does not mix the entries up"
            (List.concatMap (\o -> Match.index [ o ]) mixed)
            (Match.index mixed)
        , check "and the entries are still right" [ "a\u{0001}b", "c", "d" ] (Match.index mixed |> List.map .label)
        , check "the same for the extra text"
            [ "x\u{0001}y", "", "z" ]
            (Match.index [ labelled "a" |> Option.withDescription "x\u{0001}y", labelled "b", labelled "c" |> Option.withKeywords [ "z" ] ] |> List.map .extra)
        ]


mixed : List (Option String)
mixed =
    [ Option.option "1" "A\u{0001}b", Option.option "2" "C", Option.option "3" "D" ]



-- PROPERTIES OF THE MATCHING


vocabulary : List String
vocabulary =
    [ "Acme", "Supplies", "Globex", "Initech", "Umbrella", "Trading", "Hooli", "Soylent", "Foods", "Zürich", "Ørsted", "Åre", "Berlin", "Oslo", "Hamburg", "Co-op", "Market", "Hall", "a", "ab" ]


wordFuzzer : Fuzzer String
wordFuzzer =
    Fuzz.oneOfValues vocabulary


textFuzzer : Fuzzer String
textFuzzer =
    Fuzz.listOfLengthBetween 1 3 wordFuzzer
        |> Fuzz.map (String.join " ")


optionFuzzer : Fuzzer (Option String)
optionFuzzer =
    Fuzz.map5
        (\label description group keywords disabled ->
            { value = "", label = label, description = description, group = group, disabled = disabled, icon = Nothing, tone = Nothing, color = Nothing, keywords = keywords }
        )
        textFuzzer
        (Fuzz.maybe textFuzzer)
        (Fuzz.maybe (Fuzz.oneOfValues [ "Preferred", "Other", "Archive" ]))
        (Fuzz.listOfLengthBetween 0 2 wordFuzzer)
        Fuzz.bool


optionsFuzzer : Fuzzer (List (Option String))
optionsFuzzer =
    Fuzz.listOfLengthBetween 0 8 optionFuzzer
        |> Fuzz.map (List.indexedMap (\i opt -> { opt | value = "v" ++ String.fromInt i }))


queryFuzzer : Fuzzer String
queryFuzzer =
    Fuzz.frequency
        [ ( 5, Fuzz.oneOfValues [ "ac", "sup", "glo", "ber", "o", "a", "e", "ho", "market", "zur", "orst", "are", "co-op", "hall ma", "xyz", "", " ", "ber oslo", "sps", "umbl", "åre", "ZURICH" ] )
        , ( 2, textFuzzer )
        , ( 1, Fuzz.string )
        ]


{-| The options that match, best first, worked out one option at a time.
-}
oneByOne : String -> List (Option String) -> List (Option String)
oneByOne query options =
    if String.isEmpty (String.trim query) then
        options

    else
        options
            |> List.filterMap (\opt -> Match.score query opt |> Maybe.map (\points -> ( points, opt )))
            |> List.sortBy Tuple.first
            |> List.map Tuple.second


matchingProperties : Test
matchingProperties =
    describe "matching: properties"
        [ fuzz2 queryFuzzer optionsFuzzer "filter agrees with scoring the options one by one" <|
            \query options -> Match.filter query options |> Expect.equal (oneByOne query options)
        , fuzz2 queryFuzzer optionsFuzzer "rank over an index agrees with filter" <|
            \query options ->
                Match.index options
                    |> Match.rank query
                    |> List.map .option
                    |> Expect.equal (Match.filter query options)
        , fuzz2 queryFuzzer optionsFuzzer "the matches are options of the list, each once" <|
            \query options ->
                let
                    found =
                        Match.filter query options
                in
                Expect.all
                    [ \f -> Expect.equal True (List.all (\opt -> List.member opt options) f)
                    , \f -> Expect.equal (List.length f) (List.length (uniqueValues f))
                    , \f -> Expect.atMost (List.length options) (List.length f)
                    ]
                    found
        , fuzz2 queryFuzzer optionsFuzzer "the scores of the matches never go down" <|
            \query options ->
                let
                    points =
                        Match.filter query options
                            |> List.map (\opt -> Match.score query opt |> Maybe.withDefault -1)
                in
                Expect.equal points (List.sort points)
        , fuzz2 queryFuzzer optionsFuzzer "a blank query keeps all the options in their order" <|
            \_ options ->
                Expect.all
                    [ \_ -> Expect.equal options (Match.filter "" options)
                    , \_ -> Expect.equal options (Match.filter "  \t " options)
                    , \_ -> Expect.equal (List.length options) (List.length (Match.rank " " (Match.index options)))
                    ]
                    ()
        , fuzz2 queryFuzzer optionsFuzzer "an option is a match exactly when its score is something" <|
            \query options ->
                let
                    found =
                        Match.filter query options
                in
                options
                    |> List.filter (\opt -> not (List.member opt found))
                    |> List.all (\opt -> String.isEmpty (String.trim query) || Match.score query opt == Nothing)
                    |> Expect.equal True
        , fuzz2 (Fuzz.pair queryFuzzer wordFuzzer) optionsFuzzer "one more word in the query never adds a match" <|
            \( query, word ) options ->
                let
                    before =
                        Match.filter query options

                    after =
                        Match.filter (query ++ " " ++ word) options
                in
                if String.isEmpty (String.trim query) then
                    Expect.pass

                else
                    Expect.equal True (List.all (\opt -> List.member opt before) after)
        , fuzz2 queryFuzzer optionsFuzzer "the case of the query does not matter" <|
            \query options ->
                Match.filter (String.toUpper query) options |> Expect.equal (Match.filter (String.toLower query) options)
        , fuzz2 queryFuzzer optionsFuzzer "an index of the options is the same as one index for each option" <|
            \_ options ->
                Match.index options |> Expect.equal (List.concatMap (\opt -> Match.index [ opt ]) options)
        , fuzz optionFuzzer "an option with a label of one word is found by that word, with a score of 0" <|
            \opt ->
                let
                    single =
                        { opt | label = "Initech" }
                in
                Expect.equal (Just 0) (Match.score "initech" single)
        , fuzz2 queryFuzzer optionFuzzer "labelMatches means the score without the description is something" <|
            \query opt ->
                let
                    plain =
                        { opt | description = Nothing, keywords = [] }
                in
                Match.labelMatches (Match.prepare query) opt
                    |> Expect.equal (Match.score query plain /= Nothing)
        ]


uniqueValues : List (Option String) -> List String
uniqueValues options =
    List.foldl
        (\opt seen ->
            if List.member opt.value seen then
                seen

            else
                opt.value :: seen
        )
        []
        options


searchAgreementTests : Test
searchAgreementTests =
    let
        -- the text of an <mark> inside a highlighted text, the part that is shown marked
        markedPart query text expected =
            Html.div [] (Search.highlight query text)
                |> Query.fromHtml
                |> Query.find [ Selector.tag "mark" ]
                |> Query.has [ Selector.exactText expected ]
    in
    describe "Search and Option String agree"
        [ fuzz2 queryFuzzer textFuzzer "the score of a label is the score of a text" <|
            \query label -> Match.score query (labelled label) |> Expect.equal (Search.score query label)
        , fuzz2 queryFuzzer Fuzz.string "and of any text" <|
            \query label -> Match.score query (labelled label) |> Expect.equal (Search.score query label)
        , fuzz2 queryFuzzer Fuzz.string "the same words are found in the same places" <|
            \query label ->
                Expect.equal (List.map .text (Match.prepare query)) (Search.normalize query |> String.words |> List.filter (\w -> w /= ""))
        , test "a mark shows the part of the text that the query matched" <|
            \_ -> markedPart "ber" "Bergen" "Ber"
        , test "also when the letters have other forms" <|
            \_ -> markedPart "orsted" "Ørsted" "Ørsted"
        , -- Was a bug: `Search.normalize` is documented to keep the length of the text ("so a match
          -- position in the normalized text is the same position in the original"), but
          -- `String.toLower` turns the Turkish capital I with a dot (U+0130) into two characters
          -- (an i and a combining dot), so everything after one is marked one character late:
          -- "airport" in "\u{0130}stanbul Airport" marks "irport".
          -- Fixed in `Klar.Internal.normalize`: the capital I with a dot is made a plain I before lowering.
          test "a mark is in the right place in a text with a Turkish capital I with a dot" <|
            \_ -> markedPart "airport" "İstanbul Airport" "Airport"
        , -- Was a bug: the same cause as above, as the documented claim about the length.
          check "normalizing does not change the length of a text" (String.length "İ") (String.length (Search.normalize "İ"))
        ]



-- GROUPS AND ROWS


groupTests : Test
groupTests =
    let
        a1 =
            Option.option "a1" "A1" |> Option.withGroup "A"

        a2 =
            Option.option "a2" "A2" |> Option.withGroup "A"

        b1 =
            Option.option "b1" "B1" |> Option.withGroup "B"

        n1 =
            Option.option "n1" "N1"

        n2 =
            Option.option "n2" "N2"

        unnamed =
            { n2 | group = Just "" }
    in
    describe "groups in the rows"
        [ check "options without groups are rows without headings" [ Item 1 n1, Item 2 n2 ] (rowList (rowsOf [ n1, n2 ] ""))
        , check "no options are no rows" [] (rowList (rowsOf [] ""))
        , check "a group has a heading and its options after it" [ Heading "A", Item 1 a1 ] (rowList (rowsOf [ a1 ] ""))
        , check "groups are in the order they first appear" [ Heading "A", Item 1 a1, Item 2 a2, Heading "B", Item 3 b1 ] (rowList (rowsOf [ a1, b1, a2 ] ""))
        , check "and the options of a group are in their order" [ Heading "B", Item 1 b1, Heading "A", Item 2 a2, Item 3 a1 ] (rowList (rowsOf [ b1, a2, a1 ] ""))
        , check "options without a group come first" [ Item 1 n1, Item 2 n2, Heading "A", Item 3 a1, Heading "B", Item 4 b1 ] (rowList (rowsOf [ a1, n1, b1, n2 ] ""))
        , check "the suppliers"
            [ Item 1 globex, Item 2 initech, Item 3 soylent, Heading "Preferred", Item 4 acme, Item 5 umbrella, Heading "Other", Item 6 hooli ]
            (rowList (rowsOf suppliers ""))
        , check "an empty group name is no group" [ Item 1 n1, Item 2 unnamed ] (rowList (rowsOf [ n1, unnamed ] ""))
        , check "and the list is not grouped" False (rowsOf [ n1, unnamed ] "").grouped
        , check "an option with an empty group name is in with the options without a group, in the order of the list"
            [ Item 1 unnamed, Item 2 n1, Heading "A", Item 3 a1 ]
            (rowList (rowsOf [ unnamed, a1, n1 ] ""))
        , check "the matches of a search are grouped in the same way"
            [ Heading "A", Item 1 a1, Item 2 a2 ]
            (rowList (rowsOf [ n1, a1, b1, a2 ] "a"))
        , check "the group of the best match comes first"
            [ Heading "B", Item 1 (Option.withGroup "B" (Option.option "b2" "Bank")), Heading "A", Item 2 (Option.withGroup "A" (Option.option "a3" "Cashbank")) ]
            (rowList (rowsOf [ Option.withGroup "A" (Option.option "a3" "Cashbank"), Option.withGroup "B" (Option.option "b2" "Bank") ] "bank"))
        , check "the options without a group come before every group, even before the group of the best match"
            [ Item 1 (Option.option "n3" "Cashbank"), Heading "B", Item 2 (Option.withGroup "B" (Option.option "b2" "Bank")) ]
            (rowList (rowsOf [ Option.withGroup "B" (Option.option "b2" "Bank"), Option.option "n3" "Cashbank" ] "bank"))
        ]


{-| The rows of a list of options and a query: filtered where the user types,
without a "create" row.
-}
rowsOf : List (Option String) -> String -> Popup.Rows String
rowsOf options query =
    (Popup.build Nothing { options = options, filterLocally = True, creatable = False } query).rows


creatableRows : List (Option String) -> String -> Popup.Rows String
creatableRows options query =
    (Popup.build Nothing { options = options, filterLocally = True, creatable = True } query).rows


rowList : Popup.Rows String -> List (Row String)
rowList rows =
    Array.toList rows.rows


rowTests : Test
rowTests =
    describe "build"
        [ describe "without a query"
            [ check "the suppliers in groups, the ones without a group first, numbered from 1 without the headings"
                [ Item 1 globex, Item 2 initech, Item 3 soylent, Heading "Preferred", Item 4 acme, Item 5 umbrella, Heading "Other", Item 6 hooli ]
                (rowList (rowsOf suppliers ""))
            , check "all of them are matches"
                ( 6, 6, 6 )
                (let
                    r =
                        rowsOf suppliers ""
                 in
                 ( r.matchCount, r.total, r.optionRows )
                )
            , check "the matches are in the order of the rows" [ "globex", "initech", "soylent", "acme", "umbrella", "hooli" ] (values (rowsOf suppliers "").matched)
            , check "the list has groups" True (rowsOf suppliers "").grouped
            , check "options without groups are rows in the order of the list" [ Item 1 globex, Item 2 initech ] (rowList (rowsOf [ globex, initech ] ""))
            , check "and are not grouped" False (rowsOf [ globex, initech ] "").grouped
            , check "no options are no rows" [] (rowList (rowsOf [] ""))
            , check "and no matches"
                ( 0, 0, 0 )
                (let
                    r =
                        rowsOf [] ""
                 in
                 ( r.matchCount, r.total, r.optionRows )
                )
            , check "a blank query is no query" (rowList (rowsOf suppliers "")) (rowList (rowsOf suppliers "   "))
            , check "an index is not built without a query" Nothing (Popup.build Nothing { options = suppliers, filterLocally = True, creatable = False } "").index
            ]
        , describe "with a query"
            [ check "the options that match, the ones without a group first, then each group with its heading"
                [ Item 1 globex, Item 2 soylent, Heading "Preferred", Item 3 acme, Item 4 umbrella ]
                (rowList (rowsOf suppliers "a"))
            , check "the matches and all the options are counted"
                ( 4, 6, 4 )
                (let
                    r =
                        rowsOf suppliers "a"
                 in
                 ( r.matchCount, r.total, r.optionRows )
                )
            , check "the matches are in the order of the rows" [ "globex", "soylent", "acme", "umbrella" ] (values (rowsOf suppliers "a").matched)
            , check "a group with no match has no heading" [ Item 1 soylent, Heading "Preferred", Item 2 acme ] (rowList (rowsOf suppliers "berlin"))
            , check "nothing matches" [] (rowList (rowsOf suppliers "xyz"))
            , check "and the counts say so"
                ( 0, 6, 0 )
                (let
                    r =
                        rowsOf suppliers "xyz"
                 in
                 ( r.matchCount, r.total, r.optionRows )
                )
            , check "a query that is spaces around words" (rowList (rowsOf suppliers "hool")) (rowList (rowsOf suppliers "  hool  "))
            , check "without groups the matches are in the order of the ranking"
                [ Item 1 { umbrella | group = Nothing }, Item 2 { acme | group = Nothing } ]
                (rowList (rowsOf [ { acme | group = Nothing }, { umbrella | group = Nothing } ] "u"))
            , check "an index is built for a query, from all the options" (Just (Match.index suppliers)) (Popup.build Nothing { options = suppliers, filterLocally = True, creatable = False } "a").index
            , check "and an index that is given is kept, with or without a query"
                (Just [])
                (Popup.build (Just []) { options = suppliers, filterLocally = True, creatable = False } "").index
            ]
        , describe "when the server has done the searching"
            [ check "the options are shown as they come, whatever the query"
                (rowList (rowsOf suppliers ""))
                (rowList (Popup.build Nothing { options = suppliers, filterLocally = False, creatable = False } "xyz").rows)
            , check "and are all matches"
                ( 6, 6 )
                (let
                    r =
                        (Popup.build Nothing { options = suppliers, filterLocally = False, creatable = False } "xyz").rows
                 in
                 ( r.matchCount, r.total )
                )
            , check "no index is built" Nothing (Popup.build Nothing { options = suppliers, filterLocally = False, creatable = False } "xyz").index
            ]
        , describe "the create row"
            [ check "is first, with the text of the query, and the options are numbered from 2"
                [ Create 1 "hool", Heading "Other", Item 2 hooli ]
                (rowList (creatableRows suppliers "hool"))
            , check "the text is the query without the spaces around it"
                [ Create 1 "hool", Heading "Other", Item 2 hooli ]
                (rowList (creatableRows suppliers "  hool "))
            , check "is counted as a row of options, but not as a match"
                ( 1, 6, 2 )
                (let
                    r =
                        creatableRows suppliers "hool"
                 in
                 ( r.matchCount, r.total, r.optionRows )
                )
            , check "is not offered for an empty query" (rowList (rowsOf suppliers "")) (rowList (creatableRows suppliers ""))
            , check "nor for spaces" (rowList (rowsOf suppliers "")) (rowList (creatableRows suppliers "   "))
            , check "is not offered for the label of an option" [ Heading "Other", Item 1 hooli ] (rowList (creatableRows suppliers "Hooli"))
            , check "whatever the case" [ Heading "Other", Item 1 hooli ] (rowList (creatableRows suppliers "HOOLI"))
            , check "and the spaces around it" [ Heading "Other", Item 1 hooli ] (rowList (creatableRows suppliers "  hooli  "))
            , check "and the diacritics" [ Item 1 (labelled "Zürich") ] (rowList (creatableRows [ labelled "Zürich" ] "ZURICH"))
            , check "is offered when nothing matches" [ Create 1 "xyz" ] (rowList (creatableRows suppliers "xyz"))
            , check "is the only row when there are no options" [ Create 1 "x" ] (rowList (creatableRows [] "x"))
            , check "and then the options are one row"
                ( 0, 0, 1 )
                (let
                    r =
                        creatableRows [] "x"
                 in
                 ( r.matchCount, r.total, r.optionRows )
                )
            , check "is offered for the start of a label" [ Create 1 "Acme", Heading "Preferred", Item 2 acme ] (rowList (creatableRows [ acme ] "Acme"))
            , check "is not offered for a label with other words" [ Create 1 "Acme Suppl", Heading "Preferred", Item 2 acme ] (rowList (creatableRows [ acme ] "Acme Suppl"))
            , check "when the server searches, an exact match among the options is no reason for a new one"
                [ Heading "Other", Item 1 hooli ]
                (rowList (Popup.build Nothing { options = [ hooli ], filterLocally = False, creatable = True } "hooli").rows)
            , check "and another text is"
                [ Create 1 "hool", Heading "Other", Item 2 hooli ]
                (rowList (Popup.build Nothing { options = [ hooli ], filterLocally = False, creatable = True } "hool").rows)
            ]
        , describe "finding rows"
            [ check "an option by value" (Just globex) (Popup.findByValue "globex" suppliers)
            , check "the first of options with the same value" (Just { hooli | label = "First" }) (Popup.findByValue "hooli" [ { hooli | label = "First" }, hooli ])
            , check "no such value" Nothing (Popup.findByValue "nobody" suppliers)
            , check "no options" Nothing (Popup.findByValue "globex" [])
            , check "the row of an option, headings and all" (Just 4) (Popup.indexOfValue "acme" (rowsOf suppliers ""))
            , check "the first row" (Just 0) (Popup.indexOfValue "globex" (rowsOf suppliers ""))
            , check "a value that is filtered away" Nothing (Popup.indexOfValue "acme" (rowsOf suppliers "hool"))
            , check "the create row is no option" Nothing (Popup.indexOfValue "hool" (creatableRows suppliers "hool"))
            , check "a row by its place" (Just (Item 1 globex)) (Popup.rowAt 0 (rowsOf suppliers ""))
            , check "a heading is a row" (Just (Heading "Preferred")) (Popup.rowAt 3 (rowsOf suppliers ""))
            , check "past the end" Nothing (Popup.rowAt 8 (rowsOf suppliers ""))
            , check "before the start" Nothing (Popup.rowAt -1 (rowsOf suppliers ""))
            , check "isJust" [ True, False ] [ Popup.isJust (Just ()), Popup.isJust Nothing ]
            , check "the id of an option row" "supplier-opt-3" (Popup.optionId "supplier" 3)
            ]
        ]


cacheTests : Test
cacheTests =
    let
        env =
            { options = suppliers, filterLocally = True, creatable = False }

        cache =
            Popup.refresh Nothing env "berlin"
    in
    describe "refresh and cachedRows"
        [ check "refresh remembers the env, the query and the rows"
            ( env, "berlin", rowsOf suppliers "berlin" )
            ( cache.env, cache.query, cache.rows )
        , check "and the index it searched with" (Just (Match.index suppliers)) cache.index
        , check "the rows are those of the cache when the query and the options are the same"
            (rowsOf suppliers "berlin")
            (Popup.cachedRows (Just cache) env "berlin")
        , check "and they come from the cache, not from a new search"
            (rowsOf [] "")
            (Popup.cachedRows (Just { cache | rows = rowsOf [] "" }) env "berlin")
        , check "another query is searched for" (rowsOf suppliers "hool") (Popup.cachedRows (Just cache) env "hool")
        , check "other options are searched" (rowsOf [ globex ] "berlin") (Popup.cachedRows (Just cache) { env | options = [ globex ] } "berlin")
        , check "a list that is not searched locally any more is not filtered"
            (rowsOf suppliers "")
            (Popup.cachedRows (Just cache) { env | filterLocally = False } "berlin")
        , check "a list that can create is not the same list"
            (creatableRows suppliers "hool")
            (Popup.cachedRows (Just cache) { env | creatable = True } "hool")
        , check "no cache is a search" (rowsOf suppliers "berlin") (Popup.cachedRows Nothing env "berlin")
        , check "the search index is kept while the options are the same"
            (Just [])
            (Popup.refresh (Just { cache | index = Just [] }) env "hool").index
        , check "so a search with it finds what is in it"
            []
            (rowList (Popup.refresh (Just { cache | index = Just [] }) env "hool").rows)
        , check "the search index is made again when the options are not the same"
            (Just (Match.index [ globex ]))
            (Popup.refresh (Just cache) { env | options = [ globex ] } "glo").index
        , check "and the rows are those of the new options"
            [ Item 1 globex ]
            (rowList (Popup.refresh (Just cache) { env | options = [ globex ] } "glo").rows)
        , check "an index made for other options is not used, even when the query has not changed"
            [ Item 1 globex ]
            (rowList (Popup.refresh (Just (Popup.refresh Nothing env "glo")) { env | options = [ globex ] } "glo").rows)
        ]


{-| The rows of any list of options and any query, with and without a create
row.
-}
rowProperties : Test
rowProperties =
    describe "build: properties"
        [ fuzz2 queryFuzzer optionsFuzzer "the matches are those of filter, grouped" <|
            \query options ->
                let
                    rows =
                        rowsOf options query

                    found =
                        Match.filter query options
                in
                Expect.all
                    [ \r -> Expect.equal (List.sort (values found)) (List.sort (values r.matched))
                    , \r -> Expect.equal (List.length found) r.matchCount
                    , \r -> Expect.equal (List.length options) r.total
                    , \r -> Expect.equal r.matchCount r.optionRows
                    , \r ->
                        if r.grouped then
                            Expect.pass

                        else
                            Expect.equal (values found) (values r.matched)
                    ]
                    rows
        , fuzz2 queryFuzzer optionsFuzzer "the items are numbered from 1, one after the other, and the matches are the items" <|
            \query options ->
                let
                    rows =
                        rowsOf options query

                    items =
                        rowList rows |> List.filterMap itemPair
                in
                Expect.equal ( List.range 1 rows.matchCount, values rows.matched ) ( List.map Tuple.first items, List.map (Tuple.second >> .value) items )
        , fuzz2 queryFuzzer optionsFuzzer "a heading is followed by items of that group, and nothing without a group follows a heading" <|
            \query options ->
                let
                    step row ( current, ok ) =
                        case row of
                            Heading name ->
                                ( Just name, ok && current /= Just name )

                            Item _ opt ->
                                ( current, ok && Maybe.withDefault "" opt.group == Maybe.withDefault "" current )

                            Create _ _ ->
                                ( current, ok )
                in
                rowList (rowsOf options query)
                    |> List.foldl step ( Nothing, True )
                    |> Tuple.second
                    |> Expect.equal True
        , fuzz2 queryFuzzer optionsFuzzer "a heading is never the last row, and never follows another heading" <|
            \query options ->
                let
                    rows =
                        rowList (rowsOf options query)

                    isHeading row =
                        case row of
                            Heading _ ->
                                True

                            _ ->
                                False

                    pairs =
                        List.map2 Tuple.pair rows (List.drop 1 rows)
                in
                Expect.equal True
                    (List.all (\( a, b ) -> not (isHeading a && isHeading b)) pairs
                        && (List.reverse rows |> List.head |> Maybe.map (isHeading >> not) |> Maybe.withDefault True)
                    )
        , fuzz2 queryFuzzer optionsFuzzer "with a create row it is the first row, and the items are numbered from 2" <|
            \query options ->
                let
                    rows =
                        creatableRows options query

                    plain =
                        rowsOf options query
                in
                case rowList rows of
                    (Create 1 text) :: rest ->
                        Expect.all
                            [ \_ -> Expect.equal (String.trim query) text
                            , \_ -> Expect.equal (plain.matchCount + 1) rows.optionRows
                            , \_ -> Expect.equal (List.filterMap itemNumber rest) (List.range 2 (plain.matchCount + 1))
                            , \_ -> Expect.equal False (List.any (\opt -> Match.isExactMatch query opt) options)
                            , \_ -> Expect.equal False (String.isEmpty (String.trim query))
                            ]
                            ()

                    others ->
                        Expect.all
                            [ \_ -> Expect.equal (rowList plain) others
                            , \_ -> Expect.equal True (String.isEmpty (String.trim query) || List.any (\opt -> Match.isExactMatch query opt) options)
                            ]
                            ()
        ]


itemNumber : Row String -> Maybe Int
itemNumber row =
    case row of
        Item n _ ->
            Just n

        _ ->
            Nothing


itemPair : Row String -> Maybe ( Int, Option String )
itemPair row =
    case row of
        Item n opt ->
            Just ( n, opt )

        _ ->
            Nothing



-- NAVIGATION


navigationTests : Test
navigationTests =
    let
        -- 0 globex, 1 initech (disabled), 2 soylent, 3 heading, 4 acme, 5 umbrella, 6 heading, 7 hooli
        rows =
            rowsOf suppliers ""

        -- 0 heading, 1 acme, 2 umbrella, 3 heading, 4 hooli
        grouped =
            rowsOf [ acme, umbrella, hooli ] ""

        stuck =
            rowsOf [ initech ] ""

        empty =
            rowsOf [] ""

        createOnly =
            creatableRows [] "zzz"

        createAndItems =
            creatableRows suppliers "hool"
    in
    describe "moving through the rows"
        [ describe "the row that is highlighted first"
            [ check "is the first option that can be chosen" (Just 0) (Popup.initial rows)
            , check "skips the headings" (Just 1) (Popup.initial grouped)
            , check "skips options that are disabled" (Just 1) (Popup.initial (rowsOf [ initech, globex ] ""))
            , check "is nothing when no option can be chosen" Nothing (Popup.initial stuck)
            , check "and nothing when there are no rows" Nothing (Popup.initial empty)
            , check "is the create row when it is the only row" (Just 0) (Popup.initial createOnly)
            , check "is the create row when only disabled options match" (Just 0) (Popup.initial (creatableRows [ initech ] "ini"))
            , check "is an option, not the create row, when there are options" (Just 2) (Popup.initial createAndItems)
            ]
        , describe "first and last"
            [ check "first" (Just 0) (Popup.first rows)
            , check "last" (Just 7) (Popup.last rows)
            , check "first, after a heading" (Just 1) (Popup.first grouped)
            , check "last, an option" (Just 4) (Popup.last grouped)
            , check "first of nothing" Nothing (Popup.first stuck)
            , check "last of nothing" Nothing (Popup.last stuck)
            , check "first of no rows" Nothing (Popup.first empty)
            , check "last of no rows" Nothing (Popup.last empty)
            , check "the create row can be first" (Just 0) (Popup.first createAndItems)
            , check "and last" (Just 0) (Popup.last createOnly)
            ]
        , describe "next"
            [ check "skips an option that is disabled" 2 (Popup.next rows 0)
            , check "skips a heading" 4 (Popup.next rows 2)
            , check "goes on" 5 (Popup.next rows 4)
            , check "skips a heading again" 7 (Popup.next rows 5)
            , check "stays on the last option" 7 (Popup.next rows 7)
            , check "from a heading" 4 (Popup.next rows 3)
            , check "from an option that is disabled" 2 (Popup.next rows 1)
            , check "from the create row" 2 (Popup.next createAndItems 0)
            , check "past the end stays" 9 (Popup.next rows 9)
            , check "on nothing that can be chosen stays" 0 (Popup.next stuck 0)
            ]
        , describe "prev"
            [ check "skips a heading" 5 (Popup.prev rows 7)
            , check "goes on" 4 (Popup.prev rows 5)
            , check "skips a heading again" 2 (Popup.prev rows 4)
            , check "skips an option that is disabled" 0 (Popup.prev rows 2)
            , check "stays on the first option" 0 (Popup.prev rows 0)
            , check "from a heading" 2 (Popup.prev rows 3)
            , check "from an option that is disabled" 0 (Popup.prev rows 1)
            , check "stays on the first option when a heading is above it" 1 (Popup.prev grouped 1)
            , check "to the create row" 0 (Popup.prev createAndItems 2)
            , check "before the start stays" -3 (Popup.prev rows -3)
            ]
        , describe "pageDown"
            [ check "moves a page" 5 (Popup.pageDown 3 rows 2)
            , check "lands on the next option when it lands on a heading" 4 (Popup.pageDown 3 rows 0)
            , check "lands on the last option when it goes past the end" 7 (Popup.pageDown 100 rows 0)
            , check "from the last option it stays" 7 (Popup.pageDown 3 rows 7)
            , check "from before the last option" 7 (Popup.pageDown 3 rows 4)
            , check "of nothing" 0 (Popup.pageDown 3 stuck 0)
            , check "a page of nothing is the option itself" 4 (Popup.pageDown 0 rows 4)
            , check "when the end is an option that is disabled it lands on the option before" 1 (Popup.pageDown 100 (rowsOf [ globex, soylent, initech ] "") 0)
            ]
        , describe "pageUp"
            [ check "moves a page" 4 (Popup.pageUp 3 rows 7)
            , check "lands on the option before when it lands on a disabled option" 0 (Popup.pageUp 3 rows 4)
            , check "lands on the first option when it goes past the start" 0 (Popup.pageUp 100 rows 7)
            , check "from the first option it stays" 0 (Popup.pageUp 3 rows 0)
            , check "a page of nothing is the option itself" 5 (Popup.pageUp 0 rows 5)
            , check "when the start is a heading it lands on the first option" 1 (Popup.pageUp 100 grouped 4)
            , check "of nothing" 0 (Popup.pageUp 3 stuck 0)
            ]
        , describe "resolve makes a highlighted row valid"
            [ check "nothing is the first option" (Just 0) (Popup.resolve Nothing rows)
            , check "an option stays" (Just 2) (Popup.resolve (Just 2) rows)
            , check "an option that is disabled goes to the one before" (Just 0) (Popup.resolve (Just 1) rows)
            , check "a heading goes to the option before" (Just 2) (Popup.resolve (Just 3) rows)
            , check "another heading" (Just 5) (Popup.resolve (Just 6) rows)
            , check "past the end goes to the last option" (Just 7) (Popup.resolve (Just 8) rows)
            , check "far past the end" (Just 7) (Popup.resolve (Just 1000) rows)
            , check "before the start goes to the first option" (Just 0) (Popup.resolve (Just -1) rows)
            , check "a heading at the start goes to the option after" (Just 1) (Popup.resolve (Just 0) grouped)
            , check "nothing to choose is nothing" Nothing (Popup.resolve (Just 0) stuck)
            , check "no rows is nothing" Nothing (Popup.resolve (Just 0) empty)
            , check "and nothing is nothing" Nothing (Popup.resolve Nothing empty)
            ]
        ]


navigationProperties : Test
navigationProperties =
    let
        selectable rows index =
            case Popup.rowAt index rows of
                Just (Heading _) ->
                    False

                Just (Item _ opt) ->
                    not opt.disabled

                Just (Create _ _) ->
                    True

                Nothing ->
                    False

        selectableIndexes rows =
            List.filter (selectable rows) (List.range 0 (Array.length rows.rows - 1))

        -- every row of rows that can be chosen, from the first to the last, using next
        walkForward rows =
            case Popup.first rows of
                Nothing ->
                    []

                Just start ->
                    walk (Popup.next rows) start (Array.length rows.rows)

        walkBack rows =
            case Popup.last rows of
                Nothing ->
                    []

                Just start ->
                    walk (Popup.prev rows) start (Array.length rows.rows) |> List.reverse

        walk step start limit =
            if limit < 0 then
                [ start ]

            else
                let
                    following =
                        step start
                in
                if following == start then
                    [ start ]

                else
                    start :: walk step following (limit - 1)
    in
    describe "moving through the rows: properties"
        [ fuzz2 queryFuzzer optionsFuzzer "initial, first and last are rows that can be chosen, and are nothing exactly when there are none" <|
            \query options ->
                let
                    rows =
                        creatableRows options query

                    chosen =
                        selectableIndexes rows
                in
                Expect.all
                    [ \_ -> Expect.equal (List.head chosen) (Popup.first rows)
                    , \_ -> Expect.equal (List.reverse chosen |> List.head) (Popup.last rows)
                    , \_ -> Expect.equal (chosen == []) (Popup.initial rows == Nothing)
                    , \_ -> Expect.equal True (Maybe.withDefault True (Maybe.map (selectable rows) (Popup.initial rows)))
                    ]
                    ()
        , fuzz2 queryFuzzer optionsFuzzer "next goes through every row that can be chosen, in order, and prev back" <|
            \query options ->
                let
                    rows =
                        creatableRows options query
                in
                Expect.equal ( selectableIndexes rows, selectableIndexes rows ) ( walkForward rows, walkBack rows )
        , fuzz2 (Fuzz.intRange -3 14) optionsFuzzer "resolve gives a row that can be chosen, or nothing when there is none" <|
            \index options ->
                let
                    rows =
                        creatableRows options "q"

                    resolved =
                        Popup.resolve (Just index) rows
                in
                Expect.equal (selectableIndexes rows == []) (resolved == Nothing)
                    |> andAlso (Expect.equal True (Maybe.withDefault True (Maybe.map (selectable rows) resolved)))
        , fuzz2 (Fuzz.intRange 0 12) optionsFuzzer "a page down or up from a row that can be chosen lands on a row that can be chosen, in the right direction" <|
            \size options ->
                let
                    rows =
                        rowsOf options ""
                in
                selectableIndexes rows
                    |> List.all
                        (\index ->
                            let
                                down =
                                    Popup.pageDown size rows index

                                up =
                                    Popup.pageUp size rows index
                            in
                            selectable rows down && selectable rows up && down >= index && up <= index
                        )
                    |> Expect.equal True
        ]


andAlso : Expect.Expectation -> Expect.Expectation -> Expect.Expectation
andAlso second first =
    Expect.all [ \_ -> first, \_ -> second ] ()



-- KEYS ON AN OPEN LIST


actTests : Test
actTests =
    let
        rows =
            rowsOf suppliers ""

        act highlighted move =
            Popup.act 8 rows highlighted move
    in
    describe "act"
        [ check "next" (Just (Highlight 2)) (act (Just 0) MoveNext)
        , check "previous" (Just (Highlight 0)) (act (Just 2) MovePrevious)
        , check "first" (Just (Highlight 0)) (act (Just 7) MoveFirst)
        , check "last" (Just (Highlight 7)) (act (Just 0) MoveLast)
        , check "a page down is the visible rows less one" (Just (Highlight 7)) (act (Just 0) MovePageDown)
        , check "a page up too" (Just (Highlight 0)) (act (Just 7) MovePageUp)
        , check "a page of 3 rows when 4 can be seen" (Just (Highlight 4)) (Popup.act 4 rows (Just 0) MovePageDown)
        , check "a page is at least one row" (Just (Highlight 2)) (Popup.act 0 rows (Just 0) MovePageDown)
        , check "and a page of one visible row too" (Just (Highlight 2)) (Popup.act 1 rows (Just 0) MovePageDown)
        , check "choose" (Just (Choose (Item 3 soylent))) (act (Just 2) MoveChoose)
        , check "nothing highlighted is the first option" (Just (Highlight 2)) (act Nothing MoveNext)
        , check "and choosing it" (Just (Choose (Item 1 globex))) (act Nothing MoveChoose)
        , check "a highlighted row that is a heading is made valid first" (Just (Choose (Item 3 soylent))) (act (Just 3) MoveChoose)
        , check "and one that is disabled" (Just (Choose (Item 1 globex))) (act (Just 1) MoveChoose)
        , check "a row past the end is the last" (Just (Choose (Item 6 hooli))) (act (Just 20) MoveChoose)
        , check "choosing the create row" (Just (Choose (Create 1 "zzz"))) (Popup.act 8 (creatableRows [] "zzz") Nothing MoveChoose)
        , check "with no rows nothing happens" Nothing (Popup.act 8 (rowsOf [] "") (Just 0) MoveNext)
        , check "nor when no row can be chosen" Nothing (Popup.act 8 (rowsOf [ initech ] "") Nothing MoveChoose)
        , check "nor for choosing" Nothing (Popup.act 8 (rowsOf [] "") Nothing MoveChoose)
        ]



-- KEY BINDINGS


type Msg
    = Pressed String
    | Typed String
    | Moved Move
    | Backspaced
    | Closed
    | Left
    | Picked (Option String)
    | Created String
    | Hovered Int
    | Noop


type alias Key =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , shift : Bool
    , alt : Bool
    , repeat : Bool
    }


plainKey : String -> Key
plainKey key =
    { key = key, ctrl = False, meta = False, shift = False, alt = False, repeat = False }


keyJson : Key -> Encode.Value
keyJson k =
    Encode.object
        [ ( "key", Encode.string k.key )
        , ( "ctrlKey", Encode.bool k.ctrl )
        , ( "metaKey", Encode.bool k.meta )
        , ( "shiftKey", Encode.bool k.shift )
        , ( "altKey", Encode.bool k.alt )
        , ( "repeat", Encode.bool k.repeat )
        ]


{-| What the element does when the key goes down: the message, or nothing.
-}
pressed : Html.Attribute Msg -> Key -> Maybe Msg
pressed attribute k =
    Html.input [ attribute ] []
        |> Query.fromHtml
        |> Event.simulate (Event.custom "keydown" (keyJson k))
        |> Event.toResult
        |> Result.toMaybe


pressedWithout : Html.Attribute Msg -> Encode.Value -> Maybe Msg
pressedWithout attribute json =
    Html.input [ attribute ] []
        |> Query.fromHtml
        |> Event.simulate (Event.custom "keydown" json)
        |> Event.toResult
        |> Result.toMaybe


keydownTests : Test
keydownTests =
    let
        bindings =
            Popup.onKeydown
                { handled =
                    [ ( "ArrowDown", Pressed "down" )
                    , ( "Escape", Pressed "escape" )
                    , ( "Shift+Tab", Pressed "back" )
                    , ( "Ctrl+Enter", Pressed "submit" )
                    , ( "Ctrl+Meta+Alt+Shift+Home", Pressed "all" )
                    , ( "Backspace", Pressed "backspace" )
                    , ( "Enter", Pressed "handled enter" )
                    ]
                , passive =
                    [ ( "Tab", Pressed "tab" )
                    , ( "Enter", Pressed "passive enter" )
                    , ( "Delete", Pressed "delete" )
                    ]
                }
    in
    describe "onKeydown"
        [ check "a key that is bound" (Just (Pressed "down")) (pressed bindings (plainKey "ArrowDown"))
        , check "another" (Just (Pressed "escape")) (pressed bindings (plainKey "Escape"))
        , check "a key that is passive" (Just (Pressed "tab")) (pressed bindings (plainKey "Tab"))
        , check "and another" (Just (Pressed "delete")) (pressed bindings (plainKey "Delete"))
        , check "a key that is not bound" Nothing (pressed bindings (plainKey "x"))
        , check "a key with a modifier that is not bound" Nothing (pressed bindings { key = "ArrowDown", ctrl = True, meta = False, shift = False, alt = False, repeat = False })
        , check "shift is part of the name of keys that are not characters"
            (Just (Pressed "back"))
            (pressed bindings { key = "Tab", ctrl = False, meta = False, shift = True, alt = False, repeat = False })
        , check "and so is control"
            (Just (Pressed "submit"))
            (pressed bindings { key = "Enter", ctrl = True, meta = False, shift = False, alt = False, repeat = False })
        , check "the modifiers are in the order control, meta, alt, shift"
            (Just (Pressed "all"))
            (pressed bindings { key = "Home", ctrl = True, meta = True, shift = True, alt = True, repeat = False })
        , check "a key that is bound as handled wins over the same key bound as passive" (Just (Pressed "handled enter")) (pressed bindings (plainKey "Enter"))
        , check "a key held down is a key pressed again"
            (Just (Pressed "down"))
            (pressed bindings { key = "ArrowDown", ctrl = False, meta = False, shift = False, alt = False, repeat = True })
        , check "but not Backspace: holding it down does not go on"
            Nothing
            (pressed bindings { key = "Backspace", ctrl = False, meta = False, shift = False, alt = False, repeat = True })
        , check "Backspace pressed once" (Just (Pressed "backspace")) (pressed bindings (plainKey "Backspace"))
        , check "Backspace without a repeat field is a fresh press"
            (Just (Pressed "backspace"))
            (pressedWithout bindings (Encode.object [ ( "key", Encode.string "Backspace" ), ( "ctrlKey", Encode.bool False ), ( "metaKey", Encode.bool False ), ( "shiftKey", Encode.bool False ), ( "altKey", Encode.bool False ) ]))
        , check "an event without the fields of a key does nothing" Nothing (pressedWithout bindings (Encode.object [ ( "key", Encode.string "ArrowDown" ) ]))
        , check "an event that is not a key does nothing" Nothing (pressedWithout bindings (Encode.object []))
        , check "a repeated key can be bound by its name"
            (Just (Pressed "again"))
            (pressed
                (Popup.onKeydown { handled = [ ( "Repeat+Backspace", Pressed "again" ) ], passive = [] })
                { key = "Backspace", ctrl = False, meta = False, shift = False, alt = False, repeat = True }
            )
        , check "no bindings" Nothing (pressed (Popup.onKeydown { handled = [], passive = [] }) (plainKey "ArrowDown"))
        ]


triggerKeyTests : Test
triggerKeyTests =
    let
        bindings =
            Popup.onTriggerKeys
                [ ( "Enter", Pressed "open" )
                , ( "ArrowDown", Pressed "open" )
                , ( " ", Pressed "space" )
                , ( "Backspace", Pressed "clear" )
                ]
                (Just Typed)

        withoutTyping =
            Popup.onTriggerKeys [ ( "Enter", Pressed "open" ) ] Nothing
    in
    describe "onTriggerKeys"
        [ check "a bound key" (Just (Pressed "open")) (pressed bindings (plainKey "Enter"))
        , check "another" (Just (Pressed "open")) (pressed bindings (plainKey "ArrowDown"))
        , check "the space is bound and not typed" (Just (Pressed "space")) (pressed bindings (plainKey " "))
        , check "a character is typed" (Just (Typed "a")) (pressed bindings (plainKey "a"))
        , check "a capital too" (Just (Typed "A")) (pressed bindings { key = "A", ctrl = False, meta = False, shift = True, alt = False, repeat = False })
        , check "a digit" (Just (Typed "5")) (pressed bindings (plainKey "5"))
        , check "a letter that is not ASCII" (Just (Typed "ø")) (pressed bindings (plainKey "ø"))
        , check "a symbol" (Just (Typed "-")) (pressed bindings (plainKey "-"))
        , check "a key that is neither" Nothing (pressed bindings (plainKey "ArrowUp"))
        , check "Tab goes on" Nothing (pressed bindings (plainKey "Tab"))
        , check "so do the function keys" Nothing (pressed bindings (plainKey "F1"))
        , check "and Shift on its own" Nothing (pressed bindings (plainKey "Shift"))
        , check "control and a character is a shortcut, not a letter"
            Nothing
            (pressed bindings { key = "a", ctrl = True, meta = False, shift = False, alt = False, repeat = False })
        , check "meta and a character too"
            Nothing
            (pressed bindings { key = "a", ctrl = False, meta = True, shift = False, alt = False, repeat = False })
        , check "alt and a character too"
            Nothing
            (pressed bindings { key = "a", ctrl = False, meta = False, shift = False, alt = True, repeat = False })
        , check "Backspace held down is not repeated"
            Nothing
            (pressed bindings { key = "Backspace", ctrl = False, meta = False, shift = False, alt = False, repeat = True })
        , check "Backspace pressed once" (Just (Pressed "clear")) (pressed bindings (plainKey "Backspace"))
        , check "without a function for typing, a character does nothing" Nothing (pressed withoutTyping (plainKey "a"))
        , check "and the bound key still works" (Just (Pressed "open")) (pressed withoutTyping (plainKey "Enter"))
        , check "an event without the fields of a key does nothing" Nothing (pressedWithout bindings (Encode.object [ ( "key", Encode.string "a" ) ]))
        ]


windowKeyTests : Test
windowKeyTests =
    let
        bindings =
            Popup.onWindowKeys { typed = Typed, backspace = Backspaced, move = Moved, close = Closed, leave = Left }

        modified k =
            [ { k | ctrl = True }, { k | meta = True }, { k | alt = True } ]
    in
    describe "onWindowKeys"
        [ describe "keys that act on the list"
            [ check "Enter chooses" (Just (Moved MoveChoose)) (pressed bindings (plainKey "Enter"))
            , check "ArrowDown" (Just (Moved MoveNext)) (pressed bindings (plainKey "ArrowDown"))
            , check "ArrowUp" (Just (Moved MovePrevious)) (pressed bindings (plainKey "ArrowUp"))
            , check "PageDown" (Just (Moved MovePageDown)) (pressed bindings (plainKey "PageDown"))
            , check "PageUp" (Just (Moved MovePageUp)) (pressed bindings (plainKey "PageUp"))
            , check "Home" (Just (Moved MoveFirst)) (pressed bindings (plainKey "Home"))
            , check "End" (Just (Moved MoveLast)) (pressed bindings (plainKey "End"))
            , check "a key held down goes on" (Just (Moved MoveNext)) (pressed bindings { key = "ArrowDown", ctrl = False, meta = False, shift = False, alt = False, repeat = True })
            ]
        , describe "keys that close the list and go on"
            [ check "Escape closes" (Just Closed) (pressed bindings (plainKey "Escape"))
            , check "Tab leaves" (Just Left) (pressed bindings (plainKey "Tab"))
            , check "and Shift+Tab" (Just Left) (pressed bindings { key = "Tab", ctrl = False, meta = False, shift = True, alt = False, repeat = False })
            ]
        , describe "what is typed belongs to the search"
            [ check "a character" (Just (Typed "a")) (pressed bindings (plainKey "a"))
            , check "a space too" (Just (Typed " ")) (pressed bindings (plainKey " "))
            , check "a capital" (Just (Typed "A")) (pressed bindings { key = "A", ctrl = False, meta = False, shift = True, alt = False, repeat = False })
            , check "a letter that is not ASCII" (Just (Typed "å")) (pressed bindings (plainKey "å"))
            , check "a digit" (Just (Typed "7")) (pressed bindings (plainKey "7"))
            , check "Backspace edits" (Just Backspaced) (pressed bindings (plainKey "Backspace"))
            , check "but not when it is held down" Nothing (pressed bindings { key = "Backspace", ctrl = False, meta = False, shift = False, alt = False, repeat = True })
            , check "a character held down goes on" (Just (Typed "a")) (pressed bindings { key = "a", ctrl = False, meta = False, shift = False, alt = False, repeat = True })
            ]
        , describe "other keys are not for the list"
            [ check "F5" Nothing (pressed bindings (plainKey "F5"))
            , check "Shift" Nothing (pressed bindings (plainKey "Shift"))
            , check "Delete" Nothing (pressed bindings (plainKey "Delete"))
            , check "ArrowLeft" Nothing (pressed bindings (plainKey "ArrowLeft"))
            , check "an event that is not a key" Nothing (pressedWithout bindings (Encode.object []))
            ]
        , describe "a key with control, meta or alt is a shortcut of the browser"
            (List.concatMap
                (\name ->
                    List.map2
                        (\modifier k -> check (name ++ " with " ++ modifier) Nothing (pressed bindings k))
                        [ "control", "meta", "alt" ]
                        (modified (plainKey name))
                )
                [ "Tab", "Escape", "Enter", "ArrowDown", "a", "Backspace" ]
            )
        ]



-- TEXTS


textTests : Test
textTests =
    let
        en =
            Popup.texts Locale.en

        nb =
            Popup.texts Locale.nb
    in
    describe "the texts of the select family"
        [ describe "English"
            [ check "one option" "1 option" (en.options 1)
            , check "zero options" "0 options" (en.options 0)
            , check "options" "12 options" (en.options 12)
            , check "options with a thousands separator" "1,234 options" (en.options 1234)
            , check "one match" "1 match" (en.results 1)
            , check "matches" "2 matches" (en.results 2)
            , check "zero matches" "0 matches" (en.results 0)
            , check "how many of the options match" "3 of 12 matches" (en.matches 3 12)
            , check "with thousands separators" "1,200 of 3,000 matches" (en.matches 1200 3000)
            , check "selected" "4 selected" (en.selected 4)
            , check "selected, with a limit" "2 of max 5 selected" (en.selectedOfMax 2 5)
            , check "more" "+3" (en.more 3)
            , check "the label of more" "3 more selected" (en.moreLabel 3)
            , check "one suggestion" "1 suggestion" (en.suggestions 1)
            , check "suggestions" "5 suggestions" (en.suggestions 5)
            , check "create" "Create “Acme”" (en.create "Acme")
            , check "no options match" "No options match “xyz”." (en.noMatchesFor "xyz")
            , check "the placeholder" "Select ..." en.placeholder
            , check "the placeholder of the search" "Search ..." en.searchPlaceholder
            , check "no matches" "No matches" en.noMatches
            , check "no options" "No options" en.noOptions
            , check "no suggestions" "No suggestions" en.noSuggestions
            , check "loading" "Loading ..." en.loading
            , check "select all" "Select all" en.selectAll
            , check "clear all" "Clear all" en.clearAll
            ]
        , describe "Norwegian"
            [ check "one option" "1 alternativ" (nb.options 1)
            , check "no options" "0 alternativer" (nb.options 0)
            , check "options" "12 alternativer" (nb.options 12)
            , check "options with a thousands separator" "1\u{00A0}234 alternativer" (nb.options 1234)
            , check "matches" "2 treff" (nb.results 2)
            , check "one match" "1 treff" (nb.results 1)
            , check "how many of the options match" "3 av 12 treff" (nb.matches 3 12)
            , check "selected" "4 valgt" (nb.selected 4)
            , check "selected, with a limit" "2 av maks 5 valgt" (nb.selectedOfMax 2 5)
            , check "more" "+3" (nb.more 3)
            , check "the label of more" "3 til er valgt" (nb.moreLabel 3)
            , check "suggestions" "5 forslag" (nb.suggestions 5)
            , check "create" "Opprett «Acme»" (nb.create "Acme")
            , check "no options match" "Ingen alternativer passer til «xyz»." (nb.noMatchesFor "xyz")
            , check "the placeholder" "Velg ..." nb.placeholder
            , check "the placeholder of the search" "Søk ..." nb.searchPlaceholder
            , check "no matches" "Ingen treff" nb.noMatches
            , check "select all" "Velg alle" nb.selectAll
            ]
        , check "every text of the two languages is different"
            True
            (List.all identity
                [ en.placeholder /= nb.placeholder
                , en.searchLabel /= nb.searchLabel
                , en.noOptions /= nb.noOptions
                , en.typeToSearch /= nb.typeToSearch
                , en.loading /= nb.loading
                , en.unavailable /= nb.unavailable
                , en.clearSelection /= nb.clearSelection
                , en.clearQuery /= nb.clearQuery
                , en.selectAllFiltered /= nb.selectAllFiltered
                , en.clearAll /= nb.clearAll
                ]
            )
        ]


statusTests : Test
statusTests =
    let
        en =
            Popup.texts Locale.en
    in
    describe "statusText"
        [ check "a list that is searched locally and has no query says how many options" "6 options" (Popup.statusText en True "" (rowsOf suppliers ""))
        , check "and for spaces" "6 options" (Popup.statusText en True "   " (rowsOf suppliers "   "))
        , check "with a query it says how many of them match" "2 of 6 matches" (Popup.statusText en True "berlin" (rowsOf suppliers "berlin"))
        , check "none" "0 of 6 matches" (Popup.statusText en True "xyz" (rowsOf suppliers "xyz"))
        , check "a list that the server searches says how many results" "6 matches" (Popup.statusText en False "berlin" (rowsOf suppliers ""))
        , check "one result" "1 match" (Popup.statusText en False "x" (rowsOf [ globex ] ""))
        , check "in Norwegian" "2 av 6 treff" (Popup.statusText (Popup.texts Locale.nb) True "berlin" (rowsOf suppliers "berlin"))
        ]


geometryTests : Test
geometryTests =
    describe "geometry"
        [ check "a row is 32 pixels" 32 Popup.rowHeight
        , check "the height of the list is the visible rows" 256 (Popup.listHeight 8)
        , check "at least one row is visible" 32 (Popup.listHeight 0)
        , check "even for a negative number" 32 (Popup.listHeight -4)
        , check "a page is one less than the visible rows" 7 (Popup.pageSize 8)
        , check "but at least one" 1 (Popup.pageSize 1)
        , check "even for none" 1 (Popup.pageSize 0)
        , check "the geometry of the list of the suppliers" { rowHeight = 32, height = 256, count = 8, inset = 32 } (Popup.geometry 8 (rowsOf suppliers ""))
        , check "a list without groups has no inset" { rowHeight = 32, height = 160, count = 2, inset = 0 } (Popup.geometry 5 (rowsOf [ globex, initech ] ""))
        ]



-- THE VIEW OF A ROW


rowConfig : Popup.RowConfig String Msg
rowConfig =
    { idBase = "supplier"
    , query = ""
    , highlighted = Nothing
    , setSize = 6
    , indicator = Popup.CheckMark
    , isSelected = always False
    , isBlocked = always False
    , selectedFollowsHighlight = False
    , onPick = Picked
    , onCreate = Created
    , onHover = Hovered
    , noop = Noop
    , texts = Popup.texts Locale.en
    }


viewed : Popup.RowConfig String Msg -> Int -> Row String -> Query.Single Msg
viewed config index row =
    Popup.viewRow config index row |> Query.fromHtml


root : List Selector.Selector -> Query.Single msg -> Expect.Expectation
root selectors =
    Query.has selectors


rootLacks : List Selector.Selector -> Query.Single msg -> Expect.Expectation
rootLacks selectors =
    Query.hasNot selectors


mouseMove : ( String, Encode.Value )
mouseMove =
    Event.custom "mousemove" (Encode.object [])


viewRowTests : Test
viewRowTests =
    let
        item config opt =
            viewed config 3 (Item 4 opt)

        highlightedConfig =
            { rowConfig | highlighted = Just 3 }
    in
    describe "the view of a row"
        [ describe "an option"
            [ test "is an option of a listbox, with an id from the base and the place of the row" <|
                \_ ->
                    item rowConfig acme
                        |> root [ Selector.id "supplier-opt-3", Selector.attribute (Attr.attribute "role" "option"), Selector.class "klar-select__option" ]
            , test "says where it is in the set" <|
                \_ ->
                    item rowConfig acme
                        |> root [ Selector.attribute (Attr.attribute "aria-posinset" "4"), Selector.attribute (Attr.attribute "aria-setsize" "6") ]
            , test "shows the label and the description, and both in the tooltip" <|
                \_ ->
                    item rowConfig acme
                        |> Expect.all
                            [ root [ Selector.attribute (Attr.title "Acme Supplies – Berlin") ]
                            , Query.find [ Selector.class "klar-select__option-label" ] >> Query.has [ Selector.exactText "Acme Supplies" ]
                            , Query.find [ Selector.class "klar-select__option-description" ] >> Query.has [ Selector.exactText "Berlin" ]
                            ]
            , test "an option without a description has no description and the label as tooltip" <|
                \_ ->
                    item rowConfig globex
                        |> Expect.all
                            [ root [ Selector.attribute (Attr.title "Globex") ]
                            , Query.hasNot [ Selector.class "klar-select__option-description" ]
                            ]
            , test "is not selected, highlighted or disabled" <|
                \_ ->
                    item rowConfig acme
                        |> Expect.all
                            [ root [ Selector.attribute (Attr.attribute "aria-selected" "false") ]
                            , rootLacks [ Selector.class "klar-select__option--highlighted" ]
                            , rootLacks [ Selector.class "klar-select__option--selected" ]
                            , rootLacks [ Selector.class "klar-select__option--disabled" ]
                            , rootLacks [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                            ]
            , test "is highlighted when it is the highlighted row" <|
                \_ -> item highlightedConfig acme |> root [ Selector.class "klar-select__option--highlighted" ]
            , test "is not highlighted when another row is" <|
                \_ -> item { rowConfig | highlighted = Just 2 } acme |> rootLacks [ Selector.class "klar-select__option--highlighted" ]
            , test "is selected when the application says so" <|
                \_ ->
                    item { rowConfig | isSelected = \opt -> opt.value == "acme" } acme
                        |> Expect.all
                            [ root [ Selector.attribute (Attr.attribute "aria-selected" "true"), Selector.class "klar-select__option--selected" ]
                            , Query.find [ Selector.class "klar-select__check" ] >> Query.has [ Selector.class "klar-icon" ]
                            ]
            , test "shows no check mark when it is not selected" <|
                \_ -> item rowConfig acme |> Query.find [ Selector.class "klar-select__check" ] |> Query.hasNot [ Selector.class "klar-icon" ]
            , test "in a list where the selection follows the highlight, aria-selected is the highlight" <|
                \_ ->
                    Expect.all
                        [ \_ -> item { highlightedConfig | selectedFollowsHighlight = True } acme |> root [ Selector.attribute (Attr.attribute "aria-selected" "true") ]
                        , \_ -> item { rowConfig | selectedFollowsHighlight = True, isSelected = always True } acme |> root [ Selector.attribute (Attr.attribute "aria-selected" "false") ]
                        ]
                        ()
            , test "a checkbox as indicator is checked when the option is selected" <|
                \_ ->
                    item { rowConfig | indicator = Popup.CheckBox, isSelected = always True } acme
                        |> Query.find [ Selector.tag "input" ]
                        |> Query.has [ Selector.checked True ]
            , test "and not checked when it is not" <|
                \_ ->
                    item { rowConfig | indicator = Popup.CheckBox } acme
                        |> Query.find [ Selector.tag "input" ]
                        |> Query.has [ Selector.checked False ]
            , test "no indicator draws nothing before the label" <|
                \_ ->
                    item { rowConfig | indicator = Popup.NoIndicator } acme
                        |> Expect.all [ Query.hasNot [ Selector.class "klar-select__check" ], Query.hasNot [ Selector.class "klar-select__checkbox" ] ]
            , test "an icon is drawn before the label" <|
                \_ -> item rowConfig (Option.withIcon Icon.tag acme) |> Query.has [ Selector.class "klar-select__option-icon" ]
            , test "a click chooses the option" <|
                \_ -> item rowConfig acme |> Event.simulate Event.click |> Event.expect (Picked acme)
            , test "the mouse over it highlights it" <|
                \_ -> item rowConfig acme |> Event.simulate mouseMove |> Event.expect (Hovered 3)
            , test "but not again when it is highlighted already" <|
                \_ -> item highlightedConfig acme |> Event.simulate mouseMove |> Event.toResult |> Result.toMaybe |> Expect.equal Nothing
            , test "a click on the row takes the focus from nothing: pressing the mouse down is stopped" <|
                \_ -> item rowConfig acme |> Event.simulate (Event.custom "mousedown" (Encode.object [])) |> Event.expect Noop
            ]
        , describe "an option that is disabled"
            [ test "is dimmed and announced as disabled" <|
                \_ ->
                    item rowConfig initech
                        |> root [ Selector.class "klar-select__option--disabled", Selector.attribute (Attr.attribute "aria-disabled" "true") ]
            , test "a click does nothing" <|
                \_ -> item rowConfig initech |> Event.simulate Event.click |> Event.expect Noop
            , test "the mouse over it does not highlight it" <|
                \_ -> item rowConfig initech |> Event.simulate mouseMove |> Event.toResult |> Result.toMaybe |> Expect.equal Nothing
            ]
        , describe "an option that is blocked, as when the most that can be chosen is chosen"
            [ test "is disabled like one that is disabled" <|
                \_ ->
                    item { rowConfig | isBlocked = always True } acme
                        |> Expect.all
                            [ root [ Selector.class "klar-select__option--disabled", Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                            , Event.simulate Event.click >> Event.expect Noop
                            ]
            , test "unless it is selected, so that it can be taken away" <|
                \_ ->
                    item { rowConfig | isBlocked = always True, isSelected = always True } acme
                        |> Expect.all
                            [ rootLacks [ Selector.class "klar-select__option--disabled" ]
                            , Event.simulate Event.click >> Event.expect (Picked acme)
                            ]
            ]
        , describe "what the query matched is marked"
            [ test "in the label" <|
                \_ ->
                    item { rowConfig | query = "acm" } acme
                        |> Query.find [ Selector.class "klar-select__option-label", Selector.tag "mark" ]
                        |> Query.has [ Selector.exactText "Acm" ]
            , test "in the description when the label does not explain the match" <|
                \_ ->
                    item { rowConfig | query = "berlin" } acme
                        |> Query.find [ Selector.class "klar-select__option-description", Selector.tag "mark" ]
                        |> Query.has [ Selector.exactText "Berlin" ]
            , test "but not in the description when the label explains it" <|
                \_ ->
                    item { rowConfig | query = "acme" } (Option.withDescription "Acme town" acme)
                        |> Query.find [ Selector.class "klar-select__option-description" ]
                        |> Query.hasNot [ Selector.tag "mark" ]
            , test "nothing is marked without a query" <|
                \_ -> item rowConfig acme |> Query.hasNot [ Selector.tag "mark" ]
            ]
        , describe "the create row"
            [ test "is an option with the text to create" <|
                \_ ->
                    viewed rowConfig 0 (Create 1 "Hool")
                        |> Expect.all
                            [ root [ Selector.id "supplier-opt-0", Selector.class "klar-select__option--create", Selector.attribute (Attr.attribute "role" "option") ]
                            , Query.find [ Selector.class "klar-select__option-label" ] >> Query.has [ Selector.exactText "Create “Hool”" ]
                            , root [ Selector.attribute (Attr.title "Create “Hool”") ]
                            , root [ Selector.attribute (Attr.attribute "aria-posinset" "1") ]
                            ]
            , test "is in Norwegian when the texts are" <|
                \_ ->
                    viewed { rowConfig | texts = Popup.texts Locale.nb } 0 (Create 1 "Hool")
                        |> Query.find [ Selector.class "klar-select__option-label" ]
                        |> Query.has [ Selector.exactText "Opprett «Hool»" ]
            , test "a click creates" <|
                \_ -> viewed rowConfig 0 (Create 1 "Hool") |> Event.simulate Event.click |> Event.expect (Created "Hool")
            , test "the mouse over it highlights it" <|
                \_ -> viewed rowConfig 0 (Create 1 "Hool") |> Event.simulate mouseMove |> Event.expect (Hovered 0)
            , test "it is highlighted when it is the highlighted row" <|
                \_ -> viewed { rowConfig | highlighted = Just 0 } 0 (Create 1 "Hool") |> root [ Selector.class "klar-select__option--highlighted" ]
            ]
        , describe "a heading"
            [ test "is a group label and not an option" <|
                \_ ->
                    viewed rowConfig 3 (Heading "Preferred")
                        |> Expect.all
                            [ root [ Selector.class "klar-select__group", Selector.attribute (Attr.attribute "role" "presentation") ]
                            , rootLacks [ Selector.attribute (Attr.attribute "role" "option") ]
                            , Query.find [ Selector.class "klar-select__group-label" ] >> Query.has [ Selector.exactText "Preferred" ]
                            ]
            , test "has the name as a tooltip" <|
                \_ -> viewed rowConfig 3 (Heading "Preferred") |> root [ Selector.attribute (Attr.title "Preferred") ]
            , check "only a heading can be pinned"
                [ True, False, False ]
                [ Popup.viewPinned (Heading "Preferred") /= Nothing
                , Popup.viewPinned (Item 1 acme) /= Nothing
                , Popup.viewPinned (Create 1 "x") /= Nothing
                ]
            ]
        ]
