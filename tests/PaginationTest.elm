module PaginationTest exposing (suite)

import Expect
import Fuzz
import Klar.Pagination as Pagination exposing (Item(..))
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Klar.Pagination (page arithmetic)"
        [ pageCountTests
        , rangeTests
        , pageItemTests
        , pageItemPropertyTests
        ]


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual



-- PAGE COUNT


pageCountTests : Test
pageCountTests =
    describe "pageCount"
        [ check "3 000 rows, 25 per page" 120 (Pagination.pageCount 25 3000)
        , check "no rows is still one page" 1 (Pagination.pageCount 25 0)
        , check "exactly one full page" 1 (Pagination.pageCount 25 25)
        , check "one row more than a page" 2 (Pagination.pageCount 25 26)
        , check "exactly two pages" 2 (Pagination.pageCount 25 50)
        , check "one row more than two pages" 3 (Pagination.pageCount 25 51)
        , check "one row" 1 (Pagination.pageCount 25 1)
        , check "one row per page" 5 (Pagination.pageCount 1 5)
        , check "a page size of 0 counts as 1" 10 (Pagination.pageCount 0 10)
        , check "a negative page size counts as 1" 10 (Pagination.pageCount -25 10)
        , check "a negative total counts as 0" 1 (Pagination.pageCount 25 -100)
        , check "a page larger than the total" 1 (Pagination.pageCount 100 7)
        , check "a total above 32 bits" 120000000 (Pagination.pageCount 25 3000000000)
        , check "a very large page size" 1 (Pagination.pageCount 2000000000 1000)
        , -- Was a bug: the number of pages went through Elm's `//`, which cuts the quotient
          -- to 32 bits, so more than 2 147 483 647 pages counted as one (here 3 000 000 000
          -- rows, one per page).
          check "more pages than fit in 32 bits" 3000000000 (Pagination.pageCount 1 3000000000)
        , fuzz2 (Fuzz.intRange 1 500) (Fuzz.intRange 0 100000) "pages are enough for all rows, and none is empty" <|
            \size total ->
                let
                    pages =
                        Pagination.pageCount size total
                in
                Expect.all
                    [ \p -> Expect.atLeast total (p * size)
                    , \p -> Expect.atMost (max 1 (total // size + 1)) p
                    , \p ->
                        if total > 0 then
                            Expect.atMost total ((p - 1) * size + 1)

                        else
                            Expect.equal 1 p
                    ]
                    pages
        , fuzz2 Fuzz.int Fuzz.int "never less than 1, whatever the numbers" <|
            \size total ->
                Expect.atLeast 1 (Pagination.pageCount size total)
        ]



-- RANGE


rangeTests : Test
rangeTests =
    let
        range page size total =
            Pagination.range { page = page, pageSize = size, total = total }
    in
    describe "range"
        [ check "the first page" ( 1, 25 ) (range 1 25 3000)
        , check "a middle page" ( 51, 75 ) (range 3 25 3000)
        , check "the last page" ( 2976, 3000 ) (range 120 25 3000)
        , check "a last page that is not full" ( 26, 30 ) (range 2 25 30)
        , check "a page past the last counts as the last" ( 26, 30 ) (range 99 25 30)
        , check "page 0 counts as the first" ( 1, 25 ) (range 0 25 30)
        , check "a negative page counts as the first" ( 1, 25 ) (range -4 25 30)
        , check "no rows" ( 0, 0 ) (range 1 25 0)
        , check "no rows, whatever the page" ( 0, 0 ) (range 7 25 0)
        , check "a negative total" ( 0, 0 ) (range 1 25 -3)
        , check "a page size of 0 counts as 1" ( 3, 3 ) (range 3 0 10)
        , check "a negative page size counts as 1" ( 3, 3 ) (range 3 -5 10)
        , check "a single row" ( 1, 1 ) (range 1 25 1)
        , check "a page that fits the total exactly" ( 1, 25 ) (range 1 25 25)
        , check "a total above 32 bits" ( 2999999976, 3000000000 ) (range 120000000 25 3000000000)
        , fuzz3 (Fuzz.intRange -5 400) (Fuzz.intRange -5 120) (Fuzz.intRange -5 5000) "first and last are inside the rows, and at most a page apart" <|
            \page size total ->
                let
                    ( first, last ) =
                        range page size total
                in
                if total <= 0 then
                    Expect.equal ( 0, 0 ) ( first, last )

                else
                    Expect.all
                        [ \_ -> Expect.atLeast 1 first
                        , \_ -> Expect.atMost last first
                        , \_ -> Expect.atMost total last
                        , \_ -> Expect.atMost (max 1 size) (last - first + 1)
                        ]
                        ()
        , fuzz2 (Fuzz.intRange 1 100) (Fuzz.intRange 1 3000) "the pages follow each other without a gap and cover every row" <|
            \size total ->
                let
                    pages =
                        List.range 1 (Pagination.pageCount size total)
                            |> List.map (\page -> range page size total)

                    gapless =
                        List.map2 (\( _, last ) ( first, _ ) -> first == last + 1) pages (List.drop 1 pages)
                in
                Expect.all
                    [ \_ -> Expect.equal (Just 1) (List.head pages |> Maybe.map Tuple.first)
                    , \_ -> Expect.equal (Just total) (List.reverse pages |> List.head |> Maybe.map Tuple.second)
                    , \_ -> Expect.equal True (List.all identity gapless)
                    ]
                    ()
        ]



-- PAGE ITEMS


slot : Item -> String
slot item =
    case item of
        Page n ->
            String.fromInt n

        Ellipsis ->
            "…"


slots : { siblings : Int, page : Int, pageCount : Int } -> List String
slots options =
    List.map slot (Pagination.pageItems options)


pageItemTests : Test
pageItemTests =
    describe "pageItems"
        [ check "the documented middle" [ "1", "…", "5", "6", "7", "…", "120" ] (slots { siblings = 1, page = 6, pageCount = 120 })
        , check "the documented start" [ "1", "2", "3", "4", "5", "…", "120" ] (slots { siblings = 1, page = 1, pageCount = 120 })
        , check "the end" [ "1", "…", "116", "117", "118", "119", "120" ] (slots { siblings = 1, page = 120, pageCount = 120 })
        , check "the last but one" [ "1", "…", "116", "117", "118", "119", "120" ] (slots { siblings = 1, page = 119, pageCount = 120 })
        , check "page 4 is the last one to show 1 to 5" [ "1", "2", "3", "4", "5", "…", "120" ] (slots { siblings = 1, page = 4, pageCount = 120 })
        , check "page 5 starts the ellipsis" [ "1", "…", "4", "5", "6", "…", "120" ] (slots { siblings = 1, page = 5, pageCount = 120 })
        , check "in the middle of many pages" [ "1", "…", "59", "60", "61", "…", "120" ] (slots { siblings = 1, page = 60, pageCount = 120 })
        , check "one page" [ "1" ] (slots { siblings = 1, page = 1, pageCount = 1 })
        , check "two pages" [ "1", "2" ] (slots { siblings = 1, page = 2, pageCount = 2 })
        , check "three pages" [ "1", "2", "3" ] (slots { siblings = 1, page = 2, pageCount = 3 })
        , check "five pages show no ellipsis" [ "1", "2", "3", "4", "5" ] (slots { siblings = 1, page = 3, pageCount = 5 })
        , check "seven pages are all shown" [ "1", "2", "3", "4", "5", "6", "7" ] (slots { siblings = 1, page = 4, pageCount = 7 })
        , check "eight pages need an ellipsis" [ "1", "2", "3", "4", "5", "…", "8" ] (slots { siblings = 1, page = 1, pageCount = 8 })
        , check "eight pages, from the other end" [ "1", "…", "4", "5", "6", "7", "8" ] (slots { siblings = 1, page = 8, pageCount = 8 })
        , check "no sibling shows only the current page" [ "1", "…", "5", "…", "10" ] (slots { siblings = 0, page = 5, pageCount = 10 })
        , check "no sibling at the start" [ "1", "2", "3", "…", "10" ] (slots { siblings = 0, page = 1, pageCount = 10 })
        , check "two siblings" [ "1", "…", "8", "9", "10", "11", "12", "…", "50" ] (slots { siblings = 2, page = 10, pageCount = 50 })
        , check "two siblings at the start" [ "1", "2", "3", "4", "5", "6", "7", "…", "50" ] (slots { siblings = 2, page = 1, pageCount = 50 })
        , check "three siblings" [ "1", "…", "7", "8", "9", "10", "11", "12", "13", "…", "30" ] (slots { siblings = 3, page = 10, pageCount = 30 })
        , check "page 0 counts as the first page" (slots { siblings = 1, page = 1, pageCount = 20 }) (slots { siblings = 1, page = 0, pageCount = 20 })
        , check "a negative page counts as the first page" (slots { siblings = 1, page = 1, pageCount = 20 }) (slots { siblings = 1, page = -9, pageCount = 20 })
        , check "a page past the end counts as the last" (slots { siblings = 1, page = 20, pageCount = 20 }) (slots { siblings = 1, page = 99, pageCount = 20 })
        , check "a negative number of siblings counts as none" (slots { siblings = 0, page = 5, pageCount = 10 }) (slots { siblings = -2, page = 5, pageCount = 10 })
        , check "no pages counts as one page" [ "1" ] (slots { siblings = 1, page = 1, pageCount = 0 })
        , check "negative pages count as one page" [ "1" ] (slots { siblings = 1, page = 3, pageCount = -4 })
        , check "the number of slots does not change while paging through 120 pages"
            (List.repeat 7 7)
            ([ 1, 6, 60, 120, 3, 117, 119 ] |> List.map (\page -> List.length (slots { siblings = 1, page = page, pageCount = 120 })))
        , check "huge page counts work" [ "1", "…", "999999999", "1000000000", "1000000001", "…", "2000000000" ] (slots { siblings = 1, page = 1000000000, pageCount = 2000000000 })
        ]


{-| Every page count from 1 to `maxCount`, every number of siblings from 0 to 3,
and every page from before the first to after the last.
-}
everyCase : Int -> List { siblings : Int, page : Int, pageCount : Int }
everyCase maxCount =
    List.concatMap
        (\count ->
            List.concatMap
                (\siblings ->
                    List.map (\page -> { siblings = siblings, page = page, pageCount = count })
                        (List.range -1 (count + 2))
                )
                (List.range 0 3)
        )
        (List.range 1 maxCount)


clampPage : { a | page : Int, pageCount : Int } -> Int
clampPage options =
    clamp 1 options.pageCount options.page


forEveryCase : String -> ({ siblings : Int, page : Int, pageCount : Int } -> Bool) -> Test
forEveryCase name holds =
    test name <|
        \_ ->
            everyCase 45
                |> List.filter (\options -> not (holds options))
                |> List.take 3
                |> Expect.equal []


pageItemPropertyTests : Test
pageItemPropertyTests =
    let
        pageNumbers options =
            Pagination.pageItems options
                |> List.filterMap
                    (\item ->
                        case item of
                            Page n ->
                                Just n

                            Ellipsis ->
                                Nothing
                    )

        isEllipsis item =
            item == Ellipsis
    in
    describe "pageItems, for every page count up to 45, 0 to 3 siblings and every page"
        [ forEveryCase "starts with the first page" <|
            \options -> List.head (Pagination.pageItems options) == Just (Page 1)
        , forEveryCase "ends with the last page" <|
            \options -> List.head (List.reverse (Pagination.pageItems options)) == Just (Page options.pageCount)
        , forEveryCase "shows the current page" <|
            \options -> List.member (clampPage options) (pageNumbers options)
        , forEveryCase "lists pages in strictly rising order" <|
            \options ->
                let
                    pages =
                        pageNumbers options
                in
                List.map2 (<) pages (List.drop 1 pages) |> List.all identity
        , forEveryCase "shows only pages that exist" <|
            \options -> List.all (\n -> n >= 1 && n <= options.pageCount) (pageNumbers options)
        , forEveryCase "never puts two ellipses next to each other" <|
            \options ->
                let
                    items =
                        Pagination.pageItems options
                in
                List.map2 (\a b -> isEllipsis a && isEllipsis b) items (List.drop 1 items) |> List.any identity |> not
        , forEveryCase "has an ellipsis only between two pages that have at least two pages between them" <|
            \options ->
                let
                    items =
                        Pagination.pageItems options

                    triples =
                        List.map3 (\before item after -> ( before, item, after )) items (List.drop 1 items) (List.drop 2 items)
                in
                triples
                    |> List.all
                        (\( before, item, after ) ->
                            case ( before, item, after ) of
                                ( Page a, Ellipsis, Page b ) ->
                                    b - a >= 3

                                ( _, Ellipsis, _ ) ->
                                    False

                                _ ->
                                    True
                        )
        , forEveryCase "has no ellipsis at either end" <|
            \options ->
                let
                    items =
                        Pagination.pageItems options
                in
                not (List.any isEllipsis (List.take 1 items ++ List.drop (List.length items - 1) items))
        , forEveryCase "hides a page only behind an ellipsis" <|
            \options ->
                let
                    items =
                        Pagination.pageItems options

                    gapsBetweenPages =
                        List.map2
                            (\a b ->
                                case ( a, b ) of
                                    ( Page x, Page y ) ->
                                        y == x + 1

                                    _ ->
                                        True
                            )
                            items
                            (List.drop 1 items)
                in
                List.all identity gapsBetweenPages
        , forEveryCase "always has the same number of slots once there are enough pages" <|
            \options ->
                let
                    full =
                        2 * options.siblings + 5
                in
                if options.pageCount >= full then
                    List.length (Pagination.pageItems options) == full

                else
                    List.length (Pagination.pageItems options) == options.pageCount
        , fuzz3 (Fuzz.intRange -3 6) (Fuzz.intRange -50 200) (Fuzz.intRange -5 150) "never fails and always shows at least the first page" <|
            \siblings page count ->
                Pagination.pageItems { siblings = siblings, page = page, pageCount = count }
                    |> List.head
                    |> Expect.equal (Just (Page 1))
        , fuzz2 (Fuzz.intRange 1 200) (Fuzz.intRange 0 3) "the first two slots of the first page are pages" <|
            \count siblings ->
                Pagination.pageItems { siblings = siblings, page = 1, pageCount = count }
                    |> List.take 2
                    |> List.any isEllipsis
                    |> Expect.equal False
        ]
