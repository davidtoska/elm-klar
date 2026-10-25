module Klar.BulkBar exposing
    ( view
    , Attribute, selectAllMatching, itemName, id, locale
    )

{-| The bar of actions for the items the user has selected: "12 selected: Export,
Delete".

Use when: a list, a grid of cards or another selectable collection needs actions for the selected items.
Do not use when: the items are in a `Klar.Table`, which draws a bar of its own for its selection (`Table.bulkActions`).
Quick path: `view` with the toolbar, the count and the message of Clear selection; `selectAllMatching`; `id`, for `Klar.focus` after Clear selection

    import Klar.BulkBar as BulkBar
    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.Toolbar as Toolbar

    BulkBar.view
        [ BulkBar.id "orders-bulk"
        , BulkBar.itemName { one = "order", other = "orders" }
        , BulkBar.selectAllMatching
            { total = model.matching, onPage = List.length model.page, onSelectAll = SelectAllOrders }
        ]
        { toolbar = Toolbar.view [ Toolbar.ariaLabel "Orders" ] [ searchField, newOrderButton ]
        , selected = Set.size model.selected
        , onClear = ClearSelection
        }
        [ Button.view [ Button.icon Icon.download, Button.onClick ExportSelected ] "Export"
        , Button.view [ Button.danger, Button.icon Icon.trash, Button.onClick DeleteSelected ] "Delete"
        ]

Use it for a list, a grid of cards or any selectable collection that has no bar of
its own ([Klar.Table](Klar-Table) draws one for its selection). You keep the
selection in your model and tell the bar how many items are selected.


# Where the bar goes

Selecting the first item must not push the content down, and clearing the last one
must not pull it up. So the bar does not appear above or below the list: it takes
the place of the toolbar that is already there, in the same box. You hand that
`toolbar` to `view`; it is always drawn, and while something is selected the bar
covers it (the toolbar keeps its place, its size and its state, a search field
keeps its text, but it cannot be reached with the keyboard or the mouse until the
bar goes away). The bar has the size of the toolbar: `Toolbar.small` and `Toolbar.large`
change both. The place is as tall as the taller of the two, always: with a count
of zero (or less) the bar is drawn all the same, out of sight and out of reach of the
mouse, the keyboard and screen readers, as it would look for a whole page of ticked items
(with the offer to select everything), so that its height is counted even when the bar
wraps onto two lines in a narrow column. A list with no toolbar of its own should pass a
quiet `Toolbar` with a label, such as the name of the list: the place is kept for the
bar, and an empty one would leave a gap. The bar asks for no focus when it appears.


# Keyboard and announcements

The controls are ordinary buttons in the order the eye reads them: the count, the
offer to select everything, your actions, and "Clear selection" last. The bar listens
to no keys. In particular `Escape` does not clear the selection: it also closes
menus and dialogs and empties search fields, so whether it means "clear" is a
decision for the application (a [Klar.Shortcut](Klar-Shortcut) of its own).

The count is announced politely (`role="status"` with `aria-live="polite"`) by one
region that is always on the page and whose text changes, so a screen reader finishes
what it is reading and then says "12 selected", never a new announcement for every
click of a quick selection. Only changes are announced: a bar that is drawn for the
first time with items already selected says nothing. The count going down to zero is
not announced either; say what happened yourself, with a [Klar.Toast](Klar-Toast). The
bar is a group named with the count ("Actions, 12 selected"), so a screen reader that
moves into it with `Tab` hears how many items its buttons act on.


# Focus

"Select all N matching" stays where it is when it has been used: it turns into an
inactive button, "All matching selected" (`aria-disabled`, so that it keeps focus),
and nothing is lost.

"Clear selection", and any action of yours that empties the selection (Delete), take
the whole bar away, and with it the button that has focus. A focused element that
disappears leaves focus on the page body: a screen reader says nothing, and only some
browsers continue the next `Tab` from where the button was. The bar cannot move focus
itself, since it keeps no state and a click sends a single message, so the application
does it in the same `update`, with one call that works for all of these cases: give the
bar an `id` and move focus to it with [`Klar.focus`](Klar#focus).

    ClearSelection ->
        ( { model | selected = Set.empty }
        , Klar.focus "orders-bulk" NoOp
        )

The id is on the box that the toolbar and the bar share. That box is on the page whether
or not something is selected, so it is there to receive focus when the bar has gone, and
the next `Tab` reaches the first control of the toolbar. If you would rather return to
the list, focus the list yourself.

**Selecting from the toolbar.** While something is selected the toolbar is inert, and a
focused element that becomes inert loses focus to the page. Keep the controls that
select (the box that ticks the whole page) in the list, not in the toolbar. When a
selection can start while focus is in the toolbar (a shortcut pressed in its search
field), call `Klar.focus` with the same id in that `update` too: the next `Tab` then
reaches the bar.


# View

@docs view


# Attributes

@docs Attribute, selectAllMatching, itemName, id, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)


{-| A setting of the bar. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { all : Maybe (Everything msg)
    , itemName : Maybe { one : String, other : String }
    , id : Maybe String
    , locale : Locale
    }


type alias Everything msg =
    { total : Int
    , onPage : Int
    , onSelectAll : msg
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { all = Nothing, itemName = Nothing, id = Nothing, locale = Locale.default }
        attributes


{-| Says that more items match than the page shows, so the bar can say "200 of
12,340 selected" and offer "Select all 12,340 matching".

  - `total` is the number of items that could be selected: everything that matches
    the search and the filters, on every page.
  - `onPage` is the number of items on the page the user sees.
  - `onSelectAll` is the message sent by the button. Your `update` selects everything
    that matches, so that the next `view` has `selected` equal to `total`.

The offer is made only when the selection is at least as large as the page, and
only when something is left to select: a person who ticked a row or two is not
asked, while one who ticked the whole page is. Once everything is selected the
button stays in its place as an inactive "All matching selected", and a screen reader
is told "All 12,340 selected".

A `total` that cannot be true, below 1 or below the number selected (the selection and
the count can disagree for a moment while a new search is on its way), is taken as
"the total is not known": the bar says "12 selected" and makes no offer and no claim
about everything. It never says "12 of 3 selected" or "All 12 selected" on such a
number.

Without `selectAllMatching` the bar says "12 selected" and offers nothing.

-}
selectAllMatching : { total : Int, onPage : Int, onSelectAll : msg } -> Attribute msg
selectAllMatching options =
    Attribute (\config -> { config | all = Just options })


{-| What the items are called, in the language of the page, one and several: the bar
then says "12 orders selected", "200 of 12,340 orders selected" and "1 order selected",
and so does the name of the group and what a screen reader is told. The default is no
name: "12 selected". Give the words in the language you give to `locale`.

    BulkBar.itemName { one = "order", other = "orders" }

-}
itemName : { one : String, other : String } -> Attribute msg
itemName forms =
    Attribute (\config -> { config | itemName = Just forms })


{-| The DOM id of the box that the toolbar and the bar share, which must be unique on
the page. With it the box can take focus, so that `Klar.focus` has a place to put it
when the bar goes away. There is no id by default.

    Klar.focus "orders-bulk" NoOp

-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The language of the built-in text: the count, "Clear selection", "Select all
N matching" and the name of the group of buttons. The default is
[`Locale.default`](Klar-Locale#default), which is English. Numbers are written the
way the language does ("12,340" or "12 340").
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The toolbar with the bar over it. `toolbar` is what the bar covers while
something is selected; `selected` is the number of selected items (zero or less
draws no bar); `onClear` is the message sent by "Clear selection". The `actions`
are your buttons and menus, which sit at the end of the bar before "Clear
selection". Use ghost or ordinary buttons: the bar has the size of the toolbar it
covers, and `Toolbar.small` and `Toolbar.large` change both together.
-}
view :
    List (Attribute msg)
    -> { toolbar : Html msg, selected : Int, onClear : msg }
    -> List (Html msg)
    -> Html msg
view attributes options actions =
    let
        config =
            configure attributes

        count =
            max 0 options.selected

        covered =
            count > 0

        -- With nothing selected the bar is drawn all the same, out of sight, as it would
        -- look for a whole page of ticked items (the count with the total, and the offer),
        -- so that the place is as tall as the bar needs and showing it moves nothing.
        shownCount =
            if covered then
                count

            else
                reservedCount config

        texts =
            countTexts config.locale config.itemName shownCount (knownTotal shownCount config)
    in
    -- The three children keep their places whether or not something is selected, so
    -- that Elm updates them in place: the toolbar keeps its state and the live
    -- region is the same element from one count to the next.
    Html.div
        [ Internal.cls [ "klar-bulk" ]
        , Internal.attrMaybe Attr.id config.id
        , Internal.attrIf (config.id /= Nothing) (Attr.tabindex -1)
        ]
        [ Html.div
            [ Internal.cls [ "klar-bulk__under", when covered "klar-bulk__under--covered" ]
            , Internal.attrIf covered (Attr.attribute "inert" "")
            ]
            [ options.toolbar ]
        , Html.div
            [ Internal.cls [ "klar-bulk__live", "klar-sr-only" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            , Attr.attribute "aria-atomic" "true"
            ]
            [ Html.text
                (if covered then
                    texts.heard

                 else
                    ""
                )
            ]
        , viewBar config options.onClear (not covered) shownCount texts.shown actions
        ]


{-| The number of selected items that the hidden bar is drawn for: the page, when the
application says how big it is, else one item.
-}
reservedCount : Config msg -> Int
reservedCount config =
    case config.all of
        Just everything ->
            max 1 everything.onPage

        Nothing ->
            1


viewBar : Config msg -> msg -> Bool -> Int -> String -> List (Html msg) -> Html msg
viewBar config onClear hidden count shown actions =
    let
        language =
            config.locale
    in
    Html.div
        ([ Internal.cls [ "klar-bulk__bar", when hidden "klar-bulk__bar--reserved" ] ]
            ++ (if hidden then
                    -- takes room, but cannot be seen, reached or read
                    [ Attr.attribute "aria-hidden" "true", Attr.attribute "inert" "" ]

                else
                    [ Attr.attribute "role" "group"
                    , Attr.attribute "aria-label"
                        (Locale.pick language { nb = "Handlinger, " ++ shown, en = "Actions, " ++ shown })
                    ]
               )
        )
        [ -- The live region says the same, once.
          Html.span
            [ Internal.cls [ "klar-bulk__count", "klar-tabular" ]
            , Attr.attribute "aria-hidden" "true"
            ]
            [ Html.text shown ]

        -- The offer is one button from the moment it is made to the moment the bar
        -- goes: when it has been used it changes in place, so that focus stays on it.
        , Internal.viewMaybe (viewOffer language) (offerFor count config)
        , Html.div [ Internal.cls [ "klar-bulk__actions" ] ]
            (actions
                ++ [ Button.view
                        [ Button.ghost
                        , Button.icon Icon.close
                        , Button.onClick onClear
                        ]
                        (Locale.pick language { nb = "Fjern valg", en = "Clear selection" })
                   ]
            )
        ]


viewOffer : Locale -> Offer msg -> Html msg
viewOffer language offer =
    Html.div [ Internal.cls [ "klar-bulk__offer" ] ]
        [ case offer of
            Offered onSelectAll total ->
                Button.view
                    [ Button.link, Button.onClick onSelectAll ]
                    (Locale.pick language
                        { nb = "Velg alle " ++ Format.int language total ++ " treff"
                        , en = "Select all " ++ Format.int language total ++ " matching"
                        }
                    )

            Taken ->
                Button.view
                    [ Button.ghost, Button.icon Icon.check, Button.ariaDisabled True ]
                    (Locale.pick language { nb = "Alle treff er valgt", en = "All matching selected" })
        ]


when : Bool -> String -> String
when condition name =
    if condition then
        name

    else
        ""



-- WHAT THE BAR SAYS


{-| The button for everything that matches: to press, or, when it has been used,
done.
-}
type Offer msg
    = Offered msg Int
    | Taken


{-| The total, when it can be true: at least 1 and at least the number selected.
Anything else counts as not known, and then the bar claims nothing about it.
-}
knownTotal : Int -> Config msg -> Maybe Int
knownTotal count config =
    case config.all of
        Just everything ->
            if everything.total >= 1 && everything.total >= count then
                Just everything.total

            else
                Nothing

        Nothing ->
            Nothing


{-| The offer is made when the selection covers the page and there is more to
select; it is taken when everything that matches is selected and that was more than
the page.
-}
offerFor : Int -> Config msg -> Maybe (Offer msg)
offerFor count config =
    case ( config.all, knownTotal count config ) of
        ( Just everything, Just total ) ->
            if everything.onPage > 0 && count >= everything.onPage then
                if total > count then
                    Just (Offered everything.onSelectAll total)

                else if total > everything.onPage then
                    Just Taken

                else
                    Nothing

            else
                Nothing

        _ ->
            Nothing


{-| What the bar shows and what the live region says: "12 selected", "200 of 12,340
selected", and, when everything is selected, "12,340 selected" in the bar (the button
beside it says "All matching selected") and "All 12,340 selected" to a screen reader,
which is not looking at the button.
-}
countTexts : Locale -> Maybe { one : String, other : String } -> Int -> Maybe Int -> { shown : String, heard : String }
countTexts language name count total =
    let
        n =
            Format.int language count

        -- " orders" after a number, when the items have a name
        named k =
            case name of
                Just forms ->
                    " " ++ Format.plural language k forms

                Nothing ->
                    ""

        plain =
            Locale.pick language { nb = n ++ named count ++ " valgt", en = n ++ named count ++ " selected" }
    in
    case total of
        Just known ->
            if count < known then
                let
                    ofTotal =
                        Locale.pick language
                            { nb = n ++ " av " ++ Format.int language known ++ named known ++ " valgt"
                            , en = n ++ " of " ++ Format.int language known ++ named known ++ " selected"
                            }
                in
                { shown = ofTotal, heard = ofTotal }

            else if count > 1 then
                { shown = plain
                , heard = Locale.pick language { nb = "Alle " ++ n ++ named count ++ " valgt", en = "All " ++ n ++ named count ++ " selected" }
                }

            else
                { shown = plain, heard = plain }

        Nothing ->
            { shown = plain, heard = plain }
