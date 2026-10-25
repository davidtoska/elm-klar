module DiffTest exposing (suite)

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Diff as Diff
import Klar.Locale as Locale
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Diff"
        [ makingTextDiffs
        , makingFieldDiffs
        , makingJsonDiffs
        , hunkTests
        , textViewTests
        , interactionTests
        , entryViewTests
        , staticViewTests
        , localeTests
        ]



-- SAMPLES


oldPolicy : String
oldPolicy =
    "Orders over $50 ship free.\nReturns within 30 days.\nContact support for help.\n"


newPolicy : String
newPolicy =
    "Orders over $75 ship free.\nReturns within 30 days.\nContact support for help.\nHolidays may delay delivery.\n"


numbered : (Int -> String) -> Int -> String
numbered text count =
    List.range 1 count |> List.map text |> String.join "\n"


{-| 40 lines with line 20 changed.
-}
longOld : String
longOld =
    numbered (\i -> "line " ++ String.fromInt i) 40


longNew : String
longNew =
    numbered
        (\i ->
            if i == 20 then
                "line twenty"

            else
                "line " ++ String.fromInt i
        )
        40


{-| 600 lines of which every other line changed: 300 changes.
-}
manyOld : String
manyOld =
    numbered (\i -> "row " ++ String.fromInt i) 600


manyNew : String
manyNew =
    numbered
        (\i ->
            if modBy 2 i == 0 then
                "changed row " ++ String.fromInt i

            else
                "row " ++ String.fromInt i
        )
        600


type alias Model =
    { state : Diff.State
    , diff : Diff.Diff
    }


start : Diff.Diff -> Model
start diff =
    { state = Diff.init "diff", diff = diff }


viewOf : List (Diff.Attribute Diff.Msg) -> Model -> Html Diff.Msg
viewOf attributes model =
    Diff.view identity attributes model.state model.diff


query : List (Diff.Attribute Diff.Msg) -> Model -> Query.Single Diff.Msg
query attributes model =
    Query.fromHtml (viewOf attributes model)


{-| Presses the element and lets the viewer handle the message.
-}
press : List (Diff.Attribute Diff.Msg) -> List Selector -> Model -> Result String Model
press attributes selectors model =
    query attributes model
        |> Query.find selectors
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> { model | state = Tuple.first (Diff.update msg model.state) })


typeKey : List (Diff.Attribute Diff.Msg) -> String -> Model -> Result String Model
typeKey attributes key model =
    query attributes model
        |> Query.find [ Selector.class "klar-diff__scroll" ]
        |> Event.simulate
            (Event.custom "keydown"
                (Encode.object
                    [ ( "key", Encode.string key )
                    , ( "ctrlKey", Encode.bool False )
                    , ( "metaKey", Encode.bool False )
                    , ( "altKey", Encode.bool False )
                    , ( "shiftKey", Encode.bool False )
                    ]
                )
            )
        |> Event.toResult
        |> Result.map (\msg -> { model | state = Tuple.first (Diff.update msg model.state) })


button : String -> List Selector
button name =
    [ Selector.tag "button", Selector.containing [ Selector.text name ] ]


region : Selector
region =
    Selector.attribute (Attr.attribute "role" "region")



-- MAKING DIFFS


makingTextDiffs : Test
makingTextDiffs =
    describe "Diff.lines"
        [ test "equal texts are empty" <|
            \_ ->
                Diff.lines [] oldPolicy oldPolicy
                    |> Expect.all
                        [ \diff -> Expect.equal True (Diff.isEmpty diff)
                        , \diff -> Expect.equal { added = 0, removed = 0, changed = 0 } (Diff.stats diff)
                        , \diff -> Expect.equal [] (Diff.hunks diff)
                        , \diff -> Expect.equal False (Diff.tooLarge diff)
                        ]
        , test "two empty texts are empty" <|
            \_ -> Expect.equal True (Diff.isEmpty (Diff.lines [] "" ""))
        , test "the policy has a changed and an added line" <|
            \_ ->
                Diff.lines [] oldPolicy newPolicy
                    |> Expect.all
                        [ \diff -> Expect.equal False (Diff.isEmpty diff)
                        , \diff -> Expect.equal { added = 1, removed = 0, changed = 1 } (Diff.stats diff)
                        , \diff -> Expect.equal 2 (List.length (Diff.hunks diff))
                        ]
        , test "a removed line that is replaced counts as one changed line, not as an added and a removed" <|
            \_ -> Expect.equal { added = 0, removed = 0, changed = 1 } (Diff.stats (Diff.lines [] "a\nb\nc" "a\nB\nc"))
        , test "more removed than added lines" <|
            \_ -> Expect.equal { added = 0, removed = 2, changed = 1 } (Diff.stats (Diff.lines [] "a\nb\nc\nd" "a\nX"))
        , test "more added than removed lines" <|
            \_ -> Expect.equal { added = 2, removed = 0, changed = 1 } (Diff.stats (Diff.lines [] "a\nb" "a\nX\nY\nZ"))
        , test "white space can be ignored" <|
            \_ ->
                Expect.equal ( False, True )
                    ( Diff.isEmpty (Diff.lines [] "a  b\n" "a b\n")
                    , Diff.isEmpty (Diff.lines [ Diff.ignoreWhitespace ] "a  b\n" "a b\n")
                    )
        , test "case can be ignored" <|
            \_ ->
                Expect.equal ( False, True )
                    ( Diff.isEmpty (Diff.lines [] "Paid" "PAID")
                    , Diff.isEmpty (Diff.lines [ Diff.ignoreCase ] "Paid" "PAID")
                    )
        , test "the options can be given in any order" <|
            \_ ->
                Expect.equal
                    (Diff.lines [ Diff.ignoreCase, Diff.ignoreWhitespace ] "A  b\nc" "a b\nd")
                    (Diff.lines [ Diff.ignoreWhitespace, Diff.ignoreCase ] "A  b\nc" "a b\nd")
        , test "texts so different that the comparison would take too long become a summary" <|
            \_ ->
                let
                    old =
                        numbered (\i -> "old " ++ String.fromInt i) 3000

                    new =
                        numbered (\i -> "new " ++ String.fromInt i) 3000

                    diff =
                        Diff.lines [] old new
                in
                diff
                    |> Expect.all
                        [ \found -> Expect.equal True (Diff.tooLarge found)
                        , \found -> Expect.equal False (Diff.isEmpty found)
                        , \found -> Expect.equal [] (Diff.hunks found)
                        , \found -> Expect.equal { added = 3000, removed = 3000, changed = 0 } (Diff.stats found)
                        ]
        , test "5 000 lines with 300 changes are compared line by line" <|
            \_ ->
                let
                    old =
                        numbered (\i -> "line " ++ String.fromInt i ++ " of the stock list") 5000

                    new =
                        numbered
                            (\i ->
                                if modBy 16 i == 5 then
                                    "line " ++ String.fromInt i ++ " of the stock list, changed"

                                else
                                    "line " ++ String.fromInt i ++ " of the stock list"
                            )
                            5000

                    diff =
                        Diff.lines [] old new
                in
                diff
                    |> Expect.all
                        [ \found -> Expect.equal False (Diff.tooLarge found)
                        , \found -> Expect.equal 313 (List.length (Diff.hunks found))
                        , \found -> Expect.equal { added = 0, removed = 0, changed = 313 } (Diff.stats found)
                        ]
        ]


makingFieldDiffs : Test
makingFieldDiffs =
    let
        order =
            Diff.fields
                [ { label = "Status", before = Just "Open", after = Just "Shipped" }
                , { label = "Carrier", before = Nothing, after = Just "Nordic Freight" }
                , { label = "Coupon", before = Just "SPRING", after = Nothing }
                , { label = "Customer", before = Just "Northwind", after = Just "Northwind" }
                , { label = "Unused", before = Nothing, after = Nothing }
                ]
    in
    describe "Diff.fields"
        [ test "fields that did not change are not changes" <|
            \_ -> Expect.equal [ "Status", "Carrier", "Coupon" ] (List.map Diff.hunkKey (Diff.hunks order))
        , test "the counts" <|
            \_ -> Expect.equal { added = 1, removed = 1, changed = 1 } (Diff.stats order)
        , test "a record without changes is empty" <|
            \_ ->
                Diff.fields [ { label = "Customer", before = Just "Northwind", after = Just "Northwind" } ]
                    |> Diff.isEmpty
                    |> Expect.equal True
        , test "an empty text is a value, not a missing one" <|
            \_ ->
                Diff.fields [ { label = "Note", before = Nothing, after = Just "" } ]
                    |> Diff.stats
                    |> Expect.equal { added = 1, removed = 0, changed = 0 }
        , test "two fields with the same label have different keys" <|
            \_ ->
                Diff.fields
                    [ { label = "Phone", before = Just "1", after = Just "2" }
                    , { label = "Phone", before = Just "3", after = Just "4" }
                    ]
                    |> Diff.hunks
                    |> List.map Diff.hunkKey
                    |> Expect.equal [ "Phone", "Phone (2)" ]
        , test "no fields, no changes" <|
            \_ -> Expect.equal True (Diff.isEmpty (Diff.fields []))
        ]


makingJsonDiffs : Test
makingJsonDiffs =
    describe "Diff.json"
        [ test "the changes are found by path" <|
            \_ ->
                Diff.json []
                    (Encode.object [ ( "items", Encode.list identity [ Encode.object [ ( "price", Encode.float 12.5 ) ] ] ) ])
                    (Encode.object [ ( "items", Encode.list identity [ Encode.object [ ( "price", Encode.int 14 ) ] ] ) ])
                    |> Diff.hunks
                    |> List.map Diff.hunkKey
                    |> Expect.equal [ "items[0].price" ]
        , test "equal values are empty" <|
            \_ -> Expect.equal True (Diff.isEmpty (Diff.json [] (Encode.int 1) (Encode.int 1)))
        , test "the records of an array can be matched by a key" <|
            \_ ->
                let
                    line sku qty =
                        Encode.object [ ( "sku", Encode.string sku ), ( "qty", Encode.int qty ) ]
                in
                Diff.json [ Diff.matchBy "sku" ]
                    (Encode.list identity [ line "A" 1, line "B" 2 ])
                    (Encode.list identity [ line "B" 3, line "A" 1 ])
                    |> Diff.hunks
                    |> List.map Diff.hunkKey
                    |> Expect.equal [ "[sku=B].qty" ]
        ]



-- HUNKS


hunkTests : Test
hunkTests =
    let
        diff =
            Diff.lines [] "a\nb\nc\nd\ne\nf" "a\nB\nc\nd\nE\nF\nG"

        hunks =
            Diff.hunks diff
    in
    describe "hunks"
        [ test "a hunk has a key that says where it is" <|
            \_ -> Expect.equal [ "2:1/2:1", "5:2/5:3" ] (List.map Diff.hunkKey hunks)
        , test "the keys of the hunks of a diff are all different" <|
            \_ ->
                let
                    many =
                        Diff.hunks (Diff.lines [] manyOld manyNew) |> List.map Diff.hunkKey
                in
                Expect.equal (List.length many)
                    (List.length
                        (List.foldl
                            (\key found ->
                                if List.member key found then
                                    found

                                else
                                    key :: found
                            )
                            []
                            many
                        )
                    )
        , test "the text on each side" <|
            \_ ->
                Expect.equal
                    [ ( Just "b", Just "B" ), ( Just "e\nf", Just "E\nF\nG" ) ]
                    (List.map (\hunk -> ( Diff.hunkBefore hunk, Diff.hunkAfter hunk )) hunks)
        , test "an added hunk has no text before it, a removed one none after it" <|
            \_ ->
                Expect.equal
                    [ ( Nothing, Just "x" ), ( Just "y", Nothing ) ]
                    (List.map (\hunk -> ( Diff.hunkBefore hunk, Diff.hunkAfter hunk ))
                        (Diff.hunks (Diff.lines [] "a\nb\nc\nd\ne\ny\n" "a\nx\nb\nc\nd\ne\n"))
                    )
        , test "the same two texts give equal hunks" <|
            \_ -> Expect.equal hunks (Diff.hunks (Diff.lines [] "a\nb\nc\nd\ne\nf" "a\nB\nc\nd\nE\nF\nG"))
        , test "the hunks of a JSON diff have the text of the values" <|
            \_ ->
                Diff.json [] (Encode.object [ ( "n", Encode.int 1 ) ]) (Encode.object [ ( "n", Encode.int 2 ) ])
                    |> Diff.hunks
                    |> List.map (\hunk -> ( Diff.hunkBefore hunk, Diff.hunkAfter hunk ))
                    |> Expect.equal [ ( Just "1", Just "2" ) ]
        ]



-- THE VIEWER OF A TEXT DIFF


textViewTests : Test
textViewTests =
    let
        policy =
            start (Diff.lines [] oldPolicy newPolicy)

        long =
            start (Diff.lines [] longOld longNew)
    in
    describe "the viewer of a text diff"
        [ test "the box that scrolls is a named region and a tab stop" <|
            \_ ->
                query [ Diff.ariaLabel "Changes to the shipping policy" ] policy
                    |> Query.find [ Selector.class "klar-diff__scroll" ]
                    |> Query.has
                        [ region
                        , Selector.attribute (Attr.attribute "aria-label" "Changes to the shipping policy")
                        , Selector.attribute (Attr.tabindex 0)
                        ]
        , test "the default name is Changes" <|
            \_ ->
                query [] policy
                    |> Query.find [ Selector.class "klar-diff__scroll" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Changes") ]
        , test "the viewer has the id of the state" <|
            \_ -> query [] policy |> Query.has [ Selector.id "diff" ]
        , test "the diff is a table" <|
            \_ ->
                query [] policy
                    |> Query.find [ Selector.tag "table" ]
                    |> Query.has [ Selector.class "klar-diff__table--unified" ]
        , test "the columns have headings for screen readers" <|
            \_ ->
                query [] policy
                    |> Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "col") ]
                    |> Query.count (Expect.equal 4)
        , test "an added line says Added in text" <|
            \_ ->
                query [] policy
                    |> Query.findAll [ Selector.all [ Selector.class "klar-diff__cell--added", Selector.class "klar-diff__mark" ] ]
                    |> Query.each (Query.has [ Selector.text "Added" ])
        , test "a removed line says Removed in text" <|
            \_ ->
                query [] policy
                    |> Query.findAll [ Selector.all [ Selector.class "klar-diff__cell--removed", Selector.class "klar-diff__mark" ] ]
                    |> Query.each (Query.has [ Selector.text "Removed" ])
        , test "the signs are hidden from screen readers" <|
            \_ ->
                query [] policy
                    |> Query.findAll [ Selector.all [ Selector.class "klar-diff__mark", Selector.class "klar-diff__cell--added" ] ]
                    |> Query.each (Query.has [ Selector.containing [ Selector.attribute (Attr.attribute "aria-hidden" "true"), Selector.text "+" ] ])
        , test "what changed inside a line is an ins and a del" <|
            \_ ->
                query [] policy
                    |> Expect.all
                        [ Query.find [ Selector.tag "ins" ] >> Query.has [ Selector.text "75" ]
                        , Query.find [ Selector.tag "del" ] >> Query.has [ Selector.text "50" ]
                        ]
        , test "the line numbers of both texts are shown" <|
            \_ ->
                query [] policy
                    |> Query.findAll [ Selector.class "klar-diff__num" ]
                    |> Query.count (Expect.equal 10)
        , test "the first row of a change has the id the focus goes to and says which change it is" <|
            \_ ->
                query [] policy
                    |> Query.find [ Selector.id "diff-change-0" ]
                    |> Query.has [ Selector.attribute (Attr.tabindex -1), Selector.text "Change 1 of 2" ]
        , test "the second change has its own id" <|
            \_ ->
                query [] policy
                    |> Query.has [ Selector.id "diff-change-1" ]
        , test "the toolbar tells how much changed" <|
            \_ ->
                query [] policy
                    |> Query.find [ Selector.class "klar-diff__stats" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "1 added" ]
                        , Query.has [ Selector.text "1 changed" ]
                        ]
        , test "the toolbar counts the changes" <|
            \_ ->
                query [] policy
                    |> Query.find [ Selector.class "klar-diff__counter" ]
                    |> Query.has [ Selector.text "2 changes" ]
        , test "unchanged lines far from a change are folded into a button" <|
            \_ ->
                query [] long
                    |> Query.find (button "16 unchanged lines")
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-expanded" "false") ]
        , test "there is a fold after the change too" <|
            \_ ->
                query [] long
                    |> Query.has [ Selector.text "17 unchanged lines" ]
        , test "the lines around the change are shown" <|
            \_ ->
                query [] long
                    |> Expect.all
                        [ Query.has [ Selector.text "line 17" ]
                        , Query.has [ Selector.text "line 23" ]
                        , Query.hasNot [ Selector.text "line 16" ]
                        , Query.hasNot [ Selector.text "line 24" ]
                        ]
        , test "the context can be changed" <|
            \_ ->
                query [ Diff.context 1 ] long
                    |> Expect.all
                        [ Query.has [ Selector.text "line 19" ]
                        , Query.hasNot [ Selector.text "line 18" ]
                        , Query.has [ Selector.text "18 unchanged lines" ]
                        ]
        , test "with no context only the changes are shown" <|
            \_ ->
                query [ Diff.context 0 ] long
                    |> Expect.all
                        [ Query.hasNot [ Selector.text "line 19" ]
                        , Query.has [ Selector.text "19 unchanged lines" ]
                        ]
        , test "a run of one line is shown instead of folded" <|
            \_ ->
                -- 40 lines, the change on line 5: 1 line would be hidden at the start
                let
                    old =
                        numbered (\i -> "line " ++ String.fromInt i) 9

                    new =
                        String.replace "line 5" "line five" old

                    model =
                        start (Diff.lines [] old new)
                in
                query [ Diff.context 3 ] model
                    |> Expect.all
                        [ Query.has [ Selector.text "line 1" ]
                        , Query.hasNot [ Selector.text "1 unchanged line" ]
                        ]
        , test "texts that are equal say so" <|
            \_ ->
                query [] (start (Diff.lines [] oldPolicy oldPolicy))
                    |> Expect.all
                        [ Query.has [ Selector.text "No changes" ]
                        , Query.hasNot [ Selector.tag "table" ]
                        ]
        , test "the options that were used are told" <|
            \_ ->
                query [] (start (Diff.lines [ Diff.ignoreWhitespace, Diff.ignoreCase ] "a  b\nc\nd" "A b\nc\nD\ne"))
                    |> Expect.all
                        [ Query.has [ Selector.text "Differences in white space are ignored" ]
                        , Query.has [ Selector.text "Upper and lower case count as the same" ]
                        ]
        , test "a diff without options has no notes" <|
            \_ -> query [] policy |> Query.hasNot [ Selector.class "klar-diff__notes" ]
        , test "equal texts that were compared with an option still say so" <|
            \_ ->
                query [] (start (Diff.lines [ Diff.ignoreWhitespace ] "a  b" "a b"))
                    |> Expect.all
                        [ Query.has [ Selector.text "No changes" ]
                        , Query.has [ Selector.text "Differences in white space are ignored" ]
                        ]
        , test "different line endings are told" <|
            \_ ->
                query [] (start (Diff.lines [] "a\u{000D}\nb\u{000D}\nc" "a\nb\nX"))
                    |> Query.has [ Selector.text "The line endings differ" ]
        , test "a missing last line end is told" <|
            \_ ->
                query [] (start (Diff.lines [] "a\nb" "a\nb\n"))
                    |> Query.has [ Selector.text "No newline at end of file" ]
        , test "trailing white space of a changed line is marked" <|
            \_ ->
                query [] (start (Diff.lines [] "a\nb" "a\nb   "))
                    |> Query.has [ Selector.class "klar-diff__trailing" ]
        , test "trailing white space of an unchanged line is not marked" <|
            \_ ->
                query [] (start (Diff.lines [] "a   \nb\nc" "a   \nB\nc"))
                    |> Query.hasNot [ Selector.class "klar-diff__trailing" ]
        , test "a diff that is too large says so and gives the numbers" <|
            \_ ->
                let
                    diff =
                        Diff.lines [] (numbered (\i -> "old " ++ String.fromInt i) 3000) (numbered (\i -> "new " ++ String.fromInt i) 3000)
                in
                query [] (start diff)
                    |> Expect.all
                        [ Query.has [ Selector.text "Too large to compare line by line: showing a summary" ]
                        , Query.has [ Selector.text "3,000 lines" ]
                        , Query.hasNot [ Selector.tag "table" ]
                        ]
        , test "wrapping long lines is a class" <|
            \_ -> query [ Diff.wrapLines ] policy |> Query.has [ Selector.class "klar-diff--wrap" ]
        , test "a maximum height is a style on the box that scrolls" <|
            \_ ->
                query [ Diff.maxHeight 300 ] policy
                    |> Query.find [ Selector.class "klar-diff__scroll" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "max-height:300px") ]
        ]



-- INTERACTION


interactionTests : Test
interactionTests =
    let
        long =
            start (Diff.lines [] longOld longNew)

        many =
            start (Diff.lines [] manyOld manyNew)

        policy =
            start (Diff.lines [] oldPolicy newPolicy)
    in
    describe "using the viewer"
        [ test "there is no current change before the first step" <|
            \_ -> Expect.equal Nothing (Diff.currentHunk policy.diff policy.state)
        , test "the current change is the one the user stepped to" <|
            \_ ->
                typeKey [] "n" policy
                    |> Result.map (\moved -> Diff.currentHunk moved.diff moved.state |> Maybe.map Diff.hunkKey)
                    |> Result.map (Expect.equal (List.head (Diff.hunks policy.diff) |> Maybe.map Diff.hunkKey))
                    |> resultExpectation
        , test "going to a change by its key makes it current, draws it and focuses it" <|
            \_ ->
                let
                    keys =
                        List.map Diff.hunkKey (Diff.hunks many.diff)

                    last =
                        List.drop (List.length keys - 1) keys |> List.head |> Maybe.withDefault ""

                    ( state, _ ) =
                        Diff.goToHunk many.diff last many.state

                    moved =
                        { many | state = state }
                in
                Expect.all
                    [ \_ -> Expect.equal (Just last) (Diff.currentHunk moved.diff moved.state |> Maybe.map Diff.hunkKey)
                    , \_ -> query [] moved |> Query.has [ Selector.id ("diff-change-" ++ String.fromInt (List.length keys - 1)) ]
                    ]
                    ()
        , test "a key that is not in the diff changes nothing" <|
            \_ ->
                Expect.equal policy.state (Tuple.first (Diff.goToHunk policy.diff "nope" policy.state))
        , test "the current change is kept by its key when the diff is made again, never by its place" <|
            \_ ->
                let
                    twentyLines changed =
                        List.range 1 20
                            |> List.map
                                (\n ->
                                    if List.member n changed then
                                        "line " ++ String.fromInt n ++ " changed"

                                    else
                                        "line " ++ String.fromInt n
                                )
                            |> String.join "\n"

                    threeChanges =
                        Diff.lines [] (twentyLines []) (twentyLines [ 1, 10, 19 ])

                    twoChanges =
                        Diff.lines [] (twentyLines []) (twentyLines [ 10, 19 ])

                    middle =
                        Diff.hunks threeChanges |> List.drop 1 |> List.head |> Maybe.map Diff.hunkKey

                    ( state, _ ) =
                        Diff.goToHunk threeChanges (Maybe.withDefault "" middle) (Diff.init "diff")

                    keyIn diff =
                        Diff.currentHunk diff state |> Maybe.map Diff.hunkKey
                in
                Expect.all
                    [ \_ -> Expect.equal 3 (List.length (Diff.hunks threeChanges))
                    , \_ -> Expect.equal middle (keyIn threeChanges)

                    -- the first change is gone: the second place is now another change
                    , \_ -> Expect.equal middle (keyIn twoChanges)
                    , \_ -> Expect.equal Nothing (keyIn (Diff.lines [] "a" "b"))
                    ]
                    ()
        , test "pressing the fold opens it" <|
            \_ ->
                press [] (button "16 unchanged lines") long
                    |> Result.map (\opened -> query [] opened)
                    |> Result.map
                        (Expect.all
                            [ Query.has [ Selector.text "line 1" ]
                            , Query.has [ Selector.text "line 16" ]
                            , Query.has [ Selector.text "Hide 16 unchanged lines" ]
                            , Query.has [ Selector.attribute (Attr.attribute "aria-expanded" "true") ]
                            ]
                        )
                    |> resultExpectation
        , test "pressing it again closes it" <|
            \_ ->
                press [] (button "16 unchanged lines") long
                    |> Result.andThen (press [] (button "Hide 16 unchanged lines"))
                    |> Result.map (\closed -> query [] closed |> Query.hasNot [ Selector.text "line 16" ])
                    |> resultExpectation
        , test "an opened fold is remembered when the diff changes" <|
            \_ ->
                press [] (button "16 unchanged lines") long
                    |> Result.map (\opened -> query [] { opened | diff = Diff.lines [] longOld (String.replace "line 30" "line thirty" longNew) })
                    |> Result.map (Query.has [ Selector.text "line 16" ])
                    |> resultExpectation
        , test "the next change button goes to the first change" <|
            \_ ->
                press [] (button "Next change") policy
                    |> Result.map
                        (\moved ->
                            Expect.all
                                [ \m -> Query.has [ Selector.text "Change 1 of 2" ] (query [] m)
                                , \m -> Query.has [ Selector.class "klar-diff__hunk--current" ] (query [] m)
                                ]
                                moved
                        )
                    |> resultExpectation
        , test "the next change button goes on to the next change and the previous button back" <|
            \_ ->
                press [] (button "Next change") policy
                    |> Result.andThen (press [] (button "Next change"))
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 2 of 2" ] (query [] moved))
                    |> resultExpectation
        , test "previous goes back" <|
            \_ ->
                press [] (button "Next change") policy
                    |> Result.andThen (press [] (button "Next change"))
                    |> Result.andThen (press [] (button "Previous change"))
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 1 of 2" ] (query [] moved))
                    |> resultExpectation
        , test "previous change is disabled before the first change was visited" <|
            \_ ->
                query [] policy
                    |> Query.find (button "Previous change")
                    |> Query.has [ Selector.disabled True ]
        , test "next change is disabled at the last change" <|
            \_ ->
                press [] (button "Next change") policy
                    |> Result.andThen (press [] (button "Next change"))
                    |> Result.map (\moved -> query [] moved |> Query.find (button "Next change") |> Query.has [ Selector.disabled True ])
                    |> resultExpectation
        , test "the n key goes to the next change while the focus is in the box" <|
            \_ ->
                typeKey [] "n" policy
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 1 of 2" ] (query [] moved))
                    |> resultExpectation
        , test "the p key goes back" <|
            \_ ->
                typeKey [] "n" policy
                    |> Result.andThen (typeKey [] "n")
                    |> Result.andThen (typeKey [] "p")
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 1 of 2" ] (query [] moved))
                    |> resultExpectation
        , test "another key does nothing" <|
            \_ ->
                case typeKey [] "x" policy of
                    Ok _ ->
                        Expect.fail "the key was handled"

                    Err _ ->
                        Expect.pass
        , test "the layout can be changed with the buttons" <|
            \_ ->
                press [] (button "Split") policy
                    |> Result.map
                        (\moved ->
                            Expect.all
                                [ \m -> Expect.equal True (Diff.isSplit m.state)
                                , \m -> Query.has [ Selector.class "klar-diff__table--split" ] (query [] m)
                                , \m -> Query.has [ Selector.class "klar-diff--split" ] (query [] m)
                                ]
                                moved
                        )
                    |> resultExpectation
        , test "the layout buttons say which one is pressed" <|
            \_ ->
                query [] policy
                    |> Expect.all
                        [ Query.find (button "Unified") >> Query.has [ Selector.attribute (Attr.attribute "aria-pressed" "true") ]
                        , Query.find (button "Split") >> Query.has [ Selector.attribute (Attr.attribute "aria-pressed" "false") ]
                        ]
        , test "the layout can be set from the model" <|
            \_ ->
                query [] { policy | state = Diff.setSplit True policy.state }
                    |> Query.has [ Selector.class "klar-diff__table--split" ]
        , test "the side by side layout has six columns and the removed and the added line in one row" <|
            \_ ->
                query [] { policy | state = Diff.setSplit True policy.state }
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "col") ] >> Query.count (Expect.equal 6)
                        , Query.findAll [ Selector.tag "tr", Selector.containing [ Selector.tag "del" ], Selector.containing [ Selector.tag "ins" ] ] >> Query.count (Expect.equal 1)
                        ]
        , test "in the side by side layout the copy of an unchanged line is hidden from screen readers, and its cells stay in the table" <|
            \_ ->
                query [] { policy | state = Diff.setSplit True policy.state }
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__text", Selector.attribute (Attr.attribute "aria-hidden" "true") ] >> Query.count (Expect.equal 2)
                        ]
        , test "every row of the side by side layout has the six cells of the heading" <|
            \_ ->
                let
                    model =
                        start (Diff.lines [] "a\nb\nc\n" "a\nB\nx\ny\nc\nd\n")
                in
                query [] { model | state = Diff.setSplit True model.state }
                    |> Query.findAll [ Selector.tag "tr", Selector.class "klar-diff__row" ]
                    |> Expect.all
                        [ Query.count (Expect.atLeast 4)
                        , Query.each (Query.findAll [ Selector.tag "td" ] >> Query.count (Expect.equal 6))
                        ]
        , test "with white space ignored the old column of the side by side layout shows the old text" <|
            \_ ->
                let
                    model =
                        start (Diff.lines [ Diff.ignoreWhitespace ] "  a\nb\n" "a\nc\n")
                in
                query [] { model | state = Diff.setSplit True model.state }
                    |> Query.findAll [ Selector.tag "tr", Selector.containing [ Selector.class "klar-diff__cell--context" ] ]
                    |> Query.first
                    |> Query.findAll [ Selector.class "klar-diff__code" ]
                    |> Expect.all
                        [ Query.index 0 >> Query.has [ Selector.text "  a" ]
                        , Query.index 1 >> Query.has [ Selector.text "a" ]
                        , Query.index 1 >> Query.hasNot [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
                        , Query.index 1 >> Query.findAll [ Selector.attribute (Attr.attribute "aria-hidden" "true") ] >> Query.count (Expect.equal 0)
                        ]
        , test "with case ignored the old column of the side by side layout shows the old text" <|
            \_ ->
                let
                    model =
                        start (Diff.lines [ Diff.ignoreCase ] "Hello\nb\n" "hello\nc\n")
                in
                query [] { model | state = Diff.setSplit True model.state }
                    |> Query.findAll [ Selector.tag "tr", Selector.containing [ Selector.class "klar-diff__cell--context" ] ]
                    |> Query.first
                    |> Query.findAll [ Selector.class "klar-diff__code" ]
                    |> Query.index 0
                    |> Query.has [ Selector.text "Hello" ]
        , test "only the first changes are drawn when there are many" <|
            \_ ->
                query [] many
                    |> Expect.all
                        [ Query.has [ Selector.text "Showing 200 of 300 changes" ]
                        , Query.has [ Selector.id "diff-change-199" ]
                        , Query.hasNot [ Selector.id "diff-change-200" ]
                        ]
        , test "the limit can be changed" <|
            \_ ->
                query [ Diff.maxChanges 50 ] many
                    |> Expect.all
                        [ Query.has [ Selector.text "Showing 50 of" ]
                        , Query.hasNot [ Selector.id "diff-change-50" ]
                        ]
        ]


resultExpectation : Result String Expect.Expectation -> Expect.Expectation
resultExpectation result =
    case result of
        Ok expectation ->
            expectation

        Err message ->
            Expect.fail message



-- JSON AND FIELDS


entryViewTests : Test
entryViewTests =
    let
        order =
            start
                (Diff.fields
                    [ { label = "Status", before = Just "Open", after = Just "Shipped" }
                    , { label = "Carrier", before = Nothing, after = Just "Nordic Freight" }
                    , { label = "Coupon", before = Just "SPRING", after = Nothing }
                    , { label = "Customer", before = Just "Northwind", after = Just "Northwind" }
                    ]
                )
    in
    describe "the viewer of fields and JSON"
        [ test "the changed fields are a list" <|
            \_ ->
                query [] order
                    |> Query.findAll [ Selector.class "klar-diff__entry" ]
                    |> Query.count (Expect.equal 3)
        , test "a changed field reads like a sentence" <|
            \_ ->
                query [] order
                    |> Query.find [ Selector.class "klar-diff__entry--changed" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Status" ]
                        , Query.has [ Selector.text "changed from" ]
                        , Query.has [ Selector.text "Open" ]
                        , Query.has [ Selector.text "Shipped" ]
                        ]
        , test "the old value is a del and the new one an ins" <|
            \_ ->
                query [] order
                    |> Query.find [ Selector.class "klar-diff__entry--changed" ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "del" ] >> Query.has [ Selector.text "Open" ]
                        , Query.find [ Selector.tag "ins" ] >> Query.has [ Selector.text "Shipped" ]
                        ]
        , test "an added field says Added" <|
            \_ ->
                query [] order
                    |> Query.find [ Selector.class "klar-diff__entry--added" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Added" ]
                        , Query.has [ Selector.text "Nordic Freight" ]
                        ]
        , test "a removed field says Removed" <|
            \_ ->
                query [] order
                    |> Query.find [ Selector.class "klar-diff__entry--removed" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Removed" ]
                        , Query.has [ Selector.text "SPRING" ]
                        ]
        , test "the field that did not change is hidden" <|
            \_ -> query [] order |> Query.hasNot [ Selector.text "Northwind" ]
        , test "the field that did not change can be shown, muted" <|
            \_ ->
                query [ Diff.showUnchangedFields ] order
                    |> Query.find [ Selector.class "klar-diff__entry--unchanged" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Northwind" ]
                        , Query.has [ Selector.text "Unchanged" ]
                        ]
        , test "the first row of a change has the id for the focus" <|
            \_ -> query [] order |> Query.has [ Selector.id "diff-change-2" ]
        , test "a field that did not change has no id for the focus" <|
            \_ -> query [ Diff.showUnchangedFields ] order |> Query.hasNot [ Selector.id "diff-change-3" ]
        , test "next change goes to the first field" <|
            \_ ->
                press [] (button "Next change") order
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 1 of 3" ] (query [] moved))
                    |> resultExpectation
        , test "the buttons that step through the changes are a group with a name" <|
            \_ ->
                query [] order
                    |> Query.find [ Selector.class "klar-diff__nav" ]
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "role" "group")
                        , Selector.attribute (Attr.attribute "aria-label" "Go through the changes")
                        ]
        , test "a list of fields that cannot scroll is not a tab stop" <|
            \_ ->
                query [] order
                    |> Query.find [ Selector.class "klar-diff__scroll" ]
                    |> Query.hasNot [ Selector.attribute (Attr.tabindex 0), region ]
        , test "a list of fields in a box with a height is a named tab stop" <|
            \_ ->
                query [ Diff.maxHeight 200 ] order
                    |> Query.find [ Selector.class "klar-diff__scroll" ]
                    |> Query.has [ Selector.attribute (Attr.tabindex 0), region ]
        , test "the n key goes to the next field in a box that is not a tab stop" <|
            \_ ->
                typeKey [] "n" order
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 1 of 3" ] (query [] moved))
                    |> resultExpectation
        , test "the n key goes to the next field in a box that is a tab stop" <|
            \_ ->
                typeKey [ Diff.maxHeight 200 ] "n" order
                    |> Result.map (\moved -> Query.has [ Selector.text "Change 1 of 3" ] (query [ Diff.maxHeight 200 ] moved))
                    |> resultExpectation
        , test "a field diff has no layout buttons" <|
            \_ -> query [] order |> Query.hasNot [ Selector.class "klar-diff__layout" ]
        , test "equal fields say No changes" <|
            \_ ->
                query [] (start (Diff.fields [ { label = "Customer", before = Just "Northwind", after = Just "Northwind" } ]))
                    |> Expect.all
                        [ Query.has [ Selector.text "No changes" ]
                        , Query.hasNot [ Selector.class "klar-diff__entry" ]
                        ]
        , test "a changed text shows what changed inside it" <|
            \_ ->
                query [] (start (Diff.fields [ { label = "Address", before = Just "Harbour Road 12, Bergen", after = Just "Harbour Road 14, Bergen" } ]))
                    |> Query.find [ Selector.tag "ins" ]
                    |> Query.has [ Selector.text "4" ]
        , test "an empty text is shown as empty" <|
            \_ ->
                query [] (start (Diff.fields [ { label = "Note", before = Just "call first", after = Just "" } ]))
                    |> Query.has [ Selector.text "(empty)" ]
        , test "JSON changes are listed with their paths" <|
            \_ ->
                let
                    jsonDiff =
                        Diff.json []
                            (Encode.object [ ( "items", Encode.list identity [ Encode.object [ ( "price", Encode.float 12.5 ) ] ] ), ( "coupon", Encode.string "SPRING" ) ])
                            (Encode.object [ ( "items", Encode.list identity [ Encode.object [ ( "price", Encode.int 14 ) ] ] ) ])
                in
                query [] (start jsonDiff)
                    |> Expect.all
                        [ Query.has [ Selector.text "items[0].price" ]
                        , Query.has [ Selector.text "coupon" ]
                        , Query.has [ Selector.text "12.5" ]
                        , Query.has [ Selector.text "14" ]
                        ]
        , test "a long JSON value is cut and says so" <|
            \_ ->
                query [] (start (Diff.json [] (Encode.object []) (Encode.object [ ( "tags", Encode.list Encode.string (List.repeat 200 "warehouse") ) ])))
                    |> Query.has [ Selector.text "(shortened)" ]
        , test "only the first changes of a long JSON diff are drawn" <|
            \_ ->
                let
                    fields =
                        List.range 1 250 |> List.map (\i -> ( "field" ++ String.fromInt (1000 + i), Encode.int i ))
                in
                query [] (start (Diff.json [] (Encode.object []) (Encode.object fields)))
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__entry" ] >> Query.count (Expect.equal 200)
                        , Query.has [ Selector.text "Showing 200 of 250 changes" ]
                        ]
        , test "show more draws the rest" <|
            \_ ->
                let
                    fields =
                        List.range 1 250 |> List.map (\i -> ( "field" ++ String.fromInt (1000 + i), Encode.int i ))
                in
                press [] (button "Show 50 more") (start (Diff.json [] (Encode.object []) (Encode.object fields)))
                    |> Result.map
                        (\moved ->
                            query [] moved
                                |> Expect.all
                                    [ Query.findAll [ Selector.class "klar-diff__entry" ] >> Query.count (Expect.equal 250)
                                    , Query.hasNot [ Selector.class "klar-diff__footer" ]
                                    ]
                        )
                    |> resultExpectation
        ]



-- THE STATIC VIEWER


staticViewTests : Test
staticViewTests =
    let
        order =
            Diff.fields
                [ { label = "Status", before = Just "Open", after = Just "Shipped" } ]

        text =
            Diff.lines [] longOld longNew
    in
    describe "the viewer without state"
        [ test "a field diff is a list in a group with a name" <|
            \_ ->
                Diff.viewStatic [ Diff.ariaLabel "Changes made on 4 March" ] order
                    |> Query.fromHtml
                    |> Query.has [ Selector.attribute (Attr.attribute "role" "group"), Selector.attribute (Attr.attribute "aria-label" "Changes made on 4 March") ]
        , test "the lines of a text diff scroll sideways, so the box is a named tab stop without an id" <|
            \_ ->
                Diff.viewStatic [ Diff.ariaLabel "Changes to the policy" ] text
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-diff__scroll" ]
                    |> Expect.all
                        [ Query.has
                            [ Selector.attribute (Attr.attribute "role" "group")
                            , Selector.attribute (Attr.tabindex 0)
                            , Selector.attribute (Attr.attribute "aria-label" "Changes to the policy")
                            ]
                        , Query.hasNot [ Selector.attribute (Attr.id "-scroll") ]
                        ]
        , test "it has no toolbar, no buttons and no id" <|
            \_ ->
                Diff.viewStatic [] order
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.class "klar-diff__toolbar" ]
                        , Query.hasNot [ Selector.tag "button" ]
                        , Query.hasNot [ Selector.attribute (Attr.tabindex -1) ]
                        ]
        , test "a text diff folds the unchanged lines but the fold is not a button" <|
            \_ ->
                Diff.viewStatic [] text
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "16 unchanged lines" ]
                        , Query.hasNot [ Selector.tag "button" ]
                        ]
        , test "it draws every change" <|
            \_ ->
                Diff.viewStatic [] (Diff.lines [] manyOld manyNew)
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "ins" ]
                    |> Query.count (Expect.equal 300)
        , test "equal versions say No changes" <|
            \_ ->
                Diff.viewStatic [] (Diff.fields [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "No changes" ]
        ]



-- LOCALE


localeTests : Test
localeTests =
    describe "the language"
        [ test "Norwegian toolbar and folds" <|
            \_ ->
                query [ Diff.locale Locale.nb ] (start (Diff.lines [] longOld longNew))
                    |> Expect.all
                        [ Query.has [ Selector.text "Neste endring" ]
                        , Query.has [ Selector.text "Forrige endring" ]
                        , Query.has [ Selector.text "16 uendrede linjer" ]
                        , Query.has [ Selector.text "Under hverandre" ]
                        , Query.has [ Selector.text "Side ved side" ]
                        , Query.has [ Selector.text "1 endret" ]
                        ]
        , test "Norwegian sentences" <|
            \_ ->
                query [ Diff.locale Locale.nb ] (start (Diff.lines [] "a" "a"))
                    |> Query.has [ Selector.text "Ingen endringer" ]
        , test "Norwegian fields" <|
            \_ ->
                query [ Diff.locale Locale.nb ] (start (Diff.fields [ { label = "Status", before = Just "Åpen", after = Just "Sendt" } ]))
                    |> Query.has [ Selector.text "endret fra" ]
        , test "Norwegian summary of a diff that is too large" <|
            \_ ->
                let
                    diff =
                        Diff.lines [] (numbered (\i -> "old " ++ String.fromInt i) 3000) (numbered (\i -> "new " ++ String.fromInt i) 3000)
                in
                query [ Diff.locale Locale.nb ] (start diff)
                    |> Query.has [ Selector.text "For stor til å sammenligne linje for linje" ]
        , test "the numbers follow the language" <|
            \_ ->
                query [ Diff.locale Locale.nb ] (start (Diff.lines [] manyOld manyNew))
                    |> Query.has [ Selector.text "Viser 200 av 300 endringer" ]
        ]
