module DataDisplayFixTest exposing (suite)

{-| Regression tests for four fixes in the data display modules.

  - `Klar.Tree`: keys work on nodes whose ids end in characters that the old
    check on the name of a row mistook for the row itself ("orders.row",
    "x\_row", "dir/row").
  - `Klar.Stat`: a tile that has failed is never a button, so that its retry
    button does not sit inside another button and a click on it cannot send the
    message of the tile; `decimal` and `compact` show an en dash for a number
    that is not finite.
  - `Klar.Chart`: the `aria-value*` attributes of a gauge and a meter carry the
    real numbers, the hidden data table is captioned with the accessible name,
    and a donut honors `legend`.

Every test draws the HTML, finds an element the way a user (or a screen reader)
would, and simulates an event on it, as `TableTest` does.

-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Chart as Chart
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Stat as Stat
import Klar.Tree as Tree
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = TreeMsg Tree.Msg
    | Activated String
    | TileClicked
    | Retried


suite : Test
suite =
    describe "Data display fixes"
        [ treeIdTests
        , treeKeyTests
        , treeNestedTests
        , treePropertyTests
        , statNestingTests
        , statNumberTests
        , chartAriaValueTests
        , chartNameTests
        , chartLegendTests
        ]



-- SHARED


expectErr : Result String a -> Expectation
expectErr result =
    case result of
        Err _ ->
            Expect.pass

        Ok _ ->
            Expect.fail "The element handled the event, but it should not."


expectOk : Result String a -> Expectation
expectOk result =
    case result of
        Ok _ ->
            Expect.pass

        Err problem ->
            Expect.fail problem


{-| The HTML inside a plain wrapper. `Query.find` only looks below the element
it starts from, so the wrapper lets a test find the root of a component too.
-}
inside : Html msg -> Query.Single msg
inside html =
    Query.fromHtml (Html.div [] [ html ])


role : String -> Selector.Selector
role name =
    Selector.attribute (Attr.attribute "role" name)



-- TREE: THE IDS IN THE DOM


treeId : String
treeId =
    "catalog"


{-| Node ids that the first version of the tree could not handle (the first
six: written as DOM ids they end in `_row`) and ids that it could.
-}
awkwardIds : List String
awkwardIds =
    [ "orders.row"
    , "x_row"
    , "dir/row"
    , "_row"
    , "id:row"
    , "a b row"
    , "row"
    , "x-row"
    , "plain"
    ]


nodeLabel : String -> String
nodeLabel id =
    "Node " ++ id


leaves : List Tree.Node
leaves =
    List.map (\id -> Tree.leaf id (nodeLabel id)) awkwardIds


start : Tree.State
start =
    Tree.init treeId


{-| How the tree writes a node id into a DOM id (see the documentation of the
module): letters, digits and "-" stay, every other character becomes `_`, its
code point and `_`.
-}
encode : String -> String
encode raw =
    raw
        |> String.toList
        |> List.map
            (\c ->
                if (Char.isAlphaNum c && Char.toCode c < 128) || c == '-' then
                    String.fromChar c

                else
                    "_" ++ String.fromInt (Char.toCode c) ++ "_"
            )
        |> String.concat


{-| The id of the element of a node (the one that takes the focus).
-}
itemId : String -> String
itemId nodeId =
    treeId ++ "-n-" ++ encode nodeId


{-| The id of the row inside it, which names the node.
-}
nameId : String -> String
nameId nodeId =
    treeId ++ "-l-" ++ encode nodeId


treeHtml : Tree.State -> List Tree.Node -> Html Msg
treeHtml state nodes =
    Tree.view TreeMsg [ Tree.ariaLabel "Catalog", Tree.onActivate Activated ] state nodes


applyMsg : Tree.State -> Msg -> Tree.State
applyMsg state msg =
    case msg of
        TreeMsg treeMsg ->
            Tuple.first (Tree.update treeMsg state)

        _ ->
            state


keyDown : String -> String -> ( String, Encode.Value )
keyDown targetId key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
            ]
        )


plainClick : ( String, Encode.Value )
plainClick =
    Event.custom "click"
        (Encode.object
            [ ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            ]
        )


{-| A key pressed while the element with this DOM id has the focus: the message
that the tree sends, or why it sends none.
-}
press : Tree.State -> List Tree.Node -> String -> String -> Result String Msg
press state nodes targetId key =
    treeHtml state nodes
        |> Query.fromHtml
        |> Query.find [ role "tree" ]
        |> Event.simulate (keyDown targetId key)
        |> Event.toResult


{-| `press`, and then give the message to `Tree.update`.
-}
pressAndUpdate : Tree.State -> List Tree.Node -> String -> String -> Result String Tree.State
pressAndUpdate state nodes targetId key =
    press state nodes targetId key
        |> Result.map (applyMsg state)


{-| The tree turns a key down when it comes from this element, and handles the
same key when it comes from the element of the node. Only the target differs, so
the tree is there, it listens, and it is the target that it does not accept.
-}
expectIgnoredFrom : Tree.State -> List Tree.Node -> String -> String -> String -> Expectation
expectIgnoredFrom state nodes nodeId targetId key =
    Expect.all
        [ \_ -> press state nodes (itemId nodeId) key |> expectOk
        , \_ -> press state nodes targetId key |> expectErr
        ]
        ()


{-| Click the row with this label and give the message to `Tree.update`: the
node is selected and has the keyboard focus, as when a user clicks it.
-}
clickRow : Tree.State -> List Tree.Node -> String -> Result String Tree.State
clickRow state nodes rowLabel =
    treeHtml state nodes
        |> Query.fromHtml
        |> Query.find [ Selector.class "klar-tree__row", Selector.containing [ Selector.exactText rowLabel ] ]
        |> Event.simulate plainClick
        |> Event.toResult
        |> Result.map (applyMsg state)


{-| Click the row with this label, and then check the state that the click gave.
When the click does not work, the test fails with the reason.
-}
afterClick : List Tree.Node -> String -> (Tree.State -> Expectation) -> Expectation
afterClick nodes rowLabel check =
    case clickRow start nodes rowLabel of
        Ok clicked ->
            check clicked

        Err problem ->
            Expect.fail problem


{-| Press these keys one after the other. Every step names the node whose element
has the focus when the key goes down, and the key.
-}
play : List Tree.Node -> Tree.State -> List ( String, String ) -> Result String Tree.State
play nodes state steps =
    List.foldl
        (\( nodeId, key ) result ->
            Result.andThen (\current -> pressAndUpdate current nodes (itemId nodeId) key) result
        )
        (Ok state)
        steps


treeIdTests : Test
treeIdTests =
    describe "Klar.Tree: the ids in the DOM"
        (List.concatMap idTestsFor awkwardIds
            ++ [ test "no id is used twice, even when node ids look like the ids of other nodes" <|
                    \_ ->
                        let
                            tricky =
                                [ "x", "x_row", "x.row", "x-row", "x_95_row", "a", "a_" ]
                                    |> List.map (\id -> Tree.leaf id (nodeLabel id))

                            html =
                                treeHtml start tricky |> Query.fromHtml
                        in
                        Expect.all
                            (List.concatMap
                                (\id ->
                                    [ \_ -> Query.find [ Selector.id (itemId id) ] html |> Query.has [ role "treeitem" ]
                                    , \_ -> Query.find [ Selector.id (nameId id) ] html |> Query.has [ Selector.class "klar-tree__row" ]
                                    ]
                                )
                                [ "x", "x_row", "x.row", "x-row", "x_95_row", "a", "a_" ]
                            )
                            ()
               ]
        )


idTestsFor : String -> List Test
idTestsFor id =
    [ test ("the element of the node " ++ id ++ " has an id of its own and is named by its row") <|
        \_ ->
            treeHtml start leaves
                |> Query.fromHtml
                |> Query.find [ Selector.id (itemId id) ]
                |> Query.has
                    [ role "treeitem"
                    , Selector.attribute (Attr.attribute "aria-labelledby" (nameId id))
                    ]
    , test ("the row of the node " ++ id ++ " is another element with another id") <|
        \_ ->
            treeHtml start leaves
                |> Query.fromHtml
                |> Query.find [ Selector.id (nameId id) ]
                |> Query.has [ Selector.class "klar-tree__row" ]
    ]



-- TREE: THE KEYBOARD


treeKeyTests : Test
treeKeyTests =
    describe "Klar.Tree: keys on nodes with awkward ids"
        (List.concatMap keyTestsFor awkwardIds
            ++ arrowTests
            ++ [ test "Home and End jump to the first and the last node" <|
                    \_ ->
                        clickRow start leaves (nodeLabel "dir/row")
                            |> Result.andThen (\state -> pressAndUpdate state leaves (itemId "dir/row") "End")
                            |> Result.map Tree.focused
                            |> Expect.equal (Ok (Just "plain"))
               , test "Home jumps back to the first node" <|
                    \_ ->
                        clickRow start leaves (nodeLabel "plain")
                            |> Result.andThen (\state -> pressAndUpdate state leaves (itemId "plain") "Home")
                            |> Result.map Tree.focused
                            |> Expect.equal (Ok (Just "orders.row"))
               , test "a key from a control that has no id (a button in the tree) is not a key of the tree" <|
                    \_ ->
                        afterClick leaves (nodeLabel "x_row") <|
                            \state -> expectIgnoredFrom state leaves "x_row" "" "Enter"
               , test "a key from an element somewhere else in the page is not a key of the tree" <|
                    \_ ->
                        afterClick leaves (nodeLabel "x_row") <|
                            \state -> expectIgnoredFrom state leaves "x_row" "other-component" "Enter"
               ]
        )


keyTestsFor : String -> List Test
keyTestsFor id =
    [ test ("Enter activates the node " ++ id) <|
        \_ ->
            clickRow start leaves (nodeLabel id)
                |> Result.andThen (\state -> press state leaves (itemId id) "Enter")
                |> Expect.equal (Ok (Activated id))
    , test ("a key from inside the row of the node " ++ id ++ " is still ignored") <|
        \_ ->
            afterClick leaves (nodeLabel id) <|
                \state -> expectIgnoredFrom state leaves id (nameId id) "Enter"
    ]


{-| ArrowDown and ArrowUp between every two neighbors in the list of awkward ids.
-}
arrowTests : List Test
arrowTests =
    let
        pairs =
            List.map2 Tuple.pair awkwardIds (List.drop 1 awkwardIds)
    in
    List.concatMap
        (\( from, to ) ->
            [ test ("ArrowDown moves from " ++ from ++ " to " ++ to) <|
                \_ ->
                    clickRow start leaves (nodeLabel from)
                        |> Result.andThen (\state -> pressAndUpdate state leaves (itemId from) "ArrowDown")
                        |> Result.map Tree.focused
                        |> Expect.equal (Ok (Just to))
            , test ("ArrowUp moves from " ++ to ++ " to " ++ from) <|
                \_ ->
                    clickRow start leaves (nodeLabel to)
                        |> Result.andThen (\state -> pressAndUpdate state leaves (itemId to) "ArrowUp")
                        |> Result.map Tree.focused
                        |> Expect.equal (Ok (Just from))
            ]
        )
        pairs



-- TREE: BRANCHES WITH AWKWARD IDS


family : List Tree.Node
family =
    [ Tree.branch "dir/row"
        "Dir"
        [ Tree.leaf "dir/row/a.row" "Child A"
        , Tree.leaf "dir/row/b_row" "Child B"
        ]
    ]


treeNestedTests : Test
treeNestedTests =
    describe "Klar.Tree: opening and closing branches with awkward ids"
        [ test "ArrowRight opens a branch" <|
            \_ ->
                clickRow start family "Dir"
                    |> Result.andThen (\state -> play family state [ ( "dir/row", "ArrowRight" ) ])
                    |> Result.map (Tree.isExpanded "dir/row")
                    |> Expect.equal (Ok True)
        , test "ArrowDown then goes into the branch" <|
            \_ ->
                clickRow start family "Dir"
                    |> Result.andThen (\state -> play family state [ ( "dir/row", "ArrowRight" ), ( "dir/row", "ArrowDown" ) ])
                    |> Result.map Tree.focused
                    |> Expect.equal (Ok (Just "dir/row/a.row"))
        , test "ArrowLeft on a child goes back to the parent" <|
            \_ ->
                clickRow start family "Dir"
                    |> Result.andThen
                        (\state ->
                            play family
                                state
                                [ ( "dir/row", "ArrowRight" )
                                , ( "dir/row", "ArrowDown" )
                                , ( "dir/row/a.row", "ArrowLeft" )
                                ]
                        )
                    |> Result.map Tree.focused
                    |> Expect.equal (Ok (Just "dir/row"))
        , test "ArrowLeft on the open parent closes it" <|
            \_ ->
                clickRow start family "Dir"
                    |> Result.andThen
                        (\state ->
                            play family
                                state
                                [ ( "dir/row", "ArrowRight" )
                                , ( "dir/row", "ArrowLeft" )
                                ]
                        )
                    |> Result.map (Tree.isExpanded "dir/row")
                    |> Expect.equal (Ok False)
        , test "a child with an awkward id can be walked to and activated" <|
            \_ ->
                clickRow start family "Dir"
                    |> Result.andThen
                        (\state ->
                            play family
                                state
                                [ ( "dir/row", "ArrowRight" )
                                , ( "dir/row", "ArrowDown" )
                                , ( "dir/row/a.row", "ArrowDown" )
                                ]
                        )
                    |> Result.andThen (\state -> press state family (itemId "dir/row/b_row") "Enter")
                    |> Expect.equal (Ok (Activated "dir/row/b_row"))
        ]



-- TREE: ANY ID


{-| An id that ends in a character that is not a letter, a digit or "-",
followed by `row`: the shape that the first version could not handle.
-}
rowLikeId : Fuzzer String
rowLikeId =
    Fuzz.map2 (\base separator -> base ++ String.fromChar separator ++ "row")
        (Fuzz.stringOfLengthBetween 0 8)
        (Fuzz.oneOfValues [ '.', '_', '/', ' ', ':', '#', '+', '$', 'é', '\u{00A0}' ])


treePropertyTests : Test
treePropertyTests =
    describe "Klar.Tree: any node id"
        [ fuzz rowLikeId "Enter activates a node whose id ends like the name of a row" <|
            \id ->
                let
                    nodes =
                        [ Tree.leaf id "Only node" ]
                in
                clickRow start nodes "Only node"
                    |> Result.andThen (\state -> press state nodes (itemId id) "Enter")
                    |> Expect.equal (Ok (Activated id))
        , fuzz (Fuzz.pair rowLikeId Fuzz.string) "node ids that differ never share a DOM id" <|
            \( first, second ) ->
                if first == second then
                    Expect.pass

                else
                    let
                        html =
                            treeHtml start [ Tree.leaf first "First", Tree.leaf second "Second" ]
                                |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> Query.find [ Selector.id (itemId first) ] html |> Query.has [ role "treeitem" ]
                        , \_ -> Query.find [ Selector.id (itemId second) ] html |> Query.has [ role "treeitem" ]
                        , \_ -> Query.find [ Selector.id (nameId first) ] html |> Query.has [ Selector.class "klar-tree__row" ]
                        , \_ -> Query.find [ Selector.id (nameId second) ] html |> Query.has [ Selector.class "klar-tree__row" ]
                        ]
                        ()
        ]



-- STAT: NO BUTTON IN A BUTTON


retryable : Remote.Problem
retryable =
    Remote.problem Remote.network


notRetryable : Remote.Problem
notRetryable =
    Remote.problem Remote.forbidden


tile : List (Stat.Attribute Msg) -> Query.Single Msg
tile attributes =
    inside (Stat.view (Stat.label "Open orders" :: attributes))


{-| The tile itself, whatever it is: a `div` or a `button` with the class of a
tile.
-}
tileAs : String -> Query.Single Msg -> Query.Single Msg
tileAs tagName =
    Query.find [ Selector.tag tagName, Selector.class "klar-stat" ]


click : Query.Single Msg -> Result String Msg
click single =
    single
        |> Event.simulate Event.click
        |> Event.toResult


{-| The element is there, and it does not listen to clicks. (Without the first
check, an element that is missing would look like one that does not listen.)
-}
expectNoClickOn : List Selector.Selector -> Query.Single Msg -> Expectation
expectNoClickOn selectors single =
    Expect.all
        [ Query.find selectors >> Query.has []
        , Query.find selectors >> click >> expectErr
        ]
        single


failedTile : Query.Single Msg
failedTile =
    tile [ Stat.onClick TileClicked, Stat.onRetry Retried, Stat.failed retryable ]


statNestingTests : Test
statNestingTests =
    describe "Klar.Stat: a failed tile is never a button"
        [ test "a failed tile with onClick is a plain block" <|
            \_ ->
                failedTile
                    |> Expect.all
                        [ tileAs "div" >> Query.has []
                        , Query.hasNot [ Selector.tag "button", Selector.class "klar-stat" ]
                        , Query.hasNot [ Selector.class "klar-stat--interactive" ]
                        ]
        , test "no button sits inside another button" <|
            \_ ->
                failedTile
                    |> Query.hasNot [ Selector.tag "button", Selector.containing [ Selector.tag "button" ] ]
        , test "the retry button is the only control in the tile" <|
            \_ ->
                failedTile
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 1)
                        , Query.find [ Selector.tag "button" ] >> Query.has [ Selector.text "Try again" ]
                        ]
        , test "the retry button is a native button that a keyboard can reach" <|
            \_ ->
                failedTile
                    |> Query.find [ Selector.tag "button" ]
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.type_ "button") ]
                        , Query.hasNot [ Selector.disabled True ]
                        ]
        , test "the failure is still announced to screen readers" <|
            \_ ->
                failedTile
                    |> Query.find [ role "alert" ]
                    |> Query.has [ Selector.text (Remote.title Locale.en retryable) ]
        , test "a click on the retry button sends the retry message and nothing else" <|
            \_ ->
                failedTile
                    |> Query.find [ Selector.tag "button" ]
                    |> click
                    |> Expect.equal (Ok Retried)
        , test "nothing around the retry button listens to clicks, so a click on it cannot bubble into the tile message" <|
            \_ ->
                failedTile
                    |> Expect.all
                        [ expectNoClickOn [ Selector.tag "div", Selector.class "klar-stat" ]
                        , expectNoClickOn [ Selector.class "klar-stat__body" ]
                        , expectNoClickOn [ Selector.class "klar-stat__failure" ]
                        ]
        , test "a failure that is not worth retrying is a plain block too" <|
            \_ ->
                tile [ Stat.onClick TileClicked, Stat.onRetry Retried, Stat.failed notRetryable ]
                    |> Expect.all
                        [ tileAs "div" >> Query.has []
                        , Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 0)
                        ]
        , test "a failure that comes from a Remote is a plain block too" <|
            \_ ->
                tile
                    [ Stat.onClick TileClicked
                    , Stat.onRetry Retried
                    , Stat.remote (Remote.Failure retryable) (\n -> [ Stat.int n ])
                    ]
                    |> Expect.all
                        [ tileAs "div" >> Query.has []
                        , Query.hasNot [ Selector.tag "button", Selector.containing [ Selector.tag "button" ] ]
                        , Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 1)
                        ]
        , test "a failed tile without onClick is unchanged: a block with its retry button" <|
            \_ ->
                tile [ Stat.onRetry Retried, Stat.failed retryable ]
                    |> Expect.all
                        [ tileAs "div" >> Query.has []
                        , Query.find [ Selector.tag "button" ] >> click >> Expect.equal (Ok Retried)
                        ]
        , test "a tile with onClick that has not failed is still a button that sends its message" <|
            \_ ->
                tile [ Stat.int 5, Stat.onClick TileClicked ]
                    |> tileAs "button"
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-stat--interactive" ]
                        , Query.has [ Selector.attribute (Attr.type_ "button") ]
                        , Query.hasNot [ Selector.disabled True ]
                        , click >> Expect.equal (Ok TileClicked)
                        ]
        , test "a loading tile with onClick is still a button" <|
            \_ ->
                tile [ Stat.loading True, Stat.onClick TileClicked ]
                    |> tileAs "button"
                    |> Query.has [ Selector.class "klar-stat--interactive" ]
        , test "the tile is a button again when the data is back" <|
            \_ ->
                tile
                    [ Stat.onClick TileClicked
                    , Stat.remote (Remote.Success 5) (\n -> [ Stat.int n ])
                    ]
                    |> tileAs "button"
                    |> click
                    |> Expect.equal (Ok TileClicked)
        ]



-- STAT: NUMBERS THAT ARE NOT FINITE


shown : Stat.Attribute Msg -> Query.Single Msg
shown number =
    tile [ number ]
        |> Query.find [ Selector.class "klar-stat__value" ]


notFinite : List ( String, Float )
notFinite =
    [ ( "NaN", 0 / 0 )
    , ( "positive infinity", 1 / 0 )
    , ( "negative infinity", negate 1 / 0 )
    ]


statNumberTests : Test
statNumberTests =
    describe "Klar.Stat: decimal and compact with numbers that are not finite"
        (List.concatMap
            (\( name, number ) ->
                [ test ("decimal shows an en dash for " ++ name) <|
                    \_ ->
                        shown (Stat.decimal 1 number)
                            |> Query.has [ Selector.exactText "–" ]
                , test ("decimal without decimals shows an en dash for " ++ name) <|
                    \_ ->
                        shown (Stat.decimal 0 number)
                            |> Query.has [ Selector.exactText "–" ]
                , test ("compact shows an en dash for " ++ name) <|
                    \_ ->
                        shown (Stat.compact number)
                            |> Query.has [ Selector.exactText "–" ]
                , test ("the tile with " ++ name ++ " never writes NaN or Infinity") <|
                    \_ ->
                        tile [ Stat.decimal 2 number, Stat.unit "USD", Stat.compact number ]
                            |> Expect.all
                                [ Query.hasNot [ Selector.text "NaN" ]
                                , Query.hasNot [ Selector.text "Infinity" ]
                                ]
                ]
            )
            notFinite
            ++ [ test "decimal still rounds a finite number" <|
                    \_ -> shown (Stat.decimal 1 14.53) |> Query.has [ Selector.exactText "14.5" ]
               , test "decimal still pads with zeros" <|
                    \_ -> shown (Stat.decimal 2 3) |> Query.has [ Selector.exactText "3.00" ]
               , test "decimal still writes a negative number with a minus sign" <|
                    \_ -> shown (Stat.decimal 2 (negate 3.14159)) |> Query.has [ Selector.exactText "−3.14" ]
               , test "decimal still writes zero" <|
                    \_ -> shown (Stat.decimal 1 0) |> Query.has [ Selector.exactText "0.0" ]
               , test "compact still shortens millions" <|
                    \_ -> shown (Stat.compact 4200000) |> Query.has [ Selector.exactText "4.2M" ]
               , test "compact still writes a number below a million in full" <|
                    \_ -> shown (Stat.compact 12900) |> Query.has [ Selector.exactText "12,900" ]
               , test "a whole number is unchanged" <|
                    \_ -> shown (Stat.int 1284) |> Query.has [ Selector.exactText "1,284" ]
               ]
        )



-- CHART: THE VALUES OF A GAUGE AND A METER


meterRole : Selector.Selector
meterRole =
    role "meter"


{-| A scale and a value, and the text that the three attributes must have. Some
of the cases are beyond ±100000 or finer than 0.01, which the first version
clamped and rounded.
-}
type alias Scale =
    { name : String
    , low : Float
    , high : Float
    , value : Float
    , min : String
    , max : String
    , now : String
    }


valueAttributes : Scale -> List Selector.Selector
valueAttributes scale =
    [ meterRole
    , Selector.attribute (Attr.attribute "aria-valuemin" scale.min)
    , Selector.attribute (Attr.attribute "aria-valuemax" scale.max)
    , Selector.attribute (Attr.attribute "aria-valuenow" scale.now)
    ]


scales : List Scale
scales =
    [ { name = "a wide scale", low = 0, high = 1000000, value = 500000, min = "0", max = "1000000", now = "500000" }
    , { name = "a scale on both sides of zero", low = -250000, high = 250000, value = -123456, min = "-250000", max = "250000", now = "-123456" }
    , { name = "a fine value", low = 0, high = 1, value = 0.123456, min = "0", max = "1", now = "0.123456" }
    , { name = "a very fine value on a small scale", low = 0, high = 0.5, value = 0.0049, min = "0", max = "0.5", now = "0.0049" }
    , { name = "a huge scale", low = 0, high = 1.0e15, value = 1.0e15, min = "0", max = "1000000000000000", now = "1000000000000000" }
    , { name = "the default scale", low = 0, high = 100, value = 82, min = "0", max = "100", now = "82" }
    ]


chartAriaValueTests : Test
chartAriaValueTests =
    describe "Klar.Chart: gauge and meter carry the real values"
        (List.concatMap
            (\scale ->
                [ test ("gauge: " ++ scale.name) <|
                    \_ ->
                        inside (Chart.gauge [ Chart.range scale.low scale.high ] scale.value)
                            |> Query.find (valueAttributes scale)
                            |> Query.has []
                , test ("meter: " ++ scale.name) <|
                    \_ ->
                        inside (Chart.meter [ Chart.range scale.low scale.high ] scale.value)
                            |> Query.find (valueAttributes scale)
                            |> Query.has []
                ]
            )
            scales
            ++ [ test "a gauge value that is not a number counts as the start of the scale" <|
                    \_ ->
                        inside (Chart.gauge [ Chart.range 0 10 ] (0 / 0))
                            |> Query.find (valueAttributes { name = "", low = 0, high = 10, value = 0, min = "0", max = "10", now = "0" })
                            |> Query.has []
               , test "a gauge still has the readable value as its text" <|
                    \_ ->
                        inside (Chart.gauge [ Chart.range 0 1000000, Chart.unit "kr" ] 500000)
                            |> Query.find [ meterRole, Selector.attribute (Attr.attribute "aria-valuetext" "500,000\u{00A0}kr") ]
                            |> Query.has []
               ]
        )



-- CHART: THE NAME OF A CHART AND THE CAPTION OF ITS DATA TABLE


series : List Chart.Series
series =
    [ Chart.series "Orders" [ 1, 2, 3 ] ]


segments : List Chart.Segment
segments =
    [ Chart.segment "Shipped" 3, Chart.segment "Pending" 2 ]


type alias NamedChart =
    { kind : String
    , render : List (Chart.Attribute Msg) -> Html Msg
    , summary : String -> String
    }


{-| Charts with a hidden data table: the text of their accessible name around
the name that the application gives.
-}
namedCharts : List NamedChart
namedCharts =
    [ { kind = "line chart"
      , render = \attributes -> Chart.line (Chart.categories [ "Jan", "Feb", "Mar" ] :: attributes) series
      , summary = \name -> "Line chart. " ++ name ++ ". 1 series, 3 points"
      }
    , { kind = "bar chart"
      , render = \attributes -> Chart.bar (Chart.categories [ "Jan", "Feb", "Mar" ] :: attributes) series
      , summary = \name -> "Bar chart. " ++ name ++ ". 1 series, 3 points"
      }
    , { kind = "donut"
      , render = \attributes -> Chart.donut attributes segments
      , summary = \name -> "Donut chart. " ++ name ++ ". 2 segments"
      }
    ]


{-| The accessible name of the chart and the caption of its data table are the
same text.
-}
expectName : NamedChart -> List (Chart.Attribute Msg) -> String -> Expectation
expectName chart attributes name =
    inside (chart.render attributes)
        |> Expect.all
            [ Query.find [ Selector.tag "caption" ] >> Query.has [ Selector.exactText name ]
            , Query.find [ role "img" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-label" (chart.summary name)) ]
            ]


chartNameTests : Test
chartNameTests =
    describe "Klar.Chart: the caption of the data table and the accessible name agree"
        (List.concatMap
            (\chart ->
                [ test (chart.kind ++ ": ariaLabel wins over the title, in both places") <|
                    \_ ->
                        expectName chart
                            [ Chart.title "Visible title", Chart.ariaLabel "Accessible name" ]
                            "Accessible name"
                , test (chart.kind ++ ": the order of the attributes does not matter") <|
                    \_ ->
                        expectName chart
                            [ Chart.ariaLabel "Accessible name", Chart.title "Visible title" ]
                            "Accessible name"
                , test (chart.kind ++ ": the title is used when there is no ariaLabel") <|
                    \_ ->
                        expectName chart [ Chart.title "Visible title" ] "Visible title"
                , test (chart.kind ++ ": ariaLabel is used when there is no title") <|
                    \_ ->
                        expectName chart [ Chart.ariaLabel "Accessible name" ] "Accessible name"
                ]
            )
            namedCharts
        )



-- CHART: THE LEGEND


legends : Html Msg -> Query.Multiple Msg
legends html =
    inside html |> Query.findAll [ Selector.class "klar-chart__legend" ]


twoSeries : List Chart.Series
twoSeries =
    [ Chart.series "2025" [ 1, 2, 3 ], Chart.series "2026" [ 2, 3, 4 ] ]


chartLegendTests : Test
chartLegendTests =
    describe "Klar.Chart: legend"
        [ test "a donut shows its legend by default" <|
            \_ ->
                legends (Chart.donut [] segments)
                    |> Query.count (Expect.equal 1)
        , test "the legend of a donut lists every slice" <|
            \_ ->
                inside (Chart.donut [] segments)
                    |> Query.findAll [ Selector.class "klar-chart__legend-item" ]
                    |> Query.count (Expect.equal 2)
        , test "a donut shows its legend when asked to" <|
            \_ ->
                legends (Chart.donut [ Chart.legend True ] segments)
                    |> Query.count (Expect.equal 1)
        , test "a donut hides its legend when asked to" <|
            \_ ->
                legends (Chart.donut [ Chart.legend False ] segments)
                    |> Query.count (Expect.equal 0)
        , test "a donut without a legend still has its data table" <|
            \_ ->
                inside (Chart.donut [ Chart.legend False ] segments)
                    |> Query.findAll [ Selector.tag "table" ]
                    |> Query.count (Expect.equal 1)
        , test "a donut without a legend still draws every slice with its tooltip" <|
            \_ ->
                inside (Chart.donut [ Chart.legend False ] segments)
                    |> Query.findAll [ Selector.class "klar-chart__segment" ]
                    |> Query.count (Expect.equal 2)
        , test "a line chart with two series shows a legend by default" <|
            \_ ->
                legends (Chart.line [] twoSeries)
                    |> Query.count (Expect.equal 1)
        , test "a line chart with one series shows no legend by default" <|
            \_ ->
                legends (Chart.line [] series)
                    |> Query.count (Expect.equal 0)
        , test "a line chart can be forced to show a legend" <|
            \_ ->
                legends (Chart.line [ Chart.legend True ] series)
                    |> Query.count (Expect.equal 1)
        , test "a line chart can be forced to hide its legend" <|
            \_ ->
                legends (Chart.line [ Chart.legend False ] twoSeries)
                    |> Query.count (Expect.equal 0)
        , test "a bar chart with two series shows a legend by default" <|
            \_ ->
                legends (Chart.bar [] twoSeries)
                    |> Query.count (Expect.equal 1)
        , test "a bar chart can be forced to hide its legend" <|
            \_ ->
                legends (Chart.bar [ Chart.legend False ] twoSeries)
                    |> Query.count (Expect.equal 0)
        ]
