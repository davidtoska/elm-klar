module Klar.Pagination exposing
    ( view
    , Attribute, onPage, onPageSize, pageSizes, compact, jumpToPage, siblings, summary, disabled, id, label, locale
    , pageCount, range, Item(..), pageItems
    )

{-| Page navigation for long lists and tables: the range shown ("1–25 of
3,000"), rows per page, first / previous / page numbers with ellipsis / next /
last, and "Go to page".

Use when: you page a list that you fetch or show yourself, outside `Klar.Table`.
Do not use when: the list is a `Klar.Table`, which has its own page controls.

    import Klar.Pagination as Pagination

    Pagination.view
        [ Pagination.id "order-pages"
        , Pagination.onPage PageChanged
        , Pagination.onPageSize PageSizeChanged
        , Pagination.jumpToPage
        ]
        { page = model.page, pageSize = model.pageSize, total = 3000 }

    -- compact: "1–25 of 3,000  ‹ ›"
    Pagination.view [ Pagination.compact, Pagination.onPage PageChanged ]
        { page = model.page, pageSize = 25, total = 3000 }

It is **controlled**: the application owns `page` and `pageSize` and changes
them when `onPage` and `onPageSize` fire. The first page is 1. A page outside the
valid range is shown clamped, and `onPage` only ever sends a page between 1 and
the last page.

    PageChanged page ->
        ( { model | page = page }, loadOrders page model.pageSize )

    PageSizeChanged size ->
        ( { model | pageSize = size, page = 1 }, loadOrders 1 size )

[Klar.Table](Klar-Table) uses this component in its footer and keeps the page in
its own state.

The page buttons always use the same number of slots (first page, last page, the
current page with `siblings` neighbours on each side, and ellipses), so the
controls do not jump around while paging.

Keyboard and accessibility: every control is a native button, select or input.
In "Go to page", type a number and press Enter. The component is a `nav`
landmark; the current page has `aria-current="page"`, and the buttons that are
not available at the first or last page stay in the tab order, so the keyboard
focus is not lost when the user reaches that page. The built-in texts ("Rows per
page", "Next page" ...) follow `locale` and are English by default (see
[Klar.Locale](Klar-Locale)).


# View

@docs view


# Attributes

@docs Attribute, onPage, onPageSize, pageSizes, compact, jumpToPage, siblings, summary, disabled, id, label, locale


# Page math

The same arithmetic the view uses, for fetching and showing pages yourself.

@docs pageCount, range, Item, pageItems

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)


{-| A setting of a pagination. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { onPage : Maybe (Int -> msg)
    , onPageSize : Maybe (Int -> msg)
    , pageSizes : List Int
    , compact : Bool
    , jumpToPage : Bool
    , siblings : Int
    , disabled : Bool
    , id : String
    , label : Maybe String
    , locale : Locale
    , summary : Maybe (List (Html msg))
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { onPage = Nothing
        , onPageSize = Nothing
        , pageSizes = [ 10, 25, 50, 100 ]
        , compact = False
        , jumpToPage = False
        , siblings = 1
        , disabled = False
        , id = "klar-pagination"
        , label = Nothing
        , locale = Locale.default
        , summary = Nothing
        }
        attributes



-- ATTRIBUTES


{-| The message to send when the user chooses a page, with the page number. It is
1-based and always valid: between 1 and the last page. It is sent by the page
buttons, by first / previous / next / last, and by "Go to page". Without
`onPage` the buttons do nothing.

    Pagination.onPage PageChanged

-}
onPage : (Int -> msg) -> Attribute msg
onPage toMsg =
    Attribute (\config -> { config | onPage = Just toMsg })


{-| Shows the "Rows per page" choice (full variant only) and sends the new size
when the user picks one. The sizes on offer come from `pageSizes`. The current
page may no longer exist with a new size, so change `page` too, usually back to 1.

    Pagination.onPageSize PageSizeChanged

-}
onPageSize : (Int -> msg) -> Attribute msg
onPageSize toMsg =
    Attribute (\config -> { config | onPageSize = Just toMsg })


{-| The sizes offered in the "Rows per page" choice. The default is
`[ 10, 25, 50, 100 ]`. The current page size is always offered, even if it is
not in the list. Sizes below 1 are dropped.
-}
pageSizes : List Int -> Attribute msg
pageSizes sizes =
    Attribute (\config -> { config | pageSizes = List.filter (\n -> n > 0) sizes })


{-| Only the range and previous / next: "1–25 of 3,000 ‹ ›". For narrow places
like cards and side panels. The compact variant has no page numbers, no
"Rows per page" choice and no "Go to page".
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| Adds a "Go to page" number input after the page buttons. It is shown in the
full variant when there is more than one page and an `onPage` message. The user
types a page and presses Enter (or leaves the field); a number outside the range
goes to the nearest page.
-}
jumpToPage : Attribute msg
jumpToPage =
    Attribute (\config -> { config | jumpToPage = True })


{-| How many page numbers to show on each side of the current page. The default
is 1.
-}
siblings : Int -> Attribute msg
siblings n =
    Attribute (\config -> { config | siblings = max 0 n })


{-| While `True` every control is disabled, for example while a page is loading.
The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The DOM id of the navigation. The default is `"klar-pagination"`. The
"Rows per page" select and the "Go to page" input get ids derived from it
(`order-pages-size` and `order-pages-jump`), so give every pagination on a page
its own id.

    Pagination.id "order-pages"

-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = value })


{-| The accessible name of the navigation landmark. The default is "Pagination"
(in the language of `locale`). Name it more closely when a page has several
paginations, such as "Orders pages".
-}
label : String -> Attribute msg
label value =
    Attribute (\config -> { config | label = Just value })


{-| The language of the built-in text: the range, "Rows per page", the button
labels and "Go to page", with numbers grouped the way the language does it. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar-Locale).

    Pagination.locale Locale.nb

-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Replaces the range text ("1–25 of 3,000") with your own content, for
example a "Loading ..." message while a page is on its way, or nothing (an empty
list) when the range would describe rows that are not on screen. The controls
stay.

    Pagination.summary [ Html.text "Loading ..." ]

-}
summary : List (Html msg) -> Attribute msg
summary content =
    Attribute (\config -> { config | summary = Just content })



-- PAGE MATH


{-| The number of pages for a page size and a total number of items, in that
order. It is at least 1, also when there are no items.

    Pagination.pageCount 25 3000 --> 120

    Pagination.pageCount 25 0 --> 1

-}
pageCount : Int -> Int -> Int
pageCount pageSize total =
    let
        size =
            max 1 pageSize
    in
    -- not `//`, which cuts its result to 32 bits
    max 1 (ceiling (toFloat (max 0 total) / toFloat size))


{-| The 1-based numbers of the first and last item on a page, or `( 0, 0 )` when
there are no items. The page is clamped to the valid range. Use it to show the
range yourself, or to work out which items belong on a page.

    Pagination.range { page = 2, pageSize = 25, total = 30 } --> ( 26, 30 )

-}
range : { page : Int, pageSize : Int, total : Int } -> ( Int, Int )
range options =
    if options.total <= 0 then
        ( 0, 0 )

    else
        let
            size =
                max 1 options.pageSize

            current =
                clamp 1 (pageCount size options.total) options.page
        in
        ( (current - 1) * size + 1, min options.total (current * size) )


{-| A slot in the row of page buttons: `Page n` is a numbered button, and
`Ellipsis` is a gap ("…") that stands for the pages in between.
-}
type Item
    = Page Int
    | Ellipsis


{-| The slots of the row of page buttons for the current `page`, with `siblings`
page numbers on each side of it. The first and last page are always there. The
number of slots stays the same once there are enough pages (7 with one sibling),
so the row does not change width while paging.

    Pagination.pageItems { siblings = 1, page = 6, pageCount = 120 }
    --> [ Page 1, Ellipsis, Page 5, Page 6, Page 7, Ellipsis, Page 120 ]

    Pagination.pageItems { siblings = 1, page = 1, pageCount = 120 }
    --> [ Page 1, Page 2, Page 3, Page 4, Page 5, Ellipsis, Page 120 ]

-}
pageItems : { siblings : Int, page : Int, pageCount : Int } -> List Item
pageItems options =
    let
        count =
            max 1 options.pageCount

        s =
            max 0 options.siblings

        -- pages always shown at each end
        b =
            1

        current =
            clamp 1 count options.page

        startPages =
            List.range 1 (min b count)

        endPages =
            List.range (max (count - b + 1) (b + 1)) count

        siblingsStart =
            max (min (current - s) (count - b - s * 2 - 1)) (b + 2)

        siblingsEnd =
            min (max (current + s) (b + s * 2 + 2))
                (case endPages of
                    firstEnd :: _ ->
                        firstEnd - 2

                    [] ->
                        count - 1
                )

        leftGap =
            if siblingsStart > b + 2 then
                [ Ellipsis ]

            else if b + 1 < count - b then
                [ Page (b + 1) ]

            else
                []

        rightGap =
            if siblingsEnd < count - b - 1 then
                [ Ellipsis ]

            else if count - b > b then
                [ Page (count - b) ]

            else
                []
    in
    List.map Page startPages
        ++ leftGap
        ++ List.map Page (List.range siblingsStart siblingsEnd)
        ++ rightGap
        ++ List.map Page endPages



-- TEXT


type alias Texts =
    { label : String
    , range : Int -> Int -> Int -> String
    , rowsPerPage : String
    , first : String
    , previous : String
    , next : String
    , last : String
    , page : Int -> String
    , goTo : String
    }


texts : Locale -> Texts
texts loc =
    let
        n =
            Format.int loc
    in
    Locale.pick loc
        { nb =
            { label = "Sidenavigering"
            , range =
                \first last total ->
                    if total <= 0 then
                        "0 av 0"

                    else
                        n first ++ "–" ++ n last ++ " av " ++ n total
            , rowsPerPage = "Rader per side"
            , first = "Første side"
            , previous = "Forrige side"
            , next = "Neste side"
            , last = "Siste side"
            , page = \p -> "Side " ++ n p
            , goTo = "Gå til side"
            }
        , en =
            { label = "Pagination"
            , range =
                \first last total ->
                    if total <= 0 then
                        "0 of 0"

                    else
                        n first ++ "–" ++ n last ++ " of " ++ n total
            , rowsPerPage = "Rows per page"
            , first = "First page"
            , previous = "Previous page"
            , next = "Next page"
            , last = "Last page"
            , page = \p -> "Page " ++ n p
            , goTo = "Go to page"
            }
        }



-- VIEW


{-| The pagination. It takes the attributes and where the list stands: `page`
(the first page is 1), `pageSize` (items per page) and `total` (all items, not
only the loaded ones). A page outside the valid range is shown as the nearest
valid page.

    Pagination.view
        [ Pagination.id "order-pages", Pagination.onPage PageChanged ]
        { page = model.page, pageSize = 25, total = model.orderCount }

-}
view : List (Attribute msg) -> { page : Int, pageSize : Int, total : Int } -> Html msg
view attributes model =
    let
        config =
            configure attributes

        t =
            texts config.locale

        size =
            max 1 model.pageSize

        total =
            max 0 model.total

        count =
            pageCount size total

        current =
            clamp 1 count model.page

        ( first, last ) =
            range { page = current, pageSize = size, total = total }

        summaryView =
            case config.summary of
                Just [] ->
                    Html.text ""

                Just content ->
                    Html.span [ Internal.cls [ "klar-pagination__summary", "klar-tabular" ] ] content

                Nothing ->
                    Html.span [ Internal.cls [ "klar-pagination__summary", "klar-tabular" ] ]
                        [ Html.text (t.range first last total) ]

        go target =
            case config.onPage of
                Just toMsg ->
                    Button.onClick (toMsg target)

                Nothing ->
                    Button.htmlAttrs []

        stepButton icon text target enabled =
            Button.iconOnly
                (if config.disabled then
                    [ Button.ghost, Button.small, Button.disabled True ]

                 else if enabled then
                    [ Button.ghost, Button.small, go target ]

                 else
                    -- At the first or last page the button only looks disabled:
                    -- a natively disabled button would drop the keyboard focus
                    -- the moment it is used to reach that page.
                    [ Button.ghost
                    , Button.small
                    , Button.htmlAttrs
                        [ Attr.attribute "aria-disabled" "true"
                        , Internal.cls [ "klar-button--disabled" ]
                        ]
                    ]
                )
                icon
                text

        previous =
            stepButton Icon.chevronLeft t.previous (current - 1) (current > 1)

        next =
            stepButton Icon.chevronRight t.next (current + 1) (current < count)
    in
    Html.nav
        [ Internal.cls
            [ "klar-pagination"
            , if config.compact then
                "klar-pagination--compact"

              else
                ""
            , if config.disabled then
                "klar-pagination--disabled"

              else
                ""
            ]
        , Attr.id config.id
        , Attr.attribute "aria-label" (Maybe.withDefault t.label config.label)
        ]
        (if config.compact then
            [ summaryView
            , Html.div [ Internal.cls [ "klar-pagination__controls" ] ] [ previous, next ]
            ]

         else
            [ summaryView
            , Internal.viewMaybe (viewPageSize config t size) config.onPageSize

            -- the buttons and "go to page" wrap together, to the right
            , Html.div [ Internal.cls [ "klar-pagination__nav" ] ]
                [ Html.div [ Internal.cls [ "klar-pagination__controls" ] ]
                    [ stepButton Icon.chevronsLeft t.first 1 (current > 1)
                    , previous
                    , Html.ul [ Internal.cls [ "klar-pagination__pages" ] ]
                        (pageItems { siblings = config.siblings, page = current, pageCount = count }
                            |> List.map (viewItem config t current)
                        )
                    , next
                    , stepButton Icon.chevronsRight t.last count (current < count)
                    ]
                , case ( config.jumpToPage && count > 1, config.onPage ) of
                    ( True, Just toMsg ) ->
                        viewJump config t current count toMsg

                    _ ->
                        Html.text ""
                ]
            ]
        )


viewItem : Config msg -> Texts -> Int -> Item -> Html msg
viewItem config t current item =
    case item of
        Ellipsis ->
            Html.li [ Internal.cls [ "klar-pagination__gap" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "…" ]

        Page number ->
            let
                isCurrent =
                    number == current
            in
            Html.li []
                [ Html.button
                    [ Internal.cls
                        [ "klar-pagination__page"
                        , if isCurrent then
                            "klar-pagination__page--current"

                          else
                            ""
                        ]
                    , Attr.type_ "button"
                    , Attr.attribute "aria-label" (t.page number)
                    , Internal.attrIf isCurrent (Attr.attribute "aria-current" "page")
                    , Attr.disabled config.disabled
                    , case ( isCurrent, config.onPage ) of
                        ( False, Just toMsg ) ->
                            Events.onClick (toMsg number)

                        _ ->
                            Internal.noAttr
                    ]
                    [ Html.text (Format.int config.locale number) ]
                ]


viewPageSize : Config msg -> Texts -> Int -> (Int -> msg) -> Html msg
viewPageSize config t size toMsg =
    let
        selectId =
            config.id ++ "-size"

        choices =
            if List.member size config.pageSizes then
                config.pageSizes

            else
                List.sort (size :: config.pageSizes)
    in
    Html.div [ Internal.cls [ "klar-pagination__size" ] ]
        [ Html.label [ Internal.cls [ "klar-pagination__size-label" ], Attr.for selectId ] [ Html.text t.rowsPerPage ]
        , Html.span [ Internal.cls [ "klar-pagination__select" ] ]
            [ Html.select
                [ Internal.cls [ "klar-pagination__select-control", "klar-tabular" ]
                , Attr.id selectId
                , Attr.disabled config.disabled
                , Events.on "change" (Decode.map toMsg intValue)
                ]
                (List.map
                    (\choice ->
                        Html.option
                            [ Attr.value (String.fromInt choice)
                            , Attr.selected (choice == size)
                            ]
                            [ Html.text (String.fromInt choice) ]
                    )
                    choices
                )
            , Html.span [ Internal.cls [ "klar-pagination__select-icon" ] ] [ Icon.sized Icon.Small Icon.chevronDown ]
            ]
        ]


viewJump : Config msg -> Texts -> Int -> Int -> (Int -> msg) -> Html msg
viewJump config t current count toMsg =
    let
        inputId =
            config.id ++ "-jump"

        jump =
            intValue |> Decode.map (\n -> toMsg (clamp 1 count n))
    in
    Html.div [ Internal.cls [ "klar-pagination__jump" ] ]
        [ Html.label [ Internal.cls [ "klar-pagination__jump-label" ], Attr.for inputId ] [ Html.text t.goTo ]
        , Html.input
            [ Internal.cls [ "klar-pagination__jump-input", "klar-tabular" ]
            , Attr.id inputId
            , Attr.type_ "number"
            , Attr.min "1"
            , Attr.max (String.fromInt count)
            , Attr.step "1"
            , Attr.attribute "inputmode" "numeric"
            , Attr.value (String.fromInt current)
            , Attr.disabled config.disabled
            , Events.on "change" jump
            , Events.preventDefaultOn "keydown"
                (Decode.field "key" Decode.string
                    |> Decode.andThen
                        (\key ->
                            if key == "Enter" then
                                Decode.map (\msg -> ( msg, True )) jump

                            else
                                Decode.fail "not Enter"
                        )
                )
            ]
            []
        ]


intValue : Decoder Int
intValue =
    Events.targetValue
        |> Decode.andThen
            (\value ->
                case String.toInt (String.trim value) of
                    Just n ->
                        Decode.succeed n

                    Nothing ->
                        Decode.fail "not a whole number"
            )
