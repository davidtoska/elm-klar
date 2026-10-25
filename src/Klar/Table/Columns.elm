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
import Klar.Table.Numeric exposing (formatNumber, majorAmount, moneyTotals, plainDecimal)
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Theme as Theme exposing (Density(..), Tone)


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


{-| A text column: `Table.text (Table.columnId "customer") "Customer" .customer []` takes the
column id (unique in the table), the title for the header and a function that
reads the text from a row.

The text is searched, sorted alphabetically (in the order of the table's
`locale`), exported to CSV and highlighted where it matches the search. A long
text is cut with an ellipsis and a tooltip, a blank one is shown as a dash and
sorts last, and the column is at least 120 pixels wide (see `minWidth`).

-}
text : ColumnId -> String -> (row -> String) -> List (ColumnAttribute row msg) -> Column row msg
text (ColumnId colId) title toText attributes =
    build (baseColumn colId title (\_ row -> toText row)) attributes


{-| A whole number: `Table.int (Table.columnId "items") "Items" .items []`. It is right-aligned
with tabular digits and thousands separators (`1,234` in English), sorted
numerically, exported as a plain number and 104 pixels wide (see `width`). It
supports `filterRange`, `footerSum` and `footerAverage`, and the search box
skips it unless you add `includeInSearch`.
-}
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


{-| A decimal number with a fixed count of decimals:
`Table.float (Table.columnId "weight") "Weight (kg)" 1 .weight []`. The `Int` is the number of
decimals shown (also in filter hints and footers). It is like `int` otherwise,
but 112 pixels wide, and the CSV export keeps the decimals with the locale's
decimal separator and no thousands separator, so a spreadsheet reads a number.
-}
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


{-| An amount of money ([Klar.Money](Klar-Money)), exact to the minor unit:
`Table.money (Table.columnId "total") "Total" .total []`. It is shown with its
currency code in the format of the table's locale (`NOK 1,234.50` in English,
`1 234,50 NOK` in Norwegian), right-aligned with tabular digits and 136 pixels wide.

It sorts by amount, `filterRange` filters by the amount in whole units of the
currency (100 is 100 kroner), and the CSV export writes the plain amount with the
locale's decimal separator (`1234.50`, `1234,50`). Sorting and the range filter
compare the amounts without their currency, so they are meant for a column of one
currency: in a column of several, 100 EUR and 100 NOK sort as equal. `footerSum`
and `footerAverage` add the amounts exactly, as `Money` and not as `Float`, with one
total for each currency in the order of their codes when the column holds several
(`EUR 300.00 · NOK 1,250.00`); prepared rows (`remotePrepared`) work them out once.
The search box skips it unless you add `includeInSearch`. Use it instead of `float`
for every amount of money.

-}
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


{-| A calendar date ([Klar.Date](Klar-Date)), sorted by date and shown as
`2026-10-20` in English or `20.10.2026` in Norwegian. For a date that may be
missing use `maybeDate`.

    Table.date (Table.columnId "shipped") "Shipped" .shippedOn []

-}
date : ColumnId -> String -> (row -> Date) -> List (ColumnAttribute row msg) -> Column row msg
date (ColumnId colId) title toDate attributes =
    maybeDate (ColumnId colId) title (toDate >> Just) attributes


{-| Like `date`, for a date that may be missing: `Nothing` is shown as a dash
and sorts last, whichever way the column is sorted.
-}
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


{-| A tone ([Klar.Theme](Klar-Theme)) and a label, shown as a
[Klar.Badge](Klar-Badge). The label is the text used for search, sorting, export
and `filterSelect`; the column is 124 pixels wide.

    Table.badge (Table.columnId "status")
        "Status"
        (\order -> ( statusTone order.status, statusLabel order.status ))
        [ Table.filterSelect ]

-}
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


{-| Like `badge`, but drawn as a colored dot and text (`Badge.status` in
[Klar.Badge](Klar-Badge)), which is quieter in dense tables.
-}
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


{-| A yes / no column: a check mark for yes and a dash for no. The words ("Yes"
and "No" in English) are what screen readers hear and what search, sorting,
export and `filterSelect` use.

When the user picks values in the `filterSelect` of this column, the table
stores them as the words `"true"` and `"false"` whatever the locale, so that a
saved filter still matches when the language changes, and so that a backend can
read a server-mode `Query` without knowing the language. A `Filter` you read from
`filters` or `query` therefore holds those words, while `setFilter` also accepts
the words of either language ("Yes", "Ja").

-}
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


{-| A column with your own HTML and no text: `render` draws the cell. Without
text the column is not searched, sorted or exported; turn sorting back on with
`sortText`, `sortNumber`, `sortMaybeNumber`, `sortDate` or `sortWith`, and export
with `exportAs`. For a custom look with a text behind it, use `text` with `cell`
instead.

    Table.custom (Table.columnId "progress") "Progress" viewProgress [ Table.sortNumber .progress ]

-}
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


{-| Inline controls for each row, such as small icon buttons or links: `render`
returns the elements of one cell. Clicks inside never trigger `onRowClick`, and
the title is only read by screen readers. For a "more" menu use `rowActions`
instead: its button is one tab stop for the whole table, while controls you draw
here are a tab stop in every row (keep them few).

    Table.actions (Table.columnId "open")
        "Open"
        (\order ->
            [ Button.iconOnly
                [ Button.ghost, Button.small, Button.onClick (OpenOrder order.id) ]
                Icon.externalLink
                "Open order"
            ]
        )
        []

-}
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


{-| A fixed width in pixels (at least 24). Columns without a width share the
space that is left. A fixed column is never narrower than its header needs, so
the title is not cut.
-}
width : Int -> ColumnAttribute row msg
width px =
    ColumnAttribute (\config -> { config | width = Just (max 24 px) })


{-| The column shares the remaining space but never gets narrower than this many
pixels (at least 24); the table scrolls sideways instead. The default is 120.
It also replaces a fixed width, such as the one `int`, `date` and `badge`
columns start with.
-}
minWidth : Int -> ColumnAttribute row msg
minWidth px =
    ColumnAttribute (\config -> { config | width = Nothing, minWidth = max 24 px })


{-| Aligns the header and the cells of the column to the right, as numbers
should be. Columns start left-aligned, except `int`, `float` and `actions`,
which are right-aligned.
-}
alignRight : ColumnAttribute row msg
alignRight =
    ColumnAttribute (\config -> { config | align = AlignRight })


{-| Centers the header and the cells of the column. A `bool` column starts
centered.
-}
alignCenter : ColumnAttribute row msg
alignCenter =
    ColumnAttribute (\config -> { config | align = AlignCenter })


{-| Keeps the column in view while the table scrolls sideways. Only the first
visible column can be pinned (on any other column this does nothing); the
selection and expand columns, if there are any, stay with it.
-}
pinned : ColumnAttribute row msg
pinned =
    ColumnAttribute (\config -> { config | pinned = True })


{-| The column starts hidden. The user can show it in the column chooser (see
`columnChooser`), and you can with `setColumnVisible`.
-}
hiddenByDefault : ColumnAttribute row msg
hiddenByDefault =
    ColumnAttribute (\config -> { config | hiddenByDefault = True })


{-| The user cannot hide the column: its checkbox in the column chooser is
disabled. It also cancels `hiddenByDefault`.
-}
alwaysVisible : ColumnAttribute row msg
alwaysVisible =
    ColumnAttribute (\config -> { config | hideable = False, hiddenByDefault = False })


{-| Long values wrap onto more lines instead of being cut, so the row grows. There
is no tooltip then, as the whole value is visible.
-}
wrap : ColumnAttribute row msg
wrap =
    ColumnAttribute (\config -> { config | wrap = True, tooltip = False })


{-| Turns off the tooltip (the `title` attribute) that shows the full value of a
cell whose text is cut off.
-}
noTooltip : ColumnAttribute row msg
noTooltip =
    ColumnAttribute (\config -> { config | tooltip = False })


{-| Draws the cell yourself. The text accessor of the column is still used for
search, sorting, export and filters, but a match is no longer highlighted in the
cell, and there is no tooltip.

    Table.text (Table.columnId "customer") "Customer" .customer [ Table.cell viewCustomerLink ]

-}
cell : (row -> Html msg) -> ColumnAttribute row msg
cell render =
    ColumnAttribute (\config -> { config | cell = Just (\_ row -> render row), tooltip = False })


{-| A short explanation of the column, shown as a tooltip on the header. It
replaces the default tooltip ("Click to sort").
-}
hint : String -> ColumnAttribute row msg
hint value =
    ColumnAttribute (\config -> { config | hint = Just value })


{-| Sorts alphabetically (in the order of the table's `locale`) by another text
than the one shown.
-}
sortText : (row -> String) -> ColumnAttribute row msg
sortText toText =
    ColumnAttribute (\config -> { config | sortBy = SortByText toText })


{-| Sorts by a number instead of the text. The number also makes `filterRange`,
`footerSum` and `footerAverage` work on a column that shows text.
-}
sortNumber : (row -> Float) -> ColumnAttribute row msg
sortNumber toNumber =
    sortMaybeNumber (toNumber >> Just)


{-| Like `sortNumber`, for a number that may be missing: rows with `Nothing` go
last, whichever way the column is sorted.
-}
sortMaybeNumber : (row -> Maybe Float) -> ColumnAttribute row msg
sortMaybeNumber toNumber =
    ColumnAttribute (\config -> { config | sortBy = SortByNumber toNumber, number = Just toNumber })


{-| Sorts by a date instead of the text, for example when the column shows a
date in your own format.

    Table.text (Table.columnId "due") "Due" .dueText [ Table.sortDate .dueDate ]

-}
sortDate : (row -> Date) -> ColumnAttribute row msg
sortDate toDate =
    ColumnAttribute (\config -> { config | sortBy = SortByNumber (\row -> Just (toFloat (Date.toEpochDay (toDate row)))) })


{-| Sorts with your own comparison, written for the ascending order; the table
reverses it for `Descending`. Rows that compare equal keep their order.

    Table.text (Table.columnId "size") "Size" .sizeLabel [ Table.sortWith (\a b -> compare a.sizeRank b.sizeRank) ]

-}
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


{-| The search box looks in this column. Text, date, badge, status and yes / no
columns are searched by default; number columns are not (searching "42" rarely
means an item count). Only visible columns are searched.
-}
includeInSearch : ColumnAttribute row msg
includeInSearch =
    ColumnAttribute (\config -> { config | searchable = True })


{-| The value written to the CSV export, when it should differ from the text
shown. It also puts a column in the export that would be left out otherwise,
such as a `custom` column.
-}
exportAs : (row -> String) -> ColumnAttribute row msg
exportAs toText =
    ColumnAttribute (\config -> { config | export = Just (\_ row -> toText row), exported = True })


{-| Leaves the column out of the CSV export (see `exportCsv`).
-}
notExported : ColumnAttribute row msg
notExported =
    ColumnAttribute (\config -> { config | exported = False })


{-| Adds a "contains" text filter to the column: a filter button in the header
opens a popover with an input. Case and accents are ignored.
-}
filterText : ColumnAttribute row msg
filterText =
    ColumnAttribute (\config -> { config | filter = Just TextFilter })


{-| Adds a filter in the header where the user picks values with checkboxes. In
client mode the values are the distinct, non-blank texts of the column in all
rows, in the alphabetical order of the locale, each with the number of rows it
would add given the other filters and the search. In server mode the table only
sees one page, so without `filterOptions` it offers just the values on the
current page, with no counts. A search box appears above the values when there
are more than eight.
-}
filterSelect : ColumnAttribute row msg
filterSelect =
    ColumnAttribute (\config -> { config | filter = Just SelectFilter })


{-| The values offered by `filterSelect`, in this order, instead of the ones found
in the rows (client mode still counts the rows of each), each with the label the
user sees. The `value` is what the filter keeps and what a `Query` carries: the
column's `filterValue` of the rows it should match, or the column's text when the
column has none. A chosen value that is not in the list stays in it. It also
turns the select filter on, so `filterSelect` is not needed next to it. In server
mode, give the options: the table only sees one page.

    Table.badge (Table.columnId "status")
        "Status"
        statusBadge
        [ Table.filterValue (.status >> statusCode)
        , Table.filterOptions (List.map (\s -> { value = statusCode s, label = statusLabel s }) allStatuses)
        ]

-}
filterOptions : List { value : String, label : String } -> ColumnAttribute row msg
filterOptions options =
    ColumnAttribute (\config -> { config | filter = Just SelectFilter, filterOptions = Just options })


{-| The stable value that a select filter keeps for a row, instead of the text the
column shows: a code such as `"shipped"` for a row shown as "Shipped" in English
and "Sendt" in Norwegian. The filter, a saved view and the `Query` you send to a
backend then hold codes, which stay right when the language or a label changes and
tell two values with the same label apart. The filter popover still shows the
labels (the column's text, or the labels of `filterOptions`). Without it a select
filter keeps the column's text, and a yes / no column keeps `"true"` and
`"false"`.

    Table.filterValue (.status >> statusCode)

-}
filterValue : (row -> String) -> ColumnAttribute row msg
filterValue toValue =
    ColumnAttribute (\config -> { config | filterValue = Just toValue })


{-| Adds a from / to number filter to the column; either bound can be left
empty. It needs a number column (`int`, `float`) or `sortNumber`; on a column
without numbers there is no filter button.
-}
filterRange : ColumnAttribute row msg
filterRange =
    ColumnAttribute (\config -> { config | filter = Just RangeFilter })


{-| A footer value computed from the rows: all rows that match the search and
filters in client mode, the current page in server mode. The footer row shows
when any visible column has a footer value and there are rows.

    Table.int (Table.columnId "items") "Items" .items [ Table.footer (\orders -> String.fromInt (List.length orders) ++ " orders") ]

-}
footer : (List row -> String) -> ColumnAttribute row msg
footer summarize =
    ColumnAttribute (\config -> { config | footer = Just (FooterCustom summarize) })


{-| The sum of a number column in the footer, as in "Sum 12,345". It adds up the
same rows as `footer`.
-}
footerSum : ColumnAttribute row msg
footerSum =
    ColumnAttribute (\config -> { config | footer = Just FooterSum })


{-| The average of a number column in the footer, as in "Avg 51.2". It is written
with the decimals of the column (one at least, so an average of whole numbers is
not rounded to a whole number): cents stay cents in a money column. It averages
the same rows as `footer`; a dash is shown when there is nothing to average.
-}
footerAverage : ColumnAttribute row msg
footerAverage =
    ColumnAttribute (\config -> { config | footer = Just FooterAverage })
