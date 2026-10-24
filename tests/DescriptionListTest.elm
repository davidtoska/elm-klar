module DescriptionListTest exposing (suite)

{-| `Klar.DescriptionList`: missing values are a dash with hidden words, the items
are `div`s of one `dt` and their `dd`s, the columns are kept between 1 and 3, and
the classes of the attributes.
-}

import Expect
import Html
import Html.Attributes as Attr
import Klar.DescriptionList as DescriptionList
import Klar.Locale as Locale
import Klar.Theme exposing (Density(..))
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


missing : List DescriptionList.Attribute -> DescriptionList.Item msg -> Query.Single msg
missing attributes item =
    DescriptionList.view attributes [ item ]
        |> Query.fromHtml
        |> Query.find [ Selector.tag "dd" ]


isMissing : Query.Single msg -> Expect.Expectation
isMissing =
    Expect.all
        [ Query.has [ Selector.class "klar-description-list__value--empty" ]
        , Query.find [ Selector.class "klar-description-list__dash" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
        , Query.find [ Selector.class "klar-sr-only" ] >> Query.has [ Selector.text "Not provided" ]
        ]


suite : Test
suite =
    describe "Klar.DescriptionList"
        [ describe "a missing value is a dash, with words for screen readers"
            [ test "an empty text" <|
                \_ -> missing [] (DescriptionList.text "Phone" "") |> isMissing
            , test "a blank text" <|
                \_ -> missing [] (DescriptionList.text "Phone" "   ") |> isMissing
            , test "Nothing" <|
                \_ -> missing [] (DescriptionList.maybe "Phone" Nothing) |> isMissing
            , test "Just a blank text" <|
                \_ -> missing [] (DescriptionList.maybe "Phone" (Just " ")) |> isMissing
            , test "no values" <|
                \_ -> missing [] (DescriptionList.values "Channels" []) |> isMissing
            , test "the words follow the locale" <|
                \_ ->
                    missing [ DescriptionList.locale Locale.nb ] (DescriptionList.text "Telefon" "")
                        |> Query.has [ Selector.text "Ikke oppgitt" ]
            ]
        , test "Html always counts as a value, even when it shows nothing" <|
            \_ ->
                missing [] (DescriptionList.html "Status" (Html.text ""))
                    |> Query.hasNot [ Selector.class "klar-description-list__value--empty" ]
        , test "a text value is shown as it is" <|
            \_ ->
                missing [] (DescriptionList.text "Customer number" "100482")
                    |> Query.has [ Selector.text "100482" ]
        , test "every item is a div with one dt, in a dl" <|
            \_ ->
                DescriptionList.view []
                    [ DescriptionList.text "Customer number" "100482"
                    , DescriptionList.values "Channels" [ Html.text "Web", Html.text "Wholesale" ]
                    ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "dl" ]
                        , Query.children [ Selector.tag "div" ] >> Query.count (Expect.equal 2)
                        , Query.findAll [ Selector.tag "dt" ] >> Query.count (Expect.equal 2)
                        , Query.children [ Selector.tag "div" ] >> Query.each (Query.children [ Selector.tag "dt" ] >> Query.count (Expect.equal 1))
                        ]
        , test "fullWidth takes the whole row" <|
            \_ ->
                DescriptionList.view [] [ DescriptionList.text "Note" "Fragile" |> DescriptionList.fullWidth ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-description-list__item--full" ]
        , describe "columns are kept between 1 and 3"
            [ test "0 is 1" <|
                \_ ->
                    DescriptionList.view [ DescriptionList.columns 0 ] []
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-dl-cols:1;--klar-dl-label-w:160px") ]
            , test "9 is 3" <|
                \_ ->
                    DescriptionList.view [ DescriptionList.columns 9 ] []
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-dl-cols:3;--klar-dl-label-w:160px") ]
            ]
        , test "labelBeside and bordered" <|
            \_ ->
                DescriptionList.view [ DescriptionList.labelBeside, DescriptionList.bordered ] []
                    |> Query.fromHtml
                    |> Query.has [ Selector.classes [ "klar-description-list--beside", "klar-description-list--bordered" ] ]
        , describe "density"
            [ test "without it, no class: the list follows the application" <|
                \_ ->
                    DescriptionList.view [] []
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.hasNot [ Selector.class "klar-description-list--compact" ]
                            , Query.hasNot [ Selector.class "klar-description-list--normal" ]
                            , Query.hasNot [ Selector.class "klar-description-list--comfortable" ]
                            ]
            , test "Compact" <|
                \_ -> DescriptionList.view [ DescriptionList.density Compact ] [] |> Query.fromHtml |> Query.has [ Selector.class "klar-description-list--compact" ]
            , test "Normal, to stay normal in a compact application" <|
                \_ -> DescriptionList.view [ DescriptionList.density Normal ] [] |> Query.fromHtml |> Query.has [ Selector.class "klar-description-list--normal" ]
            , test "Comfortable" <|
                \_ -> DescriptionList.view [ DescriptionList.density Comfortable ] [] |> Query.fromHtml |> Query.has [ Selector.class "klar-description-list--comfortable" ]
            ]
        ]
