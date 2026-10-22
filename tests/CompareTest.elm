module CompareTest exposing (suite)

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Compare as Compare
import Klar.EmptyState as EmptyState
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Theme exposing (Density(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Retry
    | OnlyDifferences Bool


type alias Product =
    { id : Int
    , sku : String
    , name : String
    , price : Float
    , warehouse : String
    , discount : Maybe Int
    , summary : String
    }


widget : Product
widget =
    { id = 1
    , sku = "W-100"
    , name = "Widget"
    , price = 12.5
    , warehouse = "Bergen"
    , discount = Nothing
    , summary = "A sturdy steel widget for light duty."
    }


gadget : Product
gadget =
    { id = 2
    , sku = "G-200"
    , name = "Gadget"
    , price = 12.5
    , warehouse = "Bergen"
    , discount = Just 10
    , summary = "A sturdy steel gadget for heavy duty."
    }


gizmo : Product
gizmo =
    { id = 3
    , sku = "Z-300"
    , name = "Gizmo"
    , price = 19
    , warehouse = "Bergen"
    , discount = Nothing
    , summary = "A sturdy steel widget for light duty."
    }


products : List Product
products =
    [ widget, gadget, gizmo ]


fields : List (Compare.Field Product Msg)
fields =
    [ Compare.text "SKU" .sku
    , Compare.text "Warehouse" .warehouse
    , Compare.heading "Pricing"
    , Compare.html "Price" (.price >> String.fromFloat) (\product -> Html.span [ Attr.class "price" ] [ Html.text ("$" ++ String.fromFloat product.price) ])
    , Compare.maybe "Discount" (.discount >> Maybe.map String.fromInt)
    , Compare.heading "Description"
    , Compare.longText "Summary" .summary
    ]


compare : List (Compare.Attribute Int Msg) -> Remote (List Product) -> Html Msg
compare attributes records =
    Compare.view attributes
        { label = "Compare products"
        , records = records
        , id = .id
        , toKey = String.fromInt
        , header = \product -> Html.span [ Attr.class "product-name" ] [ Html.text product.name ]
        , fields = fields
        }


shown : List (Compare.Attribute Int Msg) -> List Product -> Query.Single Msg
shown attributes records =
    compare attributes (Loaded records) |> Query.fromHtml


byClass : String -> Selector
byClass name =
    Selector.class name


suite : Test
suite =
    describe "Klar.Compare"
        [ statesTests
        , structureTests
        , marksTests
        , baselineTests
        , onlyDifferencesTests
        , missingTests
        , edgeTests
        , wordDiffTests
        , localeTests
        ]


statesTests : Test
statesTests =
    describe "the states"
        [ test "no records is the empty state" <|
            \_ ->
                compare [] (Loaded [])
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "Nothing to compare" ]
                        , Query.hasNot [ Selector.tag "table" ]
                        ]
        , test "the empty state can be changed" <|
            \_ ->
                compare [ Compare.emptyState [ EmptyState.title "Pick two products" ] ] (Loaded [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Pick two products" ]
        , test "loading is a skeleton and says so" <|
            \_ ->
                compare [] Loading
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ byClass "klar-skeleton" ]
                        , Query.has [ Selector.text "Loading ..." ]
                        , Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
                        ]
        , test "not asked yet is a skeleton as well" <|
            \_ -> compare [] NotAsked |> Query.fromHtml |> Query.has [ byClass "klar-skeleton" ]
        , test "a failure shows the problem and a button to try again" <|
            \_ ->
                compare [ Compare.onRetry Retry ] (Failed (Remote.problem Remote.server))
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect Retry
        , test "there is no button for a problem that would fail again" <|
            \_ ->
                compare [ Compare.onRetry Retry ] (Failed (Remote.problem Remote.notFound))
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "button" ]
        , test "there is no button without a message" <|
            \_ ->
                compare [] (Failed (Remote.problem Remote.server))
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "button" ]
        , test "refreshing keeps the table, dims it and says so" <|
            \_ ->
                shown [ Compare.refreshing True ] products
                    |> Expect.all
                        [ Query.has [ byClass "klar-compare--refreshing" ]
                        , Query.has [ byClass "klar-compare__progress" ]
                        , Query.has [ Selector.text "Refreshing ..." ]
                        , Query.find [ Selector.tag "table" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
                        ]
        , test "a table that is not refreshing has no progress line" <|
            \_ -> shown [] products |> Query.hasNot [ byClass "klar-compare__progress" ]
        , test "refreshing is ignored while loading" <|
            \_ -> compare [ Compare.refreshing True ] Loading |> Query.fromHtml |> Query.hasNot [ byClass "klar-compare__progress" ]
        ]


structureTests : Test
structureTests =
    describe "the table"
        [ test "the records are column headings and the fields are row headings" <|
            \_ ->
                shown [] products
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "col") ] >> Query.count (Expect.equal 4)
                        , Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "row") ] >> Query.count (Expect.equal 5)
                        ]
        , test "a group of fields has a heading that spans the table" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "rowgroup") ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.first >> Query.has [ Selector.text "Pricing", Selector.attribute (Attr.colspan 4) ]
                        ]
        , test "the table has a name and the box that scrolls is a named region and a tab stop" <|
            \_ ->
                shown [] products
                    |> Expect.all
                        [ Query.find [ Selector.tag "table" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Compare products") ]
                        , Query.find [ byClass "klar-compare__scroll" ]
                            >> Query.has
                                [ Selector.attribute (Attr.attribute "role" "region")
                                , Selector.attribute (Attr.attribute "aria-label" "Compare products")
                                , Selector.attribute (Attr.tabindex 0)
                                ]
                        ]
        , test "the heading of a record is whatever the application gives" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "product-name" ]
                    |> Query.count (Expect.equal 3)
        , test "the values are shown as text or as the Html of the application" <|
            \_ ->
                shown [] products
                    |> Expect.all
                        [ Query.has [ Selector.text "W-100" ]
                        , Query.findAll [ byClass "price" ] >> Query.count (Expect.equal 3)
                        ]
        , test "the density is a class" <|
            \_ ->
                Expect.all
                    [ \_ -> shown [ Compare.density Compact ] products |> Query.has [ byClass "klar-compare--compact" ]
                    , \_ -> shown [ Compare.density Comfortable ] products |> Query.has [ byClass "klar-compare--comfortable" ]
                    , \_ -> shown [] products |> Query.has [ byClass "klar-compare--normal" ]
                    ]
                    ()
        , test "a maximum height is a style on the box that scrolls" <|
            \_ ->
                shown [ Compare.maxHeight 320 ] products
                    |> Query.find [ byClass "klar-compare__scroll" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "max-height:320px") ]
        , test "the headings of the fields come in the order they were given" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "row") ]
                    |> Query.first
                    |> Query.has [ Selector.text "SKU" ]
        ]


marksTests : Test
marksTests =
    describe "the differences"
        [ test "a cell that differs from the baseline has a sign and says so in text" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__cell--differs" ]
                    |> Query.each
                        (Expect.all
                            [ Query.has [ Selector.text "Differs from baseline" ]
                            , Query.has [ Selector.text "≠" ]
                            ]
                        )
        , test "a cell that is the same says so in text" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__cell--same" ]
                    |> Query.each (Query.has [ Selector.text "Same as baseline" ])
        , test "the sign is hidden from screen readers" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__sign" ]
                    |> Query.each (Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ])
        , test "the baseline column has no marks" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__cell--baseline" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 5)
                        , Query.each (Query.hasNot [ Selector.text "Differs from baseline" ])
                        ]
        , test "the count of cells of each kind" <|
            \_ ->
                -- 5 fields x 2 other records: SKU (2 differ), Warehouse (2 same), Price (1 same, 1 differs),
                -- Discount (1 differs, 1 same), Summary (1 differs, 1 same)
                shown [] products
                    |> Expect.all
                        [ Query.findAll [ byClass "klar-compare__cell--differs" ] >> Query.count (Expect.equal 5)
                        , Query.findAll [ byClass "klar-compare__cell--same" ] >> Query.count (Expect.equal 5)
                        ]
        , test "a row where every record is equal is marked as equal" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__row--equal" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.first >> Query.has [ Selector.text "Warehouse" ]
                        ]
        , test "the toolbar says how many fields differ" <|
            \_ ->
                shown [] products
                    |> Query.has [ Selector.text "4 of 5 fields differ from the baseline" ]
        , test "the summary is a status that screen readers hear" <|
            \_ ->
                shown [] products
                    |> Query.find [ byClass "klar-compare__summary" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "role" "status") ]
        , test "two records with exactly the same texts are the same, and a trailing space is a difference" <|
            \_ ->
                shown [] [ widget, { gadget | sku = "W-100" }, { gizmo | sku = "W-100 " } ]
                    |> Query.findAll [ byClass "klar-compare__row", Selector.containing [ Selector.text "SKU" ] ]
                    |> Query.first
                    |> Expect.all
                        [ Query.has [ Selector.containing [ byClass "klar-compare__cell--same" ] ]
                        , Query.has [ Selector.containing [ byClass "klar-compare__cell--differs" ] ]
                        ]
        ]


baselineTests : Test
baselineTests =
    describe "the baseline"
        [ test "the first record is the baseline" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__head--baseline" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.first >> Query.has [ Selector.text "Widget", Selector.text "Baseline" ]
                        ]
        , test "another record can be the baseline" <|
            \_ ->
                shown [ Compare.baseline 3 ] products
                    |> Query.findAll [ byClass "klar-compare__head--baseline" ]
                    |> Query.first
                    |> Query.has [ Selector.text "Gizmo" ]
        , test "the cells are compared with the record that is the baseline" <|
            \_ ->
                -- the summary of the gizmo is the summary of the widget
                shown [ Compare.baseline 3 ] products
                    |> Query.findAll [ byClass "klar-compare__row", Selector.containing [ Selector.text "Summary" ] ]
                    |> Query.first
                    |> Query.findAll [ byClass "klar-compare__cell" ]
                    |> Query.index 0
                    |> Query.has [ byClass "klar-compare__cell--same" ]
        , test "a baseline that is not among the records is the first record" <|
            \_ ->
                shown [ Compare.baseline 99 ] products
                    |> Query.find [ byClass "klar-compare__head--baseline" ]
                    |> Query.has [ Selector.text "Widget" ]
        , test "a single record is not called the baseline" <|
            \_ -> shown [] [ widget ] |> Query.hasNot [ byClass "klar-compare__head--baseline" ]
        ]


onlyDifferencesTests : Test
onlyDifferencesTests =
    describe "showing only the differences"
        [ test "without the attribute there is no switch" <|
            \_ -> shown [] products |> Query.hasNot [ Selector.tag "input" ]
        , test "the switch is shown and is on or off as the application says" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        shown [ Compare.onlyDifferences False OnlyDifferences ] products
                            |> Query.find [ Selector.tag "input" ]
                            |> Query.has [ Selector.attribute (Attr.attribute "role" "switch"), Selector.checked False ]
                    , \_ ->
                        shown [ Compare.onlyDifferences True OnlyDifferences ] products
                            |> Query.find [ Selector.tag "input" ]
                            |> Query.has [ Selector.checked True ]
                    ]
                    ()
        , test "the switch has its label" <|
            \_ ->
                shown [ Compare.onlyDifferences False OnlyDifferences ] products
                    |> Query.has [ Selector.text "Show only differences" ]
        , test "flipping the switch sends the new value" <|
            \_ ->
                shown [ Compare.onlyDifferences False OnlyDifferences ] products
                    |> Query.find [ Selector.tag "input" ]
                    |> Event.simulate (Event.check True)
                    |> Event.expect (OnlyDifferences True)
        , test "when it is off the rows that are equal are dimmed and still there" <|
            \_ ->
                shown [ Compare.onlyDifferences False OnlyDifferences ] products
                    |> Expect.all
                        [ Query.has [ Selector.text "Warehouse" ]
                        , Query.has [ byClass "klar-compare__row--equal" ]
                        ]
        , test "when it is on the rows that are equal are left out" <|
            \_ ->
                shown [ Compare.onlyDifferences True OnlyDifferences ] products
                    |> Expect.all
                        [ Query.hasNot [ Selector.text "Warehouse" ]
                        , Query.has [ Selector.text "SKU" ]
                        , Query.hasNot [ byClass "klar-compare__row--equal" ]
                        ]
        , test "the counts follow the switch" <|
            \_ ->
                shown [ Compare.onlyDifferences True OnlyDifferences ] products
                    |> Query.has [ Selector.text "Showing 4 of 5 fields" ]
        , test "a heading with no row left is left out too" <|
            \_ ->
                -- all three have the same price: the heading "Pricing" has nothing under it
                -- once the discount is the same too
                shown [ Compare.onlyDifferences True OnlyDifferences ] [ widget, { widget | id = 2 }, { widget | id = 3 } ]
                    |> Expect.all
                        [ Query.hasNot [ Selector.text "Pricing" ]
                        , Query.has [ Selector.text "No differences" ]
                        ]
        , test "a heading with a row left stays" <|
            \_ ->
                shown [ Compare.onlyDifferences True OnlyDifferences ] products
                    |> Expect.all
                        [ Query.has [ Selector.text "Pricing" ]
                        , Query.has [ Selector.text "Description" ]
                        ]
        , test "with a single record the switch is dimmed and everything is shown" <|
            \_ ->
                shown [ Compare.onlyDifferences True OnlyDifferences ] [ widget ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "input" ] >> Query.has [ Selector.disabled True ]
                        , Query.has [ Selector.text "Warehouse" ]
                        ]
        ]


missingTests : Test
missingTests =
    describe "values that are missing"
        [ test "a missing value is a dash with a hidden text" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__none-mark" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.each (Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ])
                        ]
        , test "the hidden text says that it was not provided" <|
            \_ -> shown [] products |> Query.has [ Selector.text "Not provided" ]
        , test "no value and no value are the same" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__row", Selector.containing [ Selector.text "Discount" ] ]
                    |> Query.first
                    |> Query.findAll [ byClass "klar-compare__cell" ]
                    |> Expect.all
                        [ Query.index 0 >> Query.has [ byClass "klar-compare__cell--baseline" ]
                        , Query.index 1 >> Query.has [ byClass "klar-compare__cell--differs" ]
                        , Query.index 2 >> Query.has [ byClass "klar-compare__cell--same" ]
                        ]
        , test "a blank text is no value" <|
            \_ ->
                shown [] [ { widget | sku = "  " }, { gadget | sku = "" } ]
                    |> Query.findAll [ byClass "klar-compare__row", Selector.containing [ Selector.text "SKU" ] ]
                    |> Query.first
                    |> Query.has [ Selector.containing [ byClass "klar-compare__cell--same" ] ]
        , test "the html of a field is not drawn for a missing value" <|
            \_ ->
                shown [] [ widget, { gadget | price = 0 } ]
                    |> Query.findAll [ byClass "price" ]
                    |> Query.count (Expect.equal 2)
        ]


edgeTests : Test
edgeTests =
    describe "few and many records"
        [ test "a single record has nothing to compare and says so" <|
            \_ ->
                shown [] [ widget ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Only one record" ]
                        , Query.hasNot [ byClass "klar-compare__cell--differs" ]
                        , Query.hasNot [ byClass "klar-compare__cell--same" ]
                        , Query.findAll [ byClass "klar-compare__cell--alone" ] >> Query.count (Expect.equal 5)
                        ]
        , test "two records with the same id are both drawn" <|
            \_ ->
                shown [] [ widget, { gadget | id = 1 } ]
                    |> Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "col") ]
                    |> Query.count (Expect.equal 3)
        , test "a hundred records" <|
            \_ ->
                let
                    many =
                        List.range 1 100 |> List.map (\i -> { widget | id = i, name = "Item " ++ String.fromInt i, sku = "S-" ++ String.fromInt (modBy 7 i) })
                in
                shown [] many
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "col") ] >> Query.count (Expect.equal 101)
                        , Query.findAll [ byClass "klar-compare__head--baseline" ] >> Query.count (Expect.equal 1)
                        ]
        , test "a hundred equal records have no differing cell" <|
            \_ ->
                shown [] (List.range 1 100 |> List.map (\i -> { widget | id = i }))
                    |> Expect.all
                        [ Query.hasNot [ byClass "klar-compare__cell--differs" ]
                        , Query.has [ Selector.text "0 of 5 fields differ from the baseline" ]
                        ]
        ]


wordDiffTests : Test
wordDiffTests =
    describe "long text"
        [ test "the cell that differs marks the words that differ from the baseline" <|
            \_ ->
                shown [] [ widget, gadget ]
                    |> Query.findAll [ byClass "klar-compare__cell--long", byClass "klar-compare__cell--differs" ]
                    |> Query.first
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "del" ] >> Query.first >> Query.has [ Selector.text "widget" ]
                        , Query.findAll [ Selector.tag "ins" ] >> Query.first >> Query.has [ Selector.text "gadget" ]
                        , Query.findAll [ Selector.tag "del" ] >> Query.count (Expect.equal 2)
                        , Query.has [ Selector.text "heavy" ]
                        ]
        , test "the baseline is shown as it is" <|
            \_ ->
                shown [] [ widget, gadget ]
                    |> Query.findAll [ byClass "klar-compare__cell--long", byClass "klar-compare__cell--baseline" ]
                    |> Query.first
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "ins" ]
                        , Query.has [ Selector.text "A sturdy steel widget for light duty." ]
                        ]
        , test "a cell that is the same is shown as it is" <|
            \_ ->
                shown [] products
                    |> Query.findAll [ byClass "klar-compare__cell--long", byClass "klar-compare__cell--same" ]
                    |> Query.first
                    |> Query.hasNot [ Selector.tag "ins" ]
        , test "a text with nothing in common is shown as it is" <|
            \_ ->
                shown [] [ widget, { gadget | summary = "Completely unrelated" } ]
                    |> Query.findAll [ byClass "klar-compare__cell--long", byClass "klar-compare__cell--differs" ]
                    |> Query.first
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "ins" ]
                        , Query.has [ Selector.text "Completely unrelated" ]
                        ]
        ]


localeTests : Test
localeTests =
    describe "the language"
        [ test "Norwegian" <|
            \_ ->
                shown [ Compare.locale Locale.nb, Compare.onlyDifferences False OnlyDifferences ] products
                    |> Expect.all
                        [ Query.has [ Selector.text "Felt" ]
                        , Query.has [ Selector.text "Referanse" ]
                        , Query.has [ Selector.text "Avviker fra referansen" ]
                        , Query.has [ Selector.text "Lik referansen" ]
                        , Query.has [ Selector.text "Vis bare forskjeller" ]
                        , Query.has [ Selector.text "4 av 5 felt avviker fra referansen" ]
                        ]
        , test "Norwegian states" <|
            \_ ->
                compare [ Compare.locale Locale.nb ] (Loaded [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Ingenting å sammenligne" ]
        ]
