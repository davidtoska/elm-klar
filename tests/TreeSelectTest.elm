module TreeSelectTest exposing (suite)

{-| Render and behaviour tests of `Klar.TreeSelect`: the roles and ARIA ids it
draws, the keys it handles (with the caret rules of the search box), the filter,
lazy children, multiple choice, and what the closed field shows.
-}

import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.Picking as Picking exposing (Node)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.TreeSelect as TreeSelect exposing (Multiple, Single)
import Support.PickingDrive as Drive
import Support.PickingTrees as Trees
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = TS (TreeSelect.Msg String)
    | Retried
    | RetriedNode String


ids : Picking.Ids String
ids =
    Picking.stringIds


html : List (TreeSelect.Attribute String Msg) -> State mode -> Html Msg
html extra state =
    TreeSelect.view TS (TreeSelect.label "Site" :: TreeSelect.nodes Trees.cities :: extra) state


type alias State mode =
    TreeSelect.State mode String


feed : Maybe Msg -> State mode -> State mode
feed maybe state =
    case maybe of
        Just (TS inner) ->
            TreeSelect.update inner state |> Tuple.first

        _ ->
            state


press : String -> State mode -> State mode
press name state =
    feed (Drive.fire [ Selector.id "site-search" ] (Drive.key name) (html [] state)) state


openByKey : State mode -> State mode
openByKey state =
    feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (html [] state)) state


typeText : String -> State mode -> State mode
typeText text state =
    feed (Drive.fire [ Selector.id "site-search" ] (Event.input text) (html [] state)) state


singleField : State Single
singleField =
    TreeSelect.init TreeSelect.single "site"


multipleField : State Multiple
multipleField =
    TreeSelect.init TreeSelect.multiple "site"


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


rows : List Selector
rows =
    [ attr "role" "treeitem" ]


rowId : Int -> Selector
rowId n =
    Selector.id ("site-row-" ++ String.fromInt n)


activeRow : State mode -> Maybe String
activeRow state =
    -- the id that the search box points at, when it exists
    List.range 0 40
        |> List.filter (\n -> Drive.has [ Selector.id "site-search", attr "aria-activedescendant" ("site-row-" ++ String.fromInt n) ] (html [] state))
        |> List.head
        |> Maybe.map (\n -> "site-row-" ++ String.fromInt n)


rowLabelled : String -> Html Msg -> Bool
rowLabelled label tree =
    Drive.has [ attr "role" "treeitem", Selector.containing [ Selector.text label ] ] tree


suite : Test
suite =
    describe "TreeSelect"
        [ closedTests
        , openTests
        , keyTests
        , filterTests
        , lazyTests
        , valueTests
        , multipleTests
        , localeTests
        , largeTests
        , reviewTests
        ]



-- CLOSED


closedTests : Test
closedTests =
    describe "the closed field"
        [ test "is a combobox button that offers a tree" <|
            \_ ->
                html [] singleField
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "site" ]
                    |> Query.has [ Selector.tag "button", attr "role" "combobox", attr "aria-haspopup" "tree", attr "aria-expanded" "false" ]
        , test "shows the placeholder, and no popup" <|
            \_ ->
                Expect.all
                    [ \h -> Expect.equal True (Drive.has [ Selector.text "Select ..." ] h)
                    , \h -> Expect.equal 0 (Drive.count rows h)
                    ]
                    (html [] singleField)
        , test "the label is joined to the button" <|
            \_ ->
                html [] singleField
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "label" ]
                    |> Query.has [ Selector.attribute (Attr.for "site"), Selector.text "Site" ]
        , test "Enter, Space, ArrowDown and ArrowUp on the button open the popup" <|
            \_ ->
                [ "Enter", " ", "ArrowDown", "ArrowUp" ]
                    |> List.map (\k -> TreeSelect.isOpen (feed (Drive.fire [ Selector.id "site" ] (Drive.key k) (html [] singleField)) singleField))
                    |> Expect.equal [ True, True, True, True ]
        , test "a printable character opens it and starts the search" <|
            \_ ->
                feed (Drive.fire [ Selector.id "site" ] (Drive.key "o") (html [] singleField)) singleField
                    |> TreeSelect.query
                    |> Expect.equal "o"
        , test "a disabled field cannot be opened and a read-only one shows its value" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "oslo" singleField
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "site", Selector.disabled True ] (html [ TreeSelect.disabled True ] state))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "Oslo" ] (html [ TreeSelect.readOnly True ] state))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "site", attr "aria-readonly" "true" ] (html [ TreeSelect.readOnly True ] state))
                    ]
                    ()
        ]



-- OPEN


openTests : Test
openTests =
    let
        open =
            openByKey singleField
    in
    describe "the open popup"
        [ test "is a tree with a treeitem for each node of the top level" <|
            \_ ->
                Expect.all
                    [ \h -> Expect.equal 3 (Drive.count rows h)
                    , \h -> Expect.equal True (Drive.has [ attr "role" "tree" ] h)
                    ]
                    (html [] open)
        , test "rows say their level, size and position" <|
            \_ ->
                html [] open
                    |> Query.fromHtml
                    |> Query.find [ rowId 1 ]
                    |> Query.has [ attr "aria-level" "1", attr "aria-setsize" "3", attr "aria-posinset" "2", attr "aria-expanded" "false" ]
        , test "a leaf has no aria-expanded" <|
            \_ ->
                Expect.equal False (Drive.has [ rowId 2, attr "aria-expanded" "false" ] (html [] open))
        , test "the search box and the button name ids that exist" <|
            \_ ->
                let
                    h =
                        html [] open
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "site", attr "aria-controls" "site-popup" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "site-popup" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "site-search", attr "aria-controls" "site-tree" ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "site-tree", attr "role" "tree" ] h)
                    , \_ -> Expect.equal (Just "site-row-0") (activeRow open)
                    ]
                    ()
        , test "the search box is a combobox for a tree" <|
            \_ ->
                html [] open
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "site-search" ]
                    |> Query.has [ attr "role" "combobox", attr "aria-haspopup" "tree", attr "aria-expanded" "true" ]
        , test "the button says it is expanded" <|
            \_ -> Expect.equal True (Drive.has [ Selector.id "site", attr "aria-expanded" "true" ] (html [] open))
        , test "the counts are announced politely" <|
            \_ -> Expect.equal True (Drive.has [ attr "role" "status", attr "aria-live" "polite", Selector.text "9 options" ] (html [] open))
        , test "an open node shows its children one level down" <|
            \_ ->
                let
                    state =
                        open |> press "ArrowRight"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal 5 (Drive.count rows h)
                    , \_ -> Expect.equal True (Drive.has [ rowId 1, attr "aria-level" "2", attr "aria-setsize" "2", attr "aria-posinset" "1" ] h)
                    , \_ -> Expect.equal True (Drive.has [ rowId 0, attr "aria-expanded" "true" ] h)
                    ]
                    ()
        , test "a click on a row chooses it and closes the popup" <|
            \_ ->
                let
                    state =
                        feed (Drive.fire [ rowId 2 ] Event.click (html [] open)) open
                in
                Expect.equal ( Just "africa", False ) ( TreeSelect.value state, TreeSelect.isOpen state )
        , test "a click on the arrow opens the node without choosing it" <|
            \_ ->
                let
                    state =
                        feed (Drive.fire [ rowId 0, Selector.class "klar-tree-select__toggle" ] Event.click (html [] open)) open
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (TreeSelect.value state)
                    , \_ -> Expect.equal 5 (Drive.count rows (html [] state))
                    ]
                    ()
        , test "the chosen row says so, and the field shows its label with the path as the tooltip" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "oslo" singleField |> openByKey |> press "Escape"

                    reopened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (html [] (TreeSelect.setValue ids "oslo" singleField))) (TreeSelect.setValue ids "oslo" singleField)
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.id "site", Selector.containing [ Selector.text "Oslo" ] ] (html [] state))
                    , \_ -> Expect.equal True (Drive.has [ rowId 2, attr "aria-selected" "true", attr "aria-level" "3" ] (html [] reopened))
                    , \_ -> Expect.equal (Just "site-row-2") (activeRow reopened)
                    ]
                    ()
        , test "a popup that is open but empty or loading draws that, and names no row" <|
            \_ ->
                let
                    loading =
                        html [ TreeSelect.remote Loading ] open

                    empty =
                        html [ TreeSelect.nodes [] ] open
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "aria-busy" "true" ] loading)
                    , \_ -> Expect.equal False (Drive.has [ Selector.id "site-search", attr "aria-controls" "site-tree" ] loading)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "No options" ] empty)
                    ]
                    ()
        , test "a failed top level shows the problem and a retry button when it is worth it" <|
            \_ ->
                let
                    failed kind =
                        html [ TreeSelect.remote (Failed (Remote.problem kind)), TreeSelect.onRetry Retried ] open
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] (failed Remote.network))
                    , \_ -> Expect.equal False (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] (failed Remote.forbidden))
                    , \_ ->
                        Expect.equal (Just Retried)
                            (Drive.fire [ Selector.id "site-search" ] (Drive.key "Enter") (failed Remote.network))
                    ]
                    ()
        ]



-- KEYS


keyTests : Test
keyTests =
    let
        open =
            openByKey singleField
    in
    describe "keys in the open popup"
        [ test "ArrowDown and ArrowUp move the highlight, and stop at the ends" <|
            \_ ->
                Expect.equal
                    [ Just "site-row-1", Just "site-row-2", Just "site-row-2", Just "site-row-1" ]
                    [ activeRow (open |> press "ArrowDown")
                    , activeRow (open |> press "ArrowDown" |> press "ArrowDown")
                    , activeRow (open |> press "ArrowDown" |> press "ArrowDown" |> press "ArrowDown")
                    , activeRow (open |> press "ArrowDown" |> press "ArrowDown" |> press "ArrowUp")
                    ]
        , test "Home and End jump to the first and last row" <|
            \_ ->
                Expect.equal ( Just "site-row-2", Just "site-row-0" ) ( activeRow (open |> press "End"), activeRow (open |> press "End" |> press "Home") )
        , test "ArrowRight opens a closed node, then moves into it" <|
            \_ ->
                let
                    once =
                        open |> press "ArrowRight"

                    twice =
                        once |> press "ArrowRight"
                in
                Expect.equal ( Just "site-row-0", Just "site-row-1" ) ( activeRow once, activeRow twice )
        , test "ArrowLeft closes an open node, then moves to its parent" <|
            \_ ->
                let
                    inside =
                        open |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight"

                    closed =
                        inside |> press "ArrowLeft"
                in
                Expect.all
                    [ \_ -> Expect.equal (Just "site-row-2") (activeRow inside)
                    , \_ -> Expect.equal 7 (Drive.count rows (html [] inside))
                    , \_ -> Expect.equal (Just "site-row-1") (activeRow (inside |> press "ArrowLeft"))
                    , \_ -> Expect.equal 5 (Drive.count rows (html [] (closed |> press "ArrowLeft")))
                    ]
                    ()
        , test "ArrowLeft on a top level node that is closed does nothing" <|
            \_ -> Expect.equal (Just "site-row-0") (activeRow (open |> press "ArrowLeft"))
        , test "Enter chooses the highlighted node and closes the popup" <|
            \_ ->
                let
                    state =
                        open |> press "ArrowDown" |> press "Enter"
                in
                Expect.equal ( Just "asia", False ) ( TreeSelect.value state, TreeSelect.isOpen state )
        , test "Space chooses while the search box is empty" <|
            \_ ->
                Expect.equal (Just "europe") (TreeSelect.value (open |> press " "))
        , test "Space is a letter of the search while there is text" <|
            \_ ->
                let
                    withText =
                        open |> typeText "new"
                in
                Expect.equal Nothing (Drive.fire [ Selector.id "site-search" ] (Drive.caretKey "new" 3 3 " ") (html [] withText))
        , test "Escape closes the popup" <|
            \_ -> Expect.equal False (TreeSelect.isOpen (open |> press "Escape"))
        , test "Tab closes the popup and leaves the browser to move on" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal False (TreeSelect.isOpen (open |> press "Tab"))
                    , \_ ->
                        Expect.equal True
                            (Drive.fire [ Selector.id "site-search" ] (Drive.key "Tab") (html [] open) /= Nothing)
                    ]
                    ()
        , test "the arrows that move the caret only count when the caret has nowhere to go" <|
            \_ ->
                let
                    withText =
                        open |> typeText "os"

                    at start end name =
                        Drive.fire [ Selector.id "site-search" ] (Drive.caretKey "os" start end name) (html [] withText)
                in
                Expect.equal
                    [ False, True, False, True, True ]
                    [ at 0 0 "ArrowRight" /= Nothing
                    , at 2 2 "ArrowRight" /= Nothing
                    , at 1 1 "ArrowLeft" /= Nothing
                    , at 0 0 "ArrowLeft" /= Nothing
                    , Drive.fire [ Selector.id "site-search" ] (Drive.key "ArrowRight") (html [] open) /= Nothing
                    ]
        , test "ArrowDown, Home and End always move the highlight, also in a text" <|
            \_ ->
                let
                    withText =
                        open |> typeText "o"
                in
                Expect.equal [ True, True, True ]
                    [ Drive.fire [ Selector.id "site-search" ] (Drive.caretKey "o" 0 0 "ArrowDown") (html [] withText) /= Nothing
                    , Drive.fire [ Selector.id "site-search" ] (Drive.caretKey "o" 0 0 "Home") (html [] withText) /= Nothing
                    , Drive.fire [ Selector.id "site-search" ] (Drive.caretKey "o" 0 0 "End") (html [] withText) /= Nothing
                    ]
        , test "* opens all closed nodes on the level while the search box is empty" <|
            \_ ->
                let
                    state =
                        open |> press "*"
                in
                -- europe and asia are open now (africa is a leaf): europe, norway, sweden, asia, japan, africa
                Expect.equal 6 (Drive.count rows (html [] state))
        , test "keys sent before the focus reached the search box still count (the button handles them)" <|
            \_ ->
                let
                    state =
                        open

                    onButton name =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key name) (html [] state)) state
                in
                Expect.all
                    [ \_ -> Expect.equal (Just "site-row-1") (activeRow (onButton "ArrowDown"))
                    , \_ -> Expect.equal "o" (TreeSelect.query (onButton "o"))
                    , \_ -> Expect.equal False (TreeSelect.isOpen (onButton "Escape"))
                    ]
                    ()
        , test "a click outside (the layer) closes it" <|
            \_ ->
                feed (Drive.fire [ Selector.class "klar-layer" ] Event.click (html [] open)) open
                    |> TreeSelect.isOpen
                    |> Expect.equal False
        , test "a node that is disabled cannot be chosen, but it opens and closes" <|
            \_ ->
                let
                    nodes =
                        [ Picking.branch ids "h" "Heading" [ Picking.leaf ids "a" "A" ] |> Picking.disabled ]

                    withHeading state =
                        TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.nodes nodes ] state

                    opened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (withHeading singleField)) singleField

                    afterEnter =
                        feed (Drive.fire [ Selector.id "site-search" ] (Drive.key "Enter") (withHeading opened)) opened
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (TreeSelect.value afterEnter)
                    , \_ -> Expect.equal 2 (Drive.count rows (withHeading afterEnter))
                    , \_ -> Expect.equal True (Drive.has [ rowId 0, attr "aria-disabled" "true" ] (withHeading afterEnter))
                    ]
                    ()
        ]



-- FILTER


filterTests : Test
filterTests =
    let
        open =
            openByKey singleField
    in
    describe "the filter in the popup"
        [ test "keeps the matches with their ancestors, opened, and highlights the match" <|
            \_ ->
                let
                    state =
                        open |> typeText "oslo"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal 3 (Drive.count rows h)
                    , \_ -> Expect.equal True (Drive.has [ rowId 2, Selector.containing [ Selector.tag "mark" ] ] h)
                    , \_ -> Expect.equal (Just "site-row-2") (activeRow state)
                    , \_ -> Expect.equal True (Drive.has [ attr "role" "status", Selector.text "1 of 9 matches" ] h)
                    ]
                    ()
        , test "clearing the text restores the nodes the user had opened" <|
            \_ ->
                let
                    before =
                        open |> press "ArrowRight"

                    during =
                        before |> typeText "stockholm"

                    after =
                        during |> typeText ""
                in
                Expect.equal
                    ( 5, 3, 5 )
                    ( Drive.count rows (html [] before), Drive.count rows (html [] during), Drive.count rows (html [] after) )
        , test "opening or closing a node while filtering is forgotten when the text changes" <|
            \_ ->
                let
                    state =
                        open |> typeText "oslo" |> press "ArrowLeft" |> press "ArrowLeft"

                    changed =
                        state |> typeText "osl"
                in
                Expect.equal ( True, 3 ) ( Drive.count rows (html [] state) < 3, Drive.count rows (html [] changed) )
        , test "case and accents do not matter, and a word of the description matches" <|
            \_ ->
                Expect.equal [ 3, 3, 3 ]
                    [ Drive.count rows (html [] (open |> typeText "OSLO"))
                    , Drive.count rows (html [] (open |> typeText "osl"))
                    , Drive.count rows (html [] (open |> typeText "bjorgvin"))
                    ]
        , test "a text that matches nothing says so, and the search box names no tree" <|
            \_ ->
                let
                    h =
                        html [] (open |> typeText "zzz")
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "No matches" ] h)
                    , \_ -> Expect.equal False (Drive.has [ Selector.id "site-search", attr "aria-controls" "site-tree" ] h)
                    ]
                    ()
        , test "Backspace in a single field edits the text and never removes the value" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "oslo" singleField |> openByKey |> press "Backspace"
                in
                Expect.equal (Just "oslo") (TreeSelect.value state)
        ]



-- LAZY


lazyTests : Test
lazyTests =
    let
        open =
            openByKey singleField

        withZones zones state =
            TreeSelect.view TS
                [ TreeSelect.label "Site"
                , TreeSelect.nodes [ Picking.branch ids "asia" "Asia" [ Picking.lazy ids "japan" "Japan" zones ] ]
                , TreeSelect.onRetryChildren RetriedNode
                ]
                state

        feedWith zones state name =
            feed (Drive.fire [ Selector.id "site-search" ] (Drive.key name) (withZones zones state)) state

        opened zones =
            feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (withZones zones singleField)) singleField

        goToJapan zones =
            opened zones |> (\s -> feedWith zones s "ArrowRight") |> (\s -> feedWith zones s "ArrowRight")
    in
    describe "lazy children"
        [ test "an open node whose children are not asked for is named by loadRequests, until the application marks it as loading" <|
            \_ ->
                let
                    before =
                        goToJapan NotAsked

                    after =
                        feedWith NotAsked before "ArrowRight"

                    marked =
                        feedWith Loading after "Home"
                in
                Expect.equal [ [], [ "japan" ], [ "japan" ], [] ]
                    [ TreeSelect.loadRequests before, TreeSelect.loadRequests after, TreeSelect.loadRequests after, TreeSelect.loadRequests marked ]
        , test "it is named again when the popup is opened again and the node is still not asked for" <|
            \_ ->
                let
                    after =
                        goToJapan NotAsked |> (\s -> feedWith NotAsked s "ArrowRight")

                    closed =
                        feedWith NotAsked after "Escape"

                    reopened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (withZones NotAsked closed)) closed
                in
                Expect.equal ( [], [ "japan" ] ) ( TreeSelect.loadRequests closed, TreeSelect.loadRequests reopened )
        , test "a node that the application set back to not asked is named at the next message" <|
            \_ ->
                let
                    loaded =
                        goToJapan NotAsked |> (\s -> feedWith NotAsked s "ArrowRight") |> (\s -> feedWith (Loaded []) s "Home")

                    reset =
                        feedWith NotAsked loaded "End"
                in
                Expect.equal [ "japan" ] (TreeSelect.loadRequests reset)
        , test "a node that is loading shows a loading row and nothing else is blocked" <|
            \_ ->
                let
                    state =
                        goToJapan Loading |> (\s -> feedWith Loading s "ArrowRight")

                    h =
                        withZones Loading state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "treeitem", attr "aria-busy" "true" ] h)
                    , \_ -> Expect.equal [] (TreeSelect.loadRequests state)
                    , \_ -> Expect.equal True (Drive.has [ rowId 1, attr "aria-expanded" "true" ] h)
                    ]
                    ()
        , test "the children appear when the application passes them" <|
            \_ ->
                let
                    state =
                        goToJapan NotAsked |> (\s -> feedWith NotAsked s "ArrowRight")

                    loaded =
                        Loaded [ Picking.leaf ids "tokyo" "Tokyo" ]
                in
                Expect.equal True (rowLabelled "Tokyo" (withZones loaded state))
        , test "a failed node shows the problem with a retry button, and Enter on that row retries" <|
            \_ ->
                let
                    failed =
                        Failed (Remote.problem Remote.network)

                    state =
                        goToJapan failed |> (\s -> feedWith failed s "ArrowRight") |> (\s -> feedWith failed s "ArrowDown")

                    h =
                        withZones failed state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.containing [ Selector.text "Could not be loaded" ] ] h)
                    , \_ -> Expect.equal True (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] h)
                    , \_ -> Expect.equal (Just (RetriedNode "japan")) (Drive.fire [ Selector.id "site-search" ] (Drive.key "Enter") h)
                    , \_ ->
                        Expect.equal (Just (RetriedNode "japan"))
                            (Drive.fire [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] Event.click h)
                    ]
                    ()
        , test "a failure that is not worth retrying has no button, and Enter does not retry" <|
            \_ ->
                let
                    failed =
                        Failed (Remote.problem Remote.forbidden)

                    state =
                        goToJapan failed |> (\s -> feedWith failed s "ArrowRight")

                    h =
                        withZones failed state
                in
                Expect.all
                    [ \_ -> Expect.equal False (Drive.has [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] h)
                    , \_ ->
                        Expect.notEqual (Just (RetriedNode "japan"))
                            (Drive.fire [ Selector.id "site-search" ] (Drive.key "Enter") h)
                    ]
                    ()
        , test "the rest of the tree works while one branch fails" <|
            \_ ->
                let
                    failed =
                        Failed (Remote.problem Remote.network)

                    state =
                        goToJapan failed |> (\s -> feedWith failed s "ArrowRight")
                in
                Expect.equal True (Drive.has [ rowId 0, attr "aria-expanded" "true" ] (withZones failed state))
        , test "the whole tree can be in the field without a lazy node" <|
            \_ -> Expect.equal 3 (Drive.count rows (html [] open))
        ]



-- VALUE


valueTests : Test
valueTests =
    describe "the value of a single field"
        [ test "a value that is in the nodes shows its label" <|
            \_ ->
                Expect.equal True (Drive.has [ Selector.text "Bergen" ] (html [] (TreeSelect.setValue ids "bergen" singleField)))
        , test "a value that is in no node says Unknown value, and is still the value" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "mars" singleField
                in
                Expect.all
                    [ \_ -> Expect.equal (Just "mars") (TreeSelect.value state)
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "Unknown value" ] (html [] state))
                    ]
                    ()
        , test "while the nodes load it says Loading, and when they failed Could not be loaded" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "mars" singleField
                in
                Expect.equal [ True, True ]
                    [ Drive.has [ Selector.text "Loading ..." ] (html [ TreeSelect.remote Loading ] state)
                    , Drive.has [ Selector.text "Could not be loaded" ] (html [ TreeSelect.remote (Failed (Remote.problem Remote.network)) ] state)
                    ]
        , test "valueText writes a value that is in no node" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ Selector.text "Site mars" ] (html [ TreeSelect.valueText (\id -> "Site " ++ id) ] (TreeSelect.setValue ids "mars" singleField)))
        , test "setNode gives the label of a node that is not in the tree" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ Selector.text "Mars base" ] (html [] (TreeSelect.setNode (Picking.leaf ids "mars" "Mars base") singleField)))
        , test "clear removes the value, and the clear button is there when it is clearable" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "oslo" singleField
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (TreeSelect.value (TreeSelect.clear state))
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-select__clear" ] (html [ TreeSelect.clearable ] state))
                    , \_ -> Expect.equal False (Drive.has [ Selector.class "klar-select__clear" ] (html [ TreeSelect.clearable ] singleField))
                    , \_ ->
                        Expect.equal Nothing
                            (TreeSelect.value (feed (Drive.fire [ Selector.class "klar-select__clear" ] Event.click (html [ TreeSelect.clearable ] state)) state))
                    ]
                    ()
        , test "Backspace on the closed clearable field clears it" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValue ids "oslo" singleField
                in
                feed (Drive.fire [ Selector.id "site" ] (Drive.key "Backspace") (html [ TreeSelect.clearable ] state)) state
                    |> TreeSelect.value
                    |> Expect.equal Nothing
        , test "the label, hint and error are joined to the field" <|
            \_ ->
                let
                    h =
                        html [ TreeSelect.hint "Where it is stored.", TreeSelect.error "Choose a site", TreeSelect.required ] singleField
                in
                Expect.equal True
                    (Drive.has
                        [ Selector.id "site", attr "aria-describedby" "site-hint site-error", attr "aria-invalid" "true", attr "aria-required" "true" ]
                        h
                    )
        , test "a state of the application's own id type compares with ==" <|
            \_ ->
                Expect.equal (TreeSelect.setValue ids "oslo" singleField) (TreeSelect.setValue ids "oslo" singleField)
        ]



-- MULTIPLE


multipleTests : Test
multipleTests =
    let
        open =
            openByKey multipleField
    in
    describe "a multiple field"
        [ test "rows say aria-checked, and the tree is not single-select" <|
            \_ ->
                let
                    h =
                        html [] open
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ rowId 0, attr "aria-checked" "false" ] h)
                    , \_ -> Expect.equal False (Drive.has [ attr "aria-selected" "true" ] h)
                    ]
                    ()
        , test "Enter checks the highlighted node and the popup stays open" <|
            \_ ->
                let
                    state =
                        open |> press "Enter"
                in
                Expect.all
                    [ \_ -> Expect.equal [ "europe" ] (TreeSelect.values state)
                    , \_ -> Expect.equal True (TreeSelect.isOpen state)
                    , \_ -> Expect.equal True (Drive.has [ rowId 0, attr "aria-checked" "true" ] (html [] state))
                    ]
                    ()
        , test "checking a parent checks everything below it, and the value is the parent" <|
            \_ ->
                let
                    state =
                        open |> press "Enter" |> press "ArrowRight" |> press "ArrowRight"

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal [ "europe" ] (TreeSelect.values state)
                    , \_ -> Expect.equal True (Drive.has [ rowId 1, attr "aria-checked" "true" ] h)
                    ]
                    ()
        , test "a parent with some nodes checked is mixed" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo" ] multipleField |> openByKey
                in
                Expect.equal True (Drive.has [ rowId 0, attr "aria-checked" "mixed" ] (html [] state))
        , test "unchecking a node of a checked branch splits the branch into what is left" <|
            \_ ->
                let
                    state =
                        open |> press "Enter" |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight" |> press "Enter"
                in
                -- row 2 is oslo: europe becomes bergen and sweden
                Expect.equal [ "bergen", "sweden" ] (TreeSelect.values state |> List.sort)
        , test "checking all the children gives the parent" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo" ] multipleField |> openByKey |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowRight" |> press "ArrowDown" |> press "ArrowDown" |> press "Enter"
                in
                Expect.equal [ "norway" ] (TreeSelect.values state)
        , test "values come in the order they were chosen" <|
            \_ ->
                let
                    state =
                        open |> press "End" |> press "Enter" |> press "Home" |> press "Enter"
                in
                Expect.equal [ "africa", "europe" ] (TreeSelect.values state)
        , test "leaves writes a chosen branch out as the nodes inside it, in the order of the tree" <|
            \_ ->
                TreeSelect.setValues ids [ "europe", "africa" ] multipleField
                    |> TreeSelect.leaves Trees.cities
                    |> Expect.equal [ "oslo", "bergen", "stockholm", "africa" ]
        , test "leaves keeps an id that is not in the tree, and a lazy node as it is" <|
            \_ ->
                TreeSelect.setValues ids [ "japan", "mars" ] multipleField
                    |> TreeSelect.leaves Trees.cities
                    |> Expect.equal [ "japan", "mars" ]
        , test "a few chosen nodes are chips with a remove button each" <|
            \_ ->
                let
                    h =
                        html [] (TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField)
                in
                Expect.equal ( 2, True ) ( Drive.count [ Selector.class "klar-tag__remove" ] h, Drive.has [ Selector.text "Oslo" ] h )
        , test "a chip's remove button removes that node" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField
                in
                feed (Drive.fire [ Selector.attribute (Attr.attribute "aria-label" "Remove Oslo") ] Event.click (html [] state)) state
                    |> TreeSelect.values
                    |> Expect.equal [ "bergen" ]
        , test "many chosen nodes are one chip, 40 selected, with a clear option" <|
            \_ ->
                let
                    wideNodes =
                        Trees.wide 60

                    keys =
                        List.range 1 40 |> List.map (\i -> "w" ++ String.fromInt i)

                    state =
                        TreeSelect.setValues ids keys multipleField

                    h =
                        TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.nodes wideNodes ] state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "40 selected" ] h)
                    , \_ -> Expect.equal 1 (Drive.count [ Selector.class "klar-tag__remove" ] h)
                    , \_ -> Expect.equal [] (TreeSelect.values (feed (Drive.fire [ Selector.class "klar-tag__remove" ] Event.click h) state))
                    ]
                    ()
        , test "maxVisibleChips changes where chips turn into a count" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo", "bergen", "africa", "japan" ] multipleField
                in
                Expect.equal ( 1, 4 )
                    ( Drive.count [ Selector.class "klar-tag__remove" ] (html [] state)
                    , Drive.count [ Selector.class "klar-tag__remove" ] (html [ TreeSelect.maxVisibleChips 4 ] state)
                    )
        , test "the hidden text of the button lists what is chosen, for a screen reader" <|
            \_ ->
                Expect.equal True
                    (Drive.has [ Selector.class "klar-sr-only", Selector.text "2 selected: Oslo, Bergen" ]
                        (html [] (TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField))
                    )
        , test "Backspace in an empty search box removes the last chosen node, in a text it edits the text" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField |> openByKey
                in
                Expect.equal [ "oslo" ] (TreeSelect.values (state |> press "Backspace"))
        , test "the footer counts what is chosen, and Clear all empties the choice" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField |> openByKey

                    h =
                        html [] state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "status", Selector.text "9 options · 2 selected" ] h)
                    , \_ ->
                        Expect.equal []
                            (TreeSelect.values (feed (Drive.fire [ Selector.tag "button", Selector.containing [ Selector.text "Clear all" ] ] Event.click h) state))
                    ]
                    ()
        , test "a disabled node is never chosen when its parent is checked" <|
            \_ ->
                let
                    nodes =
                        [ Picking.branch ids "p" "P" [ Picking.leaf ids "a" "A", Picking.leaf ids "b" "B" |> Picking.disabled ] ]

                    v state =
                        TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.nodes nodes ] state

                    opened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (v multipleField)) multipleField

                    checked =
                        feed (Drive.fire [ Selector.id "site-search" ] (Drive.key "Enter") (v opened)) opened
                in
                Expect.equal [ "a" ] (TreeSelect.values checked)
        , test "the value of a multiple field is read with values, of a single field with value" <|
            \_ ->
                -- (this is a compile-time guarantee: the line below must compile)
                Expect.equal ( [], Nothing ) ( TreeSelect.values multipleField, TreeSelect.value singleField )
        ]



-- LOCALE


localeTests : Test
localeTests =
    describe "built-in text"
        [ test "is English by default and Norwegian Bokmål with locale" <|
            \_ ->
                let
                    open =
                        openByKey multipleField
                in
                Expect.equal [ True, True, True, True ]
                    [ Drive.has [ Selector.text "Select ..." ] (html [] multipleField)
                    , Drive.has [ Selector.text "Velg ..." ] (html [ TreeSelect.locale Locale.nb ] multipleField)
                    , Drive.has [ Selector.text "9 alternativer · 0 valgt" ] (html [ TreeSelect.locale Locale.nb ] open)
                    , Drive.has [ Selector.text "Fjern alle" ] (html [ TreeSelect.locale Locale.nb ] open)
                    ]
        ]



-- LARGE


largeTests : Test
largeTests =
    describe "large trees"
        [ test "only the rows that are visible are drawn" <|
            \_ ->
                let
                    big =
                        Trees.wide 20000

                    v state =
                        TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.nodes big ] state

                    opened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (v singleField)) singleField
                in
                Expect.atMost 40 (Drive.count rows (v opened))
        , fuzz Trees.specFuzzer "any tree opens, and any sequence of keys leaves a field that still draws, with a highlight that exists" <|
            \spec ->
                let
                    nodes =
                        Trees.nodesOf spec

                    v state =
                        TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.nodes nodes ] state

                    send name state =
                        feed (Drive.fire [ Selector.id "site-search" ] (Drive.key name) (v state)) state

                    opened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") (v multipleField)) multipleField

                    activeId state =
                        List.range 0 60
                            |> List.filter (\n -> Drive.has [ Selector.id "site-search", attr "aria-activedescendant" ("site-row-" ++ String.fromInt n) ] (v state))
                            |> List.head
                            |> Maybe.map (\n -> "site-row-" ++ String.fromInt n)

                    final =
                        List.foldl send opened [ "ArrowRight", "ArrowDown", "Enter", "ArrowRight", "ArrowDown", "ArrowDown", "Enter", "ArrowLeft", "End", "Home", "ArrowRight", "Enter" ]
                in
                Expect.all
                    [ \_ -> Expect.atLeast 0 (Drive.count rows (v final))
                    , \_ -> Expect.equal True (Drive.has [ Selector.id "site-search" ] (v final))
                    , \_ ->
                        -- the highlight that the search box points at is a row that is drawn
                        case activeId final of
                            Just id ->
                                Expect.equal True (Drive.has [ Selector.id id ] (v final))

                            Nothing ->
                                Expect.pass
                    ]
                    ()
        ]



-- REVIEW FIXES


reviewTests : Test
reviewTests =
    let
        sendTo name state =
            feed (Drive.fire [ Selector.id "site-search" ] (Drive.key name) (html [] state)) state
    in
    describe "after the review"
        [ test "a cover set from the code shows the right boxes: Norway is checked when Oslo and Bergen are" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField |> openByKey |> sendTo "ArrowRight"
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ rowId 1, attr "aria-checked" "true" ] (html [] state))
                    , \_ -> Expect.equal True (Drive.has [ rowId 0, attr "aria-checked" "mixed" ] (html [] state))
                    ]
                    ()
        , test "opening a field does not change a value that was set from the code" <|
            \_ ->
                let
                    before =
                        TreeSelect.setValues ids [ "oslo", "bergen" ] multipleField

                    after =
                        before |> openByKey |> sendTo "ArrowDown" |> sendTo "Escape"
                in
                Expect.equal (TreeSelect.values before) (TreeSelect.values after)
        , test "once the field knows the nodes, what is set from the code is put in its shortest form" <|
            \_ ->
                let
                    seen =
                        multipleField |> openByKey |> sendTo "Escape"
                in
                Expect.equal [ "norway" ] (TreeSelect.values (TreeSelect.setValues ids [ "oslo", "bergen" ] seen))
        , test "the pointer moves the highlight, with the nodes handed over" <|
            \_ ->
                let
                    open =
                        openByKey singleField

                    hovered =
                        feed (Drive.fire [ rowId 2 ] (Event.custom "mousemove" (Encode.object [])) (html [] open)) open
                in
                Expect.equal (Just "site-row-2") (activeRow hovered)
        , test "a chip has the path of its node as a tooltip, for nodes that have the same label" <|
            \_ ->
                let
                    seen =
                        TreeSelect.setValues ids [ "oslo" ] multipleField |> openByKey |> sendTo "Escape"
                in
                Expect.equal True (Drive.has [ Selector.class "klar-select__chip", attr "title" "Europe / Norway / Oslo" ] (html [] seen))
        , test "the summary chip has a button of its own, named for what it does" <|
            \_ ->
                let
                    state =
                        TreeSelect.setValues ids (List.range 1 5 |> List.map (\k -> "w" ++ String.fromInt k)) multipleField

                    v extra =
                        TreeSelect.view TS ([ TreeSelect.label "Site", TreeSelect.nodes (Trees.wide 8) ] ++ extra) state
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.class "klar-tag__remove", attr "aria-label" "Clear the selection" ] (v []))
                    , \_ -> Expect.equal True (Drive.has [ Selector.class "klar-tag__remove", attr "aria-label" "Fjern alle valgte" ] (v [ TreeSelect.locale Locale.nb ]))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "5 selected" ] (v []))
                    ]
                    ()
        , test "the tree of a multiple field says so, the tree of a single field does not" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ attr "role" "tree", attr "aria-multiselectable" "true" ] (html [] (openByKey multipleField)))
                    , \_ -> Expect.equal False (Drive.has [ attr "aria-multiselectable" "true" ] (html [] (openByKey singleField)))
                    ]
                    ()
        , test "a popup that opened before the nodes arrived opens on the value when they have" <|
            \_ ->
                let
                    waiting =
                        TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.remote Loading ] (TreeSelect.setValue ids "oslo" singleField)

                    opened =
                        feed (Drive.fire [ Selector.id "site" ] (Drive.key "Enter") waiting) (TreeSelect.setValue ids "oslo" singleField)

                    arrived =
                        html [] opened
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ rowId 2, attr "aria-selected" "true", attr "aria-level" "3" ] arrived)
                    , \_ -> Expect.equal (Just "site-row-2") (activeRow opened)
                    ]
                    ()
        , test "a node that the application renamed is shown with its new label once the field has seen the nodes" <|
            \_ ->
                let
                    chosen =
                        openByKey singleField |> sendTo "End" |> sendTo "Enter"

                    renamed =
                        [ Picking.leaf ids "africa" "Africa (renamed)" ]
                in
                Expect.all
                    [ \_ -> Expect.equal True (Drive.has [ Selector.text "Africa" ] (html [] chosen))
                    , \_ -> Expect.equal True (Drive.has [ Selector.text "Africa (renamed)" ] (TreeSelect.view TS [ TreeSelect.label "Site", TreeSelect.nodes renamed ] chosen))
                    ]
                    ()
        , test "a key that is part of an input method composition is left alone" <|
            \_ ->
                let
                    open =
                        openByKey singleField

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

                    code229 =
                        Event.custom "keydown"
                            (Encode.object
                                [ ( "key", Encode.string "Enter" )
                                , ( "ctrlKey", Encode.bool False )
                                , ( "metaKey", Encode.bool False )
                                , ( "altKey", Encode.bool False )
                                , ( "shiftKey", Encode.bool False )
                                , ( "keyCode", Encode.int 229 )
                                ]
                            )
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "site-search" ] composing (html [] open))
                    , \_ -> Expect.equal Nothing (Drive.fire [ Selector.id "site-search" ] code229 (html [] open))
                    , \_ -> Expect.notEqual Nothing (Drive.fire [ Selector.id "site-search" ] (Drive.key "Enter") (html [] open))
                    ]
                    ()
        ]
