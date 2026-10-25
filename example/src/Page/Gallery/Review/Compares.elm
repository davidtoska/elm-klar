module Page.Gallery.Review.Compares exposing (Model, Msg, init, update, view)

{-| The compare section of the review page: three products side by side, with buttons
that put the table in every state it has (data, loading, failure, nothing to compare,
one record, refreshing, old data after a refresh that failed) and that change the
baseline and the density.
-}

import Html exposing (Html)
import Klar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Compare as Compare
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Text as Text
import Klar.Theme as Theme exposing (Density(..))
import Page.Gallery.Review.Samples as Samples exposing (Product, ProductId)
import Process
import Showcase.Doc as Doc
import Task
import Time



-- MODEL


type alias Model =
    { products : Remote (List Product)
    , onlyDifferences : Bool
    , baseline : Maybe ProductId
    , density : Density
    }


type Msg
    = Show Scenario
    | OnlyDifferences Bool
    | SetBaseline ProductId
    | SetDensity Density
    | Refresh Outcome
    | Refreshed Outcome Time.Posix
    | Retry
    | Focused


type Scenario
    = AllThree
    | LoadingNow
    | Failed
    | NoRecords
    | OnlyOne


{-| How the pretend refresh ends.
-}
type Outcome
    = Succeeds
    | Fails


init : Model
init =
    { products = Remote.Loaded Samples.products
    , onlyDifferences = False
    , baseline = Nothing
    , density = Normal
    }


compareId : String
compareId =
    "compare-products"



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Show scenario ->
            ( { model | products = productsFor scenario }, Cmd.none )

        OnlyDifferences value ->
            ( { model | onlyDifferences = value }, Cmd.none )

        SetBaseline id ->
            ( { model | baseline = Just id }, Cmd.none )

        SetDensity value ->
            ( { model | density = value }, Cmd.none )

        Refresh outcome ->
            ( { model | products = Remote.refresh model.products }, later (Refreshed outcome) )

        Refreshed outcome now ->
            ( { model
                | products =
                    Remote.refreshWith model.products
                        (case outcome of
                            Succeeds ->
                                Ok Samples.products

                            Fails ->
                                Err (Remote.problem Remote.network)
                        )
                        now
              }
            , Cmd.none
            )

        Retry ->
            -- "Try again" goes away with the new data: focus waits on the comparison
            ( { model | products = Remote.refresh model.products }
            , Cmd.batch [ later (Refreshed Succeeds), Klar.focus compareId Focused ]
            )

        Focused ->
            ( model, Cmd.none )


productsFor : Scenario -> Remote (List Product)
productsFor scenario =
    case scenario of
        AllThree ->
            Remote.Loaded Samples.products

        LoadingNow ->
            Remote.Loading

        Failed ->
            Remote.Failed (Remote.problem Remote.network)

        NoRecords ->
            Remote.Loaded []

        OnlyOne ->
            Remote.Loaded (List.take 1 Samples.products)


later : (Time.Posix -> Msg) -> Cmd Msg
later toMsg =
    Process.sleep 1200
        |> Task.andThen (\_ -> Time.now)
        |> Task.perform toMsg



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "Compare"
        "Records side by side, with the differences marked: the fields are the rows and the records are the columns. Every record is compared with the baseline (the first record, or the one you name). A cell that differs has a sign and hidden text as well as a color, a cell that is the same says so to a screen reader, and a row where every record is equal is dimmed, or left out by the switch \"Show only differences\". The row labels and the headings stay in view while the table scrolls."
        [ productsExample locale model
        , Doc.example
            { title = "What counts as the same"
            , description = Just "Every field gives a text for each record, and two records are the same when the texts are exactly equal. The price is compared as 12.5 and shown as $12.50, so two prices that look alike after rounding are still different. A blank text is no value: a dash, with hidden text for screen readers. Functions are never compared."
            , code = Just """Compare.html "Price"
    (\\product -> String.fromFloat product.price) -- what is compared
    (\\product -> Html.text (Format.currency locale "$" 2 product.price)) -- what is shown

Compare.maybe "Discount" (.discount >> Maybe.map String.fromInt)"""
            }
            (Text.caption "Try \"Show only differences\" above: the \"Pricing\" heading disappears when no price differs.")
        ]


productsExample : Locale -> Model -> Html Msg
productsExample locale model =
    Doc.example
        { title = "Three products"
        , description = Just "The buttons put the table in each of its states. \"Refresh\" keeps the table, dimmed, with a progress line (Remote.refresh). \"Refresh, then fail\" ends with the old data still shown, marked \"Old data from\" its time, with \"Try again\" in the toolbar. Choose the baseline with \"Set as baseline\" in the heading of a record (Compare.onBaseline), or with the buttons above, to compare the others with a different record. The \"Summary\" field marks the words that differ from the baseline."
        , code = Just """Compare.viewRemote
    [ Compare.baseline model.baseline
    , Compare.onlyDifferences model.onlyDifferences
    , Compare.onOnlyDifferences OnlyDifferences
    , Compare.onBaseline SetBaseline
    , Compare.onRetry Retry
    , Compare.id "compare-products"
    , Compare.locale locale
    , Compare.settings model.settings
    ]
    { ariaLabel = "Compare products"
    , ids = productIds
    , id = .id
    , header = \\product -> Html.text product.name
    , fields =
        [ Compare.text "SKU" .sku
        , Compare.html "Status" .status viewStatus
        , Compare.heading "Pricing"
        , Compare.html "Price" (.price >> String.fromFloat) viewPrice
        , Compare.maybe "Discount" (.discount >> Maybe.map String.fromInt)
        , Compare.heading "Description"
        , Compare.longText "Summary" .summary
        ]
    }
    model.products -- Remote (List Product)"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                (Text.caption "Show:"
                    :: List.map
                        (\( label, scenario ) -> Button.view [ Button.small, Button.onClick (Show scenario) ] label)
                        [ ( "All three", AllThree ), ( "Loading", LoadingNow ), ( "Failure", Failed ), ( "Nothing to compare", NoRecords ), ( "One record", OnlyOne ) ]
                    ++ [ Button.view [ Button.small, Button.onClick (Refresh Succeeds), Button.loading (Remote.isRefreshing model.products) ] "Refresh"
                       , Button.view [ Button.small, Button.onClick (Refresh Fails), Button.loading (Remote.isRefreshing model.products) ] "Refresh, then fail"
                       ]
                )
            , Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                (Text.caption "Baseline:"
                    :: List.map
                        (\product ->
                            Button.view
                                [ Button.small
                                , Button.pressed (isBaseline model product)
                                , Button.onClick (SetBaseline product.id)
                                ]
                                product.name
                        )
                        Samples.products
                    ++ [ Text.caption "Density:" ]
                    ++ List.map
                        (\( label, density ) ->
                            Button.view [ Button.small, Button.pressed (model.density == density), Button.onClick (SetDensity density) ] label
                        )
                        [ ( "Compact", Compact ), ( "Normal", Normal ), ( "Comfortable", Comfortable ) ]
                )
            , Compare.viewRemote
                (List.concat
                    [ [ Compare.onlyDifferences model.onlyDifferences
                      , Compare.onOnlyDifferences OnlyDifferences
                      , Compare.onRetry Retry
                      , Compare.onBaseline SetBaseline
                      , Compare.id compareId
                      , Compare.density model.density
                      , Compare.emptyState [ EmptyState.description "Add at least two products from the product list." ]
                      , Compare.locale locale
                      ]
                    , case model.baseline of
                        Just id ->
                            [ Compare.baseline id ]

                        Nothing ->
                            []
                    ]
                )
                { ariaLabel = "Compare products"
                , ids = Samples.productIds
                , id = .id
                , header = \product -> Html.text product.name
                , fields = fields locale
                }
                model.products
            ]
        )


isBaseline : Model -> Product -> Bool
isBaseline model product =
    case model.baseline of
        Just id ->
            id == product.id

        Nothing ->
            List.head Samples.products |> Maybe.map (\first -> first.id == product.id) |> Maybe.withDefault False


fields : Locale -> List (Compare.Field Product Msg)
fields locale =
    [ Compare.text "SKU" .sku
    , Compare.html "Status" .status viewStatus
    , Compare.text "Warehouse" .warehouse
    , Compare.text "Dimensions" .dimensions
    , Compare.heading "Pricing"
    , Compare.html "Price" (.price >> String.fromFloat) (\product -> Html.text (Format.currency locale "$" 2 product.price))
    , Compare.maybe "Discount" (.discount >> Maybe.map (\percent -> String.fromInt percent ++ " %"))
    , Compare.text "In stock" (.stock >> String.fromInt)
    , Compare.heading "Description"
    , Compare.longText "Summary" .summary
    ]


viewStatus : Product -> Html msg
viewStatus product =
    Badge.view
        [ Badge.tone
            (if product.status == "Active" then
                Theme.Success

             else
                Theme.Neutral
            )
        ]
        product.status
