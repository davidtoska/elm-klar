module Klar.Table.Texts exposing (Texts, texts)

{-| The built-in text of `Klar.Table`, in Norwegian (bokmål) and English.
Application text (column titles, empty states, bulk actions) always comes
from the application.
-}

import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)


type alias Texts =
    { searchLabel : String
    , searchPlaceholder : Int -> String
    , filterColumn : String -> String
    , filterColumnActive : String -> String
    , filterTitle : String -> String
    , contains : String
    , from : String
    , to : String
    , notANumber : String
    , rangeHint : String -> String -> String
    , searchValues : String
    , selectAll : String
    , selectNone : String
    , noValues : String
    , clear : String
    , done : String
    , filtersActive : Int -> String
    , activeFilters : String
    , resetFilters : String
    , clearSearchAndFilters : String
    , describeContains : String -> String -> String
    , columns : String
    , columnsTitle : String
    , reset : String
    , density : String
    , compact : String
    , normal : String
    , comfortable : String
    , refresh : String
    , export : String
    , exportTitle : String
    , exportAll : String
    , exportSelected : String
    , selectionOffPage : Int -> Int -> String
    , exportPage : String
    , exportNote : Int -> Char -> String
    , fileSelected : String
    , filePage : Int -> String
    , rowCount : Int -> String
    , selected : Int -> String
    , noneSelected : String
    , cancel : String
    , allOnPage : Int -> String
    , selectAllMatching : Int -> String
    , allMatching : Int -> String
    , hiddenSelected : Int -> String
    , selectedElsewhere : Int -> String
    , selectPage : String
    , selectRow : String -> String
    , pagination : String -> String
    , rowActions : String -> String
    , actions : String
    , details : String
    , showDetails : String -> String
    , hideDetails : String -> String
    , sortHint : String
    , multiSortHint : String
    , noData : String
    , noDataDescription : String
    , noMatches : String
    , noMatchesDescription : String
    , emptyPage : String
    , emptyPageDescription : String
    , firstPage : String
    , loading : String
    , refreshing : String
    , yes : String
    , no : String
    , total : String
    , sum : String
    , average : String
    , summary : Int -> Int -> Int -> String
    , noRows : String
    , sortedBy : String -> Bool -> String
    }


texts : Locale -> Texts
texts loc =
    let
        n =
            Format.int loc
    in
    Locale.pick loc
        { nb =
            { searchLabel = "Søk i tabellen"
            , searchPlaceholder =
                \count ->
                    if count > 0 then
                        "Søk i " ++ n count ++ " rader ..."

                    else
                        "Søk ..."
            , filterColumn = \title -> "Filtrer " ++ title
            , filterColumnActive = \title -> "Filtrer " ++ title ++ " (filter aktivt)"
            , filterTitle = \title -> "Filter: " ++ title
            , contains = "Inneholder"
            , from = "Fra"
            , to = "Til"
            , notANumber = "Ikke et tall"
            , rangeHint = \low high -> "Verdier fra " ++ low ++ " til " ++ high
            , searchValues = "Søk i verdier"
            , selectAll = "Velg alle"
            , selectNone = "Fjern valg"
            , noValues = "Ingen verdier"
            , clear = "Nullstill"
            , done = "Ferdig"
            , filtersActive =
                \count ->
                    if count == 1 then
                        "1 filter aktivt"

                    else
                        n count ++ " filtre aktive"
            , activeFilters = "Aktive filtre"
            , resetFilters = "Nullstill filtre"
            , clearSearchAndFilters = "Nullstill søk og filtre"
            , describeContains = \title value -> title ++ " inneholder «" ++ value ++ "»"
            , columns = "Kolonner"
            , columnsTitle = "Vis kolonner"
            , reset = "Tilbakestill"
            , density = "Tetthet"
            , compact = "Kompakt"
            , normal = "Normal"
            , comfortable = "Luftig"
            , refresh = "Oppdater"
            , export = "Eksporter"
            , exportTitle = "Eksporter som CSV"
            , exportAll = "Alle treff"
            , exportSelected = "Valgte rader"
            , selectionOffPage = \off total -> n off ++ " av " ++ n total ++ " valgte rader er på andre sider. Bare denne siden kan eksporteres her."
            , exportPage = "Denne siden"
            , exportNote =
                \count separator ->
                    n count
                        ++ (if count == 1 then
                                " kolonne"

                            else
                                " kolonner"
                           )
                        ++ " · UTF-8 · "
                        ++ (if separator == ';' then
                                "semikolon"

                            else if separator == ',' then
                                "komma"

                            else
                                String.fromChar separator
                           )
            , fileSelected = "-valgte"
            , filePage = \page -> "-side-" ++ String.fromInt page
            , rowCount =
                \count ->
                    n count
                        ++ (if count == 1 then
                                " rad"

                            else
                                " rader"
                           )
            , selected = \count -> n count ++ " valgt"
            , noneSelected = "Ingen rader valgt"
            , cancel = "Avbryt"
            , allOnPage = \count -> "Alle " ++ n count ++ " på denne siden er valgt."
            , selectAllMatching = \count -> "Velg alle " ++ n count ++ " treff"
            , allMatching = \count -> "Alle " ++ n count ++ " treff er valgt."
            , hiddenSelected =
                \count ->
                    if count == 1 then
                        "1 valgt rad er skjult av søk eller filtre"

                    else
                        n count ++ " valgte rader er skjult av søk eller filtre"
            , selectedElsewhere =
                \count ->
                    if count == 1 then
                        "1 valgt rad er ikke på denne siden"

                    else
                        n count ++ " valgte rader er ikke på denne siden"
            , selectPage = "Velg alle rader på denne siden"
            , selectRow = \name -> "Velg " ++ name
            , pagination = \name -> "Sider i " ++ name
            , rowActions = \name -> "Handlinger for " ++ name
            , actions = "Handlinger"
            , details = "Detaljer"
            , showDetails = \name -> "Vis detaljer for " ++ name
            , hideDetails = \name -> "Skjul detaljer for " ++ name
            , sortHint = "Klikk for å sortere"
            , multiSortHint = "Klikk for å sortere. Shift-klikk for å sortere på flere kolonner."
            , noData = "Ingen data"
            , noDataDescription = "Det er ingen rader å vise."
            , noMatches = "Ingen treff"
            , noMatchesDescription = "Ingen rader passer med søket eller filtrene."
            , emptyPage = "Siden er tom"
            , emptyPageDescription = "Det er færre rader enn da siden ble åpnet."
            , firstPage = "Gå til første side"
            , loading = "Laster ..."
            , refreshing = "Oppdaterer ..."
            , yes = "Ja"
            , no = "Nei"
            , total = "Totalt"
            , sum = "Sum"
            , average = "Snitt"
            , summary = \first last count -> "Viser " ++ n first ++ "–" ++ n last ++ " av " ++ n count ++ " rader."
            , noRows = "Ingen rader."
            , sortedBy =
                \title descending ->
                    "Sortert etter "
                        ++ title
                        ++ (if descending then
                                ", synkende."

                            else
                                ", stigende."
                           )
            }
        , en =
            { searchLabel = "Search the table"
            , searchPlaceholder =
                \count ->
                    if count > 0 then
                        "Search " ++ n count ++ " rows ..."

                    else
                        "Search ..."
            , filterColumn = \title -> "Filter " ++ title
            , filterColumnActive = \title -> "Filter " ++ title ++ " (filter active)"
            , filterTitle = \title -> "Filter: " ++ title
            , contains = "Contains"
            , from = "From"
            , to = "To"
            , notANumber = "Not a number"
            , rangeHint = \low high -> "Values from " ++ low ++ " to " ++ high
            , searchValues = "Search values"
            , selectAll = "Select all"
            , selectNone = "Clear"
            , noValues = "No values"
            , clear = "Reset"
            , done = "Done"
            , filtersActive =
                \count ->
                    if count == 1 then
                        "1 filter active"

                    else
                        n count ++ " filters active"
            , activeFilters = "Active filters"
            , resetFilters = "Reset filters"
            , clearSearchAndFilters = "Clear search and filters"
            , describeContains = \title value -> title ++ " contains “" ++ value ++ "”"
            , columns = "Columns"
            , columnsTitle = "Show columns"
            , reset = "Reset"
            , density = "Density"
            , compact = "Compact"
            , normal = "Normal"
            , comfortable = "Comfortable"
            , refresh = "Refresh"
            , export = "Export"
            , exportTitle = "Export as CSV"
            , exportAll = "All matching"
            , exportSelected = "Selected rows"
            , selectionOffPage = \off total -> n off ++ " of " ++ n total ++ " selected rows are on other pages. Only this page can be exported here."
            , exportPage = "This page"
            , exportNote =
                \count separator ->
                    n count
                        ++ (if count == 1 then
                                " column"

                            else
                                " columns"
                           )
                        ++ " · UTF-8 · "
                        ++ (if separator == ';' then
                                "semicolon"

                            else if separator == ',' then
                                "comma"

                            else
                                String.fromChar separator
                           )
            , fileSelected = "-selected"
            , filePage = \page -> "-page-" ++ String.fromInt page
            , rowCount =
                \count ->
                    n count
                        ++ (if count == 1 then
                                " row"

                            else
                                " rows"
                           )
            , selected = \count -> n count ++ " selected"
            , noneSelected = "No rows selected"
            , cancel = "Cancel"
            , allOnPage = \count -> "All " ++ n count ++ " on this page are selected."
            , selectAllMatching = \count -> "Select all " ++ n count ++ " matching"
            , allMatching = \count -> "All " ++ n count ++ " matching rows are selected."
            , hiddenSelected =
                \count ->
                    if count == 1 then
                        "1 selected row is hidden by search or filters"

                    else
                        n count ++ " selected rows are hidden by search or filters"
            , selectedElsewhere =
                \count ->
                    if count == 1 then
                        "1 selected row is not on this page"

                    else
                        n count ++ " selected rows are not on this page"
            , selectPage = "Select all rows on this page"
            , selectRow = \name -> "Select " ++ name
            , pagination = \name -> "Pages of " ++ name
            , rowActions = \name -> "Actions for " ++ name
            , actions = "Actions"
            , details = "Details"
            , showDetails = \name -> "Show details for " ++ name
            , hideDetails = \name -> "Hide details for " ++ name
            , sortHint = "Click to sort"
            , multiSortHint = "Click to sort. Shift-click to sort by several columns."
            , noData = "No data"
            , noDataDescription = "There are no rows to show."
            , noMatches = "No matches"
            , noMatchesDescription = "No rows match the search or filters."
            , emptyPage = "This page is empty"
            , emptyPageDescription = "There are fewer rows than when the page was opened."
            , firstPage = "Go to the first page"
            , loading = "Loading ..."
            , refreshing = "Refreshing ..."
            , yes = "Yes"
            , no = "No"
            , total = "Total"
            , sum = "Sum"
            , average = "Avg"
            , summary = \first last count -> "Showing " ++ n first ++ "–" ++ n last ++ " of " ++ n count ++ " rows."
            , noRows = "No rows."
            , sortedBy =
                \title descending ->
                    "Sorted by "
                        ++ title
                        ++ (if descending then
                                ", descending."

                            else
                                ", ascending."
                           )
            }
        }
