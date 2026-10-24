module Page.Gallery.Picking exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: picking from trees and lists. A warehouse hierarchy (region,
site, zone, bin) in a TreeSelect and in a Cascader, with branches that are fetched
when they are opened and one that fails, a tree of five thousand nodes, and a
Transfer that assigns products to a promotion from a list of two thousand.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Button as Button
import Klar.Cascader as Cascader
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Picking as Picking exposing (Node)
import Klar.Remote as Remote exposing (Problem, Remote(..))
import Klar.Select as Select
import Klar.Text as Text
import Klar.Transfer as Transfer
import Klar.TreeSelect as TreeSelect
import Process
import Showcase.Doc as Doc
import Task
import Time



-- DATA


{-| A place in the warehouse hierarchy: a region, a site, a zone or a bin. The
application's own id type; the components only ever see its key.
-}
type LocationId
    = LocationId String


locationIds : Ids LocationId
locationIds =
    Ids.make { toKey = \(LocationId key) -> key, fromKey = Just << LocationId }


locationText : LocationId -> String
locationText (LocationId key) =
    key


type ProductNo
    = ProductNo Int


productIds : Ids ProductNo
productIds =
    Ids.make { toKey = \(ProductNo n) -> String.fromInt n, fromKey = Maybe.map ProductNo << String.toInt }


productText : ProductNo -> String
productText (ProductNo n) =
    String.fromInt n


{-| How the zones of a site reach the page: with the site, when the user opens it,
or when the user opens it but the backend fails the first two times.
-}
type Delivery
    = WithSite
    | WhenOpened
    | FailsFirst
    | Closed


type alias Region =
    { id : String
    , name : String
    , sites : List Site
    }


type alias Site =
    { id : String
    , name : String
    , code : String
    , delivery : Delivery
    }


type alias Zone =
    { id : String
    , name : String
    , bins : List Bin
    }


type alias Bin =
    { id : String
    , name : String
    , usable : Bool
    }


regions : List Region
regions =
    [ { id = "nordics"
      , name = "Nordics"
      , sites =
            [ { id = "oslo", name = "Oslo", code = "OSL", delivery = WithSite }
            , { id = "bergen", name = "Bergen", code = "BGO", delivery = WhenOpened }
            , { id = "gothenburg", name = "Gothenburg", code = "GOT", delivery = WithSite }
            ]
      }
    , { id = "central"
      , name = "Central Europe"
      , sites =
            [ { id = "hamburg", name = "Hamburg", code = "HAM", delivery = FailsFirst }
            , { id = "rotterdam", name = "Rotterdam", code = "RTM", delivery = WhenOpened }
            , { id = "frankfurt", name = "Frankfurt (closed)", code = "FRA", delivery = Closed }
            ]
      }
    , { id = "iberia"
      , name = "Iberia"
      , sites = [ { id = "valencia", name = "Valencia", code = "VLC", delivery = WithSite } ]
      }
    ]


{-| The zones of a site, as the backend would answer.
-}
zonesOf : String -> List Zone
zonesOf siteId =
    [ ( "receiving", "Receiving" ), ( "picking", "Picking" ), ( "cold", "Cold store" ) ]
        |> List.map
            (\( zoneId, zoneName ) ->
                { id = siteId ++ "/" ++ zoneId
                , name = zoneName
                , bins =
                    List.range 1 4
                        |> List.map
                            (\n ->
                                let
                                    label =
                                        "A-0" ++ String.fromInt n
                                in
                                { id = siteId ++ "/" ++ zoneId ++ "/" ++ label, name = "Bin " ++ label, usable = not (zoneId == "cold" && n == 4) }
                            )
                }
            )


zoneNode : Zone -> Node LocationId
zoneNode zone =
    Picking.branch locationIds (LocationId zone.id) zone.name (List.map binNode zone.bins)


binNode : Bin -> Node LocationId
binNode bin =
    if bin.usable then
        Picking.leaf locationIds (LocationId bin.id) bin.name

    else
        Picking.leaf locationIds (LocationId bin.id) bin.name |> Picking.withDescription "damaged" |> Picking.disabled


siteNode : Dict String (Remote (List Zone)) -> Site -> Node LocationId
siteNode fetched site =
    case site.delivery of
        WithSite ->
            Picking.branch locationIds (LocationId site.id) site.name (List.map zoneNode (zonesOf site.id))
                |> Picking.withDescription site.code

        Closed ->
            Picking.branch locationIds (LocationId site.id) site.name []
                |> Picking.withDescription site.code
                |> Picking.disabled

        _ ->
            Picking.lazy locationIds
                (LocationId site.id)
                site.name
                (Dict.get site.id fetched |> Maybe.withDefault NotAsked |> Remote.map (List.map zoneNode))
                |> Picking.withDescription site.code


regionNodes : Dict String (Remote (List Zone)) -> List Region -> List (Node LocationId)
regionNodes fetched list =
    List.map
        (\region ->
            Picking.branch locationIds (LocationId region.id) region.name (List.map (siteNode fetched) region.sites)
        )
        list


{-| Five thousand nodes: fifty categories of a hundred products each.
-}
catalogue : List (Node String)
catalogue =
    List.range 1 50
        |> List.map
            (\c ->
                let
                    category =
                        "Category " ++ String.padLeft 2 '0' (String.fromInt c)
                in
                Picking.branch Ids.string
                    category
                    category
                    (List.range 1 100
                        |> List.map
                            (\p ->
                                let
                                    name =
                                        "Product " ++ String.fromInt c ++ "-" ++ String.padLeft 3 '0' (String.fromInt p)
                                in
                                Picking.leaf Ids.string name name
                            )
                    )
            )


products : List (Select.Option ProductNo)
products =
    List.range 1 2000
        |> List.map
            (\n ->
                let
                    option =
                        Select.option (ProductNo n) ("Product " ++ String.padLeft 4 '0' (String.fromInt n))
                            |> Select.withDescription ("SKU-" ++ String.fromInt (10000 + n * 7))
                in
                if modBy 250 n == 0 then
                    Select.disabledOption option

                else
                    option
            )



-- MODEL


type alias Model =
    { site : TreeSelect.State TreeSelect.Single LocationId
    , sites : TreeSelect.State TreeSelect.Multiple LocationId
    , catalogue : TreeSelect.State TreeSelect.Multiple String
    , place : Cascader.State LocationId
    , placeAny : Cascader.State LocationId
    , products : Transfer.State ProductNo
    , columns : Transfer.State String
    , downState : TreeSelect.State TreeSelect.Single LocationId
    , regions : Remote (List Region)
    , fetched : Dict String (Remote (List Zone))
    , attempts : Dict String Int
    , down : Bool
    }


type Msg
    = SiteMsg (TreeSelect.Msg LocationId)
    | SitesMsg (TreeSelect.Msg LocationId)
    | CatalogueMsg (TreeSelect.Msg String)
    | PlaceMsg (Cascader.Msg LocationId)
    | PlaceAnyMsg (Cascader.Msg LocationId)
    | ProductsMsg (Transfer.Msg ProductNo)
    | OrderedMsg (Transfer.Msg String)
    | DownMsg (TreeSelect.Msg LocationId)
    | RegionsArrived
    | ZonesArrived String (Result Problem (List Zone))
    | RetryZones LocationId
    | RetryDown
    | DownRetried
    | RefreshZones
    | ZonesRefreshFailed


init : ( Model, Cmd Msg )
init =
    ( { site = TreeSelect.init "location-single" TreeSelect.single
      , sites =
            TreeSelect.init "location-multiple" TreeSelect.multiple
                |> TreeSelect.setValues locationIds [ LocationId "nordics" ]
      , catalogue = TreeSelect.init "catalogue" TreeSelect.multiple
      , place =
            Cascader.init "location-path"
                |> Cascader.setValue locationIds [ LocationId "nordics", LocationId "oslo", LocationId "oslo/receiving", LocationId "oslo/receiving/A-01" ]
      , placeAny = Cascader.init "location-any"
      , products =
            Transfer.init "promotion-products"
                |> Transfer.setValues productIds [ ProductNo 3, ProductNo 17, ProductNo 1999, ProductNo 9999 ]
      , columns = Transfer.init "export-columns"
      , downState = TreeSelect.init "location-down" TreeSelect.single
      , regions = Loading
      , fetched = Dict.empty
      , attempts = Dict.empty
      , down = False
      }
    , Process.sleep 900 |> Task.perform (\_ -> RegionsArrived)
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SiteMsg inner ->
            let
                ( site, cmd ) =
                    TreeSelect.update inner model.site
            in
            requestZones (TreeSelect.loadRequests site) { model | site = site } (Cmd.map SiteMsg cmd)

        SitesMsg inner ->
            let
                ( sites, cmd ) =
                    TreeSelect.update inner model.sites
            in
            requestZones (TreeSelect.loadRequests sites) { model | sites = sites } (Cmd.map SitesMsg cmd)

        CatalogueMsg inner ->
            let
                ( state, cmd ) =
                    TreeSelect.update inner model.catalogue
            in
            ( { model | catalogue = state }, Cmd.map CatalogueMsg cmd )

        PlaceMsg inner ->
            let
                ( place, cmd ) =
                    Cascader.update inner model.place
            in
            requestZones (Cascader.loadRequests place) { model | place = place } (Cmd.map PlaceMsg cmd)

        PlaceAnyMsg inner ->
            let
                ( place, cmd ) =
                    Cascader.update inner model.placeAny
            in
            requestZones (Cascader.loadRequests place) { model | placeAny = place } (Cmd.map PlaceAnyMsg cmd)

        ProductsMsg inner ->
            let
                ( state, cmd ) =
                    Transfer.update inner model.products
            in
            ( { model | products = state }, Cmd.map ProductsMsg cmd )

        OrderedMsg inner ->
            let
                ( state, cmd ) =
                    Transfer.update inner model.columns
            in
            ( { model | columns = state }, Cmd.map OrderedMsg cmd )

        DownMsg inner ->
            let
                ( state, cmd ) =
                    TreeSelect.update inner model.downState
            in
            ( { model | downState = state }, Cmd.map DownMsg cmd )

        RegionsArrived ->
            ( { model | regions = Loaded regions }, Cmd.none )

        ZonesArrived siteId result ->
            let
                -- a failed refresh keeps the zones that are there, as old data
                answer before =
                    case result of
                        Ok zones ->
                            Loaded zones

                        Err problem ->
                            Remote.refreshWith before (Err problem) (Time.millisToPosix 0)
            in
            ( { model | fetched = Dict.update siteId (Maybe.withDefault NotAsked >> answer >> Just) model.fetched }, Cmd.none )

        RefreshZones ->
            ( { model | fetched = Dict.map (\_ zones -> refreshIfThere zones) model.fetched }
            , Process.sleep 900 |> Task.perform (\_ -> ZonesRefreshFailed)
            )

        ZonesRefreshFailed ->
            ( { model
                | fetched =
                    Dict.map
                        (\_ zones ->
                            if Remote.isRefreshing zones then
                                Remote.refreshWith zones (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)

                            else
                                zones
                        )
                        model.fetched
              }
            , Cmd.none
            )

        RetryZones (LocationId siteId) ->
            fetch siteId model Cmd.none

        RetryDown ->
            ( { model | down = True }, Process.sleep 900 |> Task.perform (\_ -> DownRetried) )

        DownRetried ->
            ( { model | down = False }, Cmd.none )


{-| The sites whose zones the user just opened: mark them as loading and fetch
them. A field names each site once, so there is no check of our own.
-}
requestZones : List LocationId -> Model -> Cmd Msg -> ( Model, Cmd Msg )
requestZones requested model cmd =
    List.foldl
        (\(LocationId siteId) ( current, cmds ) ->
            let
                ( next, fetching ) =
                    fetch siteId current Cmd.none
            in
            ( next, fetching :: cmds )
        )
        ( model, [ cmd ] )
        requested
        |> (\( next, cmds ) -> ( next, Cmd.batch cmds ))


{-| Zones that are there are refreshed and stay on screen meanwhile.
-}
refreshIfThere : Remote (List Zone) -> Remote (List Zone)
refreshIfThere zones =
    case Remote.toMaybe zones of
        Just _ ->
            Remote.refresh zones

        Nothing ->
            zones


{-| Asks the pretend backend for the zones of a site. Hamburg fails the first two
times.
-}
fetch : String -> Model -> Cmd Msg -> ( Model, Cmd Msg )
fetch siteId model cmd =
    let
        attempt =
            Dict.get siteId model.attempts |> Maybe.withDefault 0

        failing =
            siteId == "hamburg" && attempt < 2

        answer =
            if failing then
                Err (Remote.problem Remote.network)

            else
                Ok (zonesOf siteId)
    in
    ( { model
        | fetched = Dict.update siteId (Maybe.withDefault NotAsked >> Remote.refresh >> Just) model.fetched
        , attempts = Dict.insert siteId (attempt + 1) model.attempts
      }
    , Cmd.batch
        [ cmd
        , Process.sleep 800 |> Task.perform (\_ -> ZonesArrived siteId answer)
        ]
    )



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    let
        nodes =
            Remote.map (regionNodes model.fetched) model.regions
    in
    Doc.page
        { title = "Picking from trees and lists"
        , description = "Pick from a tree, drill down through columns, or move items between two lists. The ids are the application's own type, and everything that comes from the backend shows that it is loading, failed or empty."
        }
        [ Doc.section "TreeSelect"
            "A field that opens a tree. Type to filter: the matches keep their ancestors, which open, and clearing the text brings back what was open. The sites of Bergen and Rotterdam are fetched when they are opened, Hamburg fails the first two times (use “Try again”), and Frankfurt is closed (disabled). “Refresh the zones” refreshes the zones that are loaded and fails: they stay, marked busy, then under a row that says “Old data” with “Try again”."
            [ Doc.example
                { title = "One location"
                , description = Just "Arrow keys move, Right and Left open and close, Enter chooses. Home and End go to the first and last row while the search box is empty, and move the caret in a text (Ctrl or Cmd with them always move the rows). The popup opens on the value, with the nodes above it open. A disabled node cannot be chosen, but the nodes inside it can."
                , code =
                    Just """TreeSelect.view SiteMsg
    [ TreeSelect.label "Location"
    , TreeSelect.remote model.regions
    , TreeSelect.onRetryChildren RetryZones
    , TreeSelect.clearable
    ]
    model.site

SiteMsg inner ->
    let
        ( site, cmd ) =
            TreeSelect.update inner model.site
    in
    -- the lazy nodes the user opened: mark them Loading and fetch them
    requestZones (TreeSelect.loadRequests site) { model | site = site } (Cmd.map SiteMsg cmd)

TreeSelect.value model.site -- Maybe LocationId"""
                }
                (Layout.stack [ Layout.gap 3 ]
                    [ TreeSelect.view SiteMsg
                        [ TreeSelect.label "Location"
                        , TreeSelect.remote nodes
                        , TreeSelect.onRetryChildren RetryZones
                        , TreeSelect.clearable
                        , TreeSelect.locale locale
                        ]
                        model.site
                    , Button.view [ Button.small, Button.secondary, Button.onClick RefreshZones ] "Refresh the zones (the refresh fails)"
                    , Text.caption
                        ("Value: "
                            ++ (case TreeSelect.value model.site of
                                    Just id ->
                                        locationText id

                                    Nothing ->
                                        "nothing chosen"
                               )
                        )
                    ]
                )
            , Doc.example
                { title = "Several locations, with check boxes"
                , description = Just "Checking a parent chooses everything below it, and the value is the parent: one id, also when its children are not loaded. A parent with only some of its nodes checked shows a dash. Uncheck a bin of a checked site and the site becomes what is left. `leaves` writes the choice out as the bins."
                , code =
                    Just """TreeSelect.view SitesMsg [ TreeSelect.label "Locations", TreeSelect.remote model.regions ] model.sites

TreeSelect.values model.sites -- [ nordics ]
TreeSelect.leaves nodes model.sites -- every enabled bin loaded below it"""
                }
                (Layout.stack [ Layout.gap 3 ]
                    [ TreeSelect.view SitesMsg
                        [ TreeSelect.label "Locations"
                        , TreeSelect.remote nodes
                        , TreeSelect.onRetryChildren RetryZones
                        , TreeSelect.clearable
                        , TreeSelect.locale locale
                        ]
                        model.sites
                    , Text.caption ("Value: " ++ listText locationText (TreeSelect.values model.sites))
                    , case model.regions of
                        Loaded list ->
                            Text.caption
                                ("Written out as leaves ("
                                    ++ String.fromInt (List.length (TreeSelect.leaves (regionNodes model.fetched list) model.sites))
                                    ++ "): "
                                    ++ listText locationText (List.take 6 (TreeSelect.leaves (regionNodes model.fetched list) model.sites))
                                    ++ "..."
                                )

                        _ ->
                            Text.caption ""
                    ]
                )
            , Doc.example
                { title = "Five thousand nodes"
                , description = Just "Only the rows on screen are drawn, and the filter does not freeze: try “product 37”. Check a category and one id is the value."
                , code = Just "TreeSelect.view CatalogueMsg [ TreeSelect.label \"Products\", TreeSelect.nodes catalogue ] model.catalogue"
                }
                (Layout.stack [ Layout.gap 3 ]
                    [ TreeSelect.view CatalogueMsg
                        [ TreeSelect.label "Products"
                        , TreeSelect.nodes catalogue
                        , TreeSelect.clearable
                        , TreeSelect.locale locale
                        ]
                        model.catalogue
                    , Text.caption ("Value: " ++ listText identity (TreeSelect.values model.catalogue))
                    ]
                )
            , Doc.example
                { title = "A top level that fails"
                , description = Just "The backend is down on purpose: the popup shows the problem with “Try again”, which loads for a moment and fails again."
                , code = Just "TreeSelect.view DownMsg [ TreeSelect.label \"Locations\", TreeSelect.remote model.down, TreeSelect.onRetry RetryDown ] model.downState"
                }
                (TreeSelect.view DownMsg
                    [ TreeSelect.label "Locations"
                    , TreeSelect.remote
                        (if model.down then
                            Loading

                         else
                            Failed (Remote.problem Remote.network)
                        )
                    , TreeSelect.onRetry RetryDown
                    , TreeSelect.locale locale
                    ]
                    model.downState
                )
            ]
        , Doc.section "Cascader"
            "The same hierarchy as columns, for people who know where to look. The closed field shows the path, shortened in the middle when it is long. Typing leaves the columns and shows the full paths that match: try “A-03”. On a narrow screen the columns scroll sideways."
            [ Doc.example
                { title = "Region, site, zone, bin"
                , description = Just "Right opens a branch and moves into its column, Left goes back, Enter chooses a bin. The value is the path of ids from the top down. Only a node without children can be chosen."
                , code =
                    Just """Cascader.view PlaceMsg
    [ Cascader.label "Bin"
    , Cascader.remote model.regions
    , Cascader.onRetryChildren RetryZones
    , Cascader.clearable
    ]
    model.place

Cascader.value model.place -- Just [ nordics, oslo, receiving, bin ]"""
                }
                (Layout.stack [ Layout.gap 3 ]
                    [ Cascader.view PlaceMsg
                        [ Cascader.label "Bin"
                        , Cascader.remote nodes
                        , Cascader.onRetryChildren RetryZones
                        , Cascader.clearable
                        , Cascader.locale locale
                        ]
                        model.place
                    , Text.caption
                        ("Value: "
                            ++ (case Cascader.value model.place of
                                    Just path ->
                                        String.join " > " (List.map locationText path)

                                    Nothing ->
                                        "nothing chosen"
                               )
                        )
                    ]
                )
            , Doc.example
                { title = "Choose any level"
                , description = Just "With anyNode a region or a site can be chosen too: Enter, a double click or the button under the columns choose the branch, Right opens it."
                , code = Just "Cascader.view PlaceAnyMsg [ Cascader.label \"Place\", Cascader.nodes places, Cascader.anyNode ] model.placeAny"
                }
                (Layout.stack [ Layout.gap 3 ]
                    [ Cascader.view PlaceAnyMsg
                        [ Cascader.label "Place"
                        , Cascader.remote nodes
                        , Cascader.onRetryChildren RetryZones
                        , Cascader.anyNode
                        , Cascader.clearable
                        , Cascader.separator " > "
                        , Cascader.locale locale
                        ]
                        model.placeAny
                    , Text.caption
                        ("Value: "
                            ++ (case Cascader.value model.placeAny of
                                    Just path ->
                                        String.join " > " (List.map locationText path)

                                    Nothing ->
                                        "nothing chosen"
                               )
                        )
                    ]
                )
            ]
        , Doc.section "Transfer"
            "Two lists and the buttons between them, for assigning many things to one thing."
            [ Doc.example
                { title = "Products in a promotion"
                , description = Just "Two thousand products. Mark with a click or Space, move with the buttons, a double click, Enter or Ctrl+Right and Ctrl+Left (Cmd on a Mac). The filter boxes and the check boxes in the headers work on what is shown. Every 250th product is disabled; product 9999 is chosen but no longer in the list, so it is shown as an unknown value that can be taken out. The chosen products keep the order of the list."
                , code =
                    Just """Transfer.view ProductsMsg
    [ Transfer.label "Products in the promotion"
    , Transfer.options productIds (List.map toOption products)
    , Transfer.titles { available = "All products", chosen = "In the promotion" }
    ]
    model.products

Transfer.values model.products -- List ProductNo"""
                }
                (Layout.stack [ Layout.gap 3 ]
                    [ Transfer.view ProductsMsg
                        [ Transfer.label "Products in the promotion"
                        , Transfer.options productIds products
                        , Transfer.titles { available = "All products", chosen = "In the promotion" }
                        , Transfer.hint "Move the products that are part of the promotion to the right."
                        , Transfer.locale locale
                        ]
                        model.products
                    , Text.caption
                        (String.fromInt (List.length (Transfer.values model.products))
                            ++ " chosen: "
                            ++ listText productText (List.take 8 (Transfer.values model.products))
                            ++ (if List.length (Transfer.values model.products) > 8 then
                                    "..."

                                else
                                    ""
                               )
                        )
                    ]
                )
            , Doc.example
                { title = "In the order they were moved"
                , description = Just "For lists where the order means something, such as the columns of an export, the chosen ids keep the order of moving."
                , code = Just "Transfer.order Transfer.movedOrder"
                }
                (Transfer.view OrderedMsg
                    [ Transfer.label "Columns in the export"
                    , Transfer.options Ids.string exportColumns
                    , Transfer.order Transfer.movedOrder
                    , Transfer.titles { available = "Columns", chosen = "Exported" }
                    , Transfer.visibleRows 6
                    , Transfer.locale locale
                    ]
                    model.columns
                )
            ]
        ]


exportColumns : List (Select.Option String)
exportColumns =
    [ "Order number", "Customer", "Order date", "Delivery date", "Status", "Total", "Currency", "Warehouse" ]
        |> List.map (\name -> Select.option name name)


listText : (a -> String) -> List a -> String
listText toText items =
    case items of
        [] ->
            "nothing chosen"

        _ ->
            String.join ", " (List.map toText items)
