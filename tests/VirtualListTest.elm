module VirtualListTest exposing (suite)

import Array exposing (Array)
import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Theme as Theme
import Klar.VirtualList as VirtualList
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = ListMsg VirtualList.Msg
    | Picked Int


names : Array String
names =
    Array.initialize 1000 (\n -> "Item " ++ String.fromInt n)


start : VirtualList.State
start =
    VirtualList.init "items"


view : List (VirtualList.Attribute Msg) -> VirtualList.State -> Html Msg
view attributes state =
    VirtualList.list ListMsg
        attributes
        { label = "Items", items = names, viewRow = Html.text }
        state


picking : List (VirtualList.Attribute Msg)
picking =
    [ VirtualList.onSelect Picked ]


key : String -> Encode.Value
key name =
    Encode.object
        [ ( "key", Encode.string name )
        , ( "ctrlKey", Encode.bool False )
        , ( "metaKey", Encode.bool False )
        , ( "altKey", Encode.bool False )
        ]


{-| Press a key on the list. The result is the message the list sends, if it
listens to the key.
-}
press : String -> VirtualList.State -> List (VirtualList.Attribute Msg) -> Result String Msg
press name state attributes =
    view attributes state
        |> Query.fromHtml
        |> Event.simulate (Event.custom "keydown" (key name))
        |> Event.toResult


{-| Press a key, and give the answer to the list.
-}
moved : String -> VirtualList.State -> VirtualList.State
moved name state =
    case press name state picking of
        Ok (ListMsg inner) ->
            Tuple.first (VirtualList.update inner state)

        _ ->
            state


activeAfter : List String -> Maybe Int
activeAfter keys =
    List.foldl moved start keys |> VirtualList.active


suite : Test
suite =
    describe "Klar.VirtualList.list"
        [ drawing
        , keyboard
        , picking_
        ]


drawing : Test
drawing =
    describe "drawing"
        [ test "the list is a ul with a li for every row in view, not for all thousand" <|
            \_ ->
                view picking start
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "ul" ]
                        , Query.find [ Selector.id "items-row-0" ] >> Query.has [ Selector.tag "li", Selector.text "Item 0" ]
                        , Query.find [ Selector.id "items-row-13" ] >> Query.has [ Selector.tag "li" ]
                        , \q -> Query.findAll [ Selector.id "items-row-40" ] q |> Query.count (Expect.equal 0)
                        ]
        , test "the rows are as high as the density says, and the list needs no height of its own" <|
            \_ ->
                let
                    styleOf density =
                        view (VirtualList.density density :: picking) start
                            |> Query.fromHtml
                            |> Query.has [ Selector.attribute (Attr.attribute "style" ("height:320px;--klar-vlist-row:" ++ rowHeight density)) ]

                    rowHeight density =
                        case density of
                            Theme.Compact ->
                                "32px"

                            Theme.Normal ->
                                "44px"

                            Theme.Comfortable ->
                                "56px"
                in
                Expect.all
                    [ \_ -> styleOf Theme.Compact
                    , \_ -> styleOf Theme.Normal
                    , \_ -> styleOf Theme.Comfortable
                    ]
                    ()
        , test "every row says its place among all the rows, drawn or not" <|
            \_ ->
                view picking start
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "items-row-4" ]
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "aria-posinset" "5")
                        , Selector.attribute (Attr.attribute "aria-setsize" "1000")
                        ]
        , test "the room of the rows that are not drawn is kept" <|
            \_ ->
                view picking start
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-vlist__spacer" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
        , test "with onSelect it is a list box with a name, and its rows are options" <|
            \_ ->
                view picking start
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "role" "listbox"), Selector.attribute (Attr.attribute "aria-label" "Items") ]
                        , Query.find [ Selector.id "items-row-0" ] >> Query.has [ Selector.attribute (Attr.attribute "role" "option") ]
                        ]
        , test "without onSelect it is a plain list" <|
            \_ ->
                view [] start
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.attribute (Attr.attribute "role" "listbox") ]
                    |> Query.count (Expect.equal 0)
        ]


keyboard : Test
keyboard =
    describe "the keyboard"
        [ test "the active row starts on the first row, and the list points at it" <|
            \_ ->
                view picking start
                    |> Query.fromHtml
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" "items-row-0") ]
        , test "ArrowDown and ArrowUp move the active row by one" <|
            \_ ->
                Expect.equal [ Just 2, Just 1 ] [ activeAfter [ "ArrowDown", "ArrowDown" ], activeAfter [ "ArrowDown", "ArrowDown", "ArrowUp" ] ]
        , test "Home and End go to the first and the last row" <|
            \_ ->
                Expect.equal [ Just 999, Just 0 ] [ activeAfter [ "End" ], activeAfter [ "End", "Home" ] ]
        , test "PageDown and PageUp move by a screenful" <|
            \_ ->
                -- 320 pixels of 44 pixels a row
                Expect.equal [ Just 7, Just 14, Just 7 ] [ activeAfter [ "PageDown" ], activeAfter [ "PageDown", "PageDown" ], activeAfter [ "PageDown", "PageDown", "PageUp" ] ]
        , test "the active row stays inside the list" <|
            \_ ->
                Expect.equal [ Just 0, Just 999 ] [ activeAfter [ "ArrowUp" ], activeAfter [ "End", "ArrowDown", "PageDown" ] ]
        , test "the list points at the active row after it moved, and marks it" <|
            \_ ->
                let
                    state =
                        List.foldl moved start [ "ArrowDown", "ArrowDown", "ArrowDown" ]
                in
                view picking state
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" "items-row-3") ]
                        , Query.find [ Selector.id "items-row-3" ] >> Query.has [ Selector.class "klar-vlist__item--active" ]
                        ]
        , test "the row that was picked is where the active row starts" <|
            \_ ->
                view (VirtualList.selected (Just 5) :: picking) start
                    |> Query.fromHtml
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" "items-row-5") ]
        , test "a list without onSelect does not take the keys" <|
            \_ ->
                press "ArrowDown" start []
                    |> Expect.err
        , test "keys that are not the list's are left to the browser" <|
            \_ ->
                press "a" start picking |> Expect.err
        ]


picking_ : Test
picking_ =
    describe "picking"
        [ test "Enter and Space pick the active row" <|
            \_ ->
                let
                    state =
                        moved "ArrowDown" start
                in
                Expect.equal [ Ok (Picked 1), Ok (Picked 1) ] [ press "Enter" state picking, press " " state picking ]
        , test "a click on a row picks it" <|
            \_ ->
                view picking start
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "items-row-3" ]
                    |> Event.simulate Event.click
                    |> Event.expect (Picked 3)
        , test "the picked row is marked" <|
            \_ ->
                view (VirtualList.selected (Just 2) :: picking) start
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "items-row-2" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-selected" "true"), Selector.class "klar-vlist__item--selected" ]
        ]
