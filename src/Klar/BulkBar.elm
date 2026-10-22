module Klar.BulkBar exposing
    ( view, focus
    , Attribute, selectAllMatching, id, locale
    )

{-| The bar of actions for the items the user has selected: "12 selected: Export,
Delete".

    import Klar.BulkBar as BulkBar
    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.Toolbar as Toolbar

    BulkBar.view
        [ BulkBar.id "orders-bulk"
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
bar goes away). The place is as tall as the taller of the two. A list with no
toolbar of its own can pass a quiet `Toolbar` with a label, such as the name of the
list; without anything there to cover, the bar adds its own height when the first
item is selected.

Nothing is selected, nothing is drawn: with a count of zero (or less) you see only
your toolbar. The bar asks for no focus when it appears.


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
not announced either; say what happened yourself, with a [Klar.Toast](Klar-Toast).

A button that the user presses can be gone in the next frame, and a focused element
that disappears leaves focus on the page body. The bar removes its own buttons in two
cases, and in both the application moves focus in the same `update`:

  - "Clear selection" removes the whole bar: give focus to the list, as you do after
    any bulk action that removes the rows.
  - "Select all N matching" disappears once everything is selected: `focus` the bar
    (give it an `id`), so that the next `Tab` reaches your actions.


# View

@docs view, focus


# Attributes

@docs Attribute, selectAllMatching, id, locale

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
        { all = Nothing, id = Nothing, locale = Locale.default }
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
asked, while one who ticked the whole page is. A `total` smaller than the number
selected (the selection and the count can disagree for a moment while a new
search is on its way) is taken to be the number selected, so the bar never says
"12 of 3 selected". When everything is selected it says "All 12,340 selected".

Without `selectAllMatching` the bar says "12 selected" and offers nothing.

-}
selectAllMatching : { total : Int, onPage : Int, onSelectAll : msg } -> Attribute msg
selectAllMatching options =
    Attribute (\config -> { config | all = Just options })


{-| The DOM id of the bar, which must be unique on the page. It lets `focus` find
the bar. There is no id by default.
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


{-| Gives focus to the bar with this `id` (see the attribute `id`) while something
is selected. Call it in the `update` that handles `onSelectAll`, because the button
the user pressed is replaced by a note. The message is sent when it is done,
whether it worked or not.

    SelectAllOrders ->
        ( { model | selected = everything model }
        , BulkBar.focus "orders-bulk" NoOp
        )

-}
focus : String -> msg -> Cmd msg
focus barId done =
    Internal.focus barId done


{-| The toolbar with the bar over it. `toolbar` is what the bar covers while
something is selected; `selected` is the number of selected items (zero or less
draws no bar); `onClear` is the message sent by "Clear selection". The `actions`
are your buttons and menus, which sit at the right end of the bar before "Clear
selection". Use small ghost or ordinary buttons: the bar has the height of a
toolbar, and `Toolbar.small` and `Toolbar.large` change both together.
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

        summary =
            summaryText config.locale count (Maybe.map .total config.all)
    in
    -- The three children keep their places whether or not something is selected, so
    -- that Elm updates them in place: the toolbar keeps its state and the live
    -- region is the same element from one count to the next.
    Html.div [ Internal.cls [ "klar-bulk" ] ]
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
                    summary

                 else
                    ""
                )
            ]
        , if covered then
            viewBar config options.onClear count summary actions

          else
            Html.text ""
        ]


viewBar : Config msg -> msg -> Int -> String -> List (Html msg) -> Html msg
viewBar config onClear count summary actions =
    let
        language =
            config.locale

        offer =
            config.all
                |> Maybe.andThen
                    (\everything ->
                        if offersSelectAll count everything then
                            Just everything

                        else
                            Nothing
                    )
    in
    Html.div
        [ Internal.cls [ "klar-bulk__bar" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label"
            (Locale.pick language { nb = "Handlinger for valgte elementer", en = "Actions for the selected items" })
        , Internal.attrMaybe Attr.id config.id
        , Internal.attrIf (config.id /= Nothing) (Attr.tabindex -1)
        ]
        [ -- The live region says the same, once.
          Html.span
            [ Internal.cls [ "klar-bulk__count", "klar-tabular" ]
            , Attr.attribute "aria-hidden" "true"
            ]
            [ Html.text summary ]
        , Internal.viewMaybe
            (\everything ->
                Html.div [ Internal.cls [ "klar-bulk__offer" ] ]
                    [ Button.view
                        [ Button.link
                        , Button.onClick everything.onSelectAll
                        ]
                        (Locale.pick language
                            { nb = "Velg alle " ++ Format.int language (everythingTotal count everything) ++ " treff"
                            , en = "Select all " ++ Format.int language (everythingTotal count everything) ++ " matching"
                            }
                        )
                    ]
            )
            offer
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


when : Bool -> String -> String
when condition name =
    if condition then
        name

    else
        ""


{-| The offer is made when the selection covers the page and there is more to
select.
-}
offersSelectAll : Int -> Everything msg -> Bool
offersSelectAll count everything =
    everything.onPage > 0 && count >= everything.onPage && everythingTotal count everything > count


{-| The total, never smaller than the number selected.
-}
everythingTotal : Int -> Everything msg -> Int
everythingTotal count everything =
    max count everything.total


{-| "12 selected", "200 of 12,340 selected" or "All 12,340 selected".
-}
summaryText : Locale -> Int -> Maybe Int -> String
summaryText language count maybeTotal =
    let
        n =
            Format.int language count
    in
    case maybeTotal of
        Just total ->
            let
                of_ =
                    max count total
            in
            if count < of_ then
                Locale.pick language
                    { nb = n ++ " av " ++ Format.int language of_ ++ " valgt"
                    , en = n ++ " of " ++ Format.int language of_ ++ " selected"
                    }

            else if count > 1 then
                Locale.pick language { nb = "Alle " ++ n ++ " valgt", en = "All " ++ n ++ " selected" }

            else
                plainCount language n

        Nothing ->
            plainCount language n


plainCount : Locale -> String -> String
plainCount language n =
    Locale.pick language { nb = n ++ " valgt", en = n ++ " selected" }
