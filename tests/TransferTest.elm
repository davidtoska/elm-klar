module TransferTest exposing (suite)

{-| Tests of `Klar.Transfer`: the pure logic of the two lists (no item in both,
chosen ids that the source does not know, moving in both orders, locked items,
filters, type-ahead) with fuzz tests, and what the component draws and does with
real events (roles, ids, keys, buttons, the announcement, large sources).
-}

import Array
import Dict
import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale
import Klar.Picking as Picking
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select.Option as Option exposing (Option)
import Klar.Transfer as Transfer
import Klar.Transfer.Lists as Lists exposing (Order(..))
import Set
import Support.PickingDrive as Drive
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


ids : Ids Int
ids =
    Ids.int


products : List (Option Int)
products =
    [ Option.option 1 "Coffee" |> Option.withDescription "COF-1"
    , Option.option 2 "Cocoa"
    , Option.option 3 "Tea"
    , Option.option 4 "Milk" |> Option.disabledOption
    , Option.option 5 "Sugar"
    ]


type Msg
    = TR (Transfer.Msg Int)
    | Retried


type alias State =
    Transfer.State Int


field : State
field =
    Transfer.init "products"


html : List (Transfer.Attribute Int Msg) -> State -> Html Msg
html extra state =
    Transfer.view TR (Transfer.label "Products" :: Transfer.options ids products :: extra) state


feed : Maybe Msg -> State -> State
feed maybe state =
    case maybe of
        Just (TR inner) ->
            Transfer.update inner state |> Tuple.first

        _ ->
            state


fireOn : List (Transfer.Attribute Int Msg) -> List Selector -> ( String, Encode.Value ) -> State -> State
fireOn extra selectors event state =
    feed (Drive.fire selectors event (html extra state)) state


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


clickRow : String -> Int -> State -> State
clickRow side n state =
    fireOn [] [ Selector.id ("products-" ++ side ++ "-" ++ String.fromInt n) ] Event.click state


dblClickRow : String -> Int -> State -> State
dblClickRow side n state =
    fireOn [] [ Selector.id ("products-" ++ side ++ "-" ++ String.fromInt n) ] Event.doubleClick state


pressIn : String -> String -> State -> State
pressIn list name state =
    fireOn [] [ Selector.id ("products-" ++ list) ] (Drive.key name) state


button : String -> State -> State
button name state =
    fireOn [] [ attr "aria-label" name ] Event.click state


typeIn : String -> String -> State -> State
typeIn list text state =
    fireOn [] [ Selector.id (filterBox list) ] (Event.input text) state


{-| The id of the filter box of a list: the filter of "Available" has the id of the
field.
-}
filterBox : String -> String
filterBox list =
    if list == "available" then
        "products"

    else
        "products-" ++ list ++ "-filter"


{-| How many options a list has: the options of the list are the ones whose id
starts with the list's letter.
-}
optionCount : String -> Html Msg -> Int
optionCount list h =
    let
        letter =
            if list == "available" then
                "a"

            else
                "c"
    in
    List.range 0 60
        |> List.filter (\n -> Drive.has [ Selector.id ("products-" ++ letter ++ "-" ++ String.fromInt n) ] h)
        |> List.length


suite : Test
suite =
    describe "Transfer"
        [ listsTests
        , lazyInvariants
        , renderTests
        , markTests
        , moveTests
        , keyTests
        , filterTests
        , orderTests
        , unknownTests
        , sourceTests
        , localeTests
        , reviewTests
        ]



-- LISTS (pure)


source : Lists.Source Int
source =
    Lists.buildSource ids products


chosenOf : List Int -> List (Lists.Chosen Int)
chosenOf keys =
    List.map (\n -> { key = String.fromInt n, id = n, label = Nothing }) keys


keysOf : List (Lists.Chosen Int) -> List Int
keysOf =
    List.map .id


rowKeys : Array.Array (Lists.PaneRow Int) -> List String
rowKeys rows =
    rows |> Array.toList |> List.map .key


itemsOf : List Int -> List (Lists.Item Int)
itemsOf keys =
    keys |> List.filterMap (\n -> Lists.buildSource ids products |> .byKey |> Dict.get (String.fromInt n))


listsTests : Test
listsTests =
    describe "the logic of the lists"
        [ test "the source is indexed by key, and the first of two options with a key wins" <|
            \_ ->
                let
                    s =
                        Lists.buildSource ids [ Option.option 1 "First", Option.option 1 "Second", Option.option 2 "Other" ]
                in
                Expect.equal [ "First", "Other" ] (s.items |> Array.toList |> List.map (.option >> .label))
        , test "Available is the source without what is chosen, in the order of the source" <|
            \_ ->
                Lists.availableRows source (Set.fromList [ "2", "5" ]) []
                    |> rowKeys
                    |> Expect.equal [ "1", "3", "4" ]
        , test "the filter keeps the items that contain every word, ignoring case and accents" <|
            \_ ->
                Expect.equal ( [ "1", "2" ], [ "1" ], [] )
                    ( Lists.availableRows source Set.empty (Lists.filterWords "CO") |> rowKeys
                    , Lists.availableRows source Set.empty (Lists.filterWords "co cof") |> rowKeys
                    , Lists.availableRows source Set.empty (Lists.filterWords "co tea") |> rowKeys
                    )
        , test "the description is filtered too" <|
            \_ -> Expect.equal [ "1" ] (Lists.availableRows source Set.empty (Lists.filterWords "cof-1") |> rowKeys)
        , test "Chosen shows what is chosen, and an id that the source does not have as unknown" <|
            \_ ->
                let
                    rows =
                        Lists.chosenRows source [ { key = "2", id = 2, label = Nothing }, { key = "99", id = 99, label = Just "Old product" } ] []
                in
                Expect.equal [ ( "2", True ), ( "99", False ) ] (rows |> Array.toList |> List.map (\r -> ( r.key, r.known )))
        , test "moving puts items in the order of the source by default" <|
            \_ ->
                Lists.moveIn SourceOrder source (itemsOf [ 5, 1 ]) (chosenOf [ 3 ])
                    |> keysOf
                    |> Expect.equal [ 1, 3, 5 ]
        , test "or at the end, in the order of moving" <|
            \_ ->
                Lists.moveIn MovedOrder source (itemsOf [ 5, 1 ]) (chosenOf [ 3 ])
                    |> keysOf
                    |> Expect.equal [ 3, 5, 1 ]
        , test "a disabled item is not moved, and nothing is moved twice" <|
            \_ ->
                Lists.moveIn MovedOrder source (itemsOf [ 4, 1, 1, 3 ]) (chosenOf [ 3 ])
                    |> keysOf
                    |> Expect.equal [ 3, 1 ]
        , test "ids the source does not know keep their place after the others" <|
            \_ ->
                Lists.normalize SourceOrder source (chosenOf [ 99, 5, 77, 1 ])
                    |> keysOf
                    |> Expect.equal [ 1, 5, 99, 77 ]
        , test "removing takes items out, except the locked ones: disabled items of the source" <|
            \_ ->
                let
                    ( kept, removed ) =
                        Lists.removeFrom source (Set.fromList [ "1", "4", "99" ]) (chosenOf [ 1, 4, 99, 3 ])
                in
                Expect.equal ( [ 4, 3 ], [ "1", "99" ] ) ( keysOf kept, removed )
        , test "type-ahead: one letter looks after the current row, more letters keep it while it matches" <|
            \_ ->
                let
                    labels =
                        Array.fromList [ "coffee", "cocoa", "tea", "milk", "sugar", "sweet" ]
                in
                Expect.equal
                    [ Just 1, Just 0, Just 5, Just 4, Nothing, Just 0 ]
                    [ Lists.typeahead "c" (Just 0) labels
                    , Lists.typeahead "co" (Just 0) labels
                    , Lists.typeahead "s" (Just 4) labels
                    , Lists.typeahead "su" (Just 4) labels
                    , Lists.typeahead "x" (Just 0) labels
                    , Lists.typeahead "C" Nothing labels
                    ]
        , test "type-ahead goes round the end of the list and ignores accents and case" <|
            \_ ->
                Expect.equal [ Just 0, Just 2 ]
                    [ Lists.typeahead "c" (Just 1) (Array.fromList [ "coffee", "cocoa", "tea" ])
                    , Lists.typeahead "ø" Nothing (Array.fromList [ "a", "b", "orsted" ])
                    ]
        ]



-- LISTS (fuzz)


type Op
    = MoveSome (List Int)
    | RemoveSome (List Int)


opFuzzer : Fuzz.Fuzzer Op
opFuzzer =
    Fuzz.oneOf
        [ Fuzz.map MoveSome (Fuzz.listOfLengthBetween 0 6 (Fuzz.intRange 0 14))
        , Fuzz.map RemoveSome (Fuzz.listOfLengthBetween 0 6 (Fuzz.intRange 0 14))
        ]


optionsFuzzer : Fuzz.Fuzzer (List (Option Int))
optionsFuzzer =
    Fuzz.listOfLengthBetween 0 14 (Fuzz.pair (Fuzz.intRange 0 14) (Fuzz.intRange 0 5))
        |> Fuzz.map
            (List.map
                (\( n, d ) ->
                    Option.option n ("Item " ++ String.fromInt n)
                        |> (if d == 0 then
                                Option.disabledOption

                            else
                                identity
                           )
                )
            )


apply : Order -> Lists.Source Int -> Op -> List (Lists.Chosen Int) -> List (Lists.Chosen Int)
apply order s op chosen =
    case op of
        MoveSome keys ->
            Lists.moveIn order s (keys |> List.filterMap (\n -> Dict.get (String.fromInt n) s.byKey)) chosen

        RemoveSome keys ->
            Lists.removeFrom s (keys |> List.map String.fromInt |> Set.fromList) chosen |> Tuple.first


lazyInvariants : Test
lazyInvariants =
    describe "properties on random sources and moves"
        [ fuzz2 optionsFuzzer (Fuzz.list opFuzzer) "no item is ever in both lists, and the two lists hold every item of the source once" <|
            \opts ops ->
                let
                    s =
                        Lists.buildSource ids opts

                    chosen =
                        List.foldl (apply SourceOrder s) [] ops

                    chosenKeys =
                        Set.fromList (List.map .key chosen)

                    available =
                        Lists.availableRows s chosenKeys [] |> rowKeys |> Set.fromList

                    shownChosen =
                        Lists.chosenRows s chosen [] |> Array.toList |> List.filter .known |> List.map .key |> Set.fromList
                in
                Expect.all
                    [ \_ -> Expect.equal Set.empty (Set.intersect available chosenKeys)
                    , \_ -> Expect.equal (Set.fromList (Array.toList s.items |> List.map .key)) (Set.union available shownChosen)
                    , \_ -> Expect.equal (List.length chosen) (Set.size chosenKeys)
                    ]
                    ()
        , fuzz2 optionsFuzzer (Fuzz.list opFuzzer) "chosen ids are known to the source or shown as unknown, never dropped" <|
            \opts ops ->
                let
                    s =
                        Lists.buildSource ids opts

                    withStranger =
                        { key = "99", id = 99, label = Nothing } :: List.foldl (apply MovedOrder s) [] ops

                    rows =
                        Lists.chosenRows s withStranger []
                in
                Expect.all
                    [ \_ -> Expect.equal (List.length withStranger) (Array.length rows)
                    , \_ -> Expect.equal True (rows |> Array.toList |> List.all (\r -> r.known == Dict.member r.key s.byKey))
                    ]
                    ()
        , fuzz2 optionsFuzzer (Fuzz.list (Fuzz.intRange 0 14)) "a move is reversible: moving items in and out again gives back the chosen list" <|
            \opts picks ->
                let
                    s =
                        Lists.buildSource ids opts

                    base =
                        Lists.moveIn MovedOrder s (Array.toList s.items |> List.take 3) []

                    items =
                        picks |> List.filterMap (\n -> Dict.get (String.fromInt n) s.byKey)

                    moved =
                        Lists.moveIn MovedOrder s items base

                    added =
                        moved |> List.map .key |> List.filter (\k -> not (List.member k (List.map .key base)))

                    ( back, _ ) =
                        Lists.removeFrom s (Set.fromList added) moved
                in
                Expect.equal (List.map .key base) (List.map .key back)
        , fuzz2 optionsFuzzer (Fuzz.list opFuzzer) "in the order of the source, the same set of ids is always the same list" <|
            \opts ops ->
                let
                    s =
                        Lists.buildSource ids opts

                    chosen =
                        List.foldl (apply SourceOrder s) [] ops

                    shuffled =
                        List.reverse chosen
                in
                Expect.equal (keysOf (Lists.normalize SourceOrder s chosen)) (keysOf (Lists.normalize SourceOrder s shuffled))
        , fuzz2 optionsFuzzer (Fuzz.list opFuzzer) "a disabled item that is chosen stays chosen when everything is removed" <|
            \opts ops ->
                let
                    s =
                        Lists.buildSource ids opts

                    -- an item chosen from the code (not moved) can be disabled
                    start =
                        Array.toList s.items |> List.filter (\i -> i.option.disabled) |> List.map (\i -> { key = i.key, id = i.option.value, label = Nothing })

                    chosen =
                        List.foldl (apply MovedOrder s) start ops

                    ( kept, _ ) =
                        Lists.removeFrom s (Set.fromList (List.map .key chosen)) chosen
                in
                Expect.equal (List.length start) (List.length (List.filter (\c -> Dict.get c.key s.byKey |> Maybe.map (.option >> .disabled) |> Maybe.withDefault False) kept))
        , fuzz (Fuzz.listOfLengthBetween 0 20 (Fuzz.intRange 0 5)) "type-ahead only ever answers with a row that starts with the letters" <|
            \codes ->
                let
                    labels =
                        Array.fromList [ "apple", "avocado", "banana", "cherry", "coconut", "date" ]

                    buffer =
                        codes |> List.map (\n -> String.slice n (n + 1) "abcdef") |> String.concat
                in
                case Lists.typeahead buffer (Just 2) labels of
                    Just i ->
                        Expect.equal True (Array.get i labels |> Maybe.map (String.startsWith buffer) |> Maybe.withDefault False)

                    Nothing ->
                        Expect.equal True (not (List.any (String.startsWith buffer) (Array.toList labels)) || buffer == "")
        ]



-- RENDER


renderTests : Test
renderTests =
    describe "what it draws"
        [ test "a group named by its label, with two listboxes that allow several marked rows" <|
            \_ ->
                let
                    h =
                        html [] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "group", attr "aria-labelledby" "products-label" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-label", Selector.text "Products" ] h)
                    , \_ -> Expect.equal 2 (Drive.count [ attr "role" "listbox", attr "aria-multiselectable" "true" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", attr "role" "listbox", attr "aria-label" "Available" ] h)
                    ]
                    ()
        , test "Available shows all the items, Chosen is empty and says so" <|
            \_ ->
                let
                    h =
                        html [] field
                in
                Expect.all
                    [ \_ -> Expect.equal 5 (optionCount "available" h)
                    , \_ -> Expect.equal 0 (optionCount "chosen" h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "No items" ] h)
                    ]
                    ()
        , test "rows are options with a position, a size and their mark, and the description is shown" <|
            \_ ->
                let
                    h =
                        html [] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-1", attr "role" "option", attr "aria-selected" "false", attr "aria-posinset" "2", attr "aria-setsize" "5" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-0", Selector.containing [ Selector.text "COF-1" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-3", attr "aria-disabled" "true" ] h)
                    ]
                    ()
        , test "the list points at its highlighted row, which exists" <|
            \_ ->
                let
                    h =
                        html [] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", attr "aria-activedescendant" "products-a-0" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-0" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", Selector.attribute (Attr.tabindex 0) ] h)
                    ]
                    ()
        , test "the filter boxes, the header check boxes, the counts and the four buttons are there, with names" <|
            \_ ->
                let
                    h =
                        html [] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "products", attr "aria-label" "Filter “Available”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-chosen-filter", attr "aria-label" "Filter “Chosen”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Select all in “Available”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "0 of 5 selected" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move selected to “Chosen”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move all shown to “Chosen”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move selected to “Available”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move all shown to “Available”" ] h)
                    ]
                    ()
        , test "the buttons are dimmed (and stay in the tab order) while there is nothing to move" <|
            \_ ->
                let
                    h =
                        html [] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move selected to “Chosen”", attr "aria-disabled" "true" ] h)
                    , \_ -> Expect.equal Nothing (Drive.fire [ attr "aria-label" "Move selected to “Chosen”" ] Event.click h)
                    ]
                    ()
        , test "the titles are the application's" <|
            \_ ->
                let
                    h =
                        html [ Transfer.titles { available = "All products", chosen = "In the promotion" } ] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "All products" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move all shown to “In the promotion”" ] h)
                    ]
                    ()
        , test "the label, hint and error are joined to the group" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ attr "role" "group", attr "aria-describedby" "products-hint products-error" ]
                        (html [ Transfer.hint "At most 20.", Transfer.error "Choose some", Transfer.required ] field)
                    )
        , test "a disabled field has nothing to click, a read-only one has no keys that change it" <|
            \_ ->
                let
                    marked =
                        clickRow "a" 0 field

                    readOnly =
                        html [ Transfer.readOnly True ]
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-a-0" ] Event.click (html [ Transfer.disabled True ] field))
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-a-0" ] Event.click (readOnly field))
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-available" ] (Drive.key "Enter") (readOnly marked))
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-available" ] (Drive.key " ") (readOnly marked))
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-available" ] (Drive.keyWith { ctrl = True, shift = False } "a") (readOnly marked))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products", Selector.disabled True ] (html [ Transfer.disabled True ] field))
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-available" ] (Drive.key "ArrowDown") (html [ Transfer.disabled True ] field))
                    ]
                    ()
        , test "a read-only field can still be read with the keyboard: the arrows, Home and End move the highlight" <|
            \_ ->
                let
                    readOnly =
                        html [ Transfer.readOnly True ]

                    send name state =
                        feed (Drive.fire [ Selector.id "products-available" ] (Drive.key name) (readOnly state)) state

                    at state =
                        List.range 0 4
                            |> List.filter (\n -> Drive.has [ Selector.id "products-available", attr "aria-activedescendant" ("products-a-" ++ String.fromInt n) ] (readOnly state))
                            |> List.head
                in
                Expect.all
                    [ \_ -> Expect.equal [ Just 1, Just 4, Just 0 ] [ at (send "ArrowDown" field), at (send "End" field), at (field |> send "End" |> send "Home") ]
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", attr "aria-readonly" "true" ] (readOnly field))
                    , \_ -> Expect.equal [] (Transfer.values (field |> send "Enter" |> send " "))
                    ]
                    ()
        , test "the id of the field is the filter box of Available, so Klar.focus and an error summary land in the field" <|
            \_ ->
                Expect.equal [ True, True, True ]
                    (List.map
                        (\items -> Drive.has [ Selector.id "products", Selector.tag "input" ] (Transfer.view TR [ Transfer.label "Products", Transfer.remote ids items ] field))
                        [ Loading, Failed (Remote.problem Remote.network), Loaded products ]
                    )
        , test "only the rows that can be seen are drawn: 20 000 items" <|
            \_ ->
                let
                    many =
                        List.range 1 20000 |> List.map (\n -> Option.option n ("Item " ++ String.fromInt n))

                    h =
                        Transfer.view TR [ Transfer.label "Many", Transfer.options ids many ] field
                in
                Expect.atMost 40 (Drive.count [ attr "role" "option" ] h)
        ]



-- MARKS


markTests : Test
markTests =
    describe "marking"
        [ test "a click marks a row, another unmarks it, and the count says so" <|
            \_ ->
                let
                    once =
                        clickRow "a" 0 field

                    twice =
                        clickRow "a" 0 once
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-0", attr "aria-selected" "true" ] (html [] once))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "1 of 5 selected" ] (html [] once))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-0", attr "aria-selected" "false" ] (html [] twice))
                    ]
                    ()
        , test "a disabled item cannot be marked" <|
            \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-a-3" ] Event.click (html [] field))
        , test "the header check box marks all that can be marked: a dash while some are, and a click on it clears them" <|
            \_ ->
                let
                    all =
                        fireOn [] [ attr "aria-label" "Select all in “Available”" ] (Event.check True) field

                    some =
                        clickRow "a" 0 field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "4 of 5 selected" ] (html [] all))
                    , \_ -> Expect.equal False (Drive.has [ Selector.id "products-a-3", attr "aria-selected" "true" ] (html [] all))
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-check--indeterminate" ] (html [] some))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "0 of 5 selected" ] (html [] (fireOn [] [ attr "aria-label" "Select all in “Available”" ] (Event.check False) all)))
                    ]
                    ()
        , test "Space marks the highlighted row, ArrowDown moves it, Ctrl+A marks all" <|
            \_ ->
                let
                    state =
                        field |> pressIn "available" " " |> pressIn "available" "ArrowDown" |> pressIn "available" " "

                    everything =
                        fireOn [] [ Selector.id "products-available" ] (Drive.keyWith { ctrl = True, shift = False } "a") field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "2 of 5 selected" ] (html [] state))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", attr "aria-activedescendant" "products-a-1" ] (html [] state))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "4 of 5 selected" ] (html [] everything))
                    ]
                    ()
        , test "Shift+Arrow marks a range, Shift+click too" <|
            \_ ->
                let
                    withKeys =
                        field
                            |> pressIn "available" " "
                            |> fireOn [] [ Selector.id "products-available" ] (Drive.keyWith { ctrl = False, shift = True } "ArrowDown")
                            |> fireOn [] [ Selector.id "products-available" ] (Drive.keyWith { ctrl = False, shift = True } "ArrowDown")
                in
                Expect.equal True (Drive.has [ Selector.text "3 of 5 selected" ] (html [] withKeys))
        ]



-- MOVES


moveTests : Test
moveTests =
    describe "moving"
        [ test "the button moves the marked items to Chosen, the marks go, and an announcement is made" <|
            \_ ->
                let
                    state =
                        field |> clickRow "a" 0 |> clickRow "a" 2 |> button "Move selected to “Chosen”"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal [ 1, 3 ] (Transfer.values state)
                    , \_ -> Expect.equal ( 3, 2 ) ( optionCount "available" h, optionCount "chosen" h )
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "status", attr "aria-live" "polite", Selector.text "2 items moved to “Chosen”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "0 of 2 selected" ] h)
                    ]
                    ()
        , test "one item is announced in the singular, and the other way too" <|
            \_ ->
                let
                    there =
                        field |> clickRow "a" 0 |> button "Move selected to “Chosen”"

                    back =
                        there |> clickRow "c" 0 |> button "Move selected to “Available”"
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "status", Selector.text "1 item moved to “Chosen”" ] (html [] there))
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "status", Selector.text "1 item moved to “Available”" ] (html [] back))
                    , \_ -> Expect.equal [] (Transfer.values back)
                    ]
                    ()
        , test "the announcement uses the titles of the application" <|
            \_ ->
                let
                    state =
                        field |> clickRow "a" 0 |> fireOn [ Transfer.titles { available = "All", chosen = "Promo" } ] [ attr "aria-label" "Move selected to “Promo”" ] Event.click
                in
                Expect.equal True
                    (Drive.has [ attr "role" "status", Selector.text "1 item moved to “Promo”" ]
                        (html [ Transfer.titles { available = "All", chosen = "Promo" } ] state)
                    )
        , test "a double click moves that one item" <|
            \_ ->
                let
                    state =
                        dblClickRow "a" 2 field
                in
                Expect.equal [ 3 ] (Transfer.values state)
        , test ">> moves every item that is shown and can be moved, << brings them all back (but not the locked ones)" <|
            \_ ->
                let
                    all =
                        field |> button "Move all shown to “Chosen”"

                    locked =
                        Transfer.setValues ids [ 4 ] field |> button "Move all shown to “Chosen”"

                    back =
                        all |> button "Move all shown to “Available”"
                in
                Expect.all
                    [ \_ -> Expect.equal [ 1, 2, 3, 5 ] (Transfer.values all)
                    , \_ -> Expect.equal [ 1, 2, 3, 4, 5 ] (Transfer.values locked)
                    , \_ -> Expect.equal [] (Transfer.values back)
                    , \_ -> Expect.equal [ 4 ] (Transfer.values (Transfer.setValues ids [ 4, 1 ] field |> button "Move all shown to “Available”"))
                    ]
                    ()
        , test "the highlight goes to the row that took the place of the one that moved" <|
            \_ ->
                let
                    state =
                        field |> pressIn "available" "ArrowDown" |> pressIn "available" "Enter"
                in
                Expect.all
                    [ \_ -> Expect.equal [ 2 ] (Transfer.values state)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", attr "aria-activedescendant" "products-a-1" ] (html [] state))
                    ]
                    ()
        , test "a move that does nothing says nothing" <|
            \_ ->
                Expect.equal False (Drive.has [ attr "role" "status", Selector.containing [ Selector.text "moved" ] ] (html [] (field |> button "Move selected to “Chosen”")))
        , test "the value can be compared before and after: the same set is the same value" <|
            \_ ->
                let
                    a =
                        field |> clickRow "a" 0 |> clickRow "a" 1 |> button "Move selected to “Chosen”"

                    b =
                        field |> dblClickRow "a" 1 |> dblClickRow "a" 0
                in
                Expect.equal (Transfer.values a) (Transfer.values b)
        ]



-- KEYS


keyTests : Test
keyTests =
    describe "keys"
        [ test "Enter moves the marked items, or the highlighted one when nothing is marked" <|
            \_ ->
                Expect.equal ( [ 1 ], [ 2, 3 ] )
                    ( field |> pressIn "available" "Enter" |> Transfer.values
                    , field |> clickRow "a" 1 |> clickRow "a" 2 |> pressIn "available" "Enter" |> Transfer.values
                    )
        , test "Ctrl+ArrowRight moves the marked items to Chosen, Ctrl+ArrowLeft takes them back" <|
            \_ ->
                let
                    there =
                        field |> clickRow "a" 0 |> fireOn [] [ Selector.id "products-available" ] (Drive.keyWith { ctrl = True, shift = False } "ArrowRight")

                    back =
                        there |> clickRow "c" 0 |> fireOn [] [ Selector.id "products-chosen" ] (Drive.keyWith { ctrl = True, shift = False } "ArrowLeft")
                in
                Expect.equal ( [ 1 ], [] ) ( Transfer.values there, Transfer.values back )
        , test "with Shift they move everything that is shown" <|
            \_ ->
                field
                    |> fireOn [] [ Selector.id "products-available" ] (Drive.keyWith { ctrl = True, shift = True } "ArrowRight")
                    |> Transfer.values
                    |> Expect.equal [ 1, 2, 3, 5 ]
        , test "on a Mac Cmd does what Ctrl does: Cmd+A marks all, Cmd+ArrowRight moves them" <|
            \_ ->
                let
                    there =
                        field
                            |> fireOn [] [ Selector.id "products-available" ] (Drive.metaKey { shift = False } "a")
                            |> fireOn [] [ Selector.id "products-available" ] (Drive.metaKey { shift = False } "ArrowRight")

                    everything =
                        field |> fireOn [] [ Selector.id "products-available" ] (Drive.metaKey { shift = True } "ArrowRight")
                in
                Expect.equal ( [ 1, 2, 3, 5 ], [ 1, 2, 3, 5 ] ) ( Transfer.values there, Transfer.values everything )
        , test "Home, End, ArrowUp and ArrowDown move the highlight and skip a disabled item" <|
            \_ ->
                let
                    at state =
                        List.range 0 4
                            |> List.filter (\n -> Drive.has [ Selector.id "products-available", attr "aria-activedescendant" ("products-a-" ++ String.fromInt n) ] (html [] state))
                            |> List.head
                in
                Expect.equal [ Just 4, Just 0, Just 1, Just 4 ]
                    [ at (field |> pressIn "available" "End")
                    , at (field |> pressIn "available" "End" |> pressIn "available" "Home")
                    , at (field |> pressIn "available" "ArrowDown")
                    , at (field |> pressIn "available" "ArrowDown" |> pressIn "available" "ArrowDown" |> pressIn "available" "ArrowDown")
                    ]
        , test "typing letters jumps to the next item that starts with them" <|
            \_ ->
                let
                    at state =
                        List.range 0 4
                            |> List.filter (\n -> Drive.has [ Selector.id "products-available", attr "aria-activedescendant" ("products-a-" ++ String.fromInt n) ] (html [] state))
                            |> List.head
                in
                Expect.equal [ Just 2, Just 4, Just 1 ]
                    [ at (field |> pressIn "available" "t")
                    , at (field |> pressIn "available" "s")
                    , at (field |> pressIn "available" "c")
                    ]
        ]



-- FILTER


filterTests : Test
filterTests =
    describe "the filter"
        [ test "shows the items that match, with the highlighted match, and the counts say how many are shown" <|
            \_ ->
                let
                    state =
                        field |> typeIn "available" "co"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal 2 (optionCount "available" h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-0", Selector.containing [ Selector.tag "mark" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "0 of 2 selected (5 in all)" ] h)
                    ]
                    ()
        , test "select all marks only what is shown, and the others stay unmarked" <|
            \_ ->
                let
                    state =
                        field |> typeIn "available" "co" |> fireOn [] [ attr "aria-label" "Select all in “Available”" ] (Event.check True) |> button "Move selected to “Chosen”"
                in
                Expect.equal [ 1, 2 ] (Transfer.values state)
        , test "an item that is marked and hidden by the filter stays marked, and is not moved while hidden" <|
            \_ ->
                let
                    state =
                        field |> clickRow "a" 2 |> typeIn "available" "co" |> button "Move selected to “Chosen”"

                    cleared =
                        state |> typeIn "available" ""
                in
                Expect.all
                    [ \_ -> Expect.equal [] (Transfer.values state)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-2", attr "aria-selected" "true" ] (html [] cleared))
                    ]
                    ()
        , test ">> moves what the filter shows, not the rest" <|
            \_ ->
                field |> typeIn "available" "tea" |> button "Move all shown to “Chosen”" |> Transfer.values |> Expect.equal [ 3 ]
        , test "a filter that matches nothing says so, and the clear button empties the filter" <|
            \_ ->
                let
                    state =
                        field |> typeIn "available" "zzz"
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "No matches" ] (html [] state))
                    , \_ -> Expect.equal 5 (optionCount "available" (html [] (fireOn [] [ Selector.class "klar-input__clear" ] Event.click state)))
                    ]
                    ()
        , test "each list has its own filter" <|
            \_ ->
                let
                    state =
                        field |> button "Move all shown to “Chosen”" |> typeIn "chosen" "tea"
                in
                Expect.equal ( 1, 1 ) ( optionCount "chosen" (html [] state), optionCount "available" (html [] state) )
        ]



-- ORDER


orderTests : Test
orderTests =
    describe "the order of the chosen ids"
        [ test "by default the order of the items, whatever the order of moving" <|
            \_ ->
                Expect.equal [ 1, 5 ] (field |> dblClickRow "a" 4 |> dblClickRow "a" 0 |> Transfer.values)
        , test "with movedOrder the order of moving" <|
            \_ ->
                let
                    moved =
                        fireOn [ Transfer.order Transfer.movedOrder ] [ Selector.id "products-a-4" ] Event.doubleClick field

                    twice =
                        fireOn [ Transfer.order Transfer.movedOrder ] [ Selector.id "products-a-0" ] Event.doubleClick moved
                in
                Expect.equal [ 5, 1 ] (Transfer.values twice)
        , test "setValues keeps the order it is given until the lists are next worked out" <|
            \_ ->
                Expect.equal [ 5, 1 ] (Transfer.values (Transfer.setValues ids [ 5, 1 ] field))
        , test "reorder moves a block one place, to the top or to the bottom, and an item at the edge stays" <|
            \_ ->
                let
                    chosen keys =
                        List.map (\k -> { key = k, id = 0, label = Nothing }) keys

                    order placement marked keys =
                        Lists.reorder placement (Set.fromList marked) (chosen keys) |> List.map .key
                in
                Expect.equal
                    [ [ "b", "c", "a", "d" ], [ "a", "d", "b", "c" ], [ "a", "b", "c" ], [ "c", "a", "b" ], [ "a", "b", "c" ] ]
                    [ order Lists.Up [ "b", "c" ] [ "a", "b", "c", "d" ]
                    , order Lists.Down [ "b", "c" ] [ "a", "b", "c", "d" ]
                    , order Lists.Up [ "a", "b" ] [ "a", "c", "b" ]
                    , order Lists.ToTop [ "c" ] [ "a", "b", "c" ]
                    , order Lists.Down [ "c" ] [ "a", "b", "c" ]
                    ]
        , fuzz2 (Fuzz.list (Fuzz.intRange 0 9)) (Fuzz.list (Fuzz.intRange 0 9)) "reorder loses and adds nothing" <|
            \items marks ->
                let
                    keys =
                        items |> List.map String.fromInt |> Set.fromList |> Set.toList

                    chosen =
                        List.map (\k -> { key = k, id = 0, label = Nothing }) keys

                    marked =
                        Set.fromList (List.map String.fromInt marks)
                in
                Expect.equal [ keys, keys, keys, keys ]
                    (List.map (\placement -> Lists.reorder placement marked chosen |> List.map .key |> List.sort)
                        [ Lists.Up, Lists.Down, Lists.ToTop, Lists.ToBottom ]
                    )
        , test "in the order of moving, Alt+ArrowUp moves the highlighted item up in Chosen and says where it went" <|
            \_ ->
                let
                    moved =
                        [ Transfer.order Transfer.movedOrder ]

                    there =
                        field
                            |> fireOn moved [ Selector.id "products-a-2" ] Event.doubleClick
                            |> fireOn moved [ Selector.id "products-a-0" ] Event.doubleClick
                            |> fireOn moved [ Selector.id "products-a-0" ] Event.doubleClick

                    atEnd =
                        fireOn moved [ Selector.id "products-chosen" ] (Drive.key "End") there

                    up =
                        fireOn moved [ Selector.id "products-chosen" ] (Drive.altKey "ArrowUp") atEnd
                in
                Expect.all
                    [ \_ -> Expect.equal [ 3, 1, 2 ] (Transfer.values there)
                    , \_ -> Expect.equal [ 3, 2, 1 ] (Transfer.values up)
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "status", Selector.containing [ Selector.text "Moved to place 2 of 3" ] ] (html moved up))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-chosen", attr "aria-activedescendant" "products-c-1" ] (html moved up))
                    ]
                    ()
        , test "the buttons of Chosen move the marked items, and only in the order of moving" <|
            \_ ->
                let
                    moved =
                        [ Transfer.order Transfer.movedOrder ]

                    there =
                        field
                            |> fireOn moved [ Selector.id "products-a-2" ] Event.doubleClick
                            |> fireOn moved [ Selector.id "products-a-0" ] Event.doubleClick
                            |> fireOn moved [ Selector.id "products-a-0" ] Event.doubleClick
                            |> fireOn moved [ Selector.id "products-c-2" ] Event.click

                    top =
                        fireOn moved [ attr "aria-label" "Move to the top" ] Event.click there
                in
                Expect.all
                    [ \_ -> Expect.equal [ 2, 3, 1 ] (Transfer.values top)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move down" ] (html moved field))
                    , \_ -> Expect.equal False (Drive.has [ attr "aria-label" "Move down" ] (html [] field))
                    ]
                    ()
        ]



-- UNKNOWN AND LOCKED


unknownTests : Test
unknownTests =
    describe "ids that the items do not have, and locked items"
        [ test "an unknown id is shown in Chosen as Unknown value, counted, and kept in values" <|
            \_ ->
                let
                    state =
                        Transfer.setValues ids [ 99, 2 ] field

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal [ 99, 2 ] (Transfer.values state)
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-transfer__row--unknown", Selector.text "Unknown value" ] h)
                    , \_ -> Expect.equal 2 (optionCount "chosen" h)
                    , \_ -> Expect.equal 4 (optionCount "available" h)
                    ]
                    ()
        , test "it can be taken out, and it never turns up in Available" <|
            \_ ->
                let
                    state =
                        Transfer.setValues ids [ 99 ] field |> button "Move all shown to “Available”"
                in
                Expect.equal ( [], 5 ) ( Transfer.values state, optionCount "available" (html [] state) )
        , test "valueText writes it" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ Selector.text "Product 99" ] (html [ Transfer.valueText (\n -> "Product " ++ String.fromInt n) ] (Transfer.setValues ids [ 99 ] field)))
        , test "the label that the component saw when it was moved is kept when the item goes away" <|
            \_ ->
                let
                    moved =
                        dblClickRow "a" 2 field

                    gone =
                        Transfer.view TR [ Transfer.label "Products", Transfer.options ids [ Option.option 1 "Coffee" ] ] moved
                in
                Expect.equal True (Drive.has [ Selector.class "klar-transfer__row--unknown", Selector.text "Tea" ] gone)
        , test "a locked item (chosen and disabled) stays in Chosen: it cannot be marked, moved or removed" <|
            \_ ->
                let
                    state =
                        Transfer.setValues ids [ 1, 4 ] field

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "products-c-1", attr "aria-disabled" "true" ] h)
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "products-c-1" ] Event.click h)
                    , \_ -> Expect.equal [ 4 ] (Transfer.values (state |> dblClickRow "c" 0))
                    ]
                    ()
        ]



-- THE SOURCE FROM THE BACKEND


sourceTests : Test
sourceTests =
    describe "items from the backend"
        [ test "while loading, Available shows loading rows and Chosen shows what is chosen with Loading ..." <|
            \_ ->
                let
                    h =
                        Transfer.view TR [ Transfer.label "Products", Transfer.remote ids Loading ] (Transfer.setValues ids [ 2 ] field)
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "aria-busy" "true" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-transfer__row--unknown", Selector.text "Loading ..." ] h)
                    ]
                    ()
        , test "a failure shows the problem with a retry button when it is worth retrying" <|
            \_ ->
                let
                    v kind =
                        Transfer.view TR [ Transfer.label "Products", Transfer.remote ids (Failed (Remote.problem kind)), Transfer.onRetry Retried ] field
                in
                Expect.all
                    [ \_ -> Expect.equal (Just Retried) (Drive.fire [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] Event.click (v Remote.network))
                    , \_ -> Expect.equal True (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] (v Remote.network))
                    , \_ -> Expect.equal False (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] (v Remote.forbidden))
                    ]
                    ()
        , test "a click on Try again sends focus to the filter box of Available, which stays when the button goes" <|
            \_ ->
                let
                    failed =
                        Transfer.view TR [ Transfer.label "Products", Transfer.remote ids (Failed (Remote.problem Remote.network)), Transfer.onRetry Retried ] field

                    state =
                        [ Selector.class "klar-select__state", Selector.containing [ Selector.tag "button" ] ]

                    -- Tab on the button sends the message that does nothing
                    clicked =
                        Drive.fire state Event.click failed
                in
                Expect.all
                    [ \_ -> Expect.notEqual Nothing clicked
                    , \_ -> Expect.notEqual (Drive.fire state (Drive.key "Tab") failed) clicked
                    ]
                    ()
        , test "items that are refreshed stay and can be moved, with Available dimmed and busy" <|
            \_ ->
                let
                    items =
                        Remote.refresh (Loaded products)

                    h =
                        Transfer.view TR [ Transfer.label "Products", Transfer.remote ids items ] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-refreshing", attr "aria-busy" "true", Selector.containing [ Selector.id "products-available" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-a-0", Selector.containing [ Selector.text "Coffee" ] ] h)
                    ]
                    ()
        , test "items that are old after a failed refresh say so above the list, with a retry, and the list stays" <|
            \_ ->
                let
                    items =
                        Remote.refreshWith (Loaded products) (Err (Remote.problem Remote.server)) (Time.millisToPosix 0)

                    h =
                        Transfer.view TR [ Transfer.label "Products", Transfer.remote ids items, Transfer.onRetry Retried ] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-stale", Selector.containing [ Selector.text "Old data" ] ] h)
                    , \_ -> Expect.equal (Just Retried) (Drive.fire [ Selector.class "klar-stale", Selector.tag "button" ] Event.click h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-available", attr "role" "listbox" ] h)
                    ]
                    ()
        , test "when the items arrive the chosen ids are looked up and the unknown mark goes away" <|
            \_ ->
                let
                    state =
                        Transfer.setValues ids [ 2 ] field

                    loaded =
                        Transfer.view TR [ Transfer.label "Products", Transfer.remote ids (Loaded products) ] state
                in
                Expect.all
                    [ \_ -> Expect.equal False (Drive.has [ Selector.class "klar-transfer__row--unknown" ] loaded)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "products-c-0", Selector.containing [ Selector.text "Cocoa" ] ] loaded)
                    ]
                    ()
        ]



-- LOCALE


localeTests : Test
localeTests =
    describe "built-in text"
        [ test "is English by default and Norwegian Bokmål with locale, also in the announcement" <|
            \_ ->
                let
                    nb =
                        [ Transfer.locale Locale.nb ]

                    moved =
                        field |> clickRow "a" 0 |> clickRow "a" 1 |> fireOn nb [ attr "aria-label" "Flytt markerte til «Valgte»" ] Event.click
                in
                Expect.equal [ True, True, True, True ]
                    [ Drive.has [ Selector.text "Tilgjengelige" ] (html nb field)
                    , Drive.has [ Selector.text "0 av 5 markert" ] (html nb field)
                    , Drive.has [ attr "aria-label" "Filtrer «Tilgjengelige»" ] (html nb field)
                    , Drive.has [ attr "role" "status", Selector.text "2 elementer flyttet til «Valgte»" ] (html nb moved)
                    ]
        ]



-- REVIEW FIXES


reviewTests : Test
reviewTests =
    let
        shiftKey name state =
            fireOn [] [ Selector.id "products-available" ] (Drive.keyWith { ctrl = False, shift = True } name) state

        markedCount state =
            List.range 0 4
                |> List.filter (\row -> Drive.has [ Selector.id ("products-a-" ++ String.fromInt row), attr "aria-selected" "true" ] (html [] state))
                |> List.length

        cursorAt state =
            List.range 0 4
                |> List.filter (\row -> Drive.has [ Selector.id "products-available", attr "aria-activedescendant" ("products-a-" ++ String.fromInt row) ] (html [] state))
                |> List.head

        watching =
            fireOn [] [ attr "role" "group" ] (Event.custom "mouseenter" (Encode.object [])) field
    in
    describe "after the review"
        [ test "the value does not change order when the user only looks, marks or filters" <|
            \_ ->
                let
                    set =
                        Transfer.setValues ids [ 5, 1 ] field
                in
                Expect.equal
                    [ [ 5, 1 ], [ 5, 1 ], [ 5, 1 ], [ 5, 1 ] ]
                    [ Transfer.values set
                    , Transfer.values (clickRow "a" 0 set)
                    , Transfer.values (typeIn "available" "co" set)
                    , Transfer.values (pressIn "available" "ArrowDown" set)
                    ]
        , test "items that arrive after the ids were set do not change the value either" <|
            \_ ->
                let
                    set =
                        Transfer.setValues ids [ 5, 1 ] field

                    afterArrival =
                        fireOn [ Transfer.remote ids (Loaded products) ] [ Selector.id "products-a-1" ] Event.click set
                in
                Expect.equal [ 5, 1 ] (Transfer.values afterArrival)
        , test "a move puts the chosen ids in the order of the items" <|
            \_ ->
                Expect.equal [ 1, 3, 5 ] (Transfer.setValues ids [ 5, 1 ] field |> dblClickRow "a" 1 |> Transfer.values)
        , test "once the field has seen the items, ids that are set come out in the order of the items" <|
            \_ ->
                Expect.equal [ 1, 5 ] (Transfer.values (Transfer.setValues ids [ 5, 1 ] watching))
        , test "looking at the field the first time works the lists out once, and not again" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.notEqual Nothing (Drive.fire [ attr "role" "group" ] (Event.custom "mouseenter" (Encode.object [])) (html [] field))
                    , \_ -> Expect.notEqual Nothing (Drive.fire [ attr "role" "group" ] (Event.custom "focusin" (Encode.object [])) (html [] field))
                    , \_ -> Expect.equal Nothing (Drive.fire [ attr "role" "group" ] (Event.custom "mouseenter" (Encode.object [])) (html [] watching))
                    ]
                    ()
        , test "Enter in a filter box does not submit a form: it goes on to the list; so does ArrowDown" <|
            \_ ->
                let
                    pressed name =
                        Drive.fire [ Selector.id "products" ] (Drive.key name) (html [] field)
                in
                Expect.all
                    [ \_ -> Expect.notEqual Nothing (pressed "Enter")
                    , \_ -> Expect.notEqual Nothing (pressed "ArrowDown")
                    , \_ -> Expect.equal Nothing (pressed "x")
                    ]
                    ()
        , test "Shift+Arrow shrinks the range when the direction turns, and keeps what was marked before" <|
            \_ ->
                let
                    start =
                        field |> clickRow "a" 2

                    down2 =
                        start |> shiftKey "ArrowDown" |> shiftKey "ArrowDown"

                    back1 =
                        down2 |> shiftKey "ArrowUp"
                in
                -- item 4 (row 3) is disabled and is never marked: rows 2 and 4 are the range
                Expect.equal [ 1, 2, 1 ] [ markedCount start, markedCount down2, markedCount back1 ]
        , test "a range that goes back over a row that was marked earlier leaves that mark alone" <|
            \_ ->
                let
                    state =
                        field |> clickRow "a" 1 |> clickRow "a" 0 |> shiftKey "ArrowDown" |> shiftKey "ArrowDown"
                in
                -- rows 0 and 1 were marked, the range 0..2 adds row 2; going back to row 1 takes row 2 away only
                Expect.equal [ 3, 2 ] [ markedCount state, markedCount (shiftKey "ArrowUp" state) ]
        , test "type-ahead skips an item that is disabled, as the arrows do" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal (Just 0) (cursorAt (field |> pressIn "available" "m"))
                    , \_ -> Expect.equal (Just 4) (cursorAt (field |> pressIn "available" "s"))
                    ]
                    ()
        , test "filtering is announced politely, so a screen reader hears how many items are shown" <|
            \_ ->
                let
                    state =
                        field |> typeIn "available" "co"
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "status", attr "aria-live" "polite", Selector.text "2 shown in “Available”" ] (html [] state))
                    , \_ ->
                        Expect.equal True
                            (Drive.has [ attr "role" "status", Selector.text "2 vist i «Tilgjengelige»" ]
                                (html [ Transfer.locale Locale.nb ] (fireOn [ Transfer.locale Locale.nb ] [ Selector.id "products" ] (Event.input "co") field))
                            )
                    ]
                    ()
        , test "a title is quoted wherever it is part of a sentence" <|
            \_ ->
                let
                    h =
                        html [ Transfer.titles { available = "Stock", chosen = "On sale" } ] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move selected to “On sale”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Move all shown to “Stock”" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "aria-label" "Select all in “Stock”" ] h)
                    ]
                    ()
        , test "a key of an input method composition in a filter box is left alone" <|
            \_ ->
                let
                    composing =
                        Event.custom "keydown"
                            (Encode.object
                                [ ( "key", Encode.string "Enter" )
                                , ( "ctrlKey", Encode.bool False )
                                , ( "metaKey", Encode.bool False )
                                , ( "altKey", Encode.bool False )
                                , ( "shiftKey", Encode.bool False )
                                , ( "isComposing", Encode.bool True )
                                ]
                            )
                in
                Expect.equal Nothing (Drive.fire [ Selector.id "products" ] composing (html [] field))
        ]
