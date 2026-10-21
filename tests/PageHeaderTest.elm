module PageHeaderTest exposing (suite)

{-| The level of the title of a page header.
-}

import Klar.PageHeader as PageHeader
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.PageHeader headingLevel"
        [ test "the title is an h1 by default" <|
            \_ ->
                PageHeader.view [ PageHeader.title "Orders" ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "h1" ]
                    |> Query.has [ Selector.text "Orders" ]
        , test "headingLevel 3 makes it an h3 and not an h1" <|
            \_ ->
                let
                    header =
                        PageHeader.view [ PageHeader.title "Orders", PageHeader.headingLevel 3 ]
                            |> Query.fromHtml
                in
                header
                    |> Query.find [ Selector.tag "h3" ]
                    |> Query.has [ Selector.text "Orders", Selector.class "klar-page-header__title" ]
        , test "headingLevel 3 leaves no h1 in the header" <|
            \_ ->
                PageHeader.view [ PageHeader.title "Orders", PageHeader.headingLevel 3 ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "h1" ]
        , test "the order of the attributes does not matter" <|
            \_ ->
                PageHeader.view [ PageHeader.headingLevel 2, PageHeader.title "Orders" ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "h2" ]
        , test "a level above six is the nearest level, six" <|
            \_ ->
                PageHeader.view [ PageHeader.title "Orders", PageHeader.headingLevel 9 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "h6" ]
        , test "a level below one is the nearest level, one" <|
            \_ ->
                PageHeader.view [ PageHeader.title "Orders", PageHeader.headingLevel -4 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "h1" ]
        , test "without a title there is no heading, whatever the level" <|
            \_ ->
                PageHeader.view [ PageHeader.subtitle "Only a line of text", PageHeader.headingLevel 2 ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "h2" ]
        ]
