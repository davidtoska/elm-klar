module Klar.Table.Config exposing (..)

{-| Table attributes and their order-independent final defaults.
-}

import Html exposing (Html)
import Klar.EmptyState as EmptyState
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Table.Types exposing (Attribute(..), Column(..), Config, Rows(..), Source(..))
import Klar.Theme as Theme exposing (Tone)


configure : List (Attribute id row msg) -> Config row msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { columns = []
        , rows = Remote.Loading
        , rowId = Nothing
        , rowLabel = Nothing
        , server = Nothing
        , label = Nothing
        , locale = Locale.default
        , settings = Settings.default
        , searchable = False
        , searchPlaceholder = Nothing
        , searchDebounce = Nothing
        , rowFilter = Nothing
        , externalFilters = 0
        , onResetFilters = Nothing
        , selectable = False
        , bulkActions = []
        , rowActions = Nothing
        , onRowClick = Nothing
        , expandedRow = Nothing
        , rowTone = Nothing
        , rowDisabled = Nothing
        , currentRow = Nothing
        , toolbarActions = []
        , onRefresh = Nothing
        , refreshing = False
        , freshness = Freshness.Fresh
        , onRetry = Nothing
        , export = Nothing
        , csvSeparator = Nothing
        , columnChooser = False
        , densityToggle = False
        , pageSizes = [ 10, 25, 50, 100 ]
        , rangeText = Nothing
        , paged = True
        , virtual = False
        , multiSort = False
        , zebra = False
        , maxHeight = Nothing
        , fillHeight = False
        , emptyState = []
        }
        attributes
        |> finish


{-| What follows from the attributes together, whatever their order: a long
table has no pages in client mode, and rows of one height have no details.
-}
finish : Config row msg -> Config row msg
finish config =
    if config.virtual then
        { config
            | paged = config.paged && config.server /= Nothing
            , expandedRow = Nothing
        }

    else
        config


columns : List (Column row msg) -> Attribute id row msg
columns value =
    Attribute (\config -> { config | columns = value })


remote : Remote (List row) -> Attribute id row msg
remote value =
    Attribute
        (\config ->
            let
                ( current, freshness ) =
                    Freshness.settle value
            in
            { config | rows = Remote.map FromList current, freshness = freshness, refreshing = Freshness.busy freshness }
        )


remotePrepared : Remote (Rows row) -> Attribute id row msg
remotePrepared value =
    Attribute
        (\config ->
            let
                ( current, freshness ) =
                    Freshness.settle value
            in
            { config | rows = Remote.map FromRows current, freshness = freshness, refreshing = Freshness.busy freshness }
        )


rowId : Ids id -> (row -> id) -> Attribute id row msg
rowId ids toId =
    Attribute (\config -> { config | rowId = Just (toId >> Ids.toKey ids) })


rowLabel : (row -> String) -> Attribute id row msg
rowLabel toLabel =
    Attribute (\config -> { config | rowLabel = Just toLabel })


server : { total : Int } -> Attribute id row msg
server options =
    Attribute (\config -> { config | server = Just (max 0 options.total) })


ariaLabel : String -> Attribute id row msg
ariaLabel value =
    Attribute (\config -> { config | label = Just value })


settings : Settings -> Attribute id row msg
settings given =
    Attribute (\config -> { config | settings = given })


locale : Locale -> Attribute id row msg
locale value =
    Attribute (\config -> { config | locale = value })


searchable : Attribute id row msg
searchable =
    Attribute (\config -> { config | searchable = True })


searchPlaceholder : String -> Attribute id row msg
searchPlaceholder value =
    Attribute (\config -> { config | searchable = True, searchPlaceholder = Just value })


searchDebounce : Int -> Attribute id row msg
searchDebounce ms =
    Attribute (\config -> { config | searchDebounce = Just (max 0 ms) })


rowFilter : (row -> Bool) -> Attribute id row msg
rowFilter keep =
    Attribute (\config -> { config | rowFilter = Just keep })


activeExternalFilters : Int -> Attribute id row msg
activeExternalFilters n =
    Attribute (\config -> { config | externalFilters = max 0 n })


onResetFilters : msg -> Attribute id row msg
onResetFilters msg =
    Attribute (\config -> { config | onResetFilters = Just msg })


selectable : Attribute id row msg
selectable =
    Attribute (\config -> { config | selectable = True })


bulkActions : List (Html msg) -> Attribute id row msg
bulkActions value =
    Attribute (\config -> { config | selectable = True, bulkActions = value })


rowActions : (row -> List (Menu.Item msg)) -> Attribute id row msg
rowActions toItems =
    Attribute (\config -> { config | rowActions = Just toItems })


onRowClick : (row -> msg) -> Attribute id row msg
onRowClick toMsg =
    Attribute (\config -> { config | onRowClick = Just toMsg })


currentRow : (row -> Bool) -> Attribute id row msg
currentRow isCurrent =
    Attribute (\config -> { config | currentRow = Just isCurrent })


expandedRow : (row -> Html msg) -> Attribute id row msg
expandedRow render =
    Attribute (\config -> { config | expandedRow = Just render })


rowTone : (row -> Maybe Tone) -> Attribute id row msg
rowTone toTone =
    Attribute (\config -> { config | rowTone = Just toTone })


rowDisabled : (row -> Bool) -> Attribute id row msg
rowDisabled isDisabled =
    Attribute (\config -> { config | rowDisabled = Just isDisabled })


{-| Your own buttons at the right end of the toolbar, next to the table's own
tools.
-}
toolbarActions : List (Html msg) -> Attribute id row msg
toolbarActions value =
    Attribute (\config -> { config | toolbarActions = value })


onRefresh : msg -> Attribute id row msg
onRefresh msg =
    Attribute (\config -> { config | onRefresh = Just msg })


onRetry : msg -> Attribute id row msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


exportCsv : String -> Attribute id row msg
exportCsv filename =
    Attribute (\config -> { config | export = Just filename })


csvSeparator : Char -> Attribute id row msg
csvSeparator value =
    Attribute (\config -> { config | csvSeparator = Just value })


columnChooser : Attribute id row msg
columnChooser =
    Attribute (\config -> { config | columnChooser = True })


densityToggle : Attribute id row msg
densityToggle =
    Attribute (\config -> { config | densityToggle = True })


pageSizes : List Int -> Attribute id row msg
pageSizes value =
    Attribute (\config -> { config | pageSizes = value })


rangeText : (Int -> Int -> Int -> String) -> Attribute id row msg
rangeText words =
    Attribute (\config -> { config | rangeText = Just words })


unpaged : Attribute id row msg
unpaged =
    Attribute (\config -> { config | paged = False })


virtual : Attribute id row msg
virtual =
    Attribute (\config -> { config | virtual = True })


multiSort : Attribute id row msg
multiSort =
    Attribute (\config -> { config | multiSort = True })


{-| Gives every second row a light gray background.
-}
zebra : Attribute id row msg
zebra =
    Attribute (\config -> { config | zebra = True })


maxHeight : Int -> Attribute id row msg
maxHeight px =
    Attribute (\config -> { config | maxHeight = Just px })


fillHeight : Attribute id row msg
fillHeight =
    Attribute (\config -> { config | fillHeight = True })


emptyState : List (EmptyState.Attribute msg) -> Attribute id row msg
emptyState value =
    Attribute (\config -> { config | emptyState = value })
