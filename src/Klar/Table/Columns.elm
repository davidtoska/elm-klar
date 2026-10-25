module Klar.Table.Columns exposing (..)

{-| Column constructors and attributes; cell descriptions do not depend on the table view.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Badge as Badge
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Money)
import Klar.Table.Numeric exposing (majorAmount, plainDecimal)
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Table.Types exposing (Align(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), FilterKind(..), Footer(..), SortBy(..))
import Klar.Theme as Theme exposing (Tone)


baseColumn : String -> String -> (Locale -> row -> String) -> ColumnConfig row msg
baseColumn colId title value =
    { id = colId
    , title = title
    , value = value
    , cell = Nothing
    , sortBy = SortByValue
    , number = Nothing
    , decimals = 0
    , export = Nothing
    , align = AlignLeft
    , width = Nothing
    , minWidth = 120
    , pinned = False
    , hiddenByDefault = False
    , hideable = True
    , wrap = False
    , tooltip = True
    , searchable = True
    , exported = True
    , filter = Nothing
    , filterOptions = Nothing
    , filterValue = Nothing
    , footer = Nothing
    , hint = Nothing
    , controls = False
    , numeric = False
    , boolean = False
    , money = Nothing
    }


build : ColumnConfig row msg -> List (ColumnAttribute row msg) -> Column row msg
build base attributes =
    Column (List.foldl (\(ColumnAttribute change) config -> change config) base attributes)


text : ColumnId -> String -> (row -> String) -> List (ColumnAttribute row msg) -> Column row msg
text (ColumnId colId) title toText attributes =
    build (baseColumn colId title (\_ row -> toText row)) attributes


int : ColumnId -> String -> (row -> Int) -> List (ColumnAttribute row msg) -> Column row msg
int (ColumnId colId) title toInt attributes =
    let
        base =
            baseColumn colId title (\loc row -> Format.int loc (toInt row))

        toNumber row =
            Just (toFloat (toInt row))
    in
    build
        { base
            | sortBy = SortByNumber toNumber
            , number = Just toNumber
            , export = Just (\_ row -> String.fromInt (toInt row))
            , align = AlignRight
            , width = Just 104
            , searchable = False
            , numeric = True
            , tooltip = False
        }
        attributes


float : ColumnId -> String -> Int -> (row -> Float) -> List (ColumnAttribute row msg) -> Column row msg
float (ColumnId colId) title decimals toNumber attributes =
    let
        base =
            baseColumn colId title (\loc row -> Format.decimal loc decimals (toNumber row))
    in
    build
        { base
            | sortBy = SortByNumber (toNumber >> Just)
            , number = Just (toNumber >> Just)
            , decimals = decimals
            , export = Just (\loc row -> plainDecimal loc decimals (toNumber row))
            , align = AlignRight
            , width = Just 112
            , searchable = False
            , numeric = True
            , tooltip = False
        }
        attributes


money : ColumnId -> String -> (row -> Money) -> List (ColumnAttribute row msg) -> Column row msg
money (ColumnId colId) title toMoney attributes =
    let
        base =
            baseColumn colId title (\loc row -> Money.toString loc (toMoney row))

        amount row =
            Just (majorAmount (toMoney row))
    in
    build
        { base
            | sortBy = SortByNumber amount
            , number = Just amount
            , decimals = 2
            , money = Just toMoney
            , export = Just (\loc row -> String.replace "." (Locale.decimalSeparator loc) (Money.toDecimalString (toMoney row)))
            , align = AlignRight
            , width = Just 136
            , searchable = False
            , numeric = True
            , tooltip = False
        }
        attributes


date : ColumnId -> String -> (row -> Date) -> List (ColumnAttribute row msg) -> Column row msg
date (ColumnId colId) title toDate attributes =
    maybeDate (ColumnId colId) title (toDate >> Just) attributes


maybeDate : ColumnId -> String -> (row -> Maybe Date) -> List (ColumnAttribute row msg) -> Column row msg
maybeDate (ColumnId colId) title toDate attributes =
    let
        base =
            baseColumn colId title (\loc row -> toDate row |> Maybe.map (Format.date loc) |> Maybe.withDefault "")
    in
    build
        { base
            | sortBy = SortByNumber (\row -> toDate row |> Maybe.map (Date.toEpochDay >> toFloat))
            , width = Just 112
            , numeric = True
            , tooltip = False
        }
        attributes


badge : ColumnId -> String -> (row -> ( Tone, String )) -> List (ColumnAttribute row msg) -> Column row msg
badge (ColumnId colId) title toBadge attributes =
    let
        base =
            baseColumn colId title (\_ row -> Tuple.second (toBadge row))
    in
    build
        { base
            | cell =
                Just
                    (\_ row ->
                        let
                            ( tone, labelText ) =
                                toBadge row
                        in
                        Badge.view [ Badge.tone tone ] labelText
                    )
            , width = Just 124
            , tooltip = False
        }
        attributes


status : ColumnId -> String -> (row -> ( Tone, String )) -> List (ColumnAttribute row msg) -> Column row msg
status (ColumnId colId) title toStatus attributes =
    let
        base =
            baseColumn colId title (\_ row -> Tuple.second (toStatus row))
    in
    build
        { base
            | cell =
                Just
                    (\_ row ->
                        let
                            ( tone, labelText ) =
                                toStatus row
                        in
                        Badge.status tone labelText
                    )
            , width = Just 124
            , tooltip = False
        }
        attributes


bool : ColumnId -> String -> (row -> Bool) -> List (ColumnAttribute row msg) -> Column row msg
bool (ColumnId colId) title toBool attributes =
    let
        yesNo loc row =
            if toBool row then
                (Texts.texts loc).yes

            else
                (Texts.texts loc).no

        base =
            baseColumn colId title yesNo
    in
    build
        { base
            | cell =
                Just
                    (\loc row ->
                        if toBool row then
                            Html.span [ Internal.cls [ "klar-table__bool", "klar-table__bool--yes" ] ]
                                [ Icon.sized Icon.Small Icon.check
                                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (Texts.texts loc).yes ]
                                ]

                        else
                            Html.span [ Internal.cls [ "klar-table__bool", "klar-table__bool--no" ] ]
                                [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ]
                                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (Texts.texts loc).no ]
                                ]
                    )
            , align = AlignCenter
            , width = Just 88
            , tooltip = False
            , boolean = True
        }
        attributes


custom : ColumnId -> String -> (row -> Html msg) -> List (ColumnAttribute row msg) -> Column row msg
custom (ColumnId colId) title render attributes =
    let
        base =
            baseColumn colId title (\_ _ -> "")
    in
    build
        { base
            | cell = Just (\_ row -> render row)
            , sortBy = NotSortable
            , searchable = False
            , exported = False
            , tooltip = False
        }
        attributes


actions : ColumnId -> String -> (row -> List (Html msg)) -> List (ColumnAttribute row msg) -> Column row msg
actions (ColumnId colId) title render attributes =
    let
        base =
            baseColumn colId title (\_ _ -> "")
    in
    build
        { base
            | cell = Just (\_ row -> Html.div [ Internal.cls [ "klar-table__controls" ] ] (render row))
            , sortBy = NotSortable
            , searchable = False
            , exported = False
            , tooltip = False
            , controls = True
            , align = AlignRight
            , width = Just 96
        }
        attributes


width : Int -> ColumnAttribute row msg
width px =
    ColumnAttribute (\config -> { config | width = Just (max 24 px) })


minWidth : Int -> ColumnAttribute row msg
minWidth px =
    ColumnAttribute (\config -> { config | width = Nothing, minWidth = max 24 px })


alignRight : ColumnAttribute row msg
alignRight =
    ColumnAttribute (\config -> { config | align = AlignRight })


{-| Centers the header and the cells of the column. A `bool` column starts
centered.
-}
alignCenter : ColumnAttribute row msg
alignCenter =
    ColumnAttribute (\config -> { config | align = AlignCenter })


pinned : ColumnAttribute row msg
pinned =
    ColumnAttribute (\config -> { config | pinned = True })


hiddenByDefault : ColumnAttribute row msg
hiddenByDefault =
    ColumnAttribute (\config -> { config | hiddenByDefault = True })


alwaysVisible : ColumnAttribute row msg
alwaysVisible =
    ColumnAttribute (\config -> { config | hideable = False, hiddenByDefault = False })


wrap : ColumnAttribute row msg
wrap =
    ColumnAttribute (\config -> { config | wrap = True, tooltip = False })


noTooltip : ColumnAttribute row msg
noTooltip =
    ColumnAttribute (\config -> { config | tooltip = False })


cell : (row -> Html msg) -> ColumnAttribute row msg
cell render =
    ColumnAttribute (\config -> { config | cell = Just (\_ row -> render row), tooltip = False })


hint : String -> ColumnAttribute row msg
hint value =
    ColumnAttribute (\config -> { config | hint = Just value })


{-| Sorts alphabetically (in the order of the table's `locale`) by another text
than the one shown.
-}
sortText : (row -> String) -> ColumnAttribute row msg
sortText toText =
    ColumnAttribute (\config -> { config | sortBy = SortByText toText })


sortNumber : (row -> Float) -> ColumnAttribute row msg
sortNumber toNumber =
    sortMaybeNumber (toNumber >> Just)


sortMaybeNumber : (row -> Maybe Float) -> ColumnAttribute row msg
sortMaybeNumber toNumber =
    ColumnAttribute (\config -> { config | sortBy = SortByNumber toNumber, number = Just toNumber })


sortDate : (row -> Date) -> ColumnAttribute row msg
sortDate toDate =
    ColumnAttribute (\config -> { config | sortBy = SortByNumber (\row -> Just (toFloat (Date.toEpochDay (toDate row)))) })


sortWith : (row -> row -> Order) -> ColumnAttribute row msg
sortWith comparator =
    ColumnAttribute (\config -> { config | sortBy = SortByComparator comparator })


{-| Turns sorting off for the column: its header is a plain title instead of a
button.
-}
unsortable : ColumnAttribute row msg
unsortable =
    ColumnAttribute (\config -> { config | sortBy = NotSortable })


{-| The search box skips this column.
-}
notSearchable : ColumnAttribute row msg
notSearchable =
    ColumnAttribute (\config -> { config | searchable = False })


includeInSearch : ColumnAttribute row msg
includeInSearch =
    ColumnAttribute (\config -> { config | searchable = True })


exportAs : (row -> String) -> ColumnAttribute row msg
exportAs toText =
    ColumnAttribute (\config -> { config | export = Just (\_ row -> toText row), exported = True })


{-| Leaves the column out of the CSV export (see `exportCsv`).
-}
notExported : ColumnAttribute row msg
notExported =
    ColumnAttribute (\config -> { config | exported = False })


filterText : ColumnAttribute row msg
filterText =
    ColumnAttribute (\config -> { config | filter = Just TextFilter })


filterSelect : ColumnAttribute row msg
filterSelect =
    ColumnAttribute (\config -> { config | filter = Just SelectFilter })


filterOptions : List { value : String, label : String } -> ColumnAttribute row msg
filterOptions options =
    ColumnAttribute (\config -> { config | filter = Just SelectFilter, filterOptions = Just options })


filterValue : (row -> String) -> ColumnAttribute row msg
filterValue toValue =
    ColumnAttribute (\config -> { config | filterValue = Just toValue })


filterRange : ColumnAttribute row msg
filterRange =
    ColumnAttribute (\config -> { config | filter = Just RangeFilter })


footer : (List row -> String) -> ColumnAttribute row msg
footer summarize =
    ColumnAttribute (\config -> { config | footer = Just (FooterCustom summarize) })


{-| The sum of a number column in the footer, as in "Sum 12,345". It adds up the
same rows as `footer`.
-}
footerSum : ColumnAttribute row msg
footerSum =
    ColumnAttribute (\config -> { config | footer = Just FooterSum })


footerAverage : ColumnAttribute row msg
footerAverage =
    ColumnAttribute (\config -> { config | footer = Just FooterAverage })
