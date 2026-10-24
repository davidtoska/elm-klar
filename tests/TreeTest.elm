module TreeTest exposing (suite)

{-| `Klar.Tree`: the elements that stay the same in every state of the data (so
that focus survives a refresh), lazy loading read from the state, checkboxes that
stand for every leaf, disabled nodes, the arrow keys, the search haystack, focus
after "Try again" and the expand vocabulary.

Every test draws the HTML, finds an element the way a user would, simulates an
event on it and gives the message to `Tree.update`.

-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.EmptyState as EmptyState
import Klar.Ids as Ids
import Klar.Remote as Remote exposing (Remote)
import Klar.Tree as Tree
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = TreeMsg Tree.Msg
    | Activated String
    | Retried String
    | Reload


suite : Test
suite =
    describe "Klar.Tree"
        [ stableTests
        , lazyGroupTests
        , loadRequestTests
        , retryFocusTests
        , checkboxTests
        , disabledTests
        , arrowTests
        , searchTests
        , clickTests
        , vocabularyTests
        , pageKeyTests
        ]



-- HELPERS


treeId : String
treeId =
    "t"


start : Tree.State String
start =
    Tree.init treeId


role : String -> Selector.Selector
role name =
    Selector.attribute (Attr.attribute "role" name)


{-| How the tree writes a node id into a DOM id: these ids are plain letters.
-}
itemId : String -> String
itemId nodeId =
    treeId ++ "-n-" ++ nodeId


render : List (Tree.Attribute String Msg) -> Tree.State String -> List (Tree.Node String) -> Query.Single Msg
render attributes state nodes =
    Tree.view TreeMsg (Tree.ariaLabel "Catalog" :: attributes) state nodes |> inside


renderRemote : List (Tree.Attribute String Msg) -> Tree.State String -> Remote (List (Tree.Node String)) -> Query.Single Msg
renderRemote attributes state data =
    Tree.viewRemote TreeMsg (Tree.ariaLabel "Catalog" :: attributes) state data |> inside


inside : Html msg -> Query.Single msg
inside html =
    Query.fromHtml (Html.div [] [ html ])


apply : Tree.State String -> Result String Msg -> Result String (Tree.State String)
apply state result =
    Result.andThen
        (\msg ->
            case msg of
                TreeMsg inner ->
                    Ok (Tuple.first (Tree.update inner state))

                _ ->
                    Err "not a message of the tree"
        )
        result


click : Int -> ( String, Encode.Value )
click detail =
    Event.custom "click"
        (Encode.object
            [ ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "detail", Encode.int detail )
            ]
        )


keyDown : String -> String -> ( String, Encode.Value )
keyDown targetId key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "isComposing", Encode.bool False )
            , ( "keyCode", Encode.int 0 )
            , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
            ]
        )


{-| Click the row with this label and update.
-}
clickRow : List (Tree.Attribute String Msg) -> Tree.State String -> List (Tree.Node String) -> String -> Result String (Tree.State String)
clickRow attributes state nodes label =
    render attributes state nodes
        |> Query.find [ Selector.class "klar-tree__row", Selector.containing [ Selector.exactText label ] ]
        |> Event.simulate (click 1)
        |> Event.toResult
        |> apply state


{-| Press a key while the node with this id has the focus, and update.
-}
press : List (Tree.Attribute String Msg) -> Tree.State String -> List (Tree.Node String) -> String -> String -> Result String (Tree.State String)
press attributes state nodes nodeId key =
    render attributes state nodes
        |> Query.find [ role "tree" ]
        |> Event.simulate (keyDown (itemId nodeId) key)
        |> Event.toResult
        |> apply state


fruit : List (Tree.Node String)
fruit =
    [ Tree.branch Ids.string
        "fruit"
        "Fruit"
        [ Tree.leaf Ids.string "apple" "Apple"
        , Tree.leaf Ids.string "banana" "Banana"
        ]
    , Tree.leaf Ids.string "bread" "Bread"
    ]


retryable : Remote.Problem
retryable =
    Remote.problem Remote.network


old : Remote (List (Tree.Node String))
old =
    Remote.refreshWith
        (Remote.refreshWith Remote.Loading (Ok fruit) (Time.millisToPosix 1000))
        (Err retryable)
        (Time.millisToPosix 2000)


refreshing : Remote (List (Tree.Node String))
refreshing =
    Remote.refresh (Remote.Loaded fruit)



-- THE SAME ELEMENTS IN EVERY STATE


stableTests : Test
stableTests =
    let
        wrapper data =
            renderRemote [ Tree.filterBox, Tree.onRetry Reload ] start data
                |> Query.find [ Selector.id treeId ]

        everyState =
            [ ( "fresh", Remote.Loaded fruit )
            , ( "refreshing", refreshing )
            , ( "old after a failed refresh", old )
            ]
    in
    describe "the same elements in every state"
        (List.concatMap
            (\( name, data ) ->
                [ test ("the tree is in the scrolling body, a child of the element with the id of init (" ++ name ++ ")") <|
                    \_ ->
                        wrapper data
                            |> Query.children [ Selector.class "klar-tree__scroll" ]
                            |> Query.first
                            |> Query.children [ role "tree" ]
                            |> Query.count (Expect.equal 1)
                , test ("the filter box, the marker slot and the live region keep their places (" ++ name ++ ")") <|
                    \_ ->
                        wrapper data
                            |> Expect.all
                                [ Query.children [ Selector.class "klar-tree__filter" ] >> Query.count (Expect.equal 1)
                                , Query.children [ Selector.class "klar-tree__notice" ] >> Query.count (Expect.equal 1)
                                , Query.children [ role "status", Selector.class "klar-sr-only" ] >> Query.count (Expect.equal 1)
                                ]
                ]
            )
            everyState
            ++ [ test "the filter box stays while the nodes load, so a search that asks the backend keeps the focus" <|
                    \_ ->
                        wrapper Remote.Loading
                            |> Query.children [ Selector.class "klar-tree__filter" ]
                            |> Query.count (Expect.equal 1)
               , test "the filter box stays when the nodes failed" <|
                    \_ ->
                        wrapper (Remote.Failed retryable)
                            |> Query.children [ Selector.class "klar-tree__filter" ]
                            |> Query.count (Expect.equal 1)
               , test "old data is marked above the tree, with a retry" <|
                    \_ ->
                        wrapper old
                            |> Query.find [ Selector.class "klar-tree__notice" ]
                            |> Query.has [ Selector.text "Old data", Selector.text "Try again" ]
               , test "refreshing data is dimmed and busy" <|
                    \_ ->
                        wrapper refreshing
                            |> Query.find [ Selector.class "klar-tree__scroll" ]
                            |> Query.has [ Selector.class "klar-refreshing", Selector.attribute (Attr.attribute "aria-busy" "true") ]
               , test "the live region says that the nodes load" <|
                    \_ ->
                        wrapper Remote.Loading
                            |> Query.children [ role "status", Selector.class "klar-sr-only" ]
                            |> Query.first
                            |> Query.has [ Selector.text "Loading ..." ]
               , test "the element with the id of init can take the focus" <|
                    \_ ->
                        wrapper Remote.Loading
                            |> Query.has [ Selector.attribute (Attr.tabindex -1) ]
               , test "Klar.focus on the id of init hands the focus to the node with the tab stop" <|
                    \_ ->
                        renderRemote [] start (Remote.Loaded fruit)
                            |> Query.find [ Selector.id treeId ]
                            |> Event.simulate (Event.custom "focus" (Encode.object [ ( "target", Encode.object [ ( "id", Encode.string treeId ) ] ) ]))
                            |> Event.toResult
                            |> apply start
                            |> Result.map (Tree.focused Ids.string)
                            |> Expect.equal (Ok (Just "fruit"))
               , test "a focus that comes from inside is not handed on" <|
                    \_ ->
                        renderRemote [] start (Remote.Loaded fruit)
                            |> Query.find [ Selector.id treeId ]
                            |> Event.simulate (Event.custom "focus" (Encode.object [ ( "target", Encode.object [ ( "id", Encode.string (itemId "bread") ) ] ) ]))
                            |> Event.toResult
                            |> Expect.err
               , test "emptyState changes the empty state" <|
                    \_ ->
                        render [ Tree.emptyState [ EmptyState.title "No warehouses yet" ] ] start []
                            |> Query.has [ Selector.text "No warehouses yet" ]
               ]
        )



-- LAZY GROUPS


lazyGroupTests : Test
lazyGroupTests =
    let
        lazyTree children =
            [ Tree.lazy Ids.string "box" "Box" children ]

        opened =
            Tree.expand Ids.string "box" start
    in
    describe "the children of a lazy node"
        [ test "old children are one group, with the marker as one of its rows" <|
            \_ ->
                render [ Tree.onRetryChildren Retried ] opened (lazyTree old)
                    |> Expect.all
                        [ Query.findAll [ role "group" ] >> Query.count (Expect.equal 1)
                        , Query.find [ role "group" ] >> Query.children [ role "treeitem" ] >> Query.count (Expect.equal 2)
                        , Query.find [ role "group" ] >> Query.children [ Selector.class "klar-tree__status" ] >> Query.count (Expect.equal 1)
                        ]
        , test "the marker of old children has a retry" <|
            \_ ->
                render [ Tree.onRetryChildren Retried ] opened (lazyTree old)
                    |> Query.find [ role "group" ]
                    |> Query.has [ Selector.text "Old data", Selector.text "Try again" ]
        , test "children that are being refreshed are dimmed, and the node is busy" <|
            \_ ->
                render [] opened (lazyTree refreshing)
                    |> Expect.all
                        [ Query.find [ role "group" ] >> Query.has [ Selector.class "klar-refreshing" ]
                        , Query.find [ Selector.id (itemId "box") ] >> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
                        ]
        , test "children that load are one group with a status row" <|
            \_ ->
                render [] opened (lazyTree Remote.Loading)
                    |> Query.find [ role "group" ]
                    |> Query.children [ Selector.class "klar-tree__status" ]
                    |> Query.count (Expect.equal 1)
        ]



-- LOAD REQUESTS


loadRequestTests : Test
loadRequestTests =
    let
        nodes =
            [ Tree.unloaded Ids.string "box" "Box", Tree.leaf Ids.string "lid" "Lid" ]
    in
    describe "loadRequests"
        [ test "opening a node that was never asked for asks for its children" <|
            \_ ->
                render [] start nodes
                    |> Query.find [ Selector.id (itemId "box") ]
                    |> Query.find [ Selector.class "klar-tree__toggle" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> apply start
                    |> Result.map (Tree.loadRequests Ids.string)
                    |> Expect.equal (Ok [ "box" ])
        , test "ArrowRight on such a node asks too" <|
            \_ ->
                press [] start nodes "box" "ArrowRight"
                    |> Result.map (Tree.loadRequests Ids.string)
                    |> Expect.equal (Ok [ "box" ])
        , test "the next message asks for nothing" <|
            \_ ->
                press [] start nodes "box" "ArrowRight"
                    |> Result.andThen (\state -> press [] state nodes "box" "ArrowDown")
                    |> Result.map (Tree.loadRequests Ids.string)
                    |> Expect.equal (Ok [])
        , test "a node that the program opened asks as soon as it is drawn" <|
            \_ ->
                let
                    state =
                        Tree.expand Ids.string "box" start
                in
                render [] state nodes
                    |> Query.find [ Selector.class "klar-tree__autoload" ]
                    |> Event.simulate (Event.custom "animationstart" (Encode.object [ ( "animationName", Encode.string "klar-tree-autoload" ) ]))
                    |> Event.toResult
                    |> apply state
                    |> Result.map (Tree.loadRequests Ids.string)
                    |> Expect.equal (Ok [ "box" ])
        , test "another animation asks for nothing" <|
            \_ ->
                render [] (Tree.expand Ids.string "box" start) nodes
                    |> Query.find [ Selector.class "klar-tree__autoload" ]
                    |> Event.simulate (Event.custom "animationstart" (Encode.object [ ( "animationName", Encode.string "klar-spin" ) ]))
                    |> Event.toResult
                    |> Expect.err
        , test "a node that is loading does not ask" <|
            \_ ->
                render [] (Tree.expand Ids.string "box" start) [ Tree.lazy Ids.string "box" "Box" Remote.Loading ]
                    |> Query.findAll [ Selector.class "klar-tree__autoload" ]
                    |> Query.count (Expect.equal 0)
        ]



-- FOCUS AFTER "TRY AGAIN"


retryFocusTests : Test
retryFocusTests =
    describe "focus after Try again"
        [ test "Try again under a node that failed puts the focus back on the node" <|
            \_ ->
                let
                    state =
                        Tree.expand Ids.string "box" start
                in
                render [ Tree.onRetryChildren Retried ] state [ Tree.lazy Ids.string "box" "Box" (Remote.Failed retryable) ]
                    |> Query.find [ Selector.class "klar-tree__status" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> apply state
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "box"))
        , test "the button itself sends the message of the application" <|
            \_ ->
                render [ Tree.onRetryChildren Retried ] (Tree.expand Ids.string "box" start) [ Tree.lazy Ids.string "box" "Box" (Remote.Failed retryable) ]
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect (Retried "box")
        , test "Try again of the top level is caught by the tree too, which moves the focus" <|
            \_ ->
                renderRemote [ Tree.onRetry Reload ] start (Remote.Failed retryable)
                    |> Query.find [ Selector.class "klar-tree__state" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> apply start
                    |> Expect.ok
        , test "the top level retry sends onRetry" <|
            \_ ->
                renderRemote [ Tree.onRetry Reload ] start (Remote.Failed retryable)
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect Reload
        ]



-- CHECKBOXES


checkboxTests : Test
checkboxTests =
    let
        filtered =
            Tree.setQuery "apple" start
    in
    describe "checkboxes"
        [ test "checking a parent while filtering checks every leaf below it, also the hidden ones" <|
            \_ ->
                clickRow [ Tree.checkboxes ] filtered fruit "Fruit"
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [ "apple", "banana" ])
        , test "a parent shows every leaf below it while filtering" <|
            \_ ->
                render [ Tree.checkboxes ] (Tree.setCheckedIds Ids.string [ "apple" ] filtered) fruit
                    |> Query.find [ Selector.id (itemId "fruit") ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-checked" "mixed") ]
        , test "Space on a parent checks its leaves" <|
            \_ ->
                press [ Tree.checkboxes ] start fruit "fruit" " "
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [ "apple", "banana" ])
        , test "a parent with every leaf checked is checked" <|
            \_ ->
                render [ Tree.checkboxes ] (Tree.setCheckedIds Ids.string [ "apple", "banana" ] start) fruit
                    |> Query.find [ Selector.id (itemId "fruit") ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-checked" "true") ]
        ]



-- DISABLED NODES


disabledTests : Test
disabledTests =
    let
        nodes =
            [ Tree.branch Ids.string
                "closed"
                "Closed hall"
                [ Tree.leaf Ids.string "bay-1" "Bay 1", Tree.leaf Ids.string "bay-2" "Bay 2" ]
                |> Tree.disabled
            ]
    in
    describe "disabled nodes"
        [ test "a click on the row of a disabled branch checks nothing" <|
            \_ ->
                clickRow [ Tree.checkboxes ] start nodes "Closed hall"
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [])
        , test "Space on a disabled branch checks nothing" <|
            \_ ->
                press [ Tree.checkboxes ] start nodes "closed" " "
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [])
        , test "Enter on a disabled branch opens it" <|
            \_ ->
                press [ Tree.checkboxes ] start nodes "closed" "Enter"
                    |> Result.map (Tree.isExpanded Ids.string "closed")
                    |> Expect.equal (Ok True)
        , test "the leaves below a disabled branch can still be checked" <|
            \_ ->
                clickRow [ Tree.checkboxes ] (Tree.expand Ids.string "closed" start) nodes "Bay 1"
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [ "bay-1" ])
        , test "a click on a disabled node selects nothing" <|
            \_ ->
                clickRow [] start nodes "Closed hall"
                    |> Result.map (Tree.selectedIds Ids.string)
                    |> Expect.equal (Ok [])
        ]



-- ARROW KEYS


arrowTests : Test
arrowTests =
    let
        nodes =
            [ Tree.lazy Ids.string "box" "Box" Remote.Loading, Tree.leaf Ids.string "lid" "Lid" ]

        open =
            Tree.expand Ids.string "box" start
    in
    describe "the arrow keys"
        [ test "ArrowRight on an open node whose children load does not leave the node" <|
            \_ ->
                clickRow [] open nodes "Box"
                    |> Result.andThen (\state -> press [] state nodes "box" "ArrowRight")
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "box"))
        , test "ArrowRight on an open node with children goes to the first child" <|
            \_ ->
                clickRow [] (Tree.expand Ids.string "fruit" start) fruit "Fruit"
                    |> Result.andThen (\state -> press [] state fruit "fruit" "ArrowRight")
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "apple"))
        , test "ArrowRight on a leaf is handled, and stays" <|
            \_ ->
                clickRow [] start fruit "Bread"
                    |> Result.andThen (\state -> press [] state fruit "bread" "ArrowRight")
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "bread"))
        , test "ArrowLeft on a closed node at the top is handled, and stays" <|
            \_ ->
                clickRow [] start fruit "Bread"
                    |> Result.andThen (\state -> press [] state fruit "bread" "ArrowLeft")
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "bread"))
        ]



-- SEARCH


searchTests : Test
searchTests =
    let
        nodes =
            [ Tree.leaf Ids.string "a" "Alpha" |> Tree.withDescription "OSL-1"
            , Tree.leaf Ids.string "b" "Beta" |> Tree.withKeywords [ "Oslo" ]
            , Tree.leaf Ids.string "c" "Gamma"
            ]

        searched =
            Tree.setQuery "osl" start
    in
    describe "the filter"
        [ test "finds a node by its description and by its keywords" <|
            \_ ->
                render [] searched nodes
                    |> Query.findAll [ role "treeitem" ]
                    |> Query.count (Expect.equal 2)
        , test "leaves out the nodes that do not match" <|
            \_ ->
                render [] searched nodes
                    |> Query.findAll [ Selector.id (itemId "c") ]
                    |> Query.count (Expect.equal 0)
        , test "marks the matching text of the description" <|
            \_ ->
                render [] searched nodes
                    |> Query.find [ Selector.class "klar-tree__description" ]
                    |> Query.has [ Selector.tag "mark" ]
        , test "says how many nodes match" <|
            \_ ->
                render [ Tree.filterBox ] searched nodes
                    |> Query.find [ Selector.id treeId ]
                    |> Query.children [ role "status", Selector.class "klar-sr-only" ]
                    |> Query.first
                    |> Query.has [ Selector.text "2 matches" ]
        ]



-- CLICKS


clickTests : Test
clickTests =
    let
        twice =
            render [ Tree.allowEmptySelection ] start fruit
                |> Query.find [ Selector.class "klar-tree__row", Selector.containing [ Selector.exactText "Bread" ] ]
                |> Event.simulate (click 1)
                |> Event.toResult
                |> apply start
                |> Result.andThen
                    (\state ->
                        render [ Tree.allowEmptySelection ] state fruit
                            |> Query.find [ Selector.class "klar-tree__row", Selector.containing [ Selector.exactText "Bread" ] ]
                            |> Event.simulate (click 2)
                            |> Event.toResult
                            |> apply state
                    )
    in
    describe "clicks"
        [ test "a double click with allowEmptySelection leaves the node selected" <|
            \_ ->
                twice
                    |> Result.map (Tree.selectedIds Ids.string)
                    |> Expect.equal (Ok [ "bread" ])
        , test "a second single click with allowEmptySelection clears it" <|
            \_ ->
                clickRow [ Tree.allowEmptySelection ] start fruit "Bread"
                    |> Result.andThen (\state -> clickRow [ Tree.allowEmptySelection ] state fruit "Bread")
                    |> Result.map (Tree.selectedIds Ids.string)
                    |> Expect.equal (Ok [])
        ]



-- OPEN AND CLOSED


vocabularyTests : Test
vocabularyTests =
    describe "open and closed"
        [ test "toggle opens a closed node" <|
            \_ ->
                Tree.toggle Ids.string "fruit" start
                    |> Tree.isExpanded Ids.string "fruit"
                    |> Expect.equal True
        , test "toggle closes an open node" <|
            \_ ->
                Tree.toggle Ids.string "fruit" (Tree.expand Ids.string "fruit" start)
                    |> Tree.isExpanded Ids.string "fruit"
                    |> Expect.equal False
        , test "setExpandedIds and expandedIds" <|
            \_ ->
                Tree.setExpandedIds Ids.string [ "fruit", "box" ] start
                    |> Tree.expandedIds Ids.string
                    |> Expect.equal [ "box", "fruit" ]
        , test "setSelectedIds and selectedIds" <|
            \_ ->
                Tree.setSelectedIds Ids.string [ "bread", "apple" ] start
                    |> Tree.selectedIds Ids.string
                    |> Expect.equal [ "apple", "bread" ]
        ]



-- PAGE KEYS AND SELECT ALL


{-| A key with modifiers, while the node with this id has the focus, and update.
-}
pressWith : { ctrl : Bool, shift : Bool } -> List (Tree.Attribute String Msg) -> Tree.State String -> List (Tree.Node String) -> String -> String -> Result String (Tree.State String)
pressWith modifiers attributes state nodes nodeId key =
    render attributes state nodes
        |> Query.find [ role "tree" ]
        |> Event.simulate
            (Event.custom "keydown"
                (Encode.object
                    [ ( "key", Encode.string key )
                    , ( "ctrlKey", Encode.bool modifiers.ctrl )
                    , ( "metaKey", Encode.bool False )
                    , ( "altKey", Encode.bool False )
                    , ( "shiftKey", Encode.bool modifiers.shift )
                    , ( "isComposing", Encode.bool False )
                    , ( "keyCode", Encode.int 0 )
                    , ( "target", Encode.object [ ( "id", Encode.string (itemId nodeId) ) ] )
                    ]
                )
            )
        |> Event.toResult
        |> apply state


pageKeyTests : Test
pageKeyTests =
    let
        names =
            List.map (\n -> "node" ++ String.fromInt n) (List.range 1 15)

        many =
            List.map (\id -> Tree.leaf Ids.string id id) names
                ++ [ Tree.leaf Ids.string "off" "off" |> Tree.disabled ]

        firstClicked attributes =
            clickRow attributes start many "node1"
    in
    describe "page keys and select all"
        [ test "PageDown moves ten nodes" <|
            \_ ->
                firstClicked []
                    |> Result.andThen (\state -> press [] state many "node1" "PageDown")
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "node11"))
        , test "PageUp moves ten nodes back, and stops at the first" <|
            \_ ->
                firstClicked []
                    |> Result.andThen (\state -> press [] state many "node1" "PageDown")
                    |> Result.andThen (\state -> press [] state many "node11" "PageUp")
                    |> Result.andThen (\state -> press [] state many "node1" "PageUp")
                    |> Result.map (Tree.focused Ids.string)
                    |> Expect.equal (Ok (Just "node1"))
        , test "Shift+End in a multiSelect tree selects up to the last node that can be selected" <|
            \_ ->
                clickRow [ Tree.multiSelect ] start many "node14"
                    |> Result.andThen (\state -> pressWith { ctrl = False, shift = True } [ Tree.multiSelect ] state many "node14" "End")
                    |> Result.map (Tree.selectedIds Ids.string)
                    |> Expect.equal (Ok [ "node14", "node15" ])
        , test "Ctrl+A in a multiSelect tree selects every visible node that can be selected" <|
            \_ ->
                firstClicked [ Tree.multiSelect ]
                    |> Result.andThen (\state -> pressWith { ctrl = True, shift = False } [ Tree.multiSelect ] state many "node1" "a")
                    |> Result.map (Tree.selectedIds Ids.string >> List.length)
                    |> Expect.equal (Ok 15)
        , test "Ctrl+A is not a key of a single-select tree" <|
            \_ ->
                render [] start many
                    |> Query.find [ role "tree" ]
                    |> Event.simulate
                        (Event.custom "keydown"
                            (Encode.object
                                [ ( "key", Encode.string "a" )
                                , ( "ctrlKey", Encode.bool True )
                                , ( "metaKey", Encode.bool False )
                                , ( "altKey", Encode.bool False )
                                , ( "shiftKey", Encode.bool False )
                                , ( "isComposing", Encode.bool False )
                                , ( "keyCode", Encode.int 0 )
                                , ( "target", Encode.object [ ( "id", Encode.string (itemId "node1") ) ] )
                                ]
                            )
                        )
                    |> Event.toResult
                    |> Expect.err
        ]
