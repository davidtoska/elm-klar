module TreeTest exposing (suite)

{-| `Klar.Tree`: the elements that stay the same in every state of the data (so
that focus survives a refresh), lazy loading read from the state, checkboxes that
stand for every leaf, disabled nodes, the arrow keys, the search haystack, focus
after "Try again" and the expand vocabulary.

Every test draws the HTML, finds an element the way a user would, simulates an
event on it and gives the message to `Tree.update`.

-}

import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.EmptyState as EmptyState
import Klar.Ids as Ids
import Klar.Remote as Remote exposing (Remote)
import Klar.Tree as Tree
import Test exposing (Test, describe, fuzz2, test)
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
        , filterPropertyTests
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
                |> Query.find [ Selector.class "klar-tree-wrap" ]

        everyState =
            [ ( "fresh", Remote.Loaded fruit )
            , ( "refreshing", refreshing )
            , ( "old after a failed refresh", old )
            ]

        -- The children of the element around the tree, in order: the same
        -- element at the same place in every state.
        slots =
            [ ( "span", "klar-tree__anchor" )
            , ( "div", "klar-tree__filter" )
            , ( "span", "klar-sr-only" )
            , ( "div", "klar-tree__notice" )
            , ( "div", "klar-tree__scroll" )
            ]

        allStates =
            ( "loading", Remote.Loading )
                :: ( "failed", Remote.Failed retryable )
                :: ( "empty", Remote.Loaded [] )
                :: everyState
    in
    describe "the same elements in every state"
        (List.map
            (\( name, data ) ->
                test ("the children of the tree's element are the same, in the same order (" ++ name ++ ")") <|
                    \_ ->
                        wrapper data
                            |> Query.children []
                            |> Expect.all
                                (Query.count (Expect.equal (List.length slots))
                                    :: List.indexedMap
                                        (\index ( tag, class ) ->
                                            Query.index index >> Query.has [ Selector.tag tag, Selector.class class ]
                                        )
                                        slots
                                )
            )
            allStates
            ++ List.map
                (\( name, data ) ->
                    test ("the tree is in the scrolling body (" ++ name ++ ")") <|
                        \_ ->
                            wrapper data
                                |> Query.children [ Selector.class "klar-tree__scroll" ]
                                |> Query.first
                                |> Query.children [ role "tree" ]
                                |> Query.count (Expect.equal 1)
                )
                everyState
            ++ [ test "old data is marked above the tree, with a retry" <|
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
               , test "the element with the id of init is the anchor, which can take the focus" <|
                    \_ ->
                        wrapper Remote.Loading
                            |> Query.find [ Selector.id treeId ]
                            |> Query.has [ Selector.class "klar-tree__anchor", Selector.attribute (Attr.tabindex -1) ]
               , test "only the anchor has the id of init, so a click on a gap of the tree takes no focus" <|
                    \_ ->
                        renderRemote [ Tree.filterBox ] start (Remote.Loaded fruit)
                            |> Query.findAll [ Selector.id treeId ]
                            |> Query.count (Expect.equal 1)
               , test "Klar.focus on the id of init hands the focus to the node with the tab stop" <|
                    \_ ->
                        renderRemote [] start (Remote.Loaded fruit)
                            |> Query.find [ Selector.id treeId ]
                            |> Event.simulate (Event.custom "focus" (Encode.object []))
                            |> Event.toResult
                            |> apply start
                            |> Result.map (Tree.focused Ids.string)
                            |> Expect.equal (Ok (Just "fruit"))
               , test "while there is no node, the anchor keeps the focus" <|
                    \_ ->
                        renderRemote [] start Remote.Loading
                            |> Query.find [ Selector.id treeId ]
                            |> Event.simulate (Event.custom "focus" (Encode.object []))
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
        , test "if the automatic request never comes, the Load button under the node asks" <|
            \_ ->
                let
                    state =
                        Tree.expand Ids.string "box" start
                in
                render [] state nodes
                    |> Query.find [ Selector.class "klar-tree__load" ]
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Load" ] ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> apply state
                    |> Result.map (Tree.loadRequests Ids.string)
                    |> Expect.equal (Ok [ "box" ])
        , test "a node that is loading has no Load button" <|
            \_ ->
                render [] (Tree.expand Ids.string "box" start) [ Tree.lazy Ids.string "box" "Box" Remote.Loading ]
                    |> Query.findAll [ Selector.class "klar-tree__load" ]
                    |> Query.count (Expect.equal 0)
        , test "the live region of the tree says that an open branch loads" <|
            \_ ->
                render [] (Tree.expand Ids.string "box" start) [ Tree.lazy Ids.string "box" "Box" Remote.Loading ]
                    |> Query.find [ Selector.class "klar-tree-wrap" ]
                    |> Query.children [ role "status", Selector.class "klar-sr-only" ]
                    |> Query.first
                    |> Query.has [ Selector.text "Loading ..." ]
        , test "the status row of a loading branch is not a live region of its own" <|
            \_ ->
                render [] (Tree.expand Ids.string "box" start) [ Tree.lazy Ids.string "box" "Box" Remote.Loading ]
                    |> Query.find [ Selector.class "klar-tree__status" ]
                    |> Query.findAll [ role "status" ]
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
        , test "Try again of the top level is caught by the tree too, which moves the focus to the filter box or the anchor" <|
            \_ ->
                let
                    caught attributes slot =
                        renderRemote (Tree.onRetry Reload :: attributes) start (Remote.Failed retryable)
                            |> Query.find [ Selector.class slot ]
                            |> Event.simulate Event.click
                            |> Event.toResult

                    -- A message of the tree that does nothing: ArrowLeft on a
                    -- closed node at the top.
                    nothing =
                        render [] start fruit
                            |> Query.find [ role "tree" ]
                            |> Event.simulate (keyDown (itemId "fruit") "ArrowLeft")
                            |> Event.toResult
                in
                Expect.all
                    [ \_ -> Expect.notEqual nothing (caught [] "klar-tree__state")
                    , \_ -> Expect.notEqual nothing (caught [ Tree.filterBox ] "klar-tree__state")

                    -- The target depends on the filter box ...
                    , \_ -> Expect.notEqual (caught [] "klar-tree__state") (caught [ Tree.filterBox ] "klar-tree__state")

                    -- ... and the marker of old data sends the same message.
                    , \_ -> Expect.equal (caught [ Tree.filterBox ] "klar-tree__state") (caught [ Tree.filterBox ] "klar-tree__notice")
                    , \_ -> Expect.equal (caught [] "klar-tree__state") (caught [] "klar-tree__notice")
                    ]
                    ()
        , test "a press on the magnifier of the filter box puts the focus in the field, not in the tree" <|
            \_ ->
                let
                    pressOn tag =
                        renderRemote [ Tree.filterBox, Tree.onRetry Reload ] start (Remote.Failed retryable)
                            |> Query.find [ Selector.class "klar-tree__filter" ]
                            |> Event.simulate (Event.custom "mousedown" (Encode.object [ ( "target", Encode.object [ ( "tagName", Encode.string tag ) ] ) ]))
                            |> Event.toResult

                    toField =
                        renderRemote [ Tree.filterBox, Tree.onRetry Reload ] start (Remote.Failed retryable)
                            |> Query.find [ Selector.class "klar-tree__state" ]
                            |> Event.simulate Event.click
                            |> Event.toResult
                in
                Expect.all
                    [ \_ -> Expect.equal toField (pressOn "SPAN")
                    , \_ -> Expect.err (pressOn "INPUT")
                    ]
                    ()
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

        site =
            [ Tree.branch Ids.string
                "region"
                "Region"
                [ Tree.branch Ids.string "site" "Site" (nodes ++ [ Tree.leaf Ids.string "dock" "Dock" ]) ]
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
        , test "checking the grandparent of a disabled branch passes the branch by" <|
            \_ ->
                clickRow [ Tree.checkboxes ] start site "Region"
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [ "dock" ])
        , test "Space on the grandparent passes it by too" <|
            \_ ->
                press [ Tree.checkboxes ] start site "region" " "
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [ "dock" ])
        , test "an ancestor does not count the leaves below a disabled branch" <|
            \_ ->
                render [ Tree.checkboxes ] (Tree.setCheckedIds Ids.string [ "dock" ] start) site
                    |> Query.find [ Selector.id (itemId "region") ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-checked" "true") ]
        , test "unchecking the grandparent leaves the leaves below a disabled branch checked" <|
            \_ ->
                clickRow [ Tree.checkboxes ] (Tree.setCheckedIds Ids.string [ "bay-1", "dock" ] start) site "Region"
                    |> Result.map (Tree.checkedIds Ids.string)
                    |> Expect.equal (Ok [ "bay-1" ])
        , test "a disabled branch shows the leaves below it that were checked one by one" <|
            \_ ->
                render [ Tree.checkboxes ] (Tree.setCheckedIds Ids.string [ "bay-1" ] (Tree.setExpandedIds Ids.string [ "region", "site" ] start)) site
                    |> Query.find [ Selector.id (itemId "closed") ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-checked" "mixed") ]
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
                    |> Query.find [ Selector.class "klar-tree-wrap" ]
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
        , test "Ctrl+A with Caps Lock or Shift (a capital A) selects every node too" <|
            \_ ->
                firstClicked [ Tree.multiSelect ]
                    |> Result.andThen (\state -> pressWith { ctrl = True, shift = True } [ Tree.multiSelect ] state many "node1" "A")
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



-- THE FILTER KEEPS EXACTLY THE MATCHES AND THEIR ANCESTORS


{-| A tree of three levels with three nodes at every level (39 nodes), each
labelled with one of four words, picked by the fuzzer. The ids are the paths.
-}
wordTree : List Int -> List (Tree.Node String)
wordTree picks =
    let
        word i =
            case modBy 4 (List.drop i picks |> List.head |> Maybe.withDefault 0) of
                0 ->
                    "apple"

                1 ->
                    "bread"

                2 ->
                    "cheese"

                _ ->
                    "dates"

        node i path children =
            if List.isEmpty children then
                Tree.leaf Ids.string path (word i ++ " " ++ path)

            else
                Tree.branch Ids.string path (word i ++ " " ++ path) children
    in
    List.map
        (\a ->
            node (a * 13)
                ("p" ++ String.fromInt a)
                (List.map
                    (\b ->
                        node (a * 13 + 1 + b * 4)
                            ("p" ++ String.fromInt a ++ "x" ++ String.fromInt b)
                            (List.map
                                (\c -> node (a * 13 + 2 + b * 4 + c) ("p" ++ String.fromInt a ++ "x" ++ String.fromInt b ++ "x" ++ String.fromInt c) [])
                                (List.range 0 2)
                            )
                    )
                    (List.range 0 2)
                )
        )
        (List.range 0 2)


{-| What the filter must show: every node whose label has the word, and every
ancestor of one. Worked out here from the labels, independently of the tree.
-}
expectedRows : String -> List Int -> List String
expectedRows query picks =
    let
        labelOf i =
            case modBy 4 (List.drop i picks |> List.head |> Maybe.withDefault 0) of
                0 ->
                    "apple"

                1 ->
                    "bread"

                2 ->
                    "cheese"

                _ ->
                    "dates"

        hit i =
            labelOf i == query

        leafRows a b =
            List.filter (\c -> hit (a * 13 + 2 + b * 4 + c)) (List.range 0 2)
                |> List.map (\c -> "p" ++ String.fromInt a ++ "x" ++ String.fromInt b ++ "x" ++ String.fromInt c)

        middleRows a =
            List.concatMap
                (\b ->
                    let
                        below =
                            leafRows a b
                    in
                    if hit (a * 13 + 1 + b * 4) || not (List.isEmpty below) then
                        ("p" ++ String.fromInt a ++ "x" ++ String.fromInt b) :: below

                    else
                        []
                )
                (List.range 0 2)
    in
    List.concatMap
        (\a ->
            let
                below =
                    middleRows a
            in
            if hit (a * 13) || not (List.isEmpty below) then
                ("p" ++ String.fromInt a) :: below

            else
                []
        )
        (List.range 0 2)


filterPropertyTests : Test
filterPropertyTests =
    fuzz2 (Fuzz.listOfLength 39 (Fuzz.intRange 0 3)) (Fuzz.oneOfValues [ "apple", "bread", "cheese", "dates" ]) "the filter shows exactly the matches and their ancestors" <|
        \picks query ->
            let
                html =
                    render [] (Tree.setQuery query start) (wordTree picks)

                expected =
                    expectedRows query picks
            in
            Expect.all
                ((\_ -> html |> Query.findAll [ role "treeitem" ] |> Query.count (Expect.equal (List.length expected)))
                    :: List.map (\id -> \_ -> html |> Query.findAll [ Selector.id (itemId id) ] |> Query.count (Expect.equal 1)) expected
                )
                ()
