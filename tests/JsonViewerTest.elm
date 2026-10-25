module JsonViewerTest exposing (suite)

{-| Klar.JsonViewer: paths, opening and closing, and the keyboard of the ARIA tree.
-}

import Expect
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.JsonViewer as JsonViewer
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = Viewer JsonViewer.Msg


value : Encode.Value
value =
    Encode.object
        [ ( "id", Encode.int 7 )
        , ( "items", Encode.list Encode.int [ 1, 2, 3 ] )
        , ( "owner", Encode.object [ ( "name", Encode.string "Ada" ) ] )
        ]


render : JsonViewer.State -> Query.Single Msg
render state =
    JsonViewer.view Viewer [] state value |> Query.fromHtml


{-| The DOM id of the row of a node.
-}
rowId : String -> String
rowId path =
    "v-row-" ++ String.replace "/" "_47_" path


{-| A key press on a row, as the browser sends it.
-}
keyOn : String -> String -> ( String, Encode.Value )
keyOn targetId key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "isComposing", Encode.bool False )
            , ( "keyCode", Encode.int 0 )
            , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
            ]
        )


step : Msg -> JsonViewer.State -> JsonViewer.State
step (Viewer msg) state =
    Tuple.first (JsonViewer.update msg state)


{-| The state after a key press on a row, following the message through `update`.
-}
press : String -> String -> JsonViewer.State -> Result String JsonViewer.State
press path key state =
    render state
        |> Query.find [ Selector.attribute (Attr.attribute "role" "tree") ]
        |> Event.simulate (keyOn (rowId path) key)
        |> Event.toResult
        |> Result.map (\msg -> step msg state)


{-| The state after a row got the focus (a click or a Tab), as the browser tells it.
-}
focusOn : String -> JsonViewer.State -> Result String JsonViewer.State
focusOn path state =
    render state
        |> Query.find [ Selector.id (rowId path) ]
        |> Event.simulate Event.focus
        |> Event.toResult
        |> Result.map (\msg -> step msg state)


tabStopIs : String -> Result String JsonViewer.State -> Expect.Expectation
tabStopIs path result =
    case result of
        Ok state ->
            render state |> Query.find [ Selector.attribute (Attr.tabindex 0) ] |> Query.has [ Selector.id (rowId path) ]

        Err problem ->
            Expect.fail problem


suite : Test
suite =
    describe "Klar.JsonViewer"
        [ describe "paths"
            [ test "path joins keys as a JSON Pointer" <|
                \_ -> JsonViewer.path [ "items", "3", "error" ] |> Expect.equal "/items/3/error"
            , test "path escapes ~ and /" <|
                \_ -> JsonViewer.path [ "a/b", "c~d" ] |> Expect.equal "/a~1b/c~0d"
            , test "the root is the empty path" <|
                \_ -> JsonViewer.path [] |> Expect.equal ""
            ]
        , describe "opening and closing"
            [ test "the root and its children are open at first, deeper nodes closed" <|
                \_ ->
                    let
                        state =
                            JsonViewer.init "v"
                    in
                    List.map (\p -> JsonViewer.isExpanded p state) [ "", "/owner", "/owner/address" ]
                        |> Expect.equal [ True, True, False ]
            , test "expandedIds lists the open objects and arrays in document order" <|
                \_ -> JsonViewer.expandedIds value (JsonViewer.init "v") |> Expect.equal [ "", "/items", "/owner" ]
            , test "expandedIds given back to setExpandedIds keeps the view" <|
                \_ ->
                    let
                        before =
                            JsonViewer.init "v" |> JsonViewer.collapse "/owner"

                        after =
                            JsonViewer.init "v" |> JsonViewer.setExpandedIds (JsonViewer.expandedIds value before)
                    in
                    List.map (\p -> JsonViewer.isExpanded p after) [ "", "/items", "/owner" ]
                        |> Expect.equal [ True, True, False ]
            , test "expand opens a deep node and every node above it" <|
                \_ ->
                    let
                        state =
                            JsonViewer.init "v" |> JsonViewer.collapseAll |> JsonViewer.expand "/a/b/c"
                    in
                    List.map (\p -> JsonViewer.isExpanded p state) [ "", "/a", "/a/b", "/a/b/c" ]
                        |> Expect.equal [ True, True, True, True ]
            , test "expand leaves open nodes open" <|
                \_ ->
                    JsonViewer.init "v"
                        |> JsonViewer.expand "/owner"
                        |> JsonViewer.isExpanded "/owner"
                        |> Expect.equal True
            , test "collapse closes one node" <|
                \_ ->
                    JsonViewer.init "v"
                        |> JsonViewer.collapse "/owner"
                        |> JsonViewer.isExpanded "/owner"
                        |> Expect.equal False
            , test "setExpandedIds opens exactly the given nodes" <|
                \_ ->
                    let
                        state =
                            JsonViewer.init "v" |> JsonViewer.setExpandedIds [ "", "/items" ]
                    in
                    List.map (\p -> JsonViewer.isExpanded p state) [ "/items", "/owner" ]
                        |> Expect.equal [ True, False ]
            ]
        , describe "an ARIA tree"
            [ test "the viewer is a tree of treeitems with groups" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Expect.all
                            [ Query.has [ Selector.attribute (Attr.attribute "role" "tree") ]
                            , Query.findAll [ Selector.attribute (Attr.attribute "role" "treeitem") ] >> Query.count (Expect.atLeast 5)
                            , Query.findAll [ Selector.attribute (Attr.attribute "role" "group") ] >> Query.count (Expect.atLeast 1)
                            ]
            , test "there is one tab stop, the root at first" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Expect.all
                            [ Query.findAll [ Selector.attribute (Attr.tabindex 0) ] >> Query.count (Expect.equal 1)
                            , Query.find [ Selector.attribute (Attr.tabindex 0) ] >> Query.has [ Selector.id (rowId ""), Selector.attribute (Attr.attribute "aria-level" "1") ]
                            ]
            , test "a node says whether it is open, and its level" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Query.find [ Selector.id (rowId "/owner") ]
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-expanded" "true"), Selector.attribute (Attr.attribute "aria-level" "2") ]
            , test "a node is named by its own line, and that line exists" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Expect.all
                            [ Query.find [ Selector.id (rowId "/owner") ] >> Query.has [ Selector.attribute (Attr.attribute "aria-labelledby" "v-name-_47_owner") ]
                            , Query.has [ Selector.id "v-name-_47_owner" ]
                            ]
            ]
        , describe "the keyboard"
            [ test "Down moves the tab stop to the next row" <|
                \_ -> press "" "ArrowDown" (JsonViewer.init "v") |> tabStopIs "/id"
            , test "End moves to the last row and Home back to the first" <|
                \_ ->
                    press "" "End" (JsonViewer.init "v")
                        |> Result.andThen (press "/owner/name" "Home")
                        |> tabStopIs ""
            , test "a key acts on the row it was pressed on, even before the tab stop moved there" <|
                \_ ->
                    -- the stored tab stop is still the root: Left must close /owner, not the root
                    press "/owner" "ArrowLeft" (JsonViewer.init "v")
                        |> Result.map (\state -> ( JsonViewer.isExpanded "/owner" state, JsonViewer.isExpanded "" state ))
                        |> Expect.equal (Ok ( False, True ))
            , test "a key on an element that is not a row is left to the browser" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Query.find [ Selector.attribute (Attr.attribute "role" "tree") ]
                        |> Event.simulate (keyOn "elsewhere" "ArrowDown")
                        |> Event.toResult
                        |> Expect.err
            , test "a row that gets the focus becomes the tab stop" <|
                \_ -> focusOn "/items" (JsonViewer.init "v") |> tabStopIs "/items"
            , test "Left on an open node closes it" <|
                \_ ->
                    focusOn "/owner" (JsonViewer.init "v")
                        |> Result.andThen (press "/owner" "ArrowLeft")
                        |> Result.map (JsonViewer.isExpanded "/owner")
                        |> Expect.equal (Ok False)
            , test "Right on a closed node opens it" <|
                \_ ->
                    focusOn "/owner" (JsonViewer.init "v" |> JsonViewer.collapse "/owner")
                        |> Result.andThen (press "/owner" "ArrowRight")
                        |> Result.map (JsonViewer.isExpanded "/owner")
                        |> Expect.equal (Ok True)
            , test "Right on an open node goes to its first child" <|
                \_ ->
                    focusOn "/owner" (JsonViewer.init "v")
                        |> Result.andThen (press "/owner" "ArrowRight")
                        |> tabStopIs "/owner/name"
            , test "Left on a leaf goes to its parent" <|
                \_ ->
                    focusOn "/owner/name" (JsonViewer.init "v")
                        |> Result.andThen (press "/owner/name" "ArrowLeft")
                        |> tabStopIs "/owner"
            , test "Enter opens and closes a node" <|
                \_ ->
                    focusOn "/items" (JsonViewer.init "v")
                        |> Result.andThen (press "/items" "Enter")
                        |> Result.map (JsonViewer.isExpanded "/items")
                        |> Expect.equal (Ok False)
            , test "Enter on a cut string shows all of it, and again cuts it" <|
                \_ ->
                    let
                        long =
                            Encode.object [ ( "note", Encode.string (String.repeat 30 "abcdefg ") ) ]

                        draw state =
                            JsonViewer.view Viewer [ JsonViewer.maxStringLength 20 ] state long |> Query.fromHtml

                        enter state =
                            draw state
                                |> Query.find [ Selector.attribute (Attr.attribute "role" "tree") ]
                                |> Event.simulate (keyOn (rowId "/note") "Enter")
                                |> Event.toResult
                                |> Result.map (\msg -> step msg state)

                        -- the row of the string gets the focus first
                        start =
                            draw (JsonViewer.init "v")
                                |> Query.find [ Selector.id (rowId "/note") ]
                                |> Event.simulate Event.focus
                                |> Event.toResult
                                |> Result.map (\msg -> step msg (JsonViewer.init "v"))
                    in
                    Expect.all
                        [ \_ ->
                            start
                                |> Result.map (draw >> Query.has [ Selector.text "Show all" ])
                                |> Result.withDefault (Expect.fail "no focus message")
                        , \_ ->
                            start
                                |> Result.andThen enter
                                |> Result.map (draw >> Query.has [ Selector.text "Show less" ])
                                |> Result.withDefault (Expect.fail "no message")
                        ]
                        ()
            , test "a key from outside a row is left alone" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Query.find [ Selector.attribute (Attr.attribute "role" "tree") ]
                        |> Event.simulate (keyOn "somewhere-else" "ArrowDown")
                        |> Event.toResult
                        |> Expect.err
            , test "a click on a node opens and closes it" <|
                \_ ->
                    render (JsonViewer.init "v")
                        |> Query.find [ Selector.id (rowId "/owner") ]
                        |> Query.children [ Selector.class "klar-json__toggle" ]
                        |> Query.first
                        |> Event.simulate Event.click
                        |> Event.toResult
                        |> Result.map (\msg -> step msg (JsonViewer.init "v") |> JsonViewer.isExpanded "/owner")
                        |> Expect.equal (Ok False)
            ]
        ]
