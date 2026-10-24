module Klar.Compare exposing
    ( view, viewRemote
    , Field, text, maybe, html, longText, heading
    , Attribute, baseline, onlyDifferences, onOnlyDifferences, onRetry, id, density, maxHeight, emptyState, locale, settings
    )

{-| Records side by side, with the differences marked: two or more products,
two versions of an order, "your version" against "theirs".

Use when: two or more records are read side by side and the application wants to see where they differ.
Do not use when: the change between two versions of one text or record is the point, use `Klar.Diff`; many records of one kind with sorting and paging, use `Klar.Table`.

    import Klar.Compare as Compare
    import Klar.Format as Format

    -- model: products : Remote (List Product), onlyDifferences : Bool
    -- update
    OnlyDifferencesChanged on ->
        ( { model | onlyDifferences = on }, Cmd.none )

    -- view
    Compare.viewRemote
        [ Compare.onlyDifferences model.onlyDifferences
        , Compare.onOnlyDifferences OnlyDifferencesChanged
        , Compare.onRetry ReloadProducts
        , Compare.settings model.settings
        ]
        { ariaLabel = "Compare products"
        , ids = productIds
        , id = .id
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
        model.products

Fields are the rows and the records are the columns. The first record is the
baseline (or the one you name with `baseline`); every other record is compared
with it, cell by cell. A cell that differs says so with a sign (`≠`) and with hidden
text ("Differs from baseline") as well as with a color, a cell that is the same says
"Same as baseline" to a screen reader, and a row where every record is equal is
dimmed, or left out while `onlyDifferences` is `True` (the switch "Show only
differences" of `onOnlyDifferences` flips it). The headings of groups of fields
(`heading`) are left out with the rows under them.

**What counts as the same.** Every field gives a _text_ for each record, and two
records are the same in a field when the texts are exactly equal: no trimming and no
change of case. A text that is empty or only white space means that the record has no
value there, which is shown as a dash and is different from every real value (and the
same as another missing value). Functions are never compared, so a field that is
shown as a badge or as a formatted amount says what to compare with a text of its
own (`html`).

**States.** `view` takes the records you hold; `viewRemote` takes them as a
[Klar.Remote](Klar-Remote) (shape your data with `Remote.map`). `NotAsked` and
`Loading` draw a skeleton, `Failed` the problem with "Try again" (see `onRetry`), and
`Loaded []` the empty state ("Nothing to compare", see `emptyState`). Data that is
`Kept` stays on the screen: dimmed, busy and announced as "Refreshing ..." while a
refresh is on its way (`Remote.refresh`), and with "Old data from 14:05" and "Try
again" in the toolbar when the last refresh failed (the time is written in the zone of
`settings`). The table is the same element in all of these, so focus inside it stays
where it is. With one record there is nothing to compare it with, which the toolbar
says.

The table is a real `table` with `th scope="col"` for the records and `th
scope="row"` for the fields, inside a box that scrolls sideways and, with
`maxHeight`, up and down; that box is a region named by `ariaLabel` and a tab stop.
The row labels stay at the start and the headings at the top while it scrolls. The
component has no state: whether only the differences are shown is yours (a `Bool` in
your model).

**Right to left** pages are supported: the table, the sticky labels and the bar that marks
a difference follow the direction of the page (the `dir` attribute of the page).

**Cost.** The word marks in a long text (`longText`) are worked out once for each pair
of texts and kept while the texts stay the same (`Html.Lazy`), so a message of the
application that changes nothing in the comparison does not repeat them. All the long
texts of the table share a budget of about a third of a second; a pair that does not
fit in its part is shown without marks. The other fields cost one comparison of text
for each cell. The number of records is meant for a handful (a hundred columns work,
but are hard to read).

**No fields.** A comparison with no fields (or only headings) says "No fields", not
"No differences".


# View

@docs view, viewRemote


# Fields

@docs Field, text, maybe, html, longText, heading


# Attributes

@docs Attribute, baseline, onlyDifferences, onOnlyDifferences, onRetry, id, density, maxHeight, emptyState, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Klar.Compare.Rows as Rows exposing (Mark(..), Value(..))
import Klar.Diff.Inline as Inline
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Switch as Switch
import Klar.Theme exposing (Density(..), Size(..))



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
fields that belong to it. It has no values to compare, and when `onlyDifferences`
leaves out every field under it the heading is left out too.
-}
heading : String -> Field record msg
heading label =
    Heading label



-- ATTRIBUTES


{-| A setting of the comparison. Make them with the functions below and pass a list
to `view` or `viewRemote`; later attributes win over earlier ones. `id` is the type
of your ids of records and `msg` your message type.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { baseline : Maybe id
    , onlyDifferences : Bool
    , onOnlyDifferences : Maybe (Bool -> msg)
    , onRetry : Maybe msg
    , domId : Maybe String
    , density : Density
    , maxHeight : Maybe Int
    , emptyState : List (EmptyState.Attribute msg)
    , locale : Locale
    , settings : Settings
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { baseline = Nothing
        , onlyDifferences = False
        , onOnlyDifferences = Nothing
        , onRetry = Nothing
        , domId = Nothing
        , density = Normal
        , maxHeight = Nothing
        , emptyState = []
        , locale = Locale.default
        , settings = Settings.default
        }
        attributes


{-| The record the others are compared with, by its id. The default is the first
record. When no record has this id (it was taken out of the comparison), the first
record is the baseline again, and its column says so.
-}
baseline : id -> Attribute id msg
baseline value =
    Attribute (\config -> { config | baseline = Just value })


{-| While `True`, the rows where every record is equal are left out, and so are the
headings above only such rows. The default is `False`: every row is drawn, and the
rows that are equal are dimmed. Keep the `Bool` in your model; with a single record
there is nothing to compare and every row is drawn.

    Compare.onlyDifferences model.onlyDifferences

-}
onlyDifferences : Bool -> Attribute id msg
onlyDifferences on =
    Attribute (\config -> { config | onlyDifferences = on })


{-| Adds the switch "Show only differences" to the toolbar above the table. It is on
while `onlyDifferences` is `True`, and the function gets the new value when the user
flips it. Without this attribute there is no switch. With a single record the switch
is dimmed, as there is nothing to compare.

    Compare.onOnlyDifferences OnlyDifferencesChanged

-}
onOnlyDifferences : (Bool -> msg) -> Attribute id msg
onOnlyDifferences toMsg =
    Attribute (\config -> { config | onOnlyDifferences = Just toMsg })


{-| The message sent by "Try again": in the failure (`Failed`), and in the marker of
old data (`Kept` after a refresh that failed). Without it there is no button, and the
button only appears for problems worth retrying (see `Remote.isRetryable` in
[Klar.Remote](Klar-Remote)). The button goes away once the new data is there; give
the comparison an `id` and move focus to it when you start the request, so focus does
not fall to the page.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The DOM id of the comparison, unique on the page. The comparison is one element
in every state (loading, failed, empty, data), and with an id it can take focus, so
that `Klar.focus` has a place to put it when "Try again" goes away:

    Compare.id "compare-products"

    Retry ->
        ( { model | products = Remote.refresh model.products }
        , Cmd.batch [ fetchProducts, Klar.focus "compare-products" NoOp ]
        )

-}
id : String -> Attribute id msg
id value =
    Attribute (\config -> { config | domId = Just value })


{-| How tightly the rows are packed, like the density of [Klar.Table](Klar-Table):
`Compact`, `Normal` or `Comfortable`. Without it, or with `Normal`, the rows follow
the density of the application (`Klar.Settings`).
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
words for the baseline and the differences, the switch, the counts and the marker of
old data. The default is `Locale.default`, which is English. Your own labels and
values are shown as you give them.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Compare.settings model.settings

-}
settings : Settings -> Attribute id msg
settings given =
    Attribute (\config -> { config | settings = given })



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


{-| The comparison of the records you hold. `ariaLabel` names it for screen readers
("Compare products"): it names the box that scrolls, which is a region and a tab
stop. The records are the columns: the `header` of each record is whatever you want
in the column heading (a name, a status badge), `id` gives the id of a record in your
own type and `ids` how that type is written as a key ([Klar.Ids](Klar-Ids)). The id
is what `baseline` refers to, and it keeps the columns apart; two records with the
same id are both drawn. `fields` are the rows. An empty list draws the empty state.

The view sends a message only when a switch or a button you asked for is used
(`onOnlyDifferences`, `onRetry`).

    Compare.view [ Compare.baseline model.current ]
        { ariaLabel = "Compare versions"
        , ids = versionIds
        , id = .id
        , header = \version -> Html.text version.title
        , fields = [ Compare.text "Status" .status, Compare.longText "Notes" .notes ]
        }
        model.versions

-}
view :
    List (Attribute id msg)
    ->
        { ariaLabel : String
        , ids : Ids id
        , id : record -> id
        , header : record -> Html msg
        , fields : List (Field record msg)
        }
    -> List record
    -> Html msg
view attributes columns records =
    viewRemote attributes columns (Remote.Loaded records)


{-| The same comparison for records that come from the backend, in every state of a
[Klar.Remote](Klar-Remote): a skeleton while `NotAsked` or `Loading`, the problem
with "Try again" (`onRetry`) when `Failed`, the empty state for `Loaded []`, and the
table for `Loaded`. `Kept` data stays in the same table: dimmed and busy while it is
refreshed, and with the marker "Old data from 14:05" and "Try again" when the last
refresh failed.

    Compare.viewRemote
        [ Compare.onRetry ReloadProducts, Compare.settings model.settings ]
        productColumns
        (Remote.map .items model.products)

-}
viewRemote :
    List (Attribute id msg)
    ->
        { ariaLabel : String
        , ids : Ids id
        , id : record -> id
        , header : record -> Html msg
        , fields : List (Field record msg)
        }
    -> Remote (List record)
    -> Html msg
viewRemote attributes columns data =
    let
        config =
            configure attributes

        t =
            texts config.locale

        ( settled, freshness ) =
            Freshness.settle data
    in
    case settled of
        Remote.Loaded [] ->
            frame config
                [ Freshness.className freshness ]
                [ Freshness.busyAttr freshness ]
                [ staleNotice config freshness False
                , EmptyState.view
                    ([ EmptyState.compact
                     , EmptyState.icon Icon.columns
                     , EmptyState.title t.nothingToCompare
                     , EmptyState.description t.nothingToCompareDescription
                     ]
                        ++ config.emptyState
                    )
                ]

        Remote.Loaded records ->
            viewRecords config t columns freshness records

        Remote.Failed problem ->
            frame config
                []
                []
                [ ErrorState.view
                    (List.filterMap identity
                        [ Just ErrorState.compact
                        , Just (ErrorState.locale config.locale)
                        , Maybe.map ErrorState.onRetry config.onRetry
                        ]
                    )
                    problem
                ]

        _ ->
            viewLoading config t


{-| The element of the comparison, the same in every state: its classes, and its id
when the application gave one (with `tabindex="-1"`, so `Klar.focus` can land on it).
-}
frame : Config id msg -> List String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
frame config modifiers attributes content =
    Html.div
        ([ Internal.cls
            ([ "klar-compare", "klar-compare--" ++ Internal.densitySuffix config.density ]
                ++ modifiers
            )
         , Internal.attrMaybe Attr.id config.domId
         , Internal.attrIf (config.domId /= Nothing) (Attr.tabindex -1)
         ]
            ++ attributes
        )
        content


staleNotice : Config id msg -> Freshness -> Bool -> Html msg
staleNotice config freshness inline =
    Freshness.notice
        { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = inline }
        freshness


viewLoading : Config id msg -> Texts -> Html msg
viewLoading config t =
    let
        skeletonCell width =
            Html.td [ Internal.cls [ "klar-compare__cell" ] ] [ Skeleton.line width ]

        skeletonRow i =
            Html.tr [ Internal.cls [ "klar-compare__row" ], Attr.attribute "aria-hidden" "true" ]
                (Html.th [ Internal.cls [ "klar-compare__label" ], Attr.scope "row" ] [ Skeleton.line (40 + modBy 3 i * 12) ]
                    :: List.map (\j -> skeletonCell (45 + modBy 4 (i * 3 + j * 5) * 12)) [ 0, 1, 2 ]
                )
    in
    frame config
        [ "klar-compare--loading" ]
        [ Attr.attribute "aria-busy" "true" ]
        [ Html.div [ Internal.cls [ "klar-compare__frame" ] ]
            [ Html.div [ Internal.cls [ "klar-compare__scroll" ] ]
                [ Html.table
                    [ Internal.cls [ "klar-compare__table" ]
                    , Attr.attribute "aria-hidden" "true"
                    ]
                    [ Html.thead []
                        [ Html.tr []
                            (Html.th [ Internal.cls [ "klar-compare__corner" ], Attr.scope "col" ] []
                                :: List.map
                                    (\j ->
                                        Html.th [ Internal.cls [ "klar-compare__head" ], Attr.scope "col" ]
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
        }


lineRow : Line record msg -> Maybe Rows.Row
lineRow line =
    case line of
        HeadingLine _ ->
            Nothing

        FieldLine found ->
            Just found.row


{-| What every cell of the table needs to know besides its own value.
-}
type alias Env record =
    { t : Texts
    , columns : List ( record, String, Int )
    , baselineAt : Int
    , recordCount : Int
    , budget : Int
    }


viewRecords :
    Config id msg
    -> Texts
    ->
        { ariaLabel : String
        , ids : Ids id
        , id : record -> id
        , header : record -> Html msg
        , fields : List (Field record msg)
        }
    -> Freshness
    -> List record
    -> Html msg
viewRecords config t columns freshness records =
    let
        recordCount =
            List.length records

        plainKeys =
            List.map (columns.id >> Ids.toKey columns.ids) records

        keys =
            Rows.uniqueKeys plainKeys

        baselineAt =
            Rows.baselineIndex plainKeys (Maybe.map (Ids.toKey columns.ids) config.baseline)

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
                                }
                )
                columns.fields

        fieldRows =
            List.filterMap lineRow lines

        differing =
            List.length (List.filter (\row -> not row.allEqual) fieldRows)

        only =
            config.onlyDifferences && recordCount >= 2

        shown =
            Rows.visible only lineRow lines

        shownFields =
            List.length (List.filterMap lineRow shown)

        busy =
            Freshness.busy freshness

        summary =
            if busy then
                t.refreshing

            else if List.isEmpty fieldRows then
                t.noFields

            else if recordCount < 2 then
                t.single

            else if only then
                t.showing shownFields (List.length fieldRows)

            else
                t.differing differing (List.length fieldRows)

        toolbar =
            Html.div [ Internal.cls [ "klar-compare__toolbar" ] ]
                [ case config.onOnlyDifferences of
                    Just toMsg ->
                        Switch.view
                            [ Switch.label t.onlyDifferences
                            , Switch.checked config.onlyDifferences
                            , Switch.onToggle toMsg
                            , Switch.size Small
                            , Switch.disabled (recordCount < 2)
                            , Switch.locale config.locale
                            ]

                    Nothing ->
                        Html.text ""
                , staleNotice config freshness True
                , Html.span
                    [ Internal.cls [ "klar-compare__summary", "klar-tabular" ]
                    , Attr.attribute "role" "status"
                    ]
                    [ Html.text summary ]
                ]

        env =
            { t = t
            , columns = List.map3 (\record key index -> ( record, key, index )) records keys (List.range 0 (recordCount - 1))
            , baselineAt = baselineAt
            , recordCount = recordCount
            , budget = wordBudget baselineAt shown
            }

        headRow =
            Keyed.node "tr"
                []
                (( "field"
                 , Html.th [ Internal.cls [ "klar-compare__corner" ], Attr.scope "col" ] [ Html.text t.field ]
                 )
                    :: List.map
                        (\( record, key, index ) ->
                            let
                                isBaseline =
                                    index == baselineAt && recordCount >= 2
                            in
                            ( "record " ++ key
                            , Html.th
                                [ Internal.cls
                                    [ "klar-compare__head"
                                    , if isBaseline then
                                        "klar-compare__head--baseline"

                                      else
                                        ""
                                    ]
                                , Attr.scope "col"
                                ]
                                [ Html.div [ Internal.cls [ "klar-compare__title" ] ] [ columns.header record ]
                                , if isBaseline then
                                    Html.span [ Internal.cls [ "klar-compare__tag" ] ] [ Html.text t.baseline ]

                                  else
                                    Html.text ""
                                ]
                            )
                        )
                        env.columns
                )

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
                List.map (viewGroup env) (groupByHeading shown)
    in
    frame config
        [ if busy then
            "klar-compare--refreshing"

          else
            ""
        , if recordCount < 2 then
            "klar-compare--alone"

          else
            ""
        ]
        []
        [ toolbar
        , Html.div [ Internal.cls [ "klar-compare__frame" ] ]
            [ Html.div
                [ Internal.cls [ "klar-compare__scroll" ]
                , Attr.tabindex 0
                , Attr.attribute "role" "region"
                , Attr.attribute "aria-label" columns.ariaLabel
                , Internal.attrMaybe (\pixels -> Internal.styleVars [ ( "max-height", Internal.px pixels ) ]) config.maxHeight
                ]
                [ Html.table
                    [ Internal.cls [ "klar-compare__table" ]
                    , Freshness.busyAttr freshness
                    ]
                    (Html.thead [] [ headRow ] :: body)
                ]
            , if busy then
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


viewGroup : Env record -> ( Maybe String, List (Line record msg) ) -> Html msg
viewGroup env ( heading_, rows ) =
    Html.tbody [ Internal.cls [ "klar-compare__group" ] ]
        ((case heading_ of
            Just label ->
                [ Html.tr [ Internal.cls [ "klar-compare__heading-row" ] ]
                    [ Html.th
                        [ Internal.cls [ "klar-compare__heading" ]
                        , Attr.scope "rowgroup"
                        , Attr.colspan (env.recordCount + 1)
                        ]
                        [ Html.span [ Internal.cls [ "klar-compare__heading-text" ] ] [ Html.text label ] ]
                    ]
                ]

            Nothing ->
                []
         )
            ++ List.filterMap (viewLine env) rows
        )


viewLine : Env record -> Line record msg -> Maybe (Html msg)
viewLine env line =
    case line of
        HeadingLine _ ->
            Nothing

        FieldLine found ->
            let
                baselineValue =
                    found.values |> List.drop env.baselineAt |> List.head |> Maybe.withDefault Missing

                cells =
                    List.map3
                        (\( record, key, _ ) value mark ->
                            ( "record " ++ key, viewCell env found.show baselineValue record value mark )
                        )
                        env.columns
                        found.values
                        found.row.marks
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


{-| The work each pair of long texts may take to mark its words: the shared budget
(`Inline.sharedBudget`, about a third of a second) cut into equal parts, one for each
cell of a long text that differs from a baseline that has a value. The part depends
only on how many such cells are drawn, so it is the same from one view to the next
and the marks of a cell can be kept (`Html.Lazy`). A pair that does not fit in its
part is shown without marks.
-}
wordBudget : Int -> List (Line record msg) -> Int
wordBudget baselineAt lines =
    let
        pairs line =
            case line of
                FieldLine found ->
                    case ( found.show, found.values |> List.drop baselineAt |> List.head ) of
                        ( ShowLong, Just (Value _) ) ->
                            List.map2
                                (\value mark ->
                                    case ( mark, value ) of
                                        ( Differs, Value _ ) ->
                                            1

                                        _ ->
                                            0
                                )
                                found.values
                                found.row.marks
                                |> List.sum

                        _ ->
                            0

                HeadingLine _ ->
                    0
    in
    Inline.sharedBudget // max 1 (List.sum (List.map pairs lines))


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


viewCell : Env record -> Show record msg -> Value -> record -> Value -> Mark -> Html msg
viewCell env show baselineValue record value mark =
    let
        t =
            env.t

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

        plain content =
            Html.span [ Internal.cls [ "klar-compare__value" ] ] content

        shownValue =
            case value of
                Missing ->
                    plain
                        [ Html.span [ Internal.cls [ "klar-compare__none-mark" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "-" ]
                        , srOnly t.notProvided
                        ]

                Value shownText ->
                    case show of
                        ShowText ->
                            plain [ Html.text shownText ]

                        ShowHtml toHtml ->
                            plain [ toHtml record ]

                        ShowLong ->
                            case ( mark, baselineValue ) of
                                ( Differs, Value reference ) ->
                                    Lazy.lazy3 viewWordMarks env.budget reference shownText

                                _ ->
                                    plain [ Html.text shownText ]
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
        (prefix ++ [ shownValue ])


{-| The text of a record with the words that differ from the baseline marked: words
only the baseline has are struck through, words only this text has are underlined.
Text that has nothing in common with the baseline, or that does not fit in the
budget, is shown as it is. It takes only texts and a number, so `Html.Lazy` keeps it
while they stay the same.
-}
viewWordMarks : Int -> String -> String -> Html msg
viewWordMarks budget reference shownText =
    Html.span [ Internal.cls [ "klar-compare__value" ] ]
        (case Tuple.first (Inline.diffWithin budget reference shownText) of
            [ Inline.Replace _ _ ] ->
                [ Html.text shownText ]

            segments ->
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
        )
