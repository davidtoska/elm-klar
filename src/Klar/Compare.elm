module Klar.Compare exposing
    ( view
    , Field, text, maybe, html, longText, heading
    , Attribute, baseline, onlyDifferences, onRetry, refreshing, density, maxHeight, emptyState, locale
    )

{-| Records side by side, with the differences marked: two or more products,
two versions of an order, "your version" against "theirs".

Use when: two or more records are read side by side and the application wants to see where they differ.
Do not use when: the change between two versions of one text or record is the point, use `Klar.Diff`.

    import Klar.Compare as Compare
    import Klar.Format as Format

    Compare.view
        [ Compare.baseline model.current
        , Compare.onlyDifferences model.onlyDifferences OnlyDifferencesChanged
        , Compare.onRetry ReloadProducts
        ]
        { label = "Compare products"
        , records = model.products -- Remote (List Product)
        , id = .id
        , toKey = ProductId.toString
        , header = \product -> Html.text product.name
        , fields =
            [ Compare.text "SKU" .sku
            , Compare.heading "Pricing"
            , Compare.html "Price"
                (\product -> String.fromFloat product.price)
                (\product -> Html.text (Format.currency Locale.en "$" 2 product.price))
            , Compare.maybe "Discount" (Maybe.map String.fromInt << .discount)
            , Compare.heading "Description"
            , Compare.longText "Summary" .summary
            ]
        }

Fields are the rows and the records are the columns. The first record is the
baseline (or the one you name with `baseline`); every other record is compared
with it, cell by cell. A cell that differs says so with a sign (`≠`) and with hidden
text ("Differs from baseline") as well as with a color, a cell that is the same says
"Same as baseline" to a screen reader, and a row where every record is equal is
dimmed, or left out when the switch "Show only differences" is on (see
`onlyDifferences`). The headings of groups of fields (`heading`) are left out with
the rows under them.

**What counts as the same.** Every field gives a _text_ for each record, and two
records are the same in a field when the texts are exactly equal: no trimming and no
change of case. A text that is empty or only white space means that the record has no
value there, which is shown as a dash and is different from every real value (and the
same as another missing value). Functions are never compared, so a field that is
shown as a badge or as a formatted amount says what to compare with a text of its
own (`html`).

**States.** The records are a [Klar.Remote](Klar-Remote): `Loading` and `NotAsked`
draw a skeleton, `Failure` the error with "Try again" (see `onRetry`), and `Success
[]` an empty state ("Nothing to compare", see `emptyState`). With one record there is
nothing to compare it with, which the toolbar says. Pass `refreshing True` while new
data is on its way and the old table is still shown.

The table is a real `table` with `th scope="col"` for the records and `th
scope="row"` for the fields, inside a box that scrolls sideways and, with
`maxHeight`, up and down, and is a tab stop. The row labels stay at the left and the
headings at the top while it scrolls. The component has no state: the switch
"Show only differences" is yours (a `Bool` in your model).

**Right to left** pages are supported: the table, the sticky labels and the bar that marks
a difference follow the direction of the page (the `dir` attribute of the page).

**Cost.** The word marks in a long text (`longText`) are worked out in `view`, in
all about a third of a second for the whole table; the texts after that are shown without
marks. Keep the table to a handful of records, and long texts to the fields that need
them. The other fields cost one comparison of text for each cell.

**No fields.** A comparison with no fields (or only headings) says "No fields", not
"No differences".

Use [Klar.Table](Klar-Table) for many records of the same kind with sorting and
paging, and [Klar.Diff](Klar-Diff) for what changed between two versions of one text
or one record. The number of records is meant for a handful (a hundred columns work,
but are hard to read).


# View

@docs view


# Fields

@docs Field, text, maybe, html, longText, heading


# Attributes

@docs Attribute, baseline, onlyDifferences, onRetry, refreshing, density, maxHeight, emptyState, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Compare.Rows as Rows exposing (Mark(..), Value(..))
import Klar.Diff.Inline as Inline
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Skeleton as Skeleton
import Klar.Switch as Switch
import Klar.Theme as Theme exposing (Density(..), Size(..))



-- FIELDS


{-| A row of the comparison: a field of the records, or the heading of a group of
fields. Make them with `text`, `maybe`, `html`, `longText` and `heading`, and give a
list of them to `view`; the rows come in that order. The `record` is your type of
record and the `msg` the message type of the Html you pass to `html`.
-}
type Field record msg
    = Field
        { label : String
        , compared : record -> String
        , show : Show record msg
        }
    | Heading String


type Show record msg
    = ShowText
    | ShowHtml (record -> Html msg)
    | ShowLong


{-| A field that is a text. It is shown as it is and two records are the same in it
when the texts are the same. A blank text is no value.

    Compare.text "SKU" .sku

-}
text : String -> (record -> String) -> Field record msg
text label toText =
    Field { label = label, compared = toText, show = ShowText }


{-| A field that a record may not have: `Nothing` is no value, shown as a dash.

    Compare.maybe "Discount" (.discount >> Maybe.map String.fromInt)

-}
maybe : String -> (record -> Maybe String) -> Field record msg
maybe label toMaybe =
    Field { label = label, compared = toMaybe >> Maybe.withDefault "", show = ShowText }


{-| A field that is shown as Html (a badge, a formatted amount, a link) and compared
as a text. The first function gives the text that makes two records equal, the second
what is shown. Give the exact value as the text and the formatted one as the Html: two
prices that look the same after rounding are still different prices.

    Compare.html "Status"
        (\product -> Status.toString product.status)
        (\product -> Badge.view [] (Status.label product.status))

A blank text is no value, and then the Html is not drawn: a dash is.

-}
html : String -> (record -> String) -> (record -> Html msg) -> Field record msg
html label compared toHtml =
    Field { label = label, compared = compared, show = ShowHtml toHtml }


{-| A text of some length, such as a description or a note. It is wrapped over
several lines, and in the cells that differ from the baseline the words that
differ are marked: words only the baseline has are struck through and words only
this record has are underlined. A text that has nothing in common with the baseline
is shown as it is.

    Compare.longText "Summary" .summary

-}
longText : String -> (record -> String) -> Field record msg
longText label toText =
    Field { label = label, compared = toText, show = ShowLong }


{-| The heading of a group of fields, a full row such as "Pricing" above the
fields that belong to it. It has no values to compare, and when the switch "Show only
differences" leaves out every field under it the heading is left out too.
-}
heading : String -> Field record msg
heading label =
    Heading label



-- ATTRIBUTES


{-| A setting of the comparison. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. `id` is the type of your ids of
records and `msg` your message type.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { baseline : Maybe id
    , onlyDifferences : Maybe ( Bool, Bool -> msg )
    , onRetry : Maybe msg
    , refreshing : Bool
    , density : Density
    , maxHeight : Maybe Int
    , emptyState : List (EmptyState.Attribute msg)
    , locale : Locale
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { baseline = Nothing
        , onlyDifferences = Nothing
        , onRetry = Nothing
        , refreshing = False
        , density = Normal
        , maxHeight = Nothing
        , emptyState = []
        , locale = Locale.default
        }
        attributes


{-| The record the others are compared with, by its id. The default is the first
record. When no record has this id (it was taken out of the comparison), the first
record is the baseline again, and its column says so.
-}
baseline : id -> Attribute id msg
baseline id =
    Attribute (\config -> { config | baseline = Just id })


{-| Adds the switch "Show only differences" above the table. The `Bool` says
whether it is on (keep it in your model, `False` at the start) and the function gets
the new value when the user flips the switch. While it is on, the rows where every
record is equal, and the headings above only such rows, are left out. Without this
attribute there is no switch and all rows are drawn. With a single record the switch
is dimmed, as there is nothing to compare.

    Compare.onlyDifferences model.onlyDifferences OnlyDifferencesChanged

-}
onlyDifferences : Bool -> (Bool -> msg) -> Attribute id msg
onlyDifferences on toMsg =
    Attribute (\config -> { config | onlyDifferences = Just ( on, toMsg ) })


{-| The message to send when the user presses "Try again" in the error state, which
shows when `records` is a `Failure`. Without it there is no button, and the button
only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar-Remote)).
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Pass `True` while new data is on its way and you still hold the old records: the
table stays, dimmed, with a progress line under the headings, and screen readers hear
"Refreshing ...". It only applies to `Success`; the skeleton is shown while the
records are loading. The default is `False`.
-}
refreshing : Bool -> Attribute id msg
refreshing value =
    Attribute (\config -> { config | refreshing = value })


{-| How tightly the rows are packed, like the density of [Klar.Table](Klar-Table):
`Compact`, `Normal` (the default) or `Comfortable`.
-}
density : Density -> Attribute id msg
density value =
    Attribute (\config -> { config | density = value })


{-| Scrolls inside the table when it is taller than this many pixels, with the
headings of the records staying at the top. By default the table grows with its
rows; it scrolls sideways inside its own box in any case.
-}
maxHeight : Int -> Attribute id msg
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| Changes the empty state, which shows when there are no records: it has a title
("Nothing to compare") and a description, and these attributes are applied after
them, so yours win. Use it to say how to add records and to give the button for it.

    Compare.emptyState [ EmptyState.action addProductButton ]

-}
emptyState : List (EmptyState.Attribute msg) -> Attribute id msg
emptyState attributes =
    Attribute (\config -> { config | emptyState = attributes })


{-| The language of the built-in text: the heading of the column of the fields, the
words for the baseline and the differences, the switch and the counts. The default is
`Locale.default`, which is English. Your own labels and values are shown as you give
them.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { field : String
    , baseline : String
    , differs : String
    , same : String
    , notProvided : String
    , onlyDifferences : String
    , differing : Int -> Int -> String
    , showing : Int -> Int -> String
    , single : String
    , nothingToCompare : String
    , nothingToCompareDescription : String
    , noDifferences : String
    , noDifferencesDescription : String
    , noFields : String
    , noFieldsDescription : String
    , loading : String
    , refreshing : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        number =
            Format.int loc
    in
    { field = pick "Felt" "Field"
    , baseline = pick "Referanse" "Baseline"
    , differs = pick "Avviker fra referansen" "Differs from baseline"
    , same = pick "Lik referansen" "Same as baseline"
    , notProvided = pick "Ikke oppgitt" "Not provided"
    , onlyDifferences = pick "Vis bare forskjeller" "Show only differences"
    , differing = \n total -> pick (number n ++ " av " ++ number total ++ " felt avviker fra referansen") (number n ++ " of " ++ number total ++ " fields differ from the baseline")
    , showing = \n total -> pick ("Viser " ++ number n ++ " av " ++ number total ++ " felt") ("Showing " ++ number n ++ " of " ++ number total ++ " fields")
    , single = pick "Bare én post: det er ingenting å sammenligne den med." "Only one record: there is nothing to compare it with."
    , nothingToCompare = pick "Ingenting å sammenligne" "Nothing to compare"
    , nothingToCompareDescription = pick "Det er ingen poster å sammenligne ennå." "There are no records to compare yet."
    , noDifferences = pick "Ingen forskjeller" "No differences"
    , noDifferencesDescription = pick "Alle postene har de samme verdiene." "All the records have the same values."
    , noFields = pick "Ingen felt" "No fields"
    , noFieldsDescription = pick "Det er ingen felt å sammenligne postene på." "There are no fields to compare the records by."
    , loading = pick "Laster ..." "Loading ..."
    , refreshing = pick "Oppdaterer ..." "Refreshing ..."
    }



-- VIEW


{-| The comparison. `label` names it for screen readers ("Compare products"), and
it names the area that scrolls, which is a region and a tab stop. `records` are the
columns: the `header` of each record is whatever you want in the column heading (a
name, a status badge), `id` gives the id of a record in your own type and `toKey`
writes that id as a text (the id is what `baseline` refers to, and it keeps the
columns apart; two records with the same id are both drawn). `fields` are the rows.

The view sends a message only when a switch or a button you asked for is used
(`onlyDifferences`, `onRetry`).

-}
view :
    List (Attribute id msg)
    ->
        { label : String
        , records : Remote (List record)
        , id : record -> id
        , toKey : id -> String
        , header : record -> Html msg
        , fields : List (Field record msg)
        }
    -> Html msg
view attributes config =
    let
        settings =
            configure attributes

        t =
            texts settings.locale
    in
    case Tuple.first (Freshness.settle config.records) of
        Remote.Loaded [] ->
            frame settings
                []
                [ EmptyState.view
                    ([ EmptyState.compact
                     , EmptyState.icon Icon.columns
                     , EmptyState.title t.nothingToCompare
                     , EmptyState.description t.nothingToCompareDescription
                     ]
                        ++ settings.emptyState
                    )
                ]

        Remote.Loaded records ->
            viewRecords settings t config records

        Remote.Failed problem ->
            frame settings
                []
                [ ErrorState.view
                    (List.filterMap identity
                        [ Just ErrorState.compact
                        , Just (ErrorState.locale settings.locale)
                        , Maybe.map ErrorState.onRetry settings.onRetry
                        ]
                    )
                    problem
                ]

        _ ->
            viewLoading settings t config.label


frame : Config id msg -> List String -> List (Html msg) -> Html msg
frame settings modifiers content =
    Html.div
        [ Internal.cls
            ([ "klar-compare", "klar-compare--" ++ Theme.densitySuffix settings.density ]
                ++ modifiers
            )
        ]
        content


viewLoading : Config id msg -> Texts -> String -> Html msg
viewLoading settings t label =
    let
        skeletonCell width =
            Html.td [ Internal.cls [ "klar-compare__cell" ] ] [ Skeleton.line width ]

        skeletonRow i =
            Html.tr [ Internal.cls [ "klar-compare__row" ], Attr.attribute "aria-hidden" "true" ]
                (Html.th [ Internal.cls [ "klar-compare__label" ], Attr.scope "row" ] [ Skeleton.line (40 + modBy 3 i * 12) ]
                    :: List.map (\j -> skeletonCell (45 + modBy 4 (i * 3 + j * 5) * 12)) [ 0, 1, 2 ]
                )
    in
    frame settings
        [ "klar-compare--loading" ]
        [ Html.div [ Internal.cls [ "klar-compare__frame" ] ]
            [ Html.div [ Internal.cls [ "klar-compare__scroll" ] ]
                [ Html.table
                    [ Internal.cls [ "klar-compare__table" ]
                    , Attr.attribute "aria-label" label
                    , Attr.attribute "aria-busy" "true"
                    ]
                    [ Html.thead []
                        [ Html.tr []
                            (Html.th [ Internal.cls [ "klar-compare__corner" ], Attr.scope "col" ] [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.field ] ]
                                :: List.map
                                    (\j ->
                                        Html.th [ Internal.cls [ "klar-compare__head" ], Attr.scope "col", Attr.attribute "aria-hidden" "true" ]
                                            [ Skeleton.line (50 + j * 10) ]
                                    )
                                    [ 0, 1, 2 ]
                            )
                        ]
                    , Html.tbody [] (List.map skeletonRow (List.range 0 5))
                    ]
                ]
            ]
        , Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text t.loading ]
        ]


{-| One row as the view needs it: a heading, or a field with the value of every record
and how each cell stands to the baseline.
-}
type Line record msg
    = HeadingLine String
    | FieldLine
        { label : String
        , show : Show record msg
        , values : List Value
        , row : Rows.Row
        , words : List (Maybe (List Inline.Segment))
        }


lineRow : Line record msg -> Maybe Rows.Row
lineRow line =
    case line of
        HeadingLine _ ->
            Nothing

        FieldLine found ->
            Just found.row


viewRecords :
    Config id msg
    -> Texts
    ->
        { label : String
        , records : Remote (List record)
        , id : record -> id
        , toKey : id -> String
        , header : record -> Html msg
        , fields : List (Field record msg)
        }
    -> List record
    -> Html msg
viewRecords settings t config records =
    let
        recordCount =
            List.length records

        plainKeys =
            List.map (config.id >> config.toKey) records

        keys =
            Rows.uniqueKeys plainKeys

        baselineAt =
            Rows.baselineIndex plainKeys (Maybe.map config.toKey settings.baseline)

        lines =
            List.map
                (\field ->
                    case field of
                        Heading label ->
                            HeadingLine label

                        Field found ->
                            let
                                values =
                                    List.map (found.compared >> Rows.value) records
                            in
                            FieldLine
                                { label = found.label
                                , show = found.show
                                , values = values
                                , row = Rows.compareRow baselineAt values
                                , words = List.map (always Nothing) values
                                }
                )
                config.fields

        fieldRows =
            List.filterMap lineRow lines

        differing =
            List.length (List.filter (\row -> not row.allEqual) fieldRows)

        only =
            case settings.onlyDifferences of
                Just ( on, _ ) ->
                    on && recordCount >= 2

                Nothing ->
                    False

        shown =
            Rows.visible only lineRow lines
                |> withWordMarks baselineAt

        shownFields =
            List.length (List.filterMap lineRow shown)

        refreshingNow =
            settings.refreshing

        summary =
            if List.isEmpty fieldRows then
                t.noFields

            else if recordCount < 2 then
                t.single

            else if only then
                t.showing shownFields (List.length fieldRows)

            else
                t.differing differing (List.length fieldRows)

        toolbar =
            Html.div [ Internal.cls [ "klar-compare__toolbar" ] ]
                [ case settings.onlyDifferences of
                    Just ( on, toMsg ) ->
                        Switch.view
                            [ Switch.label t.onlyDifferences
                            , Switch.checked on
                            , Switch.onToggle toMsg
                            , Switch.size Small
                            , Switch.disabled (recordCount < 2)
                            , Switch.locale settings.locale
                            ]

                    Nothing ->
                        Html.text ""
                , Html.span
                    [ Internal.cls [ "klar-compare__summary", "klar-tabular" ]
                    , Attr.attribute "role" "status"
                    ]
                    [ Html.text
                        (if refreshingNow then
                            t.refreshing

                         else
                            summary
                        )
                    ]
                ]

        columns =
            List.map3 (\record key index -> ( record, key, index )) records keys (List.range 0 (recordCount - 1))

        headRow =
            Keyed.node "tr"
                []
                (( "field"
                 , Html.th [ Internal.cls [ "klar-compare__corner" ], Attr.scope "col" ] [ Html.text t.field ]
                 )
                    :: List.map
                        (\( record, key, index ) ->
                            ( "record " ++ key
                            , Html.th
                                [ Internal.cls
                                    [ "klar-compare__head"
                                    , if index == baselineAt && recordCount >= 2 then
                                        "klar-compare__head--baseline"

                                      else
                                        ""
                                    ]
                                , Attr.scope "col"
                                ]
                                [ Html.div [ Internal.cls [ "klar-compare__title" ] ] [ config.header record ]
                                , if index == baselineAt && recordCount >= 2 then
                                    Html.span [ Internal.cls [ "klar-compare__tag" ] ] [ Html.text t.baseline ]

                                  else
                                    Html.text ""
                                ]
                            )
                        )
                        columns
                )

        groups =
            groupByHeading shown

        body =
            if List.isEmpty shown || List.isEmpty fieldRows then
                [ Html.tbody []
                    [ Html.tr []
                        [ Html.td [ Internal.cls [ "klar-compare__none" ], Attr.colspan (recordCount + 1) ]
                            [ EmptyState.view
                                [ EmptyState.compact
                                , EmptyState.icon Icon.checkCircle
                                , if List.isEmpty fieldRows then
                                    EmptyState.title t.noFields

                                  else
                                    EmptyState.title t.noDifferences
                                , if List.isEmpty fieldRows then
                                    EmptyState.description t.noFieldsDescription

                                  else
                                    EmptyState.description t.noDifferencesDescription
                                ]
                            ]
                        ]
                    ]
                ]

            else
                List.map (viewGroup t columns baselineAt recordCount) groups
    in
    frame settings
        ((if refreshingNow then
            [ "klar-compare--refreshing" ]

          else
            []
         )
            ++ (if recordCount < 2 then
                    [ "klar-compare--alone" ]

                else
                    []
               )
        )
        [ toolbar
        , Html.div [ Internal.cls [ "klar-compare__frame" ] ]
            [ Html.div
                ([ Internal.cls [ "klar-compare__scroll" ]
                 , Attr.tabindex 0
                 , Attr.attribute "role" "region"
                 , Attr.attribute "aria-label" config.label
                 ]
                    ++ (case settings.maxHeight of
                            Just pixels ->
                                [ Internal.styleVars [ ( "max-height", Internal.px pixels ) ] ]

                            Nothing ->
                                []
                       )
                )
                [ Html.table
                    ([ Internal.cls [ "klar-compare__table" ]
                     , Attr.attribute "aria-label" config.label
                     ]
                        ++ (if refreshingNow then
                                [ Attr.attribute "aria-busy" "true" ]

                            else
                                []
                           )
                    )
                    (Html.thead [] [ headRow ] :: body)
                ]
            , if refreshingNow then
                Html.div [ Internal.cls [ "klar-compare__progress" ], Attr.attribute "aria-hidden" "true" ] []

              else
                Html.text ""
            ]
        ]


{-| The lines cut into groups, each with the heading it belongs to (the rows before the
first heading belong to none).
-}
groupByHeading : List (Line record msg) -> List ( Maybe String, List (Line record msg) )
groupByHeading lines =
    let
        step line groups =
            case line of
                HeadingLine label ->
                    ( Just label, [] ) :: groups

                FieldLine _ ->
                    case groups of
                        ( heading_, rows ) :: before ->
                            ( heading_, line :: rows ) :: before

                        [] ->
                            [ ( Nothing, [ line ] ) ]
    in
    List.foldl step [] lines
        |> List.map (\( heading_, rows ) -> ( heading_, List.reverse rows ))
        |> List.reverse


viewGroup :
    Texts
    -> List ( record, String, Int )
    -> Int
    -> Int
    -> ( Maybe String, List (Line record msg) )
    -> Html msg
viewGroup t columns baselineAt recordCount ( heading_, rows ) =
    Html.tbody [ Internal.cls [ "klar-compare__group" ] ]
        ((case heading_ of
            Just label ->
                [ Html.tr [ Internal.cls [ "klar-compare__heading-row" ] ]
                    [ Html.th
                        [ Internal.cls [ "klar-compare__heading" ]
                        , Attr.scope "rowgroup"
                        , Attr.colspan (recordCount + 1)
                        ]
                        [ Html.span [ Internal.cls [ "klar-compare__heading-text" ] ] [ Html.text label ] ]
                    ]
                ]

            Nothing ->
                []
         )
            ++ List.filterMap (viewLine t columns baselineAt) rows
        )


viewLine : Texts -> List ( record, String, Int ) -> Int -> Line record msg -> Maybe (Html msg)
viewLine t columns baselineAt line =
    case line of
        HeadingLine _ ->
            Nothing

        FieldLine found ->
            let
                baselineValue =
                    found.values |> List.drop baselineAt |> List.head |> Maybe.withDefault Missing

                cells =
                    List.map4
                        (\( record, key, _ ) value mark words ->
                            ( "record " ++ key, viewCell t found.show baselineValue record value mark words )
                        )
                        columns
                        found.values
                        found.row.marks
                        found.words
            in
            Just
                (Keyed.node "tr"
                    [ Internal.cls
                        [ "klar-compare__row"
                        , if found.row.allEqual then
                            "klar-compare__row--equal"

                          else
                            ""
                        ]
                    ]
                    (( "label"
                     , Html.th [ Internal.cls [ "klar-compare__label" ], Attr.scope "row" ] [ Html.text found.label ]
                     )
                        :: cells
                    )
                )


{-| Marks the words of the long texts that differ from the baseline. The work is
limited for the whole table (`Inline.sharedBudget`): the texts after it is spent are
shown as they are, without marks.
-}
withWordMarks : Int -> List (Line record msg) -> List (Line record msg)
withWordMarks baselineAt lines =
    let
        step line ( built, left ) =
            case line of
                FieldLine found ->
                    case ( found.show, found.values |> List.drop baselineAt |> List.head ) of
                        ( ShowLong, Just (Value reference) ) ->
                            let
                                ( words, remaining ) =
                                    wordsOf reference left found.values found.row.marks
                            in
                            ( FieldLine { found | words = words } :: built, remaining )

                        _ ->
                            ( line :: built, left )

                HeadingLine _ ->
                    ( line :: built, left )
    in
    List.foldl step ( [], Inline.sharedBudget ) lines
        |> Tuple.first
        |> List.reverse


wordsOf : String -> Int -> List Value -> List Mark -> ( List (Maybe (List Inline.Segment)), Int )
wordsOf reference budget values marks =
    let
        step ( value, mark ) ( built, left ) =
            case ( mark, value ) of
                ( Differs, Value shownText ) ->
                    let
                        ( segments, spent ) =
                            Inline.diffWithin left reference shownText
                    in
                    ( Just segments :: built, left - spent )

                _ ->
                    ( Nothing :: built, left )
    in
    List.foldl step ( [], budget ) (List.map2 Tuple.pair values marks)
        |> Tuple.mapFirst List.reverse


markName : Mark -> String
markName mark =
    case mark of
        Baseline ->
            "baseline"

        Same ->
            "same"

        Differs ->
            "differs"

        Alone ->
            "alone"


viewCell : Texts -> Show record msg -> Value -> record -> Value -> Mark -> Maybe (List Inline.Segment) -> Html msg
viewCell t show baselineValue record value mark words =
    let
        srOnly sentence =
            Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text sentence ]

        prefix =
            case mark of
                Differs ->
                    [ Html.span [ Internal.cls [ "klar-compare__sign" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "≠" ]
                    , srOnly (t.differs ++ ": ")
                    ]

                Same ->
                    [ srOnly (t.same ++ ": ") ]

                _ ->
                    []

        content =
            case value of
                Missing ->
                    [ Html.span [ Internal.cls [ "klar-compare__none-mark" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "-" ]
                    , srOnly t.notProvided
                    ]

                Value shownText ->
                    case show of
                        ShowText ->
                            [ Html.text shownText ]

                        ShowHtml toHtml ->
                            [ toHtml record ]

                        ShowLong ->
                            case words of
                                Just segments ->
                                    viewWordDiff segments shownText

                                Nothing ->
                                    [ Html.text shownText ]
    in
    Html.td
        [ Internal.cls
            [ "klar-compare__cell"
            , "klar-compare__cell--" ++ markName mark
            , case show of
                ShowLong ->
                    "klar-compare__cell--long"

                _ ->
                    ""
            ]
        ]
        (prefix ++ [ Html.span [ Internal.cls [ "klar-compare__value" ] ] content ])


{-| The text of a record with the words that differ from the baseline marked: words
only the baseline has are struck through, words only this text has are underlined.
Text that has nothing in common with the baseline is shown as it is.
-}
viewWordDiff : List Inline.Segment -> String -> List (Html msg)
viewWordDiff segments shownText =
    case segments of
        [ Inline.Replace _ _ ] ->
            [ Html.text shownText ]

        _ ->
            List.concatMap
                (\segment ->
                    case segment of
                        Inline.Keep kept ->
                            [ Html.text kept ]

                        Inline.Replace removed added ->
                            (if removed == "" then
                                []

                             else
                                [ Html.del [ Internal.cls [ "klar-compare__del" ] ] [ Html.text removed ] ]
                            )
                                ++ (if added == "" then
                                        []

                                    else
                                        [ Html.ins [ Internal.cls [ "klar-compare__ins" ] ] [ Html.text added ] ]
                                   )
                )
                segments
