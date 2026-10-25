module ToolbarTest exposing (suite)

{-| `Klar.Toolbar`: the classes of its attributes and the markup of its parts.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Theme exposing (Size(..))
import Klar.Toolbar as Toolbar
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


bar : List Toolbar.Attribute -> Html msg
bar attributes =
    Toolbar.view attributes [ Html.text "x" ]


suite : Test
suite =
    describe "Klar.Toolbar"
        [ test "size Small is the small bar" <|
            \_ -> bar [ Toolbar.size Small ] |> Query.fromHtml |> Query.has [ Selector.class "klar-toolbar--sm" ]
        , test "size Large is the large bar" <|
            \_ -> bar [ Toolbar.size Large ] |> Query.fromHtml |> Query.has [ Selector.class "klar-toolbar--lg" ]
        , test "size Medium has no size class" <|
            \_ ->
                bar [ Toolbar.small, Toolbar.size Medium ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-toolbar--sm" ]
        , test "small is size Small" <|
            \_ -> bar [ Toolbar.small ] |> Query.fromHtml |> Query.has [ Selector.class "klar-toolbar--sm" ]
        , test "plain and scroll" <|
            \_ ->
                bar [ Toolbar.plain, Toolbar.scroll ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.classes [ "klar-toolbar--plain", "klar-toolbar--scroll" ] ]
        , test "the separator is a vertical separator" <|
            \_ ->
                Toolbar.view [] [ Toolbar.separator ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-toolbar__separator" ]
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "role" "separator")
                        , Selector.attribute (Attr.attribute "aria-orientation" "vertical")
                        ]
        , test "a label is plain text" <|
            \_ ->
                Toolbar.view [] [ Toolbar.label "1,482 orders" ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-toolbar__label" ]
                    |> Query.has [ Selector.text "1,482 orders" ]
        ]
