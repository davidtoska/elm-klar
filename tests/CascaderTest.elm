module CascaderTest exposing (suite)

{-| Tests of `Klar.Cascader`: the columns and their roles, the keys, the paths it
accepts and shows, the search over full paths, lazy children, and the pure logic
of the columns (valid paths, search texts and ranking).
-}

import Array
import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Cascader as Cascader
import Klar.Cascader.Columns as Columns
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale
import Klar.Picking as Picking
import Klar.Picking.Index as Index
import Klar.Remote as Remote exposing (Remote(..))
import Support.PickingDrive as Drive
import Support.PickingTrees as Trees
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


type Msg
    = CS (Cascader.Msg String)
    | RetriedNode String
    | Retried


ids : Ids String
ids =
    Ids.string


type alias State =
    Cascader.State String


html : List (Cascader.Attribute String Msg) -> State -> Html Msg
html extra state =
    Cascader.view CS (Cascader.label "Place" :: Cascader.nodes Trees.cities :: extra) state


feed : Maybe Msg -> State -> State
feed maybe state =
    case maybe of
        Just (CS inner) ->
            Cascader.update inner state |> Tuple.first

        _ ->
            state


press : String -> State -> State
press name state =
    pressWith [] name state


pressWith : List (Cascader.Attribute String Msg) -> String -> State -> State
pressWith extra name state =
    feed (Drive.fire [ Selector.id "place-search" ] (Drive.key name) (html extra state)) state


openField : State
openField =
    openWith [] field


openWith : List (Cascader.Attribute String Msg) -> State -> State
openWith extra state =
    feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (html extra state)) state


typeText : String -> State -> State
typeText text state =
    feed (Drive.fire [ Selector.id "place-search" ] (Event.input text) (html [] state)) state


field : State
field =
    Cascader.init "place"


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


items : List Selector
items =
    [ attr "role" "treeitem" ]


itemId : Int -> Int -> Selector
itemId column index =
    Selector.id ("place-c" ++ String.fromInt column ++ "-" ++ String.fromInt index)


activeId : State -> Maybe String
activeId state =
    let
        candidates =
            List.concatMap (\c -> List.map (\i -> "place-c" ++ String.fromInt c ++ "-" ++ String.fromInt i) (List.range 0 12)) (List.range 0 4)
                ++ List.map (\i -> "place-r" ++ String.fromInt i) (List.range 0 30)
    in
    candidates
        |> List.filter (\id -> Drive.has [ Selector.id "place-search", attr "aria-activedescendant" id ] (html [] state))
        |> List.head


suite : Test
suite =
    describe "Cascader"
        [ closedTests
        , columnTests
        , keyTests
        , anyNodeTests
        , valueTests
        , searchTests
        , lazyTests
        , localeAndSizeTests
        , logicTests
        , reviewTests
        , freshnessTests
        ]



-- FRESHNESS


freshnessTests : Test
freshnessTests =
    let
        withTop top state =
            Cascader.view CS [ Cascader.label "Place", Cascader.remote top, Cascader.onRetry Retried ] state

        stale =
            Remote.refreshWith (Loaded Trees.cities) (Err (Remote.problem Remote.server)) (Time.millisToPosix 0)

        opened top =
            feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (withTop top field)) field
    in
    describe "a top level that is Kept"
        [ test "is dimmed and busy while it is refreshed, with the columns still there" <|
            \_ ->
                let
                    top =
                        Remote.refresh (Loaded Trees.cities)
                in
                Expect.equal True
                    (Drive.has [ Selector.class "klar-refreshing", attr "aria-busy" "true", Selector.containing [ Selector.id "place-tree" ] ] (withTop top (opened top)))
        , test "says Old data with a retry when the last refresh failed, and the columns stay" <|
            \_ ->
                let
                    h =
                        withTop stale (opened stale)
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-stale", Selector.containing [ Selector.text "Old data" ] ] h)
                    , \_ -> Expect.equal (Just Retried) (Drive.fire [ Selector.class "klar-stale", Selector.tag "button" ] Event.click h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-tree" ] h)
                    ]
                    ()
        , test "Tab goes on to Try again of old data, a click on it sends focus back to the search box, and Tab on it closes" <|
            \_ ->
                let
                    h =
                        withTop stale (opened stale)

                    fresh =
                        withTop (Loaded Trees.cities) (opened (Loaded Trees.cities))

                    failed =
                        Failed (Remote.problem Remote.server)

                    refocus =
                        Drive.fire [ Selector.class "klar-select__state" ] Event.click (withTop failed (opened failed))

                    dismiss =
                        Drive.fire [ Selector.id "place-search" ] (Drive.key "Tab") fresh
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "place-search" ] (Drive.key "Tab") h)
                    , \_ -> Expect.notEqual Nothing refocus
                    , \_ -> Expect.equal refocus (Drive.fire [ Selector.class "klar-picking__notice" ] Event.click h)
                    , \_ -> Expect.notEqual Nothing dismiss
                    , \_ -> Expect.equal dismiss (Drive.fire [ Selector.class "klar-picking__notice" ] (Drive.key "Tab") h)
                    ]
                    ()
        , test "the marker for old data stays above No matches" <|
            \_ ->
                let
                    h =
                        withTop stale (opened stale |> typeText "zzzz")
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-stale", Selector.containing [ Selector.text "Old data" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "No matches" ] h)
                    ]
                    ()
        , test "the search box offers a listbox while it searches and a tree otherwise" <|
            \_ ->
                let
                    open =
                        openField

                    searching =
                        open |> typeText "osl"
                in
                Expect.equal [ True, True ]
                    [ Drive.has [ Selector.id "place-search", attr "aria-haspopup" "tree" ] (html [] open)
                    , Drive.has [ Selector.id "place-search", attr "aria-haspopup" "listbox" ] (html [] searching)
                    ]
        ]



-- CLOSED


closedTests : Test
closedTests =
    describe "the closed field"
        [ test "is a combobox button that offers a tree, with the placeholder" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        html [] field
                            |> Query.fromHtml
                            |> Query.find [ Selector.id "place" ]
                            |> Query.has [ Selector.tag "button", attr "role" "combobox", attr "aria-haspopup" "tree", attr "aria-expanded" "false" ]
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "Select ..." ] (html [] field))
                    ]
                    ()
        , test "Enter, Space, ArrowDown, ArrowUp and a character open it" <|
            \_ ->
                [ "Enter", " ", "ArrowDown", "ArrowUp", "o" ]
                    |> List.map (\k -> Cascader.isOpen (feed (Drive.fire [ Selector.id "place" ] (Drive.key k) (html [] field)) field))
                    |> Expect.equal [ True, True, True, True, True ]
        , test "shows the path of the value, the whole path for a screen reader and as the tooltip" <|
            \_ ->
                let
                    h =
                        html [] (Cascader.setValue ids [ "europe", "norway", "oslo" ] field)
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-select__value", Selector.text "Europe / Norway / Oslo" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-sr-only", Selector.text "Europe / Norway / Oslo" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place", attr "title" "Europe / Norway / Oslo" ] h)
                    ]
                    ()
        , test "a long path is shortened in the middle, with the whole path in the tooltip" <|
            \_ ->
                let
                    long =
                        [ Picking.branch ids
                            "a"
                            "A region with a rather long name"
                            [ Picking.branch ids
                                "b"
                                "A country that has an even longer name"
                                [ Picking.branch ids "c" "A county" [ Picking.leaf ids "d" "The city of the very end" ] ]
                            ]
                        ]

                    h =
                        Cascader.view CS [ Cascader.label "Place", Cascader.nodes long ] (Cascader.setValue ids [ "a", "b", "c", "d" ] field)
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-select__value", Selector.text "A region with a rather long name / … / The city of the very end" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-sr-only", Selector.text "A region with a rather long name / A country that has an even longer name / A county / The city of the very end" ] h)
                    ]
                    ()
        , test "the separator is the application's" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ Selector.class "klar-sr-only", Selector.text "Europe > Norway > Oslo" ]
                        (html [ Cascader.separator " > " ] (Cascader.setValue ids [ "europe", "norway", "oslo" ] field))
                    )
        , test "a disabled field cannot be opened, a read-only one has no chevron" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "place", Selector.disabled True ] (html [ Cascader.disabled True ] field))
                    , \_ -> Expect.equal False (Drive.has [ Selector.class "klar-select__chevron" ] (html [ Cascader.readOnly True ] field))
                    ]
                    ()
        ]



-- COLUMNS


columnTests : Test
columnTests =
    describe "the columns"
        [ test "the top level is one column of treeitems with level, size and position" <|
            \_ ->
                let
                    h =
                        html [] openField
                in
                Expect.all
                    [ \_ -> Expect.equal 3 (Drive.count items h)
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "tree", Selector.id "place-tree", attr "aria-label" "Place" ] h)
                    , \_ -> Expect.equal True (Drive.has [ itemId 0 1, attr "aria-level" "1", attr "aria-setsize" "3", attr "aria-posinset" "2", attr "aria-expanded" "false" ] h)
                    , \_ -> Expect.equal False (Drive.has [ itemId 0 2, attr "aria-expanded" "false" ] h)
                    ]
                    ()
        , test "the search box is a combobox for the tree and points at an item that exists" <|
            \_ ->
                let
                    h =
                        html [] openField
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "place-search", attr "role" "combobox", attr "aria-haspopup" "tree", attr "aria-controls" "place-tree" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place", attr "aria-controls" "place-popup" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-popup" ] h)
                    , \_ -> Expect.equal (Just "place-c0-0") (activeId openField)
                    ]
                    ()
        , test "opening a branch shows its children in a column to the right, one level down" <|
            \_ ->
                let
                    state =
                        openField |> press "ArrowRight"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal 5 (Drive.count items h)
                    , \_ -> Expect.equal True (Drive.has [ itemId 0 0, attr "aria-expanded" "true" ] h)
                    , \_ -> Expect.equal True (Drive.has [ itemId 1 0, attr "aria-level" "2", attr "aria-setsize" "2", attr "aria-posinset" "1", attr "aria-expanded" "false" ] h)
                    , \_ -> Expect.equal (Just "place-c0-0") (activeId state)
                    ]
                    ()
        , test "only one branch of a level is open: opening another closes the first" <|
            \_ ->
                let
                    state =
                        openField |> press "ArrowRight" |> press "ArrowDown" |> press "ArrowRight"
                in
                -- the cursor is on asia, which is open; europe's column is gone
                Expect.all
                    [ \_ -> Expect.equal 4 (Drive.count items (html [] state))
                    , \_ -> Expect.equal False (Drive.has [ Selector.text "Norway" ] (html [] state))
                    ]
                    ()
        , test "moving to another node closes the columns of the one that was open" <|
            \_ ->
                let
                    state =
                        openField |> press "ArrowRight" |> press "ArrowDown"
                in
                Expect.equal 3 (Drive.count items (html [] state))
        , test "a click on a branch opens it, a click on a node that can be chosen chooses it" <|
            \_ ->
                let
                    opened =
                        feed (Drive.fire [ itemId 0 0 ] Event.click (html [] openField)) openField

                    chosen =
                        feed (Drive.fire [ itemId 0 2 ] Event.click (html [] openField)) openField
                in
                Expect.all
                    [ \_ -> Expect.equal 5 (Drive.count items (html [] opened))
                    , \_ -> Expect.equal ( Just [ "africa" ], False ) ( Cascader.value chosen, Cascader.isOpen chosen )
                    ]
                    ()
        , test "the open popup reveals the value: its branches are open and the node is highlighted" <|
            \_ ->
                let
                    state =
                        Cascader.setValue ids [ "europe", "norway", "bergen" ] field
                            |> (\s -> feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (html [] s)) s)

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ itemId 2 1, attr "aria-level" "3", attr "aria-selected" "true" ] h)

                    -- only the chosen node is selected; the branches above it are open
                    , \_ -> Expect.equal True (Drive.has [ itemId 0 0, attr "aria-selected" "false", attr "aria-expanded" "true" ] h)
                    , \_ -> Expect.equal 1 (Drive.count [ attr "aria-selected" "true" ] h)
                    , \_ -> Expect.equal (Just "place-c2-1") (activeId state)
                    ]
                    ()
        , test "each column after the first is the group of the open branch before it, so the hierarchy is heard" <|
            \_ ->
                let
                    state =
                        Cascader.setValue ids [ "europe", "norway", "bergen" ] field
                            |> (\s -> feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (html [] s)) s)

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ itemId 0 0, attr "aria-owns" "place-group-1" ] h)
                    , \_ -> Expect.equal True (Drive.has [ itemId 1 0, attr "aria-owns" "place-group-2" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-group-1", attr "role" "group", Selector.containing [ itemId 1 0 ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-group-2", attr "role" "group", Selector.containing [ itemId 2 1 ] ] h)
                    , \_ -> Expect.equal 2 (Drive.count [ Selector.attribute (Attr.attribute "role" "group") ] h)
                    ]
                    ()
        , test "a top level that is loading, failed or empty draws that" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "aria-busy" "true" ] (html [ Cascader.remote Loading ] openField))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "No options" ] (html [ Cascader.nodes [] ] openField))
                    , \_ -> Expect.equal True (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] (html [ Cascader.remote (Failed (Remote.problem Remote.network)), Cascader.onRetry (RetriedNode "top") ] openField))
                    , \_ -> Expect.equal False (Drive.has [ Selector.id "place-search", attr "aria-controls" "place-tree" ] (html [ Cascader.remote Loading ] openField))
                    ]
                    ()
        , test "20 000 nodes in a column draw only the rows that can be seen" <|
            \_ ->
                let
                    v state =
                        Cascader.view CS [ Cascader.label "Place", Cascader.nodes (Trees.wide 20000) ] state

                    opened =
                        feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (v field)) field
                in
                Expect.atMost 40 (Drive.count items (v opened))
        ]



-- KEYS


keyTests : Test
keyTests =
    describe "keys"
        [ test "ArrowDown and ArrowUp move in the column and stop at its ends" <|
            \_ ->
                Expect.equal
                    [ Just "place-c0-1", Just "place-c0-2", Just "place-c0-2", Just "place-c0-1" ]
                    [ activeId (openField |> press "ArrowDown")
                    , activeId (openField |> press "ArrowDown" |> press "ArrowDown")
                    , activeId (openField |> press "ArrowDown" |> press "ArrowDown" |> press "ArrowDown")
                    , activeId (openField |> press "ArrowDown" |> press "ArrowDown" |> press "ArrowUp")
                    ]
        , test "Home and End go to the first and last node of the column" <|
            \_ ->
                Expect.equal ( Just "place-c0-2", Just "place-c0-0" ) ( activeId (openField |> press "End"), activeId (openField |> press "End" |> press "Home") )
        , test "ArrowRight opens the branch, then moves into its column" <|
            \_ ->
                Expect.equal
                    ( Just "place-c0-0", Just "place-c1-0" )
                    ( activeId (openField |> press "ArrowRight"), activeId (openField |> press "ArrowRight" |> press "ArrowRight") )
        , test "ArrowRight on a leaf does nothing" <|
            \_ ->
                Expect.equal (Just "place-c0-2") (activeId (openField |> press "End" |> press "ArrowRight"))
        , test "ArrowLeft moves back to the parent, which stays open; the next ArrowLeft closes it" <|
            \_ ->
                let
                    inside =
                        openField |> press "ArrowRight" |> press "ArrowRight"

                    back =
                        inside |> press "ArrowLeft"

                    closed =
                        back |> press "ArrowLeft"
                in
                Expect.all
                    [ \_ -> Expect.equal (Just "place-c0-0") (activeId back)
                    , \_ -> Expect.equal 5 (Drive.count items (html [] back))
                    , \_ -> Expect.equal (Just "place-c0-0") (activeId closed)
                    , \_ -> Expect.equal 3 (Drive.count items (html [] closed))
                    ]
                    ()
        , test "Enter on a leaf chooses it, closes the popup and the value is the path" <|
            \_ ->
                let
                    state =
                        openField |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowDown" |> press "Enter"
                in
                Expect.equal ( Just [ "europe", "norway", "bergen" ], False ) ( Cascader.value state, Cascader.isOpen state )
        , test "Enter on a branch opens it like ArrowRight (nothing is chosen)" <|
            \_ ->
                let
                    state =
                        openField |> press "Enter"
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Cascader.value state)
                    , \_ -> Expect.equal 5 (Drive.count items (html [] state))
                    ]
                    ()
        , test "Escape closes the popup, Tab closes it and leaves the browser to move on" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal False (Cascader.isOpen (openField |> press "Escape"))
                    , \_ -> Expect.equal False (Cascader.isOpen (openField |> press "Tab"))
                    , \_ -> Expect.equal True (Drive.fire [ Selector.id "place-search" ] (Drive.key "Tab") (html [] openField) /= Nothing)
                    ]
                    ()
        , test "the arrows that move the caret only count when the caret has nowhere to go" <|
            \_ ->
                let
                    withText =
                        openField |> typeText "x"

                    -- in the list of results the horizontal arrows are not used at all
                    at start end name =
                        Drive.fire [ Selector.id "place-search" ] (Drive.caretKey "x" start end name) (html [] withText)
                in
                Expect.equal [ False, False ] [ at 1 1 "ArrowRight" /= Nothing, at 0 0 "ArrowLeft" /= Nothing ]
        , test "in the columns ArrowRight counts at the end of the text and ArrowLeft at its start" <|
            \_ ->
                let
                    at text start end name =
                        Drive.fire [ Selector.id "place-search" ] (Drive.caretKey text start end name) (html [] openField)
                in
                Expect.equal [ False, True, False, True ]
                    [ at "ab" 0 0 "ArrowRight" /= Nothing
                    , at "ab" 2 2 "ArrowRight" /= Nothing
                    , at "ab" 1 1 "ArrowLeft" /= Nothing
                    , at "ab" 0 0 "ArrowLeft" /= Nothing
                    ]
        , test "a disabled branch opens but cannot be chosen, a disabled leaf does nothing" <|
            \_ ->
                let
                    nodes =
                        [ Picking.branch ids "h" "Heading" [ Picking.leaf ids "a" "A" ] |> Picking.disabled
                        , Picking.leaf ids "x" "X" |> Picking.disabled
                        ]

                    v state =
                        Cascader.view CS [ Cascader.label "Place", Cascader.nodes nodes ] state

                    send name state =
                        feed (Drive.fire [ Selector.id "place-search" ] (Drive.key name) (v state)) state

                    opened =
                        feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (v field)) field

                    afterEnter =
                        send "Enter" opened

                    onX =
                        afterEnter |> send "ArrowLeft" |> send "ArrowDown" |> send "Enter"
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Cascader.value afterEnter)
                    , \_ -> Expect.equal 3 (Drive.count items (v afterEnter))
                    , \_ -> Expect.equal Nothing (Cascader.value onX)
                    ]
                    ()
        ]



-- ANY NODE


anyNodeTests : Test
anyNodeTests =
    let
        any =
            [ Cascader.anyNode ]

        open =
            openWith any field

        send name state =
            pressWith any name state
    in
    describe "anyNode"
        [ test "Enter chooses a branch, ArrowRight opens it" <|
            \_ ->
                Expect.equal ( Just [ "europe" ], Nothing )
                    ( Cascader.value (open |> send "Enter")
                    , Cascader.value (open |> send "ArrowRight")
                    )
        , test "a button under the columns chooses the open branch, with its label" <|
            \_ ->
                let
                    state =
                        open |> send "ArrowRight" |> send "ArrowRight" |> send "ArrowRight"

                    h =
                        html any state

                    chosen =
                        feed (Drive.fire [ Selector.tag "button", Selector.containing [ Selector.text "Select “Norway”" ] ] Event.click h) state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Select “Norway”" ] ] h)
                    , \_ -> Expect.equal (Just [ "europe", "norway" ]) (Cascader.value chosen)
                    ]
                    ()
        , test "without anyNode there is no such button" <|
            \_ ->
                Expect.equal False
                    (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Select “Europe”" ] ] (html [] (openField |> press "ArrowRight")))
        , test "a double click on a branch chooses it" <|
            \_ ->
                feed (Drive.fire [ itemId 0 0 ] Event.doubleClick (html any open)) open
                    |> Cascader.value
                    |> Expect.equal (Just [ "europe" ])
        ]



-- VALUE


valueTests : Test
valueTests =
    describe "the value"
        [ test "is a path of the application's ids, Nothing when empty" <|
            \_ ->
                Expect.equal
                    ( Nothing, Just [ "europe", "norway" ], Nothing )
                    ( Cascader.value field
                    , Cascader.value (Cascader.setValue ids [ "europe", "norway" ] field)
                    , Cascader.value (Cascader.setValue ids [] (Cascader.setValue ids [ "europe" ] field))
                    )
        , test "a path that is in no node says Unknown value and is still the value" <|
            \_ ->
                let
                    state =
                        Cascader.setValue ids [ "mars", "base" ] field
                in
                Expect.all
                    [ \_ -> Expect.equal (Just [ "mars", "base" ]) (Cascader.value state)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "Unknown value" ] (html [] state))
                    ]
                    ()
        , test "a path in the wrong order or with a gap is not a path of the tree" <|
            \_ ->
                Expect.equal [ True, True ]
                    [ Drive.has [ Selector.text "Unknown value" ] (html [] (Cascader.setValue ids [ "oslo", "norway" ] field))
                    , Drive.has [ Selector.text "Unknown value" ] (html [] (Cascader.setValue ids [ "europe", "oslo" ] field))
                    ]
        , test "while the nodes load it says Loading, and when they failed Could not be loaded" <|
            \_ ->
                let
                    state =
                        Cascader.setValue ids [ "europe", "norway" ] field
                in
                Expect.equal [ True, True ]
                    [ Drive.has [ Selector.text "Loading ..." ] (html [ Cascader.remote Loading ] state)
                    , Drive.has [ Selector.text "Could not be loaded" ] (html [ Cascader.remote (Failed (Remote.problem Remote.network)) ] state)
                    ]
        , test "setPath remembers the labels, so a path through a branch that is not loaded is shown" <|
            \_ ->
                let
                    state =
                        Cascader.setPath [ Picking.branch ids "mars" "Mars" [], Picking.leaf ids "base" "Base Alpha" ] field
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-sr-only", Selector.text "Mars / Base Alpha" ] (html [] state))
                    , \_ -> Expect.equal (Just [ "mars", "base" ]) (Cascader.value state)
                    ]
                    ()
        , test "valueText writes the ids when nothing else knows the labels" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ Selector.text "Place mars / Place base" ]
                        (html [ Cascader.valueText (\id -> "Place " ++ id) ] (Cascader.setValue ids [ "mars", "base" ] field))
                    )
        , test "a path the user chose is remembered with its labels when the tree changes" <|
            \_ ->
                let
                    chosen =
                        openField |> press "End" |> press "Enter"

                    other =
                        Cascader.view CS [ Cascader.label "Place", Cascader.nodes [ Picking.leaf ids "z" "Z" ] ] chosen
                in
                Expect.equal True (Drive.has [ Selector.class "klar-sr-only", Selector.text "Africa" ] other)
        , test "clear and the clear button" <|
            \_ ->
                let
                    state =
                        Cascader.setValue ids [ "europe", "norway", "oslo" ] field
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Cascader.value (Cascader.clear state))
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-select__clear" ] (html [ Cascader.clearable ] state))
                    , \_ -> Expect.equal False (Drive.has [ Selector.class "klar-select__clear" ] (html [ Cascader.clearable ] field))
                    , \_ -> Expect.equal Nothing (Cascader.value (feed (Drive.fire [ Selector.class "klar-select__clear" ] Event.click (html [ Cascader.clearable ] state)) state))
                    , \_ -> Expect.equal Nothing (Cascader.value (feed (Drive.fire [ Selector.id "place" ] (Drive.key "Backspace") (html [ Cascader.clearable ] state)) state))
                    ]
                    ()
        , test "the label, hint and error are joined to the field" <|
            \_ ->
                Expect.equal True
                    (Drive.has
                        [ Selector.id "place", attr "aria-describedby" "place-hint place-error", attr "aria-invalid" "true", attr "aria-required" "true" ]
                        (html [ Cascader.hint "Where it is.", Cascader.error "Choose a place", Cascader.required ] field)
                    )
        ]



-- SEARCH


searchTests : Test
searchTests =
    describe "search across all paths"
        [ test "switches the popup to a flat list of full paths, best match first" <|
            \_ ->
                let
                    state =
                        openField |> typeText "oslo"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "listbox", Selector.id "place-results" ] h)
                    , \_ -> Expect.equal 1 (Drive.count [ attr "role" "option" ] h)
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "option", Selector.containing [ Selector.tag "mark" ], attr "aria-posinset" "1", attr "aria-setsize" "1" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-search", attr "aria-controls" "place-results" ] h)
                    , \_ -> Expect.equal (Just "place-r0") (activeId state)
                    , \_ -> Expect.equal 0 (Drive.count items h)
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "option", Selector.attribute (Attr.title "Europe / Norway / Oslo") ] h)
                    ]
                    ()
        , test "Enter chooses the highlighted result and the value is its path" <|
            \_ ->
                let
                    state =
                        openField |> typeText "oslo" |> press "Enter"
                in
                Expect.equal ( Just [ "europe", "norway", "oslo" ], False ) ( Cascader.value state, Cascader.isOpen state )
        , test "a click on a result chooses it" <|
            \_ ->
                let
                    state =
                        openField |> typeText "stock"

                    chosen =
                        feed (Drive.fire [ Selector.id "place-r0" ] Event.click (html [] state)) state
                in
                Expect.equal (Just [ "europe", "sweden", "stockholm" ]) (Cascader.value chosen)
        , test "the arrows move through the results, Home and End jump" <|
            \_ ->
                let
                    state =
                        openField |> typeText "o"
                in
                -- Oslo, Norway (a branch is not a result), Stockholm, Bergen, Africa, Europe ... : several leaves
                Expect.all
                    [ \_ -> Expect.equal (Just "place-r1") (activeId (state |> press "ArrowDown"))
                    , \_ -> Expect.equal (Just "place-r0") (activeId (state |> press "ArrowDown" |> press "ArrowUp"))
                    , \_ -> Expect.equal (Just "place-r0") (activeId (state |> press "ArrowUp"))
                    , \_ -> Expect.equal True (activeId (state |> press "End") /= activeId state)
                    ]
                    ()
        , test "with anyNode a branch is a result too" <|
            \_ ->
                let
                    state =
                        openWith [ Cascader.anyNode ] field |> (\s -> feed (Drive.fire [ Selector.id "place-search" ] (Event.input "norway") (html [ Cascader.anyNode ] s)) s)
                in
                Expect.equal True (Drive.has [ attr "role" "option", Selector.attribute (Attr.title "Europe / Norway") ] (html [ Cascader.anyNode ] state))
        , test "a text that matches nothing says so" <|
            \_ -> Expect.equal True (Drive.has [ Selector.text "No matches" ] (html [] (openField |> typeText "zzzz")))
        , test "clearing the text brings the columns back as they were" <|
            \_ ->
                let
                    before =
                        openField |> press "ArrowRight" |> press "ArrowRight"

                    after =
                        before |> typeText "oslo" |> typeText ""
                in
                Expect.all
                    [ \_ -> Expect.equal (Drive.count items (html [] before)) (Drive.count items (html [] after))
                    , \_ -> Expect.equal (activeId before) (activeId after)
                    ]
                    ()
        , test "a keyword and a description are searched" <|
            \_ ->
                Expect.equal [ True, True ]
                    [ Drive.has [ attr "role" "option" ] (html [] (openField |> typeText "bjorgvin"))
                    , Drive.has [ attr "role" "option" ] (html [] (openField |> typeText "osl"))
                    ]
        , test "the number of matches is announced politely" <|
            \_ ->
                Expect.equal True (Drive.has [ attr "role" "status", attr "aria-live" "polite", Selector.text "1 match" ] (html [] (openField |> typeText "oslo")))
        ]



-- LAZY


lazyTests : Test
lazyTests =
    let
        withAreas areas state =
            Cascader.view CS
                [ Cascader.label "Place"
                , Cascader.nodes [ Picking.branch ids "asia" "Asia" [ Picking.lazy ids "japan" "Japan" areas ] ]
                , Cascader.onRetryChildren RetriedNode
                ]
                state

        sendTo areas name state =
            feed (Drive.fire [ Selector.id "place-search" ] (Drive.key name) (withAreas areas state)) state

        opened areas =
            feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (withAreas areas field)) field

        atJapan areas =
            opened areas |> sendTo areas "ArrowRight" |> sendTo areas "ArrowRight"
    in
    describe "lazy children"
        [ test "an open branch whose children are not asked for is named by loadRequests, until the application marks it as loading" <|
            \_ ->
                let
                    before =
                        atJapan NotAsked

                    after =
                        before |> sendTo NotAsked "ArrowRight"

                    marked =
                        after |> sendTo Loading "Home"
                in
                Expect.equal [ [], [ "japan" ], [ "japan" ], [] ]
                    [ Cascader.loadRequests before, Cascader.loadRequests after, Cascader.loadRequests after, Cascader.loadRequests marked ]
        , test "a click on a branch that is not loaded is named too; when the popup is opened again the branches start closed" <|
            \_ ->
                let
                    before =
                        opened NotAsked

                    after =
                        feed (Drive.fire [ itemId 0 0 ] Event.click (withAreas NotAsked before)) before

                    next =
                        feed (Drive.fire [ itemId 1 0 ] Event.click (withAreas NotAsked after)) after

                    closed =
                        next |> sendTo NotAsked "Escape"

                    reopened =
                        feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") (withAreas NotAsked closed)) closed
                in
                Expect.all
                    [ \_ ->
                        Expect.equal [ [], [], [ "japan" ], [] ]
                            [ Cascader.loadRequests before, Cascader.loadRequests after, Cascader.loadRequests next, Cascader.loadRequests closed ]
                    , \_ -> Expect.equal ( True, [] ) ( Cascader.isOpen reopened, Cascader.loadRequests reopened )
                    ]
                    ()
        , test "a branch that is loading shows a loading row in its column; the other columns work" <|
            \_ ->
                let
                    state =
                        atJapan Loading |> sendTo Loading "ArrowRight"

                    h =
                        withAreas Loading state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "treeitem", attr "aria-busy" "true" ] h)
                    , \_ -> Expect.equal [] (Cascader.loadRequests state)
                    , \_ -> Expect.equal True (Drive.has [ itemId 1 0, attr "aria-expanded" "true" ] h)
                    ]
                    ()
        , test "the children appear in the next column when the application passes them" <|
            \_ ->
                let
                    state =
                        atJapan NotAsked |> sendTo NotAsked "ArrowRight"
                in
                Expect.equal True (Drive.has [ attr "role" "treeitem", Selector.containing [ Selector.text "Tokyo" ] ] (withAreas (Loaded [ Picking.leaf ids "tokyo" "Tokyo" ]) state))
        , test "a failed branch shows the problem and a retry button; Enter on that row retries" <|
            \_ ->
                let
                    failed =
                        Failed (Remote.problem Remote.network)

                    state =
                        atJapan failed |> sendTo failed "ArrowRight" |> sendTo failed "ArrowRight"

                    h =
                        withAreas failed state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.containing [ Selector.text "Could not be loaded" ] ] h)
                    , \_ -> Expect.equal (Just (RetriedNode "japan")) (Drive.fire [ Selector.id "place-search" ] (Drive.key "Enter") h)
                    , \_ -> Expect.equal (Just (RetriedNode "japan")) (Drive.fire [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] Event.click h)
                    ]
                    ()
        , test "a failure that is not worth retrying has no button" <|
            \_ ->
                let
                    failed =
                        Failed (Remote.problem Remote.forbidden)

                    state =
                        atJapan failed |> sendTo failed "ArrowRight"
                in
                Expect.equal False (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] (withAreas failed state))
        , test "each branch is named once: the scroll of a column before the application marked it does not name it again" <|
            \_ ->
                let
                    after =
                        atJapan NotAsked |> sendTo NotAsked "ArrowRight"

                    scrolled =
                        feed (Drive.fire [ Selector.id "place-col-0" ] (Drive.scroll 10) (withAreas NotAsked after)) after
                in
                Expect.equal [ [ "japan" ], [] ] [ Cascader.loadRequests after, Cascader.loadRequests scrolled ]
        , test "after Try again the cursor stays on the branch whose children load again, and the trail stays open" <|
            \_ ->
                let
                    failed =
                        Failed (Remote.problem Remote.network)

                    onFailure =
                        atJapan failed |> sendTo failed "ArrowRight" |> sendTo failed "ArrowRight"

                    retried =
                        withAreas Loading onFailure
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "place-search", attr "aria-activedescendant" "place-c2-0" ] (withAreas failed onFailure))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-search", attr "aria-activedescendant" "place-c1-0" ] retried)
                    , \_ -> Expect.equal True (Drive.has [ itemId 1 0, attr "aria-expanded" "true" ] retried)
                    ]
                    ()
        , test "children that are refreshed stay in their column, and their branch is busy" <|
            \_ ->
                let
                    areas =
                        Remote.refresh (Loaded [ Picking.leaf ids "tokyo" "Tokyo" ])

                    h =
                        withAreas areas (atJapan areas |> sendTo areas "ArrowRight")
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ itemId 2 0, Selector.containing [ Selector.text "Tokyo" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ itemId 1 0, attr "aria-busy" "true" ] h)
                    ]
                    ()
        , test "children that are old after a failed refresh stay, under a row that says so and retries with Enter" <|
            \_ ->
                let
                    areas =
                        Remote.refreshWith (Loaded [ Picking.leaf ids "tokyo" "Tokyo" ]) (Err (Remote.problem Remote.server)) (Time.millisToPosix 0)

                    state =
                        atJapan areas |> sendTo areas "ArrowRight" |> sendTo areas "ArrowRight"

                    h =
                        withAreas areas state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ itemId 2 0, Selector.class "klar-cascader__item--stale", Selector.containing [ Selector.text "Old data" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ itemId 2 1, Selector.containing [ Selector.text "Tokyo" ] ] h)
                    , \_ -> Expect.equal (Just (RetriedNode "japan")) (Drive.fire [ Selector.id "place-search" ] (Drive.key "Enter") h)
                    ]
                    ()
        , test "a popup opened from the code opens on the value, after the user left other columns open" <|
            \_ ->
                let
                    wandered =
                        Cascader.setValue ids [ "asia" ] (atJapan NotAsked |> sendTo NotAsked "ArrowRight" |> sendTo NotAsked "Escape")

                    ( reopened, _ ) =
                        Cascader.open wandered

                    focused =
                        feed (Drive.fire [ Selector.id "place-search" ] Event.focus (withAreas NotAsked reopened)) reopened

                    h =
                        withAreas NotAsked focused
                in
                Expect.all
                    [ \_ -> Expect.equal [] (Cascader.loadRequests focused)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "place-search", attr "aria-activedescendant" "place-c0-0" ] h)
                    , \_ -> Expect.equal False (Drive.has [ itemId 1 0 ] h)
                    ]
                    ()
        ]



-- LOCALE


localeAndSizeTests : Test
localeAndSizeTests =
    describe "built-in text"
        [ test "is English by default and Norwegian Bokmål with locale" <|
            \_ ->
                Expect.equal [ True, True, True ]
                    [ Drive.has [ Selector.text "Select ..." ] (html [] field)
                    , Drive.has [ Selector.text "Velg ..." ] (html [ Cascader.locale Locale.nb ] field)
                    , Drive.has [ Selector.text "1 treff" ] (html [ Cascader.locale Locale.nb ] (openField |> typeText "oslo"))
                    ]
        ]



-- LOGIC


logicTests : Test
logicTests =
    let
        index =
            Index.build Trees.cities

        keysOf cells =
            cells
                |> Array.toList
                |> List.map
                    (\cell ->
                        case cell of
                            Columns.ItemCell key _ _ ->
                                key

                            Columns.PendingCell p ->
                                "pending:" ++ p

                            Columns.FailedCell p _ ->
                                "failed:" ++ p

                            Columns.StaleCell p _ ->
                                "stale:" ++ p
                    )
    in
    describe "the logic of the columns"
        [ test "the columns of a trail: the top level, then the children of each opened node" <|
            \_ ->
                Columns.columns index [ "europe", "norway" ]
                    |> List.map (.cells >> keysOf)
                    |> Expect.equal [ [ "europe", "asia", "africa" ], [ "norway", "sweden" ], [ "oslo", "bergen" ] ]
        , test "a trail that ends in a branch that is not loaded shows a pending cell" <|
            \_ ->
                Columns.columns index [ "asia", "japan" ]
                    |> List.map (.cells >> keysOf)
                    |> Expect.equal [ [ "europe", "asia", "africa" ], [ "japan" ], [ "pending:japan" ] ]
        , test "a trail that is not a trail stops at the first key that does not fit" <|
            \_ ->
                Columns.columns index [ "mars", "norway" ]
                    |> List.map (.cells >> keysOf)
                    |> Expect.equal [ [ "europe", "asia", "africa" ] ]
        , test "valid paths are paths from the top, node by node" <|
            \_ ->
                Expect.equal [ True, True, False, False, False, False ]
                    [ Columns.isValidPath index [ "europe", "norway", "oslo" ]
                    , Columns.isValidPath index [ "africa" ]
                    , Columns.isValidPath index []
                    , Columns.isValidPath index [ "norway", "oslo" ]
                    , Columns.isValidPath index [ "europe", "oslo" ]
                    , Columns.isValidPath index [ "oslo", "norway", "europe" ]
                    ]
        , test "only nodes without children can be chosen, unless any node may be; never a disabled one" <|
            \_ ->
                let
                    searchable anyNode =
                        Columns.searchables anyNode " / " index |> Array.toList |> List.map .key
                in
                Expect.equal
                    ( [ "oslo", "bergen", "stockholm", "africa" ], [ "europe", "norway", "oslo", "bergen", "sweden", "stockholm", "asia", "japan", "africa" ] )
                    ( searchable False, searchable True )
        , test "a disabled node is not searchable" <|
            \_ ->
                Columns.searchables True " / " (Index.build [ Picking.leaf ids "a" "A" |> Picking.disabled, Picking.leaf ids "b" "B" ])
                    |> Array.toList
                    |> List.map .key
                    |> Expect.equal [ "b" ]
        , test "the texts are the full paths" <|
            \_ ->
                Columns.searchables False " > " index
                    |> Array.toList
                    |> List.map .text
                    |> Expect.equal [ "Europe > Norway > Oslo", "Europe > Norway > Bergen", "Europe > Sweden > Stockholm", "Africa" ]
        , test "results are the matches, best first, and a blank text matches nothing" <|
            \_ ->
                let
                    items_ =
                        Columns.searchables False " / " index

                    found text =
                        Columns.results text items_ |> Array.toList |> List.map .key
                in
                Expect.equal ( [ "oslo" ], [], [ "africa" ] ) ( found "oslo", found "   ", found "afri" )
        , test "a word that is in the path of a node finds the node" <|
            \_ ->
                Columns.results "norway" (Columns.searchables False " / " index)
                    |> Array.toList
                    |> List.map .key
                    |> Expect.equal [ "oslo", "bergen" ]
        , fuzz Trees.specFuzzer "the search is stable on any tree: results are searchable nodes, and a path text ends with the label" <|
            \spec ->
                let
                    tree =
                        Trees.indexOf spec

                    searchables =
                        Columns.searchables True " / " tree

                    found =
                        Columns.results "node" searchables
                in
                Expect.all
                    [ \_ -> Expect.atMost (Array.length searchables) (Array.length found)
                    , \_ ->
                        searchables
                            |> Array.toList
                            |> List.all (\s -> Index.get s.key tree |> Maybe.map (\e -> String.endsWith e.label s.text) |> Maybe.withDefault False)
                            |> Expect.equal True
                    ]
                    ()
        , fuzz Trees.specFuzzer "every path of the tree is valid, and no list of keys that is not a path is" <|
            \spec ->
                let
                    tree =
                        Trees.indexOf spec
                in
                Expect.all
                    [ \_ -> tree.order |> List.all (\key -> Columns.isValidPath tree (Index.pathTo key tree)) |> Expect.equal True
                    , \_ -> Expect.equal False (Columns.isValidPath tree (List.reverse tree.order |> List.take 2 |> List.reverse |> List.reverse |> (\keys -> "nope" :: keys)))
                    ]
                    ()
        ]



-- REVIEW FIXES


reviewTests : Test
reviewTests =
    describe "after the review"
        [ test "a popup that opened before the nodes arrived opens on the value when they have" <|
            \_ ->
                let
                    value =
                        Cascader.setValue ids [ "europe", "norway", "bergen" ] field

                    waiting =
                        Cascader.view CS [ Cascader.label "Place", Cascader.remote Loading ] value

                    opened =
                        feed (Drive.fire [ Selector.id "place" ] (Drive.key "Enter") waiting) value

                    arrived =
                        html [] opened
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ itemId 2 1, attr "aria-selected" "true", attr "aria-level" "3" ] arrived)
                    , \_ -> Expect.equal (Just "place-c2-1") (activeId opened)
                    ]
                    ()
        , test "a path whose nodes the application renamed is shown with the new labels" <|
            \_ ->
                let
                    chosen =
                        openField |> press "End" |> press "Enter"

                    renamed =
                        [ Picking.leaf ids "africa" "Africa (renamed)" ]
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-sr-only", Selector.text "Africa" ] (html [] chosen))
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-sr-only", Selector.text "Africa (renamed)" ] (Cascader.view CS [ Cascader.label "Place", Cascader.nodes renamed ] chosen))
                    ]
                    ()
        , test "the labels of a path are found by walking only the nodes along it" <|
            \_ ->
                Expect.equal
                    [ Just [ "Europe", "Norway", "Oslo" ], Nothing, Nothing, Nothing, Nothing ]
                    [ Index.followPath [ "europe", "norway", "oslo" ] Trees.cities
                    , Index.followPath [ "norway", "oslo" ] Trees.cities
                    , Index.followPath [ "europe", "oslo" ] Trees.cities
                    , Index.followPath [ "asia", "japan", "tokyo" ] Trees.cities
                    , Index.followPath [] Trees.cities
                    ]
        , test "a key that is part of an input method composition is left alone" <|
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
                Expect.all
                    [ \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "place-search" ] composing (html [] openField))
                    , \_ -> Expect.notEqual Nothing (Drive.fire [ Selector.id "place-search" ] (Drive.key "Enter") (html [] openField))
                    ]
                    ()
        ]
